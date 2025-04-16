package com.vonagevoice.speakers

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

class SpeakerController(
    private val context: Context,
    private val eventEmitter: EventEmitter
) {

    private val audioManager: AudioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private val scope = CoroutineScope(Dispatchers.IO)

    init {
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
    }

    // Enable the speaker (speakerphone mode on)
    fun enableSpeaker() {
        Log.d("SpeakerController", "enableSpeaker")
        // This runs on the main thread, ensure it's run within a coroutine
        audioManager.isSpeakerphoneOn = true

        scope.launch {
            val map = WritableNativeMap().apply {
                putString("name", "speaker enabled")
                putString("id", "idk")
                putString("type", "speaker_enabled")
            }

            eventEmitter.sendEvent(
                Event.AUDIO_ROUTE_CHANGED,
                map
            )
        }
    }

    // Disable the speaker (speakerphone mode off)
    fun disableSpeaker() {
        Log.d("SpeakerController", "disableSpeaker")
        // This runs on the main thread, ensure it's run within a coroutine
        audioManager.isSpeakerphoneOn = false

        scope.launch {
            val map = WritableNativeMap().apply {
                putString("name", "speaker disabled")
                putString("id", "idk")
                putString("type", "speaker_disabled")
            }

            eventEmitter.sendEvent(
                Event.AUDIO_ROUTE_CHANGED,
                map
            )
        }
    }

    fun isSpeakerOn(): Boolean = audioManager.isSpeakerphoneOn
}

fun mapDeviceType(type: Int): String {
    return when (type) {
        AudioDeviceInfo.TYPE_BUILTIN_MIC -> "BUILTIN_MIC"
        AudioDeviceInfo.TYPE_WIRED_HEADSET -> "WIRED_HEADSET"
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "BLUETOOTH"
        // ajoute d'autres types si besoin
        else -> "UNKNOWN $type"
    }
}
