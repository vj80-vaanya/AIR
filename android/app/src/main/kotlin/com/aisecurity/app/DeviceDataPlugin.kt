package com.aisecurity.app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.CallLog
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Exposes device SMS inbox, call log, and widget-stats update to Flutter.
 */
object DeviceDataPlugin {

    private const val CHANNEL = "ai_security/device_data"

    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSmsInbox" -> {
                        val limit = call.argument<Int>("limit") ?: 100
                        result.success(getSmsInbox(context, limit))
                    }
                    "getCallLog" -> {
                        val limit = call.argument<Int>("limit") ?: 100
                        result.success(getCallLog(context, limit))
                    }
                    "updateWidgetStats" -> {
                        val score = call.argument<Int>("score") ?: 100
                        val today = call.argument<Int>("today") ?: 0
                        SecurityWidget.pushStats(context, score, today)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ── SMS inbox ─────────────────────────────────────────────────────────────

    private fun getSmsInbox(context: Context, limit: Int): List<Map<String, Any>> {
        val messages = mutableListOf<Map<String, Any>>()
        val uri = Uri.parse("content://sms/inbox")
        val cursor: Cursor? = try {
            context.contentResolver.query(
                uri,
                arrayOf("_id", "address", "body", "date"),
                null, null,
                "date DESC",
            )
        } catch (e: Exception) {
            return messages
        }

        cursor?.use {
            val addrIdx = it.getColumnIndex("address")
            val bodyIdx = it.getColumnIndex("body")
            val dateIdx = it.getColumnIndex("date")
            var count   = 0
            while (it.moveToNext() && count < limit) {
                messages.add(
                    mapOf(
                        "sender" to (if (addrIdx >= 0) it.getString(addrIdx) ?: "" else ""),
                        "body"   to (if (bodyIdx >= 0) it.getString(bodyIdx) ?: "" else ""),
                        "date"   to (if (dateIdx >= 0) it.getLong(dateIdx) else 0L),
                    )
                )
                count++
            }
        }
        return messages
    }

    // ── Call log ──────────────────────────────────────────────────────────────

    private fun getCallLog(context: Context, limit: Int): List<Map<String, Any>> {
        val calls = mutableListOf<Map<String, Any>>()
        val uri   = CallLog.Calls.CONTENT_URI
        val cursor: Cursor? = try {
            context.contentResolver.query(
                uri,
                arrayOf(
                    CallLog.Calls.NUMBER,
                    CallLog.Calls.CACHED_NAME,
                    CallLog.Calls.TYPE,
                    CallLog.Calls.DATE,
                    CallLog.Calls.DURATION,
                ),
                null, null,
                "${CallLog.Calls.DATE} DESC",
            )
        } catch (e: Exception) {
            return calls
        }

        cursor?.use {
            val numIdx  = it.getColumnIndex(CallLog.Calls.NUMBER)
            val nameIdx = it.getColumnIndex(CallLog.Calls.CACHED_NAME)
            val typeIdx = it.getColumnIndex(CallLog.Calls.TYPE)
            val dateIdx = it.getColumnIndex(CallLog.Calls.DATE)
            val durIdx  = it.getColumnIndex(CallLog.Calls.DURATION)
            var count   = 0
            while (it.moveToNext() && count < limit) {
                calls.add(
                    mapOf(
                        "number"   to (if (numIdx  >= 0) it.getString(numIdx)  ?: "" else ""),
                        "name"     to (if (nameIdx >= 0) it.getString(nameIdx) ?: "" else ""),
                        "type"     to (if (typeIdx >= 0) it.getInt(typeIdx) else 0),
                        "date"     to (if (dateIdx >= 0) it.getLong(dateIdx) else 0L),
                        "duration" to (if (durIdx  >= 0) it.getLong(durIdx) else 0L),
                    )
                )
                count++
            }
        }
        return calls
    }
}
