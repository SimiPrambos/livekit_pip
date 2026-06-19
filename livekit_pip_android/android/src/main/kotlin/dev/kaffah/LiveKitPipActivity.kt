package dev.kaffah

import io.flutter.embedding.android.FlutterActivity

/**
 * Optional convenience base Activity that drives the legacy (API 26–30) PiP
 * enter path. Apps with an existing base class can instead override
 * [onUserLeaveHint] themselves and forward to the plugin the same way.
 */
open class LiveKitPipActivity : FlutterActivity() {
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        val plugin = flutterEngine?.plugins?.get(PipPlugin::class.java) as? PipPlugin
        plugin?.onUserLeaveHint()
    }
}
