package com.vonagevoice.audio

import android.content.Context
import android.media.AudioManager
import android.media.AudioDeviceInfo

fun getAvailableAudioOutputs(context: Context): List<AudioDevice> {
    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)

    return devices.mapNotNull { device ->
        when (device.type) {
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> {
                AudioDevice(
                    name = device.productName.toString(),
                    id = device.id.toString(),
                    type = mapDeviceType(device.type)
                )
            }
            else -> null
        }
    }
}
