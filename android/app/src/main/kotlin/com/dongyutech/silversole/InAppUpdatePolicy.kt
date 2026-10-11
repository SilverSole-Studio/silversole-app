package com.dongyutech.silversole

import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability

// The priority is set per release at upload (`inAppUpdatePriority`, 0-5; the
// release workflow sends 3). 4+ blocks the app until it updates; 2-3, or an
// update left waiting a week, downloads in the background.
private const val IMMEDIATE_PRIORITY_THRESHOLD = 4
private const val FLEXIBLE_PRIORITY_THRESHOLD = 2
private const val FLEXIBLE_STALENESS_THRESHOLD_DAYS = 7

internal fun AppUpdateInfo.resolveUpdateType(): Int? {
    if (updateAvailability() != UpdateAvailability.UPDATE_AVAILABLE) return null

    val priority = updatePriority()
    val stalenessDays = clientVersionStalenessDays() ?: -1
    return when {
        priority >= IMMEDIATE_PRIORITY_THRESHOLD &&
            isUpdateTypeAllowed(AppUpdateType.IMMEDIATE) ->
            AppUpdateType.IMMEDIATE

        (priority >= FLEXIBLE_PRIORITY_THRESHOLD ||
            stalenessDays >= FLEXIBLE_STALENESS_THRESHOLD_DAYS) &&
            isUpdateTypeAllowed(AppUpdateType.FLEXIBLE) ->
            AppUpdateType.FLEXIBLE

        else -> null
    }
}

internal fun AppUpdateInfo.shouldResumeImmediateUpdate(): Boolean =
    updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS &&
        isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)

internal fun Int.asFlowName(): String =
    if (this == AppUpdateType.IMMEDIATE) "immediate" else "flexible"
