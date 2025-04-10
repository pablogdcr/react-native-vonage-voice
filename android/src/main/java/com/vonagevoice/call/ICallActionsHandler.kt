package com.vonagevoice.call

import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import com.vonage.voice.api.VoiceClient
import com.vonagevoice.auth.IVonageAuthenticationService
import com.vonagevoice.deprecated.TelecomHelper

interface ICallActionsHandler {
    suspend fun call(to: String)
    suspend fun answer(callId: String)

    suspend fun reject(callId: String)

    suspend fun hangup(callId: String)

    suspend fun mute(callId: String)

    suspend fun unmute(callId: String)

    suspend fun reconnectCall(legId: String)

    suspend fun enableNoiseSuppression(callId: String)

    suspend fun disableNoiseSuppression(callId: String)

    suspend fun processPushCallInvite(remoteMessageStr: String)
}

/**
 * Interface for app authentication, required to connect with vonage
 */
interface IAppAuthProvider {
    suspend fun getJwtToken(): String
}

interface IOpenCustomPhoneDialerUI {
    operator fun invoke(callId: String, from: String)
}

class CallActionsHandler(
    private val appAuthProvider: IAppAuthProvider,
    private val voiceClient: VoiceClient,
    private val vonageAuthenticationService: IVonageAuthenticationService,
    private val telecomHelper: TelecomHelper,
    private val context: Context,
    private val openCustomPhoneDialerUI: IOpenCustomPhoneDialerUI,
) : ICallActionsHandler {

    init {
        Log.d("CallActionsHandler", "init")
        observeIncomingCalls()
        observeLegStatus()
        observeHangups()
        observeSessionErrors()
    }

    private fun observeSessionErrors() {
        voiceClient.setSessionErrorListener { error ->
            // Handle session errors
        }
    }

    private fun observeHangups() {
        voiceClient.setOnCallHangupListener { callId, callQuality, reason ->
            // Handle hangups
        }
    }

    private fun observeLegStatus() {
        Log.d("CallActionsHandler", "callLegUpdates")
        voiceClient.setOnLegStatusUpdate { callId, legId, status ->
            // Call leg updates
            Log.d(
                "CallActionsHandler",
                "callLegUpdates setOnLegStatusUpdate callId: $callId, legId: $legId, status: $status"
            )
        }
    }

    enum class PhoneType {
        NativePhoneDialerUI, CustomPhoneDialerUI
    }

    private fun observeIncomingCalls() {
        Log.d("CallActionsHandler", "handleIncomingCalls")
        voiceClient.setCallInviteListener { callId, from, channelType ->
            // Handling incoming call invite
            Log.d(
                "CallActionsHandler",
                "handleIncomingCalls setCallInviteListener callId: $callId, from: $from, channelType: $channelType"
            )

            val phoneType: PhoneType = PhoneType.CustomPhoneDialerUI
            Log.d("CallActionsHandler", "handleIncomingCalls phoneType: $phoneType")
            when (phoneType) {
                PhoneType.NativePhoneDialerUI -> { // used for android auto
                    telecomHelper.showIncomingCall(callId, from)
                }

                PhoneType.CustomPhoneDialerUI -> {
                    Log.d("CallActionsHandler", "handleIncomingCalls startActivity")
                    openCustomPhoneDialerUI(callId, from)
                }
            }
        }
    }

    override suspend fun call(to: String) {
        voiceClient.serverCall(mapOf("to" to to))
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
    override suspend fun processPushCallInvite(remoteMessageStr: String) {
        Log.d("CallActionsHandler", "processPushCallInvite remoteMessageStr: $remoteMessageStr")
        Log.d(
            "CallActionsHandler",
            "processPushCallInvite requesting clientAppJwtToken to app to use Vonage"
        )
        val clientAppJwtToken: String = appAuthProvider.getJwtToken()
            ?: throw IllegalStateException("appAuthProvider returned a null jwt token")
        Log.d("CallActionsHandler", "processPushCallInvite clientAppJwtToken: $clientAppJwtToken")
        vonageAuthenticationService.login(clientAppJwtToken)
        Log.d("CallActionsHandler", "processPushCallInvite calling vonage processPushCallInvite")

        // This voiceClient::processPushCallInvite call triggers CallActionsHandler::observeIncomingCalls
        voiceClient.processPushCallInvite(remoteMessageStr)
    }
}
