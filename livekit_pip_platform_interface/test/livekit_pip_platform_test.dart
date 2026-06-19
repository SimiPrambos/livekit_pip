import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePlatform extends LivekitPipPlatform with MockPlatformInterfaceMixin {
  @override
  Future<bool> isSupported() async => true;
  @override
  Future<void> initialize({
    required bool enabled,
    required bool disableWhenScreenSharing,
    required bool androidAutoEnterOnBackground,
    required bool iosAutoEnterOnBackground,
    required bool iosIncludeLocalParticipantVideo,
    required int videoWidth,
    required int videoHeight,
  }) async {}
  @override
  Future<void> enterPip() async {}
  @override
  Future<void> exitPip() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> updateActiveTrack(String trackId) async {}
  @override
  Stream<int> get stateStream => const Stream<int>.empty();
}

void main() {
  test('updateAspectRatio default implementation is a no-op', () async {
    final platform = _FakePlatform();
    // Must not throw; the base class provides a no-op default.
    await platform.updateAspectRatio(1280, 720);
  });
}
