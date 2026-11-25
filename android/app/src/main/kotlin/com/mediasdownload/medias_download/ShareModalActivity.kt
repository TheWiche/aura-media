package com.mediasdownload.medias_download

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs
import io.flutter.embedding.engine.FlutterEngine

class ShareModalActivity : FlutterActivity() {
    private var nativeBridge: NativeBridge? = null
    private var currentSharedText: String? = null

    override fun getCachedEngineGroupId(): String = AuraApplication.ENGINE_GROUP_ID

    override fun getDartEntrypointFunctionName(): String = "shareModalMain"

    override fun getBackgroundMode(): FlutterActivityLaunchConfigs.BackgroundMode {
        return FlutterActivityLaunchConfigs.BackgroundMode.transparent
    }

    override fun shouldHandleDeeplinking(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        currentSharedText = extractSharedText(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val text = extractSharedText(intent)
        if (!text.isNullOrBlank()) {
            currentSharedText = text
            nativeBridge?.notifyNewShareIntent(text)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativeBridge = NativeBridge(
            context = applicationContext,
            activity = this,
            sharePayloadProvider = { currentSharedText },
            onCloseShareModal = { closeSafely() }
        ).also {
            it.attachToEngine(flutterEngine)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        nativeBridge?.detach()
        nativeBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun closeSafely() {
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                finishAndRemoveTask()
            } else {
                finish()
            }
            overridePendingTransition(0, android.R.anim.fade_out)
        }
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent == null) return null
        val extraText = intent.getStringExtra(Intent.EXTRA_TEXT)
        val extraSubject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        val dataStr = intent.dataString

        val combined = listOfNotNull(extraText, extraSubject, dataStr)
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .joinToString(" ")
        return combined.ifEmpty { null }
    }
}
