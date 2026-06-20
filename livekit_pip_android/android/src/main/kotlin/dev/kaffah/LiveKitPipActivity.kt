package dev.kaffah

import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity

/**
 * Optional convenience base Activity that drives the legacy (API 26–30) PiP
 * enter path. Apps with an existing base class can instead override
 * [onUserLeaveHint] and [onPictureInPictureModeChanged] themselves and forward
 * to the plugin the same way.
 */
open class LiveKitPipActivity : FlutterActivity() {
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        plugin()?.onUserLeaveHint()
    }

    @Suppress("OVERRIDE_DEPRECATION")
    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        @Suppress("DEPRECATION")
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        plugin()?.onPictureInPictureModeChanged(isInPictureInPictureMode)
    }

    private fun plugin() = flutterEngine?.plugins?.get(PipPlugin::class.java) as? PipPlugin
}
