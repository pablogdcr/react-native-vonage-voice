package com.vonagevoice.notifications

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import com.vonagevoice.R

/**
 * Be sure to add this in manifest :
 *
 * <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
 */
class NotificationManager(
    private val context: Context,
    private val appIntent: IAppIntent
) {

    companion object {
        private const val CALL_OUTBOUND_NOTIFICATION_ID = 1
        private const val CALL_INBOUND_NOTIFICATION_ID = 2
        const val CALL_IN_PROGRESS_NOTIFICATION_ID = 3

        const val INCOMING_CALL_CHANNEL_ID = "incoming_call"
        const val OUTGOING_CALL_CHANNEL_ID = "outgoing_call"
        const val ONGOING_CALL_CHANNEL_ID = "ongoing_call"
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
                    INCOMING_CALL_CHANNEL_ID,
                    context.getString(R.string.notification_incoming_calls),
                    NotificationManager.IMPORTANCE_HIGH,
                )
                    .apply {
                        description = context.getString(R.string.notification_incoming_calls_desc)
                        lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                        importance = NotificationManager.IMPORTANCE_HIGH
                    },
                NotificationChannel(
                    OUTGOING_CALL_CHANNEL_ID,
                    context.getString(R.string.notification_outgoing_calls),
                    NotificationManager.IMPORTANCE_LOW,
                )
                    .apply {
                        description = context.getString(R.string.notification_outgoing_calls_desc)
                    },
                NotificationChannel(
                    ONGOING_CALL_CHANNEL_ID,
                    context.getString(R.string.notification_ongoing_calls),
                    NotificationManager.IMPORTANCE_MIN,
                )
                    .apply {
                        description = context.getString(R.string.notification_ongoing_calls_desc)
                        setSound(null, null)
                    },
            )

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        channels.forEach { notificationManager.createNotificationChannel(it) }
    }

    fun showInboundCallNotification(
        from: String,
        callId: String,
        phoneName: String?
    ): NotificationCompat.Builder {
        Log.d("NotificationManager", "showInboundCallNotification callId: $callId, from: $from")

        val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val isDeviceUnlocked = !keyguardManager.isKeyguardLocked

        val pendingIntent = if (isDeviceUnlocked) {
            val activityIntent = appIntent.getMainActivity()

            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                activityIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            pendingIntent
        } else {
            val callActivityIntent = appIntent.getCallActivity(
                callId = callId,
                from = from,
                phoneName = phoneName,
                incomingCallImage = null,
                answerCall = false
            )

            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                callActivityIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_CANCEL_CURRENT
            )
            pendingIntent
        }

        val answerPendingIntent = if (isDeviceUnlocked) {
            PendingIntent.getActivity(
                context,
                0,
                appIntent.getCallActivity(
                    callId = callId,
                    from = from,
                    phoneName = phoneName,
                    incomingCallImage = null,
                    answerCall = true
                ),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_CANCEL_CURRENT
            )
        } else {
            PendingIntent.getBroadcast(
                context,
                0,
                Intent(context, CallActionReceiver::class.java).apply {
                    action = CallActionReceiver.ACTION_ANSWER_CALL
                    putExtra("call_id", callId)
                },
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
        }

        val rejectPendingIntent = PendingIntent.getBroadcast(
            context,
            1,
            Intent(context, CallActionReceiver::class.java).apply {
                action = CallActionReceiver.ACTION_REJECT_CALL
                putExtra("call_id", callId)
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(context, INCOMING_CALL_CHANNEL_ID)
            .setContentTitle(context.getString(R.string.notification_incoming_call_title))
            .setContentText(context.getString(R.string.call_from, from))
            .setSmallIcon(R.drawable.ic_incoming_call)
            .addAction(0, context.getString(R.string.answer), answerPendingIntent)
            .addAction(0, context.getString(R.string.reject), rejectPendingIntent)
            .setOnlyAlertOnce(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setColorized(true)
            .setColor(0x0B2120)

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(CALL_INBOUND_NOTIFICATION_ID, notification.build())

        return notification
    }

    fun updateInboundCallNotification(
        notificationBuilder: NotificationCompat.Builder,
        phoneName: String
    ) {
        // Only update if present
        if (isNotificationDisplayed(notificationId = CALL_INBOUND_NOTIFICATION_ID)) {
            notificationBuilder.setContentText(context.getString(R.string.call_from, phoneName))

            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(CALL_INBOUND_NOTIFICATION_ID, notificationBuilder.build())
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
            NotificationCompat.Builder(context, OUTGOING_CALL_CHANNEL_ID)
                .setContentTitle(context.getString(R.string.call_in_progress))
                .setContentText(context.getString(R.string.notification_call_with, from))
                .setSmallIcon(R.drawable.ic_outgoing_call)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setChannelId(OUTGOING_CALL_CHANNEL_ID)
                .build()

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(CALL_OUTBOUND_NOTIFICATION_ID, notification)
    }

    fun cancelInProgressNotification() {
        Log.d("NotificationManager", "cancelInProgressNotification")
        cancelCallNotification(CALL_IN_PROGRESS_NOTIFICATION_ID)
    }

    fun cancelInboundNotification() {
        Log.d("NotificationManager", "cancelInboundNotification")
        cancelCallNotification(CALL_INBOUND_NOTIFICATION_ID)
    }

    fun cancelOutboundNotification() {
        Log.d("NotificationManager", "cancelOutboundNotification")
        cancelCallNotification(CALL_OUTBOUND_NOTIFICATION_ID)
    }

    fun isNotificationDisplayed(notificationId: Int): Boolean {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val activeNotifications = notificationManager.activeNotifications

        val isNotificationVisible = activeNotifications.any { it.id == notificationId }
        Log.d("NotificationManager", "isNotificationDisplayed? $isNotificationVisible")
        return isNotificationVisible
    }

    fun inProgressNotification(
        callId: String,
        startedAt: Long = System.currentTimeMillis()
    ): Notification {
        Log.d("NotificationManager", "inProgressNotification $callId")

        val activityIntent = appIntent.getMainActivity()

        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            activityIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val hangUpPendingIntent = CallActionReceiver.hangUp(context, callId)


        return NotificationCompat.Builder(context, ONGOING_CALL_CHANNEL_ID)
            .setContentTitle(context.getString(R.string.call_in_progress))
            .setSmallIcon(R.drawable.ic_call)
            .setOngoing(true)
            .setSilent(true)
            .setAutoCancel(false)
            .setVibrate(longArrayOf(0L)) // Force no vibration
            .setDefaults(0) // Force no vibration
            .setChronometerCountDown(true)
            .setUsesChronometer(true)
            .setWhen(startedAt)
            .setFullScreenIntent(pendingIntent, true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .addAction(0, context.getString(R.string.hang_up), hangUpPendingIntent)
            .setContentIntent(pendingIntent)
            .build()
    }
}
