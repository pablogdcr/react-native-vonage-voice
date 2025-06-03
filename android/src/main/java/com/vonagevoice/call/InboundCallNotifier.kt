package com.vonagevoice.call

import android.content.Context
import android.util.Log
import androidx.core.app.NotificationCompat
import com.vonagevoice.audio.DeviceManager
import com.vonagevoice.notifications.NotificationManager
import com.vonagevoice.service.IncomingCallService

data class RingtonePreferences(
    val songEnabled: Boolean,
    val vibrationEnabled: Boolean
)

class InboundCallNotifier(
    private val notificationManager: NotificationManager,
    private val deviceManager: DeviceManager,
    private val context: Context
) {
    // possible to toggle via user preferences
    private val ringtonePreferences = RingtonePreferences(
        songEnabled = true, vibrationEnabled = true
    )

    fun notifyIncomingCall(from: String, callId: String, phoneName: String?): NotificationCompat.Builder {
        Log.d("InboundCallNotifier", "notifyIncomingCall")
        val notification = notificationManager.notificationBuilderForInboundCall(
            from = from,
            callId = callId,
            phoneName = phoneName
        )

        deviceManager.stopOtherAppsDoingAudio()
        playRingtoneEffects()

        return notification
    }

    private fun playRingtoneEffects() {
        Log.d("InboundCallNotifier", "playRingtoneEffects")
        with(deviceManager) {
            if (ringtonePreferences.songEnabled) startRingtoneSong()
            if (ringtonePreferences.vibrationEnabled) startRingtoneVibration()
        }
    }

    fun stopRingtoneAndInboundNotification() {
        Log.d("InboundCallNotifier", "stop")
        stopRingtoneEffects()
        notificationManager.cancelInboundNotification()
    }

    fun stopCall() {
        IncomingCallService.stop(context)
        stopRingtoneAndInboundNotification()
        deviceManager.releaseAudioFocus()
    }

    private fun stopRingtoneEffects() {
        Log.d("InboundCallNotifier", "stopRingtoneEffects")
        with(deviceManager) {
            stopRingtoneSong()
            stopRingtoneVibration()
        }
    }
}