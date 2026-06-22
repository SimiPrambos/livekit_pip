# Changelog

## 0.1.0+1

- Initial release.
- Android PiP with `PictureInPictureParams`; auto-enter on API 31+, manual enter on API 26–30.
- iOS PiP via `AVSampleBufferDisplayLayer` with dominant-speaker video track pipeline.
- `LiveKitPip` controller with `PipState` stream.
- `LiveKitPipView` platform view widget.
- `LiveKitPipConfiguration` with per-platform `AndroidPipConfiguration` and `IosPipConfiguration`.
