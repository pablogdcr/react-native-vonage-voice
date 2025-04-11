package com.vonagevoice.auth

import android.util.Log
import com.facebook.react.bridge.Arguments
import com.vonage.android_core.VGClientConfig
import com.vonage.clientcore.core.api.ClientConfigRegion
import com.vonage.voice.api.VoiceClient
import com.vonagevoice.js.Event
import com.vonagevoice.js.EventEmitter
import com.vonagevoice.storage.VonageStorage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class VonageAuthenticationService(
    private val voiceClient: VoiceClient,
    private val eventEmitter: EventEmitter,
    private val vonageStorage: VonageStorage,
) : IVonageAuthenticationService {

    private var currentSessionId: String = ""

    init {
        Log.d("VonageAuthenticationService", "init")
        // observe session errors and send to JS
/*
        voiceClient.setSessionErrorListener {
            CoroutineScope(Dispatchers.IO).launch {
                eventEmitter.sendEvent(
                    Event.SessionError,
                    Arguments.createMap().apply { putString("reason", it.toString()) },
                )
                Log.d("VonageAuthenticationService", "SessionError reason $it")
            }
        }

 */
    }

    override suspend fun login(jwt: String) {
        Log.d("VonageAuthenticationService", "login $jwt")
        currentSessionId = voiceClient.createSession(jwt)
        Log.d("VonageAuthenticationService", "login sessionId $currentSessionId")
    }

    override suspend fun logout() {
        Log.d("VonageAuthenticationService", "logout")
        voiceClient.deleteSession()
    }

    /** For push to work, you need to register a token. This token maps this device to this user. */
    override suspend fun registerVonageVoipToken(newTokenFirebase: String) {
        Log.d("VonageAuthenticationService", "registerVonageVoipToken")
        val storedTokenFirebase = vonageStorage.getPushTokenStr()
        Log.d("VonageAuthenticationService", "registerVonageVoipToken storedTokenFirebase: $storedTokenFirebase")
        Log.d("VonageAuthenticationService", "registerVonageVoipToken newTokenFirebase: $newTokenFirebase")

        val shouldRegisterDevicePushToken = storedTokenFirebase != newTokenFirebase

        Log.d(
            "VonageAuthenticationService",
            "registerVonageVoipToken shouldRegisterDevicePushToken $shouldRegisterDevicePushToken"
        )
        val deviceId: String = voiceClient.registerDevicePushToken(newTokenFirebase)

        Log.d("VonageAuthenticationService", "registerVonageVoipToken deviceId $deviceId")
        vonageStorage.saveDeviceId(deviceId)
        vonageStorage.savePushTokenStr(newTokenFirebase)
        Log.d("VonageAuthenticationService", "registerVonageVoipToken end")
    }

    override fun setRegion(region: String) {

        Log.d("VonageAuthenticationService", "setRegion $region")
        vonageStorage.saveRegion(region)

        val vonageRegion =
            when (region) {
                "EU" -> ClientConfigRegion.EU
                "AP" -> ClientConfigRegion.AP
                else -> ClientConfigRegion.US
            }

        val config = VGClientConfig(region = vonageRegion)
        voiceClient.setConfig(config)
    }
}
