package com.vonagevoice.audio

import android.media.AudioManager
import android.util.Log
import com.vonagevoice.js.EventEmitter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers

/**
 * The SpeakerController class manages the state of the speakerphone on the device.
 * It provides methods to enable or disable the speakerphone mode and emit events
 * regarding audio route changes.
 *
 * @param audioManager The AudioManager service.
 * @param eventEmitter The EventEmitter used to send events related to audio route changes.
 */
class SpeakerController(
    private val audioManager: AudioManager,
    private val eventEmitter: EventEmitter
) {
    private val scope = CoroutineScope(Dispatchers.IO)

    init {
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
    }

    /**
     * Enables the speakerphone (speakerphone mode on).
     * It changes the audio output to the speaker and sends an event to notify that the speaker has been enabled.
     */
    fun enableSpeaker() {
        Log.d("SpeakerController", "enableSpeaker")
        // This runs on the main thread, ensure it's run within a coroutine
        audioManager.isSpeakerphoneOn = true
    }

    /**
     * Disables the speakerphone (speakerphone mode off).
     * It changes the audio output to the default audio path and sends an event to notify that the speaker has been disabled.
     */
    fun disableSpeaker() {
        Log.d("SpeakerController", "disableSpeaker")
        // This runs on the main thread, ensure it's run within a coroutine
        audioManager.isSpeakerphoneOn = false
    }

    fun isSpeakerOn(): Boolean = audioManager.isSpeakerphoneOn
}
