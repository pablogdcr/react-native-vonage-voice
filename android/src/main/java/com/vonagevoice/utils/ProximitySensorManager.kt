package com.vonagevoice.utils

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.PowerManager
import android.util.Log
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

class ProximitySensorManager(private val context: Context) : KoinComponent, SensorEventListener {
    private val sensorManager: SensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val powerManager: PowerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    private val proximitySensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_PROXIMITY)
    private var wakeLock: PowerManager.WakeLock? = null
    private var isScreenOff = false

    fun startListening() {
        proximitySensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
            Log.d("ProximitySensorManager", "Started listening to proximity sensor")
        } ?: run {
            Log.e("ProximitySensorManager", "Proximity sensor not available")
        }
    }

    fun stopListening() {
        sensorManager.unregisterListener(this)
        if (isScreenOff) {
            turnScreenOn()
        }
        Log.d("ProximitySensorManager", "Stopped listening to proximity sensor")
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type == Sensor.TYPE_PROXIMITY) {
            val distance = event.values[0]
            Log.d("ProximitySensorManager", "Proximity sensor value: $distance")
            if (distance < event.sensor.maximumRange) {
                // Object is near
                if (!isScreenOff) {
                    turnScreenOff()
                }
            } else {
                // Object is far
                if (isScreenOff) {
                    turnScreenOn()
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Not needed for proximity sensor
    }

    private fun turnScreenOff() {
        try {
            wakeLock = powerManager.newWakeLock(
                PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK,
                "VonageVoice:ProximityWakeLock"
            )
            wakeLock?.acquire(10*60*1000L /*10 minutes*/)
            isScreenOff = true
            Log.d("ProximitySensorManager", "Screen turned off")
        } catch (e: Exception) {
            Log.e("ProximitySensorManager", "Error turning screen off", e)
        }
    }

    private fun turnScreenOn() {
        try {
            wakeLock?.release()
            wakeLock = null
            isScreenOff = false
            Log.d("ProximitySensorManager", "Screen turned on")
        } catch (e: Exception) {
            Log.e("ProximitySensorManager", "Error turning screen on", e)
        }
    }
} 