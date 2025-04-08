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

class TelecomHelper(private val context: Context, private val callController: CallController) {

    private val telecomManager: TelecomManager =
        context.getSystemService<TelecomManager>() as TelecomManager

    private var phoneAccountHandle: PhoneAccountHandle

    init {
        Log.d("TelecomHelper", "init")
        val componentName = ComponentName(context, CallConnectionService::class.java)
        phoneAccountHandle = PhoneAccountHandle(componentName, "Vonage Voip Calling")
        val phoneAccount =
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
        Log.d("TelecomHelper", "showIncomingCall")
        val extras =
            Bundle().apply {
                putString(TelecomManager.EXTRA_INCOMING_CALL_ADDRESS, from)
                putString("call_id", callId)
                putString("from", from)
            }

        val builder =
            PhoneAccount.builder(
                    PhoneAccountHandle(
                        ComponentName(context, CallConnectionService::class.java),
                        callId,
                    ),
                    "Vonage Call",
                )
                .apply { setCapabilities(PhoneAccount.CAPABILITY_CALL_PROVIDER) }

        telecomManager.registerPhoneAccount(builder.build())

        telecomManager.addNewIncomingCall(
            PhoneAccountHandle(ComponentName(context, CallConnectionService::class.java), callId),
            extras,
        )
    }

    @RequiresPermission(Manifest.permission.ANSWER_PHONE_CALLS)
    fun endCall(callId: String) {
        Log.d("TelecomHelper", "endCall $callId")
        telecomManager.endCall()
    }
}



