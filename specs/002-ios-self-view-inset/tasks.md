---

description: "Task list for the iOS PiP split view (revision 2)"
---

# Tasks: iOS PiP Split View with Self-View and Avatars

**Input**: Design documents from `specs/002-ios-self-view-inset/`

**Tests**: Required by the constitution (Principle II). Dart first; iOS on device.

Revision 1 tasks (T001–T024) shipped the corner inset on this branch, uncommitted.
Revision 2 replaces that design; constitution and CLAUDE.md edits from revision 1 are
kept and updated in T101.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [X] T101 Update CLAUDE.md architecture and API sketch for tiles, avatars, multitasking camera in CLAUDE.md

## Phase 2: Foundational (bridge contract)

- [X] T102 [P] Write failing tests for `PipParticipantInfo` equality and default no-op `updateParticipants` in livekit_pip_platform_interface/test/livekit_pip_platform_interface_test.dart
- [X] T103 Add `PipParticipantInfo`, `updateParticipants`; remove `updateLocalTrack` and the corner/width params in livekit_pip_platform_interface/lib/src/
- [X] T104 [P] Remove corner/width fields in livekit_pip_android/pigeons/messages.dart; regenerate; update livekit_pip_android/lib/livekit_pip_android.dart and its test
- [X] T105 [P] Add `PipParticipant` + `updateParticipants`, remove `updateLocalTrack` and corner/width in livekit_pip_ios/pigeons/messages.dart; regenerate
- [X] T106 Write failing tests, then map `PipParticipantInfo` → `PipParticipant` in livekit_pip_ios/test/livekit_pip_ios_test.dart and livekit_pip_ios/lib/livekit_pip_ios.dart

## Phase 3: US1 + US2 + US4 — tiles, avatars, muted badge (P1)

- [X] T107 [P] [US2] Write failing config tests (avatarUrlResolver default, corner/width gone) in livekit_pip/test/pip_configuration_test.dart
- [X] T108 [US2] Add `PipAvatarUrlResolver` / `avatarUrlResolver`, remove `PipSelfViewCorner` and width in livekit_pip/lib/src/pip_configuration.dart
- [X] T109 [P] [US1] Write failing tracker tests (remote choice, agent skip, camera off → null track, mic mute, avatar re-read, local on/off, dedupe) in livekit_pip/test/pip_participant_tracker_test.dart
- [X] T110 [US1] Implement `PipParticipantTracker` in livekit_pip/lib/src/pip_participant_tracker.dart
- [X] T111 [US1] Remove revision-1 local tracking from livekit_pip/lib/src/active_speaker_selector.dart and its tests
- [X] T112 [P] [US1] Write failing controller tests (sends tiles at init and on change, local only when enabled, stops after dispose) in livekit_pip/test/livekit_pip_test.dart
- [X] T113 [US1] Wire the tracker in livekit_pip/lib/src/livekit_pip.dart
- [X] T114 [US1] Implement ordering and sizing in livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/PipTileLayout.swift
- [X] T115 [US2] Implement avatar fetch and cache in livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/AvatarImageLoader.swift
- [X] T116 [US2] [US4] Implement video / avatar / initials / muted badge tile in livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/PipTileView.swift
- [X] T117 [US1] Host both tiles, apply layout, drive `preferredContentSize` in livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/PipPlatformView.swift; delete SelfViewInset.swift
- [X] T118 [US1] Route `updateParticipants` with pending state; make iOS `updateActiveTrack` a no-op in livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/LiveKitPipPlugin.swift

## Phase 4: US3 — local camera keeps running (P1)

- [X] T119 [US3] Add `cameraCaptureSession()` in livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/NativeTrackResolver.swift
- [X] T120 [US3] Request multitasking camera when the local tile binds a track; local tile follows capture interruptions, in PipPlatformView.swift and PipTileView.swift

## Phase 5: Polish

- [X] T121 [P] Update README.md (split view, avatars, multitasking requirements)
- [X] T122 Run `flutter analyze` and `flutter test` in all four packages
- [X] T123 Build livekit_pip/example for iOS (`flutter build ios --no-codesign`); needs `pod install` after removing SelfViewInset.swift
- [ ] T124 Device check per quickstart.md (manual)

## Dependencies

Phase 2 before 3–4. T108 before T110. T114–T116 before T117. T117 before T118–T120.
