package com.aisecurity.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.Random

class NotificationReceiverService : NotificationListenerService() {

    companion object {
        private const val TAG        = "NRSVC"
        private const val CHANNEL_ID = "notif_threats"

        private val TARGET_PACKAGES = setOf(
            "com.whatsapp",
            "com.whatsapp.w4b",
            "org.telegram.messenger",
            "org.telegram.messenger.web",
            "org.thoughtcrime.securesms",
            "com.instagram.android",
            "com.facebook.orca",
        )

        private val CALL_KEYWORDS = listOf(
            "incoming call", "incoming video call", "incoming voice call",
            "calling", "is calling you", "video call", "voice call",
            "ongoing call", "missed call",
            "आ रही कॉल", "कॉल आ रही है", "वीडियो कॉल", "कॉल कर रहा है",
            "call aa rahi hai", "incoming", "ka call",
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val pkg = sbn.packageName ?: return
        if (pkg !in TARGET_PACKAGES) return

        val extras   = sbn.notification?.extras ?: return
        val title    = extras.getString("android.title") ?: ""
        val text     = extras.getCharSequence("android.text")?.toString() ?: ""
        val bigText  = extras.getCharSequence("android.bigText")?.toString() ?: ""
        val combined = "$title $text $bigText"

        if (title.isBlank() && text.isBlank()) return

        val isCall = sbn.notification.category == android.app.Notification.CATEGORY_CALL ||
                     CALL_KEYWORDS.any { combined.lowercase().contains(it) }

        Log.d(TAG, "[$pkg] isCall=$isCall title=$title")

        // ── Native threat analysis (works even when Flutter is killed) ────────
        val body = if (text.isNotBlank()) text else bigText
        if (!isCall && body.isNotBlank()) {
            val result = ThreatEngine.analyzeText("$title $body")
            if (result.riskScore >= 60) {
                Log.d(TAG, "Threat in notification: score=${result.riskScore} cat=${result.category}")
                // Show overlay on top of WhatsApp/Telegram so user sees warning immediately
                val appLabel = when {
                    pkg.contains("whatsapp")  -> "WhatsApp"
                    pkg.contains("telegram")  -> "Telegram"
                    pkg.contains("instagram") -> "Instagram"
                    pkg.contains("signal")    -> "Signal"
                    else                      -> "App"
                }
                OverlayService.showThreat(
                    this,
                    "⚠ Scam in $appLabel — $title",
                    result.reason.take(100),
                    result.category,
                )
                showThreatNotification(title, body, pkg, result)
            }
        }

        // ── Also forward to Flutter for DB storage & dashboard update ─────────
        val intent = Intent("com.aisecurity.app.NOTIFICATION_EVENT").apply {
            setPackage(packageName)
            putExtra("package", pkg)
            putExtra("sender",  title)
            putExtra("body",    body)
            putExtra("isCall",  isCall)
        }
        sendBroadcast(intent)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) { /* no-op */ }

    private fun showThreatNotification(sender: String, body: String, pkg: String, result: ThreatResult) {
        createChannel()

        val appName = when {
            pkg.contains("whatsapp")  -> "WhatsApp"
            pkg.contains("telegram")  -> "Telegram"
            pkg.contains("instagram") -> "Instagram"
            pkg.contains("signal")    -> "Signal"
            else                      -> "Messaging app"
        }

        val tapIntent = packageManager
            .getLaunchIntentForPackage(packageName)
            ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK }
        val pi = PendingIntent.getActivity(
            this, Random().nextInt(9000), tapIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("⚠ Scam message in $appName from $sender")
            .setContentText(result.reason)
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("${result.reason}\n\nMessage: ${body.take(200)}"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()

        getSystemService(NotificationManager::class.java)
            .notify(Random().nextInt(9000), notification)
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL_ID, "WhatsApp Threat Alerts",
                NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Scam messages detected in WhatsApp, Telegram etc."
                enableVibration(true)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        }
    }
}
