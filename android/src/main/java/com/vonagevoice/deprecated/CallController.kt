package com.vonagevoice.deprecated

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow

interface CallController {
    val calls: Flow<Call>
    val activeCalls: StateFlow<Map<String, Call>>

    fun updateSessionToken(token: String?, completion: ((Exception?) -> Unit)? = null)

    fun registerPushToken(token: String, callback: (Exception?, String?) -> Unit)

    fun unregisterPushToken(deviceId: String, callback: (Exception?) -> Unit)

    fun startOutboundCall(context: Map<String, String>, completion: (Exception?, String?) -> Unit)

    fun toggleNoiseSuppression(call: Call, isOn: Boolean)

    fun setAudioDevice(deviceId: String, completion: (Exception?) -> Unit)

    fun setRegion(region: String?)

    fun mute(callId: String, completion: (Exception?) -> Unit)

    fun unmute(callId: String, completion: (Exception?) -> Unit)

    fun sendDTMF(dtmf: String, completion: (Exception?) -> Unit)

    fun reconnectCall(callId: String, completion: (Exception?) -> Unit)

    fun saveDebugInfo(info: String)

    fun resetCallInfo()
}