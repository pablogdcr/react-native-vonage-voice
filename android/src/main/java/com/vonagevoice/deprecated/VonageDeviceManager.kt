package com.vonagevoice.deprecated

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