import 'dart:async';

import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_pip/src/pip_configuration.dart';
import 'package:livekit_pip/src/pip_state.dart';
import 'package:livekit_pip_platform_interface/livekit_pip_platform_interface.dart';

/// Primary controller for native Picture-in-Picture.
///
/// Create one instance per call session. Call [dispose] when the call ends.
class LiveKitPip {
  final StreamController<PipState> _stateController =
      StreamController<PipState>.broadcast();

  StreamSubscription<int>? _stateSubscription;

  bool _initialized = false;
  bool _disposed = false;

  // Stored for use in T022/T024 (ActiveSpeakerSelector wiring, dispose).
  // ignore: unused_field
  Room? _room;

  // Stored for use in T022/T024 (config forwarding, dispose).
  // ignore: unused_field
  LiveKitPipConfiguration? _config;

  /// Continuous stream of PiP lifecycle state changes.
  ///
  /// Emits [PipState.unsupported] if the device does not support PiP.
  /// Closed (done event) when [dispose] is called.
  Stream<PipState> get stateStream => _stateController.stream;

  /// Returns true if PiP is supported on the current device.
  ///
  /// Safe to call at any time; never throws.
  Future<bool> isSupported() => LivekitPipPlatform.instance.isSupported();

  /// Attaches the plugin to [room] with [config].
  ///
  /// Throws [StateError] if called after [dispose].
  Future<void> initialize({
    required Room room,
    required LiveKitPipConfiguration config,
  }) async {
    _assertNotDisposed('initialize');
    _room = room;
    _config = config;
    await LivekitPipPlatform.instance.initialize(
      enabled: config.enabled,
      disableWhenScreenSharing: config.disableWhenScreenSharing,
      androidAutoEnterOnBackground: config.android.autoEnterOnBackground,
      iosAutoEnterOnBackground: config.ios.autoEnterOnBackground,
      iosIncludeLocalParticipantVideo:
          config.ios.includeLocalParticipantVideo,
      videoWidth: 0,
      videoHeight: 0,
    );
    _stateSubscription = LivekitPipPlatform.instance.stateStream.listen(
      (raw) => _stateController.add(PipState.values[raw]),
    );
    _initialized = true;
  }

  /// Requests the OS to enter PiP mode.
  ///
  /// Throws [StateError] if not initialized or already disposed.
  /// Throws [UnsupportedError] if [isSupported] returns false.
  Future<void> enterPiP() {
    _assertInitialized('enterPiP');
    return LivekitPipPlatform.instance.enterPip();
  }

  /// Requests the OS to exit PiP mode and restore full-screen.
  ///
  /// Throws [StateError] if not initialized or already disposed.
  Future<void> exitPiP() {
    _assertInitialized('exitPiP');
    return LivekitPipPlatform.instance.exitPip();
  }

  /// Releases all native resources and closes [stateStream].
  ///
  /// Idempotent — safe to call multiple times.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    await LivekitPipPlatform.instance.dispose();
    await _stateController.close();
    _room = null;
    _config = null;
    _initialized = false;
  }

  void _assertNotDisposed(String method) {
    if (_disposed) {
      throw StateError('LiveKitPip.$method called after dispose()');
    }
  }

  void _assertInitialized(String method) {
    _assertNotDisposed(method);
    if (!_initialized) {
      throw StateError('LiveKitPip.$method called before initialize()');
    }
  }
}
