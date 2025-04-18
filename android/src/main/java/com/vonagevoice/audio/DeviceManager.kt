package com.vonagevoice.audio

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.util.Log

class DeviceManager(private val audioManager: AudioManager) {

    fun getInputDeviceById(deviceId: Int): AudioDeviceInfo? {
        val inputDevices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
        return inputDevices.firstOrNull { it.id == deviceId }
    }

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

    private fun mapDeviceType(type: Int): String {
        return when (type) {
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "Speaker"
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "Receiver"
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "Bluetooth"
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "Bluetooth"
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "Headphones"
            else -> "UNKNOWN (type: $type)"
        }
    }

    fun setAudioDevice(deviceId: Int) {
        val device = getInputDeviceById(deviceId) ?: throw IllegalStateException("Device with id $deviceId is not found")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.setCommunicationDevice(device)
        } else {
            // Best effort routing using legacy APIs
            when (device.type) {
                AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> {
                    audioManager.isBluetoothScoOn = true
                    audioManager.startBluetoothSco()
                    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                }
                AudioDeviceInfo.TYPE_WIRED_HEADSET -> {
                    audioManager.isWiredHeadsetOn = true
                    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                }
                AudioDeviceInfo.TYPE_BUILTIN_MIC -> {
                    audioManager.mode = AudioManager.MODE_NORMAL
                    audioManager.isMicrophoneMute = false
                }
                else -> {
                    throw IllegalStateException("No direct routing possible for device type: ${device.type}")
                }
            }
        }
    }
}
