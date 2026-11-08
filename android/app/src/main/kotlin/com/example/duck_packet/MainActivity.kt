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
                    val streak = call.argument<Int>("streak") ?: 0
                    val lastDay = call.argument<String>("lastDay") ?: ""
                    val freezes = call.argument<Int>("freezes") ?: 0
                    val days = call.argument<String>("days") ?: ""
                    DuckWidgetProvider.save(this, streak, lastDay, freezes, days)
                    DuckWidgetProvider.refreshAll(this)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
