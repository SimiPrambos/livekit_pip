import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_pip/livekit_pip.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements LivekitPipPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PipState', () {
    test('has exactly 5 values', () {
      expect(PipState.values, hasLength(5));
    });

    test('ordinal 0 is unsupported', () {
      expect(PipState.values[0], PipState.unsupported);
    });

    test('ordinal 1 is inactive', () {
      expect(PipState.values[1], PipState.inactive);
    });

    test('ordinal 2 is entering', () {
      expect(PipState.values[2], PipState.entering);
    });

    test('ordinal 3 is active', () {
      expect(PipState.values[3], PipState.active);
    });

    test('ordinal 4 is exiting', () {
      expect(PipState.values[4], PipState.exiting);
    });
  });

  group('PipState transitions via stateStream', () {
    late MockPlatform platform;
    late StreamController<int> stateRaw;

    setUp(() {
      platform = MockPlatform();
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
        ),
      ).thenAnswer((_) async {});
      when(() => platform.stateStream).thenAnswer((_) => stateRaw.stream);
      when(() => platform.dispose()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await stateRaw.close();
    });

    test('entering always precedes active', () async {
      final pip = LiveKitPip();
      final emitted = <PipState>[];
      final sub = pip.stateStream.listen(emitted.add);

      await pip.initialize(
        room: Room(),
        config: const LiveKitPipConfiguration(
          android: AndroidPipConfiguration(pipWidgetBuilder: _dummyBuilder),
          ios: IosPipConfiguration(),
        ),
      );

      // Emit AFTER initialize so _stateSubscription is wired up
      stateRaw
        ..add(2) // entering
        ..add(3); // active
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      await pip.dispose();

      final enterIdx = emitted.indexOf(PipState.entering);
      final activeIdx = emitted.indexOf(PipState.active);
      expect(enterIdx, isNot(-1), reason: 'entering must be emitted');
      expect(activeIdx, isNot(-1), reason: 'active must be emitted');
      expect(enterIdx, lessThan(activeIdx));
    });

    test('exiting always precedes inactive', () async {
      final pip = LiveKitPip();
      final emitted = <PipState>[];
      final sub = pip.stateStream.listen(emitted.add);

      await pip.initialize(
        room: Room(),
        config: const LiveKitPipConfiguration(
          android: AndroidPipConfiguration(pipWidgetBuilder: _dummyBuilder),
          ios: IosPipConfiguration(),
        ),
      );

      stateRaw
        ..add(4) // exiting
        ..add(1); // inactive
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      await pip.dispose();

      final exitIdx = emitted.indexOf(PipState.exiting);
      final inactiveIdx = emitted.indexOf(PipState.inactive);
      expect(exitIdx, isNot(-1), reason: 'exiting must be emitted');
      expect(inactiveIdx, isNot(-1), reason: 'inactive must be emitted');
      expect(exitIdx, lessThan(inactiveIdx));
    });

    test('stateStream closes after dispose()', () async {
      final pip = LiveKitPip();
      await pip.initialize(
        room: Room(),
        config: const LiveKitPipConfiguration(
          android: AndroidPipConfiguration(
            pipWidgetBuilder: _dummyBuilder,
          ),
          ios: IosPipConfiguration(),
        ),
      );

      var doneFired = false;
      pip.stateStream.listen(null, onDone: () => doneFired = true);

      await pip.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(doneFired, isTrue);
    });
  });
}

Widget _dummyBuilder(BuildContext context, Room room) =>
    const SizedBox.shrink();
