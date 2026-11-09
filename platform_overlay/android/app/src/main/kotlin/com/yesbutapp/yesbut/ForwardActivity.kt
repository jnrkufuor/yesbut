package com.yesbutapp.yesbut

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * "Yes, but" in the text-selection menu of any app (next to Copy, Share).
 * Takes the highlighted text and hands it to the main app in its own task,
 * then gets out of the way.
 */
class ForwardActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val text = intent?.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
        if (!text.isNullOrBlank()) {
            startActivity(
                Intent(this, MainActivity::class.java)
                    .setAction(MainActivity.ACTION_INCOMING)
                    .putExtra(Intent.EXTRA_TEXT, text)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            )
        }
        finish()
        overridePendingTransition(0, 0)
    }
}
