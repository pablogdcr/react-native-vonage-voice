package com.vonagevoice.deprecated

interface DeviceManager {
    fun getAvailableAudioDevices(): Result<List<AudioDevice>>

    fun setAudioDevice(deviceId: String): Result<Unit>

    fun enableSpeaker(): Result<Unit>

    fun disableSpeaker(): Result<Unit>
}

data class AudioDevice(val name: String)
