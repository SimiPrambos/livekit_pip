import AVFoundation
import AVKit
import Flutter
import UIKit
import WebRTC

// Hosts the remote and local tiles side by side (PipTileLayout).
// preferredContentSize must always be > .zero to avoid PGPegasus -1003 crash.
private final class PipVideoCallViewController: AVPictureInPictureVideoCallViewController {

    let remoteTile = PipTileView()
    let localTile = PipTileView()

    private var visibleTiles: [PipTileView] {
        [remoteTile, localTile].filter { $0.participant != nil }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        for tile in [remoteTile, localTile] {
            tile.onAspectChanged = { [weak self] in self?.relayout() }
            view.addSubview(tile)
        }
        preferredContentSize = PipTileLayout.emptyWindowSize
        relayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let tiles = visibleTiles
        let frames = PipTileLayout.frames(layoutTiles(tiles), in: view.bounds)
        for tile in [remoteTile, localTile] {
            tile.isHidden = !tiles.contains(tile)
        }
        for (tile, frame) in zip(tiles, frames) {
            tile.frame = frame
        }
    }

    /// Re-lays out the tiles and reshapes the window to fit them.
    func relayout() {
        guard isViewLoaded else { return }
        let size = PipTileLayout.windowSize(layoutTiles(visibleTiles))
        if preferredContentSize != size { preferredContentSize = size }
        view.setNeedsLayout()
    }

    private func layoutTiles(_ tiles: [PipTileView]) -> [PipTileLayout.Tile] {
        tiles.map { PipTileLayout.Tile(isLocal: $0 === localTile, aspect: $0.aspect) }
    }
}

// containerView is the AVPictureInPictureController activeVideoCallSourceView.
// Actual rendering happens in PipVideoCallViewController's tiles.
// Never recreate pipController or the display layer mid-call.
class PipPlatformView: NSObject, FlutterPlatformView {

    private let containerView: UIView
    private let pipVC = PipVideoCallViewController()
    private var pipController: AVPictureInPictureController?
    private let trackStateAdapter = TrackStateAdapter()
    private let resolver: NativeTrackResolver
    private var hasLoggedNoMultitaskingCamera = false

    var onStateChanged: ((Int) -> Void)?
    var animateExit = true

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
        // Arm auto-enter at controller creation, not later via configure(): the host
        // configure() call is async, so the first background can fire before it lands —
        // and the first minimize would be silently ignored. configure() still applies
        // the consumer's actual preference afterward.
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true

        // Force the content view controller's view (and its AVSampleBufferDisplayLayer)
        // to load. Until the view is loaded, isPictureInPicturePossible never flips to
        // true and the system never auto-enters on background. This does NOT stream
        // frames (the renderer has a window guard) — it only loads the view hierarchy.
        _ = pipVC.view

        // Stop PiP when the app returns to the foreground so the next minimize
        // starts a fresh session.
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        // object: nil because flutter_webrtc owns the session. While iOS has
        // the camera paused, the local tile shows the avatar instead.
        center.addObserver(
            self,
            selector: #selector(handleCameraInterrupted),
            name: AVCaptureSession.wasInterruptedNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleCameraInterruptionEnded),
            name: AVCaptureSession.interruptionEndedNotification,
            object: nil
        )
    }

    @objc private func handleCameraInterrupted() {
        DispatchQueue.main.async { [weak self] in self?.pipVC.localTile.isCameraInterrupted = true }
    }

    @objc private func handleCameraInterruptionEnded() {
        DispatchQueue.main.async { [weak self] in self?.pipVC.localTile.isCameraInterrupted = false }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        pipController?.stopPictureInPicture()
    }

    @objc private func handleAppDidBecomeActive() {
        guard let ctrl = pipController, ctrl.isPictureInPictureActive else { return }
        ctrl.stopPictureInPicture()
    }

    func view() -> UIView { containerView }

    // Auto-enter on background MUST be driven by the system via
    // canStartPictureInPictureAutomaticallyFromInline. Never call
    // startPictureInPicture() from a background notification: by the time
    // UIApplication.didEnterBackgroundNotification fires, the UIScene has already
    // left foregroundActive state, so the call fails with AVKitErrorDomain -1001
    // and that failed attempt races with / disrupts the system's automatic entry.
    // isPictureInPicturePossible becomes true via the activeVideoCallSourceView
    // being in a visible window — no frame priming required (see PipVideoRenderer).
    func configure(autoEnterOnBackground: Bool) {
        pipController?.canStartPictureInPictureAutomaticallyFromInline = autoEnterOnBackground
    }

    func setMirrorSelfView(_ isMirrored: Bool) {
        pipVC.localTile.isMirrored = isMirrored
    }

    /// Binds the remote and local tiles; an absent participant clears its tile.
    func updateParticipants(_ participants: [PipParticipant]) {
        let remote = participants.first { !$0.isLocal }
        let local = participants.first { $0.isLocal }
        let resolve: (String) -> RTCVideoTrack? = { [resolver] in resolver.resolveVideoTrack(trackId: $0) }
        pipVC.remoteTile.apply(remote, resolveTrack: resolve)
        pipVC.localTile.apply(local, resolveTrack: resolve)
        trackStateAdapter.activeTrack = pipVC.remoteTile.track
        if pipVC.localTile.track != nil { enableMultitaskingCamera() }
        pipVC.relayout()
    }

    // Without this iOS pauses the camera as soon as the app leaves the
    // foreground, so the local tile could never be live in PiP. Apple asks for
    // the flag before the session starts; flutter_webrtc has already started
    // it, so it is set inside a configuration block instead.
    private func enableMultitaskingCamera() {
        guard let session = resolver.cameraCaptureSession() else { return }
        guard !session.isMultitaskingCameraAccessEnabled else { return }
        guard session.isMultitaskingCameraAccessSupported else {
            if !hasLoggedNoMultitaskingCamera {
                hasLoggedNoMultitaskingCamera = true
                print("[livekit_pip] multitasking camera access not supported; the local tile will show the avatar in PiP")
            }
            return
        }
        // Session configuration blocks; keep it off the main thread.
        DispatchQueue.global(qos: .userInitiated).async {
            session.beginConfiguration()
            session.isMultitaskingCameraAccessEnabled = true
            session.commitConfiguration()
        }
    }

    func startPictureInPicture() {
        guard let ctrl = pipController else {
            print("[livekit_pip] startPiP: pipController is nil")
            return
        }
        ctrl.startPictureInPicture()
    }

    func stopPictureInPicture() {
        pipController?.stopPictureInPicture()
    }

    fileprivate func setPipContentHidden(_ isHidden: Bool) {
        UIView.performWithoutAnimation {
            pipVC.view.alpha = isHidden ? 0 : 1
            pipVC.view.backgroundColor = isHidden ? .clear : .black
        }
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PipPlatformView: AVPictureInPictureControllerDelegate {

    func pictureInPictureControllerWillStartPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        setPipContentHidden(false)
        onStateChanged?(2) // entering
    }

    func pictureInPictureControllerDidStartPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        trackStateAdapter.isEnabled = true
        pipVC.remoteTile.resumeStreaming()
        pipVC.localTile.resumeStreaming()
        onStateChanged?(3) // active
    }

    func pictureInPictureControllerWillStopPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        // AVKit grows the window back over the source view as it closes,
        // stretching the tiles across the call screen. Hiding them lets the
        // call UI show through instead.
        if !animateExit { setPipContentHidden(true) }
        onStateChanged?(4) // exiting
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        trackStateAdapter.isEnabled = false
        setPipContentHidden(false)
        onStateChanged?(1) // inactive
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        let ns = error as NSError
        print("[livekit_pip] PiP failed to start: \(ns.domain) \(ns.code) — \(ns.localizedDescription)")
        onStateChanged?(1) // inactive
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
    }
}
