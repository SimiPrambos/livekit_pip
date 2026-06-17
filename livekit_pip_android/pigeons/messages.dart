// LivekitPipApi must be abstract.
// ignore_for_file: one_member_abstracts

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'livekit_pip',
    kotlinOut: 'android/src/main/kotlin/dev/kaffah/Messages.g.kt',
    kotlinOptions: KotlinOptions(),
    copyrightHeader: 'pigeons/copyright.txt',
  ),
)
@HostApi()
abstract class LivekitPipApi {
  @async
  String? getPlatformName();
}
