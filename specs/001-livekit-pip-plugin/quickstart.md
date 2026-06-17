# Quickstart Validation Guide: livekit_pip Plugin

**Phase 1 Output** | **Date**: 2026-06-17 | **Plan**: [plan.md](plan.md)

This guide describes how to validate each user story end-to-end after implementation.
It is a validation/run guide — not an implementation spec. Implementation details
live in `tasks.md`.

---

## Prerequisites

- Flutter SDK installed and on PATH
- Android: device or emulator running API 26+ with the example app installed
- iOS: **physical device** running iOS 16+ (simulator cannot run PiP)
- A LiveKit server URL and access token (can use livekit.io cloud sandbox)
- `fluttium_cli` installed (`dart pub global activate fluttium_cli`) for automated
  integration tests

---

## Setup: Run the Example App

```sh
# From repo root
cd livekit_pip/example

# Android (emulator or device)
flutter run -d <android-device-id>

# iOS (physical device required for PiP validation)
flutter run -d <ios-device-id>
```

The example app shows a call page that:
1. Connects to a LiveKit room using a hardcoded sandbox URL + token
2. Places `LiveKitPipView` in the widget tree
3. Initializes `LiveKitPip` with a demo `pipWidgetBuilder`
4. Shows PiP state in a status label

---

## Validate User Story 1 — PiP on Background (P1)

### 1a. Auto-enter on home press

1. Open example app, join a call with at least one remote participant
2. Confirm status label shows `inactive`
3. Press the home button
4. **Expected**: PiP window appears within 500 ms showing the call video

### 1b. Return to full screen

1. While PiP is active, tap the PiP window
2. **Expected**: App opens to full-screen call view; status label shows `inactive`

### 1c. Close PiP window

1. While PiP is active, tap the close (×) button on the PiP window
2. **Expected**: PiP window closes; audio continues; status label shows `inactive`

### 1d. Auto-enter disabled

1. In example app settings, toggle `autoEnterOnBackground` off
2. Press home button
3. **Expected**: No PiP window appears

### 1e. Automated Fluttium flow

```sh
fluttium test flows/test_pip_enter.yaml -d <device-id>
```

Expected: all steps pass with no failures.

---

## Validate User Story 2 — Active Speaker Tracking & Self-View Inset on iOS (P2)

> **iOS device required for all scenarios in this section.**

### 2a. Speaker auto-switch

1. Join a call with 3+ participants; start PiP
2. Have a second participant unmute and speak
3. **Expected**: PiP window switches to that participant's video within 1 second

### 2b. Self-view inset enabled

1. Ensure `includeLocalParticipantVideo: true` (default)
2. Start PiP
3. **Expected**: A small inset of your own camera appears in the corner of the PiP window

### 2c. Self-view inset disabled

1. Set `includeLocalParticipantVideo: false`
2. Start PiP
3. **Expected**: No self-view inset; full frame shows dominant speaker only

### 2d. Camera-off speaker

1. Start PiP with active speaker visible
2. Active speaker turns their camera off
3. **Expected**: PiP window switches to next available speaker; no freeze or blank frame

---

## Validate User Story 3 — Hardening & Edge Cases (P3)

### 3a. isSupported on unsupported device

1. Run on a device where PiP is not supported (Android < API 26 or iOS < 16)
2. Confirm `isSupported()` returns `false`
3. Confirm tapping "Enter PiP" in the example app shows an error message (not a crash)

### 3b. Screen sharing suppression

1. Start screen sharing in the LiveKit call
2. Press home button
3. **Expected**: No PiP window appears while `disableWhenScreenSharing: true` (default)
4. Stop screen sharing, press home again
5. **Expected**: PiP window now appears

### 3c. Call end during PiP

1. Start PiP
2. From a second device (or the server), terminate the LiveKit call
3. **Expected**: PiP window closes automatically within 2 seconds; status shows `inactive`

### 3d. dispose() cleanup

1. Start PiP, then return to full screen
2. Tap "Dispose" in the example app
3. Tap "Enter PiP"
4. **Expected**: Clear error shown (StateError); no crash; no PiP window

### 3e. Intermediate state stream events

1. Observe the state label in the example app while entering and exiting PiP
2. **Expected**: Label briefly shows `entering` before `active`, and `exiting` before
   `inactive` — both visible for at least one frame

---

## Validate Quality Gates

```sh
# From repo root — run in all four packages
cd livekit_pip && flutter analyze && flutter test && cd ..
cd livekit_pip_platform_interface && flutter analyze && flutter test && cd ..
cd livekit_pip_android && flutter analyze && flutter test && cd ..
cd livekit_pip_ios && flutter analyze && flutter test && cd ..
```

All commands must exit with code 0 and zero warnings.

---

## References

- Public API contract: [contracts/dart-api.md](contracts/dart-api.md)
- Native bridge schema: [contracts/native-bridge.md](contracts/native-bridge.md)
- Data model & state machine: [data-model.md](data-model.md)
- Research decisions: [research.md](research.md)
