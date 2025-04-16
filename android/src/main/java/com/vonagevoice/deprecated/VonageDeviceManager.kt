package com.vonagevoice.deprecated

import android.content.Context
import android.media.AudioManager
import android.os.Build
import com.vonagevoice.speakers.mapDeviceType

data class AudioDevice(
    val name: String,
    val id: String,
    val type: String,
)

fun getAvailableAudioInputs(context: Context): List<AudioDevice> {
    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    val devices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)

    return devices.map { device ->
        AudioDevice(
            name = device.productName?.toString() ?: "Unknown",
            id = device.id.toString(),
            type = mapDeviceType(device.type)
        )
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