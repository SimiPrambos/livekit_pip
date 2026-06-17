import Flutter

// Placeholder — full implementation in Phase 2 (T017, T018, T041–T044).
public class LiveKitPipPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = LiveKitPipPlugin()
        registrar.publish(instance)
    }
}
