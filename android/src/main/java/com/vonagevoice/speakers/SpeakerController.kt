package com.vonagevoice.speakers

import android.content.Context
import android.media.AudioManager
import android.util.Log

class SpeakerController(private val context: Context) {

    private val audioManager: AudioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    init {
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
    }

    // Enable the speaker (speakerphone mode on)
    fun enableSpeaker() {
        Log.d("SpeakerController", "enableSpeaker")
        // This runs on the main thread, ensure it's run within a coroutine
        audioManager.isSpeakerphoneOn = true
    }

    // Disable the speaker (speakerphone mode off)
    fun disableSpeaker() {
        Log.d("SpeakerController", "disableSpeaker")
        // This runs on the main thread, ensure it's run within a coroutine
        audioManager.isSpeakerphoneOn = false
    }

    fun isSpeakerOn(): Boolean = audioManager.isSpeakerphoneOn
}
