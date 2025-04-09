package com.vonagevoice.deprecated

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.os.Bundle
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log
import androidx.annotation.RequiresPermission
import androidx.core.content.getSystemService
import com.vonagevoice.call.CallConnectionService

class TelecomHelper(context: Context) {

    private val telecomManager: TelecomManager =
        context.getSystemService<TelecomManager>() as TelecomManager

    private var phoneAccountHandle: PhoneAccountHandle
    private var phoneAccount: PhoneAccount

    init {
        Log.d("TelecomHelper", "init")
        val componentName = ComponentName(context, CallConnectionService::class.java)
        phoneAccountHandle = PhoneAccountHandle(componentName, "Vonage Voip Calling")
        phoneAccount =
            PhoneAccount.builder(phoneAccountHandle, "Vonage Voip Calling")
                .setCapabilities(PhoneAccount.CAPABILITY_CALL_PROVIDER)
                .build()
        telecomManager.registerPhoneAccount(phoneAccount)
    }

    fun isIncomingCallPermitted(): Boolean {
        val value = telecomManager.isIncomingCallPermitted(phoneAccountHandle)
        Log.d("TelecomHelper", "isIncomingCallPermitted $value")
        return value
    }

    fun showIncomingCall(callId: String, from: String) {
        Log.d("TelecomHelper", "showIncomingCall callId: $callId, from: $from")
        val extras =
            Bundle().apply {
                putString(TelecomManager.EXTRA_INCOMING_CALL_ADDRESS, from)
                putString("call_id", callId)
                putString("from", from)
            }

        telecomManager.addNewIncomingCall(phoneAccountHandle, extras)
    }

    @RequiresPermission(Manifest.permission.ANSWER_PHONE_CALLS)
    fun endCall(callId: String) {
        Log.d("TelecomHelper", "endCall $callId")
        telecomManager.endCall()
    }
}



