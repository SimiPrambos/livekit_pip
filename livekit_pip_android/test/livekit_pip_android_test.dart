import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_pip_android/livekit_pip_android.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(LivekitPipAndroid, () {
    test('can be registered', () {
      LivekitPipAndroid.registerWith();
      expect(
        LivekitPipPlatform.instance,
        isA<LivekitPipAndroid>(),
      );
    });
  });
}
