package com.vonagevoice.event

import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule

class EventEmitter private constructor() {
    private var reactContext: ReactContext? = null

    fun setup(context: ReactContext) {
        reactContext = context
    }

    fun sendEvent(event: Event, params: WritableMap? = null) {
        reactContext?.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            ?.emit(event.value, params)
    }

    companion object {
        @Volatile
        private var instance: EventEmitter? = null

        fun getInstance(): EventEmitter {
            return instance ?: synchronized(this) {
                instance ?: EventEmitter().also { instance = it }
            }
        }
    }
} 