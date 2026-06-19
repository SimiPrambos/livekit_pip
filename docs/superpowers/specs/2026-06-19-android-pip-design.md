# Android PiP — Design (MVP + dynamic aspect ratio)

**Date:** 2026-06-19
**Status:** Approved, pending implementation plan
**Scope:** Make Android Picture-in-Picture work end-to-end in the example app, with a dedicated PiP widget and a window aspect ratio that matches the dominant video. Defer polish (sourceRectHint, screen-share suppression on Android, remote actions).

---

## Background

Android PiP is an Activity-level mode: the whole Flutter surface shrinks into a floating window and keeps rendering. Unlike iOS, there is **no native video pipeline** — video tiles are already native WebRTC textures, so "PiP content" is just a Flutter widget the consumer provides. The package's job is to (a) enter PiP at the right moment, (b) swap the visible Flutter tree to a compact PiP widget while in PiP, and (c) size the PiP window to match the video.

### Current state (what exists today)

- `PipPlugin` (Kotlin): channels, `LiveKitPipHostApi`, `ActivityAware`, EventChannel for state.
- `PipHelper` (Kotlin): builds `PictureInPictureParams`; API 31+ auto-enter via `setAutoEnterEnabled(true)` in `onResume`; legacy enter via `onActivityPaused`; emits state on `onPictureInPictureModeChanged`; hardcoded 16:9 aspect.
- `LiveKitPipActivity` (Kotlin): convenience base class (exists, but the example does not use it and `onUserLeaveHint` is not the enter trigger).
- Dart `LivekitPipAndroid`: `initialize/enterPip/exitPip/dispose/stateStream/updateActiveTrack` wired.
- `LiveKitPip` (shared Dart): state machine, `ActiveSpeakerSelector`, config objects.

### Gaps this design closes

1. **`pipWidgetBuilder` is never rendered.** Defined in `AndroidPipConfiguration` but nothing swaps the Flutter tree, so PiP shows the full call UI crammed into the window.
2. **Example cannot enter PiP.** `AndroidManifest.xml` lacks `android:supportsPictureInPicture="true"`; `MainActivity` is a bare `FlutterActivity`.
3. **Legacy enter uses `onActivityPaused`** (via Application lifecycle callbacks) — fires on dialogs/permission prompts, not just the home button.
4. **Aspect ratio is hardcoded 16:9** — `videoWidth/Height` always passed as `0`.

(Screen-share suppression on Android is also unhonored, but is explicitly out of scope here.)

---

## Design

### 1. Widget swap — `LiveKitPipScaffold` (Dart, in `livekit_pip`)

A new widget the consumer wraps their call content in:

```dart
LiveKitPipScaffold(
  pip: _pip,                        // the LiveKitPip instance (holds room + config)
  builder: (context) => MyCallUI(), // normal full-screen call UI
)
```

Behavior:
- Listens to `pip.stateStream`.
- When state is `entering` or `active`, renders `config.android.pipWidgetBuilder(context, room)` (the compact PiP view).
- Otherwise renders `builder`.
- **Android only.** On iOS it always renders `builder` (iOS PiP is rendered natively via `LiveKitPipView`), so the same consumer code is cross-platform.

Data source: the scaffold reads `room` and `android.pipWidgetBuilder` from the passed `LiveKitPip` instance — no duplicated config. This requires `LiveKitPip` to expose its `Room` and `LiveKitPipConfiguration` (or just the needed pieces) to the scaffold; expose them via internal/package-visible getters to keep the public surface minimal.

Boundary: `LiveKitPipScaffold` does one thing — choose which subtree to render based on PiP state. It depends only on `LiveKitPip` (for state + config). It can be unit-tested by driving a fake state stream.

### 2. Activity wiring + manifest

- `LiveKitPipActivity : FlutterActivity` overrides `onUserLeaveHint()` and forwards to the plugin's enter path (for API 26–30). On API 31+ this is a no-op because the system auto-enters via `setAutoEnterEnabled(true)`.
- **Remove** the `onActivityPaused` enter hack in `PipHelper.attach`; replace the legacy trigger with `onUserLeaveHint`. Keep the `onPictureInPictureModeChanged` → state-emit logic and the API 31+ `setAutoEnterEnabled` refresh in `onResume`.
- Mechanism for `onUserLeaveHint` to reach `PipHelper`: the plugin exposes a way for the Activity to call into the active `PipHelper` (e.g. a static/registry hook on the plugin, or `LiveKitPipActivity` looks up the plugin via the engine). Chosen mechanism to be finalized in the plan; constraint: must not leak the Activity and must no-op cleanly if PiP is disabled or not initialized.
- Consumer setup, documented in README:
  - `class MainActivity : LiveKitPipActivity()` — **or**, if they already have a base class, override `onUserLeaveHint` and call the same one-line helper.
  - Manifest on the call Activity:
    ```xml
    android:supportsPictureInPicture="true"
    android:configChanges="...|screenSize|smallestScreenSize|screenLayout|orientation"
    ```

### 3. Dynamic aspect ratio

- Add to the pigeon Host API: `void updateAspectRatio(int width, int height)`. Regenerate bindings (`dart run pigeon`); never hand-edit `*.g.dart` / `Messages.g.kt`.
- `ActiveSpeakerSelector`: when the dominant track changes, read `publication.dimensions` (`VideoDimensions(width, height)` from livekit_client 2.6.1). If present, call `updateAspectRatio(width, height)` through the platform interface. Seed once on `initialize` from the current best track, mirroring the existing `updateActiveTrack` seeding.
  - Limitation (acceptable for MVP): livekit 2.6.1 exposes no per-frame/resolution-change event, so the ratio updates on **active-speaker change**, not on every resolution change mid-track.
- `PipHelper`: store the latest `width/height`; `buildParams()` computes `Rational(width, height)` **clamped to Android's allowed range** (max ≈ 2.39:1, min ≈ 1:2.39, i.e. numerator/denominator ratio in `[0.4185, 2.39]`). Clamp prevents `setAspectRatio`/`enterPictureInPictureMode` from throwing `IllegalArgumentException`.
- On API 31+, call `setPictureInPictureParams(...)` when the ratio changes so the window updates even while already in PiP.

### 4. Example app

- `MainActivity` → `class MainActivity : LiveKitPipActivity()`.
- Add the manifest attributes to the example's call Activity.
- Wrap the call page body in `LiveKitPipScaffold`, providing a simple `pipWidgetBuilder` that renders the dominant speaker via `VideoTrackRenderer` (no controls/labels).

### 5. iOS regression guard

`LiveKitPipScaffold` must be a transparent pass-through on iOS (always renders `builder`). The existing iOS `LiveKitPipView` and native PiP are unchanged. Confirm the example still drives iOS PiP after wrapping in the scaffold.

---

## Testing

- **Dart unit tests:**
  - `LiveKitPipScaffold` renders `builder` when inactive and `pipWidgetBuilder` when `entering`/`active`, driven by a fake/mock state stream. On iOS-platform override, always renders `builder`.
  - `ActiveSpeakerSelector` invokes `updateAspectRatio` with the dominant track's dimensions on track change, and seeds on initialize.
- **Clamp unit test:** aspect-ratio clamp function (pure function) — below-min, above-max, and in-range inputs.
- **Manual device tests (PiP can't be fully automated):**
  - API 31+ device: home button auto-enters PiP; window shows the PiP widget; ratio matches the dominant video; returning restores full UI.
  - API 26–30 device/emulator: home button (`onUserLeaveHint`) enters PiP; dialogs/permission prompts do **not** falsely enter PiP.
  - `enterPiP()`/`exitPiP()` manual calls work.

---

## Out of scope (deferred)

- `sourceRectHint` for a smooth enter transition.
- Screen-share suppression on Android (`disableWhenScreenSharing` honored natively).
- Remote-action buttons in the PiP window.
- Per-frame resolution-driven aspect updates.
- Multi-tile composition (trivial on Android via the widget, but deferred to keep the MVP focused).

---

## Risks

1. **`onUserLeaveHint` → `PipHelper` wiring** must avoid Activity leaks and no-op when uninitialized/disabled. Finalize the lookup mechanism in the plan.
2. **Aspect-ratio clamp** must match Android's actual accepted range across OEMs; clamp conservatively and catch/log if `setPictureInPictureParams` still throws.
3. **`LiveKitPip` exposing room/config** to the scaffold — keep additions package-private where possible to avoid widening the public API unintentionally.
