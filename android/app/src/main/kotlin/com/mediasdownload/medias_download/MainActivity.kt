package com.mediasdownload.medias_download

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var nativeBridge: NativeBridge? = null
    private var pendingOpenUrl: String? = null

    override fun getCachedEngineGroupId(): String = AuraApplication.ENGINE_GROUP_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        extractOpenUrl(intent)?.let { pendingOpenUrl = it }
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractOpenUrl(intent)?.let { url ->
            pendingOpenUrl = url
            nativeBridge?.notifyOpenMainUrl(url)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativeBridge = NativeBridge(
            context = applicationContext,
            activity = this,
            mainOpenUrlProvider = {
                val url = pendingOpenUrl
                pendingOpenUrl = null
                url
            }
        ).also {
            it.attachToEngine(flutterEngine)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        nativeBridge?.detach()
        nativeBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (nativeBridge?.handleActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun extractOpenUrl(intent: Intent?): String? {
        if (intent == null) return null
        val url = intent.getStringExtra(NativeBridge.EXTRA_OPEN_URL)
        return if (!url.isNullOrBlank()) url else null
    }
}
