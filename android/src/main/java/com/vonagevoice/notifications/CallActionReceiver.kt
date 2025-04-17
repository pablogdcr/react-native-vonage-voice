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
    private val scope = CoroutineScope(Dispatchers.IO)

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(
            "CallActionReceiver",
            "onReceive intent: $intent"
        )
        val callId = intent.getStringExtra("call_id")
            ?: throw IllegalArgumentException("CallActionReceiver notifications call_id is required")

        when (intent.action) {
            ACTION_REJECT_CALL-> {
                Log.d("CallActionReceiver", "onReceive reject")

                scope.launch {
                    callHandler.reject(callId)
                    notificationManager.cancelInboundNotification()
                    Log.d("CallActionReceiver", "onReceive reject done")
                }
            }

            "co.themobilefirst.allo.ACTION_HANG_UP" -> {
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
        const val ACTION_REJECT_CALL = "com.vonage.ACTION_REJECT_CALL"
        const val ACTION_HANG_UP = "com.vonage.ACTION_HANG_UP"

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
    }
}
