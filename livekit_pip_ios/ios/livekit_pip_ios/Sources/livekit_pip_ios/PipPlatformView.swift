import AVFoundation
import AVKit
import Flutter
import UIKit
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
    private var backgroundObserver: NSObjectProtocol?

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
        // Force viewDidLoad so preferredContentSize is non-zero before any PiP attempt.
        // Without this, isPictureInPicturePossible stays false until the view is first accessed.
        _ = pipVC.view
    }

    deinit {
        if let obs = backgroundObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    func view() -> UIView { containerView }

    func configure(autoEnterOnBackground: Bool) {
        let possible = pipController?.isPictureInPicturePossible ?? false
        print("[pip-diag] configure: autoEnter=\(autoEnterOnBackground) possible=\(possible) containerFrame=\(containerView.frame) preferredContentSize=\(pipVC.preferredContentSize)")
        pipController?.canStartPictureInPictureAutomaticallyFromInline = autoEnterOnBackground

        // Belt-and-suspenders: system auto-enter alone isn't reliable on first background
        // (requires at least one primed frame). Explicitly start when app backgrounds.
        if let obs = backgroundObserver {
            NotificationCenter.default.removeObserver(obs)
            backgroundObserver = nil
        }
        if autoEnterOnBackground {
            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                let possible = self?.pipController?.isPictureInPicturePossible ?? false
                let active = self?.pipController?.isPictureInPictureActive ?? false
                let frame = self?.containerView.frame ?? .zero
                print("[pip-diag] BG-notification: possible=\(possible) active=\(active) containerFrame=\(frame)")
                guard let ctrl = self?.pipController,
                      ctrl.isPictureInPicturePossible,
                      !ctrl.isPictureInPictureActive else {
                    print("[pip-diag] BG-notification: skipped (guard failed)")
                    return
                }
                print("[pip-diag] BG-notification: calling startPictureInPicture()")
                ctrl.startPictureInPicture()
            }
        }
    }

    func rebindTrack(trackId: String) {
        let resolved = resolver.resolveVideoTrack(trackId: trackId)
        print("[pip-diag] rebindTrack: trackId=\(trackId) resolved=\(resolved != nil)")
        pipVC.videoRenderer.track = resolved
        trackStateAdapter.activeTrack = resolved
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
        print("[pip-diag] willStartPiP")
        onStateChanged?(2) // entering
    }

    func pictureInPictureControllerDidStartPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        trackStateAdapter.isEnabled = true
        pipVC.videoRenderer.resumeStreaming()
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
        let ns = error as NSError
        print("[pip-diag] failedToStart: domain=\(ns.domain) code=\(ns.code) msg=\(ns.localizedDescription)")
        print("[pip-diag] failedToStart: possible=\(controller.isPictureInPicturePossible) containerFrame=\(containerView.frame)")
        onStateChanged?(1) // inactive
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
    }
}
