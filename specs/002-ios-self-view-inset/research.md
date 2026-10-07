# Research: iOS PiP Split View

## R1. Can the iOS PiP window show app-provided Flutter UI?

**Decision**: No. Everything in the iOS PiP window is native.

**Rationale**: iOS PiP is only on screen while the app is backgrounded. On
`applicationDidEnterBackground` / `sceneDidEnterBackground` the Flutter engine calls
`setIsGpuDisabled:YES` (`FlutterEngine.mm`, `flutterDidEnterBackground:`); the
rasterizer and `Image.toImage` both run behind that switch.

**Alternatives considered**: widget snapshot before backgrounding (never live, races
auto-start); Android-style widget swap (no iOS equivalent).

## R2. Drawing two tiles

**Decision**: Two `PipTileView`s, each with its own `PipVideoRenderer`
(`AVSampleBufferDisplayLayer`), laid out side by side inside the
`AVPictureInPictureVideoCallViewController`. Frames are set by a pure layout function.

**Rationale**: Apple's video-call PiP guide says to "add your source as a subview" of
the video-call view controller; the window shows that view hierarchy. No per-frame
compositing is needed.

**Alternatives considered**: one composited buffer (`PixelBufferCompositor`): a GPU
pass per frame with no benefit for this content source.

## R3. Layout rule

**Decision**: Tile shape = its video's width/height after rotation; 9:16 when there is
no video. Exactly one landscape tile (ratio > 1) goes left; otherwise the local tile
goes left. Common height; widths proportional to shapes. Window
`preferredContentSize` = sum of widths at a 180 pt height.

**Rationale**: Matches the requester's screenshots (portrait+portrait: local left;
landscape remote: remote left and wider; camera-off tile: portrait-shaped avatar).

## R4. Why the local video never showed

**Decision**: When the self-view is on and the local camera is bound, set
`isMultitaskingCameraAccessEnabled = true` on flutter_webrtc's capture session if
`isMultitaskingCameraAccessSupported`, inside `beginConfiguration` /
`commitConfiguration`. Reach the session through `NativeTrackResolver`
(`FlutterWebRTCPlugin.sharedSingleton.videoCapturer.captureSession`; `videoCapturer`
is a public property in flutter_webrtc 1.6.0's `FlutterWebRTCPlugin.h`, and
`captureSession` is public on `RTCCameraVideoCapturer`).

**Rationale**: Apple, "Adopting Picture in Picture for video calls": "In iOS 16 and
later, you can use the camera in Picture in Picture mode by enabling a capture
session's `isMultitaskingCameraAccessEnabled` property. Apps that have a deployment
target earlier than iOS 16 require the
`com.apple.developer.avfoundation.multitasking-camera-access` entitlement." flutter_webrtc
never sets the property, so iOS interrupts the camera with
`videoDeviceNotAvailableInBackground`.

**Caveats**:
- Apple says to set the property before starting the session; flutter_webrtc has
  already started it. Setting it inside a configuration block on a running session
  is the only option without forking flutter_webrtc. Needs device verification.
- An app below iOS 16 (Welle is 15.5) also needs the entitlement, or the support
  check reports false. The plugin logs one line in that case, without PHI.

**Alternatives considered**: observing `AVCaptureSession.didStartRunningNotification`
(fires after start too, and would toggle any session in the app); forking
flutter_webrtc (larger blast radius).

## R5. Camera-off detection

**Decision**: Dart sends each tile's video track id, or `null` when the camera
publication is muted, missing, or (remote) unsubscribed. iOS additionally treats the
local camera as off while `AVCaptureSession.wasInterruptedNotification` is in effect.

**Rationale**: The display layer keeps its last frame, so the "stuck video" was the
renderer staying bound to a muted track.

## R6. Avatars

**Decision**: `IosPipConfiguration.avatarUrlResolver`, a
`String? Function(Participant)` the app supplies. Dart calls it while building tile
info and sends the result. iOS fetches with `URLSession`, caches in `NSCache`, shows a
circular image, and falls back to initials from the display name.

**Rationale**: A resolver lets apps use any source (their own profile data, LiveKit
metadata or attributes). Re-evaluated on name, metadata, and attribute changes.
Fetching happens when the tile info arrives, normally while the app is foreground.

## R7. Which remote participant

**Decision**: The most recent remote active speaker that is not
`ParticipantKind.AGENT`; otherwise the first non-agent remote participant.

**Rationale**: Telehealth rooms include a voice agent. The previous logic only
considered remotes with video, which is why a camera-off remote never updated.

## R8. iOS deployment target in the constitution

**Decision**: PATCH amendment 1.0.0 → 1.0.1, iOS 16.0 → 15.0 (done in revision 1).

**Superseded**: constitution 1.0.2 restores iOS 16.0, so every consumer gets
multitasking camera access without the entitlement (see R4 caveats).
