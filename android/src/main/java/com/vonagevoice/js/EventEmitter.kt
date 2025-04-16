package com.vonagevoice.js

import android.util.Log
import com.facebook.react.ReactInstanceEventListener
import com.facebook.react.ReactInstanceManager
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import kotlinx.coroutines.delay

/**
 * A class responsible for emitting events to a React Native JavaScript context.
 * It waits for the React context to be initialized and sends events to it.
 *
 * @param reactInstanceManager The ReactInstanceManager used to manage the React Native context.
 */
class EventEmitter(
    reactInstanceManager: ReactInstanceManager,
) {

    private var reactContext: ReactContext? = null

    init {
        reactContext = reactInstanceManager.currentReactContext
        Log.d("EventEmitter", "init reactContext: $reactContext")
        reactInstanceManager.addReactInstanceEventListener(object : ReactInstanceEventListener {
            override fun onReactContextInitialized(context: ReactContext) {
                Log.d("EventEmitter", "onReactContextInitialized $context")
                reactContext = context
            }
        })
    }

    /**
     * Sends an event to the React Native JavaScript context.
     * The event name and any associated parameters are passed to the JavaScript side.
     *
     * The method waits for the React context to be initialized before emitting the event.
     *
     * @param event The event to send. It must be an instance of the `Event` class.
     * @param params The parameters to send with the event. This is optional and can be null.
     *
     * @throws IllegalStateException if the React context cannot be initialized within the expected time frame.
     */
    suspend fun sendEvent(event: Event, params: WritableMap? = null) {
        Log.d("EventEmitter", "sendEvent $event , eventName: ${event.value}, params: $params")
        val context = waitForReactContext()
        context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(event.value, params)
    }

    /**
     * Waits for the React context to be initialized. This method checks the state of `reactContext`
     * and delays if the context is not yet available.
     *
     * It will keep checking for the React context and delay the execution for 200ms intervals until
     * the context is initialized.
     *
     * @return The initialized `ReactContext`.
     *
     * @throws IllegalStateException if the React context is not initialized within a reasonable time.
     */
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
}
