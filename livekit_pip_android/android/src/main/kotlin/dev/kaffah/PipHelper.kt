package dev.kaffah

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * Builds PictureInPictureParams and manages enter/exit for both API paths:
 * - API 31+: setAutoEnterEnabled(true) in onResume
 * - API 26–30: enter manually in onUserLeaveHint
 */
class PipHelper(
    private val activity: Activity,
    private val onStateChanged: (Int) -> Unit,
) {
    private var autoEnter = true
    private var aspectWidth = 16
    private var aspectHeight = 9
    private var lifecycleCallbacks: android.app.Application.ActivityLifecycleCallbacks? = null

    fun configure(request: PipInitRequest) {
        autoEnter = request.androidAutoEnterOnBackground
        if (request.videoWidth > 0 && request.videoHeight > 0) {
            aspectWidth = request.videoWidth.toInt()
            aspectHeight = request.videoHeight.toInt()
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && autoEnter) {
            activity.setPictureInPictureParams(buildParams().setAutoEnterEnabled(true).build())
        }
    }

    fun attach(binding: ActivityPluginBinding) {
        val callbacks = object : android.app.Application.ActivityLifecycleCallbacks {
            override fun onActivityResumed(a: Activity) {
                if (a !== activity) return
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && autoEnter) {
                    activity.setPictureInPictureParams(
                        buildParams().setAutoEnterEnabled(true).build()
                    )
                }
            }
            override fun onActivityPictureInPictureModeChanged(
                a: Activity,
                isInPip: Boolean,
                newConfig: Configuration,
            ) {
                if (a !== activity) return
                if (isInPip) {
                    onStateChanged(2) // entering
                    onStateChanged(3) // active
                } else {
                    onStateChanged(4) // exiting
                    onStateChanged(1) // inactive
                }
            }

            // Unused lifecycle overrides
            override fun onActivityCreated(a: Activity, b: android.os.Bundle?) {}
            override fun onActivityStarted(a: Activity) {}
            override fun onActivityPaused(a: Activity) {}
            override fun onActivityStopped(a: Activity) {}
            override fun onActivitySaveInstanceState(a: Activity, b: android.os.Bundle) {}
            override fun onActivityDestroyed(a: Activity) {}
        }
        lifecycleCallbacks = callbacks
        binding.activity.application.registerActivityLifecycleCallbacks(callbacks)
    }

    fun detach() {
        lifecycleCallbacks?.let { callbacks ->
            activity.application.unregisterActivityLifecycleCallbacks(callbacks)
            lifecycleCallbacks = null
        }
    }

    /** Called from the Activity's onUserLeaveHint (home button) on API 26–30. */
    fun onUserLeaveHint() {
        if (!autoEnter) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
        ) {
            enter()
        }
    }

    /** Updates the PiP window aspect ratio. Values are clamped on the Dart side. */
    fun updateAspectRatio(width: Int, height: Int) {
        if (width <= 0 || height <= 0) return
        aspectWidth = width
        aspectHeight = height
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && autoEnter) {
                activity.setPictureInPictureParams(
                    buildParams().setAutoEnterEnabled(true).build()
                )
            } else if (activity.isInPictureInPictureMode) {
                activity.setPictureInPictureParams(buildParams().build())
            }
        } catch (e: IllegalArgumentException) {
            android.util.Log.w("livekit_pip", "setPictureInPictureParams rejected ratio", e)
        }
    }

    fun enter() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            activity.enterPictureInPictureMode(buildParams().build())
        }
    }

    private fun buildParams(): PictureInPictureParams.Builder {
        val builder = PictureInPictureParams.Builder()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setAspectRatio(Rational(aspectWidth, aspectHeight))
        }
        return builder
    }
}
