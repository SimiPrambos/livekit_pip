# Data Model: iOS PiP Split View

## IosPipConfiguration (extended)

| Field | Type | Default | Notes |
|---|---|---|---|
| `includeLocalParticipantVideo` | `bool` | `true` | Shows the user's own tile and requests multitasking camera |
| `autoEnterOnBackground` | `bool` | `true` | Existing |
| `mirrorSelfView` | `bool` | `true` | Mirrors the user's own video only |
| `avatarUrlResolver` | `String? Function(Participant)?` | `null` | Avatar per participant; `null` result → initials |

Revision 1's `selfViewCorner`, `selfViewWidthFraction`, and `PipSelfViewCorner` are removed.

## PipParticipantInfo (platform interface) / PipParticipant (Pigeon, iOS)

| Field | Type | Meaning |
|---|---|---|
| `identity` | `String` | Stable key for the tile |
| `isLocal` | `bool` | The user's own tile |
| `videoTrackId` | `String?` | WebRTC track id; `null` when the camera is off, missing, or unsubscribed |
| `isMicMuted` | `bool` | Microphone muted or not published |
| `displayName` | `String` | Name, else identity; used for initials |
| `avatarUrl` | `String?` | From `avatarUrlResolver` |

Value equality; Dart sends a new list only when it differs from the last one sent.

## Tile list (Dart → iOS)

`[remote?, local?]`, at most one of each. Remote = latest non-agent remote speaker,
else first non-agent remote. Local present only when `includeLocalParticipantVideo`.
Recomputed on: active speakers changed, participant connected/disconnected, track
subscribed/unsubscribed/muted/unmuted, local track published/unpublished, participant
name/metadata/attributes changed.

## PipInitRequest (Pigeon, both packages)

Revision 1's `iosSelfViewCorner` and `iosSelfViewWidthFraction` are removed;
`iosMirrorSelfView` stays.

## Tile layout (iOS, pure)

Input: tiles with `isLocal` and `aspect` (video width/height after rotation, or 9/16
with no video). Output: ordered tiles and frames.

1. Order: if exactly one tile has `aspect > 1`, it is first; else the local tile first.
2. Frames: height = container height; width_i = container width × aspect_i / Σaspect.
3. Window size: height 180 pt; width = 180 × Σaspect. Never zero.
