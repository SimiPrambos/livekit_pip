# Changelog

## [0.2.0](https://github.com/SimiPrambos/livekit_pip/compare/livekit_pip_android-v0.1.0...livekit_pip_android-v0.2.0) (2026-06-22)


### Features

* **android:** add updateAspectRatio pigeon method and wiring ([8930e47](https://github.com/SimiPrambos/livekit_pip/commit/8930e476c26870102f0ea3640268b9ef6e155e90))
* **android:** enter PiP via onUserLeaveHint and apply dynamic aspect ratio ([10aca5f](https://github.com/SimiPrambos/livekit_pip/commit/10aca5f53173e764bad53a3967594d1ebd3346f5))
* **android:** forward onUserLeaveHint from LiveKitPipActivity to plugin ([4236eed](https://github.com/SimiPrambos/livekit_pip/commit/4236eedca734738493ba6ebe33468476614b8ca8))
* **android:** PipPlugin channel registration, PipHelper, LiveKitPipActivity (T016, T028-T035) ([6dd42cc](https://github.com/SimiPrambos/livekit_pip/commit/6dd42cc604410cceafb103522c7791baead96090))
* **foundational:** Pigeon schemas, regenerated bindings, platform Dart impls (T010-T013) ([a5a680a](https://github.com/SimiPrambos/livekit_pip/commit/a5a680a0ef958017c95ac9b08e851894df3514a3))
* initial commit ([b805958](https://github.com/SimiPrambos/livekit_pip/commit/b805958c725afdebd1f9866f491cb8418b102f1f))
* **setup:** add livekit_client dep, fix iOS 16 target, rename plugin classes (T001-T005) ([22a6a51](https://github.com/SimiPrambos/livekit_pip/commit/22a6a51d8460efc49246d3dfa9e22d315add22bf))


### Bug Fixes

* **android:** fix PiP mode detection and add camera/mic permissions ([2b635b4](https://github.com/SimiPrambos/livekit_pip/commit/2b635b478bf5af500eba2123d4db07b2d568202c))
* apply dart format and add missing dartdoc to pass pana checks ([c97d03a](https://github.com/SimiPrambos/livekit_pip/commit/c97d03ae4ef84295861c5d8054320570e84537d8))
* correct README alternative code, fix PipHelper lifecycle leak, reset platform in scaffold tearDown ([aa41263](https://github.com/SimiPrambos/livekit_pip/commit/aa41263d9b69267d39c3a9df149f50f869a9df17))
* resolve pub.dev publish validation errors ([19a2352](https://github.com/SimiPrambos/livekit_pip/commit/19a2352a7f9bc14f2a88496463573450bce1fb66))

## 0.1.0+1

- Initial release.
- Android implementation using `PictureInPictureParams`.
- Auto-enter PiP on API 31+; manual enter via `onUserLeaveHint` on API 26–30.
- `PipHelper` attaches to any Activity; `LiveKitPipActivity` provided as a convenience base class.
- Consumer-supplied `pipWidgetBuilder` rendered inside the PiP window via Flutter widget swap.
