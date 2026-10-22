package com.mite.cse.ember

import android.media.MediaMetadataRetriever
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mite.cse.ember/video_metadata"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getVideoDurationMs") {
                val path = call.argument<String>("path")
                if (path.isNullOrEmpty()) {
                    result.error("INVALID_PATH", "Path was null or empty", null)
                    return@setMethodCallHandler
                }
                var retriever: MediaMetadataRetriever? = null
                try {
                    retriever = MediaMetadataRetriever()
                    retriever.setDataSource(path)
                    val timeStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    val durationMs = timeStr?.toLongOrNull() ?: 0L
                    result.success(durationMs)
                } catch (e: Exception) {
                    result.error("ERROR", e.localizedMessage ?: e.message, null)
                } finally {
                    try {
                        retriever?.release()
                    } catch (_: Exception) {}
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
