import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_pip_platform_interface/src/method_channel_livekit_pip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const kPlatformName = 'platformName';

  group('$MethodChannelLivekitPip', () {
    late MethodChannelLivekitPip
    methodChannelLivekitPip;
    final log = <MethodCall>[];

    setUp(() {
      methodChannelLivekitPip = MethodChannelLivekitPip();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            methodChannelLivekitPip.methodChannel,
            (methodCall) async {
              log.add(methodCall);
              switch (methodCall.method) {
                case 'getPlatformName':
                  return kPlatformName;
                default:
                  return null;
              }
            },
          );
    });

    tearDown(log.clear);

    test('getPlatformName', () async {
      final platformName = await methodChannelLivekitPip
          .getPlatformName();
      expect(
        log,
        <Matcher>[isMethodCall('getPlatformName', arguments: null)],
      );
      expect(platformName, equals(kPlatformName));
    });
  });
}
