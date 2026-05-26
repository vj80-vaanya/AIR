package com.aisecurity.app

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.content.Intent
import android.util.Log

class DeepSecurityService : AccessibilityService() {

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val packageName = event.packageName?.toString() ?: return
        
        // Only monitor target apps when they are in the foreground
        val targetApps = listOf(
            "com.whatsapp",
            "org.telegram.messenger",
            "org.thoughtcrime.securesms",
            "com.google.android.apps.nbu.paisa.user", // GPay
            "com.phonepe.app",                       // PhonePe
            "net.one97.paytm",                       // Paytm
            "in.org.npci.upiapp",                     // BHIM
            "com.anydesk.anydeskandroid",            // AnyDesk
            "com.teamviewer.teamviewer.market.mobile", // TeamViewer
            "com.rustdesk.rustdesk"                  // RustDesk
        )

        if (packageName in targetApps) {
            val isPaymentApp = packageName.contains("paisa") || 
                              packageName.contains("phonepe") || 
                              packageName.contains("paytm") || 
                              packageName.contains("upiapp")
            
            val isRemoteApp = packageName.contains("anydesk") || 
                             packageName.contains("teamviewer") || 
                             packageName.contains("rustdesk")

            if ((isPaymentApp || isRemoteApp) && event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                val action = if (isPaymentApp) "com.aisecurity.app.PAYMENT_APP_OPENED" else "com.aisecurity.app.REMOTE_APP_OPENED"
                val intent = Intent(action).apply {
                    setPackage(applicationContext.packageName)
                    putExtra("package", packageName)
                }
                sendBroadcast(intent)
                return
            }

            val rootNode = rootInActiveWindow ?: return
            
            // Extract text from the screen
            val sb = StringBuilder()
            extractText(rootNode, sb)
            val screenText = sb.toString()

            if (screenText.isNotEmpty()) {
                val intent = Intent("com.aisecurity.app.DEEP_SCAN_EVENT").apply {
                    setPackage(applicationContext.packageName)
                    putExtra("package", packageName)
                    putExtra("content", screenText)
                }
                sendBroadcast(intent)
            }
        }
    }

    private fun extractText(node: AccessibilityNodeInfo, sb: StringBuilder) {
        node.text?.let { 
            if (it.isNotBlank()) {
                sb.append(it).append(" ")
            }
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                extractText(child, sb)
                child.recycle()
            }
        }
    }

    override fun onInterrupt() {
        // No-op
    }
}
