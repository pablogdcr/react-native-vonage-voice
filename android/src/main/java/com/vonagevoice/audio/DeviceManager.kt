package com.vonagevoice.audio

import android.annotation.SuppressLint
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.asExecutor

class DeviceManager(
    private val audioManager: AudioManager,
    private val speakerController: SpeakerController,
    private val context: Context,
) {
    private var audioFocusRequest: AudioFocusRequest? = null
    private var vibrator: Vibrator? = null
    private var ringtone: Ringtone? = null
    private var previousAudioMode: Int = AudioManager.MODE_NORMAL

    private fun getDeviceById(deviceId: Int): AudioDeviceInfo? {
        Log.d("DeviceManager", "getDeviceById deviceId: $deviceId")
        val deviceFound = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.availableCommunicationDevices.find { it.id == deviceId }
        } else {
            audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).find { it.id == deviceId }
        }
        Log.d(
            "DeviceManager", "getDeviceById deviceFound: ${deviceFound?.toAudioDevice()}"
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
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE, AudioDeviceInfo.TYPE_BLUETOOTH_A2DP, AudioDeviceInfo.TYPE_BLUETOOTH_SCO, AudioDeviceInfo.TYPE_BLE_HEADSET, AudioDeviceInfo.TYPE_BLE_SPEAKER, AudioDeviceInfo.TYPE_BLE_BROADCAST, AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> {
                AudioDevice(
                    name = productName.toString(), id = id.toString(), type = mapDeviceType(type)
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

    fun prepareAudioForCall() {
        Log.d("DeviceManager", "prepareAudioForCall called")

        // Set volume control for the call
        val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_VOICE_CALL)
        audioManager.setStreamVolume(
            AudioManager.STREAM_VOICE_CALL, currentVolume, 0
        )
        Log.d("DeviceManager", "Stream volume for VOICE_CALL set to $currentVolume")

        // Ensure we are in communication mode
        if (audioManager.mode != AudioManager.MODE_IN_COMMUNICATION) {
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
            Log.d("DeviceManager", "Audio mode set to MODE_IN_COMMUNICATION")
        }

        // Detect if Bluetooth is connected or already routing audio
        val isBluetoothScoOn = audioManager.isBluetoothScoOn || audioManager.isBluetoothA2dpOn
        val isBluetoothConnected = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            .any { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO || it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP }

        if (!isBluetoothScoOn && !isBluetoothConnected) {
            Log.d("DeviceManager", "No Bluetooth device detected, disabling speaker")
            speakerController.disableSpeaker()
        } else {
            Log.d("DeviceManager", "Bluetooth audio already active, leaving routing unchanged")
        }
    }

    fun stopOtherAppsDoingAudio() {
        val focusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
            Log.d("DeviceManager", "Focus changed: $focusChange")
            // react here if we need to do something
        }

        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE) // or USAGE_NOTIFICATION
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()

        audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            .setAudioAttributes(attributes).setAcceptsDelayedFocusGain(false)
            .setOnAudioFocusChangeListener(focusChangeListener).build()

        val result = audioManager.requestAudioFocus(audioFocusRequest!!)

        if (result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            Log.d("DeviceManager", "Audio focus granted, other music apps will pause.")
        } else {
            Log.e("DeviceManager", "Could not gain audio focus.")
        }
    }

    // Call after ringtone
    fun releaseAudioFocus() {
        Log.d("DeviceManager", "releaseAudioFocus audioFocusRequest: $audioFocusRequest")
        audioFocusRequest?.let {
            audioManager.abandonAudioFocusRequest(it)
        }
    }

    @SuppressLint("MissingPermission")
    fun startRingtoneSong() {

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val interruptionFilter = notificationManager.currentInterruptionFilter
        if (interruptionFilter == NotificationManager.INTERRUPTION_FILTER_NONE) {
            Log.e("DeviceManager", "Do Not Disturb enabled — ringtone may not play")
        }

        try {
            // 1. Get default ringtone URI
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            if (uri == null) {
                Log.e("DeviceManager", "No ringtone URI found")
                return
            }

            // 2. Check volume
            if (audioManager.getStreamVolume(AudioManager.STREAM_RING) == 0) {
                Log.e("DeviceManager", "STREAM_RING volume is zero, ringtone won't be heard")
                return
            }

            // 3. Set audio mode to ringtone
            previousAudioMode = audioManager.mode
            audioManager.mode = AudioManager.MODE_RINGTONE

            // 4. Get ringtone
            val ringtoneInstance = RingtoneManager.getRingtone(context, uri)
            if (ringtoneInstance == null) {
                Log.e("DeviceManager", "Failed to get Ringtone instance")
                return
            }

            // 5. Optional: request audio focus
            val result = audioManager.requestAudioFocus(
                null,
                AudioManager.STREAM_RING,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
            )
            if (result != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                Log.e("DeviceManager", "Could not get audio focus for ringtone")
            }

            // 6. Play
            ringtoneInstance.streamType = AudioManager.STREAM_RING
            ringtoneInstance.play()
            ringtone = ringtoneInstance

            Log.d("DeviceManager", "Ringtone started")
        } catch (e: Exception) {
            Log.e("DeviceManager", "Error starting ringtone", e)
        }
    }

    fun stopRingtoneSong() {
        try {
            ringtone?.let {
                if (it.isPlaying) {
                    it.stop()
                    Log.d("DeviceManager", "Ringtone stopped")
                }
            }

            ringtone = null
        } catch (e: Exception) {
            Log.e("DeviceManager", "Error stopping ringtone", e)
        }
    }

    @SuppressLint("MissingPermission")
    fun startRingtoneVibration() {
        Log.d("DeviceManager", "startRingtoneVibration")
        try {
            // Get Vibrator service
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager =
                    context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            // Create vibration pattern (vibrate for 1 second, pause for 1 second, repeat)
            val pattern = longArrayOf(0, 1000, 1000)
            val amplitudes = intArrayOf(0, 255, 0) // 0 for pause, 255 for full vibration

            val vibrationEffect = VibrationEffect.createWaveform(pattern, amplitudes, 0)
            vibrator?.vibrate(vibrationEffect)
        } catch (e: Exception) {
            Log.e("DeviceManager", "Error starting vibration", e)
        }
    }

    @SuppressLint("MissingPermission")
    fun stopRingtoneVibration() {
        // Stop vibration
        vibrator?.cancel()
        vibrator = null
    }

    fun onCommunicationDeviceChangedListener(callback: (AudioDeviceInfo?) -> Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.addOnCommunicationDeviceChangedListener(Dispatchers.IO.asExecutor()) { device ->
                callback(device)
            }
        } else {
            Log.e("DeviceManager", "Cannot do onCommunicationDeviceChangedListener")
        }
    }
}
