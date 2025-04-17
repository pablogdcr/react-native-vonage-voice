package com.vonagevoice.notifications

import android.app.ActivityOptions
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
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
            "onReceive intent: $intent"
        )
        val callId = intent.getStringExtra("call_id")
            ?: throw IllegalArgumentException("CallActionReceiver notifications call_id is required")

        when (intent.action) {
            "com.vonagevoice.ACTION_ANSWER_CALL" -> {
                Log.d("CallActionReceiver", "onReceive answer")

                val phoneName = intent.getStringExtra("phone_name")
                    ?: throw IllegalArgumentException("CallActionReceiver notifications phone_name is required")
                val from = intent.getStringExtra("from")
                    ?: throw IllegalArgumentException("CallActionReceiver notifications from is required")
                val language = intent.getStringExtra("language")
                    ?: throw IllegalArgumentException("CallActionReceiver notifications language is required")
                val incoming_call_image = intent.getStringExtra("incoming_call_image")

                notificationManager.cancelInboundNotification()
                val callActivityIntent =  appIntent.getCallActivity(
                    callId = callId,
                    from = from,
                    phoneName = phoneName,
                    language = language,
                    incomingCallImage = incoming_call_image,
                    answerCall = true
                )

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    callActivityIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    context.startActivity(callActivityIntent, ActivityOptions.makeBasic().apply {
                        pendingIntentBackgroundActivityStartMode = ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                    }.toBundle())
                } else {
                    callActivityIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(callActivityIntent)
                }
                Log.d("CallActionReceiver", "onReceive answer done")
            }

            "com.vonagevoice.ACTION_REJECT_CALL" -> {
                Log.d("CallActionReceiver", "onReceive reject")

                scope.launch {
                    callHandler.reject(callId)
                    notificationManager.cancelInboundNotification()
                    Log.d("CallActionReceiver", "onReceive reject done")
                }
            }

            "com.vonagevoice.ACTION_HANG_UP" -> {
                Log.d("CallActionReceiver", "onReceive hangup")

                scope.launch {
                    callHandler.hangup(callId)
                    notificationManager.cancelInProgressNotification()
                    Log.d("CallActionReceiver", "onReceive hangup done")
                }
            }
        }
    }


    companion object {
        fun hangUp(
            context: Context,
            callId: String,
        ): PendingIntent {
            Log.d("CallActionReceiver", "pending intent hangup")
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
            Log.d("CallActionReceiver", "pending intent reject")
            val rejectIntent = Intent(context, CallActionReceiver::class.java).apply {
                action = "com.vonagevoice.ACTION_REJECT_CALL"
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
            incomingCallImage: String?
        ): PendingIntent? {
            Log.d("CallActionReceiver", "pending intent answer")
            val answerIntent = Intent(context, CallActionReceiver::class.java).apply {
                action = "com.vonagevoice.ACTION_ANSWER_CALL"
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
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_CANCEL_CURRENT,
            )
            return answerPendingIntent
        }
    }
}
