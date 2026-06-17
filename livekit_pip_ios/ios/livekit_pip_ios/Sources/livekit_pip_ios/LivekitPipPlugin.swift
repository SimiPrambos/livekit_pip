import Flutter

public class LivekitPipPlugin: NSObject, FlutterPlugin, LivekitPipApi {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let binaryMessenger = registrar.messenger()
    let instance = LivekitPipPlugin()
    LivekitPipApiSetup.setUp(binaryMessenger: binaryMessenger, api: instance)
    registrar.publish(instance)
  }

  func getPlatformName(completion: @escaping (Result<String?, Error>) -> Void) {
    completion(.success("iOS"))
  }
}
