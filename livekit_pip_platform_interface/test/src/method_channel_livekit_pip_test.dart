import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('$MethodChannelLivekitPip', () {
    late MethodChannelLivekitPip methodChannelLivekitPip;

    setUp(() {
      methodChannelLivekitPip = MethodChannelLivekitPip();
    });

    test('isSupported throws UnimplementedError', () {
      expect(
        () => methodChannelLivekitPip.isSupported(),
        throwsUnimplementedError,
      );
    });

    test('enterPip throws UnimplementedError', () {
      expect(
        () => methodChannelLivekitPip.enterPip(),
        throwsUnimplementedError,
      );
    });

    test('exitPip throws UnimplementedError', () {
      expect(
        () => methodChannelLivekitPip.exitPip(),
        throwsUnimplementedError,
      );
    });

    test('dispose throws UnimplementedError', () {
      expect(
        () => methodChannelLivekitPip.dispose(),
        throwsUnimplementedError,
      );
    });

    test('updateActiveTrack throws UnimplementedError', () {
      expect(
        () => methodChannelLivekitPip.updateActiveTrack('track-1'),
        throwsUnimplementedError,
      );
    });

    test('stateStream throws UnimplementedError', () {
      expect(
        () => methodChannelLivekitPip.stateStream,
        throwsUnimplementedError,
      );
    });
  });
}
