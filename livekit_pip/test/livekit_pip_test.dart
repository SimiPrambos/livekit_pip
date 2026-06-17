import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockLivekitPipPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements LivekitPipPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(LivekitPipPlatform, () {
    late MockLivekitPipPlatform livekitPipPlatform;

    setUp(() {
      livekitPipPlatform = MockLivekitPipPlatform();
      LivekitPipPlatform.instance = livekitPipPlatform;
    });

    group('isSupported', () {
      test('returns true when platform reports supported', () async {
        when(
          () => livekitPipPlatform.isSupported(),
        ).thenAnswer((_) async => true);

        final result = await LivekitPipPlatform.instance.isSupported();
        expect(result, isTrue);
      });

      test('returns false when platform reports unsupported', () async {
        when(
          () => livekitPipPlatform.isSupported(),
        ).thenAnswer((_) async => false);

        final result = await LivekitPipPlatform.instance.isSupported();
        expect(result, isFalse);
      });
    });
  });
}
