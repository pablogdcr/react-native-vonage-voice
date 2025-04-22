package com.vonagevoice.utils

import android.content.Context
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri

lateinit var ringtone: Ringtone

fun startRingtone(context: Context) {
    val notification: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
    ringtone = RingtoneManager.getRingtone(context, notification)
    ringtone.play()
}

fun stopRingtone() {
    if (::ringtone.isInitialized && ringtone.isPlaying) {
        ringtone.stop()
    }
}