import AVKit
import Flutter

/// Registers Pigeon host API, EventChannel, and the platform view factory.
public class LiveKitPipPlugin: NSObject, FlutterPlugin, LiveKitPipHostApi {

    private var stateEventSink: FlutterEventSink?
    private weak var platformView: PipPlatformView?
    private var frameBridge: FrameBridge?
    private var iosAutoEnter = true
    private var backgroundObserver: NSObjectProtocol?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let instance = LiveKitPipPlugin()
        LiveKitPipHostApiSetup.setUp(binaryMessenger: messenger, api: instance)
        // EventChannel: Pigeon does not model push streams
        FlutterEventChannel(name: "livekit_pip/state", binaryMessenger: messenger)
            .setStreamHandler(instance)
        registrar.register(
            PipPlatformViewFactory(plugin: instance),
            withId: "livekit_pip_view"
        )
        registrar.publish(instance)
    }

    // ──── LiveKitPipHostApi ────────────────────────────────────────────────

    func isSupported() -> Bool {
        return AVPictureInPictureController.isPictureInPictureSupported()
    }

    func initialize(request: PipInitRequest) {
        iosAutoEnter = request.iosAutoEnterOnBackground
        frameBridge?.configure(
            includeLocalVideo: request.iosIncludeLocalParticipantVideo
        )
        if iosAutoEnter {
            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.platformView?.startPictureInPicture()
            }
        }
    }

    func enterPip() {
        platformView?.startPictureInPicture()
    }

    func exitPip() {
        platformView?.stopPictureInPicture()
    }

    func dispose() {
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
        }
        platformView?.stopPictureInPicture()
        frameBridge?.detach()
        frameBridge = nil
    }

    func updateActiveTrack(trackId: String) {
        frameBridge?.rebindTrack(trackId: trackId)
    }

    // ──── Called by PipPlatformViewFactory once the view is created ────────

    func didCreatePlatformView(_ view: PipPlatformView) {
        platformView = view
        view.onStateChanged = { [weak self] ordinal in
            self?.stateEventSink?(ordinal)
        }
        let bridge = FrameBridge(displayLayer: view.displayLayer)
        frameBridge = bridge
        view.frameBridge = bridge
    }
}

// ──── FlutterStreamHandler ─────────────────────────────────────────────────

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
