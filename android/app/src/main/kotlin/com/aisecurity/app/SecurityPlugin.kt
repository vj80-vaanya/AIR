package com.aisecurity.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import android.telephony.TelephonyManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Android call/SMS events to Flutter via EventChannels.
 * For testing: sends a mock threat event 10 s after the channel is opened.
 */
object SecurityPlugin {

    private const val CALL_CHANNEL         = "ai_security/call_events"
    private const val SMS_CHANNEL          = "ai_security/sms_events"
    private const val NOTIFICATION_CHANNEL = "ai_security/notification_events"
    private const val DEEP_SCAN_CHANNEL    = "ai_security/deep_scan_events"
    private const val PAYMENT_CHANNEL      = "ai_security/payment_events"
    private const val REMOTE_CHANNEL       = "ai_security/remote_events"
    private const val STATUS_CHANNEL       = "ai_security/status"
    private const val SOS_CHANNEL          = "ai_security/sos"

    fun register(engine: FlutterEngine, context: Context) {
        EventChannel(engine.dartExecutor.binaryMessenger, CALL_CHANNEL)
            .setStreamHandler(CallStreamHandler(context))

        EventChannel(engine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setStreamHandler(SmsStreamHandler(context))

        EventChannel(engine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
            .setStreamHandler(NotificationStreamHandler(context))

        EventChannel(engine.dartExecutor.binaryMessenger, DEEP_SCAN_CHANNEL)
            .setStreamHandler(DeepScanStreamHandler(context))

        EventChannel(engine.dartExecutor.binaryMessenger, PAYMENT_CHANNEL)
            .setStreamHandler(PaymentStreamHandler(context))

        EventChannel(engine.dartExecutor.binaryMessenger, REMOTE_CHANNEL)
            .setStreamHandler(RemoteStreamHandler(context))

        MethodChannel(engine.dartExecutor.binaryMessenger, STATUS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isNotificationListenerEnabled" -> {
                        val pkgName = context.packageName
                        val flat = android.provider.Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
                        result.success(flat?.contains(pkgName) == true)
                    }
                    "isAccessibilityServiceEnabled" -> {
                        val pkgName = context.packageName
                        val flat = android.provider.Settings.Secure.getString(context.contentResolver, android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
                        result.success(flat?.contains(pkgName) == true)
                    }
                    "openNotificationListenerSettings" -> {
                        context.startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    }
                    "openAccessibilitySettings" -> {
                        context.startActivity(Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // SOS: send SMS alerts + make emergency call
        MethodChannel(engine.dartExecutor.binaryMessenger, SOS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSosAlerts" -> {
                        @Suppress("UNCHECKED_CAST")
                        val contacts = call.argument<List<Map<String, String>>>("contacts") ?: emptyList()
                        val message  = call.argument<String>("message") ?: "SOS EMERGENCY! I need immediate help!"
                        val smsManager = getSmsManager(context)
                        var sent = 0
                        for (contact in contacts) {
                            val phone = contact["phone"] ?: continue
                            try {
                                smsManager.sendTextMessage(phone, null, message, null, null)
                                sent++
                            } catch (e: Exception) { /* ignored */ }
                        }
                        result.success(sent)
                    }
                    "makeEmergencyCall" -> {
                        val phone = call.argument<String>("phone") ?: ""
                        if (phone.isNotEmpty()) {
                            try {
                                val intent = Intent(Intent.ACTION_CALL).apply {
                                    data = Uri.parse("tel:$phone")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                context.startActivity(intent)
                            } catch (e: Exception) { /* ignored */ }
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun getSmsManager(context: Context): SmsManager =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            context.getSystemService(SmsManager::class.java)
        else
            SmsManager.getDefault()

    // ── Deep Scanning (Accessibility) ────────────────────────────────────────

    class DeepScanStreamHandler(private val ctx: Context) : EventChannel.StreamHandler {
        private var sink: EventChannel.EventSink? = null
        private var receiver: BroadcastReceiver? = null

        override fun onListen(args: Any?, events: EventChannel.EventSink?) {
            sink = events
            receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    sink?.success(mapOf(
                        "package" to intent.getStringExtra("package"),
                        "content" to intent.getStringExtra("content"),
                    ))
                }
            }
            val filter = IntentFilter("com.aisecurity.app.DEEP_SCAN_EVENT")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ctx.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                ctx.registerReceiver(receiver, filter)
            }
        }

        override fun onCancel(args: Any?) {
            receiver?.let { ctx.unregisterReceiver(it) }
            receiver = null
            sink = null
        }
    }

    class PaymentStreamHandler(private val ctx: Context) : EventChannel.StreamHandler {
        private var sink: EventChannel.EventSink? = null
        private var receiver: BroadcastReceiver? = null

        override fun onListen(args: Any?, events: EventChannel.EventSink?) {
            sink = events
            receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    sink?.success(mapOf(
                        "package" to intent.getStringExtra("package"),
                    ))
                }
            }
            val filter = IntentFilter("com.aisecurity.app.PAYMENT_APP_OPENED")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ctx.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                ctx.registerReceiver(receiver, filter)
            }
        }

        override fun onCancel(args: Any?) {
            receiver?.let { ctx.unregisterReceiver(it) }
            receiver = null
            sink = null
        }
    }

    class RemoteStreamHandler(private val ctx: Context) : EventChannel.StreamHandler {
        private var sink: EventChannel.EventSink? = null
        private var receiver: BroadcastReceiver? = null

        override fun onListen(args: Any?, events: EventChannel.EventSink?) {
            sink = events
            receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    sink?.success(mapOf(
                        "package" to intent.getStringExtra("package"),
                    ))
                }
            }
            val filter = IntentFilter("com.aisecurity.app.REMOTE_APP_OPENED")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ctx.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                ctx.registerReceiver(receiver, filter)
            }
        }

        override fun onCancel(args: Any?) {
            receiver?.let { ctx.unregisterReceiver(it) }
            receiver = null
            sink = null
        }
    }

    // ── Notification monitoring ──────────────────────────────────────────────

    class NotificationStreamHandler(private val ctx: Context) : EventChannel.StreamHandler {
        private var sink: EventChannel.EventSink? = null
        private var receiver: BroadcastReceiver? = null

        override fun onListen(args: Any?, events: EventChannel.EventSink?) {
            sink = events
            receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    sink?.success(mapOf(
                        "package" to intent.getStringExtra("package"),
                        "sender"  to intent.getStringExtra("sender"),
                        "body"    to intent.getStringExtra("body"),
                    ))
                }
            }
            val filter = IntentFilter("com.aisecurity.app.NOTIFICATION_EVENT")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ctx.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                ctx.registerReceiver(receiver, filter)
            }
        }

        override fun onCancel(args: Any?) {
            receiver?.let { ctx.unregisterReceiver(it) }
            receiver = null
            sink = null
        }
    }

    // ── Call monitoring ──────────────────────────────────────────────────────

    class CallStreamHandler(private val ctx: Context) : EventChannel.StreamHandler {
        private var sink: EventChannel.EventSink? = null
        private var receiver: BroadcastReceiver? = null

        override fun onListen(args: Any?, events: EventChannel.EventSink?) {
            sink = events
            receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
                    val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER) ?: ""
                    if (state == TelephonyManager.EXTRA_STATE_RINGING) {
                        sink?.success(mapOf(
                            "phoneNumber" to number,
                            "callerId"    to "",
                            "isKnownContact" to false,
                        ))
                    }
                }
            }
            val filter = IntentFilter(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ctx.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                ctx.registerReceiver(receiver, filter)
            }
        }

        override fun onCancel(args: Any?) {
            receiver?.let { ctx.unregisterReceiver(it) }
            receiver = null
            sink = null
        }
    }

    // ── SMS monitoring ───────────────────────────────────────────────────────

    class SmsStreamHandler(private val ctx: Context) : EventChannel.StreamHandler {
        private var sink: EventChannel.EventSink? = null
        private var receiver: BroadcastReceiver? = null

        override fun onListen(args: Any?, events: EventChannel.EventSink?) {
            sink = events
            receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    if (intent.action != "android.provider.Telephony.SMS_RECEIVED") return
                    @Suppress("DEPRECATION")
                    val pdus = intent.extras?.get("pdus") as? Array<*> ?: return
                    for (pdu in pdus) {
                        val sms = android.telephony.SmsMessage.createFromPdu(pdu as ByteArray)
                        sink?.success(mapOf(
                            "sender"      to (sms.displayOriginatingAddress ?: ""),
                            "body"        to (sms.displayMessageBody ?: ""),
                            "containsUrl" to false,
                        ))
                    }
                }
            }
            val filter = IntentFilter("android.provider.Telephony.SMS_RECEIVED")
            filter.priority = IntentFilter.SYSTEM_HIGH_PRIORITY
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ctx.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                ctx.registerReceiver(receiver, filter)
            }
        }

        override fun onCancel(args: Any?) {
            receiver?.let { ctx.unregisterReceiver(it) }
            receiver = null
            sink = null
        }
    }
}
