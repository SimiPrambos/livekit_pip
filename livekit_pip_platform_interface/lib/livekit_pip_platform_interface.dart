import 'package:livekit_pip_platform_interface/src/method_channel_livekit_pip.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// {@template livekit_pip_platform}
/// The interface that implementations of
/// livekit_pip must implement.
///
/// Platform implementations should extend this class
/// rather than implement it as `LivekitPip`.
///
/// Extending this class (using `extends`) ensures that the subclass will get
/// the default implementation, while platform implementations that `implements`
/// this interface will be broken by newly added
/// [LivekitPipPlatform] methods.
/// {@endtemplate}
abstract class LivekitPipPlatform extends PlatformInterface {
  /// {@macro livekit_pip_platform}
  LivekitPipPlatform() : super(token: _token);

  static final Object _token = Object();

  static LivekitPipPlatform _instance = MethodChannelLivekitPip();

  /// The default instance of [LivekitPipPlatform] to use.
  ///
  /// Defaults to [MethodChannelLivekitPip].
  static LivekitPipPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [LivekitPipPlatform]
  /// when they register themselves.
  static set instance(LivekitPipPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Return the current platform name.
  Future<String?> getPlatformName();
}
