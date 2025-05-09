package com.vonagevoice.notifications

import android.content.Intent

interface IAppIntent {
    fun getCallActivity(
        callId: String,
        from: String,
        phoneName: String?,
        incomingCallImage: String?,
        answerCall: Boolean,
    ): Intent

    fun getMainActivity(): Intent
}
