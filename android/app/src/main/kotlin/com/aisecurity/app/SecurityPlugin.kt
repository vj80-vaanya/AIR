package com.aisecurity.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.telephony.TelephonyManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

/**
 * Bridges Android call/SMS events to Flutter via EventChannels.
 * For testing: sends a mock threat event 10 s after the channel is opened.
 */
object SecurityPlugin {

    private const val CALL_CHANNEL = "ai_security/call_events"
    private const val SMS_CHANNEL  = "ai_security/sms_events"

    fun register(engine: FlutterEngine, context: Context) {
        EventChannel(engine.dartExecutor.binaryMessenger, CALL_CHANNEL)
            .setStreamHandler(CallStreamHandler(context))

        EventChannel(engine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setStreamHandler(SmsStreamHandler(context))
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
