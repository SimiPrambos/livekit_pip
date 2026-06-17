// Copyright (c) 2026, Dev Kaffah

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'livekit_pip_android',
    kotlinOut: 'android/src/main/kotlin/dev/kaffah/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.kaffah'),
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
  });

  bool enabled;
  bool disableWhenScreenSharing;
  bool androidAutoEnterOnBackground;
  bool iosAutoEnterOnBackground;
  bool iosIncludeLocalParticipantVideo;
  int videoWidth;
  int videoHeight;
}

@HostApi()
abstract class LiveKitPipHostApi {
  void initialize(PipInitRequest request);
  void enterPip();
  void exitPip();
  void dispose();
  bool isSupported();
  void updateActiveTrack(String trackId);
}
