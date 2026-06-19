package dev.kaffah

import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel

/** Registers channels and owns the Activity reference. */
class PipPlugin : FlutterPlugin, ActivityAware, LiveKitPipHostApi {

    private var activityBinding: ActivityPluginBinding? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pipHelper: PipHelper? = null
    private var initRequest: PipInitRequest? = null

    // ──── FlutterPlugin ────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        LiveKitPipHostApi.setUp(binding.binaryMessenger, this)
        // EventChannel: Pigeon does not model push streams
        EventChannel(binding.binaryMessenger, "livekit_pip/state")
            .setStreamHandler(stateStreamHandler)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        LiveKitPipHostApi.setUp(binding.binaryMessenger, null)
    }

    // ──── ActivityAware ────────────────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        pipHelper = PipHelper(binding.activity, ::emitState)
        pipHelper?.attach(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        pipHelper?.detach()
        pipHelper = null
        activityBinding = null
    }

    // ──── LiveKitPipHostApi ────────────────────────────────────────────────

    override fun isSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O

    override fun initialize(request: PipInitRequest) {
        initRequest = request
        pipHelper?.configure(request)
    }

    override fun enterPip() {
        pipHelper?.enter()
    }

    override fun exitPip() {
        activityBinding?.activity?.moveTaskToBack(false)
    }

    /** Forwarded from LiveKitPipActivity.onUserLeaveHint. */
    fun onUserLeaveHint() {
        pipHelper?.onUserLeaveHint()
    }

    override fun dispose() {
        pipHelper?.detach()
        pipHelper = null
        initRequest = null
        eventSink = null
    }

    override fun updateActiveTrack(trackId: String) {
        // Android: widget builder handles track selection in Dart
    }

    override fun updateAspectRatio(width: Long, height: Long) {
        pipHelper?.updateAspectRatio(width.toInt(), height.toInt())
    }

    // ──── State stream ─────────────────────────────────────────────────────

    internal fun emitState(stateOrdinal: Int) {
        eventSink?.success(stateOrdinal.toLong())
    }

    private val stateStreamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
        }
        override fun onCancel(arguments: Any?) {
            eventSink = null
        }
    }
}
