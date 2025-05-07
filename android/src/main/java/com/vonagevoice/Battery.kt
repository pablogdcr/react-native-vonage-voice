package com.vonagevoice

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import androidx.core.net.toUri

fun isBatteryPermissionGranted(context: Context): Boolean {
    val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    val packageName = context.packageName
    val isIgnoringOptimizations = pm.isIgnoringBatteryOptimizations(packageName)
    return isIgnoringOptimizations
}

fun requestBattery(context: Context) {
    if (!isBatteryPermissionGranted(context)) {
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
             data = "package:${context.packageName}".toUri()
        }
        context.startActivity(intent)
    }
}
