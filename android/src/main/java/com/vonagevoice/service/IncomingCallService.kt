package com.vonagevoice.service

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.util.Log
import com.vonagevoice.call.InboundCallNotifier
import com.vonagevoice.notifications.NotificationManager.Companion.CALL_INBOUND_NOTIFICATION_ID
import kotlinx.coroutines.Job
import org.koin.java.KoinJavaComponent.inject

class IncomingCallService : Service() {

    private val inboundCallNotifier: InboundCallNotifier by inject(InboundCallNotifier::class.java)

    private var callId: String? = null
    private var phoneName: String? = null
    private var from: String? = null
    private var job: Job? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        callId = intent?.getStringExtra("callId")
            ?: throw IllegalStateException("callId is required in CallService")

        from = intent.getStringExtra("from")
            ?: throw IllegalStateException("from is required in CallService")

        phoneName = intent.getStringExtra("phoneName")
            ?: throw IllegalStateException("phoneName is required in CallService")

        Log.d("CallService", "onStartCommand callId: $callId")

        val builder = inboundCallNotifier.notifyIncomingCall(
            callId = requireNotNull(callId),
            from = requireNotNull(from),
            phoneName = requireNotNull(phoneName)
        )

        startForeground(
            CALL_INBOUND_NOTIFICATION_ID,
            builder.build().apply {
                this.flags = this.flags or (Notification.FLAG_NO_CLEAR or Notification.FLAG_ONGOING_EVENT)
            }
        )
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("CallService", "onDestroy")
        job?.cancel()
        job = null
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private var incomingCallServiceIntent: Intent? = null

        fun start(
            context: Context,
            callId: String,
            from: String,
            phoneName: String,
        ) {
            Log.d("CallService", "start callId: $callId")
            incomingCallServiceIntent = Intent(context, IncomingCallService::class.java).apply {
                putExtra("callId", callId)
                putExtra("from", from)
                putExtra("phoneName", phoneName)
            }
            context.startForegroundService(incomingCallServiceIntent)
        }

        fun stop(context: Context) {
            Log.d("IncomingCallService", "stop")
            incomingCallServiceIntent?.let {
                context.stopService(it)
            }
        }
    }
}
