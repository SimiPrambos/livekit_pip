import 'package:flutter/foundation.dart';
import 'package:livekit_pip_android/src/messages.g.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';

/// {@template livekit_pip_android}
/// The Android implementation of [LivekitPipPlatform].
/// {@endtemplate}
class LivekitPipAndroid extends LivekitPipPlatform {
  /// {@macro livekit_pip_android}
  LivekitPipAndroid({
    @visibleForTesting LivekitPipApi? api,
  }) : api = api ?? LivekitPipApi();

  /// The API used to interact with the native platform.
  final LivekitPipApi api;

  /// Registers this class as the default instance of
  /// [LivekitPipPlatform].
  static void registerWith() {
    LivekitPipPlatform.instance =
        LivekitPipAndroid();
  }

  @override
  Future<String?> getPlatformName() {
    return api.getPlatformName();
  }
}
