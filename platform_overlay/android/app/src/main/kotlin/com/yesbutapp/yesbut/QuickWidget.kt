package com.yesbutapp.yesbut

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews

/** Home-screen widget: four quick starts plus your latest check. */
class QuickWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val last = prefs.getString("flutter.widget_last", null)
        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.quick_widget)
            views.setOnClickPendingIntent(R.id.widget_title, open(context, "home", 0))
            views.setOnClickPendingIntent(R.id.btn_scan, open(context, "scan", 1))
            views.setOnClickPendingIntent(R.id.btn_upload, open(context, "upload", 2))
            views.setOnClickPendingIntent(R.id.btn_paste, open(context, "paste", 3))
            views.setOnClickPendingIntent(R.id.btn_link, open(context, "link", 4))
            if (last.isNullOrBlank()) {
                views.setViewVisibility(R.id.widget_last, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_last, View.VISIBLE)
                views.setTextViewText(R.id.widget_last, last)
                views.setOnClickPendingIntent(R.id.widget_last, open(context, "history", 5))
            }
            manager.updateAppWidget(id, views)
        }
    }

    private fun open(context: Context, action: String, code: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("yesbut://$action"), context, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        return PendingIntent.getActivity(
            context, code, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
