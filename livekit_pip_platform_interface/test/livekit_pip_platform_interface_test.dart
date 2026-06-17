import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';
import 'package:livekit_pip_platform_interface/src/method_channel_livekit_pip.dart';

class LivekitPipMock
    extends LivekitPipPlatform {
  static const mockPlatformName = 'Mock';

  @override
  Future<String?> getPlatformName() async => mockPlatformName;
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
    late LivekitPipPlatform
    livekitPipPlatform;

    setUp(() {
      livekitPipPlatform = LivekitPipMock();
      LivekitPipPlatform.instance =
          livekitPipPlatform;
    });

    group('getPlatformName', () {
      test('returns correct name', () async {
        expect(
          await LivekitPipPlatform.instance.getPlatformName(),
          equals(LivekitPipMock.mockPlatformName),
        );
      });
    });
  });
}
