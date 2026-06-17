---

description: "Task list for livekit_pip plugin implementation"
---

# Tasks: livekit_pip Plugin — Native PiP for LiveKit Flutter Apps

**Input**: Design documents from `specs/001-livekit-pip-plugin/`

**Prerequisites**: plan.md ✅ | spec.md ✅ | research.md ✅ | data-model.md ✅ | contracts/ ✅

**Constitution gate (Principle II)**: All implementation tasks follow Red-Green-Refactor.
Test tasks marked below MUST be written and confirmed failing BEFORE the implementation
tasks they cover. Device-only iOS PiP behavior tests are marked `@Skip`.

**Organization**: Tasks are grouped by user story to enable independent implementation
and testing.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Exact file paths are in each description

## Path Conventions

Based on plan.md — 4-package federated Flutter plugin at repo root:
- Dart shared: `livekit_pip/lib/src/`
- Platform interface: `livekit_pip_platform_interface/lib/src/`
- Android native: `livekit_pip_android/android/src/main/kotlin/dev/kaffah/`
- iOS native: `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/`
- Pigeon source of truth: `livekit_pip_{android,ios}/pigeons/messages.dart`
- Tests: `<package>/test/`
- Example: `livekit_pip/example/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify scaffolding, fix known defects, align dependencies across packages.

- [X] T001 Verify `pubspec.yaml` in all 4 packages has correct `dartPluginClass` wiring and package names match federated plugin convention (`livekit_pip`, `livekit_pip_platform_interface`, `livekit_pip_android`, `livekit_pip_ios`)
- [X] T002 [P] Add `livekit_client: ^2.8.0` (or latest) to dependencies in `livekit_pip/pubspec.yaml`
- [X] T003 [P] Add `pigeon` as a `dev_dependency` in `livekit_pip_android/pubspec.yaml` and `livekit_pip_ios/pubspec.yaml`
- [X] T004 [P] Sync `very_good_analysis` to the same version in all 4 `analysis_options.yaml` files and confirm `include: package:very_good_analysis/analysis_options.yaml` is present in each
- [X] T005 Fix `Package.swift` iOS deployment target: change `.iOS(.v13)` to `.iOS(.v16)` in `livekit_pip_ios/ios/livekit_pip_ios/Package.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Dart contracts, Pigeon bridge, and skeleton classes that all user
stories depend on. No user story work begins until this phase is complete.

**⚠️ CRITICAL**: All Phase 3+ tasks block on Phase 2 completion.

- [X] T006 Create `PipState` enum (values: `unsupported`, `inactive`, `entering`, `active`, `exiting`) with `///` doc comment on each value in `livekit_pip/lib/src/pip_state.dart`
- [X] T007 [P] Create `LiveKitPipConfiguration`, `AndroidPipConfiguration`, and `IosPipConfiguration` immutable classes with all fields and defaults from `specs/001-livekit-pip-plugin/contracts/dart-api.md` in `livekit_pip/lib/src/pip_configuration.dart`
- [X] T008 Create abstract `LivekitPipPlatform` with method stubs for `isSupported`, `initialize`, `enterPip`, `exitPip`, `dispose`, `updateActiveTrack`, and `stateStream` getter in `livekit_pip_platform_interface/lib/src/livekit_pip_platform.dart`
- [X] T009 Create `MethodChannelLivekitPip` stub extending `LivekitPipPlatform` (all methods throw `UnimplementedError` initially) in `livekit_pip_platform_interface/lib/src/method_channel_livekit_pip.dart`
- [X] T010 Write Pigeon schema (`PipInitRequest`, `LiveKitPipHostApi`) in `livekit_pip_android/pigeons/messages.dart` exactly per `specs/001-livekit-pip-plugin/contracts/native-bridge.md`
- [X] T011 [P] Write Pigeon schema (`PipInitRequest`, `LiveKitPipHostApi`) in `livekit_pip_ios/pigeons/messages.dart` exactly per `specs/001-livekit-pip-plugin/contracts/native-bridge.md`
- [X] T012 Regenerate Android Pigeon bindings: run `dart run pigeon --input pigeons/messages.dart` from `livekit_pip_android/`; confirm `Messages.g.kt` is updated and not hand-edited
- [X] T013 Regenerate iOS Pigeon bindings: run `dart run pigeon --input pigeons/messages.dart` from `livekit_pip_ios/`; confirm `Messages.g.swift` is updated and not hand-edited
- [X] T014 [P] Create `LiveKitPip` class skeleton with all public methods from `specs/001-livekit-pip-plugin/contracts/dart-api.md` (stub bodies throw `UnimplementedError`; add `_disposed` bool and `_stateController` StreamController) in `livekit_pip/lib/src/livekit_pip.dart`
- [X] T015 [P] Create `LiveKitPipView` widget skeleton (returns `SizedBox.shrink()` for now; `///` doc comment explaining iOS vs Android behavior) in `livekit_pip/lib/src/livekit_pip_view.dart`
- [X] T016 Register `LiveKitPipHostApi` (Pigeon) and EventChannel `livekit_pip/state` (with inline comment "EventChannel: Pigeon does not model push streams") in `livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipPlugin.kt`
- [X] T017 Register `LiveKitPipHostApi` (Pigeon) and EventChannel `livekit_pip/state` (with inline comment "EventChannel: Pigeon does not model push streams") in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/LiveKitPipPlugin.swift`
- [X] T018 Register `livekit_pip_view` platform view factory in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/LiveKitPipPlugin.swift` (returns `PipPlatformView`)
- [X] T019 Write unit tests for `PipState` transition invariants (all valid transitions from data-model.md, unsupported is terminal, entering always followed by active, exiting always followed by inactive) in `livekit_pip/test/pip_state_test.dart` — these MUST fail before T020
- [X] T020 Implement `stateStream` `StreamController<PipState>` wiring in `LiveKitPip` — subscribe to EventChannel `livekit_pip/state`, parse int payload to `PipState`, emit to broadcast stream; update `_state` field on each event in `livekit_pip/lib/src/livekit_pip.dart`

**Checkpoint**: Foundation ready — platform interface, Pigeon bindings, channel registration, and state machine skeleton exist. User story phases can now begin in parallel.

---

## Phase 3: User Story 1 — PiP on Background (Priority: P1) 🎯 MVP

**Goal**: Any LiveKit Flutter app can show a floating PiP window automatically when
the user presses the home button. Android shows a developer-supplied Flutter widget;
iOS shows the active speaker's video feed.

**Independent Test**: Run example app on Android device + iOS physical device. Join a
call, press home, confirm PiP window appears within 500 ms. See quickstart.md §1.

### Dart Layer — US1

- [X] T021 [P] [US1] Implement `LiveKitPip.isSupported()` — delegate to `MethodChannelLivekitPip.isSupported()` which calls `LiveKitPipHostApi.isSupported()` via generated Pigeon stub in `livekit_pip/lib/src/livekit_pip.dart` and `livekit_pip_platform_interface/lib/src/method_channel_livekit_pip.dart`
- [X] T022 [US1] Implement `LiveKitPip.initialize()` — assert `!_disposed`, call `isSupported()`, store Room + config, call native `initialize(PipInitRequest)` with config fields and initial video dimensions, subscribe to Room events in `livekit_pip/lib/src/livekit_pip.dart`
- [X] T023 [US1] Implement `LiveKitPip.enterPiP()` and `exitPiP()` — guard: throw `StateError` if not initialized or disposed; throw `UnsupportedError` if unsupported; delegate to `MethodChannelLivekitPip` in `livekit_pip/lib/src/livekit_pip.dart`
- [X] T024 [US1] Implement `LiveKitPip.dispose()` — cancel all Room subscriptions, call native `dispose()`, close `_stateController` with done event, set `_disposed = true`; idempotent in `livekit_pip/lib/src/livekit_pip.dart`
- [X] T025 [P] [US1] Implement `LiveKitPipView` — return `UiKitView(viewType: 'livekit_pip_view', ...)` on iOS via `defaultTargetPlatform` check; return `SizedBox.shrink()` on Android in `livekit_pip/lib/src/livekit_pip_view.dart`
- [X] T026 [US1] Implement Android widget swap: on EventChannel `active` state, rebuild widget tree with `pipWidgetBuilder(context, room)`; on `inactive`, restore original content; implement via callback registered in `initialize()` in `livekit_pip/lib/src/livekit_pip.dart`
- [X] T027 [US1] Write unit tests for `LiveKitPip` lifecycle: initialize → enter → active → exit → inactive → dispose; mock `MethodChannelLivekitPip` and EventChannel with `mocktail` in `livekit_pip/test/livekit_pip_test.dart`

### Android Native — US1

- [X] T028 [P] [US1] Implement `PipHostApiImpl.isSupported()` — return `Build.VERSION.SDK_INT >= Build.VERSION_CODES.O` in `livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipPlugin.kt`
- [X] T029 [P] [US1] Implement `PipHostApiImpl.initialize()` — store `PipInitRequest` fields (aspect ratio from `videoWidth`/`videoHeight`, fall back to 16:9 if 0); store `autoEnterOnBackground` flag in `livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipPlugin.kt`
- [X] T030 [US1] Implement `PipHelper.buildParams()` — `PictureInPictureParams.Builder` with `setAspectRatio(Rational(w, h))` and `setSourceRectHint(view.globalVisibleRect)` in `livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipHelper.kt`
- [X] T031 [US1] Implement API 31+ auto-enter path in `PipHelper.attach()` — call `activity.setPictureInPictureParams(params.setAutoEnterEnabled(true))` in `onResume`; check `SDK_INT >= 31` in `livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipHelper.kt`
- [X] T032 [US1] Implement API 26–30 manual enter path in `PipHelper` — override `onUserLeaveHint()` to call `activity.enterPictureInPictureMode(params)` when `autoEnterOnBackground = true` and `SDK_INT < 31` in `livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipHelper.kt`
- [X] T033 [US1] Implement `PipHostApiImpl.enterPip()` and `exitPip()` — call `activity.enterPictureInPictureMode(params)` / `activity.moveTaskToBack(false)` in `livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipPlugin.kt`
- [X] T034 [US1] Forward `onPictureInPictureModeChanged` to EventChannel `livekit_pip/state` — emit `2` (entering) then `3` (active) on enter; emit `4` (exiting) then `1` (inactive) on exit in `livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipPlugin.kt`
- [X] T035 [US1] Implement `LiveKitPipActivity` convenience class — extends `FlutterActivity`; overrides `onUserLeaveHint` and `onPictureInPictureModeChanged`; delegates to `PipHelper` in `livekit_pip_android/android/src/main/kotlin/dev/kaffah/LiveKitPipActivity.kt`

### iOS Native — US1

- [X] T036 [P] [US1] Implement `NativeTrackResolver.swift` — define `NativeTrackResolver` protocol with `resolveVideoTrack(trackId: String) -> RTCVideoTrack?`; implement `FlutterWebRTCTrackResolver` conformance that looks up `FlutterWebRTCPlugin.sharedPlugin`'s track registry; add runtime guard returning `nil` (not crashing) if plugin is nil or track not found in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/NativeTrackResolver.swift`
- [X] T037 [P] [US1] Implement `PlaybackDelegate.swift` — conform to `AVPictureInPictureSampleBufferPlaybackDelegate`; return `CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)` from `pictureInPictureControllerTimeRangeForPlayback`; `isPlaybackPaused` returns `false`; all seek/rate methods are no-ops in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/PlaybackDelegate.swift`
- [X] T038 [P] [US1] Implement `PipPlatformView.swift` — `UIView` subclass containing `AVSampleBufferDisplayLayer` as sublayer; create `AVPictureInPictureController(contentSource: .init(sampleBufferDisplayLayer: layer, playbackDelegate: delegate))` once; expose `startPictureInPicture()` / `stopPictureInPicture()` in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/PipPlatformView.swift`
- [X] T039 [US1] Implement `FrameBridge.swift` — resolve `RTCVideoTrack` via `NativeTrackResolver`; attach `RTCVideoRenderer`; on each `didCapture(frame:)`: extract `CVPixelBuffer` from `RTCCVPixelBuffer` (or convert `RTCI420Buffer` to `32BGRA` via `vImageConvert`); wrap in `CMSampleBuffer`; call `displayLayer.enqueue(sampleBuffer)` in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/FrameBridge.swift`
- [X] T040 [US1] Allocate `CVPixelBufferPool` in `FrameBridge.swift` on first frame (pixel format `kCVPixelFormatType_32BGRA`, dimensions matching first frame); reuse pool for all subsequent frames; never reallocate per-frame in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/FrameBridge.swift`
- [X] T041 [US1] Implement `PipHostApiImpl.isSupported()` on iOS — return `AVPictureInPictureController.isPictureInPictureSupported()` in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/LiveKitPipPlugin.swift`
- [X] T042 [US1] Implement `PipHostApiImpl.initialize()` on iOS — store config flags; wire `FrameBridge` to `PipPlatformView`'s display layer; register `UIApplication.didEnterBackgroundNotification` observer when `autoEnterOnBackground = true` in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/LiveKitPipPlugin.swift`
- [X] T043 [US1] Implement `PipHostApiImpl.enterPip()` / `exitPip()` on iOS — call `PipPlatformView.startPictureInPicture()` / `stopPictureInPicture()` in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/LiveKitPipPlugin.swift`
- [X] T044 [US1] Forward `AVPictureInPictureControllerDelegate` callbacks to EventChannel `livekit_pip/state` — `willStartPictureInPicture` → emit `2` (entering); `didStartPictureInPicture` → emit `3` (active); `willStopPictureInPicture` → emit `4` (exiting); `didStopPictureInPicture` → emit `1` (inactive) in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/PipPlatformView.swift`

### Example App & Integration — US1

- [ ] T045 [US1] Build example app call page: connect to LiveKit sandbox, place `LiveKitPipView(room: room)` in stack, initialize `LiveKitPip`, display `stateStream` value as text label, add "Enter PiP" / "Exit PiP" buttons in `livekit_pip/example/lib/main.dart`
- [ ] T046 [US1] Add Fluttium integration flow `livekit_pip/example/flows/test_pip_enter.yaml` covering quickstart.md scenarios 1a (auto-enter), 1b (return to full screen), 1c (close PiP)

**Checkpoint**: User Story 1 fully functional — run `flutter test` in all packages and `fluttium test flows/test_pip_enter.yaml` on device.

---

## Phase 4: User Story 2 — Active Speaker Tracking & Self-View Inset on iOS (Priority: P2)

**Goal**: On iOS, the PiP window automatically follows the dominant speaker and shows
a self-view inset when `includeLocalParticipantVideo` is enabled.

**Independent Test**: 3+ participant call on iOS device; confirm speaker switch ≤1s;
confirm self-view inset appears/disappears per config. See quickstart.md §2.

- [ ] T047 [P] [US2] Write unit tests for `ActiveSpeakerSelector` covering: empty room (no crash), all participants muted (holds last speaker), rapid speaker churn (debounces), local camera off (hides self-view) in `livekit_pip/test/active_speaker_selector_test.dart` — MUST fail before T048
- [ ] T048 [US2] Implement `ActiveSpeakerSelector` — subscribe to `room.events` stream; on `RoomEvent.activeSpeakersChanged`: pick first remote participant with non-muted video track; fall back to last known per research.md §5; call `onTrackChanged(trackId)` callback on change in `livekit_pip/lib/src/active_speaker_selector.dart`
- [ ] T049 [US2] Subscribe to local `TrackMuted` / `TrackUnmuted` events in `ActiveSpeakerSelector` to track local camera state; expose `isLocalCameraActive` bool for compositor in `livekit_pip/lib/src/active_speaker_selector.dart`
- [ ] T050 [US2] Wire `ActiveSpeakerSelector` into `LiveKitPip.initialize()` — create selector with `room`; on `onTrackChanged`, call `MethodChannelLivekitPip.updateActiveTrack(trackId)` in `livekit_pip/lib/src/livekit_pip.dart`
- [ ] T051 [US2] Implement `PipHostApiImpl.updateActiveTrack()` on iOS — forward `trackId` to `FrameBridge.rebindTrack(trackId:)` in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/LiveKitPipPlugin.swift`
- [ ] T052 [US2] Implement `FrameBridge.rebindTrack(trackId:)` — detach current `RTCVideoRenderer` from old track; resolve new track via `NativeTrackResolver`; attach renderer to new track; do NOT recreate `AVSampleBufferDisplayLayer` or `AVPictureInPictureController` in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/FrameBridge.swift`
- [ ] T053 [P] [US2] Implement `PixelBufferCompositor.swift` — accepts two `CVPixelBuffer` inputs (dominant + self-view); uses `CIContext(mtlDevice: MTLCreateSystemDefaultDevice())` + `CIFilter` compositing; scales self-view to 20% of frame width; positions bottom-right at 8pt margin; outputs single `CVPixelBuffer` from pool in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/PixelBufferCompositor.swift`
- [ ] T054 [US2] Integrate `PixelBufferCompositor` into `FrameBridge.swift` — when `includeLocalParticipantVideo = true` and local camera active: resolve local track via `NativeTrackResolver`, composite both buffers before `CMSampleBuffer` creation; when local camera off or flag false: pass dominant buffer directly
- [ ] T055 [US2] Implement `PipHostApiImpl.updateActiveTrack()` on Android — no-op with inline comment "Android: widget builder handles track selection in Dart" in `livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipPlugin.kt`
- [ ] T056 [US2] Add Fluttium flow `livekit_pip/example/flows/test_speaker_switch.yaml` covering quickstart.md scenarios 2a (speaker switch), 2b (self-view on), 2c (self-view off)

**Checkpoint**: User Stories 1 AND 2 independently functional on iOS physical device.

---

## Phase 5: User Story 3 — Hardening, Edge Cases & DX (Priority: P3)

**Goal**: Plugin is production-safe: unsupported devices return clear errors, screen
sharing suppresses PiP, call-end during PiP cleans up, dispose() leaves no leaks.

**Independent Test**: Each edge case scenario from quickstart.md §3 on physical device.

- [ ] T057 [P] [US3] Write unit tests for error contract edge cases: `enterPiP()` before `initialize()`, any method after `dispose()`, `enterPiP()` on unsupported device — mock `isSupported()` = false in `livekit_pip/test/livekit_pip_test.dart` — MUST fail before T058
- [ ] T058 [US3] Implement `StateError` and `UnsupportedError` guards in `LiveKitPip` — add `_assertInitialized()` (throws `StateError("LiveKitPip.X called before initialize()")`) and `_assertNotDisposed()` (throws `StateError("LiveKitPip.X called after dispose()")`) helpers; call from all public methods in `livekit_pip/lib/src/livekit_pip.dart`
- [ ] T059 [US3] Implement screen-sharing suppression — subscribe to local participant's screen-share track events in `ActiveSpeakerSelector`; expose `isScreenSharing` bool; in `LiveKitPip`: when `disableWhenScreenSharing = true` and `isScreenSharing = true`, block auto-enter by returning early from the background notification handler in `livekit_pip/lib/src/active_speaker_selector.dart` and `livekit_pip/lib/src/livekit_pip.dart`
- [ ] T060 [US3] Implement Room disconnect auto-exit — subscribe to `RoomEvent.disconnected` in `LiveKitPip.initialize()`; on disconnect, call `exitPiP()` (if active), emit `exiting` → `inactive`, cancel `ActiveSpeakerSelector` in `livekit_pip/lib/src/livekit_pip.dart`
- [ ] T061 [US3] Implement full `LiveKitPip.dispose()` — cancel `ActiveSpeakerSelector` subscriptions, cancel Room event subscriptions, call native `LiveKitPipHostApi.dispose()`, add done event to `stateStream`, set `_disposed = true`, null out Room ref; idempotent (second call is a no-op) in `livekit_pip/lib/src/livekit_pip.dart`
- [ ] T062 [US3] Implement `PipHostApiImpl.dispose()` on Android — stop PiP if active, unregister all `ActivityLifecycleCallbacks`, clear EventChannel stream handler in `livekit_pip_android/android/src/main/kotlin/dev/kaffah/PipPlugin.kt`
- [ ] T063 [US3] Implement `PipHostApiImpl.dispose()` on iOS — call `stopPictureInPicture()` if active, detach `RTCVideoRenderer` in `FrameBridge`, release `CVPixelBufferPool`, remove `UIApplication` notification observers, nil out delegate refs in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/LiveKitPipPlugin.swift` and `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/FrameBridge.swift`
- [ ] T064 [US3] Handle all-remote-tracks-gone on iOS — when `ActiveSpeakerSelector.onTrackChanged` is called with `null` (no video tracks), `FrameBridge` holds the last-displayed frame rather than blanking or crashing; implement `FrameBridge.holdLastFrame()` path in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/FrameBridge.swift`
- [ ] T065 [US3] Handle `AVPictureInPictureControllerDelegate.pictureInPictureController(_:failedToStartPictureInPictureWithError:)` — log error, emit `1` (inactive) to EventChannel; do not crash in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/PipPlatformView.swift`
- [ ] T066 [US3] Update example app — add "Dispose" button that calls `pip.dispose()`, a screen-share toggle stub, and `isSupported()` result label in `livekit_pip/example/lib/main.dart`
- [ ] T067 [US3] Add Fluttium flow `livekit_pip/example/flows/test_edge_cases.yaml` covering quickstart.md scenarios 3a (unsupported), 3b (screen-share suppression), 3c (call-end cleanup), 3d (post-dispose error), 3e (intermediate state events)

**Checkpoint**: All three user stories independently functional. Run full quickstart.md validation.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Quality gates, documentation, and final validation.

- [ ] T068 [P] Add `///` doc comments to all public Dart symbols in `livekit_pip/lib/src/*.dart` and `livekit_pip_platform_interface/lib/src/*.dart` per constitution Principle I
- [ ] T069 [P] Run `flutter analyze` from each of the 4 package roots and fix all warnings to zero; no `// ignore:` without inline explanation in `livekit_pip/`, `livekit_pip_platform_interface/`, `livekit_pip_android/`, `livekit_pip_ios/`
- [ ] T070 [P] Verify `LiveKitPipConfiguration` minimum integration is ≤20 lines — count lines in `specs/001-livekit-pip-plugin/contracts/dart-api.md` "Minimum Integration" example against a fresh example app page; adjust API if count exceeds 20 (SC-001)
- [ ] T071 Run `flutter test` in all 4 packages (from their respective roots) and confirm zero failures
- [ ] T072 Run `fluttium test flows/test_pip_enter.yaml -d <device>`, `flows/test_speaker_switch.yaml -d <device>`, `flows/test_edge_cases.yaml -d <device>` from `livekit_pip/example/` on a physical iOS device and Android device
- [ ] T073 Manual validation of all quickstart.md scenarios on both Android device and iOS physical device; document results inline in `specs/001-livekit-pip-plugin/quickstart.md` under each scenario

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user story phases
- **US1 (Phase 3)**: Depends on Phase 2 completion
- **US2 (Phase 4)**: Depends on Phase 3 completion (needs `FrameBridge` from US1)
- **US3 (Phase 5)**: Can begin after Phase 3; fully independent from Phase 4 on Dart layer
- **Polish (Phase 6)**: Depends on all story phases complete

### User Story Dependencies

- **US1 (P1)**: Foundational complete → can start. No dependency on US2/US3.
- **US2 (P2)**: Requires `FrameBridge` (T039) and `NativeTrackResolver` (T036) from US1.
- **US3 (P3)**: Dart-layer tasks (T057–T061, T059) can start after Phase 2. Native
  dispose tasks (T062–T063) require native init from US1.

### Within Each User Story

- Test tasks (T027, T047, T057) MUST be written first and confirmed failing (Red)
- Platform interface before native implementation
- `FrameBridge` (T039) before `rebindTrack` (T052)
- `PixelBufferCompositor` (T053) before integration (T054) — can build in parallel with T039–T052

### Parallel Opportunities

All tasks marked `[P]` can run concurrently with other `[P]` tasks in the same phase:
- T002, T003, T004 (pubspec updates) — parallel
- T010, T011 (Pigeon schemas for Android + iOS) — parallel
- T021, T025 (isSupported + LiveKitPipView) — parallel
- T028, T029, T036, T037, T038 (Android + iOS native stubs) — parallel across platforms
- T047, T053 (ActiveSpeakerSelector tests + PixelBufferCompositor) — parallel
- T068, T069, T070 (docs + analyze + line count) — parallel

---

## Parallel Example: User Story 1

```bash
# Phase 3 can fan out across Dart and native immediately:

# Dart layer (no native deps):
Task: T021 isSupported() in livekit_pip.dart
Task: T025 LiveKitPipView platform branching in livekit_pip_view.dart

# Android native (independent of iOS):
Task: T028 PipHostApiImpl.isSupported() in PipPlugin.kt
Task: T029 PipHostApiImpl.initialize() in PipPlugin.kt
Task: T035 LiveKitPipActivity.kt

# iOS native (independent of Android):
Task: T036 NativeTrackResolver.swift
Task: T037 PlaybackDelegate.swift
Task: T038 PipPlatformView.swift

# Then sequential within each platform:
T030 → T031 → T032 → T033 (Android PipHelper chain)
T039 → T040 → T041 → T042 → T043 → T044 (iOS FrameBridge chain)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Run quickstart.md §1 on Android + iOS device
5. Ship Phase 1 build

### Incremental Delivery

1. Setup + Foundational → scaffold ready
2. US1 → Android full PiP + iOS dominant speaker → Phase 1 build
3. US2 → iOS self-view inset + speaker switching → Phase 2 build
4. US3 → hardening + DX → Phase 3 build (production-ready)

### Parallel Team Strategy (if multiple developers)

After Foundational (Phase 2):
- Developer A: US1 Dart layer (T021–T027) + example app
- Developer B: US1 Android native (T028–T035)
- Developer C: US1 iOS native (T036–T044)
All three merge into Phase 3 checkpoint before Phase 4 begins.

---

## Notes

- `[P]` = parallelizable (different files, no incomplete task dependencies)
- `[US1/2/3]` maps task to its user story for traceability
- Tests marked above MUST fail before their paired implementation tasks
- iOS PiP tests touching `AVPictureInPictureController` / `AVSampleBufferDisplayLayer`
  are device-only; mark with `@Skip('requires physical device')` and comment the reason
- Never hand-edit `*.g.dart`, `Messages.g.kt`, `Messages.g.swift` — always regenerate
- Commit after each checkpoint (end of each phase) with a `feat:` commit message
- `flutter analyze` MUST be clean at every checkpoint
