import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_pip/livekit_pip.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements LivekitPipPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPlatform platform;
  late StreamController<int> stateRaw;

  setUp(() {
    platform = _MockPlatform();
    stateRaw = StreamController<int>.broadcast();
    LivekitPipPlatform.instance = platform;

    when(() => platform.isSupported()).thenAnswer((_) async => true);
    when(
      () => platform.initialize(
        enabled: any(named: 'enabled'),
        disableWhenScreenSharing: any(named: 'disableWhenScreenSharing'),
        androidAutoEnterOnBackground:
            any(named: 'androidAutoEnterOnBackground'),
        iosAutoEnterOnBackground: any(named: 'iosAutoEnterOnBackground'),
        iosIncludeLocalParticipantVideo:
            any(named: 'iosIncludeLocalParticipantVideo'),
        videoWidth: any(named: 'videoWidth'),
        videoHeight: any(named: 'videoHeight'),
      ),
    ).thenAnswer((_) async {});
    when(() => platform.stateStream).thenAnswer((_) => stateRaw.stream);
    when(() => platform.enterPip()).thenAnswer((_) async {});
    when(() => platform.exitPip()).thenAnswer((_) async {});
    when(() => platform.dispose()).thenAnswer((_) async {});
    when(() => platform.updateActiveTrack(any())).thenAnswer((_) async {});
    when(() => platform.updateAspectRatio(any(), any()))
        .thenAnswer((_) async {});
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

    test('initialize throws UnsupportedError when isSupported returns false',
        () async {
      when(() => platform.isSupported()).thenAnswer((_) async => false);
      final pip = LiveKitPip();
      await expectLater(
        () => pip.initialize(room: Room(), config: _config()),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('stateStream emits unsupported before throwing in initialize',
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
    });

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
}

Widget _dummyBuilder(BuildContext context, Room room) =>
    const SizedBox.shrink();

LiveKitPipConfiguration _config() => const LiveKitPipConfiguration(
      android: AndroidPipConfiguration(pipWidgetBuilder: _dummyBuilder),
      ios: IosPipConfiguration(),
    );
