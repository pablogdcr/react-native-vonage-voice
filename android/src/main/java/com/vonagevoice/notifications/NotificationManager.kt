package com.vonagevoice.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import com.vonagevoice.R
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Be sure to add this in manifest :
 *
 * <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
 */
class NotificationManager(private val context: Context, private val appIntent: IAppIntent) {

    companion object {
        private const val CALL_OUTBOUND_NOTIFICATION_ID = 1
        private const val CALL_INBOUND_NOTIFICATION_ID = 2
        private const val CALL_IN_PROGRESS_NOTIFICATION_ID = 3
        private const val CALL_MISSED_NOTIFICATION_ID = 4

        const val MISSED_CALL = "missed_call"
        const val INCOMING_CALL = "incoming_call"
        const val OUTGOING_CALL = "outgoing_call"
        const val ONGOING_CALL = "ongoing_call"
    }

    init {
        Log.d("NotificationManager", "init")
        createNotificationChannels()
    }

    private fun cancelCallNotification(notificationId: Int) {
        Log.d("NotificationManager", "cancelCallNotification notificationId: $notificationId")
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(notificationId)
    }

    private fun createNotificationChannels() {
        Log.d("NotificationManager", "createNotificationChannels")
        val channels =
            listOf(
                NotificationChannel(
                        MISSED_CALL,
                        "Missed Calls",
                        NotificationManager.IMPORTANCE_DEFAULT,
                    )
                    .apply { description = "Notifications for missed calls" },
                NotificationChannel(
                        INCOMING_CALL,
                        "Incoming Calls",
                        NotificationManager.IMPORTANCE_HIGH,
                    )
                    .apply {
                        description = "Notifications for incoming calls"
                        enableLights(true)
                        enableVibration(true)
                    },
                NotificationChannel(
                        OUTGOING_CALL,
                        "Outgoing Calls",
                        NotificationManager.IMPORTANCE_LOW,
                    )
                    .apply { description = "Notifications for outgoing calls" },
                NotificationChannel(
                        ONGOING_CALL,
                        "Ongoing Calls",
                        NotificationManager.IMPORTANCE_MIN,
                    )
                    .apply {
                        description = "Persistent notification for active calls"
                        setSound(null, null)
                    },
            )

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        channels.forEach { notificationManager.createNotificationChannel(it) }
    }

    fun createNotification(
        channelId: String,
        title: String,
        text: String,
        iconResId: Int,
        intent: Intent,
        callId: String,
    ) {
        Log.d("NotificationManager", "createNotification")
        val pendingIntent =
            PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT)

        val notification =
            NotificationCompat.Builder(context, channelId)
                .setContentTitle(title)
                .setContentText(text)
                .setSmallIcon(iconResId)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .build()

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(callId.hashCode(), notification)
    }

    fun showInboundCallNotification(
        callId: String,
        from: String,
        phoneName: String,
        language: String,
        incomingCallImage: String,
    ) {
        Log.d("NotificationManager", "showInboundCallNotification callId: $callId, from: $from")

        /*  val intent =
             appIntent.getCallActivity(
                 callId = callId,
                 from = from,
                 phoneName = phoneName,
                 language = language,
                 incomingCallImage = incomingCallImage,
             )

         val pendingIntent =
             PendingIntent.getActivity(
                 context,
                 0,
                 intent,
                 PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
             )

         // Intentions pour Refuser et Répondre
         val answerPendingIntent =
             CallActionReceiver.answer(
                 context = context,
                 callId = callId,
                 incomingCallImage = incomingCallImage,
                 language = language,
                 phoneName = phoneName,
                 from = from,
             )
         val rejectPendingIntent = CallActionReceiver.reject(context, callId)

         val notification =
             NotificationCompat.Builder(context, "inbound_call_channel")
                 .setContentTitle("Appel entrant")
                 .setContentText("Appel de $phoneName")
                 .setSmallIcon(R.drawable.ic_incoming_call) // Icône pour appel entrant
                 .addAction(0, "Répondre", answerPendingIntent) // No icon for "Répondre"
                 .addAction(0, "Refuser", rejectPendingIntent) // No icon for "Refuser"
                 .setPriority(NotificationCompat.PRIORITY_HIGH)
                 .setCategory(NotificationCompat.CATEGORY_CALL)
                 .setFullScreenIntent(pendingIntent, true)
                 .build()

         val notificationManager =
             context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
         notificationManager.notify(
             CALL_INBOUND_NOTIFICATION_ID,
             notification,
         ) // ID unique pour inbound


        */

        val fullScreenIntent =
            appIntent.getCallActivity(
                callId = callId,
                from = from,
                phoneName = phoneName,
                language = language,
                incomingCallImage = incomingCallImage,
            )

        val pendingIntent =
            PendingIntent.getActivity(
                context,
                0,
                fullScreenIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        // Intentions pour Refuser et Répondre
        val answerPendingIntent =
            CallActionReceiver.answer(
                context = context,
                callId = callId,
                incomingCallImage = incomingCallImage,
                language = language,
                phoneName = phoneName,
                from = from,
            )
        val rejectPendingIntent = CallActionReceiver.reject(context, callId)

        val notification =
            NotificationCompat.Builder(context, "inbound_call_channel")
                .setContentTitle("Appel entrant")
                .setContentText("Appel de ${phoneName}")
                .setSmallIcon(R.drawable.ic_incoming_call)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .addAction(0, "Répondre", answerPendingIntent)
                .addAction(0, "Refuser", rejectPendingIntent)
                .setFullScreenIntent(pendingIntent, true)
                .setAutoCancel(true)
                .build()

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(CALL_INBOUND_NOTIFICATION_ID, notification)
    }

    fun showInProgressCallNotification(
        callId: String,
        from: String,
        phoneName: String,
        language: String,
        incomingCallImage: String,
        elapsedTime: Long,
    ) {
        Log.d("NotificationManager", "showInProgressCallNotification callId: $callId, from: $from")
        val intent =
            appIntent.getCallActivity(
                callId = callId,
                from = from,
                phoneName = phoneName,
                language = language,
                incomingCallImage = incomingCallImage,
            )

        val pendingIntent =
            PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        // Intent pour raccrocher
        val hangUpPendingIntent = CallActionReceiver.hangUp(context, callId)

        // Formatage du temps écoulé
        val minutes = (elapsedTime / 60).toInt()
        val seconds = (elapsedTime % 60).toInt()
        val time = String.format("%02d:%02d", minutes, seconds)

        val notification =
            NotificationCompat.Builder(context, "inprogress_call_channel")
                .setContentTitle("Appel en cours")
                .setContentText("$phoneName - $time")
                .setSilent(true)
                .setSmallIcon(R.drawable.ic_call)
                .addAction(0, "Raccrocher", hangUpPendingIntent)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_MIN) // Priorité minimale
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setOngoing(true) // Notification persistante
                .setSound(null)
                .setVibrate(null)
                .setVisibility(NotificationCompat.VISIBILITY_SECRET)
                .build()

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(
            CALL_IN_PROGRESS_NOTIFICATION_ID,
            notification,
        ) // ID unique pour in progress
    }

    fun showMissedCallNotification(callId: String, from: String) {
        Log.d("NotificationManager", "showMissedCallNotification callId: $callId, from: $from")
        val notification = TODO()
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(CALL_MISSED_NOTIFICATION_ID, notification)
    }

    fun showNotificationAndStartCallTimer(
        callId: String,
        from: String,
        phoneName: String,
        language: String,
        incoming_call_image: String,
    ): Job {
        Log.d("NotificationManager", "showNotificationAndStartCallTimer callId: $callId, from: $from")
        return GlobalScope.launch(Dispatchers.Main) {
            var elapsedTime = 0L
            while (isActive) {
                showInProgressCallNotification(
                    callId = callId,
                    from = from,
                    phoneName = phoneName,
                    elapsedTime = elapsedTime,
                    incomingCallImage = incoming_call_image,
                    language = language,
                )
                delay(1000)
                elapsedTime++
            }
        }
    }

    fun showOutboundCallNotification(callId: String, from: String) {
        Log.d("NotificationManager", "showOutboundCallNotification callId: $callId, from: $from")
        val intent = appIntent.getMainActivity()

        val pendingIntent =
            PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        val notification =
            NotificationCompat.Builder(context, "outbound_call_channel")
                .setContentTitle("Appel en cours")
                .setContentText("Appel avec $from")
                .setSmallIcon(R.drawable.ic_outgoing_call) // Icône pour appel sortant
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(pendingIntent)
                .setOngoing(true) // Rendre la notification persistante
                .build()

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(
            CALL_OUTBOUND_NOTIFICATION_ID,
            notification,
        ) // ID unique pour outbound
    }

    fun cancelInProgressNotification() {
        Log.d("NotificationManager", "cancelInProgressNotification")
        cancelCallNotification(CALL_IN_PROGRESS_NOTIFICATION_ID)
    }

    fun cancelInboundNotification() {
        Log.d("NotificationManager", "cancelInboundNotification")
        cancelCallNotification(CALL_INBOUND_NOTIFICATION_ID)
    }

    fun cancelMissedNotification() {
        Log.d("NotificationManager", "cancelMissedNotification")
        cancelCallNotification(CALL_MISSED_NOTIFICATION_ID)
    }

    fun cancelOutboundNotification() {
        Log.d("NotificationManager", "cancelOutboundNotification")
        cancelCallNotification(CALL_OUTBOUND_NOTIFICATION_ID)
    }
}
