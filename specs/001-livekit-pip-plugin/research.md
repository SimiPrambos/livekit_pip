# Research: livekit_pip Plugin

**Phase 0 Output** | **Date**: 2026-06-17 | **Plan**: [plan.md](plan.md)

## 1. flutter_webrtc Native Track Resolution (iOS)

**Decision**: Isolate all flutter_webrtc native access behind the `NativeTrackResolver`
protocol. Access tracks via `FlutterWebRTCPlugin`'s shared instance track registry.

**Rationale**: flutter_webrtc stores `RTCVideoTrack` instances in an internal dictionary
keyed by track ID. The registry is accessible via `FlutterWebRTCPlugin.sharedPlugin`
(or equivalent shared accessor) through the track's `trackId` string — the same ID
the Dart layer knows. Isolating this behind a protocol (`NativeTrackResolver`) means
that if flutter_webrtc changes its registry API (which has happened between major
versions), only `NativeTrackResolver.swift` needs updating.

**Runtime guard required**: If the shared plugin is nil or the track ID is not found
(e.g., track not yet published, or WebRTC not initialised), `FrameBridge` must surface
a clear error to Dart via the state channel rather than crashing with a force-unwrap.

**Alternatives considered**:
- Direct access to `FlutterWebRTCPlugin.sharedPlugin.localTracks` / `remoteTracks`
  dictionaries spread across multiple files — rejected: fragile, hard to update.
- Dart-layer track passing (serialize frame data cross-platform) — rejected:
  performance cost and complexity far outweigh isolation benefits.

---

## 2. iOS Frame Pipeline: CVPixelBufferPool + Metal Compositor

**Decision**: Use `CVPixelBufferPool` for buffer reuse and a `CIContext` backed by a
Metal device for the 2-feed compositor in `PixelBufferCompositor`.

**Rationale**:
- `CVPixelBufferPool` pre-allocates a pool of pixel buffers with consistent dimensions
  and pixel format (`kCVPixelFormatType_32BGRA`). Per-frame allocation is O(alloc +
  memset) and causes GC pressure at 30 fps; pool reuse brings this to near-zero.
- Metal-backed `CIContext` runs compositing on the GPU, keeping the CPU free for audio
  and Dart UI work. A `CIContext(mtlDevice:)` with `CIImage` compositing is simpler
  to implement correctly than raw Metal shaders while still meeting the ≤33 ms budget.
- Core Image's `CIFilter.compositeOver` (or manual `CIImage` transform + blend) is
  sufficient for the self-view inset: scale self-view to ~20% of frame width, position
  bottom-right, blend over dominant speaker frame.

**Pixel format alignment**: `AVSampleBufferDisplayLayer` accepts `32BGRA` and
`420YpCbCr8BiPlanarVideoRange`; use `32BGRA` for the compositor output since Core
Image works natively in BGRA. WebRTC frames arrive as `I420` or native `32BGRA`
depending on the device; `RTCCVPixelBuffer` wraps the native buffer directly when
available, avoiding a copy.

**Alternatives considered**:
- CPU-only `memcpy` blending — rejected: violates constitution Principle V.
- Raw Metal shaders — rejected: higher implementation risk and maintenance cost with
  no measurable benefit over CIContext for a 2-feed composite.
- `AVMutableComposition` — rejected: designed for file assets, not live frames.

---

## 3. Pigeon EventChannel Pattern (Why the stateStream Uses a Raw EventChannel)

**Decision**: Use Pigeon (`@HostApi` / `@FlutterApi`) for all command messages
(Dart → Native). Use a raw Flutter `EventChannel` (string name `livekit_pip/state`)
for the continuous `PipState` stream (Native → Dart).

**Rationale**: Pigeon generates typed bidirectional call-response channels but does
not model push streams (continuous events with no initiating call). The `stateStream`
is a live broadcast that fires whenever the OS changes PiP mode — there is no request.
The constitution explicitly permits a hand-written `EventChannel` for exactly this
case, with the inline comment "Pigeon does not model push streams" to satisfy the
audit requirement.

All other native communication (initialize, enterPip, exitPip, dispose, isSupported,
updateActiveTrack) goes through Pigeon-generated `LiveKitPipHostApi`.

**Alternatives considered**:
- Single `@FlutterApi` method called repeatedly by native — rejected: no clean
  stream semantics in Dart; subscriber management is manual and error-prone.
- Polling from Dart via MethodChannel — rejected: adds latency and wasted CPU for
  state that changes infrequently.

---

## 4. Android PiP: API 26–30 vs API 31+ Paths

**Decision**: Implement both paths in `PipHelper`, selected at runtime via
`Build.VERSION.SDK_INT` check.

| API level | How PiP is entered | Auto-enter support |
|-----------|--------------------|--------------------|
| 26–30 | Override `onUserLeaveHint()`, call `enterPictureInPictureMode(params)` | Not available — user must press home |
| 31+ | `setPictureInPictureParams(params.setAutoEnterEnabled(true))` early in Activity lifecycle | Yes — OS enters PiP on home press |

**Aspect ratio**: `PipHelper` reads the current video track's natural resolution from
the Dart layer (passed via `initialize`) and sets `PictureInPictureParams.Builder
.setAspectRatio(Rational(width, height))`. Falls back to 16:9 if no track is active.

**sourceRectHint**: Set to the bounding rect of `LiveKitPipView` on screen for a
smooth zoom-out animation. Retrieved via `view.getGlobalVisibleRect()`.

**Activity base class**: `LiveKitPipActivity` is an optional convenience class that
extends `FlutterActivity` and implements the override hooks. Apps with a custom base
class use `PipHelper.attach(activity)` instead, which registers lifecycle callbacks
via `ActivityLifecycleCallbacks`.

**Alternatives considered**:
- Requiring API 31+ only — rejected: drops Android 8–10 support, which still
  represents a significant portion of LiveKit app users.
- Using a `ProcessLifecycleObserver` instead of `onUserLeaveHint` for API 26–30 —
  rejected: does not fire on a home-button press specifically; fires on any background
  transition including PiP re-entry, causing a loop.

---

## 5. Active Speaker Selection Algorithm

**Decision**: `ActiveSpeakerSelector` subscribes to the LiveKit Room's `activeSpeakers`
event stream (list of Participants ordered by audio energy, re-emitted by the server
periodically). It selects the first remote participant in the list that has at least
one active video track. Falls back to the last known dominant speaker if the list is
empty.

**Track selection priority**:
1. First `RemoteVideoTrack` of the first entry in `activeSpeakers` that has a
   non-muted video track.
2. If no active speaker has video: last known dominant speaker's track (held in state).
3. If no prior dominant speaker: the first remote participant with a published video
   track (alphabetical by SID as stable tiebreak).

**Track ID propagation**: When the selected track changes, `ActiveSpeakerSelector`
calls `LiveKitPipHostApi.updateActiveTrack(trackId)` on native. On iOS, `FrameBridge`
receives this and rebinds the `RTCVideoRenderer` to the new track without recreating
the display layer.

**Alternatives considered**:
- Polling `room.remoteParticipants` on a timer — rejected: misses rapid speaker
  changes and wastes CPU.
- Native-side speaker selection — rejected: would require the native layer to have
  a Room reference, breaking the architecture boundary.
