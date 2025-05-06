package com.vonagevoice.call

import android.util.Log
import androidx.core.app.NotificationCompat
import com.vonagevoice.audio.DeviceManager
import com.vonagevoice.notifications.NotificationManager

data class RingtonePreferences(
    val songEnabled: Boolean,
    val vibrationEnabled: Boolean
)

class InboundCallNotifier(
    private val notificationManager: NotificationManager,
    private val deviceManager: DeviceManager,
) {
    // possible to toggle via user preferences
    private val ringtonePreferences = RingtonePreferences(
        songEnabled = true, vibrationEnabled = true
    )

    fun notifyIncomingCall(from: String, callId: String): NotificationCompat.Builder {
        val notification = notificationManager.showInboundCallNotification(
            from = from,
            callId = callId,
        )

        //deviceManager.stopOtherAppsDoingAudio()
        playRingtoneEffects()

        return notification
    }

    private fun playRingtoneEffects() = with(deviceManager) {
        if (ringtonePreferences.songEnabled) startRingtoneSong()
        if (ringtonePreferences.vibrationEnabled) startRingtoneVibration()
    }

    fun stop() {
        Log.d("InboundCallNotifier", "stop")
        stopRingtoneEffects()
        notificationManager.cancelInboundNotification()
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