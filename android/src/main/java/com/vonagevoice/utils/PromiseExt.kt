package com.vonagevoice.utils

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise

fun Promise.success() {
    val result = Arguments.createMap().apply { putBoolean("success", true) }
    resolve(result)
}

suspend fun Promise.tryBlocking(block: suspend () -> Unit) {
    try {
        block()
        success()
    } catch (e: Exception) {
        reject(e)
    }
}

fun Promise.tryNotBlocking(block: () -> Unit) {
    try {
        block()
        success()
    } catch (e: Exception) {
        reject(e)
    }
}
