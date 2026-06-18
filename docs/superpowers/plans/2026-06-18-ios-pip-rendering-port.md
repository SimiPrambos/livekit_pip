# iOS PiP Rendering Pipeline Port — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken `FrameBridge` + manual I420 conversion with the template's Accelerate-powered rendering pipeline so iOS PiP shows video and stops hanging on init.

**Architecture:** A new `PipVideoRenderer` (UIView + RTCVideoRenderer) owns the `AVSampleBufferDisplayLayer` and gates frame delivery internally via `willMove(toWindow:)`. Frames are converted from YUV to BGRA using `vImageConvert_420Yp8_Cb8_Cr8ToARGB8888` (Accelerate.framework) and delivered to the layer via a Combine `PassthroughSubject` serialised to the main thread. `PipPlatformView` no longer holds a `FrameBridge`; it holds a `PipVideoCallViewController` whose content view is the `PipVideoRenderer`.

**Tech Stack:** Swift, Accelerate.framework (vImage), Combine, AVKit, WebRTC (flutter_webrtc), Flutter plugin APIs

## Global Constraints

- All Swift files live in `livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/`
- iOS deployment target: 15.0 (AVPictureInPictureVideoCallViewController requires iOS 15+)
- Import WebRTC types as `import WebRTC` — NOT `import stream_webrtc_flutter`
- Never edit `Messages.g.swift` (Pigeon-generated)
- Never recreate `AVSampleBufferDisplayLayer` or `AVPictureInPictureController` mid-call
- Build verification command (from repo root): `cd livekit_pip/example && flutter build ios --no-codesign --simulator`
- No Dart API changes — `LiveKitPipHostApi`, `PipState`, all Dart files stay the same

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `YpCbCrPixelRange+Default.swift` | Static `.default` extension on `vImage_YpCbCrPixelRange` |
| Create | `YUVToARGBConversion.swift` | Holds `vImage_YpCbCrToARGB` struct, initialised once |
| Create | `PixelBufferPool.swift` | CVPixelBufferPool for one (width × height × format) |
| Create | `PixelBufferRepository.swift` | Dict of pools keyed by size+format; `UnfairQueue` lock |
| Create | `RTCYUVBuffer.swift` | `RTCVideoFrameBuffer` wrapper; Accelerate I420→BGRA; `sampleBuffer` computed var |
| Create | `BufferTransformer.swift` | Resizes `RTCVideoFrame` to fit PiP window; returns `RTCVideoFrame?` wrapping `RTCYUVBuffer` |
| Create | `SampleBufferVideoCallView.swift` | UIView with `AVSampleBufferDisplayLayer` layer; `SampleBufferVideoRendering` protocol |
| Create | `PipWindowSizePolicy.swift` | `PipViewControlling` protocol; `PipWindowSizePolicy` protocol; `PipAdaptiveWindowSizePolicy`; `PipFixedWindowSizePolicy` |
| Create | `TrackStateAdapter.swift` | Combine timer re-enables track every 0.1s while PiP active |
| Create | `PipVideoRenderer.swift` | UIView + RTCVideoRenderer; Combine publisher; frame-skip logic; `track` didSet |
| Rewrite | `PipPlatformView.swift` | `PipVideoCallViewController` hosts `PipVideoRenderer`; `PipPlatformView` owns VC + controller + adapter |
| Modify | `LiveKitPipPlugin.swift` | Remove `FrameBridge`; `updateActiveTrack` → `rebindTrack`; thin `didCreatePlatformView` |
| Delete | `FrameBridge.swift` | Replaced entirely |
| Delete | `PixelBufferCompositor.swift` | Phase 2 |

---

## Task 1: Pixel range extension + YUV conversion setup

**Files:**
- Create: `YpCbCrPixelRange+Default.swift`
- Create: `YUVToARGBConversion.swift`

**Interfaces:**
- Produces: `vImage_YpCbCrPixelRange.default` static property; `YUVToARGBConversion` class with `output: vImage_YpCbCrToARGB`

- [ ] **Step 1: Create `YpCbCrPixelRange+Default.swift`**

```swift
import Accelerate
import Foundation

extension vImage_YpCbCrPixelRange {
    static let `default` = vImage_YpCbCrPixelRange(
        Yp_bias: 0,
        CbCr_bias: 128,
        YpRangeMax: 255,
        CbCrRangeMax: 255,
        YpMax: 255,
        YpMin: 1,
        CbCrMax: 255,
        CbCrMin: 0
    )
}
```

- [ ] **Step 2: Create `YUVToARGBConversion.swift`**

```swift
import Accelerate
import Foundation

final class YUVToARGBConversion {

    enum Coefficient {
        case bt601
        case bt709

        var matrix: UnsafePointer<vImage_YpCbCrToARGBMatrix> {
            switch self {
            case .bt601: return kvImage_YpCbCrToARGBMatrix_ITU_R_601_4
            case .bt709: return kvImage_YpCbCrToARGBMatrix_ITU_R_709_2
            }
        }
    }

    var output: vImage_YpCbCrToARGB

    init(
        coefficient: Coefficient = .bt601,
        inYpCbCrType: vImageYpCbCrType = kvImage420Yp8_Cb8_Cr8,
        outARGBType: vImageARGBType = kvImageARGB8888,
        flags: UInt32 = UInt32(kvImageNoFlags)
    ) {
        var pixelRange = vImage_YpCbCrPixelRange.default
        output = vImage_YpCbCrToARGB()
        vImageConvert_YpCbCrToARGB_GenerateConversion(
            coefficient.matrix,
            &pixelRange,
            &output,
            inYpCbCrType,
            outARGBType,
            flags
        )
    }
}
```

- [ ] **Step 3: Verify build**

```bash
cd livekit_pip/example && flutter build ios --no-codesign --simulator 2>&1 | grep -E "error:|warning:|Build complete"
```

Expected: no Swift compile errors for the two new files.

- [ ] **Step 4: Commit**

```bash
git add livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/YpCbCrPixelRange+Default.swift \
        livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/YUVToARGBConversion.swift
git commit -m "feat(ios): add YUV-to-ARGB conversion setup (Accelerate)"
```

---

## Task 2: Pixel buffer pool + repository

**Files:**
- Create: `PixelBufferPool.swift`
- Create: `PixelBufferRepository.swift`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `PixelBufferPool(bufferSize:pixelFormat:maxNoOfBuffers:).dequeuePixelBuffer() throws -> CVPixelBuffer`
  - `PixelBufferRepository().dequeuePixelBuffer(of:pixelFormat:) throws -> CVPixelBuffer`

- [ ] **Step 1: Create `PixelBufferPool.swift`**

```swift
import CoreVideo
import Foundation

final class PixelBufferPool {

    enum PoolError: LocalizedError {
        case unavailable
        case wouldExceedThreshold
        case unknown(CGSize)

        var errorDescription: String? {
            switch self {
            case .unavailable: return "PixelBufferPool is unavailable"
            case .wouldExceedThreshold: return "PixelBufferPool exhausted — dropping frame"
            case let .unknown(s): return "PixelBufferPool unknown error for size \(s)"
            }
        }
    }

    let maxNoOfBuffers: Int
    let bufferSize: CGSize
    let pixelFormat: OSType

    private var pool: CVPixelBufferPool?

    init(
        bufferSize: CGSize,
        pixelFormat: OSType = kCVPixelFormatType_32BGRA,
        maxNoOfBuffers: Int = 5
    ) {
        self.bufferSize = bufferSize
        self.pixelFormat = pixelFormat
        self.maxNoOfBuffers = maxNoOfBuffers

        var cvPool: CVPixelBufferPool?
        let poolAttrs: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: maxNoOfBuffers
        ]
        let bufAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(pixelFormat),
            kCVPixelBufferWidthKey as String: Int(bufferSize.width),
            kCVPixelBufferHeightKey as String: Int(bufferSize.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        CVPixelBufferPoolCreate(nil, poolAttrs as CFDictionary, bufAttrs as CFDictionary, &cvPool)
        pool = cvPool
    }

    func dequeuePixelBuffer() throws -> CVPixelBuffer {
        guard let pool else { throw PoolError.unavailable }
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        if status == kCVReturnWouldExceedAllocationThreshold {
            throw PoolError.wouldExceedThreshold
        }
        guard let pixelBuffer else { throw PoolError.unknown(bufferSize) }
        return pixelBuffer
    }
}
```

- [ ] **Step 2: Create `PixelBufferRepository.swift`**

```swift
import CoreVideo
import Foundation

final class PixelBufferRepository {

    private struct PoolKey: Hashable {
        let width: Int
        let height: Int
        let pixelFormat: OSType

        init(_ size: CGSize, pixelFormat: OSType) {
            width = Int(size.width)
            height = Int(size.height)
            self.pixelFormat = pixelFormat
        }
    }

    private var pools: [PoolKey: PixelBufferPool] = [:]
    private let queue = UnfairQueue()

    func dequeuePixelBuffer(
        of size: CGSize,
        pixelFormat: OSType = kCVPixelFormatType_32BGRA
    ) throws -> CVPixelBuffer {
        let key = PoolKey(size, pixelFormat: pixelFormat)
        return try queue.sync {
            let pool: PixelBufferPool
            if let existing = pools[key] {
                pool = existing
            } else {
                pool = PixelBufferPool(bufferSize: size, pixelFormat: pixelFormat)
                pools[key] = pool
            }
            return try pool.dequeuePixelBuffer()
        }
    }
}

final class UnfairQueue {
    private let lock: os_unfair_lock_t

    init() {
        lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
    }

    deinit { lock.deallocate() }

    func sync<T>(_ block: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return try block()
    }
}
```

- [ ] **Step 3: Verify build**

```bash
cd livekit_pip/example && flutter build ios --no-codesign --simulator 2>&1 | grep -E "error:|Build complete"
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/PixelBufferPool.swift \
        livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/PixelBufferRepository.swift
git commit -m "feat(ios): add pixel buffer pool and repository"
```

---

## Task 3: RTCYUVBuffer — hardware-accelerated YUV→BGRA

**Files:**
- Create: `RTCYUVBuffer.swift`

**Interfaces:**
- Consumes: `PixelBufferRepository`, `YUVToARGBConversion`; `RTCI420Buffer`, `RTCCVPixelBuffer`, `RTCVideoFrameBuffer` from WebRTC
- Produces:
  - `RTCYUVBuffer(source:conversion:)` — NSObject, RTCVideoFrameBuffer
  - `RTCYUVBuffer.pixelBuffer: CVPixelBuffer?`
  - `RTCYUVBuffer.sampleBuffer: CMSampleBuffer?`
  - `RTCYUVBuffer.resize(to:) -> RTCYUVBuffer?`

- [ ] **Step 1: Create `RTCYUVBuffer.swift`**

```swift
import Accelerate
import CoreVideo
import Foundation
import WebRTC

final class RTCYUVBuffer: NSObject, RTCVideoFrameBuffer {

    private let pixelBufferRepository = PixelBufferRepository()
    private let source: RTCVideoFrameBuffer
    private let conversion: YUVToARGBConversion

    var width: Int32 { source.width }
    var height: Int32 { source.height }

    private lazy var i420ToYUVPixelBuffer = buildI420ToYUVPixelBuffer()

    init(
        source: RTCVideoFrameBuffer,
        conversion: YUVToARGBConversion = .init()
    ) {
        self.source = source
        self.conversion = conversion
    }

    func toI420() -> any RTCI420BufferProtocol {
        if let i420 = source as? RTCI420Buffer { return i420 }
        return source.toI420()
    }

    func resize(to targetSize: CGSize) -> RTCYUVBuffer? {
        if let i420 = source as? RTCI420Buffer {
            let resized = i420.cropAndScale(
                with: 0, offsetY: 0,
                cropWidth: Int32(source.width), cropHeight: Int32(source.height),
                scaleWidth: Int32(targetSize.width), scaleHeight: Int32(targetSize.height)
            )
            return .init(source: resized, conversion: conversion)
        } else if let cvBuffer = source as? RTCCVPixelBuffer,
                  let dequeued = try? pixelBufferRepository.dequeuePixelBuffer(
                      of: targetSize,
                      pixelFormat: CVPixelBufferGetPixelFormatType(cvBuffer.pixelBuffer)
                  ) {
            let count = cvBuffer.bufferSizeForCroppingAndScaling(
                toWidth: Int32(targetSize.width), height: Int32(targetSize.height))
            let tmp: UnsafeMutableRawPointer? = malloc(Int(count))
            cvBuffer.cropAndScale(to: dequeued, withTempBuffer: tmp)
            tmp?.deallocate()
            return .init(source: RTCCVPixelBuffer(pixelBuffer: dequeued))
        }
        return nil
    }

    var pixelBuffer: CVPixelBuffer? {
        if source is RTCI420Buffer { return i420ToYUVPixelBuffer }
        if let cvBuffer = source as? RTCCVPixelBuffer { return cvBuffer.pixelBuffer }
        return nil
    }

    var sampleBuffer: CMSampleBuffer? {
        guard let pixelBuffer else { return nil }
        var timingInfo = CMSampleTimingInfo()
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard let formatDescription else { return nil }
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        guard let buffer = sampleBuffer else { return nil }
        let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true) as! CFArray
        let dict = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
        CFDictionarySetValue(
            dict,
            Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
            Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
        )
        return buffer
    }

    private func buildI420ToYUVPixelBuffer() -> CVPixelBuffer? {
        guard let i420 = source as? RTCI420Buffer,
              let pixelBuffer = try? pixelBufferRepository.dequeuePixelBuffer(
                  of: CGSize(width: Int(width), height: Int(height))
              )
        else { return nil }

        var Yp = vImage_Buffer(
            data: UnsafeMutablePointer(mutating: i420.dataY),
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: Int(i420.strideY)
        )
        var Cb = vImage_Buffer(
            data: UnsafeMutablePointer(mutating: i420.dataU),
            height: vImagePixelCount(i420.chromaHeight),
            width: vImagePixelCount(i420.chromaWidth),
            rowBytes: Int(i420.strideU)
        )
        var Cr = vImage_Buffer(
            data: UnsafeMutablePointer(mutating: i420.dataV),
            height: vImagePixelCount(i420.chromaHeight),
            width: vImagePixelCount(i420.chromaWidth),
            rowBytes: Int(i420.strideV)
        )
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        var output = vImage_Buffer(
            data: CVPixelBufferGetBaseAddress(pixelBuffer)!,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: CVPixelBufferGetBytesPerRow(pixelBuffer)
        )
        let error = vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(
            &Yp, &Cb, &Cr, &output, &conversion.output,
            [3, 2, 1, 0], 255, vImage_Flags(kvImageNoFlags)
        )
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

        return error == kvImageNoError ? pixelBuffer : nil
    }
}
```

- [ ] **Step 2: Verify build**

```bash
cd livekit_pip/example && flutter build ios --no-codesign --simulator 2>&1 | grep -E "error:|Build complete"
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/RTCYUVBuffer.swift
git commit -m "feat(ios): add RTCYUVBuffer with Accelerate vImage I420→BGRA conversion"
```

---

## Task 4: BufferTransformer

**Files:**
- Create: `BufferTransformer.swift`

**Interfaces:**
- Consumes: `RTCYUVBuffer`, `RTCI420Buffer`, `RTCVideoFrame`, `RTCVideoFrameBuffer` from WebRTC
- Produces:
  - `BufferTransformer` struct with `requiresResize: Bool`
  - `transformAndResizeIfRequired(_:targetSize:) -> RTCVideoFrame?`

- [ ] **Step 1: Create `BufferTransformer.swift`**

```swift
import Foundation
import WebRTC

struct BufferTransformer {

    var requiresResize = false

    func transformAndResizeIfRequired(
        _ frame: RTCVideoFrame,
        targetSize: CGSize
    ) -> RTCVideoFrame? {
        // Always prefer I420 path (RTCCVPixelBuffer has known rendering issues per template).
        let buffer: RTCVideoFrameBuffer = (frame.buffer as? RTCI420Buffer) ?? frame.buffer
        guard let yuvBuffer = transformBuffer(buffer, targetSize: targetSize) else { return nil }
        return RTCVideoFrame(
            buffer: yuvBuffer,
            rotation: frame.rotation,
            timeStampNs: frame.timeStampNs
        )
    }

    private func transformBuffer(
        _ source: RTCVideoFrameBuffer,
        targetSize: CGSize
    ) -> RTCYUVBuffer? {
        if requiresResize {
            let sourceSize = CGSize(width: CGFloat(source.width), height: CGFloat(source.height))
            return RTCYUVBuffer(source: source)
                .resize(to: resizeSize(sourceSize, toFitWithin: targetSize))
        }
        return RTCYUVBuffer(source: source)
    }

    private func resizeSize(_ size: CGSize, toFitWithin container: CGSize) -> CGSize {
        let ratio = min(container.width / size.width, container.height / size.height)
        return CGSize(width: size.width * ratio, height: size.height * ratio)
    }
}
```

- [ ] **Step 2: Verify build**

```bash
cd livekit_pip/example && flutter build ios --no-codesign --simulator 2>&1 | grep -E "error:|Build complete"
```

- [ ] **Step 3: Commit**

```bash
git add livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/BufferTransformer.swift
git commit -m "feat(ios): add BufferTransformer for RTCVideoFrame resize/conversion"
```

---

## Task 5: SampleBufferVideoCallView

**Files:**
- Create: `SampleBufferVideoCallView.swift`

**Interfaces:**
- Produces:
  - `SampleBufferVideoCallView: UIView` — `layerClass = AVSampleBufferDisplayLayer`
  - `SampleBufferVideoCallView.renderingComponent: SampleBufferVideoRendering`
  - `protocol SampleBufferVideoRendering` — `isReadyForMoreMediaData`, `flush()`, `enqueue(_:)`, `requiresFlushToResumeDecoding` (iOS 14+)

- [ ] **Step 1: Create `SampleBufferVideoCallView.swift`**

```swift
import AVKit
import UIKit

final class SampleBufferVideoCallView: UIView {

    override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }

    private var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
        // swiftlint:disable:next force_cast
        layer as! AVSampleBufferDisplayLayer
    }

    var renderingComponent: SampleBufferVideoRendering {
        if #available(iOS 17.0, *) {
            return sampleBufferDisplayLayer.sampleBufferRenderer
        }
        return sampleBufferDisplayLayer
    }

    var videoGravity: AVLayerVideoGravity {
        get { sampleBufferDisplayLayer.videoGravity }
        set { sampleBufferDisplayLayer.videoGravity = newValue }
    }

    var preventsDisplaySleepDuringVideoPlayback: Bool {
        get { sampleBufferDisplayLayer.preventsDisplaySleepDuringVideoPlayback }
        set { sampleBufferDisplayLayer.preventsDisplaySleepDuringVideoPlayback = newValue }
    }
}

protocol SampleBufferVideoRendering {
    @available(iOS 14.0, *)
    var requiresFlushToResumeDecoding: Bool { get }
    var isReadyForMoreMediaData: Bool { get }
    func flush()
    func enqueue(_ sampleBuffer: CMSampleBuffer)
}

extension AVSampleBufferDisplayLayer: SampleBufferVideoRendering {}

@available(iOS 17.0, *)
extension AVSampleBufferVideoRenderer: SampleBufferVideoRendering {}
```

- [ ] **Step 2: Verify build**

```bash
cd livekit_pip/example && flutter build ios --no-codesign --simulator 2>&1 | grep -E "error:|Build complete"
```

- [ ] **Step 3: Commit**

```bash
git add livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/SampleBufferVideoCallView.swift
git commit -m "feat(ios): add SampleBufferVideoCallView and SampleBufferVideoRendering protocol"
```

---

## Task 6: PipWindowSizePolicy

**Files:**
- Create: `PipWindowSizePolicy.swift`

**Interfaces:**
- Produces:
  - `protocol PipViewControlling: AnyObject` — `var preferredContentSize: CGSize { get set }`
  - `protocol PipWindowSizePolicy` — `trackSize: CGSize`, `controller: PipViewControlling?`
  - `PipAdaptiveWindowSizePolicy: PipWindowSizePolicy` — updates `controller.preferredContentSize` on `trackSize` change
  - `PipFixedWindowSizePolicy: PipWindowSizePolicy` — sets fixed size when `controller` is assigned

- [ ] **Step 1: Create `PipWindowSizePolicy.swift`**

```swift
import Foundation

protocol PipViewControlling: AnyObject {
    var preferredContentSize: CGSize { get set }
}

protocol PipWindowSizePolicy {
    var trackSize: CGSize { get set }
    var controller: PipViewControlling? { get set }
}

final class PipAdaptiveWindowSizePolicy: PipWindowSizePolicy {
    var trackSize: CGSize = .zero {
        didSet {
            guard trackSize != oldValue, trackSize != .zero else { return }
            controller?.preferredContentSize = trackSize
        }
    }
    weak var controller: PipViewControlling?
}

final class PipFixedWindowSizePolicy: PipWindowSizePolicy {
    var trackSize: CGSize = .zero
    weak var controller: PipViewControlling? {
        didSet { controller?.preferredContentSize = fixedSize }
    }
    private let fixedSize: CGSize
    init(_ fixedSize: CGSize = .init(width: 640, height: 480)) {
        self.fixedSize = fixedSize
    }
}
```

- [ ] **Step 2: Verify build**

```bash
cd livekit_pip/example && flutter build ios --no-codesign --simulator 2>&1 | grep -E "error:|Build complete"
```

- [ ] **Step 3: Commit**

```bash
git add livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/PipWindowSizePolicy.swift
git commit -m "feat(ios): add PipWindowSizePolicy (adaptive + fixed) and PipViewControlling protocol"
```

---

## Task 7: TrackStateAdapter

**Files:**
- Create: `TrackStateAdapter.swift`

**Interfaces:**
- Consumes: `RTCVideoTrack` from WebRTC; `Combine`
- Produces:
  - `TrackStateAdapter` with `isEnabled: Bool` and `activeTrack: RTCVideoTrack?`
  - When `isEnabled = true`: starts 0.1s Combine timer that calls `activeTrack.isEnabled = true` if it drifted to false

- [ ] **Step 1: Create `TrackStateAdapter.swift`**

```swift
import Combine
import Foundation
import WebRTC

final class TrackStateAdapter {

    var isEnabled: Bool = false {
        didSet {
            guard isEnabled != oldValue else { return }
            enableObserver(isEnabled)
        }
    }

    var activeTrack: RTCVideoTrack? {
        didSet {
            guard isEnabled, oldValue?.trackId != activeTrack?.trackId else { return }
            oldValue?.isEnabled = false
        }
    }

    private var observerCancellable: AnyCancellable?

    private func enableObserver(_ active: Bool) {
        if active {
            observerCancellable = Timer
                .publish(every: 0.1, on: .main, in: .default)
                .autoconnect()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.checkTracksState() }
        } else {
            observerCancellable?.cancel()
            observerCancellable = nil
        }
    }

    private func checkTracksState() {
        guard let track = activeTrack, !track.isEnabled else { return }
        activeTrack?.isEnabled = true
    }
}
```

- [ ] **Step 2: Verify build**

```bash
cd livekit_pip/example && flutter build ios --no-codesign --simulator 2>&1 | grep -E "error:|Build complete"
```

- [ ] **Step 3: Commit**

```bash
git add livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/TrackStateAdapter.swift
git commit -m "feat(ios): add TrackStateAdapter to keep track enabled during PiP"
```

---

## Task 8: PipVideoRenderer

**Files:**
- Create: `PipVideoRenderer.swift`

**Interfaces:**
- Consumes: `SampleBufferVideoCallView`, `BufferTransformer`, `RTCYUVBuffer`, `PipWindowSizePolicy`; `RTCVideoTrack`, `RTCVideoRenderer`, `RTCVideoFrame` from WebRTC; `Combine`
- Produces:
  - `PipVideoRenderer: UIView, RTCVideoRenderer`
  - `init(windowSizePolicy: PipWindowSizePolicy)`
  - `var track: RTCVideoTrack?` — setting starts/stops frame streaming
  - `var displayLayer: CALayer` — the AVSampleBufferDisplayLayer backing layer (used by PipPlatformView to pass to ContentSource if needed)
  - `var pictureInPictureWindowSizePolicy: PipWindowSizePolicy`
  - `setSize(_:)`, `renderFrame(_:)` — RTCVideoRenderer conformance

- [ ] **Step 1: Create `PipVideoRenderer.swift`**

```swift
import AVKit
import Combine
import Foundation
import UIKit
import WebRTC

final class PipVideoRenderer: UIView, RTCVideoRenderer {

    // Setting this starts/stops frame streaming without recreating the display layer.
    var track: RTCVideoTrack? {
        didSet {
            guard oldValue !== track else { return }
            prepareForTrackRendering(oldValue)
        }
    }

    var displayLayer: CALayer { contentView.layer }
    var pictureInPictureWindowSizePolicy: PipWindowSizePolicy

    private let bufferPublisher: PassthroughSubject<CMSampleBuffer, Never> = .init()

    private lazy var contentView: SampleBufferVideoCallView = {
        let v = SampleBufferVideoCallView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.contentMode = .scaleAspectFill
        v.videoGravity = .resizeAspectFill
        v.preventsDisplaySleepDuringVideoPlayback = true
        return v
    }()

    private var bufferTransformer = BufferTransformer()
    private var bufferUpdatesCancellable: AnyCancellable?

    // Accessed from WebRTC thread AND main thread; written only on WebRTC thread.
    private var contentSize: CGSize = .zero
    private var trackSize: CGSize = .zero {
        didSet {
            guard trackSize != oldValue else { return }
            didUpdateTrackSize()
        }
    }
    private var requiresResize = false {
        didSet { bufferTransformer.requiresResize = requiresResize }
    }
    private var noOfFramesToSkipAfterRendering = 1
    private var skippedFrames = 0
    private var shouldRenderFrame: Bool { skippedFrames == 0 && trackSize != .zero }

    private let resizeRequiredSizeRatioThreshold: CGFloat = 1
    private let sizeRatioThreshold: CGFloat = 15

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    init(windowSizePolicy: PipWindowSizePolicy) {
        pictureInPictureWindowSizePolicy = windowSizePolicy
        super.init(frame: .zero)
        addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Window lifecycle (gates frame delivery)

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow != nil {
            startFrameStreaming(for: track, on: newWindow)
        } else {
            stopFrameStreaming(for: track)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentSize = frame.size
    }

    // MARK: - RTCVideoRenderer

    func setSize(_ size: CGSize) { trackSize = size }

    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame else { return }
        trackSize = CGSize(width: CGFloat(frame.width), height: CGFloat(frame.height))
        defer { handleFrameSkippingIfRequired() }
        guard shouldRenderFrame else { return }
        guard let transformed = bufferTransformer.transformAndResizeIfRequired(
            frame, targetSize: contentSize
        ),
        let yuvBuffer = transformed.buffer as? RTCYUVBuffer,
        let sampleBuffer = yuvBuffer.sampleBuffer
        else { return }
        bufferPublisher.send(sampleBuffer)
    }

    // MARK: - Private

    private func process(_ buffer: CMSampleBuffer) {
        guard bufferUpdatesCancellable != nil, buffer.isValid else {
            contentView.renderingComponent.flush()
            return
        }
        if #available(iOS 14.0, *),
           contentView.renderingComponent.requiresFlushToResumeDecoding {
            contentView.renderingComponent.flush()
        }
        if contentView.renderingComponent.isReadyForMoreMediaData {
            contentView.renderingComponent.enqueue(buffer)
        }
    }

    private func startFrameStreaming(for track: RTCVideoTrack?, on window: UIWindow?) {
        guard window != nil, let track else { return }
        bufferUpdatesCancellable = bufferPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.process($0) }
        track.add(self)
    }

    private func stopFrameStreaming(for track: RTCVideoTrack?) {
        guard bufferUpdatesCancellable != nil else { return }
        bufferUpdatesCancellable?.cancel()
        bufferUpdatesCancellable = nil
        track?.remove(self)
        contentView.renderingComponent.flush()
    }

    private func didUpdateTrackSize() {
        guard contentSize != .zero, trackSize != .zero else { return }
        let wRatio = trackSize.width / contentSize.width
        let hRatio = trackSize.height / contentSize.height
        requiresResize = wRatio >= resizeRequiredSizeRatioThreshold
                      || hRatio >= resizeRequiredSizeRatioThreshold
        let needsSkip = wRatio >= sizeRatioThreshold || hRatio >= sizeRatioThreshold
        noOfFramesToSkipAfterRendering = needsSkip
            ? max(Int(max(Int(wRatio), Int(hRatio)) / 2), 1) : 0
        skippedFrames = 0
        pictureInPictureWindowSizePolicy.trackSize = trackSize
    }

    private func handleFrameSkippingIfRequired() {
        if noOfFramesToSkipAfterRendering > 0 {
            skippedFrames = skippedFrames == noOfFramesToSkipAfterRendering ? 0 : skippedFrames + 1
        } else if skippedFrames > 0 {
            skippedFrames = 0
        }
    }

    private func prepareForTrackRendering(_ oldTrack: RTCVideoTrack?) {
        stopFrameStreaming(for: oldTrack)
        noOfFramesToSkipAfterRendering = 0
        skippedFrames = 0
        requiresResize = false
        startFrameStreaming(for: track, on: window)
    }
}
```

- [ ] **Step 2: Verify build**

```bash
cd livekit_pip/example && flutter build ios --no-codesign --simulator 2>&1 | grep -E "error:|Build complete"
```

Expected: no errors. `PipVideoRenderer` uses all previously created types — if any name is wrong, it surfaces here.

- [ ] **Step 3: Commit**

```bash
git add livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/PipVideoRenderer.swift
git commit -m "feat(ios): add PipVideoRenderer (UIView+RTCVideoRenderer, Combine delivery)"
```

---

## Task 9: Rewrite PipPlatformView

**Files:**
- Rewrite: `PipPlatformView.swift`

**Interfaces:**
- Consumes: `PipVideoRenderer`, `PipAdaptiveWindowSizePolicy`, `PipViewControlling`, `TrackStateAdapter`, `NativeTrackResolver`, `FlutterWebRTCTrackResolver`
- Produces:
  - `PipPlatformView: NSObject, FlutterPlatformView`
  - `func rebindTrack(trackId: String)` — resolves via `NativeTrackResolver`, sets `pipVC.videoRenderer.track`
  - `func startPictureInPicture()`, `func stopPictureInPicture()`
  - `var onStateChanged: ((Int) -> Void)?`
  - Removes: `displayLayer`, `frameBridge`, `updateContentSize`

- [ ] **Step 1: Rewrite `PipPlatformView.swift`**

Replace the entire file content with:

```swift
import AVFoundation
import AVKit
import Flutter
import WebRTC

// Hosts PipVideoRenderer as its full-frame content view.
// PipAdaptiveWindowSizePolicy updates preferredContentSize when track size changes.
// preferredContentSize must always be > .zero to avoid PGPegasus -1003 crash.
private final class PipVideoCallViewController:
    AVPictureInPictureVideoCallViewController,
    PipViewControlling
{
    private(set) var videoRenderer: PipVideoRenderer

    init() {
        let policy = PipAdaptiveWindowSizePolicy()
        let renderer = PipVideoRenderer(windowSizePolicy: policy)
        videoRenderer = renderer
        super.init(nibName: nil, bundle: nil)
        policy.controller = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        videoRenderer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(videoRenderer)
        NSLayoutConstraint.activate([
            videoRenderer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoRenderer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoRenderer.topAnchor.constraint(equalTo: view.topAnchor),
            videoRenderer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        preferredContentSize = CGSize(width: 320, height: 180) // 16:9 until first frame
    }
}

// containerView is the AVPictureInPictureController activeVideoCallSourceView.
// Actual rendering happens in PipVideoCallViewController.videoRenderer.
// Never recreate pipController or the display layer mid-call.
class PipPlatformView: NSObject, FlutterPlatformView {

    private let containerView: UIView
    private let pipVC = PipVideoCallViewController()
    private var pipController: AVPictureInPictureController?
    private let trackStateAdapter = TrackStateAdapter()
    private let resolver: NativeTrackResolver

    var onStateChanged: ((Int) -> Void)?

    init(
        frame: CGRect,
        viewId: Int64,
        args: Any?,
        resolver: NativeTrackResolver = FlutterWebRTCTrackResolver()
    ) {
        containerView = UIView(frame: frame)
        containerView.backgroundColor = .clear
        containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.resolver = resolver
        super.init()

        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        let source = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: containerView,
            contentViewController: pipVC
        )
        pipController = AVPictureInPictureController(contentSource: source)
        pipController?.delegate = self
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true
    }

    func view() -> UIView { containerView }

    func rebindTrack(trackId: String) {
        let resolved = resolver.resolveVideoTrack(trackId: trackId)
        pipVC.videoRenderer.track = resolved
        trackStateAdapter.activeTrack = resolved
        if resolved == nil {
            print("[livekit_pip] rebindTrack: \(trackId) not found — holding last frame")
        }
    }

    func startPictureInPicture() {
        guard let ctrl = pipController else {
            print("[livekit_pip] startPiP: pipController is nil")
            return
        }
        print("[livekit_pip] startPiP: possible=\(ctrl.isPictureInPicturePossible)")
        ctrl.startPictureInPicture()
    }

    func stopPictureInPicture() {
        pipController?.stopPictureInPicture()
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PipPlatformView: AVPictureInPictureControllerDelegate {

    func pictureInPictureControllerWillStartPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        onStateChanged?(2) // entering
    }

    func pictureInPictureControllerDidStartPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        trackStateAdapter.isEnabled = true
        onStateChanged?(3) // active
    }

    func pictureInPictureControllerWillStopPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        onStateChanged?(4) // exiting
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        trackStateAdapter.isEnabled = false
        onStateChanged?(1) // inactive
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        print("[livekit_pip] PiP failed to start: \(error.localizedDescription)")
        onStateChanged?(1) // inactive
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
    }
}
```

- [ ] **Step 2: Verify build**

```bash
cd livekit_pip/example && flutter build ios --no-codesign --simulator 2>&1 | grep -E "error:|Build complete"
```

Expected: errors for `FrameBridge` references still in `LiveKitPipPlugin.swift` — that's fine, Task 10 fixes them.

- [ ] **Step 3: Commit**

```bash
git add livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/PipPlatformView.swift
git commit -m "feat(ios): rewrite PipPlatformView to use PipVideoRenderer (remove FrameBridge)"
```

---

## Task 10: Update LiveKitPipPlugin + delete old files

**Files:**
- Modify: `LiveKitPipPlugin.swift`
- Delete: `FrameBridge.swift`
- Delete: `PixelBufferCompositor.swift`

**Interfaces:**
- Consumes: `PipPlatformView.rebindTrack(trackId:)`, `PipPlatformView.startPictureInPicture()`, `PipPlatformView.stopPictureInPicture()`
- Removes: `FrameBridge` entirely from the plugin; `frameBridge` property; bridge wiring in `didCreatePlatformView`

- [ ] **Step 1: Rewrite `LiveKitPipPlugin.swift`**

Replace the entire file content with:

```swift
import AVKit
import Flutter

public class LiveKitPipPlugin: NSObject, FlutterPlugin, LiveKitPipHostApi {

    private var stateEventSink: FlutterEventSink?
    private weak var platformView: PipPlatformView?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let instance = LiveKitPipPlugin()
        LiveKitPipHostApiSetup.setUp(binaryMessenger: messenger, api: instance)
        FlutterEventChannel(name: "livekit_pip/state", binaryMessenger: messenger)
            .setStreamHandler(instance)
        registrar.register(
            PipPlatformViewFactory(plugin: instance),
            withId: "livekit_pip_view"
        )
        registrar.publish(instance)
    }

    // MARK: - LiveKitPipHostApi

    func isSupported() -> Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    func initialize(request: PipInitRequest) {
        // Phase 2: wire request.iosIncludeLocalParticipantVideo for self-view inset
    }

    func enterPip() {
        guard let pv = platformView else {
            print("[livekit_pip] enterPip: platformView is nil — view not in tree?")
            return
        }
        pv.startPictureInPicture()
    }

    func exitPip() {
        platformView?.stopPictureInPicture()
    }

    func dispose() {
        platformView?.stopPictureInPicture()
    }

    func updateActiveTrack(trackId: String) {
        platformView?.rebindTrack(trackId: trackId)
    }

    // MARK: - Called by PipPlatformViewFactory

    func didCreatePlatformView(_ view: PipPlatformView) {
        platformView = view
        view.onStateChanged = { [weak self] ordinal in
            self?.stateEventSink?(ordinal)
        }
    }
}

// MARK: - FlutterStreamHandler

extension LiveKitPipPlugin: FlutterStreamHandler {

    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        stateEventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stateEventSink = nil
        return nil
    }
}
```

- [ ] **Step 2: Delete `FrameBridge.swift`**

```bash
rm livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/FrameBridge.swift
```

- [ ] **Step 3: Delete `PixelBufferCompositor.swift`**

```bash
rm livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/PixelBufferCompositor.swift
```

- [ ] **Step 4: Verify build — must be clean**

```bash
cd livekit_pip/example && flutter build ios --no-codesign --simulator 2>&1 | grep -E "error:|Build complete"
```

Expected: `Build complete!` with no errors.

- [ ] **Step 5: Commit**

```bash
git add livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/LiveKitPipPlugin.swift
git rm livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/FrameBridge.swift
git rm livekit_pip_ios/ios/livekit_pip_ios/Sources/livekit_pip_ios/PixelBufferCompositor.swift
git commit -m "feat(ios): remove FrameBridge, update plugin to use rebindTrack"
```

---

## Task 11: Device smoke test

**Manual test — requires a physical iOS device (PiP not supported in simulator).**

- [ ] **Step 1: Run the example app on a device**

```bash
cd livekit_pip/example
flutter run -d <your-device-id>
```

- [ ] **Step 2: Connect to a LiveKit room with at least one remote participant publishing video**

Use the example app's connect UI.

- [ ] **Step 3: Verify no hang on initialization**

After `LiveKitPip.initialize(room: room, config: config)` is called, the app should remain responsive. Previously it would freeze on first frame.

- [ ] **Step 4: Tap "Enter PiP" (or background the app)**

The PiP window should appear immediately showing the remote participant's video.

- [ ] **Step 5: Verify PiP window shows live video**

The PiP window should display moving video — not a black screen, not a frozen frame.

- [ ] **Step 6: Switch dominant speaker**

The `ActiveSpeakerSelector` emits a new track ID → `rebindTrack` is called → `PipVideoRenderer.track` is set to the new track → video switches without recreating the PiP window.

- [ ] **Step 7: Stop PiP / foreground the app**

PiP dismisses cleanly. State stream emits `exiting` then `inactive`.

- [ ] **Step 8: Commit any debug-print cleanup if needed**

```bash
git add -p
git commit -m "chore(ios): remove debug prints after smoke test"
```
