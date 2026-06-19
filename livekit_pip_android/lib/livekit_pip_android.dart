import 'package:flutter/services.dart';
import 'package:livekit_pip_android/src/messages.g.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';

/// Android implementation of [LivekitPipPlatform].
class LivekitPipAndroid extends LivekitPipPlatform {
  /// Creates an Android PiP platform implementation.
  LivekitPipAndroid();

  /// Registers this class as the default [LivekitPipPlatform] instance.
  static void registerWith() {
    LivekitPipPlatform.instance = LivekitPipAndroid();
  }

  // EventChannel: Pigeon does not model push streams
  static const _stateChannel = EventChannel('livekit_pip/state');

  final _api = LiveKitPipHostApi();

  @override
  Future<bool> isSupported() => _api.isSupported();

  @override
  Future<void> initialize({
    required bool enabled,
    required bool disableWhenScreenSharing,
    required bool androidAutoEnterOnBackground,
    required bool iosAutoEnterOnBackground,
    required bool iosIncludeLocalParticipantVideo,
    required int videoWidth,
    required int videoHeight,
  }) =>
      _api.initialize(
        PipInitRequest(
          enabled: enabled,
          disableWhenScreenSharing: disableWhenScreenSharing,
          androidAutoEnterOnBackground: androidAutoEnterOnBackground,
          iosAutoEnterOnBackground: iosAutoEnterOnBackground,
          iosIncludeLocalParticipantVideo: iosIncludeLocalParticipantVideo,
          videoWidth: videoWidth,
          videoHeight: videoHeight,
        ),
      );

  @override
  Future<void> enterPip() => _api.enterPip();

  @override
  Future<void> exitPip() => _api.exitPip();

  @override
  Future<void> dispose() => _api.dispose();

  @override
  Future<void> updateActiveTrack(String trackId) =>
      _api.updateActiveTrack(trackId);

  @override
  Future<void> updateAspectRatio(int width, int height) =>
      _api.updateAspectRatio(width, height);

  @override
  Stream<int> get stateStream =>
      _stateChannel.receiveBroadcastStream().cast<int>();
}
