# Android PiP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Android Picture-in-Picture work end-to-end — a dedicated PiP widget swapped in while in PiP, a window aspect ratio matching the dominant video, correct home-button enter on all supported API levels, and a working example app.

**Architecture:** Android PiP shrinks the whole Flutter surface, so PiP content is just a Flutter widget. A new `LiveKitPipScaffold` listens to `LiveKitPip.stateStream` and swaps the visible subtree to the consumer's `pipWidgetBuilder` while in PiP (Android only; pass-through on iOS). A new pigeon `updateAspectRatio` host call carries the dominant track's dimensions (read from `ActiveSpeakerSelector`) to `PipHelper`, which clamps and applies them. `LiveKitPipActivity.onUserLeaveHint` drives the legacy (API 26–30) enter path, replacing the current `onActivityPaused` hack.

**Tech Stack:** Flutter, Dart, Kotlin (Android Activity/PictureInPictureParams), Pigeon for host messaging, livekit_client 2.6.1, mocktail for Dart tests.

## Global Constraints

- Federated plugin: `livekit_pip_platform_interface` defines abstract `LivekitPipPlatform`; platform packages **extend** (not implement) it.
- Native messaging uses Pigeon. Never hand-edit `*.g.dart`, `Messages.g.kt`, or `Messages.g.swift` — regenerate from `pigeons/messages.dart`.
- Android floor: `minSdk 26`. Auto-enter (`setAutoEnterEnabled`) is API 31+ (`Build.VERSION_CODES.S`); legacy manual enter is API 26–30.
- iOS is unchanged by this work. The new `updateAspectRatio` is a no-op on iOS (iOS derives aspect from frames natively).
- All packages use `very_good_analysis`. Run `flutter analyze` (zero issues) before each commit.
- Android allowed PiP aspect ratio: width/height must lie within `[1/2.39, 2.39]`. Outside this range, `PictureInPictureParams` throws `IllegalArgumentException`.
- Tests use `mocktail` with `MockPlatformInterfaceMixin`. PiP itself cannot be tested in simulators/CI — device behavior is verified manually.
- Run Dart commands from inside each package directory (e.g. `cd livekit_pip && flutter test`).

---

### Task 1: Add `updateAspectRatio` to the platform interface (default no-op)

**Files:**
- Modify: `livekit_pip_platform_interface/lib/src/livekit_pip_platform.dart`
- Test: `livekit_pip_platform_interface/test/livekit_pip_platform_test.dart` (create if absent)

**Interfaces:**
- Produces: `Future<void> updateAspectRatio(int width, int height)` on `LivekitPipPlatform`, with a concrete default no-op body. Android overrides it; iOS and the method-channel fallback inherit the no-op.

- [ ] **Step 1: Write the failing test**

Create/append `livekit_pip_platform_interface/test/livekit_pip_platform_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePlatform extends LivekitPipPlatform with MockPlatformInterfaceMixin {
  @override
  Future<bool> isSupported() async => true;
  @override
  Future<void> initialize({
    required bool enabled,
    required bool disableWhenScreenSharing,
    required bool androidAutoEnterOnBackground,
    required bool iosAutoEnterOnBackground,
    required bool iosIncludeLocalParticipantVideo,
    required int videoWidth,
    required int videoHeight,
  }) async {}
  @override
  Future<void> enterPip() async {}
  @override
  Future<void> exitPip() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> updateActiveTrack(String trackId) async {}
  @override
  Stream<int> get stateStream => const Stream<int>.empty();
}

void main() {
  test('updateAspectRatio default implementation is a no-op', () async {
    final platform = _FakePlatform();
    // Must not throw; the base class provides a no-op default.
    await platform.updateAspectRatio(1280, 720);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd livekit_pip_platform_interface && flutter test test/livekit_pip_platform_test.dart`
Expected: FAIL — `The method 'updateAspectRatio' isn't defined for the type 'LivekitPipPlatform'` (compile error).

- [ ] **Step 3: Add the concrete default method**

In `livekit_pip_platform_interface/lib/src/livekit_pip_platform.dart`, add after the `updateActiveTrack` declaration (around line 48):

```dart
  /// Called when the dominant video's aspect ratio changes.
  ///
  /// Used on Android to size the PiP window. Default is a no-op; iOS derives
  /// its aspect ratio from native frames and does not override this.
  Future<void> updateAspectRatio(int width, int height) async {}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd livekit_pip_platform_interface && flutter test test/livekit_pip_platform_test.dart`
Expected: PASS

- [ ] **Step 5: Analyze and commit**

```bash
cd livekit_pip_platform_interface && flutter analyze
git add livekit_pip_platform_interface/lib/src/livekit_pip_platform.dart livekit_pip_platform_interface/test/livekit_pip_platform_test.dart
git commit -m "feat(platform): add updateAspectRatio host method (default no-op)"
```

---

### Task 2: Add `updateAspectRatio` to the Android pigeon + native + Dart impl

**Files:**
- Modify: `livekit_pip_android/pigeons/messages.dart`
- Regenerate: `livekit_pip_android/lib/src/messages.g.dart`, `livekit_pip_android/android/src/main/kotlin/dev/kaffah/Messages.g.kt`
- Modify: `livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipPlugin.kt`
- Modify: `livekit_pip_android/lib/livekit_pip_android.dart`

**Interfaces:**
- Consumes: `LivekitPipPlatform.updateAspectRatio` (Task 1).
- Produces: `LiveKitPipHostApi.updateAspectRatio(int width, int height)` (pigeon); `PipHelper.updateAspectRatio(width, height)` is called from `PipPlugin` (the `PipHelper` method is implemented in Task 7 — until then, call it; Task 7 lands the method).

> Note: `PipHelper.updateAspectRatio` does not exist until Task 7. To keep this task compiling, add a temporary minimal stub `fun updateAspectRatio(width: Int, height: Int) {}` to `PipHelper.kt` in Step 3 here; Task 7 replaces the stub body with the real implementation.

- [ ] **Step 1: Add the method to the pigeon schema**

In `livekit_pip_android/pigeons/messages.dart`, add to `abstract class LiveKitPipHostApi` (after `updateActiveTrack`):

```dart
  void updateAspectRatio(int width, int height);
```

- [ ] **Step 2: Regenerate bindings**

Run: `cd livekit_pip_android && dart run pigeon --input pigeons/messages.dart`
Expected: `lib/src/messages.g.dart` and `android/src/main/kotlin/dev/kaffah/Messages.g.kt` regenerate with a new `updateAspectRatio` member. Do not edit them by hand.

- [ ] **Step 3: Implement in PipPlugin + add temporary PipHelper stub**

In `livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipPlugin.kt`, add to the `LiveKitPipHostApi` region (after `updateActiveTrack`):

```kotlin
    override fun updateAspectRatio(width: Long, height: Long) {
        pipHelper?.updateAspectRatio(width.toInt(), height.toInt())
    }
```

In `livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipHelper.kt`, add a temporary stub method (Task 7 replaces the body):

```kotlin
    fun updateAspectRatio(width: Int, height: Int) {
        // Implemented in Task 7.
    }
```

> Pigeon maps Dart `int` to Kotlin `Long`. Match the generated signature exactly (`Long` params).

- [ ] **Step 4: Override in the Android Dart impl**

In `livekit_pip_android/lib/livekit_pip_android.dart`, add (after `updateActiveTrack`):

```dart
  @override
  Future<void> updateAspectRatio(int width, int height) =>
      _api.updateAspectRatio(width, height);
```

- [ ] **Step 5: Analyze and commit**

```bash
cd livekit_pip_android && flutter analyze
git add livekit_pip_android/pigeons/messages.dart livekit_pip_android/lib/src/messages.g.dart livekit_pip_android/android/src/main/kotlin/dev/kaffah/Messages.g.kt livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipPlugin.kt livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipHelper.kt livekit_pip_android/lib/livekit_pip_android.dart
git commit -m "feat(android): add updateAspectRatio pigeon method and wiring"
```

---

### Task 3: Dart aspect-ratio clamp utility

**Files:**
- Create: `livekit_pip/lib/src/aspect_ratio.dart`
- Test: `livekit_pip/test/aspect_ratio_test.dart`

**Interfaces:**
- Produces: `({int width, int height}) clampPipAspectRatio(int width, int height)` — returns `(0, 0)` for non-positive input; otherwise scales the smaller dimension so the ratio is within Android's `[1/2.39, 2.39]` range, preserving the longer dimension.

- [ ] **Step 1: Write the failing test**

Create `livekit_pip/test/aspect_ratio_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_pip/src/aspect_ratio.dart';

void main() {
  group('clampPipAspectRatio', () {
    test('in-range ratio is unchanged', () {
      expect(clampPipAspectRatio(1280, 720), (width: 1280, height: 720));
    });

    test('zero or negative returns (0, 0)', () {
      expect(clampPipAspectRatio(0, 720), (width: 0, height: 0));
      expect(clampPipAspectRatio(1280, 0), (width: 0, height: 0));
      expect(clampPipAspectRatio(-1, -1), (width: 0, height: 0));
    });

    test('too-wide is clamped to 2.39:1', () {
      final r = clampPipAspectRatio(3000, 1000); // 3.0 ratio
      expect(r.height, 1000);
      expect(r.width / r.height, closeTo(2.39, 0.01));
    });

    test('too-tall is clamped to 1:2.39', () {
      final r = clampPipAspectRatio(1000, 3000); // 0.333 ratio
      expect(r.width, 1000);
      expect(r.width / r.height, closeTo(1 / 2.39, 0.01));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd livekit_pip && flutter test test/aspect_ratio_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:livekit_pip/src/aspect_ratio.dart'`.

- [ ] **Step 3: Implement the utility**

Create `livekit_pip/lib/src/aspect_ratio.dart`:

```dart
/// Android's PiP window aspect ratio must lie within [minRatio, maxRatio].
/// Values outside this range cause PictureInPictureParams to throw.
const double _maxRatio = 2.39;
const double _minRatio = 1 / 2.39;

/// Clamps [width]/[height] to Android's allowed PiP aspect-ratio range.
///
/// Returns `(0, 0)` for non-positive input. The longer side is preserved and
/// the other side is scaled to bring the ratio into range.
({int width, int height}) clampPipAspectRatio(int width, int height) {
  if (width <= 0 || height <= 0) return (width: 0, height: 0);
  final ratio = width / height;
  if (ratio > _maxRatio) {
    return (width: (height * _maxRatio).round(), height: height);
  }
  if (ratio < _minRatio) {
    return (width: width, height: (width / _minRatio).round());
  }
  return (width: width, height: height);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd livekit_pip && flutter test test/aspect_ratio_test.dart`
Expected: PASS

- [ ] **Step 5: Analyze and commit**

```bash
cd livekit_pip && flutter analyze
git add livekit_pip/lib/src/aspect_ratio.dart livekit_pip/test/aspect_ratio_test.dart
git commit -m "feat: add PiP aspect-ratio clamp utility"
```

---

### Task 4: `ActiveSpeakerSelector` surfaces dominant-track dimensions

**Files:**
- Modify: `livekit_pip/lib/src/active_speaker_selector.dart`
- Test: `livekit_pip/test/active_speaker_selector_test.dart`

**Interfaces:**
- Consumes: livekit_client `TrackPublication.dimensions` (`VideoDimensions?` with `.width` / `.height`).
- Produces: optional constructor param `void Function(int width, int height)? onAspectRatioChanged`, invoked alongside `onTrackChanged` when the chosen publication has dimensions; and getter `VideoDimensions? get currentBestDimensions`.

- [ ] **Step 1: Write the failing test**

Append to `livekit_pip/test/active_speaker_selector_test.dart` inside the existing `group`:

```dart
    test('accepts onAspectRatioChanged and exposes currentBestDimensions',
        () async {
      final room = Room();
      final selector = ActiveSpeakerSelector(
        room: room,
        onTrackChanged: (_) {},
        onAspectRatioChanged: (_, __) {},
      );
      // Empty room → no dimensions known yet.
      expect(selector.currentBestDimensions, isNull);
      await selector.dispose();
      await room.dispose();
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd livekit_pip && flutter test test/active_speaker_selector_test.dart`
Expected: FAIL — `No named parameter with the name 'onAspectRatioChanged'` and `currentBestDimensions` undefined.

- [ ] **Step 3: Implement the changes**

In `livekit_pip/lib/src/active_speaker_selector.dart`:

Add the constructor param and field. Change the constructor signature and initializer list:

```dart
  ActiveSpeakerSelector({
    required Room room,
    required void Function(String? trackId) onTrackChanged,
    void Function(int width, int height)? onAspectRatioChanged,
  })  : _room = room,
        _onTrackChanged = onTrackChanged,
        _onAspectRatioChanged = onAspectRatioChanged {
    _listener = room.createListener()
      ..on<ActiveSpeakersChangedEvent>(_onActiveSpeakersChanged)
      ..on<TrackMutedEvent>(_onTrackMuted)
      ..on<TrackUnmutedEvent>(_onTrackUnmuted)
      ..on<LocalTrackPublishedEvent>(_onLocalTrackPublished)
      ..on<LocalTrackUnpublishedEvent>(_onLocalTrackUnpublished);
  }

  final Room _room;
  final void Function(String? trackId) _onTrackChanged;
  final void Function(int width, int height)? _onAspectRatioChanged;
```

In `_onActiveSpeakersChanged`, after `_updateTrack(trackId);` and before `return;`, emit dimensions:

```dart
        if (!pub.muted && pub.subscribed && trackId != null) {
          _updateTrack(trackId);
          final dim = pub.dimensions;
          if (dim != null) {
            _onAspectRatioChanged?.call(dim.width, dim.height);
          }
          return;
        }
```

Add the getter near `currentBestTrackId`:

```dart
  /// Dimensions of the current best remote video track, if known.
  VideoDimensions? get currentBestDimensions {
    for (final p in _room.activeSpeakers) {
      if (p is! RemoteParticipant) continue;
      for (final pub in p.videoTrackPublications) {
        if (!pub.muted && pub.subscribed && pub.dimensions != null) {
          return pub.dimensions;
        }
      }
    }
    for (final p in _room.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        if (!pub.muted && pub.subscribed && pub.dimensions != null) {
          return pub.dimensions;
        }
      }
    }
    return null;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd livekit_pip && flutter test test/active_speaker_selector_test.dart`
Expected: PASS (all tests in file)

- [ ] **Step 5: Analyze and commit**

```bash
cd livekit_pip && flutter analyze
git add livekit_pip/lib/src/active_speaker_selector.dart livekit_pip/test/active_speaker_selector_test.dart
git commit -m "feat: surface dominant-track dimensions from ActiveSpeakerSelector"
```

---

### Task 5: Wire aspect ratio + expose room/config in `LiveKitPip`

**Files:**
- Modify: `livekit_pip/lib/src/livekit_pip.dart`
- Test: `livekit_pip/test/livekit_pip_test.dart`

**Interfaces:**
- Consumes: `clampPipAspectRatio` (Task 3), `ActiveSpeakerSelector.onAspectRatioChanged` / `currentBestDimensions` (Task 4), `LivekitPipPlatform.updateAspectRatio` (Task 1).
- Produces: `Room? get room` and `LiveKitPipConfiguration? get configuration` on `LiveKitPip` (consumed by `LiveKitPipScaffold` in Task 6).

- [ ] **Step 1: Write the failing test**

In `livekit_pip/test/livekit_pip_test.dart`, add the mock stub in `setUp` (after the `updateActiveTrack` stub):

```dart
    when(() => platform.updateAspectRatio(any(), any()))
        .thenAnswer((_) async {});
```

Add a new test inside `group('LiveKitPip lifecycle', ...)`:

```dart
    test('exposes room and configuration after initialize', () async {
      final pip = LiveKitPip();
      final room = Room();
      final config = _config();
      await pip.initialize(room: room, config: config);

      expect(pip.room, same(room));
      expect(pip.configuration, same(config));

      await pip.dispose();
      await room.dispose();
    });
```

> The aspect-ratio push happens on active-speaker events, which can't be synthesized on a real `Room` in unit tests (same limitation as `updateActiveTrack`). This task verifies the new getters; the aspect flow is covered by manual device testing in Task 9.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd livekit_pip && flutter test test/livekit_pip_test.dart`
Expected: FAIL — `The getter 'room'/'configuration' isn't defined for the type 'LiveKitPip'`.

- [ ] **Step 3: Implement the changes**

In `livekit_pip/lib/src/livekit_pip.dart`:

Add the import at the top:

```dart
import 'package:livekit_pip/src/aspect_ratio.dart';
```

Add a `_room` field and getters (near the other fields, after `_config`):

```dart
  Room? _room;

  /// The room passed to [initialize], or null before initialize / after dispose.
  Room? get room => _room;

  /// The configuration passed to [initialize], or null before initialize.
  LiveKitPipConfiguration? get configuration => _config;
```

In `initialize`, set `_room = room;` right after `_config = config;`. Then extend the `ActiveSpeakerSelector` construction to pass the aspect callback:

```dart
    _speakerSelector = ActiveSpeakerSelector(
      room: room,
      onTrackChanged: (trackId) {
        if (trackId != null && _initialized && !_disposed) {
          unawaited(LivekitPipPlatform.instance.updateActiveTrack(trackId));
        }
      },
      onAspectRatioChanged: (width, height) {
        if (!_initialized || _disposed) return;
        final r = clampPipAspectRatio(width, height);
        if (r.width > 0 && r.height > 0) {
          unawaited(
            LivekitPipPlatform.instance.updateAspectRatio(r.width, r.height),
          );
        }
      },
    );
```

After the existing initial-track seeding block (near the end of `initialize`), add aspect seeding:

```dart
    final initialDim = _speakerSelector?.currentBestDimensions;
    if (initialDim != null) {
      final r = clampPipAspectRatio(initialDim.width, initialDim.height);
      if (r.width > 0 && r.height > 0) {
        unawaited(
          LivekitPipPlatform.instance.updateAspectRatio(r.width, r.height),
        );
      }
    }
```

In `dispose`, set `_room = null;` where `_config = null;` is set.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd livekit_pip && flutter test test/livekit_pip_test.dart`
Expected: PASS (all tests in file)

- [ ] **Step 5: Analyze and commit**

```bash
cd livekit_pip && flutter analyze
git add livekit_pip/lib/src/livekit_pip.dart livekit_pip/test/livekit_pip_test.dart
git commit -m "feat: push dominant-track aspect ratio and expose room/config"
```

---

### Task 6: `LiveKitPipScaffold` widget

**Files:**
- Create: `livekit_pip/lib/src/livekit_pip_scaffold.dart`
- Modify: `livekit_pip/lib/livekit_pip.dart` (export)
- Test: `livekit_pip/test/livekit_pip_scaffold_test.dart`

**Interfaces:**
- Consumes: `LiveKitPip` (`stateStream`, `room`, `configuration`) from Task 5; `PipState`.
- Produces: `LiveKitPipScaffold({required LiveKitPip pip, required WidgetBuilder builder})`.

- [ ] **Step 1: Write the failing test**

Create `livekit_pip/test/livekit_pip_scaffold_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_pip/livekit_pip.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements LivekitPipPlatform {}

LiveKitPipConfiguration _config() => LiveKitPipConfiguration(
      android: AndroidPipConfiguration(
        pipWidgetBuilder: (_, __) => const Text('PIP'),
      ),
      ios: const IosPipConfiguration(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPlatform platform;
  late StreamController<int> stateRaw;

  setUp(() {
    platform = _MockPlatform();
    stateRaw = StreamController<int>.broadcast();
    LivekitPipPlatform.instance = platform;
    when(() => platform.isSupported()).thenAnswer((_) async => true);
    when(
      () => platform.initialize(
        enabled: any(named: 'enabled'),
        disableWhenScreenSharing: any(named: 'disableWhenScreenSharing'),
        androidAutoEnterOnBackground:
            any(named: 'androidAutoEnterOnBackground'),
        iosAutoEnterOnBackground: any(named: 'iosAutoEnterOnBackground'),
        iosIncludeLocalParticipantVideo:
            any(named: 'iosIncludeLocalParticipantVideo'),
        videoWidth: any(named: 'videoWidth'),
        videoHeight: any(named: 'videoHeight'),
      ),
    ).thenAnswer((_) async {});
    when(() => platform.stateStream).thenAnswer((_) => stateRaw.stream);
    when(() => platform.dispose()).thenAnswer((_) async {});
    when(() => platform.updateActiveTrack(any())).thenAnswer((_) async {});
    when(() => platform.updateAspectRatio(any(), any()))
        .thenAnswer((_) async {});
  });

  tearDown(() async => stateRaw.close());

  testWidgets('Android: shows pip widget when active, builder otherwise',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final pip = LiveKitPip();
    final room = Room();
    await pip.initialize(room: room, config: _config());

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LiveKitPipScaffold(
          pip: pip,
          builder: (_) => const Text('FULL'),
        ),
      ),
    );
    expect(find.text('FULL'), findsOneWidget);
    expect(find.text('PIP'), findsNothing);

    stateRaw.add(3); // active
    await tester.pump();
    await tester.pump();
    expect(find.text('PIP'), findsOneWidget);
    expect(find.text('FULL'), findsNothing);

    await pip.dispose();
    await room.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('non-Android: always shows builder', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final pip = LiveKitPip();
    final room = Room();
    await pip.initialize(room: room, config: _config());

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LiveKitPipScaffold(
          pip: pip,
          builder: (_) => const Text('FULL'),
        ),
      ),
    );
    stateRaw.add(3); // active
    await tester.pump();
    await tester.pump();
    expect(find.text('FULL'), findsOneWidget);
    expect(find.text('PIP'), findsNothing);

    await pip.dispose();
    await room.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd livekit_pip && flutter test test/livekit_pip_scaffold_test.dart`
Expected: FAIL — `LiveKitPipScaffold` undefined.

- [ ] **Step 3: Implement the widget**

Create `livekit_pip/lib/src/livekit_pip_scaffold.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:livekit_pip/src/livekit_pip.dart';
import 'package:livekit_pip/src/pip_state.dart';

/// Wraps the call UI and swaps to the Android PiP widget while in PiP mode.
///
/// On Android, when [LiveKitPip] reports [PipState.entering] or
/// [PipState.active], this renders `AndroidPipConfiguration.pipWidgetBuilder`;
/// otherwise it renders [builder]. On other platforms it always renders
/// [builder] (iOS PiP is rendered natively via `LiveKitPipView`).
class LiveKitPipScaffold extends StatelessWidget {
  /// Creates a scaffold bound to [pip].
  const LiveKitPipScaffold({
    required this.pip,
    required this.builder,
    super.key,
  });

  /// The controller whose state drives the swap.
  final LiveKitPip pip;

  /// Builds the normal, full-screen call UI.
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return builder(context);
    }
    return StreamBuilder<PipState>(
      stream: pip.stateStream,
      initialData: PipState.inactive,
      builder: (context, snapshot) {
        final state = snapshot.data ?? PipState.inactive;
        final inPip =
            state == PipState.entering || state == PipState.active;
        final room = pip.room;
        final pipBuilder = pip.configuration?.android.pipWidgetBuilder;
        if (inPip && room != null && pipBuilder != null) {
          return pipBuilder(context, room);
        }
        return builder(context);
      },
    );
  }
}
```

Add the export to `livekit_pip/lib/livekit_pip.dart`:

```dart
export 'src/livekit_pip_scaffold.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd livekit_pip && flutter test test/livekit_pip_scaffold_test.dart`
Expected: PASS (both widget tests)

- [ ] **Step 5: Analyze and commit**

```bash
cd livekit_pip && flutter analyze
git add livekit_pip/lib/src/livekit_pip_scaffold.dart livekit_pip/lib/livekit_pip.dart livekit_pip/test/livekit_pip_scaffold_test.dart
git commit -m "feat: add LiveKitPipScaffold for Android PiP widget swap"
```

---

### Task 7: `PipHelper` — onUserLeaveHint enter + real updateAspectRatio + remove onPause hack

**Files:**
- Modify: `livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipHelper.kt`

**Interfaces:**
- Consumes: `PipPlugin.updateAspectRatio` calls `PipHelper.updateAspectRatio` (Task 2).
- Produces: `fun onUserLeaveHint()` (called by `PipPlugin` in Task 8); real `fun updateAspectRatio(width: Int, height: Int)` body.

- [ ] **Step 1: Replace the onPause hack with onUserLeaveHint and implement updateAspectRatio**

In `livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipHelper.kt`:

Replace the temporary stub `updateAspectRatio` (added in Task 2) with the real implementation and add `onUserLeaveHint`. Insert these methods (e.g. after `configure`):

```kotlin
    /** Called from the Activity's onUserLeaveHint (home button) on API 26–30. */
    fun onUserLeaveHint() {
        if (!autoEnter) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
        ) {
            enter()
        }
    }

    /** Updates the PiP window aspect ratio. Values are clamped on the Dart side. */
    fun updateAspectRatio(width: Int, height: Int) {
        if (width <= 0 || height <= 0) return
        aspectWidth = width
        aspectHeight = height
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && autoEnter) {
                activity.setPictureInPictureParams(
                    buildParams().setAutoEnterEnabled(true).build()
                )
            } else if (activity.isInPictureInPictureMode) {
                activity.setPictureInPictureParams(buildParams().build())
            }
        } catch (e: IllegalArgumentException) {
            android.util.Log.w("livekit_pip", "setPictureInPictureParams rejected ratio", e)
        }
    }
```

In `attach(...)`, change `onActivityPaused` to no longer enter PiP (remove the legacy enter block); leave it as an empty override:

```kotlin
                override fun onActivityPaused(a: Activity) {}
```

- [ ] **Step 2: Verify the Android package compiles**

Run: `cd livekit_pip_android && flutter analyze`
Expected: No issues. (Kotlin compilation is exercised by the example build in Task 9; there is no standalone Kotlin unit suite in this module.)

- [ ] **Step 3: Commit**

```bash
git add livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipHelper.kt
git commit -m "feat(android): enter PiP via onUserLeaveHint and apply dynamic aspect ratio"
```

---

### Task 8: `LiveKitPipActivity.onUserLeaveHint` + plugin hook

**Files:**
- Modify: `livekit_pip_android/android/src/main/kotlin/dev/kaffah/LiveKitPipActivity.kt`
- Modify: `livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipPlugin.kt`

**Interfaces:**
- Consumes: `PipHelper.onUserLeaveHint` (Task 7).
- Produces: `PipPlugin.onUserLeaveHint()` (public, called by the Activity); `LiveKitPipActivity` overriding `onUserLeaveHint`.

- [ ] **Step 1: Add the plugin hook**

In `livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipPlugin.kt`, add a public method (e.g. after `enterPip`):

```kotlin
    /** Forwarded from LiveKitPipActivity.onUserLeaveHint. */
    fun onUserLeaveHint() {
        pipHelper?.onUserLeaveHint()
    }
```

- [ ] **Step 2: Override onUserLeaveHint in the base Activity**

Replace `livekit_pip_android/android/src/main/kotlin/dev/kaffah/LiveKitPipActivity.kt` with:

```kotlin
package dev.kaffah

import io.flutter.embedding.android.FlutterActivity

/**
 * Optional convenience base Activity that drives the legacy (API 26–30) PiP
 * enter path. Apps with an existing base class can instead override
 * [onUserLeaveHint] themselves and forward to the plugin the same way.
 */
open class LiveKitPipActivity : FlutterActivity() {
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        val plugin = flutterEngine?.plugins?.get(PipPlugin::class.java) as? PipPlugin
        plugin?.onUserLeaveHint()
    }
}
```

- [ ] **Step 3: Verify the Android package compiles**

Run: `cd livekit_pip_android && flutter analyze`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add livekit_pip_android/android/src/main/kotlin/dev/kaffah/LiveKitPipActivity.kt livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipPlugin.kt
git commit -m "feat(android): forward onUserLeaveHint from LiveKitPipActivity to plugin"
```

---

### Task 9: Wire the example app + manual device verification

**Files:**
- Modify: `livekit_pip/example/android/app/src/main/kotlin/.../MainActivity.kt`
- Modify: `livekit_pip/example/android/app/src/main/AndroidManifest.xml`
- Modify: `livekit_pip/example/lib/main.dart`

**Interfaces:**
- Consumes: `LiveKitPipActivity` (Task 8), `LiveKitPipScaffold` (Task 6).

- [ ] **Step 1: Point MainActivity at LiveKitPipActivity**

Find the file: `find livekit_pip/example/android -name MainActivity.kt`. Replace its contents with (keep the existing `package` line from the file):

```kotlin
package dev.kaffah.example

import dev.kaffah.LiveKitPipActivity

class MainActivity : LiveKitPipActivity()
```

- [ ] **Step 2: Enable PiP in the manifest**

In `livekit_pip/example/android/app/src/main/AndroidManifest.xml`, add to the `<activity android:name=".MainActivity" ...>` tag (the `configChanges` already includes `screenSize|smallestScreenSize|screenLayout|orientation`):

```xml
            android:supportsPictureInPicture="true"
```

- [ ] **Step 3: Wrap the call page body in LiveKitPipScaffold**

In `livekit_pip/example/lib/main.dart`, in `_CallPageState.build`, wrap the `Scaffold` body. Replace:

```dart
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
```

with:

```dart
    return Scaffold(
      backgroundColor: Colors.black,
      body: LiveKitPipScaffold(
        pip: _pip,
        builder: (context) => Stack(
          children: [
```

and close the new `builder` by replacing the body's closing `),` (the `Stack`'s closing paren before the Scaffold close) — locate the end of the `Stack(children: [ ... ])` and add one more closing `)` for the `builder`/`LiveKitPipScaffold`. The structure becomes:

```dart
        ),  // end Stack children list + Stack
      ),    // end LiveKitPipScaffold
    );      // end Scaffold
```

Update the Android PiP content builder to show the dominant remote video. Replace `_AndroidPipContent`:

```dart
class _AndroidPipContent extends StatelessWidget {
  const _AndroidPipContent({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    for (final p in room.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        final track = pub.track;
        if (track != null && pub.source == TrackSource.camera) {
          return ColoredBox(
            color: Colors.black,
            child: VideoTrackRenderer(track, fit: VideoViewFit.cover),
          );
        }
      }
    }
    return const ColoredBox(
      color: Colors.black,
      child: Center(child: Icon(Icons.videocam, color: Colors.white, size: 32)),
    );
  }
}
```

Update the config's `pipWidgetBuilder` in `_initPip` to pass the room:

```dart
          android: AndroidPipConfiguration(
            pipWidgetBuilder: (ctx, room) => _AndroidPipContent(room: room),
          ),
```

- [ ] **Step 4: Analyze the example**

Run: `cd livekit_pip/example && flutter analyze`
Expected: No issues.

- [ ] **Step 5: Manual device verification**

Build and run on an Android device, connect to a room with a second participant publishing video, then:

Run: `cd livekit_pip/example && flutter run -d <android-device>`

Verify:
- Press the home button → app enters PiP; the PiP window shows only the dominant remote video (not the full call UI).
- The PiP window aspect ratio matches the video (not always 16:9).
- Returning to the app restores the full call UI.
- On an API 26–30 device/emulator: home button enters PiP; opening a permission dialog or in-app dialog does **not** enter PiP.

Record the results (pass/fail per check) in the commit message or a follow-up note. If a check fails, stop and debug before committing — do not mark this task complete with failing behavior.

- [ ] **Step 6: Commit**

```bash
git add livekit_pip/example/android/app/src/main/kotlin livekit_pip/example/android/app/src/main/AndroidManifest.xml livekit_pip/example/lib/main.dart
git commit -m "feat(example): wire Android PiP (LiveKitPipActivity, manifest, scaffold)"
```

---

### Task 10: Document Android setup + update status

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the Status table and Android setup**

In `README.md`, update the Status table rows for Android to reflect the new MVP (auto-enter, manual enter/exit, active speaker, dynamic aspect, widget swap) as ✅ and note self-view/custom-grid niceties remain via the widget. In the **Android setup** section, document:
- Manifest: `android:supportsPictureInPicture="true"` + the `configChanges` list.
- `MainActivity : LiveKitPipActivity()` (or override `onUserLeaveHint` and forward to the plugin if using a custom base class).
- Wrapping call UI in `LiveKitPipScaffold(pip: ..., builder: ...)` and providing `pipWidgetBuilder`.

Keep the platform-support table's 🚧 only where still true (e.g. iOS self-view inset).

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: document Android PiP setup and update status"
```

---

## Self-Review

**Spec coverage:**
- §1 Widget swap → Task 6 (+ Task 5 exposes room/config). ✓
- §2 Activity wiring + manifest → Tasks 7, 8, 9. ✓
- §3 Dynamic aspect ratio → Tasks 1, 2, 3, 4, 5, 7. ✓
- §4 Example app → Task 9. ✓
- §5 iOS regression guard → Task 6 (non-Android pass-through test) + Task 9 manual note. ✓
- Testing section → unit tests in Tasks 1, 3, 4, 5, 6; manual in Task 9. ✓
- Out-of-scope items are not implemented. ✓

**Placeholder scan:** No "TBD"/"handle edge cases"/vague steps; all code steps include code. The one cross-task dependency (PipHelper stub in Task 2 → real body in Task 7) is called out explicitly. ✓

**Type consistency:**
- `updateAspectRatio(int width, int height)` consistent across platform interface (Dart), android impl (Dart), pigeon, and `PipHelper.updateAspectRatio(Int, Int)` (Kotlin params are `Long` at the pigeon boundary in `PipPlugin`, converted with `.toInt()`). ✓
- `clampPipAspectRatio` returns `({int width, int height})` everywhere it's used (Tasks 3, 5). ✓
- `onAspectRatioChanged(int width, int height)` / `currentBestDimensions` consistent between Task 4 (definition) and Task 5 (use). ✓
- `LiveKitPipScaffold({required LiveKitPip pip, required WidgetBuilder builder})` consistent between Task 6 (definition) and Task 9 (use). ✓
- `LiveKitPip.room` / `LiveKitPip.configuration` consistent between Task 5 (definition) and Task 6 (use). ✓
