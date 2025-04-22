package com.vonagevoice.utils

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

private var ringtone: Ringtone? = null
private var audioManager: AudioManager? = null
private var vibrator: Vibrator? = null

fun startRingtone(context: Context) {
    try {
        // Get AudioManager
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        // Set audio mode to RINGTONE to ensure proper audio routing
        audioManager?.mode = AudioManager.MODE_RINGTONE
        
        // Get the default ringtone
        val notification: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        ringtone = RingtoneManager.getRingtone(context, notification)
        
        // Configure audio attributes for ringtone
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setLegacyStreamType(AudioManager.STREAM_RING)
            .build()
        
        // Set audio attributes and play
        ringtone?.let {
            it.audioAttributes = audioAttributes
            it.play()
        }

        // Start vibration
        startVibration(context)
        
        Log.d("Ringtone", "Started ringing with volume: ${audioManager?.getStreamVolume(AudioManager.STREAM_RING)}")
    } catch (e: Exception) {
        Log.e("Ringtone", "Error starting ringtone", e)
    }
}

private fun startVibration(context: Context) {
    try {
        // Get Vibrator service
        vibrator = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        // Create vibration pattern (vibrate for 1 second, pause for 1 second, repeat)
        val pattern = longArrayOf(0, 1000, 1000)
        val amplitudes = intArrayOf(0, 255, 0) // 0 for pause, 255 for full vibration

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val vibrationEffect = VibrationEffect.createWaveform(pattern, amplitudes, 0)
            vibrator?.vibrate(vibrationEffect)
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(pattern, 0)
        }
    } catch (e: Exception) {
        Log.e("Ringtone", "Error starting vibration", e)
    }
}

fun stopRingtone() {
    try {
        ringtone?.stop()
        ringtone = null
        
        // Stop vibration
        vibrator?.cancel()
        vibrator = null
        
        // Reset audio mode to normal
        audioManager?.mode = AudioManager.MODE_NORMAL
        audioManager = null
        
        Log.d("Ringtone", "Stopped ringing")
    } catch (e: Exception) {
        Log.e("Ringtone", "Error stopping ringtone", e)
    }
}