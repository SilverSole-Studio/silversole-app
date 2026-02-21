package com.andongni.silversole

import android.content.Intent
import androidx.core.content.ContextCompat
import com.andongni.silversole.ble.BleForegroundService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel


class MainActivity : FlutterActivity() {
    private val bleCannel = "com.andongni.silversole/ble_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            bleCannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBleService" -> {
                    startBleService()
                    result.success(null)
                }

                "stopBleService" -> {
                    stopBleService()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun startBleService() {
        val intent = Intent(this, BleForegroundService::class.java).apply {
            action = BleForegroundService.ACTION_START
        }
        ContextCompat.startForegroundService(this, intent)
    }

    private fun stopBleService() {
        val intent = Intent(this, BleForegroundService::class.java).apply {
            action = BleForegroundService.ACTION_STOP
        }
        startService(intent)
    }
}