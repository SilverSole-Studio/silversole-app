package com.andongni.silversole.ble

import android.app.*
import android.content.Intent
import android.os.*
import androidx.core.app.NotificationCompat
import com.andongni.silversole.MainActivity
import com.andongni.silversole.R

class BleForegroundService : Service() {
    companion object {
        const val ACTION_START = "com.andongni.silversole.ble.START"
        const val ACTION_STOP = "com.andongni.silversole.ble.STOP"
        private const val CHANNEL_ID = "ble_foreground_channel"
        private const val NOTIFICATION_ID = 1001
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_START, null -> {
                createNotificationChannelIfNeeded()
                startForeground(NOTIFICATION_ID, buildNotification())
                return START_STICKY
            }

            else -> return START_NOT_STICKY
        }
    }

    private fun buildNotification(): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.ble_service_title))
            .setContentText(getString(R.string.ble_service_running))
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
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
