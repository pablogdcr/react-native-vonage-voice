package com.vonagevoice.js

import android.provider.CallLog.Calls
import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableNativeMap
import com.vonagevoice.call.Call
import com.vonagevoice.call.CallStatus
import kotlinx.coroutines.launch

class JSEventSender(private val eventEmitter: EventEmitter) {

    suspend fun sendFirebasePushToken(pushToken: String) {
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
}
