package com.vonagevoice.call

import android.util.Log
import com.vonage.clientcore.core.api.LegStatus
import com.vonage.clientcore.core.api.VoiceInviteCancelReason
import com.vonage.voice.api.VoiceClient
import com.vonagevoice.audio.SpeakerController
import com.vonagevoice.js.JSEventSender
import com.vonagevoice.notifications.NotificationManager
import com.vonagevoice.storage.CallRepository
import com.vonagevoice.utils.nowDate
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class VonageEventsObserver(
    private val openCustomPhoneDialerUI: IOpenCustomPhoneDialerUI,
    private val callRepository: CallRepository,
    private val voiceClient: VoiceClient,
    private val notificationManager: NotificationManager,
    private val speakerController: SpeakerController,
    private val jsEventSender: JSEventSender,
) {

    private val scope = CoroutineScope(Dispatchers.IO)

    init {
        Log.d("VonageEventsObserver", "init")
    }

    fun startObserving() {
        Log.d("VonageEventsObserver", "startObserving")
        observeIncomingCalls()
        observeLegStatus()
        observeHangups()
        observeSessionErrors()
        observeCallInviteCancel()
        observeMute()
    }

    /**
     * Observes and handles mute actions on the voice client.
     *
     * Listens for mute/unmute events and logs the changes.
     */
    private fun observeMute() {
        voiceClient.setOnMutedListener { callId, legId, isMuted ->
            Log.d("VonageEventsObserver", "setOnMutedListener callId: $callId, isMuted: $isMuted")
            scope.launch {
                jsEventSender.sendMuteChanged(isMuted)
            }
        }
    }

    /**
     * Observes and handles the cancellation of a call invite.
     *
     * Cancels the inbound call notification when the call invite is canceled by the caller.
     */
    private fun observeCallInviteCancel() {
        voiceClient.setCallInviteCancelListener { callId, reason: VoiceInviteCancelReason ->
            Log.d(
                "VonageEventsObserver",
                "setCallInviteCancelListener callId: $callId, reason: $reason"
            )
            notificationManager.cancelInboundNotification()
            val storedCall = callRepository.getCall(callId)
                ?: throw IllegalStateException("Call $callId does not exist on storage")
            Log.d("VonageEventsObserver", "observeCallInviteCancel storedCall: $storedCall")

            val normalizedCallId = callId.lowercase()

            callRepository.removeHangedUpCall(normalizedCallId)

            scope.launch {
                jsEventSender.sendCallEvent(
                    callId = normalizedCallId,
                    status = CallStatus.COMPLETED,
                    phoneNumber = storedCall.phoneNumber,
                    startedAt = storedCall.startedAt,
                    outbound = storedCall is Call.Outbound
                )
            }
            notificationManager.cancelInProgressNotification()
            CallLifecycleManager.callback?.onCallEnded()
        }
    }

    private fun observeSessionErrors() {
        Log.d("VonageEventsObserver", "observeSessionErrors")
        voiceClient.setSessionErrorListener { error ->
            Log.d("VonageEventsObserver", "setSessionErrorListener $error")
            // Handle session errors
        }
    }

    /**
     * Observes and handles call hangups.
     *
     * Updates the call repository and cancels in-progress notifications when a call is hung up.
     */
    private fun observeHangups() {
        Log.d("VonageEventsObserver", "observeHangups")
        voiceClient.setOnCallHangupListener { callId, callQuality, reason ->
            val normalizedCallId = callId.lowercase()

            Log.d(
                "VonageEventsObserver",
                "observeHangups callId: $callId, callQuality: $callQuality, reason: $reason",
            )

            notificationManager.cancelInProgressNotification()

            scope.launch {
                val storedCall = callRepository.getCall(callId)

                Log.d("VonageEventsObserver", "observeHangups storedCall: $storedCall")
                Log.d("VonageEventsObserver", "observeHangups startedAt: ${storedCall?.startedAt}")

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
    }

    /**
     * Observes and handles updates to the call leg status.
     *
     * Updates the call repository and sends events based on the call leg status (e.g., ringing,
     * answered, completed).
     *
     * @param callId The ID of the call.
     * @param legId The ID of the leg (part) of the call.
     * @param status The new status of the call leg (e.g., completed, ringing, answered).
     */
    private fun observeLegStatus() {
        Log.d("VonageEventsObserver", "callLegUpdates")
        voiceClient.setOnLegStatusUpdate { callId, legId, status ->

            // Call leg updates
            Log.d(
                "VonageEventsObserver",
                "callLegUpdates setOnLegStatusUpdate callId: $callId, legId: $legId, status: $status",
            )

            val normalizedCallId = callId.lowercase()

            scope.launch {
                val storedCall = callRepository.getCall(callId)

                if (storedCall != null) {
                    when (status) {
                        LegStatus.completed -> {
                            Log.d("VonageEventsObserver", "observeLegStatus completed")
                            notificationManager.cancelInProgressNotification()
                            notificationManager.cancelInboundNotification()
                        }

                        LegStatus.ringing -> {
                            Log.d("VonageEventsObserver", "observeLegStatus ringing")
                            // no need to call callRepository.newInbound because it's already called in observeIncomingCalls setCallInviteListener
                        }

                        LegStatus.answered -> {
                            Log.d("VonageEventsObserver", "observeLegStatus answered")
                            // update status
                            // when status change
                            // and update startedAt when answered for inbound
                            if (!storedCall.isOutbound) {
                                speakerController.disableSpeaker()
                                callRepository.answerInboundCall(normalizedCallId)
                                notificationManager.cancelInboundNotification()
                            }
                        }
                    }

                    // updated variable because when answering call repository changes status and startedAt
                    val updatedStoredCall =
                        callRepository.getCall(callId)
                            ?: throw IllegalStateException("Call $callId does not exist on storage")

                    Log.d("VonageEventsObserver", "observeLegStatus updatedStoredCall: $updatedStoredCall")
                    Log.d("VonageEventsObserver", "observeLegStatus startedAt: ${updatedStoredCall.startedAt}")
                    Log.d("VonageEventsObserver", "observeLegStatus status: ${status.toString()}")

                    jsEventSender.sendCallEvent(
                        callId = normalizedCallId,
                        status = CallStatus.fromString(status.toString()),
                        phoneNumber = updatedStoredCall.phoneNumber,
                        startedAt = updatedStoredCall.startedAt,
                        outbound = updatedStoredCall is Call.Outbound
                    )
                }
            }
        }
    }

    /**
     * Observes and handles incoming call invites.
     *
     * Displays incoming calls and updates the UI to reflect the incoming call.
     *
     * @param callId The ID of the incoming call.
     * @param from The phone number of the caller.
     * @param channelType The channel type (e.g., voice, video).
     */
    private fun observeIncomingCalls() {
        Log.d("VonageEventsObserver", "observeIncomingCalls")
        voiceClient.setCallInviteListener { callId, from, channelType ->
            // Handling incoming call invite
            Log.d(
                "VonageEventsObserver",
                "observeIncomingCalls setCallInviteListener callId: $callId, from: $from, channelType: $channelType",
            )

            callRepository.newInbound(callId, from)

            val normalizedCallId = callId.lowercase()

            scope.launch {
                jsEventSender.sendCallEvent(
                    callId = normalizedCallId,
                    status = CallStatus.RINGING,
                    phoneNumber = from,
                    startedAt = nowDate(),
                    outbound = false
                )
            }

            val phoneType: PhoneType = PhoneType.CustomPhoneDialerUI
            Log.d("VonageEventsObserver", "handleIncomingCalls phoneType: $phoneType")
            when (phoneType) {
                PhoneType.NativePhoneDialerUI -> { // used for android auto
                    // telecomHelper.showIncomingCall(callId, from)
                }

                PhoneType.CustomPhoneDialerUI -> {
                    Log.d("VonageEventsObserver", "handleIncomingCalls startActivity")
                    openCustomPhoneDialerUI(callId, from)
                }
            }
        }
    }
}