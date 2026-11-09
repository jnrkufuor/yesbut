package com.yesbutapp.yesbut

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.view.WindowManager
import java.io.File

/**
 * Takes a single picture of the screen and stops. Android requires screen
 * capture to run in a foreground service; it's on for about a second.
 * The picture is saved in the app's private cache and read on the phone.
 */
class CaptureService : Service() {
    private val main = Handler(Looper.getMainLooper())
    private var projection: MediaProjection? = null
    private var display: VirtualDisplay? = null
    private var reader: ImageReader? = null
    private var finished = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        goForeground()
        val code = intent?.getIntExtra(EXTRA_CODE, 0) ?: 0
        @Suppress("DEPRECATION")
        val data: Intent? = intent?.getParcelableExtra(EXTRA_DATA)
        if (data == null) {
            finish(null)
            return START_NOT_STICKY
        }
        try {
            val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val p = mpm.getMediaProjection(code, data)
            if (p == null) {
                finish(null)
                return START_NOT_STICKY
            }
            projection = p
            p.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() {
                    if (!finished) finish(null)
                }
            }, main)
            // Give the permission dialog a moment to fade so it isn't in the picture.
            main.postDelayed({ capture() }, 450)
            // Never hang around: give up after a few seconds.
            main.postDelayed({ if (!finished) finish(null) }, 6000)
        } catch (_: Exception) {
            finish(null)
        }
        return START_NOT_STICKY
    }

    @Suppress("DEPRECATION")
    private fun capture() {
        val p = projection ?: return finish(null)
        try {
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val m = DisplayMetrics()
            wm.defaultDisplay.getRealMetrics(m)
            val w = m.widthPixels
            val h = m.heightPixels
            val r = ImageReader.newInstance(w, h, PixelFormat.RGBA_8888, 2)
            reader = r
            r.setOnImageAvailableListener({ ir ->
                if (finished) return@setOnImageAvailableListener
                val img = try { ir.acquireLatestImage() } catch (_: Exception) { null } ?: return@setOnImageAvailableListener
                try {
                    val plane = img.planes[0]
                    val pixelStride = plane.pixelStride
                    val rowPadding = plane.rowStride - pixelStride * w
                    val full = Bitmap.createBitmap(w + rowPadding / pixelStride, h, Bitmap.Config.ARGB_8888)
                    full.copyPixelsFromBuffer(plane.buffer)
                    val bmp = if (rowPadding == 0) full else Bitmap.createBitmap(full, 0, 0, w, h)
                    val out = File(cacheDir, "screen_${System.currentTimeMillis()}.png")
                    out.outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
                    finish(out.absolutePath)
                } catch (_: Exception) {
                    finish(null)
                } finally {
                    img.close()
                }
            }, main)
            display = p.createVirtualDisplay(
                "yesbut-screen", w, h, m.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                r.surface, null, main
            )
        } catch (_: Exception) {
            finish(null)
        }
    }

    private fun finish(path: String?) {
        if (finished) return
        finished = true
        try { display?.release() } catch (_: Exception) {}
        try { reader?.close() } catch (_: Exception) {}
        try { projection?.stop() } catch (_: Exception) {}
        val cb = listener
        if (cb != null) {
            cb(path)
        } else if (path != null) {
            // The invisible screen is gone; open the app directly.
            try {
                startActivity(
                    Intent(this, MainActivity::class.java)
                        .setAction(MainActivity.ACTION_INCOMING)
                        .putExtra(MainActivity.EXTRA_SCREEN, path)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            } catch (_: Exception) {}
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    @Suppress("DEPRECATION")
    private fun goForeground() {
        val b: Notification.Builder = if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL) == null) {
                nm.createNotificationChannel(NotificationChannel(CHANNEL, getString(R.string.capture_channel), NotificationManager.IMPORTANCE_LOW))
            }
            Notification.Builder(this, CHANNEL)
        } else {
            Notification.Builder(this)
        }
        val n: Notification = b.setSmallIcon(R.drawable.ic_tile)
            .setContentTitle(getString(R.string.capture_note))
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTE_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(NOTE_ID, n)
        }
    }

    companion object {
        const val EXTRA_CODE = "code"
        const val EXTRA_DATA = "data"
        private const val CHANNEL = "screen_check"
        private const val NOTE_ID = 4107
        @Volatile var listener: ((String?) -> Unit)? = null
    }
}
