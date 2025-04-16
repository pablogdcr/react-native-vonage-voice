package com.vonagevoice.call

import android.content.Context
import android.util.Log
import com.facebook.react.bridge.WritableNativeMap
import com.vonage.clientcore.core.api.LegStatus
import com.vonage.clientcore.core.api.VoiceInviteCancelReason
import com.vonage.voice.api.VoiceClient
import com.vonagevoice.auth.IVonageAuthenticationService
import com.vonagevoice.deprecated.Call
import com.vonagevoice.deprecated.CallStatus
import com.vonagevoice.deprecated.TelecomHelper
import com.vonagevoice.js.Event
import com.vonagevoice.js.EventEmitter
import com.vonagevoice.storage.CallRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

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

interface ICallListener {
    fun dispatchCallEvent(callEvent: Event)
}

class CallActionsHandler(
    private val appAuthProvider: IAppAuthProvider,

    private val vonageAuthenticationService: IVonageAuthenticationService,
    private val telecomHelper: TelecomHelper,
    private val context: Context,
    private val openCustomPhoneDialerUI: IOpenCustomPhoneDialerUI,
    private val eventEmitter: EventEmitter,
    private val callRepository: CallRepository,
    private val voiceClient: VoiceClient
) : ICallActionsHandler {
    private var callListener: ICallListener? = null
    private val scope = CoroutineScope(Dispatchers.IO)

    init {
        Log.d("CallActionsHandler", "init")
        observeIncomingCalls()
        observeCallInviteCancel()
        observeLegStatus()
        observeHangups()
        observeSessionErrors()
    }

    fun attachCallListener(callListener: ICallListener) {
        Log.d("CallActionsHandler", "attachCallListener")
        this.callListener = callListener
    }

    private fun observeSessionErrors() {
        Log.d("CallActionsHandler", "observeSessionErrors")
        voiceClient.setSessionErrorListener { error ->
            Log.d("CallActionsHandler", "setSessionErrorListener $error")
            // Handle session errors
        }
    }

    private fun observeHangups() {
        Log.d("CallActionsHandler", "observeHangups")
        voiceClient.setOnCallHangupListener { callId, callQuality, reason ->
            // Handle hangups

            Log.d(
                "CallActionsHandler",
                "observeHangups callId: $callId, callQuality: $callQuality, reason: $reason"
            )

            callRepository.removeHangedUpCall(callId)
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

            val storedCall = callRepository.getCall(callId)
                ?: throw IllegalStateException("Call $callId does not exist on storage")
            val normalizedCallId = callId.lowercase()

            when (status) {
                LegStatus.completed -> {
                    Log.d("CallActionsHandler", "observeLegStatus completed")

                    // TODO cancelCallNotification(context, CALL_IN_PROGRESS_NOTIFICATION_ID)
                    // when status is completed remove item from list
                    callRepository.removeHangedUpCall(callId)
                }

                LegStatus.ringing -> {
                    Log.d("CallActionsHandler", "observeLegStatus ringing")
                    callRepository.newInbound(callId, storedCall.phoneNumber)
                }

                LegStatus.answered -> {
                    Log.d("CallActionsHandler", "observeLegStatus answered")
                    // update status
                    // when status change
                    // and update startedAt when answered for inbound
                    callRepository.answerInboundCall(callId)

                    // TODO cancelCallNotification(context, CALL_INBOUND_NOTIFICATION_ID)
                }
            }

            scope.launch {
                val call = callRepository.getCall(callId)

                val map = WritableNativeMap().apply {
                    putString("id", normalizedCallId)
                    putString("status", status.name)
                    putBoolean("isOutbound", call is Call.Outbound)
                    putString("phoneNumber", (call ?: storedCall).phoneNumber)
                    putDouble("startedAt", ((call ?: storedCall).sstartedAt?.toDouble() ?: 0.0) / 1000)
                }
                Log.d("CallActionsHandler", "observeLegStatus sendEvent callEvents with $map")
                eventEmitter.sendEvent(Event.CALL_EVENTS, map)
            }
        }
    }

    enum class PhoneType {
        NativePhoneDialerUI, CustomPhoneDialerUI
    }

    private fun observeCallInviteCancel() {
        voiceClient.setCallInviteCancelListener { callId, reason: VoiceInviteCancelReason ->
            val storedCall = callRepository.getCall(callId)
                ?: throw IllegalStateException("Call $callId does not exist on storage")
            val normalizedCallId = callId.lowercase()

            callRepository.removeHangedUpCall(normalizedCallId)
            val map = WritableNativeMap().apply {
                putString("id", normalizedCallId)
                putString("status", CallStatus.COMPLETED.toString())
                putString("phoneNumber", storedCall.phoneNumber)
                putDouble("startedAt", (storedCall.sstartedAt?.toDouble() ?: 0.0) / 1000)
            }
            scope.launch {
                Log.d("CallActionsHandler", "observeLegStatus sendEvent callEvents with $map")
                eventEmitter.sendEvent(Event.CALL_EVENTS, map)
            }
        }
    }

    private fun observeIncomingCalls() {
        Log.d("CallActionsHandler", "handleIncomingCalls")
        voiceClient.setCallInviteListener { callId, from, channelType ->
            // Handling incoming call invite
            Log.d(
                "CallActionsHandler",
                "handleIncomingCalls setCallInviteListener callId: $callId, from: $from, channelType: $channelType"
            )

            callRepository.newInbound(callId, from)

            val normalizedCallId = callId.lowercase()
            scope.launch {
                val map = WritableNativeMap().apply {
                    putString("id", normalizedCallId)
                    putString("status", "ringing")
                    putBoolean("isOutbound", false)
                    putString("phoneNumber", from)
                    putDouble("startedAt", System.currentTimeMillis().toDouble() / 1000)
                }

                Log.d("CallActionsHandler", "observeLegStatus sendEvent callEvents with $map")
                eventEmitter.sendEvent(Event.CALL_EVENTS, map)
            }

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
        val param = WritableNativeMap().apply {
            putBoolean("muted", true)
        }
        eventEmitter.sendEvent(Event.MUTE_CHANGED, param)
    }

    override suspend fun unmute(callId: String) {
        Log.d("CallActionsHandler", "unmute $callId")
        voiceClient.unmute(callId)
        val param = WritableNativeMap().apply {
            putBoolean("muted", false)
        }
        eventEmitter.sendEvent(Event.MUTE_CHANGED, param)
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
