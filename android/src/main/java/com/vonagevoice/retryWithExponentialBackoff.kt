package com.vonagevoice

import android.util.Log
import kotlinx.coroutines.delay

/**
 * Enhance the retry logic with exponential backoff to avoid overwhelming the server and to handle
 * longer downtimes gracefully
 *
 * use : val result = retryWithExponentialBackoff { api.getData() }
 */
suspend fun <T> retryWithExponentialBackoff(
    times: Int = 3,
    initialDelay: Long = 1_000L,
    maxDelay: Long = 10_000L,
    factor: Double = 2.0,
    block: suspend () -> T,
): T {
    var currentDelay = initialDelay
    repeat(times - 1) {
        try {
            return block()
        } catch (e: Exception) {
            Log.e("retryWithExponentialBackoff", "retryWithExponentialBackoff", e)
        }
        delay(currentDelay)
        currentDelay = (currentDelay * factor).toLong().coerceAtMost(maxDelay)
    }
    return block()
}
