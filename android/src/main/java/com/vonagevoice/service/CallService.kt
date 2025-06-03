package com.vonagevoice.service

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.util.Log
import com.vonagevoice.notifications.NotificationManager.Companion.CALL_IN_PROGRESS_NOTIFICATION_ID
import kotlinx.coroutines.Job
import org.koin.java.KoinJavaComponent.inject

class CallService : Service() {

    private val notificationManager: com.vonagevoice.notifications.NotificationManager by inject(com.vonagevoice.notifications.NotificationManager::class.java)
    private var callId: String? = null
    private var job: Job? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        callId = intent?.getStringExtra("callId")
        if (callId == null) {
            Log.e("CallService", "Missing callId, stopping service.")
            stopSelf()
            return START_NOT_STICKY
        } else {
            Log.d("CallService", "onStartCommand callId: $callId")
            startForeground(
                CALL_IN_PROGRESS_NOTIFICATION_ID,
                notificationManager.inProgressNotification(
                    callId = requireNotNull(callId),
                )
            )
            return START_STICKY
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("CallService", "onDestroy")
        job?.cancel()
        job = null
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private var callServiceIntent: Intent? = null

        fun start(context: Context, callId: String) {
            Log.d("CallService", "start callId: $callId")
            callServiceIntent = Intent(context, CallService::class.java).apply {
                putExtra("callId", callId)
            }
            context.startForegroundService(callServiceIntent)
        }

        fun stop(context: Context) {
            Log.d("CallService", "stop")
            callServiceIntent?.let {
                context.stopService(it)
            }
        }
    }
}
