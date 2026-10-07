import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_pip_ios/livekit_pip_ios.dart';
import 'package:livekit_pip_ios/src/messages.g.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';

const _channelPrefix = 'dev.flutter.pigeon.livekit_pip_ios.LiveKitPipHostApi';

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

  group(LivekitPipIOS, () {
    test('can be registered', () {
      LivekitPipIOS.registerWith();
      expect(
        LivekitPipPlatform.instance,
        isA<LivekitPipIOS>(),
      );
    });

    test(
      'initialize sends the mirroring and exit animation settings',
      () async {
        final sent = _capture('initialize');
        await LivekitPipIOS().initialize(
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

    test('updateParticipants sends every tile field', () async {
      final sent = _capture('updateParticipants');
      await LivekitPipIOS().updateParticipants(const [
        PipParticipantInfo(
          identity: 'clinician',
          isLocal: false,
          isMicMuted: true,
          displayName: 'Dr. Example',
          videoTrackId: 'remote-cam',
          avatarUrl: 'https://example.com/a.png',
        ),
        PipParticipantInfo(
          identity: 'member',
          isLocal: true,
          isMicMuted: false,
          displayName: 'Member',
        ),
      ]);
      final tiles = (sent()! as List<Object?>).cast<PipParticipant>();
      expect(tiles, hasLength(2));
      expect(tiles[0].identity, 'clinician');
      expect(tiles[0].isLocal, isFalse);
      expect(tiles[0].isMicMuted, isTrue);
      expect(tiles[0].displayName, 'Dr. Example');
      expect(tiles[0].videoTrackId, 'remote-cam');
      expect(tiles[0].avatarUrl, 'https://example.com/a.png');
      expect(tiles[1].isLocal, isTrue);
      expect(tiles[1].videoTrackId, isNull);
      expect(tiles[1].avatarUrl, isNull);
    });
  });
}
