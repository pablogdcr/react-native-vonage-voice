package com.vonagevoice.call

import android.content.Context
import android.util.Log
import com.facebook.react.bridge.Dynamic
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.ReadableType
import com.vonage.android_core.VGError
import com.vonage.voice.api.CallId
import com.vonage.voice.api.VoiceClient
import com.vonagevoice.auth.IAppAuthProvider
import com.vonagevoice.auth.IVonageAuthenticationService
import com.vonagevoice.js.JSEventSender
import com.vonagevoice.service.CallService
import com.vonagevoice.service.IncomingCallService
import com.vonagevoice.storage.CallRepository
import com.vonagevoice.utils.retryWithExponentialBackoff
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Handles various call actions such as answering, rejecting, muting, and processing incoming call
 * invites.
 *
 * This class observes incoming calls, call leg status, session errors, hangups, and mute/unmute
 * actions. It provides the necessary functionality to interact with the Vonage Voice Client and
 * update the UI accordingly.
 *
 * It also processes push call invites, enabling smooth handling of incoming calls and their states.
 * The class leverages coroutines for asynchronous operations and uses Koin for dependency injection
 * to manage its dependencies like authentication, voice client, and notifications.
 */
class CallActionsHandler(
    private val appAuthProvider: IAppAuthProvider,
    private val vonageAuthenticationService: IVonageAuthenticationService,
    private val callRepository: CallRepository,
    private val voiceClient: VoiceClient,
    private val jsEventSender: JSEventSender,
    private val inboundCallNotifier: InboundCallNotifier,
    private val context: Context,
    vonageEventsObserver: VonageEventsObserver
) : ICallActionsHandler {
    private var processingServerCall = false
    private val scope = CoroutineScope(Dispatchers.IO)

    init {
        Log.d("CallActionsHandler", "init")
        vonageEventsObserver.startObserving()
    }

    /**
     * Makes a call to a specified phone number.
     *
     * @param to The phone number to call.
     */
    override suspend fun call(to: String, customData: ReadableMap): CallId? {
        Log.d("CallActionsHandler", "call to: $to")

        if (processingServerCall) {
            throw IllegalStateException("A server call is already being processed")
        }

        processingServerCall = true

        val callData = mutableMapOf<String, Any>("to" to to)

        customData.let {
            val iterator = it.keySetIterator()
            while (iterator.hasNextKey()) {
                val key = iterator.nextKey()
                when (val value = it.getDynamic(key)) {
                    is Dynamic -> {
                        when (value.type) {
                            ReadableType.String -> callData[key] = value.asString()
                            ReadableType.Number -> callData[key] = value
                            ReadableType.Boolean -> callData[key] = value.asBoolean()
                            ReadableType.Map -> callData[key] = value.asMap().toString()
                            // Add support for arrays if needed
                            else -> {} // unsupported types can be skipped or handled
                        }
                    }
                }
            }
        }

        Log.d("CallActionsHandler", "call to: $to, with custom data: $callData")
        val callId = retryWithExponentialBackoff {
            val clientAppJwtToken: String = appAuthProvider.getJwtToken()
            vonageAuthenticationService.login(clientAppJwtToken)
            val callId = try {
                val callId = voiceClient.serverCall(callData as Map<String, String>)
                processingServerCall = false
                callRepository.newOutbound(callId = callId, phoneNumber = to)
                Log.d("CallActionsHandler", "call to: $to, callId: $callId")
                callId
            } catch (e: Exception) {
                Log.e("CallActionsHandler", "serverCall failed ${e.message}", e)
                null
            }

            callId
        }
        return callId?.let {
            val normalizedCallId = callId.lowercase()
            IncomingCallService.stop(context)
            CallService.start(context, normalizedCallId)
            normalizedCallId
        }
    }

    /**
     * Answers an incoming call.
     *
     * @param callId The ID of the incoming call.
     */
    override suspend fun answer(callId: String) {
        Log.d("CallActionsHandler", "answer $callId")
        val normalizedCallId = callId.lowercase()
        IncomingCallService.stop(context)
        CallService.start(context, normalizedCallId)
        inboundCallNotifier.stopRingtoneAndInboundNotification()

        val storedCall = callRepository.getCall(callId)
        Log.d("CallActionsHandler", "answer storedCall: $storedCall")

        if (storedCall?.status == CallStatus.RINGING) {
            try {
                Log.d("CallActionsHandler", "answer voiceClient.answer")
                voiceClient.answer(normalizedCallId)
            } catch (e: VGError) {
                Log.e("CallActionsHandler", "answer failed ${e.message}", e)
                throw e
            }
        } else {
            Log.e(
                "CallActionsHandler",
                "answer storedCall is not in ringing status",
                IllegalStateException("answer storedCall is not in ringing status")
            )
        }
    }

    /**
     * Rejects an incoming call.
     *
     * @param callId The ID of the incoming call.
     */
    override suspend fun reject(callId: String) {
        Log.d("CallActionsHandler", "reject $callId")
        val normalizedCallId = callId.lowercase()

        try {
            voiceClient.reject(normalizedCallId)
        } catch (e: VGError) {
            Log.e("CallActionsHandler", "reject failed ${e.message}", e)
        }
        IncomingCallService.stop(context)
        inboundCallNotifier.stopRingtoneAndInboundNotification()

        scope.launch {
            val storedCall = callRepository.getCall(callId)
            jsEventSender.sendCallEvent(
                callId = normalizedCallId,
                status = CallStatus.COMPLETED,
                phoneNumber = storedCall?.phoneNumber,
                startedAt = storedCall?.startedAt,
                outbound = storedCall is Call.Outbound
            )
            callRepository.removeHangedUpCall(callId)
        }
        CallLifecycleManager.callback?.onCallEnded()
    }

    /**
     * Hangs up an ongoing call.
     *
     * @param callId The ID of the ongoing call.
     */
    override suspend fun hangup(callId: String) {
        Log.d("CallActionsHandler", "hangup $callId")
        CallService.stop(context)
        try {
            voiceClient.hangup(callId)
        } catch (e: Exception) {
            Log.e("CallActionsHandler", "hangup failed ${e.message}", e)
        }
    }

    /**
     * Mutes an ongoing call.
     *
     * @param callId The ID of the ongoing call.
     */
    override suspend fun mute(callId: String) {
        Log.d("CallActionsHandler", "mute $callId")

        try {
            voiceClient.mute(callId)
        } catch (e: VGError) {
            Log.e("CallActionsHandler", "mute failed ${e.message}", e)
        }
    }

    /**
     * Unmutes an ongoing call.
     *
     * @param callId The ID of the ongoing call.
     */
    override suspend fun unmute(callId: String) {
        Log.d("CallActionsHandler", "unmute $callId")

        try {
            voiceClient.unmute(callId)
        } catch (e: VGError) {
            Log.e("CallActionsHandler", "unmute failed ${e.message}", e)
        }
    }

    override suspend fun reconnectCall(legId: String) {
        Log.d("CallActionsHandler", "reconnectCall $legId")

        try {
            voiceClient.reconnectCall(legId)
        } catch (e: VGError) {
            Log.e("CallActionsHandler", "reconnectCall failed ${e.message}", e)
        }
    }

    override suspend fun enableNoiseSuppression(callId: String) {
        Log.d("CallActionsHandler", "enableNoiseSuppression")

        try {
            voiceClient.enableNoiseSuppression(callId)
        } catch (e: VGError) {
            Log.e("CallActionsHandler", "enableNoiseSuppression failed ${e.message}", e)
        }
    }

    override suspend fun disableNoiseSuppression(callId: String) {
        Log.d("CallActionsHandler", "disableNoiseSuppression")
        try {
            voiceClient.disableNoiseSuppression(callId)
        } catch (e: VGError) {
            Log.e("CallActionsHandler", "disableNoiseSuppression failed ${e.message}", e)
        }
    }

    /** Give the incoming push to the SDK to process */
    override suspend fun processPushCallInvite(remoteMessageStr: String) {
        Log.d("CallActionsHandler", "processPushCallInvite remoteMessageStr: $remoteMessageStr")
        Log.d(
            "CallActionsHandler",
            "processPushCallInvite requesting clientAppJwtToken to app to use Vonage",
        )
        val clientAppJwtToken: String = appAuthProvider.getJwtToken()
        Log.d("CallActionsHandler", "processPushCallInvite clientAppJwtToken: $clientAppJwtToken")
        vonageAuthenticationService.login(clientAppJwtToken)
        Log.d("CallActionsHandler", "processPushCallInvite calling vonage processPushCallInvite")

        // This voiceClient::processPushCallInvite call triggers
        // CallActionsHandler::observeIncomingCalls

        try {
            voiceClient.processPushCallInvite(remoteMessageStr)
        } catch (e: VGError) {
            Log.e("CallActionsHandler", "processPushCallInvite failed ${e.message}", e)
        }
    }

    override suspend fun sendDTMF(dtmf: String) {
        val call = callRepository.getActiveCall()
            ?: throw IllegalStateException("sendDTMF called while no active call found")
        Log.d("CallActionsHandler", "sendDTMF $dtmf, found call: $call")

        try {
            voiceClient.sendDTMF(callId = call.id, digits = dtmf)
        } catch (e: VGError) {
            Log.e("CallActionsHandler", "sendDTMF failed ${e.message}", e)
        }
    }
}
