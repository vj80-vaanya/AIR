package com.aisecurity.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class SecurityWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        ids.forEach { id -> updateWidget(context, manager, id) }
    }

    companion object {
        fun updateWidget(context: Context, manager: AppWidgetManager, id: Int) {
            val prefs = context.getSharedPreferences("ai_security_widget", Context.MODE_PRIVATE)
            val score = prefs.getInt("widget_score", 100)
            val today = prefs.getInt("widget_today", 0)

            val statusText = when {
                score >= 80 -> "Protected"
                score >= 50 -> "Partial"
                else        -> "At Risk"
            }

            val views = RemoteViews(context.packageName, R.layout.security_widget)
            views.setTextViewText(R.id.widget_score,   "$score")
            views.setTextViewText(R.id.widget_status,  statusText)
            views.setTextViewText(R.id.widget_blocked, "$today blocked today")

            // Tap → open app
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK }
            val launchPi = PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            views.setOnClickPendingIntent(R.id.widget_root, launchPi)

            // SOS button → open app with sos action
            // Clone the Intent — apply{} mutates in place and would corrupt launchIntent.
            val sosIntent = launchIntent?.let { Intent(it).apply { putExtra("open_screen", "sos") } }
            val sosPi = PendingIntent.getActivity(
                context, 1, sosIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            views.setOnClickPendingIntent(R.id.widget_sos_btn, sosPi)

            manager.updateAppWidget(id, views)
        }

        /** Called from Dart side via MethodChannel to push fresh stats. */
        fun pushStats(context: Context, score: Int, today: Int) {
            context.getSharedPreferences("ai_security_widget", Context.MODE_PRIVATE)
                .edit()
                .putInt("widget_score", score)
                .putInt("widget_today", today)
                .apply()

            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                android.content.ComponentName(context, SecurityWidget::class.java)
            )
            ids.forEach { updateWidget(context, manager, it) }
        }
    }
}
