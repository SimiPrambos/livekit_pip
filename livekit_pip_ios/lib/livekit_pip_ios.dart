import 'package:flutter/foundation.dart';
import 'package:livekit_pip_ios/src/messages.g.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';

/// {@template livekit_pip_ios}
/// The iOS implementation of [LivekitPipPlatform].
/// {@endtemplate}
class LivekitPipIOS extends LivekitPipPlatform {
  /// {@macro livekit_pip_ios}
  LivekitPipIOS({
    @visibleForTesting LivekitPipApi? api,
  }) : api = api ?? LivekitPipApi();

  /// The API used to interact with the native platform.
  final LivekitPipApi api;

  /// Registers this class as the default instance of
  /// [LivekitPipPlatform].
  static void registerWith() {
    LivekitPipPlatform.instance =
        LivekitPipIOS();
  }

  @override
  Future<String?> getPlatformName() {
    return api.getPlatformName();
  }
}
