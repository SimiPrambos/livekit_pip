// LivekitPipApi must be abstract.
// ignore_for_file: one_member_abstracts

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'livekit_pip',
    swiftOut: 'ios/livekit_pip_ios/Sources/livekit_pip_ios/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    copyrightHeader: 'pigeons/copyright.txt',
  ),
)
@HostApi()
abstract class LivekitPipApi {
  @async
  String? getPlatformName();
}
