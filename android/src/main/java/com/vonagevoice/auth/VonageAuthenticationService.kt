package com.vonagevoice.auth

import android.util.Log
import com.vonage.android_core.VGClientConfig
import com.vonage.clientcore.core.api.ClientConfigRegion
import com.vonage.voice.api.VoiceClient
import com.vonagevoice.storage.VonageStorage

/**
 * The VonageAuthenticationService class is responsible for managing authentication and
 * session management with the Vonage Voice API. It allows for login, logout, token registration,
 * and region configuration for the Vonage Voice client.
 *
 * @param vonageStorage The VonageStorage instance used to persist data related to the authentication session.
 * @param voiceClient The VoiceClient instance used to interact with the Vonage Voice API.
 */
class VonageAuthenticationService(
    private val vonageStorage: VonageStorage,
    private val voiceClient: VoiceClient,
) : IVonageAuthenticationService {

    init {
        Log.d("VonageAuthenticationService", "init")
    }

    /**
     * Logs in to the Vonage Voice service using the provided JWT token.
     *
     * @param jwt The JSON Web Token (JWT) used to authenticate the session.
     */
    override suspend fun login(jwt: String) {
        Log.d("VonageAuthenticationService", "login $jwt")
        voiceClient.createSession(jwt)
    }

    /**
     * Logs out from the Vonage Voice service and deletes the current session.
     */
    override suspend fun logout() {
        Log.d("VonageAuthenticationService", "logout")
        voiceClient.deleteSession()
    }


    /**
     * Registers a Firebase push token with the Vonage Voice service to enable push notifications.
     * This token maps the device to the user, allowing push notifications for incoming calls.
     *
     * @param newTokenFirebase The new Firebase push token to be registered with the Vonage service.
     */
    override suspend fun registerVonageVoipToken(newTokenFirebase: String) {
        Log.d("VonageAuthenticationService", "registerVonageVoipToken")
        val deviceId: String = voiceClient.registerDevicePushToken(newTokenFirebase)
        vonageStorage.saveDeviceId(deviceId)
        vonageStorage.savePushTokenStr(newTokenFirebase)
    }

    /**
     * Sets the region for the Vonage Voice service, which determines the server region used
     * for the session. This configuration is saved and applied to the voice client.
     *
     * @param region The region to be set, which can be "EU", "AP", or other supported regions.
     */
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
