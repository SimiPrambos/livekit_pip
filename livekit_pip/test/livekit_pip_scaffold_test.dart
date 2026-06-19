import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_pip/livekit_pip.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements LivekitPipPlatform {}

LiveKitPipConfiguration _config() => LiveKitPipConfiguration(
      android: AndroidPipConfiguration(
        pipWidgetBuilder: (_, _) => const Text('PIP'),
      ),
      ios: const IosPipConfiguration(),
    );

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
    when(() => platform.dispose()).thenAnswer((_) async {});
    when(() => platform.updateActiveTrack(any())).thenAnswer((_) async {});
    when(() => platform.updateAspectRatio(any(), any()))
        .thenAnswer((_) async {});
  });

  tearDown(() async => stateRaw.close());

  testWidgets('Android: shows pip widget when active, builder otherwise',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final pip = LiveKitPip();
    final room = Room();
    await tester.runAsync(() => pip.initialize(room: room, config: _config()));

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LiveKitPipScaffold(
          pip: pip,
          builder: (_) => const Text('FULL'),
        ),
      ),
    );
    expect(find.text('FULL'), findsOneWidget);
    expect(find.text('PIP'), findsNothing);

    await tester.runAsync(() async => stateRaw.add(3)); // active
    await tester.pump();
    await tester.pump();
    expect(find.text('PIP'), findsOneWidget);
    expect(find.text('FULL'), findsNothing);

    await tester.runAsync(pip.dispose);
    await tester.runAsync(room.dispose);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('non-Android: always shows builder', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final pip = LiveKitPip();
    final room = Room();
    await tester.runAsync(() => pip.initialize(room: room, config: _config()));

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LiveKitPipScaffold(
          pip: pip,
          builder: (_) => const Text('FULL'),
        ),
      ),
    );
    await tester.runAsync(() async => stateRaw.add(3)); // active
    await tester.pump();
    await tester.pump();
    expect(find.text('FULL'), findsOneWidget);
    expect(find.text('PIP'), findsNothing);

    await tester.runAsync(pip.dispose);
    await tester.runAsync(room.dispose);
    debugDefaultTargetPlatformOverride = null;
  });
}
