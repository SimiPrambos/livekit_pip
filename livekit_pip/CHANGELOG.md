# Changelog

## [0.2.0](https://github.com/SimiPrambos/livekit_pip/compare/livekit_pip-v0.1.0...livekit_pip-v0.2.0) (2026-06-22)


### Features

* add LiveKitPipScaffold for Android PiP widget swap ([feb91ed](https://github.com/SimiPrambos/livekit_pip/commit/feb91ed4fa1b0e0bb87434bf0868d54c0de548a7))
* add PiP aspect-ratio clamp utility ([f9fdb62](https://github.com/SimiPrambos/livekit_pip/commit/f9fdb626c97bddf8b00f5984fe50d498ffcb83c7))
* **example:** add LiveKit connect page with URL + token input ([c7f3500](https://github.com/SimiPrambos/livekit_pip/commit/c7f350047a13004b0ffd134252ecab330d6d923e))
* **example:** add real video rendering with camera/mic controls ([3f2cbba](https://github.com/SimiPrambos/livekit_pip/commit/3f2cbbadec66857b88c0bb9cb7736b6d2497a3f9))
* **example:** call page with LiveKitPipView, stateStream, Enter/Exit/Dispose (T045-T046) ([db9c1ba](https://github.com/SimiPrambos/livekit_pip/commit/db9c1ba68b2ee6ab87fb1bf985dc13180c2f47ae))
* **example:** wire Android PiP (LiveKitPipActivity, manifest, scaffold) ([76a01c0](https://github.com/SimiPrambos/livekit_pip/commit/76a01c0d076415364003f69383147768f4bb9682))
* **foundational:** Dart types, platform interface, LiveKitPip skeleton (T006-T009, T014-T015) ([f7b6c59](https://github.com/SimiPrambos/livekit_pip/commit/f7b6c59e5962165c01d31bd1b4e0b86ebe5e9cf4))
* initial commit ([b805958](https://github.com/SimiPrambos/livekit_pip/commit/b805958c725afdebd1f9866f491cb8418b102f1f))
* push dominant-track aspect ratio and expose room/config ([4b21ef1](https://github.com/SimiPrambos/livekit_pip/commit/4b21ef10a54c7d0e0348192420930d6c420c357b))
* **setup:** add livekit_client dep, fix iOS 16 target, rename plugin classes (T001-T005) ([22a6a51](https://github.com/SimiPrambos/livekit_pip/commit/22a6a51d8460efc49246d3dfa9e22d315add22bf))
* surface dominant-track dimensions from ActiveSpeakerSelector ([7c3b1bb](https://github.com/SimiPrambos/livekit_pip/commit/7c3b1bb43c7b5b518203e1edf12d1a55f578611a))
* **us1-dart:** LiveKitPip full impl, guards, lifecycle tests (T021-T027) ([5b33469](https://github.com/SimiPrambos/livekit_pip/commit/5b334699dfe709b2f13d27a5b1e29c93b8fc5081))
* **us2:** implement ActiveSpeakerSelector and wire into LiveKitPip ([8184a22](https://github.com/SimiPrambos/livekit_pip/commit/8184a22d9f125165bf2f57493bf0ad7e8c75e92f))
* **us2:** iOS compositor, rebindTrack, speaker switch flow ([dc83146](https://github.com/SimiPrambos/livekit_pip/commit/dc83146b184cc25719064bf22745f6258b9fc579))
* **us3:** screen-share suppression, disconnect auto-exit, edge case flow ([61580ea](https://github.com/SimiPrambos/livekit_pip/commit/61580eabba9b3606429a79f5257d3742027ffc00))


### Bug Fixes

* **android:** fix PiP mode detection and add camera/mic permissions ([2b635b4](https://github.com/SimiPrambos/livekit_pip/commit/2b635b478bf5af500eba2123d4db07b2d568202c))
* correct README alternative code, fix PipHelper lifecycle leak, reset platform in scaffold tearDown ([aa41263](https://github.com/SimiPrambos/livekit_pip/commit/aa41263d9b69267d39c3a9df149f50f869a9df17))
* **ios:** declare flutter_webrtc dependency in podspec, fix Podfile ([bb9652a](https://github.com/SimiPrambos/livekit_pip/commit/bb9652acbfe7df61886184a769a8ce6192236817))
* **ios:** fix PiP not starting on first minimize; dynamic aspect ratio ([5838945](https://github.com/SimiPrambos/livekit_pip/commit/5838945cff056bd2aaea37fbe4dfa2a38a86d0df))
* pin all iOS 26 SDK offenders in example dependency_overrides ([f4513ee](https://github.com/SimiPrambos/livekit_pip/commit/f4513eedda6286c6cdd0085bca0e769b1cb2af53))
* pin connectivity_plus to 7.0.0 and add missing LICENSE file ([b88c3d8](https://github.com/SimiPrambos/livekit_pip/commit/b88c3d84bc423bc4e60f8c4416addcb8a55266dc))
* **polish:** zero analyze warnings, mark T068-T071 done ([092fc00](https://github.com/SimiPrambos/livekit_pip/commit/092fc00a288a6389c2f92d957634b71f226f4305))
* resolve pub.dev publish validation errors ([19a2352](https://github.com/SimiPrambos/livekit_pip/commit/19a2352a7f9bc14f2a88496463573450bce1fb66))
* seed native track on initialize and allow re-initialize after dispose ([9b13c71](https://github.com/SimiPrambos/livekit_pip/commit/9b13c711fd25f2a1b39d87582aaf0c5405e0030a))
* update PRODUCT_BUNDLE_IDENTIFIER for iOS example project ([c31b370](https://github.com/SimiPrambos/livekit_pip/commit/c31b3704f4835df8103d642a598cbb20575f12c3))

## 0.1.0+1

- Initial release.
- Android PiP with `PictureInPictureParams`; auto-enter on API 31+, manual enter on API 26–30.
- iOS PiP via `AVSampleBufferDisplayLayer` with dominant-speaker video track pipeline.
- `LiveKitPip` controller with `PipState` stream.
- `LiveKitPipView` platform view widget.
- `LiveKitPipConfiguration` with per-platform `AndroidPipConfiguration` and `IosPipConfiguration`.
