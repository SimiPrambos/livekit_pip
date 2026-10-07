import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';

class _MockLivekitPipPlatform extends LivekitPipPlatform {
  bool? lastMirrorSelfView;
  bool? lastAnimateExit;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> initialize({
    required bool enabled,
    required bool disableWhenScreenSharing,
    required bool androidAutoEnterOnBackground,
    required bool iosAutoEnterOnBackground,
    required bool iosIncludeLocalParticipantVideo,
    required int videoWidth,
    required int videoHeight,
    bool iosMirrorSelfView = true,
    bool iosAnimateExit = true,
  }) async {
    lastMirrorSelfView = iosMirrorSelfView;
    lastAnimateExit = iosAnimateExit;
  }

  @override
  Future<void> enterPip() async {}

  @override
  Future<void> exitPip() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> updateActiveTrack(String trackId) async {}

  @override
  Stream<int> get stateStream => const Stream<int>.empty();
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
    late LivekitPipPlatform livekitPipPlatform;

    setUp(() {
      livekitPipPlatform = _MockLivekitPipPlatform();
      LivekitPipPlatform.instance = livekitPipPlatform;
    });

    group('initialize', () {
      test(
        'mirroring and the exit animation default to on',
        () async {
          final platform = livekitPipPlatform as _MockLivekitPipPlatform;
          await platform.initialize(
            enabled: true,
            disableWhenScreenSharing: true,
            androidAutoEnterOnBackground: true,
            iosAutoEnterOnBackground: true,
            iosIncludeLocalParticipantVideo: true,
            videoWidth: 0,
            videoHeight: 0,
          );
          expect(platform.lastMirrorSelfView, isTrue);
          expect(platform.lastAnimateExit, isTrue);
        },
      );
    });

    group('updateParticipants', () {
      // Android draws the consumer widget, so the default must not throw.
      test('is a no-op by default', () async {
        await expectLater(
          LivekitPipPlatform.instance.updateParticipants(const []),
          completes,
        );
      });
    });

    group('isSupported', () {
      test('returns true from mock', () async {
        expect(
          await LivekitPipPlatform.instance.isSupported(),
          isTrue,
        );
      });
    });
  });

  group(PipParticipantInfo, () {
    const info = PipParticipantInfo(
      identity: 'clinician',
      isLocal: false,
      isMicMuted: true,
      displayName: 'Dr. Example',
      videoTrackId: 'track-1',
      avatarUrl: 'https://example.com/a.png',
    );

    test('is equal by value, so unchanged tiles are not resent', () {
      const same = PipParticipantInfo(
        identity: 'clinician',
        isLocal: false,
        isMicMuted: true,
        displayName: 'Dr. Example',
        videoTrackId: 'track-1',
        avatarUrl: 'https://example.com/a.png',
      );
      expect(info, same);
      expect(info.hashCode, same.hashCode);
    });

    test('differs when the camera turns off', () {
      const cameraOff = PipParticipantInfo(
        identity: 'clinician',
        isLocal: false,
        isMicMuted: true,
        displayName: 'Dr. Example',
        avatarUrl: 'https://example.com/a.png',
      );
      expect(info, isNot(cameraOff));
    });
  });
}
