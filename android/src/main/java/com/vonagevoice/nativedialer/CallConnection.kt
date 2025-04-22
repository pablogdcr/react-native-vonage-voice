package com.vonagevoice.nativedialer

import android.net.Uri
import android.os.Bundle
import android.telecom.CallAudioState
import android.telecom.Connection
import android.telecom.DisconnectCause
import android.telecom.TelecomManager
import android.util.Log
import com.vonagevoice.call.ICallActionsHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

class CallConnection(from: Uri, private val callId: String) : Connection(), KoinComponent {

    companion object {
        private const val TAG = "CallConnection"
    }

    private val callActionsHandler: ICallActionsHandler by inject()
    private val scope = CoroutineScope(Dispatchers.IO)

    init {
        Log.d(TAG, "init")
        audioModeIsVoip = true
        connectionProperties = PROPERTY_SELF_MANAGED
        setAddress(from, TelecomManager.PRESENTATION_ALLOWED)
        setInitialized()
        setActive()
        setRinging()
    }

    override fun onShowIncomingCallUi() {
        super.onShowIncomingCallUi()
        Log.d(TAG, "onShowIncomingCallUi")
    }

    override fun onDisconnect() {
        Log.d(TAG, "onDisconnect")
        scope.launch { callActionsHandler.hangup(callId) }
        setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        destroy()
    }

    override fun onAnswer() {
        Log.d(TAG, "onAnswer")
        setActive()
        scope.launch { callActionsHandler.answer(callId) }
    }

    override fun onReject() {
        Log.d(TAG, "onReject")
        scope.launch { callActionsHandler.reject(callId) }
    }

    override fun onAbort() {
        Log.d(TAG, "onAbort()")
    }

    override fun onAnswer(videoState: Int) {
        Log.d(TAG, "onAnswer(videoState=$videoState)")
    }

    override fun onReject(rejectReason: Int) {
        Log.d(TAG, "onReject(rejectReason=$rejectReason)")
    }

    override fun onHold() {
        Log.d(TAG, "onHold()")
    }

    @Deprecated("Deprecated in Java")
    override fun onCallAudioStateChanged(state: CallAudioState) {
        Log.d(TAG, "onCallAudioStateChanged(state=$state)")
    }

    override fun onPlayDtmfTone(c: Char) {
        Log.d(TAG, "onPlayDtmfTone(c=$c)")
    }

    override fun onStopDtmfTone() {
        Log.d(TAG, "onStopDtmfTone()")
    }

    override fun onPostDialContinue(proceed: Boolean) {
        Log.d(TAG, "onPostDialContinue(proceed=$proceed)")
    }

    override fun onPullExternalCall() {
        Log.d(TAG, "onPullExternalCall()")
    }

    override fun onCallEvent(event: String, extras: Bundle) {
        Log.d(TAG, "onCallEvent(event=$event, extras=$extras)")
    }

    override fun onExtrasChanged(extras: Bundle) {
        Log.d(TAG, "onExtrasChanged(extras=$extras)")
    }

    override fun onStopRtt() {
        Log.d(TAG, "onStopRtt()")
    }

    override fun onStateChanged(state: Int) {
        Log.d(TAG, "onStateChanged(state=$state)")
    }
}
