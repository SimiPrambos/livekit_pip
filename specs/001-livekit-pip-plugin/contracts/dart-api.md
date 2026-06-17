# Contract: Public Dart API

**Phase 1 Output** | **Date**: 2026-06-17 | **Plan**: [../plan.md](../plan.md)

This is the consumer-facing contract. It MUST NOT change without a version bump and
migration note (Constitution Principle IV).

---

## LiveKitPip

The primary controller. Consumers create one instance per call session.

```dart
class LiveKitPip {
  /// Returns true if the current device and OS version support PiP.
  /// MUST be called before any other method. Never throws.
  Future<bool> isSupported();

  /// Attaches the plugin to [room] with [config].
  /// Throws [UnsupportedError] if [isSupported()] is false.
  /// Throws [StateError] if called after [dispose()].
  Future<void> initialize({
    required Room room,
    required LiveKitPipConfiguration config,
  });

  /// Requests the OS to enter PiP mode.
  /// Throws [UnsupportedError] if [isSupported()] is false.
  /// Throws [StateError] if not initialized or already disposed.
  Future<void> enterPiP();

  /// Requests the OS to exit PiP mode and restore full-screen.
  /// Throws [StateError] if not initialized or already disposed.
  Future<void> exitPiP();

  /// Continuous stream of PiP lifecycle state changes.
  /// Emits [PipState.unsupported] if the device does not support PiP.
  /// Closed (done event) when [dispose()] is called.
  Stream<PipState> get stateStream;

  /// Releases all native resources and closes [stateStream].
  /// Idempotent — safe to call multiple times.
  /// Any subsequent method call (except dispose) throws [StateError].
  Future<void> dispose();
}
```

---

## PipState

```dart
enum PipState {
  /// Device or OS version does not support PiP.
  /// Terminal state — no transitions out.
  unsupported,

  /// PiP is supported and initialized but the window is not visible.
  inactive,

  /// PiP window is being created; OS has accepted the request.
  /// Transient — always followed by [active].
  entering,

  /// PiP window is visible and active.
  active,

  /// PiP window is being dismissed.
  /// Transient — always followed by [inactive].
  exiting,
}
```

---

## LiveKitPipConfiguration

```dart
class LiveKitPipConfiguration {
  const LiveKitPipConfiguration({
    this.enabled = true,
    this.disableWhenScreenSharing = true,
    required this.android,
    required this.ios,
  });

  /// Master switch. When false, all PiP functionality is a no-op.
  final bool enabled;

  /// Suppress auto-enter when the local participant is screen sharing.
  final bool disableWhenScreenSharing;

  final AndroidPipConfiguration android;
  final IosPipConfiguration ios;
}
```

---

## AndroidPipConfiguration

```dart
class AndroidPipConfiguration {
  const AndroidPipConfiguration({
    required this.pipWidgetBuilder,
    this.autoEnterOnBackground = true,
  });

  /// Widget rendered inside the PiP window on Android.
  /// May include any Flutter content: grid, self-view, controls, etc.
  final Widget Function(BuildContext context, Room room) pipWidgetBuilder;

  /// If true, the OS automatically enters PiP when the user presses home (API 31+)
  /// or when [onUserLeaveHint] fires (API 26–30).
  final bool autoEnterOnBackground;
}
```

---

## IosPipConfiguration

```dart
class IosPipConfiguration {
  const IosPipConfiguration({
    this.includeLocalParticipantVideo = true,
    this.autoEnterOnBackground = true,
  });

  /// If true, the local participant's camera feed is composited as a
  /// self-view inset in the corner of the PiP window.
  /// Hidden automatically if the local camera is off.
  final bool includeLocalParticipantVideo;

  /// If true, PiP is entered automatically when the app is backgrounded.
  final bool autoEnterOnBackground;
}
```

---

## LiveKitPipView

```dart
/// Place once in the call page widget tree.
///
/// iOS: hosts the native AVSampleBufferDisplayLayer platform view.
/// Android: zero-size no-op (no layout impact).
class LiveKitPipView extends StatelessWidget {
  const LiveKitPipView({required this.room, super.key});
  final Room room;
}
```

---

## Error Contract

| Condition | Exception | Message pattern |
|-----------|-----------|-----------------|
| Called before `initialize()` | `StateError` | "LiveKitPip.X called before initialize()" |
| Called after `dispose()` | `StateError` | "LiveKitPip.X called after dispose()" |
| `enterPiP()` on unsupported device | `UnsupportedError` | "PiP is not supported on this device (isSupported() returned false)" |
| `isSupported()` | never throws | — |
| `dispose()` | never throws | — |

---

## Minimum Integration (< 20 lines)

```dart
// 1. Add to widget tree once
LiveKitPipView(room: room)

// 2. Initialize
final pip = LiveKitPip();
if (await pip.isSupported()) {
  await pip.initialize(
    room: room,
    config: LiveKitPipConfiguration(
      android: AndroidPipConfiguration(
        pipWidgetBuilder: (ctx, r) => MyCallGrid(room: r),
      ),
      ios: const IosPipConfiguration(),
    ),
  );
}

// 3. Observe state
pip.stateStream.listen((state) { /* update UI */ });

// 4. Dispose
await pip.dispose();
```
