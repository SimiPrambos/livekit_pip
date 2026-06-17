import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';

class _MockLivekitPipPlatform extends LivekitPipPlatform {
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
  TestWidgetsFlutterBinding.ensureInitialized();

  late LivekitPipPlatform defaultInstance;

  setUpAll(() {
    defaultInstance = LivekitPipPlatform.instance;
  });

  test('default instance is MethodChannelLivekitPip', () {
    expect(defaultInstance, isA<MethodChannelLivekitPip>());
  });

  group('LivekitPipPlatformInterface', () {
    late LivekitPipPlatform livekitPipPlatform;

    setUp(() {
      livekitPipPlatform = _MockLivekitPipPlatform();
      LivekitPipPlatform.instance = livekitPipPlatform;
    });

    group('isSupported', () {
      test('returns true from mock', () async {
        expect(
          await LivekitPipPlatform.instance.isSupported(),
          isTrue,
        );
      });
    });
  });
}
