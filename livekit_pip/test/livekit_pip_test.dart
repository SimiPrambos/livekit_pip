import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_pip/livekit_pip.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockLivekitPipPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements LivekitPipPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(LivekitPipPlatform, () {
    late LivekitPipPlatform
    livekitPipPlatform;

    setUp(() {
      livekitPipPlatform =
          MockLivekitPipPlatform();
      LivekitPipPlatform.instance =
          livekitPipPlatform;
    });

    group('getPlatformName', () {
      test(
        'returns correct name when platform implementation exists',
        () async {
          const platformName = '__test_platform__';
          when(
            () => livekitPipPlatform.getPlatformName(),
          ).thenAnswer((_) async => platformName);

          final actualPlatformName = await getPlatformName();
          expect(actualPlatformName, equals(platformName));
        },
      );

      test(
        'throws exception when platform implementation is missing',
        () async {
          when(
            () => livekitPipPlatform.getPlatformName(),
          ).thenAnswer((_) async => null);

          expect(getPlatformName, throwsException);
        },
      );
    });
  });
}
