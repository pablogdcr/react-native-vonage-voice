package com.vonagevoice.js

import android.content.Context
import android.content.Intent
import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.vonage.voice.api.VoiceClient
import com.vonagevoice.auth.IVonageAuthenticationService
import com.vonagevoice.call.ICallActionsHandler
import com.vonagevoice.call.VonagePushMessageService
import com.vonagevoice.deprecated.getAvailableAudioInputs
import com.vonagevoice.speakers.SpeakerController
import com.vonagevoice.storage.VonageStorage
import com.vonagevoice.utils.success
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
    private val scope = CoroutineScope(Dispatchers.IO)
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
        Log.d("VonageVoiceModule", "answerCall $callId")
        scope.launch { promise.tryBlocking { callActionsHandler.answer(callId) } }
    }

    @ReactMethod
    fun rejectCall(callId: String, promise: Promise) {
        Log.d("VonageVoiceModule", "rejectCall $callId")
        scope.launch { promise.tryBlocking { callActionsHandler.reject(callId) } }
    }

    @ReactMethod
    fun hangup(callId: String, promise: Promise) {
        Log.d("VonageVoiceModule", "hangup $callId")
        scope.launch { promise.tryBlocking { callActionsHandler.hangup(callId) } }
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
        Log.d("VonageVoiceModule", "reconnectCall $callId")

        scope.launch { promise.tryBlocking { callActionsHandler.reconnectCall(callId) } }
    }

    @ReactMethod
    fun getAvailableAudioDevices(promise: Promise) {
        Log.d("VonageVoiceModule", "getAvailableAudioDevices")

        getAvailableAudioInputs(context).map {
            Arguments.createMap().apply { putBoolean("success", true) }
        }

        /*
                let devices = AVAudioSession.sharedInstance().availableInputs

                resolve(devices?.map { device in
                        return [
                            "name": device.portName,
                    "id": device.uid,
                    "type": device.portType
                    ]
                })*/
    }

    @ReactMethod
    fun setAudioDevice(deviceId: String, promise: Promise) {
        Log.d("VonageVoiceModule", "setAudioDevice $deviceId")
    }

    @ReactMethod
    fun subscribeToCallEvents() {
        Log.d("VonageVoiceModule", "subscribeToCallEvents")

        /*
         callController.calls
            .flatMap { $0 }
            .sink { call in
                let callData: [String: Any] = [
                    "id": call.id.uuidString,
                    "status": call.status.description,
                    "isOutbound": call.isOutbound,
                    "phoneNumber": call.phoneNumber,
                    "startedAt": call.startedAt?.timeIntervalSince1970 as Any
                ]

                EventEmitter.shared.sendEvent(withName: Event.callEvents.rawValue, body: callData)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .voipTokenRegistered)
            .sink { notification in
                if let token = notification.userInfo?["token"] as? String {
                    EventEmitter.shared.sendEvent(withName: Event.register.rawValue, body: ["token": token])
                }
            }
            .store(in: &cancellables)
         */
    }

    @ReactMethod
    fun unsubscribeFromCallEvents() {
        Log.d("VonageVoiceModule", "unsubscribeFromCallEvents")
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
        Log.d("VonageVoiceModule", "mute $callId")

        scope.launch { promise.tryBlocking { callActionsHandler.mute(callId) } }
    }

    @ReactMethod
    fun unmute(callId: String, promise: Promise) {
        Log.d("VonageVoiceModule", "unmute $callId")

        scope.launch { promise.tryBlocking { callActionsHandler.unmute(callId) } }
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
    fun subscribeToAudioRouteChange(promise: Promise) {
        Log.d("VonageVoiceModule", "subscribeToAudioRouteChange")
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
}
