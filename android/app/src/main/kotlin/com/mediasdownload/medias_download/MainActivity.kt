package com.mediasdownload.medias_download

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mediasdownload/audio_extractor"
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "extractAudio") {
                val inputPath = call.argument<String>("inputPath")
                val outputPath = call.argument<String>("outputPath")
                if (inputPath == null || outputPath == null) {
                    result.error("INVALID_ARGS", "inputPath and outputPath are required", null)
                    return@setMethodCallHandler
                }

                executor.execute {
                    try {
                        val success = extractAudioTrack(inputPath, outputPath)
                        mainHandler.post {
                            if (success) {
                                result.success(true)
                            } else {
                                result.error("FAILED", "Could not extract audio track", null)
                            }
                        }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("ERROR", e.message, null)
                        }
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun extractAudioTrack(inputPath: String, outputPath: String): Boolean {
        val extractor = MediaExtractor()
        extractor.setDataSource(inputPath)

        var audioTrackIndex = -1
        var audioFormat: MediaFormat? = null

        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.startsWith("audio/")) {
                audioTrackIndex = i
                audioFormat = format
                break
            }
        }

        if (audioTrackIndex == -1 || audioFormat == null) {
            extractor.release()
            return false
        }

        extractor.selectTrack(audioTrackIndex)

        val outputFile = File(outputPath)
        if (outputFile.exists()) {
            outputFile.delete()
        }

        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val muxerAudioTrack = muxer.addTrack(audioFormat)
        muxer.start()

        val maxBufferSize = try {
            if (audioFormat.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                audioFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
            } else {
                64 * 1024
            }
        } catch (e: Exception) {
            64 * 1024
        }
        val buffer = ByteBuffer.allocate(Math.max(maxBufferSize, 64 * 1024))
        val bufferInfo = MediaCodec.BufferInfo()

        try {
            while (true) {
                val sampleSize = extractor.readSampleData(buffer, 0)
                if (sampleSize < 0) {
                    break
                }
                bufferInfo.offset = 0
                bufferInfo.size = sampleSize
                bufferInfo.presentationTimeUs = extractor.sampleTime
                bufferInfo.flags = extractor.sampleFlags
                muxer.writeSampleData(muxerAudioTrack, buffer, bufferInfo)
                extractor.advance()
            }
        } finally {
            try {
                muxer.stop()
            } catch (ignored: Exception) {}
            try {
                muxer.release()
            } catch (ignored: Exception) {}
            extractor.release()
        }

        return true
    }
}
