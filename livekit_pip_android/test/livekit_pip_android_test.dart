import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_pip_android/livekit_pip_android.dart';
import 'package:livekit_pip_android/src/messages.g.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';

const _channelPrefix =
    'dev.flutter.pigeon.livekit_pip_android.LiveKitPipHostApi';

/// Captures the first argument Dart sends on a Pigeon host channel.
Object? Function() _capture(String method) {
  Object? argument;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('$_channelPrefix.$method', (message) async {
        final args =
            LiveKitPipHostApi.pigeonChannelCodec.decodeMessage(message)
                as List<Object?>?;
        argument = args?.first;
        return LiveKitPipHostApi.pigeonChannelCodec.encodeMessage(
          <Object?>[null],
        );
      });
  return () => argument;
}

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

    test(
      'initialize sends the mirroring and exit animation settings',
      () async {
        final sent = _capture('initialize');
        await LivekitPipAndroid().initialize(
          enabled: true,
          disableWhenScreenSharing: true,
          androidAutoEnterOnBackground: true,
          iosAutoEnterOnBackground: true,
          iosIncludeLocalParticipantVideo: true,
          videoWidth: 0,
          videoHeight: 0,
          iosMirrorSelfView: false,
          iosAnimateExit: false,
        );
        final request = sent()! as PipInitRequest;
        expect(request.iosMirrorSelfView, isFalse);
        expect(request.iosAnimateExit, isFalse);
      },
    );

    // Android draws the consumer widget; there is no native inset to feed.
    // Android draws the consumer widget; there are no native tiles to feed.
    test('updateParticipants is a no-op that sends nothing', () async {
      final sent = _capture('updateParticipants');
      await LivekitPipAndroid().updateParticipants(const []);
      expect(sent(), isNull);
    });
  });
}
