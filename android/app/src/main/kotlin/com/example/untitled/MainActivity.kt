package com.example.untitled

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
class MainActivity : FlutterActivity() {
    private val CHANNEL = "au.com.sharpblue.inkworm/epub"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getEpubFile" -> {
                        val epubUri = intent?.data?.toString()
                        val epubPath = intent?.data?.path
                        result.success(
                            mapOf(
                                "uri" to epubUri,
                                "path" to epubPath
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
