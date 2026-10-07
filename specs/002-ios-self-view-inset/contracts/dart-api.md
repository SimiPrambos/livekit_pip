# Contract: Public Dart API changes

Additive for callers of the released API; revision 1's corner/width options never shipped.

```dart
/// Returns an avatar image URL for [participant], or null for initials.
typedef PipAvatarUrlResolver = String? Function(Participant participant);

class IosPipConfiguration {
  const IosPipConfiguration({
    this.includeLocalParticipantVideo = true,
    this.autoEnterOnBackground = true,
    this.mirrorSelfView = true,
    this.avatarUrlResolver,
  });
  final bool includeLocalParticipantVideo;
  final bool autoEnterOnBackground;
  final bool mirrorSelfView;
  final PipAvatarUrlResolver? avatarUrlResolver;
}
```

## Platform interface

```dart
/// Immutable tile description sent to native.
class PipParticipantInfo {
  const PipParticipantInfo({
    required this.identity,
    required this.isLocal,
    required this.isMicMuted,
    required this.displayName,
    this.videoTrackId,
    this.avatarUrl,
  });
  // fields + value equality
}

Future<void> initialize({
  // ...existing required parameters...
  bool iosMirrorSelfView = true,
});

/// iOS only. Default no-op.
Future<void> updateParticipants(List<PipParticipantInfo> participants) async {}
```

`updateLocalTrack` from revision 1 is removed.

## Behavior of `LiveKitPip`

- Builds the tile list with `PipParticipantTracker` and sends it at initialize and on
  every change, until dispose.
- The local tile is included only when `includeLocalParticipantVideo` is true.
