package com.vonagevoice.nativedialer

import android.telecom.*
import android.util.Log
import androidx.core.net.toUri
import org.koin.core.component.KoinComponent

/**
 * Init in manifest with :
 *
 *     <service android:name="com.vonagevoice.nativedialer.CallConnectionService" android:permission="android.permission.BIND_TELECOM_CONNECTION_SERVICE" android:exported="false">
 *       <intent-filter>
 *         <action android:name="android.telecom.ConnectionService"/>
 *       </intent-filter>
 *     </service>
 */
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
