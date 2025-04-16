package com.vonagevoice.call

import android.util.Log
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.vonage.android_core.PushType
import com.vonage.voice.api.VoiceClient
import com.vonagevoice.js.JSEventSender
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Service responsible for handling Firebase push messages and tokens in the Vonage context.
 *
 * This service extends FirebaseMessagingService and uses Koin for dependency injection to
 * manage the `callActionsHandler` and `jsEventSender`. It listens for new Firebase tokens
 * and incoming push notifications, forwarding the necessary data to the appropriate handlers.
 * The service operates in a background coroutine scope with IO dispatcher to ensure non-blocking operations.
 */
class VonagePushMessageService : FirebaseMessagingService(), KoinComponent {

    private val callActionsHandler: ICallActionsHandler by inject()
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val jsEventSender: JSEventSender by inject()

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

        scope.launch {
            jsEventSender.sendFirebasePushToken(token)
        }
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        val pushType: PushType = VoiceClient.getPushNotificationType(remoteMessage.data.toString())
        Log.d("VonagePushMessageService", "onMessageReceived pushType: $pushType, remoteMessage: $remoteMessage")
        if (pushType == PushType.INCOMING_CALL) {
            scope.launch {
                callActionsHandler.processPushCallInvite(remoteMessage.data.toString())
            }
        }
    }
}
