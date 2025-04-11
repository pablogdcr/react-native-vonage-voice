package com.vonagevoice.js

import android.util.Log
import com.facebook.react.ReactInstanceEventListener
import com.facebook.react.ReactInstanceManager
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import kotlinx.coroutines.delay

class EventEmitter(
    reactInstanceManager: ReactInstanceManager,
    //private val context: Context
) {

    private var reactContext: ReactContext? = null

    init {
        reactContext = reactInstanceManager.currentReactContext
        Log.d("EventEmitter", "init $reactContext")
        reactInstanceManager.addReactInstanceEventListener(object : ReactInstanceEventListener {
            override fun onReactContextInitialized(context: ReactContext) {
                Log.d("EventEmitter", "onReactContextInitialized $context")
                reactContext = context
            }
        })
    }

    suspend fun sendEvent(event: Event, params: WritableMap? = null) {
        Log.d("EventEmitter", "sendEvent $event , eventName: ${event.value}, params: $params")
        val context = waitForReactContext()
        context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(event.value, params)
    }

    private suspend fun waitForReactContext(): ReactContext {
        Log.d("EventEmitter", "waitForReactContext")
        val startTime = System.currentTimeMillis()

        while (reactContext == null) {
            delay(200)
            val waited = System.currentTimeMillis() - startTime
            Log.d("EventEmitter", "waitForReactContext delay 200 — waited ${waited}ms")
        }

        val totalWaited = System.currentTimeMillis() - startTime
        Log.d("EventEmitter", "ReactContext initialized after ${totalWaited}ms")

        return requireNotNull(reactContext)
    }

    /*fun sendVoipTokenRegistered(token: String) {
        context.sendBroadcast(
            actionName = "voipTokenRegistered",
            extras = mapOf("token" to token)
        )
    }*/
}
