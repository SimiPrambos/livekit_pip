import AVFoundation
import AVKit
import Flutter

/// UIView subclass that propagates layout changes to the display layer.
private final class _PipHostView: UIView {
    var onLayout: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

/// UIView that hosts AVSampleBufferDisplayLayer and AVPictureInPictureController.
///
/// Never recreate this view mid-call — rebind FrameBridge.displayLayer instead.
class PipPlatformView: NSObject, FlutterPlatformView {

    private let _view: _PipHostView
    let displayLayer: AVSampleBufferDisplayLayer
    private var pipController: AVPictureInPictureController?
    private let playbackDelegate = PlaybackDelegate()
    var onStateChanged: ((Int) -> Void)?
    var frameBridge: FrameBridge?

    init(frame: CGRect, viewId: Int64, args: Any?) {
        _view = _PipHostView(frame: frame)
        _view.backgroundColor = .black
        _view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        displayLayer = AVSampleBufferDisplayLayer()
        displayLayer.videoGravity = .resizeAspect
        displayLayer.frame = _view.bounds
        _view.layer.addSublayer(displayLayer)
        super.init()
        _view.onLayout = { [weak self] in
            guard let self = self else { return }
            self.displayLayer.frame = self._view.bounds
        }
        if AVPictureInPictureController.isPictureInPictureSupported() {
            let source = AVPictureInPictureController.ContentSource(
                sampleBufferDisplayLayer: displayLayer,
                playbackDelegate: playbackDelegate
            )
            pipController = AVPictureInPictureController(contentSource: source)
            pipController?.delegate = self
        }
    }

    func view() -> UIView { _view }

    func startPictureInPicture() {
        pipController?.startPictureInPicture()
    }

    func stopPictureInPicture() {
        pipController?.stopPictureInPicture()
    }
}

// ──── AVPictureInPictureControllerDelegate ─────────────────────────────────

extension PipPlatformView: AVPictureInPictureControllerDelegate {

    func pictureInPictureControllerWillStartPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        onStateChanged?(2) // entering
    }

    func pictureInPictureControllerDidStartPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
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
        onStateChanged?(1) // inactive
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        print("[livekit_pip] PiP failed to start: \(error.localizedDescription)")
        onStateChanged?(1) // inactive
    }
}
