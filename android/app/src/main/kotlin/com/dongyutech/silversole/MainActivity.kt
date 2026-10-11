package com.dongyutech.silversole

import android.content.Intent
import androidx.core.content.ContextCompat
import com.dongyutech.silversole.ble.BleForegroundService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel


class MainActivity : FlutterActivity() {
    private val bleCannel = "com.dongyutech.silversole/ble_service"
    private val inAppUpdateController by lazy { InAppUpdateController(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        inAppUpdateController.configureFlutterEngine(flutterEngine)

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

    override fun onResume() {
        super.onResume()
        inAppUpdateController.onResume()
    }

    override fun onPause() {
        inAppUpdateController.onPause()
        super.onPause()
    }

    override fun onStop() {
        inAppUpdateController.onStop()
        super.onStop()
    }

    override fun onDestroy() {
        inAppUpdateController.onDestroy()
        super.onDestroy()
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