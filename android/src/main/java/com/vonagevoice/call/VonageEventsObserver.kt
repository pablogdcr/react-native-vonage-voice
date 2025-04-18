package com.vonagevoice.call

import android.util.Log
import com.facebook.react.bridge.WritableNativeMap
import com.vonage.clientcore.core.api.LegStatus
import com.vonage.clientcore.core.api.VoiceInviteCancelReason
import com.vonage.voice.api.VoiceClient
import com.vonagevoice.audio.SpeakerController
import com.vonagevoice.js.Event
import com.vonagevoice.js.EventEmitter
import com.vonagevoice.notifications.NotificationManager
import com.vonagevoice.storage.CallRepository
import com.vonagevoice.utils.nowDate
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class VonageEventsObserver(
    private val openCustomPhoneDialerUI: IOpenCustomPhoneDialerUI,
    private val eventEmitter: EventEmitter,
    private val callRepository: CallRepository,
    private val voiceClient: VoiceClient,
    private val notificationManager: NotificationManager,
    private val speakerController: SpeakerController,
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
        // observeAudioRoute()
    }

    /**
     * Observes and handles audio route changes.
     * Uses the system's audio focus listener to detect route changes.
     */
    // private fun observeAudioRoute() {
    //     Log.d("VonageEventsObserver", "observeAudioRoute")
    //     val audioDeviceCallback = object : AudioDeviceCallback() {
    //         override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
    //             super.onAudioDevicesAdded(addedDevices)
    //             Log.d("AudioOutputObserver", "Devices added: ${addedDevices.joinToString { it.productName.toString() }}")
    //             emitCurrentAudioRoute()
    //         }

    //         override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) {
    //             super.onAudioDevicesRemoved(removedDevices)
    //             Log.d("AudioOutputObserver", "Devices removed: ${removedDevices.joinToString { it.productName.toString() }}")
    //             emitCurrentAudioRoute()
    //         }
    //     }
    //     speakerController.audioManager.registerAudioDeviceCallback(audioDeviceCallback, Handler(Looper.getMainLooper()))    }

    // private fun emitCurrentAudioRoute() {
    //     val isSpeakerOn = speakerController.isSpeakerOn()
    //     val currentRoute = if (isSpeakerOn) "Speaker" else "Receiver"

    //     val map = WritableNativeMap().apply {
    //         putMap("device", WritableNativeMap().apply {
    //             putString("name", currentRoute)
    //             putString("id", "default")
    //             putString("type", currentRoute)
    //         })
    //     }

    //     Log.d("VonageEventsObserver", "Current audio route: $currentRoute")
    //     scope.launch {
    //         eventEmitter.sendEvent(Event.AUDIO_ROUTE_CHANGED, map)
    //     }
    // }

    /**
     * Observes and handles mute actions on the voice client.
     *
     * Listens for mute/unmute events and logs the changes.
     */
    private fun observeMute() {
        voiceClient.setOnMutedListener { callId, legId, isMuted ->
            Log.d("VonageEventsObserver", "setOnMutedListener callId: $callId, isMuted: $isMuted")
            val param = WritableNativeMap().apply { putBoolean("muted", isMuted) }
            scope.launch {
                eventEmitter.sendEvent(Event.MUTE_CHANGED, param)
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
            val normalizedCallId = callId.lowercase()

            callRepository.removeHangedUpCall(normalizedCallId)
            val map = WritableNativeMap().apply {
                putString("id", normalizedCallId)
                putString("status", CallStatus.COMPLETED.toString())
                putString("phoneNumber", storedCall.phoneNumber)
                putDouble("startedAt", storedCall.startedAt ?: 0.0)
            }
            scope.launch {
                Log.d(
                    "VonageEventsObserver",
                    "observeCallInviteCancel sendEvent callEvents with $map"
                )
                eventEmitter.sendEvent(Event.CALL_EVENTS, map)
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
            // Handle hangups

            val normalizedCallId = callId.lowercase()

            Log.d(
                "VonageEventsObserver",
                "observeHangups callId: $callId, callQuality: $callQuality, reason: $reason",
            )

            notificationManager.cancelInProgressNotification()

            scope.launch {
                val storedCall = callRepository.getCall(callId)

                val map =
                    WritableNativeMap().apply {
                        putString("id", normalizedCallId)
                        putString("status", CallStatus.COMPLETED.toString())
                        putBoolean("isOutbound", storedCall is Call.Outbound)
                        putString("phoneNumber", (storedCall)?.phoneNumber)
                        putDouble("startedAt", storedCall?.startedAt ?: 0.0)
                    }
                Log.d("VonageEventsObserver", "observeHangups sendEvent callEvents with $map")
                eventEmitter.sendEvent(Event.CALL_EVENTS, map)

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
                val storedCall =
                    callRepository.getCall(callId)
                        ?: throw IllegalStateException("Call $callId does not exist on storage")

                when (status) {
                    LegStatus.completed -> {
                        Log.d("VonageEventsObserver", "observeLegStatus completed")
                        notificationManager.cancelInProgressNotification()
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

                val map =
                    WritableNativeMap().apply {
                        putString("id", normalizedCallId)
                        putString("status", status.toString())
                        putBoolean("isOutbound", storedCall is Call.Outbound)
                        putString("phoneNumber", storedCall.phoneNumber)
                        putDouble("startedAt", storedCall.startedAt ?: 0.0)
                    }
                Log.d("VonageEventsObserver", "observeLegStatus sendEvent callEvents with $map")
                eventEmitter.sendEvent(Event.CALL_EVENTS, map)
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
                val map =
                    WritableNativeMap().apply {
                        putString("id", normalizedCallId)
                        putString("status", "ringing")
                        putBoolean("isOutbound", false)
                        putString("phoneNumber", from)
                        putDouble("startedAt", nowDate())
                    }

                Log.d("VonageEventsObserver", "observeLegStatus sendEvent callEvents with $map")
                eventEmitter.sendEvent(Event.CALL_EVENTS, map)
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