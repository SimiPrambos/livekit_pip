# Implementation Plan: iOS PiP Split View with Self-View and Avatars

**Branch**: `002-ios-self-view-inset` | **Date**: 2026-10-05 (revision 2) | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-ios-self-view-inset/spec.md`

## Summary

Replace the single remote video (and revision 1's corner inset) in the iOS PiP window
with up to two side-by-side tiles, ordered and sized by their video shapes. Dart
builds a tile list (`PipParticipantTracker`) holding each person's video track,
mute state, name, and app-supplied avatar URL, and sends it with a new
`updateParticipants` Pigeon call. iOS shows video, or the avatar/initials when the
camera is off or interrupted, plus a muted badge. When the self-view is on, iOS asks
flutter_webrtc's capture session for multitasking camera access, which is why the
local video never appeared in revision 1.

## Technical Context

**Language/Version**: Dart 3.11 (Flutter 3.44.9), Swift 5

**Primary Dependencies**: `livekit_client` (>=2.11.0 <3.0.0), flutter_webrtc 1.6.x
(transitive), Pigeon 27 (dev), AVKit, AVFoundation, UIKit

**Storage**: In-memory image cache (`NSCache`) only

**Testing**: `flutter test` + `mocktail`; iOS layout and PiP verified on device

**Target Platform**: iOS 16+ (restored from 15 in constitution 1.0.2); Android unchanged

**Project Type**: Flutter federated plugin

**Performance Goals**: No compositing; each tile renders through its own layer

**Constraints**: PiP controller never recreated; `NativeTrackResolver` stays the only
file using flutter_webrtc internals; avatar URLs never logged

**Scale/Scope**: 4 packages; Dart tracker + tests; 3 new Swift files

## Constitution Check

| Principle | Gate | Status |
|-----------|------|--------|
| I. Code Quality | Analyze clean; Pigeon regenerated; `///` on public symbols | ✅ |
| II. Test-First | Tracker, config, controller, platform packages tested first; iOS manual on device | ✅ |
| III. Platform Asymmetry | Max 2 feeds; no controller recreation; resolver isolation | ⚠️ Two display-layer tiles instead of `PixelBufferCompositor` (constitution 1.0.1 allows this) |
| IV. Consumer UX | Released API unchanged; new option has a default | ✅ |
| V. Frame Pipeline | No CPU compositing; pooled transforms reused | ✅ |
| Platform Constraints | iOS 16.0 everywhere | ✅ (15.0 in revision 1, back to 16.0 in constitution 1.0.2) |

## Project Structure

```text
livekit_pip/lib/src/
├── pip_configuration.dart        # avatarUrlResolver; corner/width removed
├── pip_participant_tracker.dart  # new: builds the tile list
├── active_speaker_selector.dart  # revision-1 local tracking removed
└── livekit_pip.dart              # wires the tracker

livekit_pip_platform_interface/lib/src/
├── pip_participant_info.dart     # new
└── livekit_pip_platform.dart     # updateParticipants; updateLocalTrack removed

livekit_pip_android/pigeons/messages.dart  # drop corner/width fields
livekit_pip_ios/pigeons/messages.dart      # PipParticipant + updateParticipants

livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/
├── PipTileView.swift             # new: video / avatar / muted badge
├── PipTileLayout.swift           # new: pure ordering and sizing
├── AvatarImageLoader.swift       # new: URLSession + NSCache
├── NativeTrackResolver.swift     # + cameraCaptureSession()
├── PipPlatformView.swift         # two tiles in the video-call view controller
├── LiveKitPipPlugin.swift        # route updateParticipants; pending state
└── SelfViewInset.swift           # removed
```

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Two display-layer tiles, not `PixelBufferCompositor` | Video-call content source shows the view hierarchy | Compositing adds a per-frame GPU pass for nothing |
| Multitasking flag set on an already-running session | flutter_webrtc starts the session before PiP exists | Setting it before start requires forking flutter_webrtc |
| No automated tests for Swift layout | The package has no XCTest target and PiP is device-only | Layout kept as a pure function (`PipTileLayout`) to make review and a later XCTest target easy |
