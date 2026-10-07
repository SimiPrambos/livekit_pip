# Quickstart: iOS PiP Split View

## Configure

```dart
await pip.initialize(
  room: room,
  config: LiveKitPipConfiguration(
    android: AndroidPipConfiguration(pipWidgetBuilder: buildPipTile),
    ios: IosPipConfiguration(
      includeLocalParticipantVideo: true, // default
      mirrorSelfView: true, // default
      avatarUrlResolver: (participant) => avatarFor(participant.identity),
    ),
  ),
);
```

## Keep the user's camera live in PiP

The plugin asks iOS to keep the camera running. The plugin requires iOS 16,
and at that deployment target iOS agrees without the
`multitasking-camera-access` entitlement, as long as the device reports
multitasking camera support.

Otherwise the user's tile shows their avatar during PiP. The Xcode console prints
`[livekit_pip] multitasking camera access not supported` once in that case.

## Verify on a device (simulator cannot run PiP)

1. Both cameras portrait → leave the app → user's tile left, other person right.
2. Other person rotates to landscape → their tile moves left and widens.
3. Other person turns the camera off → their avatar (or initials) replaces the frame.
4. Other person mutes → badge on their tile.
5. In a qualifying app, the user's own tile stays live; otherwise it shows their avatar.
