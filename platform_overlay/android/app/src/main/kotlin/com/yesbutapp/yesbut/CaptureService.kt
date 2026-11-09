package com.yesbutapp.yesbut

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.service.quicksettings.TileService
import android.util.DisplayMetrics
import android.view.WindowManager
import java.io.File
import kotlin.math.abs

/**
 * "Keep reading while I scroll": after one permission, saves a picture each
 * time the screen settles on something new, until you tap the tile again or
 * Done. Pictures stay in the app's private cache, are read on the phone and
 * deleted afterwards. Android requires this to run as a foreground service.
 */
class CaptureService : Service() {
    private var worker: HandlerThread? = null
    private var bg: Handler? = null
    private var projection: MediaProjection? = null
    private var display: VirtualDisplay? = null
    private var reader: ImageReader? = null
    private var held: Image? = null
    private var lastSig: IntArray? = null
    private var width = 0
    private var height = 0
    private val settle = Runnable { saveIfNew() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopCapture(auto = false)
            return START_NOT_STICKY
        }
        synchronized(lock) {
            frames.clear()
            savedAt.clear()
            running = true
            startedAt = System.currentTimeMillis()
        }
        cleanOld()
        goForeground()
        refreshTile()
        val code = intent?.getIntExtra(EXTRA_CODE, 0) ?: 0
        @Suppress("DEPRECATION")
        val data: Intent? = intent?.getParcelableExtra(EXTRA_DATA)
        if (data == null) {
            stopCapture(auto = true)
            return START_NOT_STICKY
        }
        val t = HandlerThread("yesbut-capture").also { it.start() }
        worker = t
        val h = Handler(t.looper)
        bg = h
        try {
            val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val p = mpm.getMediaProjection(code, data) ?: run { stopCapture(auto = true); return START_NOT_STICKY }
            projection = p
            p.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() {
                    if (running) stopCapture(auto = true)
                }
            }, h)
            // Let the permission dialog fade so it isn't in the first picture.
            h.postDelayed({ startDisplay() }, 500)
            h.postDelayed({ if (running) stopCapture(auto = true) }, MAX_MS)
        } catch (_: Exception) {
            stopCapture(auto = true)
        }
        return START_NOT_STICKY
    }

    @Suppress("DEPRECATION")
    private fun startDisplay() {
        val p = projection ?: return
        val h = bg ?: return
        try {
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val m = DisplayMetrics()
            wm.defaultDisplay.getRealMetrics(m)
            width = m.widthPixels
            height = m.heightPixels
            val r = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 3)
            reader = r
            r.setOnImageAvailableListener({ ir ->
                val img = try { ir.acquireLatestImage() } catch (_: Exception) { null } ?: return@setOnImageAvailableListener
                held?.close()
                held = img
                // Wait for the screen to stop moving before keeping a picture.
                h.removeCallbacks(settle)
                h.postDelayed(settle, SETTLE_MS)
            }, h)
            display = p.createVirtualDisplay(
                "yesbut-screen", width, height, m.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, r.surface, null, h
            )
        } catch (_: Exception) {
            stopCapture(auto = true)
        }
    }

    private fun saveIfNew() {
        val img = held ?: return
        held = null
        if (!running) { img.close(); return }
        try {
            val plane = img.planes[0]
            val pixelStride = plane.pixelStride
            val rowPadding = plane.rowStride - pixelStride * width
            val full = Bitmap.createBitmap(width + rowPadding / pixelStride, height, Bitmap.Config.ARGB_8888)
            full.copyPixelsFromBuffer(plane.buffer)
            img.close()
            val bmp = if (rowPadding == 0) full else Bitmap.createBitmap(full, 0, 0, width, height)
            val sig = signature(bmp)
            val prev = lastSig
            if (prev != null && difference(prev, sig) < SAME) return
            lastSig = sig
            val out = File(cacheDir, "screen_${System.currentTimeMillis()}.jpg")
            out.outputStream().use { bmp.compress(Bitmap.CompressFormat.JPEG, 90, it) }
            val count = synchronized(lock) {
                frames.add(out.absolutePath)
                savedAt.add(System.currentTimeMillis())
                frames.size
            }
            updateNote(count)
            if (count >= MAX_FRAMES) stopCapture(auto = true)
        } catch (_: Exception) {
            try { img.close() } catch (_: Exception) {}
        }
    }

    /** A tiny greyscale thumbnail, to tell whether the screen really changed. */
    private fun signature(b: Bitmap): IntArray {
        val s = Bitmap.createScaledBitmap(b, 24, 48, true)
        val px = IntArray(24 * 48)
        s.getPixels(px, 0, 24, 0, 0, 24, 48)
        return IntArray(px.size) { i ->
            val c = px[i]
            ((c shr 16 and 255) * 3 + (c shr 8 and 255) * 6 + (c and 255)) / 10
        }
    }

    private fun difference(a: IntArray, b: IntArray): Int {
        var sum = 0
        for (i in a.indices) sum += abs(a[i] - b[i])
        return sum / a.size
    }

    private fun stopCapture(auto: Boolean) {
        val wasRunning = running
        running = false
        bg?.removeCallbacksAndMessages(null)
        try { display?.release() } catch (_: Exception) {}
        try { held?.close() } catch (_: Exception) {}
        held = null
        try { reader?.close() } catch (_: Exception) {}
        try { projection?.stop() } catch (_: Exception) {}
        display = null; reader = null; projection = null
        worker?.quitSafely()
        refreshTile()
        val count = synchronized(lock) { frames.size }
        if (auto && wasRunning && count > 0) {
            // Stopped by itself (limit reached): leave a tap-to-read notification.
            stopForeground(STOP_FOREGROUND_DETACH)
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTE_ID, builder()
                .setContentTitle(getString(R.string.capture_ready, count))
                .setContentText(getString(R.string.capture_ready_body))
                .setContentIntent(finishIntent())
                .setAutoCancel(true)
                .setOngoing(false)
                .build())
        } else {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
        stopSelf()
    }

    private fun cleanOld() {
        try {
            cacheDir.listFiles()?.filter { it.name.startsWith("screen_") }?.forEach { it.delete() }
        } catch (_: Exception) {}
    }

    private fun refreshTile() {
        try { TileService.requestListeningState(this, ComponentName(this, ScreenTile::class.java)) } catch (_: Exception) {}
    }

    private fun finishIntent(): PendingIntent = PendingIntent.getActivity(
        this, 9,
        Intent(this, MainActivity::class.java).setAction(MainActivity.ACTION_FINISH_SCREENS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    )

    @Suppress("DEPRECATION")
    private fun builder(): Notification.Builder {
        val b = if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL) == null) {
                nm.createNotificationChannel(NotificationChannel(CHANNEL, getString(R.string.capture_channel), NotificationManager.IMPORTANCE_LOW))
            }
            Notification.Builder(this, CHANNEL)
        } else Notification.Builder(this)
        return b.setSmallIcon(R.drawable.ic_tile).setOnlyAlertOnce(true)
    }

    private fun runningNote(count: Int): Notification = builder()
        .setContentTitle(if (count == 0) getString(R.string.capture_note) else getString(R.string.capture_count, count))
        .setContentText(getString(R.string.capture_hint))
        .setOngoing(true)
        .setContentIntent(finishIntent())
        .addAction(Notification.Action.Builder(null as android.graphics.drawable.Icon?, getString(R.string.capture_done), finishIntent()).build())
        .build()

    private fun updateNote(count: Int) {
        if (!running) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTE_ID, runningNote(count))
    }

    private fun goForeground() {
        val n = runningNote(0)
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTE_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(NOTE_ID, n)
        }
    }

    companion object {
        const val EXTRA_CODE = "code"
        const val EXTRA_DATA = "data"
        const val ACTION_STOP = "com.yesbutapp.yesbut.STOP_SCREENS"
        private const val CHANNEL = "screen_check"
        private const val NOTE_ID = 4107
        private const val SETTLE_MS = 450L
        private const val SAME = 4
        private const val MAX_FRAMES = 40
        private const val MAX_MS = 4 * 60 * 1000L
        /** Pictures taken while pulling down the shade to tap Done. */
        private const val TAIL_MS = 2000L

        private val lock = Any()
        private val frames = mutableListOf<String>()
        private val savedAt = mutableListOf<Long>()
        @Volatile private var instance: CaptureService? = null
        @Volatile var running = false
            private set
        private var startedAt = 0L

        /**
         * Ends the session (if it's still going) and hands back the pictures,
         * minus any taken in the last couple of seconds, which usually show
         * the notification shade rather than the terms.
         */
        fun collect(ctx: Context): List<String> {
            if (running) {
                val s = instance
                running = false
                if (s != null) {
                    val h = s.bg
                    if (h != null) h.post { s.stopCapture(auto = false) } else s.stopCapture(auto = false)
                } else {
                    running = false
                }
            }
            val now = System.currentTimeMillis()
            val out = synchronized(lock) {
                val keep = frames.filterIndexed { i, _ -> now - savedAt[i] > TAIL_MS }
                val list = if (keep.isEmpty()) frames.take(1) else keep
                frames.clear(); savedAt.clear()
                list
            }
            try {
                (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTE_ID)
            } catch (_: Exception) {}
            return out
        }

        fun count(): Int = synchronized(lock) { frames.size }
    }
}
