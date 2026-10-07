import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_pip/src/pip_configuration.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';

/// Builds the tiles of the iOS PiP window from the room: the most recent
/// remote speaker and, optionally, the local participant.
///
/// Reports through `onChanged` only when the tiles differ from the last
/// report, so frequent speaker events do not flood the platform channel.
class PipParticipantTracker {
  /// Creates a tracker attached to [room].
  PipParticipantTracker({
    required Room room,
    required bool includeLocal,
    required void Function(List<PipParticipantInfo> tiles) onChanged,
    PipAvatarUrlResolver? avatarUrlResolver,
  }) : _room = room,
       _includeLocal = includeLocal,
       _onChanged = onChanged,
       _avatarUrlResolver = avatarUrlResolver {
    _listener = room.createListener()
      ..on<ActiveSpeakersChangedEvent>(_onActiveSpeakersChanged)
      ..on<ParticipantConnectedEvent>((_) => refresh())
      ..on<ParticipantDisconnectedEvent>((_) => refresh())
      ..on<TrackPublishedEvent>((_) => refresh())
      ..on<TrackUnpublishedEvent>((_) => refresh())
      ..on<TrackSubscribedEvent>((_) => refresh())
      ..on<TrackUnsubscribedEvent>((_) => refresh())
      ..on<TrackMutedEvent>((_) => refresh())
      ..on<TrackUnmutedEvent>((_) => refresh())
      ..on<LocalTrackPublishedEvent>((_) => refresh())
      ..on<LocalTrackUnpublishedEvent>((_) => refresh())
      ..on<ParticipantNameUpdatedEvent>((_) => refresh())
      ..on<ParticipantMetadataUpdatedEvent>((_) => refresh())
      ..on<ParticipantAttributesChanged>((_) => refresh());
  }

  final Room _room;
  final bool _includeLocal;
  final void Function(List<PipParticipantInfo> tiles) _onChanged;
  final PipAvatarUrlResolver? _avatarUrlResolver;
  late final EventsListener<RoomEvent> _listener;

  String? _lastSpeakerIdentity;
  List<PipParticipantInfo>? _lastReported;
  bool _disposed = false;

  /// Recomputes the tiles and reports them if they changed. Also seeds the
  /// first report, since participants may already be in the room.
  void refresh() {
    if (_disposed) return;
    final tiles = [
      ?_remoteTile(),
      if (_includeLocal)
        if (_room.localParticipant case final local?) _tileFor(local),
    ];
    if (listEquals(tiles, _lastReported)) return;
    _lastReported = tiles;
    _onChanged(tiles);
  }

  void _onActiveSpeakersChanged(ActiveSpeakersChangedEvent event) {
    final speaker = event.speakers
        .whereType<RemoteParticipant>()
        .where(_isPerson)
        .firstOrNull;
    // Silence keeps the last speaker on screen instead of flipping back.
    if (speaker != null) _lastSpeakerIdentity = speaker.identity;
    refresh();
  }

  PipParticipantInfo? _remoteTile() {
    final remotes = _room.remoteParticipants;
    final remote =
        remotes[_lastSpeakerIdentity] ??
        remotes.values.where(_isPerson).firstOrNull;
    return remote == null ? null : _tileFor(remote);
  }

  // Telehealth rooms include a voice agent; it has no camera or face to show.
  bool _isPerson(Participant participant) =>
      participant.kind != ParticipantKind.AGENT;

  PipParticipantInfo _tileFor(Participant participant) {
    final isLocal = participant is LocalParticipant;
    return PipParticipantInfo(
      identity: participant.identity,
      isLocal: isLocal,
      videoTrackId: _cameraTrackId(participant),
      isMicMuted: _isMicMuted(participant),
      displayName: participant.name.isNotEmpty
          ? participant.name
          : participant.identity,
      avatarUrl: _avatarUrlResolver?.call(participant),
    );
  }

  String? _cameraTrackId(Participant participant) {
    for (final pub in participant.videoTrackPublications) {
      if (pub.source != TrackSource.camera || pub.muted) continue;
      if (pub is RemoteTrackPublication && !pub.subscribed) continue;
      final trackId = pub.track?.mediaStreamTrack.id;
      if (trackId != null) return trackId;
    }
    return null;
  }

  bool _isMicMuted(Participant participant) {
    final mic = participant.audioTrackPublications
        .where((pub) => pub.source == TrackSource.microphone)
        .firstOrNull;
    return mic == null || mic.muted;
  }

  /// Detaches all Room event listeners. Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _listener.dispose();
  }
}
