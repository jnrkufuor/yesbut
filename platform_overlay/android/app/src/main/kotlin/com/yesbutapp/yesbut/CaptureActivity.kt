package com.yesbutapp.yesbut

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.widget.Toast

/**
 * Invisible screen that asks Android for permission to capture what's on
 * screen (Android asks every time), takes one picture via [CaptureService],
 * then opens Yes,But with it. Stays transparent so the app you were looking
 * at is what gets captured.
 */
class CaptureActivity : Activity() {
    private var asked = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        asked = savedInstanceState?.getBoolean("asked") ?: false
        if (!asked) {
            asked = true
            val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            try {
                @Suppress("DEPRECATION")
                startActivityForResult(mpm.createScreenCaptureIntent(), REQ)
            } catch (_: Exception) {
                fail()
            }
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putBoolean("asked", asked)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ) return
        if (resultCode != RESULT_OK || data == null) {
            finishQuiet()
            return
        }
        CaptureService.listener = { path -> runOnUiThread { done(path) } }
        val svc = Intent(this, CaptureService::class.java)
            .putExtra(CaptureService.EXTRA_CODE, resultCode)
            .putExtra(CaptureService.EXTRA_DATA, data)
        try {
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(svc) else startService(svc)
        } catch (_: Exception) {
            fail()
        }
    }

    private fun done(path: String?) {
        CaptureService.listener = null
        if (path == null) {
            fail()
            return
        }
        startActivity(
            Intent(this, MainActivity::class.java)
                .setAction(MainActivity.ACTION_INCOMING)
                .putExtra(MainActivity.EXTRA_SCREEN, path)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        )
        finishQuiet()
    }

    private fun fail() {
        Toast.makeText(this, getString(R.string.capture_failed), Toast.LENGTH_SHORT).show()
        finishQuiet()
    }

    private fun finishQuiet() {
        finish()
        overridePendingTransition(0, 0)
    }

    companion object {
        private const val REQ = 41
    }
}
