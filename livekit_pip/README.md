# livekit_pip

[![pub package](https://img.shields.io/pub/v/livekit_pip.svg)](https://pub.dev/packages/livekit_pip)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

Native system Picture-in-Picture (PiP) for [LiveKit](https://livekit.io) video calls on Android and iOS.

## Features

- **Android** — PiP via `PictureInPictureParams`; auto-enter on API 31+, manual enter on API 26–30. Consumer supplies a Flutter widget rendered inside the PiP window (full grid layout supported).
- **iOS** — PiP via `AVPictureInPictureController` with a native `AVSampleBufferDisplayLayer`; shows the dominant/active speaker. Optional local-participant self-view inset via pixel-buffer composition.
- `PipState` stream (`unsupported → inactive → entering → active → exiting`) for UI-driven reactions.
- Auto-enter on app background, configurable per platform.

## Platform requirements

| Platform | Minimum |
|---|---|
| Android | API 26 (minSdk 26) |
| iOS | 16.0 |

## Android setup

In your call `Activity` inside `AndroidManifest.xml`:

```xml
android:supportsPictureInPicture="true"
android:configChanges="screenSize|smallestScreenSize|screenLayout|orientation"
```

Either extend `LiveKitPipActivity` or call `PipHelper.attach(activity)` manually.

## iOS setup

In `Info.plist`, add `voip` (and optionally `audio`) to `UIBackgroundModes`:

```xml
<key>UIBackgroundModes</key>
<array>
  <string>voip</string>
  <string>audio</string>
</array>
```

For self-view in PiP on iOS 17 and below, add the multitasking camera access entitlement:

```xml
<key>com.apple.developer.avfoundation.multitasking-camera-access</key>
<true/>
```

## Usage

```dart
import 'package:livekit_pip/livekit_pip.dart';

final pip = LiveKitPip();

await pip.initialize(
  room: room,
  config: LiveKitPipConfiguration(
    android: AndroidPipConfiguration(
      pipWidgetBuilder: (context, room) => MyCallGridWidget(room: room),
    ),
    ios: IosPipConfiguration(
      includeLocalParticipantVideo: true,
    ),
  ),
);

// Place once in your call widget tree (required for iOS; no-op on Android)
LiveKitPipView(room: room)

// Enter PiP manually
await pip.enterPiP();

// React to state changes
pip.stateStream.listen((state) {
  if (state == PipState.active) {
    // hide call controls
  }
});

// Clean up
await pip.dispose();
```

> **Prerequisite:** The LiveKit `Room` must stay connected in the background. Do not disconnect on app lifecycle background events.

## Federated plugin packages

| Package | Description |
|---|---|
| [`livekit_pip`](https://pub.dev/packages/livekit_pip) | App-facing package |
| [`livekit_pip_platform_interface`](https://pub.dev/packages/livekit_pip_platform_interface) | Shared platform interface |
| [`livekit_pip_android`](https://pub.dev/packages/livekit_pip_android) | Android implementation |
| [`livekit_pip_ios`](https://pub.dev/packages/livekit_pip_ios) | iOS implementation |
