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
        val from = request?.extras?.getString("from")
        return CallConnection("tel:$from".toUri())
    }

    override fun onCreateIncomingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?,
    ) {
        Log.d("CallConnectionService", "onCreateIncomingConnection")
        super.onCreateIncomingConnectionFailed(connectionManagerPhoneAccount, request)
    }
}
