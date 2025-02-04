package com.vonagevoice.telecom

import android.content.Context
import android.telecom.*
import android.os.Bundle
import androidx.core.content.getSystemService

class TelecomHelper(
    private val context: Context,
    private val callController: CallController
) {
    private val telecomManager = context.getSystemService<TelecomManager>()
    
    fun showIncomingCall(callId: String, from: String) {
        val extras = Bundle().apply {
            putString(TelecomManager.EXTRA_INCOMING_CALL_ADDRESS, from)
            putString("call_id", callId)
        }
        
        val builder = PhoneAccount.builder(
            PhoneAccountHandle(ComponentName(context, VonageConnectionService::class.java), callId),
            "Vonage Call"
        ).apply {
            setCapabilities(PhoneAccount.CAPABILITY_CALL_PROVIDER)
        }
        
        telecomManager?.registerPhoneAccount(builder.build())
        
        telecomManager?.addNewIncomingCall(
            PhoneAccountHandle(ComponentName(context, VonageConnectionService::class.java), callId),
            extras
        )
    }
    
    fun endCall(callId: String) {
        telecomManager?.endCall()
    }
} 