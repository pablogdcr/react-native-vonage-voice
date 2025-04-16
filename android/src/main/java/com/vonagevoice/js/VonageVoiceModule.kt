package com.vonagevoice.js

import android.content.Context
import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.vonagevoice.auth.IVonageAuthenticationService
import com.vonagevoice.call.ICallActionsHandler
import com.vonagevoice.call.VonagePushMessageService
import com.vonagevoice.deprecated.getAvailableAudioInputs
import com.vonagevoice.speakers.SpeakerController
import com.vonagevoice.storage.VonageStorage
import com.vonagevoice.utils.tryBlocking
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

class VonageVoiceModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext), KoinComponent {

    private val vonageAuthenticationService: IVonageAuthenticationService by inject()
    private val speakerController: SpeakerController by inject()
    private val callActionsHandler: ICallActionsHandler by inject()
    private val eventEmitter: EventEmitter by inject()
    private val storage: VonageStorage by inject()
    private val scope = CoroutineScope(Dispatchers.Main)
    private val context: Context by inject()

    /*
        private val callManager: CallActionsHandler by inject()
        private val deviceManager: DeviceManager by inject()
    */
    override fun getName(): String {
        return "VonageVoiceModule"
    }

    override fun getConstants(): MutableMap<String, Any> {
        return hashMapOf()
    }

    @ReactMethod
    fun saveDebugAdditionalInfo(info: String) {
        Log.d("VonageVoiceModule", "saveDebugAdditionalInfo $info")
    }

    @ReactMethod
    fun setRegion(region: String) {
        Log.d("VonageVoiceModule", "setRegion $region")
        vonageAuthenticationService.setRegion(region)
    }

    @ReactMethod
    fun login(jwt: String, promise: Promise) {
        Log.d("VonageVoiceModule", "login $jwt")
        scope.launch { promise.tryBlocking { vonageAuthenticationService.login(jwt) } }
    }

    @ReactMethod
    fun logout(promise: Promise) {
        Log.d("VonageVoiceModule", "logout")
        scope.launch { promise.tryBlocking { vonageAuthenticationService.logout() } }
    }

    /**
     * isSandbox looks used only for iOS, we ignore it here
     * This method is triggered by react native when event register is sent by event emitter
     * @param token = push token from firebase
     */
    @ReactMethod
    fun registerVonageVoipToken(token: String, isSandbox: Boolean, promise: Promise) {
        Log.d("VonageVoiceModule", "registerVonageVoipToken $token")
        scope.launch {
            promise.tryBlocking {
                vonageAuthenticationService.registerVonageVoipToken(newTokenFirebase = token)
            }
        }
    }

    @ReactMethod
    fun unregisterDeviceTokens(deviceId: String, promise: Promise) {
        Log.d("VonageVoiceModule", "unregisterDeviceTokens $deviceId")
    }

    @ReactMethod
    fun answerCall(callId: String, promise: Promise) {
        val normalizedCallId = callId.lowercase()
        Log.d("VonageVoiceModule", "answerCall $normalizedCallId")
        scope.launch { callActionsHandler.answer(normalizedCallId) }
    }

    @ReactMethod
    fun rejectCall(callId: String, promise: Promise) {
        val normalizedCallId = callId.lowercase()
        Log.d("VonageVoiceModule", "rejectCall $normalizedCallId")
        scope.launch { promise.tryBlocking { callActionsHandler.reject(normalizedCallId) } }
    }

    @ReactMethod
    fun hangup(callId: String, promise: Promise) {
        val normalizedCallId = callId.lowercase()
        Log.d("VonageVoiceModule", "hangup $normalizedCallId")
        scope.launch { promise.tryBlocking { callActionsHandler.hangup(normalizedCallId) } }
    }

    @ReactMethod
    fun serverCall(to: String, customData: ReadableMap, promise: Promise) {
        Log.d("VonageVoiceModule", "serverCall to: $to, customData: $customData")
        scope.launch { promise.tryBlocking { callActionsHandler.call(to) } }
    }

    @ReactMethod
    fun sendDTMF(dtmf: String, promise: Promise) {
        Log.d("VonageVoiceModule", "sendDTMF $dtmf")
    }

    @ReactMethod
    fun reconnectCall(callId: String, promise: Promise) {
        val normalizedCallId = callId.lowercase()
        Log.d("VonageVoiceModule", "reconnectCall $normalizedCallId")
        scope.launch { promise.tryBlocking { callActionsHandler.reconnectCall(normalizedCallId) } }
    }

    @ReactMethod
    fun getAvailableAudioDevices(promise: Promise) {
        Log.d("VonageVoiceModule", "getAvailableAudioDevices")

        try {
            val inputs = getAvailableAudioInputs(reactApplicationContext)
            val mapped = inputs.map {
                mapOf(
                    "name" to it.name,
                    "id" to it.id,
                    "type" to it.type
                )
            }
            promise.resolve(mapped)
        } catch (e: Exception) {
            promise.reject("AUDIO_INPUT_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun setAudioDevice(deviceId: String, promise: Promise) {
        Log.d("VonageVoiceModule", "setAudioDevice $deviceId")
    }


    @ReactMethod
    fun addListener(eventName: String) {
        Log.d("VonageVoiceModule", "addListener $eventName")
    }

    @ReactMethod
    fun removeListeners(count: Int) {
        Log.d("VonageVoiceModule", "removeListeners $count")
    }

    @ReactMethod
    fun mute(callId: String, promise: Promise) {
        val normalizedCallId = callId.lowercase()
        Log.d("VonageVoiceModule", "mute $normalizedCallId")

        scope.launch { promise.tryBlocking { callActionsHandler.mute(normalizedCallId) } }
    }

    @ReactMethod
    fun unmute(callId: String, promise: Promise) {
        val normalizedCallId = callId.lowercase()
        Log.d("VonageVoiceModule", "unmute $normalizedCallId")

        scope.launch { promise.tryBlocking { callActionsHandler.unmute(normalizedCallId) } }
    }

    @ReactMethod
    fun enableSpeaker(promise: Promise) {
        Log.d("VonageVoiceModule", "enableSpeaker")
        speakerController.enableSpeaker()
    }

    @ReactMethod
    fun disableSpeaker(promise: Promise) {
        Log.d("VonageVoiceModule", "disableSpeaker")
        speakerController.disableSpeaker()
    }

    @ReactMethod
    fun registerVoipToken(promise: Promise) {
        Log.d("VonageVoiceModule", "registerVoipToken")

        scope.launch {
            val pushToken = VonagePushMessageService.requestToken()
            eventEmitter.sendEvent(
                Event.REGISTER,
                Arguments.createMap().apply { putString("token", pushToken) }
            )
        }
    }

    override fun invalidate() {
        super.invalidate()
        Log.d("VonageVoiceModule", "invalidate")
    }


    // delete


    @ReactMethod
    fun subscribeToAudioRouteChange() {
        Log.d("VonageVoiceModule", "subscribeToAudioRouteChange")

    }


    @ReactMethod
    fun subscribeToCallEvents() {
        Log.d("VonageVoiceModule", "subscribeToCallEvents")

        // Done in CallActionsHandler::init
    }

    @ReactMethod
    fun unsubscribeFromCallEvents() {
        Log.d("VonageVoiceModule", "unsubscribeFromCallEvents")
    }

}
