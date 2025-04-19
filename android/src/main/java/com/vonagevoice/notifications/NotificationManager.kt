package com.vonagevoice.notifications

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import com.vonagevoice.R
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import android.app.KeyguardManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.os.Build

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
                    context.getString(R.string.notification_missed_calls),
                    NotificationManager.IMPORTANCE_DEFAULT,
                )
                    .apply {
                        description = context.getString(R.string.notification_missed_calls_desc)
                    },
                NotificationChannel(
                    INCOMING_CALL,
                    context.getString(R.string.notification_incoming_calls),
                    NotificationManager.IMPORTANCE_HIGH,
                )
                    .apply {
                        description = context.getString(R.string.notification_incoming_calls_desc)
                        enableLights(true)
                        lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                        enableVibration(true)
                        setSound(
                            Settings.System.DEFAULT_RINGTONE_URI,
                            AudioAttributes.Builder()
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .setLegacyStreamType(AudioManager.STREAM_RING)
                                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE).build(),
                        )
                        importance = NotificationManager.IMPORTANCE_HIGH
                    },
                NotificationChannel(
                    OUTGOING_CALL,
                    context.getString(R.string.notification_outgoing_calls),
                    NotificationManager.IMPORTANCE_LOW,
                )
                    .apply {
                        description = context.getString(R.string.notification_outgoing_calls_desc)
                    },
                NotificationChannel(
                    ONGOING_CALL,
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
    ): NotificationCompat.Builder {
        Log.d("NotificationManager", "showInboundCallNotification callId: $callId, from: $from")
        val callActivityIntent = appIntent.getCallActivity(
            callId = callId,
            from = from,
            phoneName = "",
            language = "",
            incomingCallImage = null,
            answerCall = false
        )

        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            callActivityIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_CANCEL_CURRENT
        )

        val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val isDeviceUnlocked = !keyguardManager.isKeyguardLocked

        val answerPendingIntent = if (isDeviceUnlocked) {
            PendingIntent.getActivity(
                context,
                0,
                appIntent.getCallActivity(
                    callId = callId,
                    from = from,
                    phoneName = "",
                    language = "",
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

        val notification = NotificationCompat.Builder(context, "inbound_call_channel")
            .setContentTitle(context.getString(R.string.notification_incoming_call_title))
            .setContentText(context.getString(R.string.call_from, from))
            .setSmallIcon(R.drawable.ic_incoming_call)
            .addAction(0, context.getString(R.string.answer), answerPendingIntent)
            .addAction(0, context.getString(R.string.reject), rejectPendingIntent)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(pendingIntent, true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setChannelId(INCOMING_CALL)
            .setOngoing(true)
            .setColorized(true)
            .setColor(0x0B2120)

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(CALL_INBOUND_NOTIFICATION_ID, notification.build())

        return notification
    }

    fun updateInboundCallNotification(
        notification: NotificationCompat.Builder,
        phoneName: String
    ) {
        // Only update if present
        if (isNotificationDisplayed(notificationId = CALL_INBOUND_NOTIFICATION_ID)) {
            notification.setContentText(context.getString(R.string.call_from, phoneName))

            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(CALL_INBOUND_NOTIFICATION_ID, notification.build())
        }
    }

    private fun showInProgressCallNotification(
        callId: String,
        from: String,
        phoneName: String,
        language: String,
        incomingCallImage: String?,
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
                answerCall = false
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
                .setContentTitle(context.getString(R.string.call_in_progress))
                .setContentText(context.getString(R.string.call_duration, phoneName, time))
                .setSilent(true)
                .setSmallIcon(R.drawable.ic_call)
                .addAction(0, context.getString(R.string.hang_up), hangUpPendingIntent)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_MIN)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setOngoing(true)
                .setSound(null)
                .setVibrate(null)
                .setVisibility(NotificationCompat.VISIBILITY_SECRET)
                .setChannelId(ONGOING_CALL)
                .build()

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(CALL_IN_PROGRESS_NOTIFICATION_ID, notification)
    }

    fun showMissedCallNotification(from: String) {
        Log.d("NotificationManager", "showMissedCallNotification from: $from")
        val intent = appIntent.getMainActivity()

        val pendingIntent =
            PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        val notification =
            NotificationCompat.Builder(context, MISSED_CALL)
                .setContentTitle(context.getString(R.string.notification_missed_calls))
                .setContentText(context.getString(R.string.notification_missed_calls_desc, from))
                .setSmallIcon(R.drawable.ic_missed_call)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(pendingIntent)
                .setChannelId(OUTGOING_CALL)
                .build()

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(CALL_OUTBOUND_NOTIFICATION_ID, notification)
    }

    fun showNotificationAndStartCallTimer(
        callId: String,
        from: String,
        phoneName: String,
        language: String,
        incoming_call_image: String?,
    ): Job {
        Log.d(
            "NotificationManager",
            "showNotificationAndStartCallTimer callId: $callId, from: $from",
        )
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
                .setContentTitle(context.getString(R.string.call_in_progress))
                .setContentText(context.getString(R.string.notification_call_with, from))
                .setSmallIcon(R.drawable.ic_outgoing_call)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setChannelId(OUTGOING_CALL)
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

    fun cancelMissedNotification() {
        Log.d("NotificationManager", "cancelMissedNotification")
        cancelCallNotification(CALL_MISSED_NOTIFICATION_ID)
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
        Log.d("NotificationStatus", "isNotificationDisplayed? $isNotificationVisible")
        return isNotificationVisible
    }
}
