package com.aisecurity.app

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.N)
class SecurityQSTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onClick() {
        super.onClick()
        launchApp()
    }

    private fun updateTile() {
        val prefs = getSharedPreferences("ai_security_widget", MODE_PRIVATE)
        val score = prefs.getInt("widget_score", 100)
        val today = prefs.getInt("widget_today", 0)

        qsTile?.apply {
            state = if (score >= 70) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            label = "AI Security"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                subtitle = if (today == 0) "Protected" else "$today blocked"
            }
            contentDescription = "AI Security protection score: $score"
            updateTile()
        }
    }

    private fun launchApp() {
        val intent = packageManager
            .getLaunchIntentForPackage(packageName)
            ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
            ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pi = PendingIntent.getActivity(
                this, 0, intent, PendingIntent.FLAG_IMMUTABLE
            )
            startActivityAndCollapse(pi)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
