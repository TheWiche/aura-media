package com.mediasdownload.medias_download

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors

class NativeBridge(
    private val context: Context,
    private var activity: Activity? = null,
    private val sharePayloadProvider: (() -> String?)? = null,
    private val onCloseShareModal: (() -> Unit)? = null,
    private val mainOpenUrlProvider: (() -> String?)? = null,
) {
    companion object {
        const val AUDIO_CHANNEL = "com.mediasdownload/audio_extractor"
        const val NATIVE_CHANNEL = "com.mediasdownload/native"
        const val REQUEST_PICK_DIRECTORY = 41091
        const val EXTRA_OPEN_URL = "com.mediasdownload.EXTRA_OPEN_URL"

        private val audioExecutor = Executors.newSingleThreadExecutor()
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var audioChannel: MethodChannel? = null
    private var nativeChannel: MethodChannel? = null
    private var pendingDirectoryResult: MethodChannel.Result? = null

    fun attachToEngine(flutterEngine: FlutterEngine) {
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        audioChannel = MethodChannel(messenger, AUDIO_CHANNEL).apply {
            setMethodCallHandler { call, result -> handleAudioCall(call, result) }
        }

        nativeChannel = MethodChannel(messenger, NATIVE_CHANNEL).apply {
            setMethodCallHandler { call, result -> handleNativeCall(call, result) }
        }
    }

    fun detach() {
        audioChannel?.setMethodCallHandler(null)
        nativeChannel?.setMethodCallHandler(null)
        audioChannel = null
        nativeChannel = null
        activity = null
        pendingDirectoryResult = null
    }

    fun notifyNewShareIntent(sharedText: String) {
        mainHandler.post {
            nativeChannel?.invokeMethod("onNewShareIntent", sharedText)
        }
    }

    fun notifyOpenMainUrl(url: String) {
        mainHandler.post {
            nativeChannel?.invokeMethod("onOpenMainUrl", url)
        }
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK_DIRECTORY) return false
        val pending = pendingDirectoryResult
        pendingDirectoryResult = null

        if (pending == null) return true

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pending.success(null)
            return true
        }

        val treeUri = data.data!!
        try {
            val takeFlags =
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            context.contentResolver.takePersistableUriPermission(treeUri, takeFlags)
        } catch (_: Exception) {
        }

        val resolvedPath = resolveTreeUriToPath(treeUri)
        pending.success(resolvedPath)
        return true
    }

    private fun handleAudioCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "extractAudio") {
            val inputPath = call.argument<String>("inputPath")
            val outputPath = call.argument<String>("outputPath")
            if (inputPath == null || outputPath == null) {
                result.error("INVALID_ARGS", "inputPath and outputPath are required", null)
                return
            }

            audioExecutor.execute {
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

    private fun handleNativeCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickDirectory" -> {
                val host = activity
                if (host == null) {
                    result.error("NO_ACTIVITY", "Directory picker requires an active Activity", null)
                    return
                }
                if (pendingDirectoryResult != null) {
                    pendingDirectoryResult?.success(null)
                    pendingDirectoryResult = null
                }
                pendingDirectoryResult = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                    addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
                    )
                }
                try {
                    host.startActivityForResult(intent, REQUEST_PICK_DIRECTORY)
                } catch (e: Exception) {
                    pendingDirectoryResult = null
                    result.error("PICKER_ERROR", e.message, null)
                }
            }

            "scanMediaFile" -> {
                val path = call.argument<String>("path")
                val mimeType = call.argument<String>("mimeType")
                if (path.isNullOrBlank()) {
                    result.success(false)
                    return
                }
                try {
                    val mimeArray = if (mimeType != null) arrayOf(mimeType) else null
                    MediaScannerConnection.scanFile(
                        context.applicationContext,
                        arrayOf(path),
                        mimeArray,
                        null
                    )
                    result.success(true)
                } catch (_: Exception) {
                    result.success(false)
                }
            }

            "isWifiConnected" -> {
                result.success(checkWifiConnected())
            }

            "getAppVersion" -> {
                result.success(readAppVersion())
            }

            "openFolder" -> {
                val path = call.argument<String>("path")
                result.success(if (path != null) launchFolderViewer(path) else false)
            }

            "getSharePayload" -> {
                result.success(sharePayloadProvider?.invoke())
            }

            "closeShareModal" -> {
                onCloseShareModal?.invoke()
                result.success(null)
            }

            "openMainApp" -> {
                val url = call.argument<String>("url")
                val mainIntent = Intent(context, MainActivity::class.java).apply {
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                    )
                    if (!url.isNullOrBlank()) {
                        putExtra(EXTRA_OPEN_URL, url)
                    }
                }
                context.startActivity(mainIntent)
                onCloseShareModal?.invoke()
                result.success(null)
            }

            "getMainOpenUrl" -> {
                result.success(mainOpenUrlProvider?.invoke())
            }

            else -> result.notImplemented()
        }
    }

    private fun checkWifiConnected(): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = cm.activeNetwork ?: return false
            val caps = cm.getNetworkCapabilities(network) ?: return false
            return caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
        } else {
            @Suppress("DEPRECATION")
            val info = cm.activeNetworkInfo ?: return false
            @Suppress("DEPRECATION")
            return info.isConnected && (
                info.type == ConnectivityManager.TYPE_WIFI ||
                    info.type == ConnectivityManager.TYPE_ETHERNET
                )
        }
    }

    private fun readAppVersion(): String {
        return try {
            val pm = context.packageManager
            val pkgInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getPackageInfo(
                    context.packageName,
                    android.content.pm.PackageManager.PackageInfoFlags.of(0)
                )
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(context.packageName, 0)
            }
            val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                pkgInfo.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                pkgInfo.versionCode.toLong()
            }
            "${pkgInfo.versionName ?: "1.3.0"}+$code"
        } catch (_: Exception) {
            "1.3.0+10"
        }
    }

    private fun resolveTreeUriToPath(treeUri: Uri): String? {
        return try {
            val docId = DocumentsContract.getTreeDocumentId(treeUri) ?: return null
            val parts = docId.split(":", limit = 2)
            val volume = parts.getOrNull(0) ?: return null
            val relative = parts.getOrNull(1)?.trimStart('/') ?: ""

            if (volume.equals("primary", ignoreCase = true)) {
                val base = Environment.getExternalStorageDirectory().absolutePath
                if (relative.isEmpty()) base else "$base/$relative"
            } else if (volume.equals("home", ignoreCase = true)) {
                val docs = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOCUMENTS
                ).absolutePath
                if (relative.isEmpty()) docs else "$docs/$relative"
            } else {
                val sdRoot = "/storage/$volume"
                if (File(sdRoot).exists()) {
                    if (relative.isEmpty()) sdRoot else "$sdRoot/$relative"
                } else {
                    null
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun launchFolderViewer(path: String): Boolean {
        return try {
            val dir = File(path)
            if (!dir.exists()) {
                dir.mkdirs()
            }
            val primaryRoot = Environment.getExternalStorageDirectory().absolutePath
            if (path.startsWith(primaryRoot)) {
                val relative = path.removePrefix(primaryRoot).trimStart('/')
                val docId = if (relative.isEmpty()) "primary:" else "primary:$relative"
                val uri = DocumentsContract.buildDocumentUri(
                    "com.android.externalstorage.documents",
                    docId
                )
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, DocumentsContract.Document.MIME_TYPE_DIR)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                context.startActivity(intent)
                return true
            }
            false
        } catch (_: Exception) {
            false
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
        outputFile.parentFile?.let { parent ->
            if (!parent.exists()) parent.mkdirs()
        }
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
        } catch (_: Exception) {
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
            } catch (_: Exception) {
            }
            try {
                muxer.release()
            } catch (_: Exception) {
            }
            extractor.release()
        }

        return true
    }
}
