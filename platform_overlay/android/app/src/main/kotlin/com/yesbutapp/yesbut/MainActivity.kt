package com.yesbutapp.yesbut

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hands things that arrive from outside the app to Flutter:
 *  - taps on the home-screen widget (yesbut://scan, yesbut://paste, …)
 *  - text, links, screenshots and PDFs shared to Yes,But from other apps.
 * Shared files are copied into the app's cache so Flutter can read them.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pending = parse(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yesbut/incoming").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "initial" -> {
                        result.success(pending)
                        pending = null
                    }
                    "updateWidget" -> {
                        refreshWidgets()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val data = parse(intent) ?: return
        val ch = channel
        if (ch != null) ch.invokeMethod("incoming", data) else pending = data
    }

    private fun refreshWidgets() {
        val mgr = AppWidgetManager.getInstance(this)
        val ids = mgr.getAppWidgetIds(ComponentName(this, QuickWidget::class.java))
        if (ids.isEmpty()) return
        val update = Intent(this, QuickWidget::class.java)
        update.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        update.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        sendBroadcast(update)
    }

    @Suppress("DEPRECATION")
    private fun parse(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        return when (intent.action) {
            Intent.ACTION_VIEW -> {
                val u = intent.data ?: return null
                if (u.scheme == "yesbut") mapOf("kind" to "action", "action" to (u.host ?: "")) else null
            }
            Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE -> {
                val uris = mutableListOf<Uri>()
                if (intent.action == Intent.ACTION_SEND) {
                    (intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))?.let { uris.add(it) }
                } else {
                    intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.addAll(it) }
                }
                val paths = mutableListOf<String>()
                val types = mutableListOf<String>()
                uris.forEachIndexed { i, u ->
                    try {
                        val type = contentResolver.getType(u) ?: ""
                        val ext = when {
                            type.contains("pdf") -> "pdf"
                            type.startsWith("image/png") -> "png"
                            type.startsWith("image/") -> "jpg"
                            type.contains("html") -> "html"
                            else -> "txt"
                        }
                        val out = File(cacheDir, "shared_${System.currentTimeMillis()}_$i.$ext")
                        contentResolver.openInputStream(u)?.use { input ->
                            out.outputStream().use { input.copyTo(it) }
                        }
                        paths.add(out.absolutePath)
                        types.add(type)
                    } catch (_: Exception) {
                    }
                }
                // Handled: don't replay it if the activity is recreated.
                intent.action = Intent.ACTION_MAIN
                mapOf(
                    "kind" to "share",
                    "text" to intent.getStringExtra(Intent.EXTRA_TEXT),
                    "subject" to intent.getStringExtra(Intent.EXTRA_SUBJECT),
                    "files" to paths,
                    "types" to types,
                )
            }
            else -> null
        }
    }
}
