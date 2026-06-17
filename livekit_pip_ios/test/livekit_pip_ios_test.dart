import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_pip_ios/livekit_pip_ios.dart';
import 'package:livekit_pip_ios/src/messages.g.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';
import 'package:mocktail/mocktail.dart';

class _MockLivekitPipApi extends Mock
    implements LivekitPipApi {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(LivekitPipIOS, () {
    const kPlatformName = 'iOS';
    late LivekitPipIOS livekitPip;
    late LivekitPipApi api;

    setUp(() {
      api = _MockLivekitPipApi();
      livekitPip = LivekitPipIOS(api: api);
    });

    test('can be registered', () {
      LivekitPipIOS.registerWith();
      expect(
        LivekitPipPlatform.instance,
        isA<LivekitPipIOS>(),
      );
    });

    test('getPlatformName returns correct name', () async {
      when(api.getPlatformName).thenAnswer((_) async => kPlatformName);

      await expectLater(
        livekitPip.getPlatformName(),
        completion(equals(kPlatformName)),
      );

      verify(api.getPlatformName).called(1);
    });
  });
}
