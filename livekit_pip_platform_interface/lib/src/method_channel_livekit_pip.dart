import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';

/// An implementation of [LivekitPipPlatform]
/// that uses method channels.
class MethodChannelLivekitPip
    extends LivekitPipPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('livekit_pip');

  @override
  Future<String?> getPlatformName() {
    return methodChannel.invokeMethod<String>('getPlatformName');
  }
}
