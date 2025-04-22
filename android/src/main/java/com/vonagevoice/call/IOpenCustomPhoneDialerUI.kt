package com.vonagevoice.call

interface IOpenCustomPhoneDialerUI {
    operator fun invoke(callId: String, from: String)
}
