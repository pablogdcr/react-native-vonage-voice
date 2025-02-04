package com.vonagevoice.event

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.vonagevoice.model.Call

object EventPayload {
    fun createCallEventPayload(call: Call): WritableMap {
        return Arguments.createMap().apply {
            putString("id", call.callId)
            putString("status", call.status.toString())
            putBoolean("isOutbound", call.isOutbound)
            putString("phoneNumber", call.phoneNumber)
            putDouble("startedAt", (call as? Call.Inbound)?.startedAt?.toDouble() ?: 0.0)
        }
    }

    fun createRegisterEventPayload(token: String): WritableMap {
        return Arguments.createMap().apply {
            putString("token", token)
        }
    }

    fun createAudioRouteChangedPayload(
        name: String,
        id: String,
        type: String
    ): WritableMap {
        return Arguments.createMap().apply {
            putMap("device", Arguments.createMap().apply {
                putString("name", name)
                putString("id", id)
                putString("type", type)
            })
        }
    }

    fun createMuteChangedPayload(isMuted: Boolean): WritableMap {
        return Arguments.createMap().apply {
            putBoolean("muted", isMuted)
        }
    }
} 