package com.aisecurity.app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.content.Intent
import android.os.Bundle
import android.util.Log

class NotificationReceiverService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName ?: return
        
        // Target messaging apps
        val targetApps = listOf(
            "com.whatsapp",
            "org.telegram.messenger",
            "org.thoughtcrime.securesms" // Signal
        )

        if (packageName in targetApps) {
            val extras = sbn.notification.extras
            val title = extras.getString("android.title") ?: ""
            val text = extras.getCharSequence("android.text")?.toString() ?: ""
            val category = sbn.notification.category

            Log.d("NotificationReceiver", "Received from $packageName: $title - $text (Cat: $category)")

            val isCall = category == android.app.Notification.CATEGORY_CALL ||
                         text.contains("Incoming call") ||
                         text.contains("Calling")

            val intent = Intent("com.aisecurity.app.NOTIFICATION_EVENT").apply {
                setPackage(this@NotificationReceiverService.packageName)
                putExtra("package", packageName)
                putExtra("sender", title)
                putExtra("body", text)
                putExtra("isCall", isCall)
            }
            sendBroadcast(intent)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // No-op
    }
}
