package com.andongni.silversole.ble

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
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
                return START_STICKY
            }
            else -> return START_NOT_STICKY
        }
    }

    private fun createNotificationChannelIfNeeded() {

    }

}
