# Changelog

## [0.2.0](https://github.com/SimiPrambos/livekit_pip/compare/livekit_pip_ios-v0.1.0...livekit_pip_ios-v0.2.0) (2026-06-22)


### Features

* **foundational:** Pigeon schemas, regenerated bindings, platform Dart impls (T010-T013) ([a5a680a](https://github.com/SimiPrambos/livekit_pip/commit/a5a680a0ef958017c95ac9b08e851894df3514a3))
* initial commit ([b805958](https://github.com/SimiPrambos/livekit_pip/commit/b805958c725afdebd1f9866f491cb8418b102f1f))
* **ios:** add BufferTransformer for RTCVideoFrame resize/conversion ([57f8c84](https://github.com/SimiPrambos/livekit_pip/commit/57f8c84a8f8ed81d496f86441d62802482875d08))
* **ios:** add PipVideoRenderer (UIView+RTCVideoRenderer, Combine delivery) ([360476e](https://github.com/SimiPrambos/livekit_pip/commit/360476ebe323ba523bfd259250b4feab435dc7b2))
* **ios:** add PipWindowSizePolicy (adaptive + fixed) and PipViewControlling protocol ([9b091a6](https://github.com/SimiPrambos/livekit_pip/commit/9b091a69d963c76f360cf40c3ea647070c976bde))
* **ios:** add pixel buffer pool and repository ([1779fee](https://github.com/SimiPrambos/livekit_pip/commit/1779feef3a193918ca26d7a5e09f06ad341d2290))
* **ios:** add RTCYUVBuffer with Accelerate vImage I420→BGRA conversion ([7bd1239](https://github.com/SimiPrambos/livekit_pip/commit/7bd12397c976b96bdac1644577749d18df53e440))
* **ios:** add SampleBufferVideoCallView and SampleBufferVideoRendering protocol ([a6a3514](https://github.com/SimiPrambos/livekit_pip/commit/a6a3514585428f3fbf04851a2ec58d7ae98525ba))
* **ios:** add TrackStateAdapter to keep track enabled during PiP ([a0ed0de](https://github.com/SimiPrambos/livekit_pip/commit/a0ed0de4fa55fc42ef3d06e5226703df0abdcd7f))
* **ios:** add YUV-to-ARGB conversion setup (Accelerate) ([e932554](https://github.com/SimiPrambos/livekit_pip/commit/e9325546569b4962bd3b4d29d6b2cc0fe6b21794))
* **ios:** LiveKitPipPlugin, PipPlatformView, PlaybackDelegate, FrameBridge, NativeTrackResolver (T017-T018, T036-T044) ([550c5e0](https://github.com/SimiPrambos/livekit_pip/commit/550c5e0332929858f6a622827c1168a8a101a2f9))
* **ios:** remove FrameBridge, update plugin to use rebindTrack ([4e5c870](https://github.com/SimiPrambos/livekit_pip/commit/4e5c870b1788c925ec4580ddf3c91d924c871e19))
* **ios:** rewrite PipPlatformView to use PipVideoRenderer (remove FrameBridge) ([e910568](https://github.com/SimiPrambos/livekit_pip/commit/e910568e66c801f3fdf3934e639682f456e257e2))
* **setup:** add livekit_client dep, fix iOS 16 target, rename plugin classes (T001-T005) ([22a6a51](https://github.com/SimiPrambos/livekit_pip/commit/22a6a51d8460efc49246d3dfa9e22d315add22bf))
* **us2:** iOS compositor, rebindTrack, speaker switch flow ([dc83146](https://github.com/SimiPrambos/livekit_pip/commit/dc83146b184cc25719064bf22745f6258b9fc579))


### Bug Fixes

* apply dart format and add missing dartdoc to pass pana checks ([c97d03a](https://github.com/SimiPrambos/livekit_pip/commit/c97d03ae4ef84295861c5d8054320570e84537d8))
* **ios:** add required argument labels to CMVideoFormatDescriptionCreateForImageBuffer ([261f712](https://github.com/SimiPrambos/livekit_pip/commit/261f7120a0e145bfdc26c9dcb45233ee868dfeb6))
* **ios:** correct FlutterWebRTCPlugin track resolution ([0689547](https://github.com/SimiPrambos/livekit_pip/commit/0689547c0fa17772ae2c3b782ca638646922771f))
* **ios:** correct RTCYUVBuffer lock flags, conversion pass-through, malloc/free ([823284d](https://github.com/SimiPrambos/livekit_pip/commit/823284dbc709c5e06bcb91060800e0ceadb20038))
* **ios:** declare flutter_webrtc dependency in podspec, fix Podfile ([bb9652a](https://github.com/SimiPrambos/livekit_pip/commit/bb9652acbfe7df61886184a769a8ce6192236817))
* **ios:** fix PiP not starting on first minimize; dynamic aspect ratio ([5838945](https://github.com/SimiPrambos/livekit_pip/commit/5838945cff056bd2aaea37fbe4dfa2a38a86d0df))
* **ios:** honor autoEnterOnBackground flag; set frame timestamp on CMSampleBuffer ([a6f293d](https://github.com/SimiPrambos/livekit_pip/commit/a6f293d3f8716b6dae3e9876512ec1f861540f81))
* **ios:** reliable PiP auto-enter on first minimize ([70bc1d0](https://github.com/SimiPrambos/livekit_pip/commit/70bc1d07a330fe292ccb7061f5686883549bde85))
* **ios:** remove undefined _DominantRenderer reference in FrameBridge ([c00df4e](https://github.com/SimiPrambos/livekit_pip/commit/c00df4ea4ae0bb089a838bec06b1b37d3b9357ff))
* **ios:** replace non-existent UIView.layoutMarginsDidChangeNotification ([241bffe](https://github.com/SimiPrambos/livekit_pip/commit/241bffe3b42831fa8201a415ee5e115230952f7f))
* **ios:** wire autoEnterOnBackground in initialize; remove PlaybackDelegate ([4bf2a1d](https://github.com/SimiPrambos/livekit_pip/commit/4bf2a1d7e41e29d01f124b02ddf5422d50f75ada))
* pin connectivity_plus to 7.0.0 and add missing LICENSE file ([b88c3d8](https://github.com/SimiPrambos/livekit_pip/commit/b88c3d84bc423bc4e60f8c4416addcb8a55266dc))
* resolve pub.dev publish validation errors ([19a2352](https://github.com/SimiPrambos/livekit_pip/commit/19a2352a7f9bc14f2a88496463573450bce1fb66))

## 0.1.0+1

- Initial release.
- iOS implementation using `AVPictureInPictureController` with `sampleBufferDisplayLayer` content source.
- `FrameBridge` converts `RTCVideoFrame` → `CVPixelBuffer` → `CMSampleBuffer` for enqueue into the display layer.
- Active-speaker switching via Dart-driven track rebind without recreating the display layer.
- `PixelBufferCompositor` for optional local-participant self-view inset.
