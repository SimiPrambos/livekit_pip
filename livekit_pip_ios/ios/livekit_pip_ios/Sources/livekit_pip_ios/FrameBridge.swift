import AVFoundation
import CoreImage
import WebRTC

/// Bridges RTCVideoFrame → CVPixelBuffer → CMSampleBuffer → AVSampleBufferDisplayLayer.
///
/// Never recreate AVSampleBufferDisplayLayer or AVPictureInPictureController mid-call.
/// Rebind by calling rebindTrack(trackId:) instead.
class FrameBridge: NSObject {

    private let displayLayer: AVSampleBufferDisplayLayer
    private let resolver: NativeTrackResolver
    private var currentTrack: RTCVideoTrack?
    private var localTrack: RTCVideoTrack?
    private var pixelBufferPool: CVPixelBufferPool?
    private var poolWidth: Int32 = 0
    private var poolHeight: Int32 = 0
    private var includeLocalVideo = true
    private var localCameraActive = false
    private let compositor = PixelBufferCompositor()

    // Held so ARC keeps the local-camera renderer alive
    private var localRenderer: _LocalRenderer?

    init(
        displayLayer: AVSampleBufferDisplayLayer,
        resolver: NativeTrackResolver = FlutterWebRTCTrackResolver()
    ) {
        self.displayLayer = displayLayer
        self.resolver = resolver
    }

    func configure(includeLocalVideo: Bool) {
        self.includeLocalVideo = includeLocalVideo
    }

    /// Binds to a new dominant-speaker track without recreating the display layer.
    func rebindTrack(trackId: String) {
        currentTrack?.remove(self)
        currentTrack = resolver.resolveVideoTrack(trackId: trackId)
        if let track = currentTrack {
            track.add(self)
        } else {
            print("[livekit_pip] FrameBridge: track \(trackId) not found — holding last frame")
        }
    }

    /// Binds the local camera track for self-view compositing.
    func rebindLocalTrack(trackId: String) {
        if let renderer = localRenderer {
            localTrack?.remove(renderer)
        }
        localTrack = resolver.resolveVideoTrack(trackId: trackId)
        let renderer = _LocalRenderer(bridge: self)
        localRenderer = renderer
        localTrack?.add(renderer)
        localCameraActive = true
    }

    func setLocalCameraActive(_ active: Bool) {
        localCameraActive = active
    }

    func detach() {
        currentTrack?.remove(self)
        currentTrack = nil
        if let renderer = localRenderer {
            localTrack?.remove(renderer)
        }
        localTrack = nil
        localRenderer = nil
        pixelBufferPool = nil
    }

    // ──── Pixel buffer pool ────────────────────────────────────────────────

    private func ensurePool(width: Int32, height: Int32) {
        guard width != poolWidth || height != poolHeight else { return }
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ]
        CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &pixelBufferPool)
        poolWidth = width
        poolHeight = height
    }

    private func pixelBuffer(from frame: RTCVideoFrame) -> CVPixelBuffer? {
        guard let buffer = frame.buffer as? RTCCVPixelBuffer else {
            return i420ToBGRA(frame: frame)
        }
        return buffer.pixelBuffer
    }

    private func i420ToBGRA(frame: RTCVideoFrame) -> CVPixelBuffer? {
        let w = frame.width
        let h = frame.height
        ensurePool(width: w, height: h)
        guard let pool = pixelBufferPool else { return nil }
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
        guard let dst = pb else { return nil }
        CVPixelBufferLockBaseAddress(dst, [])
        defer { CVPixelBufferUnlockBaseAddress(dst, []) }
        if let i420 = frame.buffer as? RTCI420Buffer {
            let dstPtr = CVPixelBufferGetBaseAddress(dst)!
            let dstStride = CVPixelBufferGetBytesPerRow(dst)
            for row in 0..<Int(h) {
                let srcY = i420.dataY.advanced(by: row * Int(i420.strideY))
                let dstRow = dstPtr.advanced(by: row * dstStride).assumingMemoryBound(to: UInt8.self)
                for col in 0..<Int(w) {
                    let y = Int(srcY[col])
                    dstRow[col * 4 + 0] = UInt8(clamping: y) // B
                    dstRow[col * 4 + 1] = UInt8(clamping: y) // G
                    dstRow[col * 4 + 2] = UInt8(clamping: y) // R
                    dstRow[col * 4 + 3] = 255               // A
                }
            }
        }
        return dst
    }

    private func makeSampleBuffer(from pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
        var formatDesc: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDesc
        )
        guard let fd = formatDesc else { return nil }
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateForImageBuffer(
            allocator: nil,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: fd,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        return sampleBuffer
    }

    // Called by the local renderer when a self-view frame arrives
    fileprivate var latestLocalBuffer: CVPixelBuffer?

    fileprivate func enqueue(dominantBuffer: CVPixelBuffer) {
        let finalBuffer: CVPixelBuffer
        if includeLocalVideo, localCameraActive, let localBuf = latestLocalBuffer {
            finalBuffer = compositor.composite(dominant: dominantBuffer, selfView: localBuf)
        } else {
            finalBuffer = dominantBuffer
        }
        guard let sb = makeSampleBuffer(from: finalBuffer) else { return }
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(sb)
    }
}

// ──── RTCVideoRenderer (dominant speaker) ─────────────────────────────────

extension FrameBridge: RTCVideoRenderer {

    func setSize(_ size: CGSize) {}

    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame = frame,
              let pb = pixelBuffer(from: frame)
        else { return }
        enqueue(dominantBuffer: pb)
    }
}

// ──── Local camera renderer ────────────────────────────────────────────────

private class _LocalRenderer: NSObject, RTCVideoRenderer {
    weak var bridge: FrameBridge?
    init(bridge: FrameBridge) { self.bridge = bridge }
    func setSize(_ size: CGSize) {}
    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame = frame,
              let buffer = frame.buffer as? RTCCVPixelBuffer
        else { return }
        bridge?.latestLocalBuffer = buffer.pixelBuffer
    }
}
