package com.vonagevoice.audio

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.util.Log
import com.facebook.react.bridge.WritableNativeMap
import com.vonagevoice.js.Event
import com.vonagevoice.js.EventEmitter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * The SpeakerController class manages the state of the speakerphone on the device.
 * It provides methods to enable or disable the speakerphone mode and emit events
 * regarding audio route changes.
 *
 * @param context The context used to obtain the AudioManager service.
 * @param eventEmitter The EventEmitter used to send events related to audio route changes.
 */
class SpeakerController(
    context: Context,
    private val eventEmitter: EventEmitter
) {
    val audioManager: AudioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

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

        scope.launch {
            val map = WritableNativeMap().apply {
                putMap("device", WritableNativeMap().apply {
                    putString("name", "Speaker")
                    putString("id", "idk")
                    putString("type", "Speaker")
                })
            }

            eventEmitter.sendEvent(
                Event.AUDIO_ROUTE_CHANGED,
                map
            )
        }
    }

    /**
     * Disables the speakerphone (speakerphone mode off).
     * It changes the audio output to the default audio path and sends an event to notify that the speaker has been disabled.
     */
    fun disableSpeaker() {
        Log.d("SpeakerController", "disableSpeaker")
        // This runs on the main thread, ensure it's run within a coroutine
        audioManager.isSpeakerphoneOn = false

        scope.launch {
            val map = WritableNativeMap().apply {
                putString("name", "Receiver")
                putString("id", "idk")
                putString("type", "Receiver")
            }

            eventEmitter.sendEvent(
                Event.AUDIO_ROUTE_CHANGED,
                map
            )
        }
    }

    fun isSpeakerOn(): Boolean = audioManager.isSpeakerphoneOn
}
