package com.vonagevoice.call

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

class ProcessVonageCallWorker(
    context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams), KoinComponent {
    private val callActionsHandler: ICallActionsHandler by inject()

    override suspend fun doWork(): Result {
        val remoteMessageStr = inputData.getString("remoteMessageStr") ?: return Result.failure()

        return try {
            callActionsHandler.processPushCallInvite(remoteMessageStr)
            Result.success()
        } catch (e: Exception) {
            Log.e("ProcessVonageCallWorker", "Error: ${e.message}", e)
            Result.retry()
        }
    }

    private fun String.toMap(): Map<String, String> {
        return this.removePrefix("{").removeSuffix("}")
            .split(",")
            .map {
                val (key, value) = it.split("=")
                key.trim() to value.trim()
            }.toMap()
    }
}
