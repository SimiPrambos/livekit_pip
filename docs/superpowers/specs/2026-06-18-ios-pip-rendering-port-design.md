# iOS PiP Rendering Pipeline Port

**Date:** 2026-06-18  
**Status:** Approved  
**Scope:** `livekit_pip_ios` Swift package — iOS rendering layer only. Dart API, Pigeon bindings, Android, and the Flutter widget layer are unchanged.

---

## Problem

The current iOS implementation has two root bugs:

1. **Hang on init** — `FrameBridge.i420ToBGRA()` does manual pixel-by-pixel YUV→BGRA conversion on the WebRTC callback thread. At 1080p (2M pixels × 4 bytes) this takes ~60–200ms per frame, completely blocking the WebRTC thread and making the app appear frozen.

2. **PiP window shows nothing** — `FrameBridge` gates frame delivery via an `enqueueEnabled` flag set from an `onWindowChange` callback. The callback wiring is fragile: if `PipPlatformView` or `FrameBridge` are not fully set up before the PiP window opens, the gate never opens and no frames reach the display layer.

## Solution

Port the rendering pipeline from `stream_video_flutter`'s `PictureInPicture` directory. The template solves both problems with a clean design:

- Hardware-accelerated YUV→BGRA via `vImageConvert_420Yp8_Cb8_Cr8ToARGB8888` (Accelerate.framework) — sub-millisecond per frame.
- Frame delivery gating lives inside the rendering view (`willMove(toWindow:)`) — never requires external callbacks.

The Dart API surface, Pigeon API, `NativeTrackResolver`, `ActiveSpeakerSelector`, and all Dart files are **unchanged**.

Self-view compositing (`PixelBufferCompositor`) is dropped; `includeLocalParticipantVideo` is a Phase 2 item.

---

## Architecture

### Frame pipeline (after port)

```
RTCVideoTrack
  └─ PipVideoRenderer (UIView + RTCVideoRenderer)
       ├─ renderFrame() on WebRTC thread
       │    └─ BufferTransformer.transformAndResizeIfRequired()
       │         └─ RTCYUVBuffer
       │              ├─ RTCI420Buffer → vImageConvert_420Yp8_Cb8_Cr8ToARGB8888 (Accelerate)
       │              └─ RTCCVPixelBuffer → pass-through pixelBuffer
       │              → CVPixelBuffer (from PixelBufferRepository pool)
       │              → CMSampleBuffer (DisplayImmediately attachment)
       └─ bufferPublisher.send(sampleBuffer)   ← Combine PassthroughSubject
            └─ receive(on: DispatchQueue.main)
                 └─ SampleBufferVideoCallView.renderingComponent.enqueue()
```

Frame delivery is gated by `PipVideoRenderer.willMove(toWindow:)`:
- `newWindow != nil` → `track.add(self)` + subscribe Combine sink
- `newWindow == nil` → `track.remove(self)` + cancel sink + flush display layer

Track binding: `PipVideoRenderer.track: RTCVideoTrack?` didSet — remove old track, add self to new track.

### Object graph

```
PipPlatformView
  ├─ containerView: UIView              (anchor for PiP animation)
  ├─ pipVC: PipVideoCallViewController  (content shown in PiP window)
  │    └─ videoRenderer: PipVideoRenderer
  │         └─ contentView: SampleBufferVideoCallView  (AVSampleBufferDisplayLayer)
  ├─ pipController: AVPictureInPictureController
  ├─ trackStateAdapter: TrackStateAdapter
  └─ resolver: NativeTrackResolver      (unchanged)
```

`PipPlatformView.rebindTrack(trackId:)` replaces the old `FrameBridge.rebindTrack(trackId:)`.

---

## Files

### New files (all in `livekit_pip_ios/ios/.../Sources/livekit_pip_ios/`)

| File | Ported from | Notes |
|------|-------------|-------|
| `SampleBufferVideoCallView.swift` | `SampleBufferVideoCallView.swift` | Direct port; `import WebRTC` instead of `stream_webrtc_flutter` is not needed here (AVKit only) |
| `PixelBufferPool.swift` | `StreamPixelBufferPool.swift` | BGRA pool; max 5 buffers |
| `PixelBufferRepository.swift` | `StreamPixelBufferRepository.swift` | Multi-pool keyed by (width, height, format); os_unfair_lock |
| `YpCbCrPixelRange+Default.swift` | Same name | Exact copy |
| `YUVToARGBConversion.swift` | `StreamYUVToARGBConversion.swift` | BT.601/BT.709 vImage conversion setup; `import Accelerate` |
| `RTCYUVBuffer.swift` | `StreamRTCYUVBuffer.swift` | `import WebRTC` (not stream_webrtc_flutter); same logic |
| `BufferTransformer.swift` | `StreamBufferTransformer.swift` | `import WebRTC`; same logic |
| `PipWindowSizePolicy.swift` | `StreamPictureInPictureWindowSizePolicy.swift` + adaptive + fixed | Simplified: `PipViewControlling` protocol has only `preferredContentSize`; no SwiftUI overlay methods |
| `PipVideoRenderer.swift` | `StreamPictureInPictureVideoRenderer.swift` | `import WebRTC`, `import Combine`; same frame-skip logic, same Combine pattern |
| `TrackStateAdapter.swift` | `StreamPictureInPictureTrackStateAdapter.swift` | Ensures track stays enabled during PiP; 0.1s Combine timer |

### Modified files

**`PipPlatformView.swift`** — complete rewrite, same public shape:
- Remove `_SampleBufferView` class (replaced by `SampleBufferVideoCallView` inside `PipVideoRenderer`)
- Rewrite `PipVideoCallViewController`:
  - Creates `PipVideoRenderer(windowSizePolicy: PipAdaptiveWindowSizePolicy())`
  - Adds renderer as full-frame subview in `viewDidLoad()`
  - Conforms to `PipViewControlling` (exposes `preferredContentSize`)
  - Policy's `controller = self` set in `init()`
  - Remove `_SampleBufferView`, `sampleBufferDisplayLayer`, `onWindowChange`
- `PipPlatformView`:
  - Remove `frameBridge: FrameBridge?`
  - Remove `displayLayer` computed property
  - Add `videoRenderer: PipVideoRenderer` (accessed via `pipVC`)
  - Add `trackStateAdapter: TrackStateAdapter`
  - Add `resolver: NativeTrackResolver = FlutterWebRTCTrackResolver()`
  - Add `rebindTrack(trackId:)` → resolve → `pipVC.videoRenderer.track = resolved`
  - `AVPictureInPictureControllerDelegate`: on `didStart` set `trackStateAdapter.isEnabled = true`; on `didStop` set `false`
  - Remove `pipVC.onWindowChange` callback wiring

**`LiveKitPipPlugin.swift`** — smaller changes:
- Remove `frameBridge: FrameBridge?` property
- `updateActiveTrack(trackId:)` → `platformView?.rebindTrack(trackId: trackId)`
- `initialize(request:)` → no-op for now (Phase 2: pass `iosIncludeLocalParticipantVideo` through)
- `dispose()` → remove frameBridge calls; `platformView?.stopPictureInPicture()`
- `didCreatePlatformView(_:)` → remove bridge creation; only wire `onStateChanged`

### Deleted files

| File | Reason |
|------|--------|
| `FrameBridge.swift` | Replaced by `PipVideoRenderer` + `RTCYUVBuffer` |
| `PixelBufferCompositor.swift` | Phase 2 (self-view inset) |

### Unchanged files

`NativeTrackResolver.swift`, `Messages.g.swift`, `PipPlatformViewFactory.swift`, all Dart files.

---

## Key design decisions

**Why `willMove(toWindow:)` instead of a callback flag?**  
The template's renderer gates itself — no external actor needs to know when the PiP window appears. This eliminates the timing dependency that caused the "nothing shown" bug.

**Why Combine PassthroughSubject?**  
`renderFrame(_:)` is called on the WebRTC thread. The display layer must be driven from the main thread. The subject serializes delivery without blocking the WebRTC thread.

**Frame skipping logic (preserved from template):**  
When the track resolution is much larger than the PiP window, we skip frames proportionally (e.g., 4K track → 15× ratio → skip every other frame). Reduces CPU without visible quality loss.

**Window size policy:**  
`PipAdaptiveWindowSizePolicy` updates `preferredContentSize` whenever `trackSize` changes. `PipVideoCallViewController` sets the initial `preferredContentSize = (320, 180)` in `viewDidLoad` so the PiP controller never sees a zero size (which triggers the `PGPegasus -1003` crash).

**`TrackStateAdapter`:**  
iOS can mute a track's enabled state when the app backgrounds. The adapter runs a 0.1s timer during active PiP to force `isEnabled = true`. Enabled while PiP is active (`pictureInPictureControllerDidStartPictureInPicture`), disabled on stop.

**import WebRTC:**  
The template uses `stream_webrtc_flutter`. Our package uses `WebRTC` (the standard flutter_webrtc Swift package import). All ported files replace that import.

---

## What does NOT change

- Dart API: `LiveKitPip`, `PipState`, `LiveKitPipConfiguration`, `ActiveSpeakerSelector`
- Pigeon bindings: `Messages.g.swift`, `Messages.g.dart`
- `NativeTrackResolver` and flutter_webrtc integration
- Android implementation
- Example app

---

## Out of scope (Phase 2)

- Local self-view inset compositing (`includeLocalParticipantVideo`)
- SwiftUI overlay with participant name/quality indicator (template's `StreamAVPictureInPictureVideoCallViewController` overlay)
