package com.vonagevoice.call

import android.net.Uri
import android.telecom.Connection
import android.telecom.DisconnectCause
import android.telecom.TelecomManager
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

class CallConnection(private val from: Uri) : Connection(), KoinComponent {

    // TODO private var clientManager = ClientManager.getInstance(context)

    private val callActionsHandler: ICallActionsHandler by inject()
    private val scope = CoroutineScope(Dispatchers.IO)

    init {
        Log.d("CallConnection", "init")
        audioModeIsVoip = true
        connectionProperties = PROPERTY_SELF_MANAGED
        setAddress(from, TelecomManager.PRESENTATION_ALLOWED)
        setRinging()
    }

    override fun onDisconnect() {
        Log.d("CallConnection", "onDisconnect")
        // TODO clientManager.endCall(this)
        TODO("hangup")//  scope.launch { callActionsHandler.hangup() }
        setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        destroy()
    }

    override fun onAnswer() {
        Log.d("CallConnection", "onAnswer")
        setActive()
        // TODO clientManager.answerCall(this)
    }

    override fun onReject() {
        Log.d("CallConnection", "onReject")
        // TODO clientManager.rejectCall(this)
    }
}
