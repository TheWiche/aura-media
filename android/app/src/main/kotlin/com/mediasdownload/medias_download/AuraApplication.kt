package com.mediasdownload.medias_download

import com.pravera.flutter_foreground_task.FlutterForegroundTaskLifecycleListener
import com.pravera.flutter_foreground_task.FlutterForegroundTaskPlugin
import com.pravera.flutter_foreground_task.FlutterForegroundTaskStarter
import io.flutter.app.FlutterApplication
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.FlutterEngineGroupCache

class AuraApplication : FlutterApplication() {
    companion object {
        const val ENGINE_GROUP_ID = "aura_engine_group"
    }

    private var foregroundBridge: NativeBridge? = null

    private val foregroundLifecycleListener = object : FlutterForegroundTaskLifecycleListener {
        override fun onEngineCreate(flutterEngine: FlutterEngine?) {
            if (flutterEngine != null) {
                foregroundBridge?.detach()
                foregroundBridge = NativeBridge(applicationContext).also {
                    it.attachToEngine(flutterEngine)
                }
            }
        }

        override fun onTaskStart(starter: FlutterForegroundTaskStarter) {}

        override fun onTaskRepeatEvent() {}

        override fun onTaskDestroy() {}

        override fun onEngineWillDestroy() {
            foregroundBridge?.detach()
            foregroundBridge = null
        }
    }

    override fun onCreate() {
        super.onCreate()
        val group = FlutterEngineGroup(this)
        FlutterEngineGroupCache.getInstance().put(ENGINE_GROUP_ID, group)
        FlutterForegroundTaskPlugin.addTaskLifecycleListener(foregroundLifecycleListener)
    }
}
