package com.vonagevoice.call

import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import com.google.firebase.messaging.remoteMessage
import com.vonage.voice.api.VoiceClient
import com.vonagevoice.auth.IVonageAuthenticationService
import com.vonagevoice.deprecated.TelecomHelper

interface ICallActionsHandler {
    suspend fun answer(callId: String)

    suspend fun reject(callId: String)

    suspend fun hangup(callId: String)

    suspend fun mute(callId: String)

    suspend fun unmute(callId: String)

    suspend fun reconnectCall(legId: String)

    suspend fun enableNoiseSuppression(callId: String)

    suspend fun disableNoiseSuppression(callId: String)

    suspend fun processPushCallInvite(remoteMessage: RemoteMessage)
}

interface IAppAuthProvider {
    suspend fun getJwtToken(): String
}

class CallActionsHandler(
    private val appAuthProvider: IAppAuthProvider,
    private val voiceClient: VoiceClient,
    private val vonageAuthenticationService: IVonageAuthenticationService,
    private val telecomHelper: TelecomHelper
) : ICallActionsHandler {

    init {
        Log.d("CallActionsHandler", "init")
        handleIncomingCalls()
        callLegUpdates()
    }

    private fun callLegUpdates() {
        Log.d("CallActionsHandler", "callLegUpdates")
        voiceClient.setOnLegStatusUpdate { callId, legId, status ->
            // Call leg updates
            Log.d("CallActionsHandler", "callLegUpdates setOnLegStatusUpdate callId: $callId, legId: $legId, status: $status")
        }
    }

    private fun handleIncomingCalls() {
        Log.d("CallActionsHandler", "handleIncomingCalls")
        voiceClient.setCallInviteListener { callId, from, channelType ->
            // Handling incoming call invite
            Log.d("CallActionsHandler", "handleIncomingCalls setCallInviteListener callId: $callId, from: $from, channelType: $channelType")

            telecomHelper.showIncomingCall(callId, from)
        }
    }

    override suspend fun answer(callId: String) {
        Log.d("CallActionsHandler", "answer $callId")
        voiceClient.answer(callId)
    }

    override suspend fun reject(callId: String) {
        Log.d("CallActionsHandler", "reject $callId")
        voiceClient.reject(callId)
        /* callConnection.setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        callConnection.destroy()*/
    }

    override suspend fun hangup(callId: String) {
        Log.d("CallActionsHandler", "hangup $callId")
    
        voiceClient.hangup(callId)
    }

    override suspend fun mute(callId: String) {
        Log.d("CallActionsHandler", "mute $callId")
        voiceClient.mute(callId)
    }

    override suspend fun unmute(callId: String) {
        Log.d("CallActionsHandler", "unmute $callId")
        voiceClient.unmute(callId)
    }

    override suspend fun reconnectCall(legId: String) {
        Log.d("CallActionsHandler", "reconnectCall $legId")
        voiceClient.reconnectCall(legId)
    }

    override suspend fun enableNoiseSuppression(callId: String) {
        Log.d("CallActionsHandler", "enableNoiseSuppression")
        voiceClient.enableNoiseSuppression(callId)
    }

    override suspend fun disableNoiseSuppression(callId: String) {
        Log.d("CallActionsHandler", "disableNoiseSuppression")
        voiceClient.disableNoiseSuppression(callId)
    }

    /** Give the incoming push to the SDK to process */
    override suspend fun processPushCallInvite(remoteMessage: RemoteMessage) {
        Log.d("CallActionsHandler", "processPushCallInvite $remoteMessage")
        val jwt: String = appAuthProvider.getJwtToken()
        vonageAuthenticationService.login(jwt)
        voiceClient.processPushCallInvite(remoteMessage.data.toString())
    }
}
