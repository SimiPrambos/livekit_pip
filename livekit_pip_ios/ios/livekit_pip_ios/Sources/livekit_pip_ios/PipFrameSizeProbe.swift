import CoreGraphics
import Foundation
import WebRTC

/// Reads a track's frame size while its tile is off screen, so the PiP
/// window opens at the right shape. It never touches a display layer.
final class PipFrameSizeProbe: NSObject, RTCVideoRenderer {

    let track: RTCVideoTrack

    /// Called on the main thread when the frame size changes.
    var onSize: ((CGSize) -> Void)?

    // Written and read only on the WebRTC thread.
    private var lastSize: CGSize = .zero

    init(track: RTCVideoTrack) {
        self.track = track
        super.init()
        track.add(self)
    }

    func stop() {
        track.remove(self)
    }

    func setSize(_ size: CGSize) {}

    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame else { return }
        let size: CGSize
        switch frame.rotation {
        case ._90, ._270:
            size = CGSize(width: CGFloat(frame.height), height: CGFloat(frame.width))
        default:
            size = CGSize(width: CGFloat(frame.width), height: CGFloat(frame.height))
        }
        guard size != lastSize, size.width > 0, size.height > 0 else { return }
        lastSize = size
        DispatchQueue.main.async { [weak self] in self?.onSize?(size) }
    }
}
