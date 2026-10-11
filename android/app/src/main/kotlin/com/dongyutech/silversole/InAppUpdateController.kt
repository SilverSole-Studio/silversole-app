package com.dongyutech.silversole

import android.content.IntentSender
import android.content.pm.PackageManager
import android.os.Build
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Google Play in-app updates, driven from Dart over [CHANNEL_NAME].
 *
 * A Play install must update through Play only — Play policy forbids steering
 * it to any other download — so Dart asks [isInstalledFromPlay] first and keeps
 * the GitHub prompt for sideloaded APKs.
 *
 * A flexible update downloads in the background and is installed only once the
 * app has left the foreground: installing restarts the process, and doing that
 * mid-session would cut a live BLE stream or a recording.
 */
internal class InAppUpdateController(
    private val activity: FlutterActivity,
) {
    companion object {
        private const val CHANNEL_NAME = "com.dongyutech.silversole/in_app_update"
        private const val UPDATE_REQUEST_CODE = 1732
        private const val PLAY_STORE_PACKAGE = "com.android.vending"
    }

    private lateinit var appUpdateManager: AppUpdateManager
    private var currentUpdateType: Int? = null
    private var inForeground = false

    private val installStateListener = InstallStateUpdatedListener { state ->
        if (state.installStatus() == InstallStatus.DOWNLOADED && !inForeground) {
            completeFlexibleUpdate()
        }
    }

    fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        appUpdateManager = AppUpdateManagerFactory.create(activity)
        appUpdateManager.registerListener(installStateListener)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isInstalledFromPlay" -> result.success(isInstalledFromPlay())
                "checkForUpdate" -> checkForUpdate(result)
                else -> result.notImplemented()
            }
        }
    }

    fun onResume() {
        inForeground = true
        if (!::appUpdateManager.isInitialized) return

        // An immediate update the user left half way must be resumed, or the
        // app keeps running the version Play considers too old.
        appUpdateManager.appUpdateInfo.addOnSuccessListener { info ->
            if (info.shouldResumeImmediateUpdate()) {
                currentUpdateType = AppUpdateType.IMMEDIATE
                try {
                    startUpdateFlow(info, AppUpdateType.IMMEDIATE)
                } catch (_: IntentSender.SendIntentException) {
                }
            }
        }
    }

    fun onPause() {
        inForeground = false
    }

    fun onStop() {
        if (!::appUpdateManager.isInitialized) return

        appUpdateManager.appUpdateInfo.addOnSuccessListener { info ->
            if (info.installStatus() == InstallStatus.DOWNLOADED) {
                completeFlexibleUpdate()
            }
        }
    }

    fun onDestroy() {
        if (::appUpdateManager.isInitialized) {
            appUpdateManager.unregisterListener(installStateListener)
        }
    }

    private fun isInstalledFromPlay(): Boolean {
        val installer = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                activity.packageManager
                    .getInstallSourceInfo(activity.packageName)
                    .installingPackageName
            } else {
                @Suppress("DEPRECATION")
                activity.packageManager.getInstallerPackageName(activity.packageName)
            }
        } catch (_: PackageManager.NameNotFoundException) {
            null
        }
        return installer == PLAY_STORE_PACKAGE
    }

    private fun checkForUpdate(result: MethodChannel.Result) {
        appUpdateManager.appUpdateInfo.addOnSuccessListener { info ->
            val updateType = info.resolveUpdateType()
            if (updateType == null) {
                currentUpdateType = null
                result.success("none")
                return@addOnSuccessListener
            }

            try {
                if (!startUpdateFlow(info, updateType)) {
                    currentUpdateType = null
                    result.success("none")
                    return@addOnSuccessListener
                }
                result.success(updateType.asFlowName())
            } catch (e: IntentSender.SendIntentException) {
                currentUpdateType = null
                result.error("IN_APP_UPDATE_START_FAILED", e.message, null)
            }
        }.addOnFailureListener { e ->
            currentUpdateType = null
            result.error("IN_APP_UPDATE", e.message, null)
        }
    }

    private fun completeFlexibleUpdate() {
        appUpdateManager.completeUpdate().addOnSuccessListener {
            currentUpdateType = null
        }
    }

    @Throws(IntentSender.SendIntentException::class)
    private fun startUpdateFlow(info: AppUpdateInfo, updateType: Int): Boolean {
        currentUpdateType = updateType
        return appUpdateManager.startUpdateFlowForResult(
            info,
            activity,
            AppUpdateOptions.newBuilder(updateType).build(),
            UPDATE_REQUEST_CODE
        )
    }
}
