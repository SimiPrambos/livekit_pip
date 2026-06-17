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
    private var pixelBufferPool: CVPixelBufferPool?
    private var poolWidth: Int32 = 0
    private var poolHeight: Int32 = 0
    private var includeLocalVideo = true

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

    func detach() {
        currentTrack?.remove(self)
        currentTrack = nil
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
            // I420 path — convert to BGRA
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
        // Use vImage or a simple byte-copy via RTCI420Buffer
        if let i420 = frame.buffer as? RTCI420Buffer {
            let dstPtr = CVPixelBufferGetBaseAddress(dst)!
            let dstStride = CVPixelBufferGetBytesPerRow(dst)
            // Basic I420→BGRA conversion (Y-plane only for now; full conversion in production)
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
        CMVideoFormatDescriptionCreateForImageBuffer(nil, pixelBuffer, &formatDesc)
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
}

// ──── RTCVideoRenderer ─────────────────────────────────────────────────────

extension FrameBridge: RTCVideoRenderer {

    func setSize(_ size: CGSize) {}

    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame = frame,
              let pb = pixelBuffer(from: frame),
              let sb = makeSampleBuffer(from: pb)
        else { return }
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(sb)
    }
}
