import 'package:flutter/foundation.dart';

/// One tile of the iOS PiP window: who it is for and what it shows.
@immutable
class PipParticipantInfo {
  /// Creates a tile description.
  const PipParticipantInfo({
    required this.identity,
    required this.isLocal,
    required this.isMicMuted,
    required this.displayName,
    this.videoTrackId,
    this.avatarUrl,
  });

  /// The participant's LiveKit identity; stable for the tile's lifetime.
  final String identity;

  /// True for the user's own tile.
  final bool isLocal;

  /// WebRTC track id of the camera, or null while the camera is off,
  /// unpublished, or (for remote participants) unsubscribed.
  final String? videoTrackId;

  /// True while the microphone is muted or not published.
  final bool isMicMuted;

  /// Name shown as initials when there is no avatar.
  final String displayName;

  /// Avatar image shown while the camera is off.
  final String? avatarUrl;

  @override
  bool operator ==(Object other) =>
      other is PipParticipantInfo &&
      other.identity == identity &&
      other.isLocal == isLocal &&
      other.videoTrackId == videoTrackId &&
      other.isMicMuted == isMicMuted &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(
    identity,
    isLocal,
    videoTrackId,
    isMicMuted,
    displayName,
    avatarUrl,
  );
}
