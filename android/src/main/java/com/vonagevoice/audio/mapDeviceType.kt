package com.vonagevoice.audio

import android.media.AudioDeviceInfo

fun mapDeviceType(type: Int): String {
    return when (type) {
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "Speaker"
        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "Receiver"
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "Bluetooth"
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "Bluetooth"
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "Headphones"
        else -> "UNKNOWN (type: $type)"
    }
}
