package com.vonagevoice.js

import com.facebook.react.bridge.Arguments

class JSEventSender(private val eventEmitter: EventEmitter) {

    suspend fun sendFirebasePushToken(pushToken: String) {
        eventEmitter.sendEvent(
            Event.REGISTER,
            Arguments.createMap().apply { putString("token", pushToken) }
        )
    }
}
