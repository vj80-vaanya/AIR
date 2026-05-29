package com.aisecurity.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SecurityPlugin.register(flutterEngine, this)
        MediaCleanupPlugin.register(flutterEngine, this)
        DeviceDataPlugin.register(flutterEngine, this)
        // Keep the security engine alive in background
        ForegroundSecurityService.start(this)
    }
}
