# livekit_pip

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

Native Picture-in-Picture for [LiveKit](https://livekit.io) Flutter apps — on both Android and iOS — in a single package.

---

## Status

This package is under active development.

| Area | State |
|---|---|
| iOS — dominant-speaker PiP (auto-enter, manual enter/exit, active-speaker switching) | ✅ Working |
| iOS — screen-share suppression & `PipState` stream | ✅ Working |
| iOS — self-view inset (`includeLocalParticipantVideo`) | 🚧 Planned (config exists, native compositing not yet wired) |
| Android — full widget-based PiP | 🚧 In progress (scaffolded, not yet finalized) |

The API surface below is the intended public interface; flags marked 🚧 are accepted but not yet fully honored.

---

## Why livekit_pip?

Keeping a video call visible while users switch apps is table stakes for any serious calling product. Flutter's WebRTC layer doesn't expose PiP out of the box, and the two platforms work completely differently under the hood. `livekit_pip` handles all of it:

- **Android** — shrinks the entire Flutter surface into a floating window. You supply the widget (grid, self-view, anything). The package handles `PictureInPictureParams`, auto-enter on background (API 31+), and the legacy `onUserLeaveHint` path (API 26–30).
- **iOS** — drives a native `AVSampleBufferDisplayLayer` with a live WebRTC frame pipeline. The active speaker fills the PiP window automatically (a composited self-view inset is planned). No extra entitlements needed on iOS 18+ with a `voip` background mode.

Just hand the package a LiveKit `Room` and drop in one widget. Everything else is automatic.

---

## Features

- Auto-enter PiP when the user backgrounds the app (configurable)
- Manual enter/exit via a simple API
- Active-speaker tracking — iOS PiP always shows the dominant speaker
- Screen-share suppression (exit PiP when the local user is screen sharing)
- `PipState` stream for driving your own UI (`unsupported` → `inactive` → `entering` → `active` → `exiting`)
- Graceful no-ops when PiP is unsupported or disabled in system settings

Planned (see [Status](#status)):

- Optional self-view inset on iOS (composited natively, no extra layers)
- Custom Flutter widget inside the PiP window on Android (render whatever you like)

---

## Platform support

| Feature | Android | iOS |
|---|---|---|
| Minimum version | API 26 (Android 8) | iOS 16 |
| Auto-enter on background | 🚧 | ✅ |
| Manual enter/exit | 🚧 | ✅ |
| Custom widget in PiP window | 🚧 | — |
| Active speaker (dominant feed) | 🚧 | ✅ |
| Self-view inset | 🚧 (via widget) | 🚧 (composited) |

> ✅ implemented · 🚧 in progress — see [Status](#status).

> iOS shows a single composited feed — one dominant speaker plus optional self-view inset. An arbitrary multi-tile grid in the PiP window is not possible on iOS due to platform constraints (`AVSampleBufferDisplayLayer` accepts one buffer at a time).

---

## Installation

Add to your app's `pubspec.yaml`:

```yaml
dependencies:
  livekit_pip: ^0.1.0
```

### Android setup

In your call `Activity` in `AndroidManifest.xml`:

```xml
<activity
  android:name=".MainActivity"
  android:supportsPictureInPicture="true"
  android:configChanges="screenSize|smallestScreenSize|screenLayout|orientation">
```

### iOS setup

In `Info.plist`, add `voip` (and/or `audio`) to `UIBackgroundModes`:

```xml
<key>UIBackgroundModes</key>
<array>
  <string>voip</string>
  <string>audio</string>
</array>
```

For self-view in PiP on iOS 17 and below, add the multitasking camera entitlement to your `.entitlements` file:

```xml
<key>com.apple.developer.avfoundation.multitasking-camera-access</key>
<true/>
```

> **Prerequisite:** The LiveKit `Room` must remain connected while the app is in the background. Do not disconnect or suspend audio on lifecycle background events.

---

## Usage

### 1. Add `LiveKitPipView` to your call page

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Stack(
      children: [
        // ... your call UI ...
        LiveKitPipView(room: room),
      ],
    ),
  );
}
```

`LiveKitPipView` is a zero-size no-op on Android and hosts the native rendering layer on iOS.

### 2. Initialize and configure

```dart
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
```

### 3. Observe state

```dart
pip.stateStream.listen((state) {
  // PipState.active → hide your call controls
  // PipState.inactive → restore them
});
```

### 4. Enter / exit manually

```dart
// Enter PiP (e.g. on a button press)
await pip.enterPiP();

// Restore full-screen
await pip.exitPiP();
```

### 5. Clean up

```dart
@override
void dispose() {
  pip.dispose();
  super.dispose();
}
```

---

## License

MIT — see [LICENSE](LICENSE).

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
