package com.vonagevoice.call

import android.telecom.*
import android.util.Log
import androidx.core.net.toUri
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

class CallConnectionService : ConnectionService(), KoinComponent {

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?,
    ): Connection {
        Log.d("CallConnectionService", "onCreateIncomingConnection")
        val from = request?.extras?.getString("from") ?: throw IllegalArgumentException("CallConnectionService from is required")
        val callId = request.extras?.getString("call_id") ?: throw IllegalArgumentException("CallConnectionService call_id is required")
        return CallConnection("tel:$from".toUri(), callId).apply {
            setCallerDisplayName("TOTO", TelecomManager.PRESENTATION_ALLOWED)
            setAddress("SUPER ADRESSE".toUri(), TelecomManager.PRESENTATION_ALLOWED)
        }
    }

    override fun onCreateIncomingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?,
    ) {
        Log.d("CallConnectionService", "onCreateIncomingConnection")
        super.onCreateIncomingConnectionFailed(connectionManagerPhoneAccount, request)
    }
}
