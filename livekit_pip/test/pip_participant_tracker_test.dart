import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_pip/src/pip_participant_tracker.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';

import 'helpers/fake_room.dart';

void main() {
  late FakeRoom fake;
  late List<List<PipParticipantInfo>> sent;
  late PipParticipantTracker tracker;
  late Map<String, String?> avatars;

  PipParticipantTracker track({bool includeLocal = true}) =>
      PipParticipantTracker(
        room: fake.room,
        includeLocal: includeLocal,
        avatarUrlResolver: (p) => avatars[p.identity],
        onChanged: sent.add,
      );

  PipParticipantInfo? remoteOf(List<PipParticipantInfo> tiles) =>
      tiles.where((t) => !t.isLocal).firstOrNull;

  PipParticipantInfo? localOf(List<PipParticipantInfo> tiles) =>
      tiles.where((t) => t.isLocal).firstOrNull;

  setUp(() {
    fake = FakeRoom(localIdentity: 'member', localName: 'Member');
    sent = [];
    avatars = {};
  });

  tearDown(() => tracker.dispose());

  test('reports the remote and the local tile with their cameras', () {
    fake
      ..addRemote('clinician', name: 'Dr. Example', cameraTrackId: 'r-cam')
      ..addCamera('l-cam')
      ..addMicrophone();
    avatars['clinician'] = 'https://example.com/c.png';
    tracker = track()..refresh();

    expect(sent.single, const [
      PipParticipantInfo(
        identity: 'clinician',
        isLocal: false,
        isMicMuted: false,
        displayName: 'Dr. Example',
        videoTrackId: 'r-cam',
        avatarUrl: 'https://example.com/c.png',
      ),
      PipParticipantInfo(
        identity: 'member',
        isLocal: true,
        isMicMuted: false,
        displayName: 'Member',
        videoTrackId: 'l-cam',
      ),
    ]);
  });

  test('leaves the local tile out when the self-view is off', () {
    fake
      ..addRemote('clinician', cameraTrackId: 'r-cam')
      ..addCamera('l-cam');
    tracker = track(includeLocal: false)..refresh();
    expect(sent.single.map((t) => t.identity), ['clinician']);
  });

  // The display layer keeps its last frame, so a muted camera must clear the
  // track id or the PiP window freezes on it.
  test('clears the remote video when its camera is muted', () async {
    final clinician = fake.addRemote('clinician', cameraTrackId: 'r-cam');
    tracker = track()..refresh();
    fake.setMuted(
      clinician.camera!,
      muted: true,
      participant: clinician.participant,
    );
    await pumpEventQueue();
    expect(remoteOf(sent.last)!.videoTrackId, isNull);
  });

  test('clears the remote video when it is unsubscribed', () async {
    final clinician = fake.addRemote('clinician', cameraTrackId: 'r-cam');
    tracker = track()..refresh();
    clinician.setCameraSubscribed(subscribed: false);
    await pumpEventQueue();
    expect(remoteOf(sent.last)!.videoTrackId, isNull);
  });

  test('clears the local video when the camera is muted', () async {
    final camera = fake.addCamera('l-cam');
    tracker = track()..refresh();
    fake.setMuted(camera, muted: true);
    await pumpEventQueue();
    expect(localOf(sent.last)!.videoTrackId, isNull);
  });

  test('reports a muted or missing microphone as muted', () {
    fake
      ..addRemote('clinician', micMuted: true)
      ..addRemote('other');
    // The local participant has published no microphone at all.
    tracker = track()..refresh();
    expect(localOf(sent.single)!.isMicMuted, isTrue);
    expect(remoteOf(sent.single)!.isMicMuted, isTrue);
  });

  test('follows the most recent remote speaker', () async {
    fake.addRemote('clinician', cameraTrackId: 'c-cam');
    final nurse = fake.addRemote('nurse', cameraTrackId: 'n-cam');
    tracker = track()..refresh();
    fake.speak([nurse.participant]);
    await pumpEventQueue();
    expect(remoteOf(sent.last)!.identity, 'nurse');
  });

  test('keeps the last speaker when nobody is speaking', () async {
    fake.addRemote('clinician');
    final nurse = fake.addRemote('nurse');
    tracker = track()..refresh();
    fake.speak([nurse.participant]);
    await pumpEventQueue();
    fake.speak([]);
    await pumpEventQueue();
    expect(remoteOf(sent.last)!.identity, 'nurse');
  });

  test('never picks an AI agent, even when it speaks', () async {
    final agent = fake.addRemote('agent', kind: ParticipantKind.AGENT);
    fake.addRemote('clinician');
    tracker = track()..refresh();
    expect(remoteOf(sent.single)!.identity, 'clinician');
    fake.speak([agent.participant]);
    await pumpEventQueue();
    expect(remoteOf(sent.last)!.identity, 'clinician');
  });

  test('drops the remote tile when they leave', () async {
    final clinician = fake.addRemote('clinician');
    tracker = track()..refresh();
    fake.disconnect(clinician);
    await pumpEventQueue();
    expect(remoteOf(sent.last), isNull);
  });

  test('asks for the avatar again when the name changes', () async {
    final clinician = fake.addRemote('clinician', name: 'Dr. A');
    tracker = track()..refresh();
    avatars['clinician'] = 'https://example.com/new.png';
    clinician.rename('Dr. B');
    await pumpEventQueue();
    final remote = remoteOf(sent.last)!;
    expect(remote.displayName, 'Dr. B');
    expect(remote.avatarUrl, 'https://example.com/new.png');
  });

  test('uses the identity when there is no name', () {
    fake.addRemote('clinician');
    tracker = track()..refresh();
    expect(remoteOf(sent.single)!.displayName, 'clinician');
  });

  test('does not resend tiles that did not change', () async {
    final clinician = fake.addRemote('clinician');
    tracker = track()..refresh();
    fake.speak([clinician.participant]);
    await pumpEventQueue();
    expect(sent, hasLength(1));
  });

  test('stops reporting after dispose', () async {
    final camera = fake.addCamera('l-cam');
    tracker = track()..refresh();
    await tracker.dispose();
    fake.setMuted(camera, muted: true);
    await pumpEventQueue();
    expect(sent, hasLength(1));
  });
}
