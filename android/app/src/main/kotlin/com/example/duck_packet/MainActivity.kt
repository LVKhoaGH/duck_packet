package com.example.duck_packet

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "duckpacket/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "update") {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        DuckData.save(this, args)
                        DuckData.refreshAll(this)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
