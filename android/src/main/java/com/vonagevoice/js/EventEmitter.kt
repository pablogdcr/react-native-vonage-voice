package com.vonagevoice.js

import android.util.Log
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule

class EventEmitter(private val reactContext: ReactContext) {

    fun sendEvent(event: Event, params: WritableMap? = null) {
        Log.d("EventEmitter", "sendEvent $event , params: $params")
        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(event.value, params)
    }
}
