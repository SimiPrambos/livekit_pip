# Feature Specification: iOS PiP Split View with Self-View and Avatars

**Feature Branch**: `002-ios-self-view-inset`

**Created**: 2026-10-05

**Status**: Draft (revision 2)

**Input**: Revision 1: "Implement the self-view inset natively; allow passing a widget builder in IosPipConfiguration like Android." iOS cannot draw app UI while PiP shows, so the inset is native. Revision 2, after device testing: "(1) Let each participant pass an avatar URL to display while their camera is off; the video is stuck when the camera is off. (2) includeLocalParticipantVideo = true but the local video does not show; check the multitasking configuration. (3) Follow the attached screenshots: the local participant is on the left when both videos are portrait; a participant in landscape takes the left side."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — See Both People Side by Side (Priority: P1)

An end user on an iPhone leaves the app during a video call. The PiP window shows two
tiles side by side: the other person and themselves, like FaceTime. Each tile keeps
its video's shape, so a landscape video is wider than a portrait one.

**Why this priority**: It is the layout the requester asked for, and it is how users
know the call is still live and what the other side sees.

**Independent Test**: With background camera access, start a call where both cameras
are portrait, leave the app, and confirm the user's own tile is on the left and the
other person's on the right, both live.

**Acceptance Scenarios**:

1. **Given** both videos are portrait, **When** PiP shows, **Then** the user's own tile
   is on the left and the other person's on the right, at equal height.
2. **Given** exactly one video is landscape, **When** PiP shows, **Then** the landscape
   tile is on the left and is wider; the portrait tile is on the right.
3. **Given** both videos are landscape, **When** PiP shows, **Then** the user's own
   tile is on the left.
4. **Given** a video turns from portrait to landscape during PiP, **When** the next
   frames arrive, **Then** the window and order update to follow the rules above.
5. **Given** the self-view is turned off in configuration, **When** PiP shows, **Then**
   only the other person's tile is shown.

---

### User Story 2 — Avatar Instead of a Frozen Picture (Priority: P1)

When someone's camera is off, or iOS has paused the user's own camera, their tile
shows their avatar on a dark background instead of a frozen last frame. Each person's
avatar comes from the app; when there is no avatar, their initials are shown.

**Why this priority**: Today the remote video freezes on its last frame when the
camera turns off, which misleads the user about what is happening.

**Independent Test**: During PiP, have the other person turn off their camera; their
tile switches to their avatar within one second and back to video when the camera
returns.

**Acceptance Scenarios**:

1. **Given** the other person turns their camera off, **When** PiP is showing,
   **Then** their tile shows their avatar within one second, not a frozen frame.
2. **Given** a person has no avatar, or it fails to load, **When** their camera is off,
   **Then** their tile shows their initials.
3. **Given** iOS pauses the user's own camera, **When** PiP is showing, **Then** the
   user's tile shows their avatar.
4. **Given** a camera turns back on, **When** frames arrive, **Then** the tile shows
   video again.

---

### User Story 3 — The User's Own Camera Keeps Running in PiP (Priority: P1)

When the app is allowed to use the camera while multitasking, the user's own camera
keeps running after they leave the app, so their tile is live and the other person
still sees them.

**Why this priority**: The requester tested `includeLocalParticipantVideo` and saw no
local video. The camera was paused by iOS because the plugin never asked to keep it.

**Independent Test**: In an app that meets the platform requirements, leave the app
during a call and confirm the user's own tile is live video.

**Acceptance Scenarios**:

1. **Given** the self-view is on and the device supports multitasking camera access,
   **When** the user's camera is running, **Then** the plugin asks iOS to keep it
   running in PiP.
2. **Given** the device or app does not qualify, **When** PiP shows, **Then** the
   user's tile shows their avatar (User Story 2) and nothing fails.
3. **Given** the self-view is off, **When** PiP shows, **Then** the plugin does not
   ask to keep the camera running.

---

### User Story 4 — See Who Is Muted (Priority: P2)

Each tile shows a muted-microphone badge in its bottom-right corner while that
person's microphone is muted.

**Why this priority**: Shown in the requester's screenshots; it tells the user why
they cannot hear someone.

**Independent Test**: Mute the other person's microphone during PiP and confirm the
badge appears on their tile only.

**Acceptance Scenarios**:

1. **Given** a person's microphone is muted, **When** PiP shows, **Then** their tile
   has the muted badge.
2. **Given** they unmute, **When** PiP is showing, **Then** the badge disappears.

---

### Edge Cases

- **Alone in the room**: only the user's own tile shows (or an empty window when the
  self-view is off).
- **Several remote people**: the other tile shows the most recent remote speaker;
  AI agent participants are never chosen.
- **Remote person leaves**: their tile is removed; the window resizes.
- **Avatar URL changes or arrives late**: the tile updates when the new image loads.
- **Screen sharing by the local user**: PiP is suppressed already (spec 001).
- **Android**: unchanged; the app's own widget is shown.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The iOS PiP window MUST show up to two tiles side by side: the other
  person and, when the self-view is on, the user.
- **FR-002**: Tiles MUST share one height; each width MUST follow its video's
  width-to-height ratio. A tile without video MUST use a portrait 9:16 shape.
- **FR-003**: Order MUST be: when exactly one tile is landscape, it is on the left;
  otherwise the user's own tile is on the left.
- **FR-004**: The PiP window's shape MUST follow the combined tiles and update when a
  video's orientation changes.
- **FR-005**: A tile whose camera is off, unpublished, unsubscribed, or paused by iOS
  MUST show the person's avatar (or initials) on a dark background, never a frozen frame.
- **FR-006**: Apps MUST be able to provide an avatar image address per participant; it
  MUST be re-read when the participant's name or metadata changes.
- **FR-007**: When the self-view is on, the plugin MUST ask iOS to keep the user's
  camera running while multitasking, when the device and app support it.
- **FR-008**: A tile MUST show a muted badge while that person's microphone is muted.
- **FR-009**: The other-person tile MUST follow the most recent remote speaker and MUST
  skip AI agent participants.
- **FR-010**: The user's own video MAY be mirrored like a front-camera preview; on by
  default.
- **FR-011**: Avatar images MUST NOT be logged, and only addresses the app provides
  MUST be fetched.
- **FR-012**: Releasing the plugin MUST release both tiles and stop asking for the
  camera.

### Key Entities

- **Tile participant**: who the tile is for (identity), whether it is the user, their
  current video (or none), whether their microphone is muted, their display name, and
  their avatar address.
- **Layout**: the ordered tiles and the window shape derived from their video shapes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 100% of PiP sessions with two portrait videos, the user's own tile is
  on the left.
- **SC-002**: A camera turning off shows the avatar within 1 second; no tile shows a
  frozen frame for longer than 1 second.
- **SC-003**: On an app and device that qualify for multitasking camera access, the
  user's own tile is live in 100% of PiP sessions.
- **SC-004**: The main video stays visibly smooth during a 10-minute PiP session with
  both tiles live.

## Assumptions

- Multitasking camera access is decided by iOS: the device must report support, and
  apps with a deployment target below iOS 16 also need Apple's
  `multitasking-camera-access` entitlement. Meeting that is the app's job.
- Keeping the camera running means the other side keeps seeing the user while they
  are in another app. Whether that is acceptable is the app's decision, made by
  turning the self-view on.
- One-to-one calls are the main case; with several remote people only the latest
  speaker is shown (constitution Principle III: at most two feeds on iOS).
- A widget builder on iOS stays out of scope: Flutter does not render in the background.
- Revision 1's corner and width options are dropped: they do not apply to a split
  view, and they never shipped.
