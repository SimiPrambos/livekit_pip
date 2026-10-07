// Copyright (c) 2026, Dev kaffah

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'livekit_pip_ios',
    swiftOut: 'ios/livekit_pip_ios/Sources/livekit_pip_ios/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    copyrightHeader: 'pigeons/copyright.txt',
  ),
)
class PipInitRequest {
  PipInitRequest({
    this.enabled = true,
    this.disableWhenScreenSharing = true,
    this.androidAutoEnterOnBackground = true,
    this.iosAutoEnterOnBackground = true,
    this.iosIncludeLocalParticipantVideo = true,
    this.videoWidth = 0,
    this.videoHeight = 0,
    this.iosMirrorSelfView = true,
    this.iosAnimateExit = true,
  });

  bool enabled;
  bool disableWhenScreenSharing;
  bool androidAutoEnterOnBackground;
  bool iosAutoEnterOnBackground;
  bool iosIncludeLocalParticipantVideo;
  int videoWidth;
  int videoHeight;

  bool iosMirrorSelfView;
  bool iosAnimateExit;
}

/// One tile of the PiP window.
class PipParticipant {
  PipParticipant({
    required this.identity,
    required this.isLocal,
    required this.isMicMuted,
    required this.displayName,
    this.videoTrackId,
    this.avatarUrl,
  });

  String identity;
  bool isLocal;

  /// Null while the camera is off, unpublished, or unsubscribed.
  String? videoTrackId;
  bool isMicMuted;
  String displayName;
  String? avatarUrl;
}

@HostApi()
abstract class LiveKitPipHostApi {
  void initialize(PipInitRequest request);
  void enterPip();
  void exitPip();
  void dispose();
  bool isSupported();
  void updateActiveTrack(String trackId);

  /// Tiles of the PiP window: the remote speaker and the local camera.
  void updateParticipants(List<PipParticipant> participants);
}
