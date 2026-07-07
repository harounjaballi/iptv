package com.smartech.premiumiptv

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "premium_iptv/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTv" -> {
                        val pm = packageManager
                        val isTv = pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
                                pm.hasSystemFeature("amazon.hardware.fire_tv")
                        result.success(isTv)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
