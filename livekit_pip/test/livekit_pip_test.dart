import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_pip/livekit_pip.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'helpers/fake_room.dart';

class _MockPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements LivekitPipPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPlatform platform;
  late StreamController<int> stateRaw;

  setUpAll(() => registerFallbackValue(<PipParticipantInfo>[]));

  setUp(() {
    platform = _MockPlatform();
    stateRaw = StreamController<int>.broadcast();
    LivekitPipPlatform.instance = platform;

    when(() => platform.isSupported()).thenAnswer((_) async => true);
    when(
      () => platform.initialize(
        enabled: any(named: 'enabled'),
        disableWhenScreenSharing: any(named: 'disableWhenScreenSharing'),
        androidAutoEnterOnBackground: any(
          named: 'androidAutoEnterOnBackground',
        ),
        iosAutoEnterOnBackground: any(named: 'iosAutoEnterOnBackground'),
        iosIncludeLocalParticipantVideo: any(
          named: 'iosIncludeLocalParticipantVideo',
        ),
        videoWidth: any(named: 'videoWidth'),
        videoHeight: any(named: 'videoHeight'),
        iosMirrorSelfView: any(named: 'iosMirrorSelfView'),
        iosAnimateExit: any(named: 'iosAnimateExit'),
      ),
    ).thenAnswer((_) async {});
    when(() => platform.stateStream).thenAnswer((_) => stateRaw.stream);
    when(() => platform.enterPip()).thenAnswer((_) async {});
    when(() => platform.exitPip()).thenAnswer((_) async {});
    when(() => platform.dispose()).thenAnswer((_) async {});
    when(() => platform.updateActiveTrack(any())).thenAnswer((_) async {});
    when(
      () => platform.updateParticipants(any()),
    ).thenAnswer((_) async {});
    when(
      () => platform.updateAspectRatio(any(), any()),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await stateRaw.close();
  });

  group('LiveKitPip lifecycle', () {
    test('initialize → enter → active → exit → inactive → dispose', () async {
      final pip = LiveKitPip();
      final states = <PipState>[];
      final sub = pip.stateStream.listen(states.add);

      await pip.initialize(room: Room(), config: _config());
      stateRaw
        ..add(2) // entering
        ..add(3); // active
      await pip.enterPiP();
      stateRaw
        ..add(4) // exiting
        ..add(1); // inactive
      await pip.exitPiP();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      await pip.dispose();

      expect(
        states,
        containsAllInOrder([
          PipState.entering,
          PipState.active,
          PipState.exiting,
          PipState.inactive,
        ]),
      );
    });

    test('enterPiP before initialize throws StateError', () async {
      final pip = LiveKitPip();
      expect(pip.enterPiP, throwsStateError);
    });

    test('enterPiP after dispose throws StateError', () async {
      final pip = LiveKitPip();
      await pip.initialize(room: Room(), config: _config());
      await pip.dispose();
      expect(pip.enterPiP, throwsStateError);
    });

    test('dispose is idempotent', () async {
      final pip = LiveKitPip();
      await pip.initialize(room: Room(), config: _config());
      await pip.dispose();
      await pip.dispose(); // second call must not throw
    });

    test('isSupported delegates to platform', () async {
      final pip = LiveKitPip();
      expect(await pip.isSupported(), isTrue);
    });

    test('stateStream emits unsupported when platform returns 0', () async {
      final pip = LiveKitPip();
      final states = <PipState>[];
      final sub = pip.stateStream.listen(states.add);
      await pip.initialize(room: Room(), config: _config());
      stateRaw.add(0); // unsupported
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      await pip.dispose();
      expect(states, contains(PipState.unsupported));
    });

    test(
      'initialize throws UnsupportedError when isSupported returns false',
      () async {
        when(() => platform.isSupported()).thenAnswer((_) async => false);
        final pip = LiveKitPip();
        await expectLater(
          () => pip.initialize(room: Room(), config: _config()),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );

    test(
      'stateStream emits unsupported before throwing in initialize',
      () async {
        when(() => platform.isSupported()).thenAnswer((_) async => false);
        final pip = LiveKitPip();
        final states = <PipState>[];
        final sub = pip.stateStream.listen(states.add);
        // UnsupportedError extends Error; expectLater handles it cleanly.
        await expectLater(
          () => pip.initialize(room: Room(), config: _config()),
          throwsA(isA<UnsupportedError>()),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();
        expect(states, contains(PipState.unsupported));
      },
    );

    test('enterPiP throws StateError when called before initialize', () async {
      // enterPiP before initialize always throws StateError.
      // The UnsupportedError path (after init on unsupported device) is
      // covered by initialize() guard — supported=false throws before setting
      // _initialized=true, so enterPiP's _assertInitialized fires first.
      final pip = LiveKitPip();
      expect(pip.enterPiP, throwsStateError);
    });

    test('exposes room and configuration after initialize', () async {
      final pip = LiveKitPip();
      final room = Room();
      final config = _config();
      await pip.initialize(room: room, config: config);

      expect(pip.room, same(room));
      expect(pip.configuration, same(config));

      await pip.dispose();
      await room.dispose();
    });
  });

  group('updateAspectRatio', () {
    test('before initialize throws StateError', () {
      final pip = LiveKitPip();
      expect(() => pip.updateAspectRatio(16, 9), throwsStateError);
    });

    test('forwards the ratio clamped to Android range', () async {
      final pip = LiveKitPip();
      await pip.initialize(room: Room(), config: _config());
      await pip.updateAspectRatio(1000, 100);
      verify(() => platform.updateAspectRatio(239, 100)).called(1);
      await pip.dispose();
    });

    test('ignores a non-positive size', () async {
      final pip = LiveKitPip();
      await pip.initialize(room: Room(), config: _config());
      await pip.updateAspectRatio(0, 9);
      verifyNever(() => platform.updateAspectRatio(any(), any()));
      await pip.dispose();
    });
  });

  group('iOS tiles', () {
    List<PipParticipantInfo> lastSent() =>
        verify(
              () => platform.updateParticipants(captureAny()),
            ).captured.last
            as List<PipParticipantInfo>;

    test('sends mirroring to the platform', () async {
      final pip = LiveKitPip();
      await pip.initialize(
        room: Room(),
        config: _config(ios: const IosPipConfiguration(mirrorSelfView: false)),
      );
      verify(
        () => platform.initialize(
          enabled: any(named: 'enabled'),
          disableWhenScreenSharing: any(named: 'disableWhenScreenSharing'),
          androidAutoEnterOnBackground: any(
            named: 'androidAutoEnterOnBackground',
          ),
          iosAutoEnterOnBackground: any(named: 'iosAutoEnterOnBackground'),
          iosIncludeLocalParticipantVideo: any(
            named: 'iosIncludeLocalParticipantVideo',
          ),
          videoWidth: any(named: 'videoWidth'),
          videoHeight: any(named: 'videoHeight'),
          iosMirrorSelfView: false,
          iosAnimateExit: any(named: 'iosAnimateExit'),
        ),
      ).called(1);
      await pip.dispose();
    });

    test('sends the exit animation setting to the platform', () async {
      final pip = LiveKitPip();
      await pip.initialize(
        room: Room(),
        config: _config(ios: const IosPipConfiguration(animateExit: false)),
      );
      verify(
        () => platform.initialize(
          enabled: any(named: 'enabled'),
          disableWhenScreenSharing: any(named: 'disableWhenScreenSharing'),
          androidAutoEnterOnBackground: any(
            named: 'androidAutoEnterOnBackground',
          ),
          iosAutoEnterOnBackground: any(named: 'iosAutoEnterOnBackground'),
          iosIncludeLocalParticipantVideo: any(
            named: 'iosIncludeLocalParticipantVideo',
          ),
          videoWidth: any(named: 'videoWidth'),
          videoHeight: any(named: 'videoHeight'),
          iosMirrorSelfView: any(named: 'iosMirrorSelfView'),
          iosAnimateExit: false,
        ),
      ).called(1);
      await pip.dispose();
    });

    test('seeds the tiles already in the room, then sends changes', () async {
      final fake = FakeRoom();
      final camera = fake.addCamera('cam-1');
      fake.addRemote('clinician', cameraTrackId: 'r-cam');
      final pip = LiveKitPip();
      await pip.initialize(room: fake.room, config: _config());
      expect(lastSent().map((t) => t.videoTrackId), ['r-cam', 'cam-1']);

      fake.setMuted(camera, muted: true);
      await pumpEventQueue();
      expect(lastSent().map((t) => t.videoTrackId), ['r-cam', null]);
      await pip.dispose();
    });

    test('passes the avatar resolver through', () async {
      final fake = FakeRoom()..addRemote('clinician');
      final pip = LiveKitPip();
      await pip.initialize(
        room: fake.room,
        config: _config(
          ios: IosPipConfiguration(
            avatarUrlResolver: (p) => 'https://example.com/${p.identity}.png',
          ),
        ),
      );
      expect(lastSent().first.avatarUrl, 'https://example.com/clinician.png');
      await pip.dispose();
    });

    test('leaves the local tile out when the self-view is off', () async {
      final fake = FakeRoom()..addCamera('cam-1');
      final pip = LiveKitPip();
      await pip.initialize(
        room: fake.room,
        config: _config(
          ios: const IosPipConfiguration(includeLocalParticipantVideo: false),
        ),
      );
      expect(lastSent(), isEmpty);
      await pip.dispose();
    });

    test('stops sending after dispose', () async {
      final fake = FakeRoom();
      final pip = LiveKitPip();
      await pip.initialize(room: fake.room, config: _config());
      await pip.dispose();
      clearInteractions(platform);
      fake.publishCamera('cam-1');
      await pumpEventQueue();
      verifyNever(() => platform.updateParticipants(any()));
    });
  });
}

Widget _dummyBuilder(BuildContext context, Room room) =>
    const SizedBox.shrink();

LiveKitPipConfiguration _config({
  IosPipConfiguration ios = const IosPipConfiguration(),
}) => LiveKitPipConfiguration(
  android: const AndroidPipConfiguration(pipWidgetBuilder: _dummyBuilder),
  ios: ios,
);
