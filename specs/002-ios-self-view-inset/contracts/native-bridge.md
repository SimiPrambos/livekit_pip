# Contract: Native bridge (Pigeon)

Source of truth: `pigeons/messages.dart` per platform package; regenerate, never hand-edit.

## PipInitRequest (both packages)

Keeps `iosMirrorSelfView` (bool, default true). Removes `iosSelfViewCorner` and
`iosSelfViewWidthFraction`.

## iOS only

```dart
class PipParticipant {
  String identity;
  bool isLocal;
  String? videoTrackId;
  bool isMicMuted;
  String displayName;
  String? avatarUrl;
}

@HostApi()
abstract class LiveKitPipHostApi {
  // ...existing...
  void updateParticipants(List<PipParticipant> participants);
}
```

`updateLocalTrack` is removed. `updateActiveTrack` stays in the contract (Android and
the shared interface use it) and is a no-op on iOS, which takes the remote video from
`updateParticipants`.

## iOS native behavior

| Input | Effect |
|---|---|
| `initialize(request)` | Stores mirroring |
| `updateParticipants(list)` | Binds the remote and local tiles; resolves track ids; loads avatars; re-lays out |
| Local tile bound with a video track | Requests multitasking camera on the capture session when supported |
| `AVCaptureSession` interrupted / ended | Local tile shows avatar / video |
| A renderer reports a new frame size | Re-lays out; updates `preferredContentSize` |
| `dispose()` | Clears both tiles |

Values that arrive before the platform view exists are kept on the plugin and applied
when it is created.
