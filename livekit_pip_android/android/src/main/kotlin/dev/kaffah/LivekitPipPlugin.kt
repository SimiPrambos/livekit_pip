package dev.kaffah

import LivekitPipApi
import io.flutter.embedding.engine.plugins.FlutterPlugin

class LivekitPipPlugin : FlutterPlugin, LivekitPipApi {
    companion object {
        private const val TAG = "LivekitPipPlugin"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        LivekitPipApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        LivekitPipApi.setUp(binding.binaryMessenger, null)
    }

    override fun getPlatformName(callback: (Result<String?>) -> Unit) {
        callback(Result.success("Android ${android.os.Build.VERSION.RELEASE}"))
    }
}