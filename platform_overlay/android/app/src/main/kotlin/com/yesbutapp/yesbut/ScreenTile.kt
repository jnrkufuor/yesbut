package com.yesbutapp.yesbut

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * Quick settings button. First tap: start reading as you scroll.
 * Second tap: stop and open the result.
 */
class ScreenTile : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        val t = qsTile ?: return
        val on = CaptureService.running
        t.state = if (on) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        t.label = getString(if (on) R.string.tile_done else R.string.tile_label)
        if (Build.VERSION.SDK_INT >= 29) {
            t.subtitle = if (on) getString(R.string.capture_count, CaptureService.count()) else null
        }
        t.updateTile()
    }

    override fun onClick() {
        super.onClick()
        if (CaptureService.running) {
            val paths = CaptureService.collect(this)
            open(
                Intent(this, MainActivity::class.java)
                    .setAction(MainActivity.ACTION_INCOMING)
                    .putExtra(MainActivity.EXTRA_SCREENS, paths.toTypedArray())
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            )
            return
        }
        val start = Intent(this, CaptureActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (isLocked) unlockAndRun { open(start) } else open(start)
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    @Suppress("DEPRECATION")
    private fun open(i: Intent) {
        if (Build.VERSION.SDK_INT >= 34) {
            val pi = PendingIntent.getActivity(this, i.hashCode(), i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            startActivityAndCollapse(pi)
        } else {
            startActivityAndCollapse(i)
        }
    }
}
