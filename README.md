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
| Android — auto-enter PiP on background (API 31+) | ✅ Working |
| Android — manual enter/exit via API | ✅ Working |
| Android — active speaker tracking & dynamic aspect ratio | ✅ Working |
| Android — custom widget rendering in PiP window | ✅ Working |

The API surface below is the intended public interface; flags marked 🚧 are accepted but not yet fully honored.

---

## Why livekit_pip?

Keeping a video call visible while users switch apps is table stakes for any serious calling product. Flutter's WebRTC layer doesn't expose PiP out of the box, and the two platforms work completely differently under the hood. `livekit_pip` handles all of it:

- **Android** — shrinks the entire Flutter surface into a floating window. You supply the widget (grid, self-view, anything). The package handles `PictureInPictureParams`, auto-enter on background (API 31+), and the legacy `onUserLeaveHint` path (API 26–30).
- **iOS** — drives a native `AVSampleBufferDisplayLayer` with a live WebRTC frame pipeline. The active speaker fills the PiP window automatically (a composited self-view inset is planned). No extra entitlements needed on iOS 18+ with a `voip` background mode.

Just hand the package a LiveKit `Room` and drop in one widget. Everything else is automatic.

---

## Features

- **Auto-enter PiP on background** — API 31+ enters automatically; API 26–30 via legacy `onUserLeaveHint` path (configurable)
- **Manual enter/exit** via `enterPiP()` and `exitPiP()`
- **Active-speaker tracking** — iOS shows the dominant speaker; Android renders your custom widget with live feed updates
- **Dynamic aspect ratio** — Android PiP window automatically adapts to video resolution
- **Screen-share suppression** — exits PiP when the local user shares screen (configurable)
- **`PipState` stream** for driving your own UI (`unsupported` → `inactive` → `entering` → `active` → `exiting`)
- **Custom widget rendering** — Android: provide any Flutter widget (grid, self-view, branded overlay, etc.)
- **Graceful degradation** — no-ops when PiP is unsupported or disabled in system settings

Planned (see [Status](#status)):

- Optional self-view inset on iOS (composited natively, no extra layers)

---

## Platform support

| Feature | Android | iOS |
|---|---|---|
| Minimum version | API 26 (Android 8) | iOS 16 |
| Auto-enter on background | ✅ | ✅ |
| Manual enter/exit | ✅ | ✅ |
| Custom widget in PiP window | ✅ | — |
| Active speaker (dominant feed) | ✅ | ✅ |
| Dynamic aspect ratio | ✅ | — |
| Self-view inset | ✅ (via widget) | 🚧 (composited) |

> ✅ implemented · 🚧 in progress — see [Status](#status).

> **Note:** iOS shows a single composited feed — one dominant speaker plus optional self-view inset. An arbitrary multi-tile grid in the PiP window is not possible on iOS due to platform constraints (`AVSampleBufferDisplayLayer` accepts one buffer at a time). Android supports any custom widget in the PiP window via `pipWidgetBuilder`, enabling full flexibility.

---

## Installation

Add to your app's `pubspec.yaml`:

```yaml
dependencies:
  livekit_pip: ^0.1.0
```

### Android setup

#### 1. Update `AndroidManifest.xml`

Add `android:supportsPictureInPicture="true"` and the config-change handlers to your call `Activity`:

```xml
<activity
  android:name=".MainActivity"
  android:supportsPictureInPicture="true"
  android:configChanges="screenSize|smallestScreenSize|screenLayout|orientation">
  <!-- ... intent filters ... -->
</activity>
```

- `supportsPictureInPicture` — declares PiP capability; required for all API levels.
- `configChanges` — tells Android to not recreate the Activity when these config changes occur (screen rotation, size); without this, the Flutter engine would tear down mid-call.

#### 2. Extend `LiveKitPipActivity` in your `MainActivity`

The simplest path: inherit `LiveKitPipActivity` instead of the default base class:

```kotlin
import dev.kaffah.livekit_pip_android.LiveKitPipActivity

class MainActivity : LiveKitPipActivity() {
  // Your custom logic here; PiP wiring is automatic.
}
```

**Alternative:** If you already extend a custom Activity base class:

Override `onUserLeaveHint()` and forward to the plugin:

```kotlin
import dev.kaffah.livekit_pip_android.PipHelper

class MainActivity : MyCustomActivityBase() {
  override fun onUserLeaveHint() {
    PipHelper.instance.onUserLeaveHint(this)
    super.onUserLeaveHint()
  }
}
```

#### 3. Wrap your call UI in `LiveKitPipScaffold`

On the call page where you render video, use `LiveKitPipScaffold`:

```dart
final pip = LiveKitPip();

await pip.initialize(
  room: room,
  config: LiveKitPipConfiguration(
    android: AndroidPipConfiguration(
      pipWidgetBuilder: (context, room) => MyCallGridWidget(room: room),
    ),
    ios: const IosPipConfiguration(),
  ),
);

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: LiveKitPipScaffold(
      pip: pip,
      builder: (context) => Stack(
        children: [
          LiveKitPipView(room: room),
          // ... your call UI (grid, self-view, controls, etc.) ...
        ],
      ),
    ),
  );
}
```

- `LiveKitPipScaffold` automatically swaps the visible widget tree: shows `builder` when full-screen, switches to `pipWidgetBuilder` when PiP is active.
- On Android, `LiveKitPipView` is a no-op; on iOS it hosts the native rendering layer.

#### 4. Provide a `pipWidgetBuilder`

The `pipWidgetBuilder` closure receives the `BuildContext` and `Room`, and must return a widget to display inside the PiP window. This is typically a simplified view of the call:

```dart
pipWidgetBuilder: (context, room) {
  // Render the dominant speaker or a grid — whatever fits your design.
  return VideoTrackRenderer(dominantTrack, fit: VideoViewFit.cover);
}
```

The PiP window will automatically adjust its aspect ratio to match the video resolution and remain responsive to active-speaker changes.

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
