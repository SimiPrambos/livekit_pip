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
        binding.activity.application.registerActivityLifecycleCallbacks(
            object : android.app.Application.ActivityLifecycleCallbacks {
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
                override fun onActivityPaused(a: Activity) {
                    if (a !== activity) return
                    // API 26–30: enter on home button (user leave hint fires in onPause on some OEMs)
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S && autoEnter) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            @Suppress("DEPRECATION")
                            activity.enterPictureInPictureMode(buildParams().build())
                        }
                    }
                }
                override fun onActivityStopped(a: Activity) {}
                override fun onActivitySaveInstanceState(a: Activity, b: android.os.Bundle) {}
                override fun onActivityDestroyed(a: Activity) {}
            }
        )
    }

    fun detach() {
        // Lifecycle callbacks are registered on Application; cleaned up when Activity is destroyed.
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
