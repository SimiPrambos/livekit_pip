# Changelog

## 0.1.0+1

- Initial release.
- iOS implementation using `AVPictureInPictureController` with `sampleBufferDisplayLayer` content source.
- `FrameBridge` converts `RTCVideoFrame` → `CVPixelBuffer` → `CMSampleBuffer` for enqueue into the display layer.
- Active-speaker switching via Dart-driven track rebind without recreating the display layer.
- `PixelBufferCompositor` for optional local-participant self-view inset.
