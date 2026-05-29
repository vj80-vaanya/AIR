package com.aisecurity.app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.content.Intent
import android.util.Log

class NotificationReceiverService : NotificationListenerService() {

    companion object {
        private val TARGET_PACKAGES = setOf(
            "com.whatsapp",
            "com.whatsapp.w4b",                  // WhatsApp Business
            "org.telegram.messenger",
            "org.telegram.messenger.web",
            "org.thoughtcrime.securesms",         // Signal
            "com.instagram.android",              // Instagram DMs
            "com.facebook.orca",                  // Messenger
        )

        // Strings that indicate a VoIP/voice call notification (English + Hindi)
        private val CALL_KEYWORDS = listOf(
            // English
            "incoming call", "incoming video call", "incoming voice call",
            "calling", "is calling you", "video call", "voice call",
            "ongoing call", "missed call",
            // Hindi
            "आ रही कॉल", "कॉल आ रही है", "वीडियो कॉल", "वॉयस कॉल",
            "कॉल कर रहा है", "कॉल कर रही है", "मिस्ड कॉल", "इनकमिंग कॉल",
            // Hinglish
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
        val combined = "$title $text $bigText".lowercase()

        // Suppress empty notifications (e.g. ongoing service badges)
        if (title.isBlank() && text.isBlank()) return

        val isCall = sbn.notification.category == android.app.Notification.CATEGORY_CALL ||
                     CALL_KEYWORDS.any { combined.contains(it) }

        Log.d("NRSVC", "[$pkg] title=$title | isCall=$isCall")

        val intent = Intent("com.aisecurity.app.NOTIFICATION_EVENT").apply {
            setPackage(this@NotificationReceiverService.packageName)
            putExtra("package", pkg)
            putExtra("sender",  title)
            putExtra("body",    if (text.isNotBlank()) text else bigText)
            putExtra("isCall",  isCall)
        }
        sendBroadcast(intent)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) { /* no-op */ }
}
