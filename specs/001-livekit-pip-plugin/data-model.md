# Data Model: livekit_pip Plugin

**Phase 1 Output** | **Date**: 2026-06-17 | **Plan**: [plan.md](plan.md)

## PipState Machine

The central state machine governing a `LiveKitPip` controller instance.

```
                 initialize()
[uninitialized] ─────────────► inactive
                                  │
               isSupported()=false│
                                  ▼
                             unsupported  ◄──── (terminal; dispose() to destroy)
                                  
inactive ──── enterPiP() ────► entering ──── (OS confirms) ────► active
  ▲                                                                 │
  │                 exitPiP() / user closes window                  │
  └──────────────────────────── exiting ◄──────────────────────────┘
  │
  └──── Room.disconnected ──► inactive  (auto-exit, resources released)
  
dispose() from any state ──► [destroyed]  (stateStream closed)
```

### Valid Transitions

| From | Event | To | Side Effect |
|------|-------|----|-------------|
| `uninitialized` | `initialize()` | `inactive` | Native setup; EventChannel opens |
| `inactive` | `isSupported()` = false | `unsupported` | No further transitions allowed |
| `inactive` | `enterPiP()` / auto-enter | `entering` | Native PiP request sent |
| `entering` | OS confirms PiP active | `active` | Native callback received |
| `active` | `exitPiP()` / user closes | `exiting` | Native exit request sent |
| `active` | Room disconnected | `exiting` | Auto-exit triggered |
| `exiting` | OS confirms PiP closed | `inactive` | Flutter surface restored |
| any | `dispose()` | `[destroyed]` | All resources released; stream done |

### Invariants

- No transition from `unsupported` to any other state.
- `entering` and `exiting` are transient — they MUST always be followed by
  `active` or `inactive` respectively within one OS round-trip.
- Rapid background/foreground cycling (entering → immediate exiting) MUST still
  emit both intermediate states before settling.
- After `[destroyed]`, any method call throws `StateError`.

---

## Entities

### LiveKitPip

The primary controller. One instance per call session.

| Field | Type | Notes |
|-------|------|-------|
| `_state` | `PipState` | Current state; drives `stateStream` |
| `_room` | `Room?` | Set by `initialize()`; observed for disconnect |
| `_config` | `LiveKitPipConfiguration?` | Set by `initialize()` |
| `_activeSpeakerSelector` | `ActiveSpeakerSelector?` | Created by `initialize()` |
| `_stateController` | `StreamController<PipState>` | Broadcast stream backing `stateStream` |
| `_disposed` | `bool` | Guards against post-dispose calls |

### LiveKitPipConfiguration

Immutable aggregate of platform-specific settings.

| Field | Type | Default |
|-------|------|---------|
| `enabled` | `bool` | `true` |
| `disableWhenScreenSharing` | `bool` | `true` |
| `android` | `AndroidPipConfiguration` | required |
| `ios` | `IosPipConfiguration` | required |

### AndroidPipConfiguration

| Field | Type | Default |
|-------|------|---------|
| `pipWidgetBuilder` | `Widget Function(BuildContext, Room)` | required |
| `autoEnterOnBackground` | `bool` | `true` |

### IosPipConfiguration

| Field | Type | Default |
|-------|------|---------|
| `includeLocalParticipantVideo` | `bool` | `true` |
| `autoEnterOnBackground` | `bool` | `true` |

### ActiveSpeakerSelector

Stateful Dart object observing Room events.

| Field | Type | Notes |
|-------|------|-------|
| `_room` | `Room` | Observed (not owned) |
| `_dominantTrackId` | `String?` | ID of current dominant remote video track |
| `_subscriptions` | `List<StreamSubscription>` | Room event listeners |

**Outputs**: calls `onTrackChanged(String trackId)` callback when the dominant
speaker's video track ID changes.

### LiveKitPipView

Stateless widget. Renders a zero-size box on Android; renders a `UiKitView` hosting
the native `PipPlatformView` on iOS.

### PiP Session (iOS native)

Managed entirely in Swift. Not directly modeled in Dart.

| Component | Responsibility |
|-----------|---------------|
| `PipPlatformView` | Owns `AVSampleBufferDisplayLayer` and `AVPictureInPictureController`; never recreated |
| `PlaybackDelegate` | Satisfies the OS playback delegate with infinite time range |
| `FrameBridge` | Resolves `RTCVideoTrack`, attaches renderer, converts frames, enqueues to display layer |
| `PixelBufferCompositor` | (Phase 2) Composites dominant + self-view into a single `CVPixelBuffer` using Metal/Core Image |
| `NativeTrackResolver` | Single point of contact with flutter_webrtc internals |

### PiP Session (Android native)

Managed in Kotlin.

| Component | Responsibility |
|-----------|---------------|
| `PipPlugin` | Registers channels; holds `Activity` ref |
| `PipHelper` | Builds `PictureInPictureParams`; handles API 26/31 paths; forwards mode changes to Dart |
| `LiveKitPipActivity` | Optional convenience base class wrapping `PipHelper.attach()` |

---

## Native Bridge Message Types (Pigeon)

See [contracts/native-bridge.md](contracts/native-bridge.md) for the full Pigeon
schema. Summary of types crossing the bridge:

| Dart → Native | Native → Dart (FlutterApi) | EventChannel |
|---------------|---------------------------|--------------|
| `PipInitRequest` (trackId, config fields) | — | `PipStateMessage` (stateStream) |
| `enterPip()` | — | — |
| `exitPip()` | — | — |
| `dispose()` | — | — |
| `isSupported()` → `bool` | — | — |
| `updateActiveTrack(trackId)` | — | — |
