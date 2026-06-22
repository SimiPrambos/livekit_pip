import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_pip/src/active_speaker_selector.dart';

void main() {
  group('ActiveSpeakerSelector', () {
    test('can be created and disposed without error', () async {
      final room = Room();
      final selector = ActiveSpeakerSelector(
        room: room,
        onTrackChanged: (_) {},
      );
      await selector.dispose();
      await room.dispose();
    });

    test('does not crash on empty room', () async {
      final room = Room();
      String? lastTrackId;
      final selector = ActiveSpeakerSelector(
        room: room,
        onTrackChanged: (id) => lastTrackId = id,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(lastTrackId, isNull);
      await selector.dispose();
      await room.dispose();
    });

    test('dispose is idempotent', () async {
      final room = Room();
      final selector = ActiveSpeakerSelector(
        room: room,
        onTrackChanged: (_) {},
      );
      await selector.dispose();
      await selector.dispose(); // must not throw
      await room.dispose();
    });

    test(
      'accepts onAspectRatioChanged and exposes currentBestDimensions',
      () async {
        final room = Room();
        final selector = ActiveSpeakerSelector(
          room: room,
          onTrackChanged: (_) {},
          onAspectRatioChanged: (_, _) {},
        );
        // Empty room → no dimensions known yet.
        expect(selector.currentBestDimensions, isNull);
        await selector.dispose();
        await room.dispose();
      },
    );
  });
}
