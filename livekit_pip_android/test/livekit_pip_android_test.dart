import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_pip_android/livekit_pip_android.dart';
import 'package:livekit_pip_android/src/messages.g.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';
import 'package:mocktail/mocktail.dart';

class _MockLivekitPipApi extends Mock
    implements LivekitPipApi {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(LivekitPipAndroid, () {
    const kPlatformName = 'Android';
    late LivekitPipAndroid livekitPip;
    late LivekitPipApi api;

    setUp(() {
      api = _MockLivekitPipApi();
      livekitPip = LivekitPipAndroid(api: api);
    });

    test('can be registered', () {
      LivekitPipAndroid.registerWith();
      expect(
        LivekitPipPlatform.instance,
        isA<LivekitPipAndroid>(),
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
