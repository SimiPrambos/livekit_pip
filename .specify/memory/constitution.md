<!--
SYNC IMPACT REPORT
==================
Version change: [PLACEHOLDER] → 1.0.0
Type of bump: MINOR (initial population — all placeholders replaced with concrete content)

Modified principles (old → new):
  [PRINCIPLE_1_NAME] → I. Code Quality & Static Analysis
  [PRINCIPLE_2_NAME] → II. Test-First, Platform-Aware Testing
  [PRINCIPLE_3_NAME] → III. Platform Asymmetry Fidelity
  [PRINCIPLE_4_NAME] → IV. Consumer UX Consistency
  [PRINCIPLE_5_NAME] → V. Frame Pipeline Performance

Added sections:
  Platform & Dependency Constraints
  Development Workflow

Removed sections: none

Templates reviewed:
  .specify/templates/plan-template.md     ✅ no changes needed (Constitution Check is filled at plan-time)
  .specify/templates/spec-template.md     ✅ no changes needed
  .specify/templates/tasks-template.md    ✅ no changes needed

Deferred TODOs: none
-->

# livekit_pip Constitution

## Core Principles

### I. Code Quality & Static Analysis

All Dart code in every package (`livekit_pip`, `livekit_pip_platform_interface`,
`livekit_pip_android`, `livekit_pip_ios`) MUST pass `flutter analyze` with zero
warnings before any commit lands. The project uses `very_good_analysis` — the
stricter-than-default lint ruleset from Very Good Ventures — and no rule MUST be
silenced with `// ignore:` without an inline comment explaining an unavoidable
platform constraint.

- Pigeon-generated files (`*.g.dart`, `Messages.g.kt`, `Messages.g.swift`) MUST
  never be hand-edited; regenerate via `dart run pigeon` only.
- All public Dart symbols MUST have doc comments (`///`).
- No `dynamic` usage except where Pigeon-generated code requires it.
- Kotlin and Swift code MUST follow the platform idiomatic style (Kotlin official
  style guide; Swift API Design Guidelines).

**Rationale**: `very_good_analysis` is the boilerplate's chosen baseline; relaxing
it creates drift from the package's quality promise to consumers. Pigeon is the
single source of truth for the native bridge contract — hand-edits break it silently.

### II. Test-First, Platform-Aware Testing

Unit tests MUST be written before implementation for every new public class or
method. The Red-Green-Refactor cycle is mandatory.

- Dart unit tests use `mocktail` with `MockPlatformInterfaceMixin`; no hand-rolled
  fakes for platform interfaces.
- Run `flutter test` from within each package directory; tests MUST pass in CI
  before merging.
- iOS PiP behavior tests (anything touching `AVPictureInPictureController` or
  `AVSampleBufferDisplayLayer`) are device-only; they MUST be marked as
  `@Skip('requires physical device')` and documented in the test file.
- `ActiveSpeakerSelector` logic and `PipState` transitions MUST have exhaustive
  unit tests covering every valid state transition and the boundary conditions
  (empty room, all participants muted, rapid speaker churn).
- Integration tests (Fluttium flows) gate Phase 3 completion for each build phase.

**Rationale**: The iOS simulator cannot run PiP; pretending otherwise produces
false confidence. Dart-layer logic is fully simulatable and MUST be covered there.

### III. Platform Asymmetry Fidelity

The Android and iOS implementations are architecturally different by design and
MUST NOT be converged.

- **Android**: PiP content is always a Flutter widget supplied via
  `AndroidPipConfiguration.pipWidgetBuilder`. No native video rendering on Android.
- **iOS**: PiP content is always a single `AVSampleBufferDisplayLayer` driven by
  one dominant-speaker video track. An arbitrary N-tile grid MUST NOT be attempted
  natively on iOS — composite at most a 2-feed (dominant + self-view inset) via
  `PixelBufferCompositor`.
- The `AVSampleBufferDisplayLayer` and its `AVPictureInPictureController` MUST
  never be recreated mid-call. Track switching MUST rebind the renderer source only.
- `NativeTrackResolver` MUST be the only file that touches flutter_webrtc internals
  on iOS. Any breaking change to flutter_webrtc's native track registry affects
  exactly one file.

**Rationale**: iOS has no "shrink the app" mode. Fighting the platform wastes effort
and produces fragile code. The asymmetry is a first-class design constraint, not a
deficiency.

### IV. Consumer UX Consistency

The public Dart API surface defined in CLAUDE.md is the contract. It MUST NOT be
changed without a version bump and migration note.

- `PipState` transitions MUST be deterministic and exhaustive: every native callback
  maps to exactly one `PipState` value; intermediate states (`entering`, `exiting`)
  MUST be emitted even on fast transitions.
- `LiveKitPip.isSupported()` MUST be called and checked before any other method;
  methods called on an unsupported device MUST throw `UnsupportedError` with a
  clear message, never silently no-op.
- `LiveKitPip.dispose()` MUST release all native resources (renderer, compositor,
  PiP controller) and complete the `stateStream` with a done event. Calling any
  method after `dispose()` MUST throw `StateError`.
- `LiveKitPipConfiguration.disableWhenScreenSharing` MUST be honoured on both
  platforms; screen-share detection is a required gate, not optional.

**Rationale**: Consumers integrate this plugin into production call apps. Silent
failures or inconsistent state transitions will surface as hard-to-debug production
incidents. Clear contracts reduce integration friction.

### V. Frame Pipeline Performance

The iOS frame pipeline (RTCVideoFrame → CVPixelBuffer → CMSampleBuffer → display
layer) MUST be evaluated on real hardware before each phase ships.

- Frame delivery latency to `AVSampleBufferDisplayLayer` MUST stay below 33 ms per
  frame (30 fps floor) under normal call conditions on a supported device.
- `PixelBufferCompositor` MUST use Core Image or Metal — CPU-only pixel copies are
  not acceptable for the 2-feed compositor path.
- Memory for pixel buffers MUST be managed via a pool (e.g., `CVPixelBufferPool`);
  per-frame allocations are prohibited.
- Android PiP widget rebuilds MUST not trigger janky transitions; the widget tree
  swap on `onPictureInPictureModeChanged` MUST complete within a single frame.

**Rationale**: PiP is a supplementary view shown during multitasking. Users expect
it to be smooth and lightweight. A laggy or battery-draining PiP window will prompt
consumers to disable the feature entirely.

## Platform & Dependency Constraints

- **Android minSdk**: 26 (legacy enter path); auto-enter API available on 31+.
- **iOS deployment target**: 16.0. The `Package.swift` MUST declare `platforms: [.iOS(.v16)]`.
  The current value of 13.0 is a known defect that MUST be corrected in Phase 1.
- **Dart dependency**: `livekit_client` (and its transitive `flutter_webrtc`) is the
  only allowed LiveKit-specific dependency. No direct `flutter_webrtc` import from
  the plugin's public API.
- **Native bridge**: Pigeon only. Hand-written MethodChannel/EventChannel strings are
  permitted only for the state-change EventChannel (not covered by Pigeon's event
  model); document the rationale inline.
- **Federated plugin wiring**: Platform packages extend (never implement)
  `LivekitPipPlatform`; auto-registration via `dartPluginClass` in `pubspec.yaml`.
  Do not use `registerWith` manual registration.

## Development Workflow

- `flutter analyze` MUST pass in all packages before opening a PR. CI enforces this.
- Pigeon bindings MUST be regenerated whenever `pigeons/messages.dart` changes:
  run `dart run pigeon --input pigeons/messages.dart` from the relevant package root.
- `very_good_analysis` version MUST be kept in sync across all packages; divergence
  causes rule-set inconsistency.
- Example app (`livekit_pip/example`) MUST compile and run on both Android and iOS
  simulators (Android) / device (iOS PiP flows) before a phase is marked complete.
- Fluttium integration tests (`flows/`) gate phase sign-off; `fluttium test` MUST
  run clean on the target device before merging a phase branch.
- Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`
  etc.). Breaking changes MUST use `!` suffix and include a `BREAKING CHANGE:` footer.

## Governance

This constitution supersedes all other written practices for `livekit_pip`. CLAUDE.md
is the authoritative architecture reference; when CLAUDE.md and this constitution
conflict, CLAUDE.md governs architecture decisions and this constitution governs
process and quality gates. Both MUST be updated together.

Amendment procedure:
1. Propose the change in a PR description with a rationale.
2. Update `LAST_AMENDED_DATE` and increment `CONSTITUTION_VERSION` following semver:
   MAJOR for principle removals or redefinitions; MINOR for additions; PATCH for
   clarifications.
3. Propagate changes to affected templates (plan, spec, tasks) and CLAUDE.md in the
   same PR.

All PRs MUST include a "Constitution Check" confirming no principle is violated.
If a violation is necessary (e.g., an unavoidable platform quirk), it MUST be
documented in `plan.md`'s Complexity Tracking table.

**Version**: 1.0.0 | **Ratified**: 2026-06-17 | **Last Amended**: 2026-06-17
