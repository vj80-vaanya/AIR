package com.aisecurity.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.SmsMessage
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.Random

/**
 * Manifest-declared receiver — captures SMS even when the app is fully killed.
 * Uses the native ThreatEngine (Kotlin port of the Dart SecurityEngine) so
 * full pattern matching + ML inference work in the background.
 */
class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG        = "SmsReceiver"
        private const val CHANNEL_ID = "sms_threats"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "android.provider.Telephony.SMS_RECEIVED") return

        // Initialise ML engine if this is the first time (cold start without app open)
        if (!ThreatEngine.mlReady) ThreatEngine.init(context)

        @Suppress("DEPRECATION")
        val pdus = intent.extras?.get("pdus") as? Array<*> ?: return
        val formatKey = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) "format" else null
        val format    = formatKey?.let { intent.extras?.getString(it) }

        for (pdu in pdus) {
            val sms = try {
                if (format != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                    SmsMessage.createFromPdu(pdu as ByteArray, format)
                else
                    @Suppress("DEPRECATION")
                    SmsMessage.createFromPdu(pdu as ByteArray)
            } catch (e: Exception) { continue }

            val body   = sms.displayMessageBody   ?: continue
            val sender = sms.displayOriginatingAddress ?: "Unknown"

            Log.d(TAG, "SMS from $sender — analysing")

            val result = ThreatEngine.analyzeText(body)

            if (result.riskScore >= 60) {
                Log.d(TAG, "Threat detected: score=${result.riskScore} cat=${result.category}")
                showThreatNotification(context, sender, body, result)
                forwardToFlutter(context, sender, body, result)
            }
        }
    }

    private fun showThreatNotification(context: Context, sender: String, body: String, result: ThreatResult) {
        createChannel(context)

        val tapIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK }
        val pi = PendingIntent.getActivity(
            context, Random().nextInt(9000), tapIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val title = when {
            result.riskScore >= 85 -> "⚠ SCAM ALERT from $sender"
            result.riskScore >= 60 -> "Suspicious SMS from $sender"
            else                   -> "SMS flagged from $sender"
        }

        val notification = androidx.core.app.NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(result.reason)
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("${result.reason}\n\nMessage: ${body.take(200)}"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()

        context.getSystemService(NotificationManager::class.java)
            .notify(Random().nextInt(9000), notification)
    }

    /** Broadcast so the running Flutter engine can store the threat in SQLite. */
    private fun forwardToFlutter(context: Context, sender: String, body: String, result: ThreatResult) {
        val intent = Intent("com.aisecurity.app.SMS_THREAT_DETECTED").apply {
            setPackage(context.packageName)
            putExtra("sender",     sender)
            putExtra("body",       body)
            putExtra("riskScore",  result.riskScore)
            putExtra("category",   result.category)
            putExtra("reason",     result.reason)
            putExtra("shouldBlock",result.shouldBlock)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.sendBroadcast(intent, null)
        } else {
            context.sendBroadcast(intent)
        }
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL_ID, "SMS Threat Alerts",
                NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Alerts for suspicious SMS detected in the background"
                enableVibration(true)
            }
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        }
    }
}
