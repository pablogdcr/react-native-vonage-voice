package com.vonagevoice.call

import android.util.Log
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.vonage.android_core.PushType
import com.vonage.voice.api.VoiceClient
import com.vonagevoice.auth.IVonageAuthenticationService
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

class VonagePushMessageService : FirebaseMessagingService(), KoinComponent {

    private val callActionsHandler: ICallActionsHandler by inject()
    private val vonageAuthenticationService: IVonageAuthenticationService by inject()
    private val scope = CoroutineScope(Dispatchers.IO)

    companion object {
        suspend fun requestToken(): String = suspendCancellableCoroutine { continuation ->
            Log.d("VonagePushMessageService", "requestToken")
            FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                if (task.isSuccessful) {
                    val token = task.result
                    if (token != null) {
                        continuation.resume(token)
                    } else {
                        continuation.resumeWithException(Exception("Token is null"))
                    }
                } else {
                    continuation.resumeWithException(
                        task.exception ?: Exception("Token request failed")
                    )
                }
            }
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d("VonagePushMessageService", "onNewToken $token")
        // Register new token with Vonage
        scope.launch { vonageAuthenticationService.registerVonageVoipToken(token) }
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        Log.d("VonagePushMessageService", "onMessageReceived $remoteMessage")
        val pushType = VoiceClient.getPushNotificationType(remoteMessage.data.toString())

        Log.d("VonagePushMessageService", "onMessageReceived pushType: $pushType")
        if (pushType == PushType.INCOMING_CALL) {
            scope.launch {
                callActionsHandler.processPushCallInvite(remoteMessage)
            }
        }
    }
}
