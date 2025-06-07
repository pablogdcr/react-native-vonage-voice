package com.vonagevoice.call

import com.facebook.react.bridge.ReadableMap
import com.vonage.clientcore.core.api.CallId

interface ICallActionsHandler {
    suspend fun call(to: String, customData: ReadableMap): CallId?

    suspend fun answer(callId: String)

    suspend fun reject(callId: String)

    suspend fun hangup(callId: String)

    suspend fun mute(callId: String)

    suspend fun unmute(callId: String)

    suspend fun reconnectCall(legId: String)

    suspend fun enableNoiseSuppression(callId: String)

    suspend fun disableNoiseSuppression(callId: String)

    suspend fun processPushCallInvite(remoteMessageStr: String)

    suspend fun sendDTMF(dtmf: String)
}

