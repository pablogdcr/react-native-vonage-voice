package com.vonagevoice.notifications

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.vonagevoice.call.ICallActionsHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

class CallActionReceiver : BroadcastReceiver(), KoinComponent {
    private val callHandler: ICallActionsHandler by inject()
    private val notificationManager: NotificationManager by inject()
    private val appIntent: IAppIntent by inject()
    private val scope = CoroutineScope(Dispatchers.IO)


    override fun onReceive(context: Context, intent: Intent) {
        Log.d(
            "CallActionReceiver",
            "onReceive (launched from OpenCustomAlloPhoneDialerUI) intent action : ${intent.action}"
        )

        val callId = intent.getStringExtra("call_id")
            ?: throw IllegalArgumentException("CallActionReceiver notifications call_id is required")

        when (intent.action) {
           /* "co.themobilefirst.allo.ACTION_INCOMING_CALL" -> {
                Log.d("CallActionReceiver", "onReceive ACTION_INCOMING_CALL starting Activity")

                val phoneName = intent.getStringExtra("phone_name")
                    ?: throw IllegalArgumentException("CallActionReceiver notifications phone_name is required")
                val from = intent.getStringExtra("from")
                    ?: throw IllegalArgumentException("CallActionReceiver notifications from is required")
                val language = intent.getStringExtra("language")
                    ?: throw IllegalArgumentException("CallActionReceiver notifications language is required")
                val incoming_call_image = intent.getStringExtra("incoming_call_image")
                    ?: throw IllegalArgumentException("CallActionReceiver notifications incoming_call_image is required")

                val startActivityIntent = Intent(context, CallActivity::class.java).apply {
                    putExtra("call_id", callId)
                    putExtra("from", from)
                    putExtra("phone_name", phoneName)
                    putExtra("language", language)
                    putExtra("incoming_call_image", incoming_call_image)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                context.startActivity(startActivityIntent)
            }*/

            "co.themobilefirst.allo.ACTION_ANSWER_CALL" -> {
                // Gérer l'acceptation de l'appel
                val phoneName = intent.getStringExtra("phone_name")
                    ?: throw IllegalArgumentException("CallActionReceiver notifications phone_name is required")
                val from = intent.getStringExtra("from")
                    ?: throw IllegalArgumentException("CallActionReceiver notifications from is required")
                val language = intent.getStringExtra("language")
                    ?: throw IllegalArgumentException("CallActionReceiver notifications language is required")
                val incoming_call_image = intent.getStringExtra("incoming_call_image")
                    ?: throw IllegalArgumentException("CallActionReceiver notifications incoming_call_image is required")

                notificationManager.cancelInboundNotification()
                val callActivityIntent =  appIntent.getCallActivity(
                    callId = callId,
                    from = from,
                    phoneName = phoneName,
                    language = language,
                    incomingCallImage = incoming_call_image,
                )

                context.startActivity(callActivityIntent)
                Log.d("CallActionReceiver", "onReceive hangup")
            }

            "co.themobilefirst.allo.ACTION_REJECT_CALL" -> {
                scope.launch {
                    callHandler.reject(callId)
                    Log.d("CallActionReceiver", "onReceive reject done")
                }
                notificationManager.cancelInboundNotification()
            }

            "co.themobilefirst.allo.ACTION_HANG_UP" -> {
                // Gérer la fin de l'appel
                Log.d("CallActionReceiver", "onReceive hangup")

                scope.launch {
                    callHandler.hangup(callId)
                    Log.d("CallActionReceiver", "onReceive reject done")
                }
                notificationManager.cancelInProgressNotification()
            }
        }
    }


    companion object {
        fun hangUp(
            context: Context,
            callId: String,
        ): PendingIntent {
            val intent = Intent(context, CallActionReceiver::class.java).apply {
                action = "co.themobilefirst.allo.ACTION_HANG_UP"
                putExtra("call_id", callId)
            }
            val hangUpPendingIntent =
                PendingIntent.getBroadcast(
                    context,
                    2,
                    intent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
            return hangUpPendingIntent
        }

        fun reject(context: Context, callId: String): PendingIntent? {
            val rejectIntent = Intent(context, CallActionReceiver::class.java).apply {
                action = "co.themobilefirst.allo.ACTION_REJECT_CALL"
                putExtra("call_id", callId)
            }
            val rejectPendingIntent = PendingIntent.getBroadcast(
                context,
                1,
                rejectIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            return rejectPendingIntent
        }

        fun answer(
            context: Context, callId: String,
            phoneName: String,
            from: String,
            language: String,
            incomingCallImage: String
        ): PendingIntent? {
            val answerIntent = Intent(context, CallActionReceiver::class.java).apply {
                action = "co.themobilefirst.allo.ACTION_ANSWER_CALL"
                putExtra("call_id", callId)
                putExtra("phone_name", phoneName)
                putExtra("from", from)
                putExtra("language", language)
                putExtra("incoming_call_image", incomingCallImage)
            }

            val answerPendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                answerIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            return answerPendingIntent
        }
    }
}
