# Feature Specification: livekit_pip Plugin — Native Picture-in-Picture for LiveKit Flutter Apps

**Feature Branch**: `001-livekit-pip-plugin`

**Created**: 2026-06-17

**Status**: Draft

**Input**: User description: "implement the livekit_pip plugin as described in CLAUDE.md and README.md"

## User Scenarios & Testing *(mandatory)*

### User Story 1 — PiP on Background (Priority: P1)

An end user is on a LiveKit video call in a Flutter app. They press the home button
or switch to another app. Instead of the call disappearing, a small floating PiP
window appears on-screen showing the call video. The user can continue their call
while using other apps. When they tap the PiP window, they return to the full-screen
call.

On Android the PiP window shows the full call layout the app developer configured
(e.g. a participant grid with self-view). On iOS the PiP window shows the active
speaker's video feed.

**Why this priority**: This is the core value proposition of the plugin — keeping a
call visible while multitasking. Without this working reliably, the plugin has no
value to consumers.

**Independent Test**: Integrate the plugin into a LiveKit demo app, join a call, press
the home button, and confirm a floating video window appears within 500 ms and stays
visible while using other apps.

**Acceptance Scenarios**:

1. **Given** a LiveKit call is active and the plugin is initialized, **When** the user
   presses the home button, **Then** a floating PiP window appears showing the call
   video within 500 ms.
2. **Given** PiP is active, **When** the user taps the PiP window, **Then** the app
   returns to full-screen call view and the PiP window closes.
3. **Given** PiP is active, **When** the user taps the close button on the PiP window,
   **Then** the PiP window closes and the call continues in the background.
4. **Given** PiP auto-enter is disabled in configuration, **When** the user backgrounds
   the app, **Then** no PiP window appears.

---

### User Story 2 — Active Speaker Tracking & Self-View Inset on iOS (Priority: P2)

An end user on an iOS device is watching a PiP window from a multi-participant
LiveKit call. As different participants speak, the PiP window automatically switches
to show the current dominant speaker's video without any user action. The user also
sees a small inset of their own camera feed in a corner of the PiP window, so they
know their camera is on.

**Why this priority**: A static PiP showing the wrong participant loses most of its
value in group calls. This makes the PiP window genuinely useful in the most common
call scenario.

**Independent Test**: Join a call with 3+ participants on an iOS device with the plugin,
begin PiP, have participants take turns speaking, and confirm the PiP window switches
to each speaker within 1 second. Confirm a self-view inset appears when
`includeLocalParticipantVideo` is enabled.

**Acceptance Scenarios**:

1. **Given** PiP is active on iOS with multiple remote participants, **When** a new
   participant becomes the dominant speaker, **Then** the PiP window switches to that
   participant's video within 1 second.
2. **Given** `includeLocalParticipantVideo` is enabled, **When** PiP is active on iOS,
   **Then** the user's own camera feed appears as a small inset within the PiP window.
3. **Given** `includeLocalParticipantVideo` is disabled, **When** PiP is active on iOS,
   **Then** no self-view inset is shown.
4. **Given** the active speaker turns their camera off, **When** PiP is active on iOS,
   **Then** the PiP window transitions to the next available speaker without freezing.

---

### User Story 3 — Hardening: Edge Cases, Programmatic Control & DX (Priority: P3)

An app developer using the plugin can safely handle all edge cases: calling the API
on an unsupported device returns a clear signal rather than crashing; screen sharing
suppresses auto-enter PiP; a call that ends while PiP is active cleans up gracefully;
and calling `dispose()` releases all resources with no leaks.

The developer can also manually trigger enter/exit PiP from their UI (e.g., a button),
observe every PiP lifecycle change via a state stream, and integrate the plugin into
an app that already has a custom `Activity` base class on Android.

**Why this priority**: Without hardening, the plugin is not safe for production. A
crash on an unsupported device or a resource leak at call-end will generate support
tickets and damage the plugin's reputation.

**Independent Test**: Test each edge case in isolation on a physical device: call
`enterPiP()` on an unsupported device, end a call while PiP is active, call
`dispose()` and then `enterPiP()` again. Confirm no crashes, no leaks, and clear
error signals in each case.

**Acceptance Scenarios**:

1. **Given** PiP is not supported on the current device or OS version, **When** the
   developer calls `isSupported()`, **Then** it returns `false` without crashing.
2. **Given** PiP is not supported, **When** the developer calls `enterPiP()`, **Then**
   a clear error is thrown — the app does not silently fail or crash.
3. **Given** the local user starts screen sharing, **When** `disableWhenScreenSharing`
   is enabled, **Then** PiP auto-enter is suppressed for the duration of the share.
4. **Given** PiP is active, **When** the LiveKit call ends (Room disconnects), **Then**
   the PiP window closes automatically and all resources are released.
5. **Given** the developer calls `dispose()`, **When** any subsequent method is called
   on the controller, **Then** a clear error is thrown and no system resources remain
   held.
6. **Given** the plugin is initialized, **When** PiP transitions between any two
   states, **Then** the state stream emits the correct intermediate state
   (`entering`/`exiting`) before settling on the final state.

---

### Edge Cases

- What happens when `enterPiP()` is called before `initialize()`?
- What happens when all remote participants leave the call while PiP is active on iOS
  (no video tracks remain)?
- What happens when the user rapidly backgrounds and foregrounds the app multiple
  times in quick succession?
- What happens when the local participant's camera is off and `includeLocalParticipantVideo`
  is enabled — does the self-view inset show a blank frame or disappear?
- What happens when the device's PiP system setting is disabled by the user after the
  plugin has been initialized?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The plugin MUST allow an app developer to activate PiP by passing a
  LiveKit Room reference and a configuration object in a single initialization call.
- **FR-002**: The plugin MUST automatically enter PiP mode when the user backgrounds
  the app, unless auto-enter is disabled via configuration.
- **FR-003**: The plugin MUST allow the developer to programmatically enter and exit
  PiP at any time after initialization.
- **FR-004**: The plugin MUST expose a continuous state stream emitting one of five
  states: `unsupported`, `inactive`, `entering`, `active`, `exiting`.
- **FR-005**: On Android, the plugin MUST render a developer-supplied widget inside
  the PiP window; the developer has full control over the widget content.
- **FR-006**: On iOS, the plugin MUST render the dominant/active speaker's video feed
  in the PiP window, switching automatically as the active speaker changes.
- **FR-007**: On iOS, the plugin MUST optionally composite the local participant's
  camera feed as a self-view inset within the PiP window, controlled by
  `includeLocalParticipantVideo`.
- **FR-008**: The plugin MUST detect when the local user starts screen sharing and
  suppress auto-enter PiP if `disableWhenScreenSharing` is enabled.
- **FR-009**: The plugin MUST expose an `isSupported()` method that returns `false`
  on devices or OS versions that do not support PiP, without throwing.
- **FR-010**: The plugin MUST release all native resources — video renderers, display
  layers, and any system PiP session — when `dispose()` is called.
- **FR-011**: The plugin MUST close the PiP window and release resources automatically
  when the LiveKit Room disconnects.
- **FR-012**: The plugin MUST include a zero-configuration widget (`LiveKitPipView`)
  that the developer places once in the call page widget tree; it handles any
  necessary native surface setup with no developer configuration required.

### Key Entities

- **Room**: A LiveKit call session, provided by the consumer; the plugin observes it
  but does not own it.
- **PiP Session**: The lifecycle of a single PiP activation — created on `initialize`,
  enters/exits modes, destroyed on `dispose` or Room disconnect.
- **PipState**: The five-value enumeration describing where the PiP session is in its
  lifecycle (`unsupported`, `inactive`, `entering`, `active`, `exiting`).
- **PiP Configuration**: Per-platform settings controlling auto-enter, widget builder
  (Android), self-view inset (iOS), and screen-share suppression.
- **Dominant Speaker**: The remote participant whose audio is currently loudest; the
  plugin tracks this continuously on iOS and switches the displayed video feed
  accordingly.
- **Self-View Inset**: The local participant's camera feed, composited into a corner
  of the iOS PiP window when enabled.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An app developer with an existing LiveKit Flutter app can integrate PiP
  with fewer than 20 lines of new code in their call page.
- **SC-002**: The PiP window appears within 500 ms of the app being backgrounded on
  any supported device.
- **SC-003**: On iOS, the PiP window reflects the correct active speaker within
  1 second of a speaker change during a call.
- **SC-004**: The PiP window displays video at a visually smooth frame rate on any
  supported device under normal network conditions (no visible stuttering on a stable
  connection).
- **SC-005**: `isSupported()` returns a result in under 100 ms on every supported
  device, and never throws.
- **SC-006**: After `dispose()` is called, zero system resources attributable to the
  plugin remain held (verified by profiler with no persistent native threads, display
  layers, or video renderers).
- **SC-007**: The plugin integrates into a consumer app without requiring the consumer
  to suppress any linting warnings or modify any quality-gate configuration in their
  own project.

## Assumptions

- The consumer app is responsible for keeping the LiveKit Room connected while in the
  background; the plugin does not manage Room connection lifecycle.
- The consumer app has configured the required platform-level permissions before
  calling `initialize()`: `supportsPictureInPicture` activity attribute on Android;
  `voip` or `audio` background mode in `Info.plist` on iOS.
- The plugin targets Android API 26+ and iOS 16+; devices below these floors are
  treated as `unsupported` and `isSupported()` returns `false`.
- The aspect ratio of the PiP window follows the natural aspect ratio of the active
  video track; the developer does not configure this explicitly.
- On iOS, "dominant speaker" is defined as the remote participant with the highest
  recent audio energy level, as reported by the LiveKit Room. When no remote
  participant has audio activity, the most recently active speaker remains displayed.
- The self-view inset on iOS shows a fixed-size overlay in a corner of the PiP
  window; the exact position and size are platform-determined defaults (not
  configurable in v1).
- When the local participant's camera is off, the self-view inset is hidden rather
  than showing a blank frame.
- The plugin is distributed as a Flutter federated plugin; consumers install one
  top-level package and both platform implementations are included automatically.
