# Implementation Plan: livekit_pip Plugin — Native PiP for LiveKit Flutter Apps

**Branch**: `001-livekit-pip-plugin` | **Date**: 2026-06-17 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-livekit-pip-plugin/spec.md`

## Summary

Build a Flutter federated plugin that adds native system Picture-in-Picture to any
LiveKit-based video call app. The consumer passes a `LiveKit Room`; the plugin owns
the entire PiP lifecycle across Android (Flutter widget in a shrunk Activity window)
and iOS (native `AVSampleBufferDisplayLayer` driven by a live WebRTC frame pipeline).

Three phased deliverables:
- **Phase 1**: Skeleton + Android full implementation + iOS dominant-speaker pipeline
- **Phase 2**: iOS self-view inset compositor + active-speaker switching
- **Phase 3**: Hardening, edge-case handling, and developer experience polish

## Technical Context

**Language/Version**: Dart 3.x (Flutter 3.x), Kotlin 1.9+ (Android), Swift 5.9+ (iOS)

**Primary Dependencies**:
- `livekit_client` — LiveKit Dart SDK (Room, Participant, Track APIs)
- `flutter_webrtc` — transitive via livekit_client; native RTCVideoTrack on iOS
- `pigeon` (dev) — typed native bridge code generation
- `very_good_analysis` (dev) — strict lint ruleset
- `mocktail` (dev) — test mocking with `MockPlatformInterfaceMixin`
- Android system: `PictureInPictureParams`, `Activity.enterPictureInPictureMode`
- iOS system: `AVPictureInPictureController`, `AVSampleBufferDisplayLayer`,
  `CVPixelBufferPool`, Core Image / Metal

**Storage**: N/A — plugin is stateless beyond the lifetime of one `LiveKitPip` instance

**Testing**:
- Dart unit tests: `flutter test` + `mocktail`
- iOS PiP behavior: device-only (simulator cannot run PiP), marked `@Skip`
- Integration: Fluttium flows on physical device (gates phase sign-off)

**Target Platform**: Android API 26+ / iOS 16+ (Flutter mobile)

**Project Type**: Flutter federated plugin (library)

**Performance Goals**:
- PiP window visible ≤ 500 ms after backgrounding
- iOS active-speaker switch ≤ 1 second
- iOS frame pipeline latency ≤ 33 ms per frame (30 fps floor)

**Constraints**:
- iOS PiP cannot be tested in the simulator
- `Package.swift` must be fixed from iOS 13.0 → 16.0 in Phase 1
- `AVSampleBufferDisplayLayer` must never be recreated mid-call
- No per-frame `CVPixelBuffer` allocation — pool required
- No N-tile grid compositor on iOS — maximum 2 feeds (dominant + self-view inset)
- Pigeon is the only approved native bridge for commands

**Scale/Scope**: 4 packages (`livekit_pip`, `livekit_pip_platform_interface`,
`livekit_pip_android`, `livekit_pip_ios`) + example app; 3 build phases

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Status |
|-----------|------|--------|
| I. Code Quality | `flutter analyze` clean; Pigeon-only bridge; public `///` docs | ✅ |
| II. Test-First | Red-Green-Refactor; device-only iOS tests marked `@Skip`; Fluttium gates phases | ✅ |
| III. Platform Asymmetry | Android = Flutter widget only; iOS = single layer max 2-feed; no layer recreate; `NativeTrackResolver` isolation | ✅ |
| IV. Consumer UX | All 5 `PipState` transitions deterministic; `isSupported()` gate; `dispose()` completes stream | ✅ |
| V. Frame Pipeline | ≤33 ms iOS frame path; Metal/Core Image compositor; `CVPixelBufferPool` | ✅ |
| Platform Constraints | Android minSdk 26; iOS 16.0; `dartPluginClass` auto-registration | ⚠️ Package.swift currently 13.0 — MUST fix in Phase 1 (known defect, documented in CLAUDE.md) |

No unresolved violations. The `Package.swift` issue is a known pre-existing defect, not a design choice.

## Project Structure

### Documentation (this feature)

```text
specs/001-livekit-pip-plugin/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── dart-api.md
│   └── native-bridge.md
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

```text
# Federated Flutter Plugin — 4 packages

livekit_pip/                              # Consumer-facing top-level package
├── lib/
│   └── src/
│       ├── livekit_pip.dart              # LiveKitPip controller
│       ├── livekit_pip_view.dart         # LiveKitPipView widget
│       ├── pip_configuration.dart        # LiveKitPipConfiguration + platform configs
│       ├── pip_state.dart                # PipState enum
│       └── active_speaker_selector.dart  # Dart-layer Room event observer
├── test/
│   ├── livekit_pip_test.dart
│   ├── active_speaker_selector_test.dart
│   └── pip_state_test.dart
└── example/
    ├── lib/main.dart                     # Demo call page
    └── flows/
        └── test_pip_enter.yaml           # Fluttium integration flow

livekit_pip_platform_interface/           # Abstract platform layer
├── lib/
│   └── src/
│       ├── livekit_pip_platform.dart     # Abstract LivekitPipPlatform
│       └── method_channel_livekit_pip.dart  # Default MethodChannel impl
└── test/

livekit_pip_android/                      # Android implementation
├── lib/
├── android/src/main/kotlin/dev/kaffah/
│   ├── PipPlugin.kt                      # FlutterPlugin + ActivityAware
│   ├── PipHelper.kt                      # PictureInPictureParams builder
│   └── LiveKitPipActivity.kt             # Optional convenience base Activity
├── pigeons/messages.dart                 # Pigeon source of truth (Android)
└── test/

livekit_pip_ios/                          # iOS implementation
├── lib/
├── ios/livekit_pip_ios/Sources/livekit_pip_ios/
│   ├── LiveKitPipPlugin.swift            # Channel registration + view factory
│   ├── PipPlatformView.swift             # UIView + AVSampleBufferDisplayLayer
│   ├── PlaybackDelegate.swift            # AVPictureInPictureSampleBufferPlaybackDelegate
│   ├── FrameBridge.swift                 # RTCVideoFrame → CVPixelBuffer → CMSampleBuffer
│   ├── PixelBufferCompositor.swift       # 2-feed Metal/Core Image compositor
│   └── NativeTrackResolver.swift        # flutter_webrtc internals isolation
├── pigeons/messages.dart                 # Pigeon source of truth (iOS)
└── test/
```

**Structure Decision**: Federated plugin with 4 separate Dart packages, matching the
Very Good CLI scaffold. Each platform package has its own `pigeons/messages.dart` as
the single source of truth for its native bridge.

## Complexity Tracking

> No constitution violations requiring justification.
> The Package.swift iOS 13.0 defect is pre-existing — fix task is in Phase 1.
