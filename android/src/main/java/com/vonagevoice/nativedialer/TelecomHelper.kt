package com.vonagevoice.nativedialer

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Context.TELECOM_SERVICE
import android.content.Intent
import android.os.Bundle
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log
import androidx.annotation.RequiresPermission


class TelecomHelper(private val context: Context, private val appName: String) {

    private val telecomManager: TelecomManager =
        context.getSystemService(TELECOM_SERVICE) as TelecomManager

    private var phoneAccountHandle: PhoneAccountHandle
    private var phoneAccount: PhoneAccount

    init {
        Log.d("TelecomHelper", "init")
        val componentName = ComponentName(context.packageName!!, CallConnectionService::class.java.name)
        phoneAccountHandle = PhoneAccountHandle(componentName, appName)
        phoneAccount =
            PhoneAccount.builder(phoneAccountHandle, appName)
                .setCapabilities(PhoneAccount.CAPABILITY_CALL_PROVIDER)
                .build()
        telecomManager.registerPhoneAccount(phoneAccount)
    }

    /**
     * Required if using native dialer but useless if using custom ui
     * see PhoneType (NativePhoneDialerUI, CustomPhoneDialerUI)
     */
    fun enablePhoneAccount() {
        val intent = Intent()
        intent.setClassName(
            "com.android.server.telecom",
            "com.android.server.telecom.settings.EnableAccountPreferenceActivity"
        )
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
    }

    fun isPhoneAccountEnabled(): Boolean {
        val isEnabled = phoneAccount.isEnabled
        Log.d("TelecomHelper", "PhoneAccount isEnabled: $isEnabled")
        return isEnabled
    }

    private fun requestChangePhoneAccount() {
        val intent = Intent(TelecomManager.ACTION_CHANGE_PHONE_ACCOUNTS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
    }

    fun requestChangePhoneAccountIfRequired() {
        if (!isPhoneAccountEnabled()  && !isIncomingCallPermitted()) {
            requestChangePhoneAccount()
        }
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

        Log.d("TelecomHelper", "showIncomingCall addNewIncomingCall start")
        telecomManager.addNewIncomingCall(phoneAccountHandle, extras)
        Log.d("TelecomHelper", "showIncomingCall addNewIncomingCall done")
    }

    @RequiresPermission(Manifest.permission.ANSWER_PHONE_CALLS)
    fun endCall(callId: String) {
        Log.d("TelecomHelper", "endCall $callId")
        telecomManager.endCall()
    }
}
