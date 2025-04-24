package com.vonagevoice.audio

import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.util.Log

class DeviceManager(
    private val audioManager: AudioManager,
    private val speakerController: SpeakerController
) {

    private fun getDeviceById(deviceId: Int): AudioDeviceInfo? {
        Log.d("DeviceManager", "getDeviceById deviceId: $deviceId")
        val deviceFound = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.availableCommunicationDevices.find { it.id == deviceId }
        } else {
            audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).find { it.id == deviceId }
        }
        Log.d(
            "DeviceManager",
            "getDeviceById deviceFound: ${deviceFound?.toAudioDevice()}"
        )
        return deviceFound
    }

    fun getAvailableAudioDevices(): List<AudioDevice> {
        Log.d("DeviceManager", "getAvailableAudioOutputs")
        val devices = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.availableCommunicationDevices.mapNotNull { device ->
                device.toAudioDevice()
            }
        } else {
            audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).mapNotNull { device ->
                device.toAudioDevice()
            }
        }

        Log.d("DeviceManager", "getAvailableAudioOutputs devices: $devices")
        return devices
    }

    private fun AudioDeviceInfo.toAudioDevice(): AudioDevice? {
        Log.d("DeviceManager", "toAudioDevice type: $type, name: ${productName}")
        return when (type) {
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
            AudioDeviceInfo.TYPE_BLE_SPEAKER,
            AudioDeviceInfo.TYPE_BLE_BROADCAST,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> {
                AudioDevice(
                    name = productName.toString(),
                    id = id.toString(),
                    type = mapDeviceType(type)
                )
            }
            else -> {
                Log.d("DeviceManager", "Unhandled device type: $type")
                null
            }
        }
    }

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

    fun setAudioDevice(deviceId: Int) {
        Log.d("DeviceManager", "setAudioDevice deviceId: $deviceId")
        val device = getDeviceById(deviceId)
            ?: throw IllegalStateException("DeviceManager Device with id $deviceId is not found")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Log.d("DeviceManager", "setCommunicationDevice device: ${device.toAudioDevice()}")
            audioManager.setCommunicationDevice(device)
        } else {
            Log.d("DeviceManager", "old API logic for setting device: $device")
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
