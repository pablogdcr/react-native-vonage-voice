package com.vonagevoice.deprecated
import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager

class AudioDeviceManager(private val context: Context) {
    private val audioManager: AudioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    fun getAvailableDevices(): List<AudioDeviceInfo> {
        //return audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).toList()
        TODO()
    }

    fun setPreferredDevice(deviceId: String): Boolean {
        /*val device = getAvailableDevices().find { it.id.toString() == deviceId }
        return device?.let { audioManager.setPreferredDevice(it) } ?: false*/
        TODO()
    }

    fun resetPreferredDevice() {
        //audioManager.setPreferredDevice(null)
        TODO()
    }
}