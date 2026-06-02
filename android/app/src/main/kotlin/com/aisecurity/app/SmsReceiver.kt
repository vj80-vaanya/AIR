package com.aisecurity.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.SmsMessage
import androidx.core.app.NotificationCompat
import java.util.Random

/**
 * Manifest-declared SMS receiver — captures incoming SMS even when the
 * Flutter/Dart isolate is paused or the app is fully killed.
 *
 * Performs lightweight keyword analysis in Kotlin so high-risk messages
 * trigger a notification without needing Dart to be awake.
 */
class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val CHANNEL_ID = "sms_threats"

        // High-signal Indian scam keywords — intentionally short list to avoid false positives
        private val SCAM_KEYWORDS = listOf(
            "otp", "do not share", "never share",
            "kyc", "account blocked", "account suspended",
            "digital arrest", "cbi", "cybercrime",
            "click here", "link expires", "verify now",
            "won", "lottery", "prize", "lucky draw",
            "investment", "guaranteed return",
            "aadhaar", "pan card", "income tax",
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "android.provider.Telephony.SMS_RECEIVED") return

        @Suppress("DEPRECATION")
        val pdus = intent.extras?.get("pdus") as? Array<*> ?: return

        for (pdu in pdus) {
            val sms = try {
                SmsMessage.createFromPdu(pdu as ByteArray)
            } catch (e: Exception) { continue }

            val body   = sms.displayMessageBody?.lowercase() ?: continue
            val sender = sms.displayOriginatingAddress ?: "Unknown"

            val matchCount = SCAM_KEYWORDS.count { body.contains(it) }
            if (matchCount >= 2) {
                showThreatNotification(context, sender, sms.displayMessageBody ?: "")
                // Also forward to the running Flutter engine if it's alive
                forwardToFlutter(context, sender, sms.displayMessageBody ?: "")
            }
        }
    }

    private fun showThreatNotification(context: Context, sender: String, body: String) {
        createChannel(context)

        val tapIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK }
        val pi = PendingIntent.getActivity(
            context, Random().nextInt(9000), tapIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Suspicious SMS from $sender")
            .setContentText("This message contains scam patterns. Tap to review.")
            .setStyle(NotificationCompat.BigTextStyle().bigText(body.take(200)))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()

        context.getSystemService(NotificationManager::class.java)
            .notify(Random().nextInt(9000), notification)
    }

    private fun forwardToFlutter(context: Context, sender: String, body: String) {
        // Broadcast to the running app so Flutter can do full ML analysis
        val intent = Intent("com.aisecurity.app.SMS_THREAT_DETECTED").apply {
            setPackage(context.packageName)
            putExtra("sender", sender)
            putExtra("body",   body)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.sendBroadcast(intent, null)
        } else {
            context.sendBroadcast(intent)
        }
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID, "SMS Threat Alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Alerts for suspicious SMS detected while app is in background"
                enableVibration(true)
            }
            context.getSystemService(NotificationManager::class.java)
                .createNotificationChannel(ch)
        }
    }
}
