package com.vonagevoice.js

import android.media.AudioDeviceInfo
import android.provider.CallLog.Calls
import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableNativeMap
import com.vonagevoice.audio.DeviceManager
import com.vonagevoice.call.Call
import com.vonagevoice.call.CallStatus
import kotlinx.coroutines.launch

class JSEventSender(
    private val eventEmitter: EventEmitter,
    private val deviceManager: DeviceManager,
) {

    suspend fun sendFirebasePushToken(pushToken: String) {
        Log.d("JSEventSender", "send event REGISTER: $pushToken")
        eventEmitter.sendEvent(
            Event.REGISTER,
            Arguments.createMap().apply { putString("token", pushToken) }
        )
    }

    suspend fun sendCallEvent(
        callId: String,
        status: CallStatus,
        outbound: Boolean,
        phoneNumber: String?,
        startedAt: Double?
    ) {
        Log.d(
            "JSEventSender",
            "sendCallEvent: callId=$callId, status=$status, outbound=$outbound, phoneNumber=$phoneNumber, startedAt=$startedAt"
        )

        val map =
            WritableNativeMap().apply {
                putString("id", callId)
                putString("status", status.toString())
                putBoolean("isOutbound", outbound)
                putString("phoneNumber", phoneNumber)
                putDouble("startedAt", startedAt ?: 0.0)
            }
        Log.d("JSEventSender", "sendCallEvent map: $map")
        eventEmitter.sendEvent(Event.CALL_EVENTS, map)
    }

    suspend fun sendMuteChanged(muted: Boolean) {
        val param = WritableNativeMap().apply { putBoolean("muted", muted) }
        eventEmitter.sendEvent(Event.MUTE_CHANGED, param)
    }

    suspend fun sendAudioRouteChanged(device: AudioDeviceInfo) {
        val map = WritableNativeMap().apply {
            putString("name", device.productName.toString())
            putString("id", device.id.toString())
            putString("type", deviceManager.mapDeviceType(device.type))
        }
        Log.d("JSEventSender", "sendAudioRouteChanged map: $map")
        eventEmitter.sendEvent(
            Event.AUDIO_ROUTE_CHANGED,
            WritableNativeMap().apply {
                putMap("device", map)
            }
        )
    }

    suspend fun sendAudioRouteChanged(
        name: String,
        id: String,
        type: String
    ) {
        val map = WritableNativeMap().apply {
            putString("name", name)
            putString("id", id)
            putString("type", type)
        }
        Log.d("JSEventSender", "sendAudioRouteChanged map: $map")
        eventEmitter.sendEvent(
            Event.AUDIO_ROUTE_CHANGED,
            WritableNativeMap().apply {
                putMap("device", map)
            }
        )
    }
}
