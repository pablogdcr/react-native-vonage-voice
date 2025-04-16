package com.vonagevoice.audio

import android.content.Context
import android.media.AudioManager

fun getAvailableAudioOutputs(context: Context): List<AudioDevice> {
    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)

    return devices.map { device ->
        AudioDevice(
            name = device.productName?.toString() ?: "Unknown",
            id = device.id.toString(),
            type = mapDeviceType(device.type)
        )
    }
}
