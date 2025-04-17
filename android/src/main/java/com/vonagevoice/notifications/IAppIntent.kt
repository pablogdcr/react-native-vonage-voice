package com.vonagevoice.notifications

import android.content.Intent

interface IAppIntent {
    fun getCallActivity(
        callId: String,
        from: String,
        phoneName: String,
        language: String,
        incomingCallImage: String?,
    ): Intent

    fun getMainActivity(): Intent
}
