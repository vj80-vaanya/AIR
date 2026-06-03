package com.aisecurity.app

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.*
import android.provider.Settings
import android.view.*
import android.view.animation.AnimationUtils
import android.widget.*
import androidx.core.app.NotificationCompat

/**
 * Draws a floating threat-warning banner over any app on screen —
 * even when AI Security is completely closed.
 *
 * Requires SYSTEM_ALERT_WINDOW permission (Draw over other apps).
 * Call showThreat() from SmsReceiver, NotificationReceiverService,
 * or the call handler; it is safe to call from any thread.
 */
class OverlayService : Service() {

    companion object {
        private const val CHANNEL_ID = "overlay_channel"
        private const val NOTIF_ID   = 8001

        private const val EXTRA_TITLE    = "title"
        private const val EXTRA_REASON   = "reason"
        private const val EXTRA_CATEGORY = "category"

        /** Show the overlay — starts service if not running. Safe from any thread. */
        fun showThreat(context: Context, title: String, reason: String, category: String) {
            if (!Settings.canDrawOverlays(context)) return
            val intent = Intent(context, OverlayService::class.java).apply {
                putExtra(EXTRA_TITLE,    title)
                putExtra(EXTRA_REASON,   reason)
                putExtra(EXTRA_CATEGORY, category)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                context.startForegroundService(intent)
            else
                context.startService(intent)
        }

        fun hasPermission(context: Context)  = Settings.canDrawOverlays(context)

        /** Opens system settings so user can grant SYSTEM_ALERT_WINDOW. */
        fun requestPermission(context: Context) {
            if (hasPermission(context)) return
            context.startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    android.net.Uri.parse("package:${context.packageName}")
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    private var windowManager: WindowManager? = null
    private var overlayView:   View?          = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var autoDismiss: Runnable?        = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        ensureChannel()
        startForeground(NOTIF_ID, silentNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title    = intent?.getStringExtra(EXTRA_TITLE)    ?: "Scam Detected"
        val reason   = intent?.getStringExtra(EXTRA_REASON)   ?: ""
        mainHandler.post { showOverlay(title, reason) }
        return START_NOT_STICKY
    }

    // ── Overlay lifecycle ─────────────────────────────────────────────────────

    private fun showOverlay(title: String, reason: String) {
        if (!Settings.canDrawOverlays(this)) { stopSelf(); return }
        dismissOverlay() // remove any existing one

        val inflater = LayoutInflater.from(this)
        val view     = inflater.inflate(R.layout.overlay_threat, null)

        view.findViewById<TextView>(R.id.overlay_title).text  = title
        view.findViewById<TextView>(R.id.overlay_reason).text = reason.take(120)

        // Close button
        view.findViewById<ImageButton>(R.id.overlay_close).setOnClickListener {
            dismissOverlay()
        }

        // Tap anywhere → open the app
        view.setOnClickListener {
            packageManager.getLaunchIntentForPackage(packageName)?.let {
                it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                startActivity(it)
            }
            dismissOverlay()
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0; y = 0
        }

        windowManager?.addView(view, params)
        overlayView = view

        // Slide down from top
        view.startAnimation(
            AnimationUtils.loadAnimation(this, android.R.anim.slide_in_left)
        )

        // Auto-dismiss after 12 seconds
        autoDismiss = Runnable { dismissOverlay() }.also {
            mainHandler.postDelayed(it, 12_000L)
        }
    }

    private fun dismissOverlay() {
        autoDismiss?.let { mainHandler.removeCallbacks(it) }
        autoDismiss = null
        overlayView?.let {
            try { windowManager?.removeView(it) } catch (_: Exception) {}
        }
        overlayView = null
    }

    override fun onDestroy() {
        dismissOverlay()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID, "Overlay Service", NotificationManager.IMPORTANCE_MIN
            ).apply { setShowBadge(false); enableVibration(false) }
            getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        }
    }

    private fun silentNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("AI Security overlay active")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setSilent(true)
            .setOngoing(true)
            .build()
}
