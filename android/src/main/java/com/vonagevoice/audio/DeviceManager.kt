package com.vonagevoice.audio

import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.util.Log

class DeviceManager(
    private val audioManager: AudioManager,
    private val speakerController: SpeakerController
) {

    private fun getInputDeviceById(deviceId: Int): AudioDeviceInfo? {
        Log.d("DeviceManager", "getInputDeviceById deviceId: $deviceId")
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        val deviceFound = devices.find { it.id == deviceId }
        Log.d(
            "DeviceManager",
            "getInputDeviceById devices: ${devices.map { it.toAudioDevice() }}, deviceFound: $deviceFound"
        )
        return deviceFound
    }

    fun getAvailableAudioOutputs(): List<AudioDevice> {
        Log.d("DeviceManager", "getAvailableAudioOutputs")
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)

        Log.d("DeviceManager", "getAvailableAudioOutputs devices: $devices")
        return devices.mapNotNull { device ->
            device.toAudioDevice()
        }
    }

    private fun AudioDeviceInfo.toAudioDevice(): AudioDevice? {
        return when (type) {
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> {
                AudioDevice(
                    name = productName.toString(),
                    id = id.toString(),
                    type = mapDeviceType(type)
                )
            }

            else -> null
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
        val device = getInputDeviceById(deviceId)
            ?: throw IllegalStateException("DeviceManager Device with id $deviceId is not found")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.setCommunicationDevice(device)
        } else {
            // Best effort routing using legacy APIs
            when (device.type) {
                AudioDeviceInfo.TYPE_BLUETOOTH_SCO, AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                AudioDeviceInfo.TYPE_BLE_HEADSET, AudioDeviceInfo.TYPE_BLE_SPEAKER, AudioDeviceInfo.TYPE_BLE_BROADCAST,
                    -> {
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

                AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> {
                    speakerController.disableSpeaker()
                }

                else -> {
                    throw IllegalStateException("DeviceManager No direct routing possible for device type: ${device.type}")
                }
            }
        }
    }
}
