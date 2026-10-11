package com.dongyutech.silversole.ble

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.*
import androidx.core.app.NotificationCompat
import com.dongyutech.silversole.MainActivity
import com.dongyutech.silversole.R

class BleForegroundService : Service() {
    companion object {
        const val ACTION_START = "com.dongyutech.silversole.ble.START"
        const val ACTION_STOP = "com.dongyutech.silversole.ble.STOP"
        private const val CHANNEL_ID = "ble_foreground_channel"
        private const val NOTIFICATION_ID = 1001

        // What the ongoing notification says, pushed from Dart (sole name,
        // online / last connected, battery). Kept here rather than on the
        // instance so a restarted service comes back with the latest text.
        @Volatile private var title: String? = null
        @Volatile private var text: String? = null
        @Volatile private var running = false

        /**
         * Rewrites the ongoing notification in place. While the service is
         * stopped this only stores the text for its next start, so an update
         * can never leave a stray notification behind.
         */
        fun updateNotification(context: Context, title: String, text: String) {
            this.title = title
            this.text = text
            if (!running) return
            try {
                context.getSystemService(NotificationManager::class.java)
                    .notify(NOTIFICATION_ID, buildNotification(context))
            } catch (_: SecurityException) {
                // Notification permission revoked: the service keeps running.
            }
        }

        private fun buildNotification(context: Context): Notification {
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setContentTitle(title ?: context.getString(R.string.ble_service_title))
                .setContentText(text ?: context.getString(R.string.ble_service_running))
                .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                // Battery and "last connected" refresh it often; never buzz.
                .setOnlyAlertOnce(true)
                .build()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                running = false
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_START, null -> {
                createNotificationChannelIfNeeded()
                startForeground(NOTIFICATION_ID, buildNotification(this))
                running = true
                return START_STICKY
            }

            else -> return START_NOT_STICKY
        }
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    private fun createNotificationChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "BLE Foreground Service",
            NotificationManager.IMPORTANCE_LOW
        )
        manager.createNotificationChannel(channel)
    }
}
