import 'package:livekit_client/livekit_client.dart';

/// Subscribes to Room events and tracks the dominant remote speaker's video
/// track ID, calling `onTrackChanged` whenever the dominant track changes.
///
/// Also tracks local camera state and screen-sharing state for use by the
/// native layer (iOS compositor, PiP suppression).
class ActiveSpeakerSelector {
  /// Creates a selector attached to [room].
  ///
  /// [onTrackChanged] is called with the WebRTC track ID whenever the dominant
  /// remote video track changes. Called with `null` when no video is available.
  ActiveSpeakerSelector({
    required Room room,
    required void Function(String? trackId) onTrackChanged,
  })  : _room = room,
        _onTrackChanged = onTrackChanged {
    _listener = room.createListener()
      ..on<ActiveSpeakersChangedEvent>(_onActiveSpeakersChanged)
      ..on<TrackMutedEvent>(_onTrackMuted)
      ..on<TrackUnmutedEvent>(_onTrackUnmuted)
      ..on<LocalTrackPublishedEvent>(_onLocalTrackPublished)
      ..on<LocalTrackUnpublishedEvent>(_onLocalTrackUnpublished);
  }

  final Room _room;
  final void Function(String? trackId) _onTrackChanged;

  late final EventsListener<RoomEvent> _listener;

  String? _lastTrackId;
  bool _localCameraActive = false;
  bool _isScreenSharing = false;
  bool _disposed = false;

  /// True when the local participant has an active (unmuted) camera track.
  bool get isLocalCameraActive => _localCameraActive;

  /// True when the local participant is publishing a screen-share video track.
  bool get isScreenSharing => _isScreenSharing;

  void _onActiveSpeakersChanged(ActiveSpeakersChangedEvent event) {
    for (final speaker in event.speakers) {
      if (speaker is! RemoteParticipant) continue;
      for (final pub in speaker.videoTrackPublications) {
        // Only use subscribed, non-muted camera tracks
        final trackId = pub.track?.mediaStreamTrack.id;
        if (!pub.muted && pub.subscribed && trackId != null) {
          _updateTrack(trackId);
          return;
        }
      }
    }
    // No eligible remote speaker — hold last known track (fallback per spec)
  }

  void _onTrackMuted(TrackMutedEvent event) {
    if (event.participant is! LocalParticipant) return;
    if (event.publication.source == TrackSource.camera) {
      _localCameraActive = false;
    } else if (event.publication.source == TrackSource.screenShareVideo) {
      _isScreenSharing = false;
    }
  }

  void _onTrackUnmuted(TrackUnmutedEvent event) {
    if (event.participant is! LocalParticipant) return;
    if (event.publication.source == TrackSource.camera) {
      _localCameraActive = true;
    } else if (event.publication.source == TrackSource.screenShareVideo) {
      _isScreenSharing = true;
    }
  }

  void _onLocalTrackPublished(LocalTrackPublishedEvent event) {
    if (event.publication.source == TrackSource.screenShareVideo) {
      _isScreenSharing = true;
    } else if (event.publication.source == TrackSource.camera) {
      _localCameraActive = true;
    }
  }

  void _onLocalTrackUnpublished(LocalTrackUnpublishedEvent event) {
    if (event.publication.source == TrackSource.screenShareVideo) {
      _isScreenSharing = false;
    } else if (event.publication.source == TrackSource.camera) {
      _localCameraActive = false;
    }
  }

  /// Returns the best available remote video track ID from the room's current
  /// state, without waiting for an event. Used to seed native on initialize.
  String? get currentBestTrackId {
    for (final p in _room.activeSpeakers) {
      if (p is! RemoteParticipant) continue;
      for (final pub in p.videoTrackPublications) {
        final trackId = pub.track?.mediaStreamTrack.id;
        if (!pub.muted && pub.subscribed && trackId != null) return trackId;
      }
    }
    for (final p in _room.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        final trackId = pub.track?.mediaStreamTrack.id;
        if (!pub.muted && pub.subscribed && trackId != null) return trackId;
      }
    }
    return null;
  }

  void _updateTrack(String trackId) {
    if (trackId == _lastTrackId) return;
    _lastTrackId = trackId;
    _onTrackChanged(trackId);
  }

  /// Detaches all Room event listeners. Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _listener.dispose();
  }
}
