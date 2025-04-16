package com.vonagevoice.deprecated

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.util.Log
import com.vonagevoice.speakers.mapDeviceType

data class AudioDevice(
    val name: String,
    val id: String,
    val type: String,
)

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

fun setAudioInputById(context: Context, deviceId: Int, onResult: (Boolean, String?) -> Unit) {

}


/*
class VonageDeviceManager(private val voiceClient: VoiceClient) : DeviceManager {
    override fun getAvailableAudioDevices(): Result<List<AudioDevice>> {
        return try {
            val devices = voiceClient.getAudioDevices()
            Result.success(devices)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override fun setAudioDevice(deviceId: String): Result<Unit> {
        return try {
            voiceClient.setAudioDevice(deviceId)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override fun enableSpeaker(): Result<Unit> {
        return try {
            voiceClient.enableSpeaker()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override fun disableSpeaker(): Result<Unit> {
        return try {
            voiceClient.disableSpeaker()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}


 */