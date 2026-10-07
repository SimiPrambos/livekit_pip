import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_pip/livekit_pip.dart';

void main() {
  group('AndroidPipConfiguration', () {
    test('window follows the active speaker by default', () {
      final config = AndroidPipConfiguration(
        pipWidgetBuilder: (_, _) => const SizedBox.shrink(),
      );
      expect(config.aspectRatioFollowsActiveSpeaker, isTrue);
    });
  });

  group('IosPipConfiguration', () {
    test('self-view on and mirrored, exit animated, with no avatars', () {
      const config = IosPipConfiguration();
      expect(config.includeLocalParticipantVideo, isTrue);
      expect(config.mirrorSelfView, isTrue);
      expect(config.animateExit, isTrue);
      expect(config.avatarUrlResolver, isNull);
    });

    test('keeps the avatar resolver it is given', () {
      String? resolver(Participant participant) => 'https://example.com/a.png';
      final config = IosPipConfiguration(avatarUrlResolver: resolver);
      expect(config.avatarUrlResolver, same(resolver));
    });
  });
}
