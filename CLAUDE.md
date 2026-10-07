# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

`livekit_pip` is a standalone, reusable Flutter **federated plugin** that adds native system Picture-in-Picture (PiP) to any LiveKit-based video call app. It depends only on `livekit_client` (and the `flutter_webrtc` it transitively pulls in). The consumer hands the package a LiveKit `Room`; the package owns everything PiP.

The repo was scaffolded by Very Good CLI. Only a `getPlatformName()` stub exists end-to-end — the full PiP implementation is yet to be built.

## Core platform asymmetry (critical design constraint)

**Android**: PiP is an Activity-level mode — the whole Flutter surface shrinks and keeps rendering. Video tiles are already native WebRTC textures, so PiP content is just a Flutter widget the consumer provides. Minimal native work.

**iOS**: There is no "shrink the app" mode, and Flutter cannot draw while the app is backgrounded (the engine disables the GPU), so iOS PiP content is always native. The plugin uses the video-call content source (`AVPictureInPictureVideoCallViewController`); its PiP window shows that view controller's view hierarchy. WebRTC frames go through a native pipeline: `RTCVideoFrame → CVPixelBuffer → CMSampleBuffer → AVSampleBufferDisplayLayer`.

**Consequence**: iOS shows at most two native tiles side by side — the latest remote speaker and, optionally, the local camera — each showing video or the participant's avatar. Never an arbitrary grid, and never a consumer Flutter widget. The full grid+self experience exists only on Android. Do not try to build a native N-tile grid compositor on iOS. This asymmetry is intentional.

## Platform floors
- Android: minSdk 26 (legacy enter path), full auto-enter on API 31+
- iOS: deployment target 16.0 (the sample-buffer PiP API needs 15+; 16 grants multitasking camera access, so the live self-view needs no entitlement)

## Intended public Dart API

```dart
class LiveKitPipConfiguration {
  final bool enabled;                          // default true
  final bool disableWhenScreenSharing;         // default true
  final AndroidPipConfiguration android;
  final IosPipConfiguration ios;
}

class AndroidPipConfiguration {
  // Consumer provides a widget rendered inside the PiP window (can be full grid+self)
  final Widget Function(BuildContext context, Room room) pipWidgetBuilder;
  final bool autoEnterOnBackground;            // default true
  final bool aspectRatioFollowsActiveSpeaker;  // default true; false: size it with updateAspectRatio
}

class IosPipConfiguration {
  final bool includeLocalParticipantVideo;     // default true: local tile + multitasking camera
  final bool autoEnterOnBackground;            // default true
  final bool mirrorSelfView;                   // default true
  final bool animateExit;                      // default true; false hides tiles while PiP closes
  final String? Function(Participant)? avatarUrlResolver; // shown while camera is off
}

enum PipState { unsupported, inactive, entering, active, exiting }

class LiveKitPip {
  Future<bool> isSupported();
  Future<void> initialize({required Room room, required LiveKitPipConfiguration config});
  Future<void> enterPiP();
  Future<void> exitPiP();
  Future<void> updateAspectRatio(int width, int height); // Android window shape; no-op on iOS
  Stream<PipState> get stateStream;
  Future<void> dispose();
}

// Placed once in the call page widget tree.
// iOS: hosts the native AVSampleBufferDisplayLayer platform view.
// Android: zero-size no-op.
class LiveKitPipView extends StatelessWidget {
  const LiveKitPipView({required this.room, super.key});
  final Room room;
}
```

## Architecture

### Dart (shared, `livekit_pip/lib/src/`)
- **`LiveKitPip`** — controller + `PipState` machine
- **`LiveKitPipConfiguration`** / `AndroidPipConfiguration` / `IosPipConfiguration` — config objects
- **`ActiveSpeakerSelector`** — subscribes to Room events (`activeSpeakers`, `trackPublished/Unpublished`, `participantDisconnected`, `disconnected`), computes the dominant remote video track, exposes its track id/sid to native (Android aspect ratio; screen-share state)
- **`PipParticipantTracker`** — builds the iOS tile list (remote speaker + local): video track id or null, mic mute, display name, avatar URL; sends it via `updateParticipants`
- **`LiveKitPipView`** — platform view widget
- MethodChannel `livekit_pip` for commands; EventChannel for mode-change + state callbacks from native

### Android (`livekit_pip_android/android/src/main/kotlin/dev/kaffah/`)
- **`PipPlugin`** (`FlutterPlugin`, `ActivityAware`) — registers channels, holds Activity ref
- **`PipHelper`** — builds `PictureInPictureParams` (aspect ratio from current video, `sourceRectHint`); API 31+: `setAutoEnterEnabled(true)` early; API 26–30: `enterPictureInPictureMode()` in `onUserLeaveHint()`; forwards `onPictureInPictureModeChanged` to Dart
- **`LiveKitPipActivity`** — optional convenience base class; also support manual `PipHelper.attach(...)` path for apps with existing base classes
- No native video rendering — the Dart side swaps visible tree to `pipWidgetBuilder` on mode change

### iOS (`livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/`)
- **`LiveKitPipPlugin`** — registers channels + platform view factory
- **`PipPlatformView`** (`FlutterPlatformView`) — `UIView` containing `AVSampleBufferDisplayLayer`; owns `AVPictureInPictureController` created with `ContentSource(sampleBufferDisplayLayer:playbackDelegate:)`
- **`PlaybackDelegate`** (`AVPictureInPictureSampleBufferPlaybackDelegate`) — live stream (return infinite `CMTimeRange`, `isPlaybackPaused = false`)
- **`FrameBridge`** — resolves the native `RTCVideoTrack` from a Dart track id via flutter_webrtc's native track registry; attaches `RTCVideoRenderer`; on each frame: `RTCVideoFrame → CVPixelBuffer → CMSampleBuffer → displayLayer.enqueue(...)`. On active-speaker change from Dart: rebind renderer to new track id. **Never recreate the display layer or PiP controller mid-call.**
- **`PipTileView`** — one participant: `PipVideoRenderer`, or avatar/initials on a dark background while the camera is off or interrupted, plus a muted badge
- **`PipTileLayout`** — pure ordering/sizing: a single landscape tile goes left, otherwise the local tile; widths follow video shapes; drives `preferredContentSize`
- **`AvatarImageLoader`** — `URLSession` + `NSCache`; never logs URLs
- Multitasking camera: when the local tile binds a track, `isMultitaskingCameraAccessEnabled` is set on flutter_webrtc's capture session (reached via `NativeTrackResolver`) if supported
- **`NativeTrackResolver`** protocol — isolates the flutter_webrtc internals dependency to one file so a breaking change touches only one place

### Native communication
Uses [Pigeon](https://pub.dev/packages/pigeon). Source of truth: `pigeons/messages.dart` in each platform package. Never hand-edit `*.g.dart`, `Messages.g.kt`, or `Messages.g.swift`.

### Federated plugin wiring
`livekit_pip_platform_interface` defines abstract `LivekitPipPlatform`. Platform packages extend (not implement) it. Auto-registration via `dartPluginClass` in each package's `pubspec.yaml`.

## Build phases

**Phase 1** — Skeleton + Android full + iOS dominant speaker (no inset): package scaffolding, Dart core + state machine, MethodChannel/EventChannel, Android PiP (auto-enter + manual + widget builder swap), iOS single-track `AVSampleBufferDisplayLayer` pipeline, example app.

**Phase 2** — iOS self-view inset + active-speaker switching: self-view inset view (spec 002), `ActiveSpeakerSelector` wired to native rebind, `includeLocalParticipantVideo` honored.

**Phase 3** — Hardening + DX: `isSupported()` gating, screen-share suppression, permission/camera-off handling, call-end-in-PiP cleanup, full README, polished example.

## Key risks

1. **flutter_webrtc native track resolution (iOS)** — getting `RTCVideoTrack` from a Dart track id depends on flutter_webrtc internals. Isolate behind `NativeTrackResolver` protocol. Add a runtime guard with a clear error if resolution fails.
2. **iOS PiP cannot be tested in the simulator** — gate iOS PiP behavior tests as manual/device-only.
3. **`AVSampleBufferDisplayLayer` lifecycle** — never recreate it mid-call; rebind the renderer source instead.

## Consumer platform setup (document in README)

Android `AndroidManifest.xml` on the call activity:
```xml
android:supportsPictureInPicture="true"
android:configChanges="screenSize|smallestScreenSize|screenLayout|orientation"
```

iOS `Info.plist`: `UIBackgroundModes` must include `voip` and/or `audio`. For live self-video in PiP, iOS must allow multitasking camera access. With the iOS 16 deployment target no entitlement is needed; the device must still report `isMultitaskingCameraAccessSupported` (Apple, "Adopting Picture in Picture for video calls").

The LiveKit `Room` must stay connected in background — the host app must not disconnect on lifecycle background events. This is a hard prerequisite.

## Commands

**Unit tests** (run from inside each package directory):
```sh
cd livekit_pip && flutter test
cd livekit_pip_platform_interface && flutter test
cd livekit_pip_android && flutter test
cd livekit_pip_ios && flutter test
```

**Single test file:**
```sh
flutter test test/livekit_pip_test.dart
```

**Analyze:**
```sh
flutter analyze
```

**Regenerate Pigeon bindings** (after editing `pigeons/messages.dart`):
```sh
cd livekit_pip_android && dart run pigeon --input pigeons/messages.dart
cd livekit_pip_ios && dart run pigeon --input pigeons/messages.dart
```

**Integration tests** (requires `fluttium_cli`):
```sh
cd livekit_pip/example
fluttium test flows/test_platform_name.yaml -d <device>
```

## Linting
All packages use `very_good_analysis` — stricter than Flutter defaults. Always run `flutter analyze` before committing. Test mocking uses `mocktail` with `MockPlatformInterfaceMixin`.

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
at specs/002-ios-self-view-inset/plan.md
<!-- SPECKIT END -->
