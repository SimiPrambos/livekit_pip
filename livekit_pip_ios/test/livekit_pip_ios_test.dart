import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_pip_ios/livekit_pip_ios.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(LivekitPipIOS, () {
    test('can be registered', () {
      LivekitPipIOS.registerWith();
      expect(
        LivekitPipPlatform.instance,
        isA<LivekitPipIOS>(),
      );
    });
  });
}
