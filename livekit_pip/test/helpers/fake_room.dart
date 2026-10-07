import 'dart:collection';

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:mocktail/mocktail.dart';

class _MockRoom extends Mock implements Room {}

class _MockLocalParticipant extends Mock implements LocalParticipant {}

class _MockRemoteParticipant extends Mock implements RemoteParticipant {}

class _MockLocalVideoPublication extends Mock
    implements LocalTrackPublication<LocalVideoTrack> {}

class _MockLocalAudioPublication extends Mock
    implements LocalTrackPublication<LocalAudioTrack> {}

class _MockRemoteVideoPublication extends Mock
    implements RemoteTrackPublication<RemoteVideoTrack> {}

class _MockRemoteAudioPublication extends Mock
    implements RemoteTrackPublication<RemoteAudioTrack> {}

class _MockLocalVideoTrack extends Mock implements LocalVideoTrack {}

class _MockRemoteVideoTrack extends Mock implements RemoteVideoTrack {}

class _MockMediaStreamTrack extends Mock implements rtc.MediaStreamTrack {}

rtc.MediaStreamTrack _mediaTrack(String id) {
  final track = _MockMediaStreamTrack();
  when(() => track.id).thenReturn(id);
  return track;
}

/// A [Room] stand-in whose events and participants the test controls.
///
/// Setters change state silently; pair them with [emit] (or the helpers that
/// emit) the way the real room would.
class FakeRoom {
  FakeRoom({String localIdentity = 'me', String localName = ''}) {
    when(
      room.createListener,
    ).thenAnswer((_) => EventsListener<RoomEvent>(_events));
    when(() => room.activeSpeakers).thenAnswer(
      (_) => UnmodifiableListView(_activeSpeakers),
    );
    when(
      () => room.remoteParticipants,
    ).thenAnswer((_) => UnmodifiableMapView(_remotes));
    when(() => room.localParticipant).thenReturn(local);
    when(() => local.identity).thenReturn(localIdentity);
    when(() => local.name).thenReturn(localName);
    when(() => local.videoTrackPublications).thenAnswer((_) => _publications);
    when(
      () => local.audioTrackPublications,
    ).thenAnswer((_) => _localAudio);
  }

  final Room room = _MockRoom();
  final LocalParticipant local = _MockLocalParticipant();
  final _events = EventsEmitter<RoomEvent>();
  final _publications = <LocalTrackPublication<LocalVideoTrack>>[];
  final _localAudio = <LocalTrackPublication<LocalAudioTrack>>[];
  final _remotes = <String, RemoteParticipant>{};
  final _activeSpeakers = <Participant>[];

  /// Publishes a local camera track with [trackId], unmuted, without an event.
  LocalTrackPublication<LocalVideoTrack> addCamera(String trackId) {
    final track = _MockLocalVideoTrack();
    final mediaTrack = _mediaTrack(trackId);
    when(() => track.mediaStreamTrack).thenReturn(mediaTrack);
    final publication = _MockLocalVideoPublication();
    when(() => publication.source).thenReturn(TrackSource.camera);
    when(() => publication.muted).thenReturn(false);
    when(() => publication.track).thenReturn(track);
    _publications.add(publication);
    return publication;
  }

  /// Publishes a local microphone, without an event.
  LocalTrackPublication<LocalAudioTrack> addMicrophone({bool muted = false}) {
    final publication = _MockLocalAudioPublication();
    when(() => publication.source).thenReturn(TrackSource.microphone);
    when(() => publication.muted).thenReturn(muted);
    _localAudio.add(publication);
    return publication;
  }

  /// Publishes a camera and emits [LocalTrackPublishedEvent].
  LocalTrackPublication<LocalVideoTrack> publishCamera(String trackId) {
    final publication = addCamera(trackId);
    emit(
      LocalTrackPublishedEvent(participant: local, publication: publication),
    );
    return publication;
  }

  /// Unpublishes [publication] and emits [LocalTrackUnpublishedEvent].
  void unpublish(LocalTrackPublication<LocalVideoTrack> publication) {
    _publications.remove(publication);
    emit(
      LocalTrackUnpublishedEvent(participant: local, publication: publication),
    );
  }

  /// Sets [publication]'s mute state and emits the matching event.
  void setMuted(
    TrackPublication publication, {
    required bool muted,
    Participant? participant,
  }) {
    when(() => publication.muted).thenReturn(muted);
    final owner = participant ?? local;
    emit(
      muted
          ? TrackMutedEvent(participant: owner, publication: publication)
          : TrackUnmutedEvent(participant: owner, publication: publication),
    );
  }

  /// Adds a remote participant, without an event.
  FakeRemote addRemote(
    String identity, {
    String name = '',
    ParticipantKind kind = ParticipantKind.STANDARD,
    String? cameraTrackId,
    bool micMuted = false,
  }) {
    final remote = FakeRemote._(this, identity, name, kind)
      ..setCamera(cameraTrackId)
      ..setMicMuted(muted: micMuted);
    _remotes[identity] = remote.participant;
    return remote;
  }

  /// Removes [remote] and emits [ParticipantDisconnectedEvent].
  void disconnect(FakeRemote remote) {
    _remotes.remove(remote.participant.identity);
    _activeSpeakers.remove(remote.participant);
    emit(ParticipantDisconnectedEvent(participant: remote.participant));
  }

  /// Sets the active speakers and emits [ActiveSpeakersChangedEvent].
  void speak(List<Participant> speakers) {
    _activeSpeakers
      ..clear()
      ..addAll(speakers);
    emit(ActiveSpeakersChangedEvent(speakers: speakers));
  }

  /// Emits [event] to every listener created from [room].
  ///
  /// Delivery is asynchronous; await `pumpEventQueue()` before asserting.
  void emit(RoomEvent event) {
    // emit() is @internal to livekit_client; there is no public way to drive
    // room events in a unit test.
    // ignore: invalid_use_of_internal_member
    _events.emit(event);
  }
}

/// A remote participant inside a [FakeRoom].
class FakeRemote {
  FakeRemote._(this._room, String identity, String name, ParticipantKind kind) {
    when(() => participant.identity).thenReturn(identity);
    when(() => participant.name).thenReturn(name);
    when(() => participant.kind).thenReturn(kind);
    when(
      () => participant.videoTrackPublications,
    ).thenAnswer((_) => [?_camera]);
    when(
      () => participant.audioTrackPublications,
    ).thenAnswer((_) => [?_microphone]);
  }

  final FakeRoom _room;
  final RemoteParticipant participant = _MockRemoteParticipant();
  RemoteTrackPublication<RemoteVideoTrack>? _camera;
  RemoteTrackPublication<RemoteAudioTrack>? _microphone;

  /// The camera publication, if any.
  RemoteTrackPublication<RemoteVideoTrack>? get camera => _camera;

  /// Sets a subscribed, unmuted camera with [trackId], or removes it.
  void setCamera(String? trackId) {
    if (trackId == null) {
      _camera = null;
      return;
    }
    final track = _MockRemoteVideoTrack();
    final mediaTrack = _mediaTrack(trackId);
    when(() => track.mediaStreamTrack).thenReturn(mediaTrack);
    final publication = _MockRemoteVideoPublication();
    when(() => publication.source).thenReturn(TrackSource.camera);
    when(() => publication.muted).thenReturn(false);
    when(() => publication.subscribed).thenReturn(true);
    when(() => publication.track).thenReturn(track);
    _camera = publication;
  }

  /// Sets whether the camera is subscribed and emits the matching event.
  void setCameraSubscribed({required bool subscribed}) {
    final publication = _camera!;
    final track = publication.track!;
    when(() => publication.subscribed).thenReturn(subscribed);
    _room.emit(
      subscribed
          ? TrackSubscribedEvent(
              participant: participant,
              publication: publication,
              track: track,
            )
          : TrackUnsubscribedEvent(
              participant: participant,
              publication: publication,
              track: track,
            ),
    );
  }

  /// Sets the microphone's mute state, without an event.
  void setMicMuted({required bool muted}) {
    final publication = _MockRemoteAudioPublication();
    when(() => publication.source).thenReturn(TrackSource.microphone);
    when(() => publication.muted).thenReturn(muted);
    _microphone = publication;
  }

  /// Renames the participant and emits [ParticipantNameUpdatedEvent].
  void rename(String name) {
    when(() => participant.name).thenReturn(name);
    _room.emit(
      ParticipantNameUpdatedEvent(participant: participant, name: name),
    );
  }
}
