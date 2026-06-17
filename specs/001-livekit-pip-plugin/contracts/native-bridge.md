# Contract: Native Bridge (Pigeon + EventChannel)

**Phase 1 Output** | **Date**: 2026-06-17 | **Plan**: [../plan.md](../plan.md)

The native bridge has two parts:
1. **Pigeon** — typed command messages (Dart → Native) and one bidirectional
   callback (`@FlutterApi` is not used; see rationale in research.md §3).
2. **EventChannel** — continuous state stream (Native → Dart push).

This file is the source of truth for `pigeons/messages.dart` in both platform
packages. The generated files (`*.g.dart`, `Messages.g.kt`, `Messages.g.swift`)
MUST NOT be hand-edited.

---

## EventChannel (State Stream)

```
Channel name: livekit_pip/state
Direction:    Native → Dart (push stream)
Codec:        StandardMessageCodec
Payload:      int (PipState index, matching the Dart enum ordinal)
```

Mapping:

| Int value | PipState |
|-----------|----------|
| 0 | `unsupported` |
| 1 | `inactive` |
| 2 | `entering` |
| 3 | `active` |
| 4 | `exiting` |

The stream starts after `initialize()` succeeds and is cancelled by `dispose()`.
The stream MUST emit `entering` before `active` and `exiting` before `inactive`,
even if the OS reports them in rapid succession.

**Rationale for raw EventChannel**: Pigeon does not model push streams. This is
the one permitted hand-written channel string per the constitution. The comment
`// EventChannel: Pigeon does not model push streams` MUST appear next to the
channel registration in both platform plugin files.

---

## Pigeon Schema (pigeons/messages.dart)

```dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/messages.g.dart',
  kotlinOut: 'android/src/main/kotlin/dev/kaffah/Messages.g.kt',
  kotlinOptions: KotlinOptions(package: 'dev.kaffah'),
  swiftOut: 'ios/livekit_pip_ios/Sources/livekit_pip_ios/Messages.g.swift',
))

// ---------------------------------------------------------------------------
// Dart → Native commands
// ---------------------------------------------------------------------------

class PipInitRequest {
  /// Serialized config fields passed once at initialization.
  bool enabled = true;
  bool disableWhenScreenSharing = true;
  bool androidAutoEnterOnBackground = true;
  bool iosAutoEnterOnBackground = true;
  bool iosIncludeLocalParticipantVideo = true;

  /// Natural video dimensions for PiP aspect ratio hint.
  /// Pass 0/0 when no track is active (falls back to 16:9).
  int videoWidth = 0;
  int videoHeight = 0;
}

@HostApi()
abstract class LiveKitPipHostApi {
  /// Must be the first call after plugin registration.
  void initialize(PipInitRequest request);

  /// Request OS to enter PiP mode.
  void enterPip();

  /// Request OS to exit PiP mode.
  void exitPip();

  /// Release all native resources.
  void dispose();

  /// Returns true if the current device/OS supports PiP.
  /// Always safe to call; never throws.
  bool isSupported();

  /// Called by Dart when the dominant speaker's video track changes.
  /// On iOS: FrameBridge rebinds the RTCVideoRenderer to the new track.
  /// On Android: no-op (widget builder handles track selection in Dart).
  void updateActiveTrack(String trackId);
}
```

---

## Channel Registration (both platforms)

### Android — PipPlugin.kt

```kotlin
// Register Pigeon host API
LiveKitPipHostApi.setUp(messenger, PipHostApiImpl(activity))

// EventChannel: Pigeon does not model push streams
val stateChannel = EventChannel(messenger, "livekit_pip/state")
stateChannel.setStreamHandler(stateStreamHandler)
```

### iOS — LiveKitPipPlugin.swift

```swift
// Register Pigeon host API
LiveKitPipHostApiSetup.setUp(binaryMessenger: messenger, api: pipHostApiImpl)

// EventChannel: Pigeon does not model push streams
let stateChannel = FlutterEventChannel(name: "livekit_pip/state",
                                       binaryMessenger: messenger)
stateChannel.setStreamHandler(stateStreamHandler)
```

---

## Platform View Channel

```
View type ID: livekit_pip_view
Direction:    Dart → Native (creation only; no further messages)
Used by:      LiveKitPipView widget (iOS only)
Android:      Returns a zero-size dummy view
```

The platform view carries no message payload. Its creation triggers native setup
of the `AVSampleBufferDisplayLayer` hierarchy on iOS.
