# Changelog

## 0.1.0+1

- Initial release.
- Android implementation using `PictureInPictureParams`.
- Auto-enter PiP on API 31+; manual enter via `onUserLeaveHint` on API 26–30.
- `PipHelper` attaches to any Activity; `LiveKitPipActivity` provided as a convenience base class.
- Consumer-supplied `pipWidgetBuilder` rendered inside the PiP window via Flutter widget swap.
