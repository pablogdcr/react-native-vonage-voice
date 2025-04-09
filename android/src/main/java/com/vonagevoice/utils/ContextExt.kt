package com.vonagevoice.utils

import android.content.Context
import android.content.Intent

fun Context.sendBroadcast(actionName: String, extras: Map<String, String>) {
    val intent = Intent(actionName)
    extras.forEach { (key, value) ->
        intent.putExtra(key, value)
    }
    sendBroadcast(intent)
}
