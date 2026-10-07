import AVKit
import Flutter

public class LiveKitPipPlugin: NSObject, FlutterPlugin, LiveKitPipHostApi {

    private var stateEventSink: FlutterEventSink?
    private weak var platformView: PipPlatformView?
    // Kept here because initialize() and the first updateParticipants() can
    // land before Flutter creates the platform view.
    private var mirrorSelfView = true
    private var animateExit = true
    private var participants: [PipParticipant] = []

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
        platformView?.configure(
            autoEnterOnBackground: request.enabled && request.iosAutoEnterOnBackground
        )
        mirrorSelfView = request.iosMirrorSelfView
        platformView?.setMirrorSelfView(mirrorSelfView)
        animateExit = request.iosAnimateExit
        platformView?.animateExit = animateExit
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
        platformView?.configure(autoEnterOnBackground: false)
        platformView?.stopPictureInPicture()
        participants = []
        platformView?.updateParticipants([])
    }

    // The remote tile's video comes from updateParticipants on iOS; this stays
    // in the shared contract for Android.
    func updateActiveTrack(trackId: String) {}

    func updateParticipants(participants: [PipParticipant]) {
        self.participants = participants
        platformView?.updateParticipants(participants)
    }

    // MARK: - Called by PipPlatformViewFactory

    func didCreatePlatformView(_ view: PipPlatformView) {
        platformView = view
        view.onStateChanged = { [weak self] ordinal in
            self?.stateEventSink?(ordinal)
        }
        view.setMirrorSelfView(mirrorSelfView)
        view.animateExit = animateExit
        view.updateParticipants(participants)
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
