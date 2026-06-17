import AVFoundation
import CoreImage
import Metal

/// Composites two CVPixelBuffers into one: dominant speaker fills the frame,
/// self-view inset is scaled to 20% of width and placed at the bottom-right.
///
/// Uses a CIContext backed by a Metal device for GPU compositing.
class PixelBufferCompositor {

    private let context: CIContext
    private var outputPool: CVPixelBufferPool?
    private var poolWidth: Int = 0
    private var poolHeight: Int = 0

    init() {
        if let device = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: device, options: [.workingColorSpace: NSNull()])
        } else {
            context = CIContext(options: [.workingColorSpace: NSNull()])
        }
    }

    /// Composites [dominant] and [selfView] buffers.
    ///
    /// Returns a single output buffer with selfView inset at bottom-right,
    /// or [dominant] unchanged if compositing is not possible.
    func composite(dominant: CVPixelBuffer, selfView: CVPixelBuffer) -> CVPixelBuffer {
        let dstW = CVPixelBufferGetWidth(dominant)
        let dstH = CVPixelBufferGetHeight(dominant)

        guard let output = allocateBuffer(width: dstW, height: dstH) else {
            return dominant
        }

        let dominantImage = CIImage(cvPixelBuffer: dominant)
        let selfImage = CIImage(cvPixelBuffer: selfView)

        // Scale self-view to 20% of output width, preserve aspect ratio
        let insetW = CGFloat(dstW) * 0.20
        let svW = CGFloat(CVPixelBufferGetWidth(selfView))
        let svH = CGFloat(CVPixelBufferGetHeight(selfView))
        let scale = (svW > 0) ? insetW / svW : 1.0
        let insetH = svH * scale

        let margin: CGFloat = 8
        let tx = CGFloat(dstW) - insetW - margin
        let ty = margin

        let scaledSelf = selfImage
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: tx, y: ty))

        // Composite self-view over dominant speaker
        let finalImage = scaledSelf.composited(over: dominantImage)
        context.render(finalImage, to: output)
        return output
    }

    // ──── Pool management ──────────────────────────────────────────────────

    private func allocateBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        if width != poolWidth || height != poolHeight {
            let attrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            ]
            var pool: CVPixelBufferPool?
            CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &pool)
            outputPool = pool
            poolWidth = width
            poolHeight = height
        }
        guard let pool = outputPool else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        return buffer
    }
}
