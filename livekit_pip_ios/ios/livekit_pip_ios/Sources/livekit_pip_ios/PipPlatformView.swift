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
        pipController?.canStartPictureInPictureAutomaticallyFromInline = false
    }

    func view() -> UIView { containerView }

    func configure(autoEnterOnBackground: Bool) {
        pipController?.canStartPictureInPictureAutomaticallyFromInline = autoEnterOnBackground
    }

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
