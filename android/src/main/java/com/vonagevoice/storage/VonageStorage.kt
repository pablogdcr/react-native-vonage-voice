package com.vonagevoice.storage

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import android.util.Log
import androidx.core.content.edit

/**
 * A storage class that manages saving, retrieving, and removing user-related data such as region,
 * push notification tokens, and device ID using Android's SharedPreferences.
 *
 * @param context The context to access SharedPreferences.
 */
class VonageStorage(context: Context) {

    companion object {
        private const val REGION_KEY = "region"
        private const val PUSH_TOKEN_KEY = "push_token"
        private const val PUSH_TOKEN_STR_KEY = "push_token_str"
        private const val DEVICE_ID_KEY = "device_id"
    }

    private val sharedPrefs: SharedPreferences =
        context.getSharedPreferences("Vonage_Preferences", Context.MODE_PRIVATE)

    fun saveRegion(region: String?) {
        Log.d("VonageStorage", "saveRegion $region")
        sharedPrefs.edit { putString(REGION_KEY, region ?: "US") }
    }

    fun getRegion(): String {
        val region = sharedPrefs.getString(REGION_KEY, "US") ?: "US"
        Log.d("VonageStorage", "getRegion region: $region")
        return region
    }

    fun savePushToken(token: ByteArray) {
        Log.d("VonageStorage", "savePushToken $token")
        val encoded = Base64.encodeToString(token, Base64.NO_WRAP)
        sharedPrefs.edit { putString(PUSH_TOKEN_KEY, encoded) }
    }

    fun savePushTokenStr(token: String) {
        Log.d("VonageStorage", "savePushTokenStr $token")
        sharedPrefs.edit { putString(PUSH_TOKEN_STR_KEY, token) }
    }

    fun getPushTokenStr(): String? {
        val token = sharedPrefs.getString(PUSH_TOKEN_STR_KEY, "")
        Log.d("VonageStorage", "getPushTokenStr token: $token")
        return token
    }

    fun getPushToken(): ByteArray? {
        val encoded = sharedPrefs.getString(PUSH_TOKEN_KEY, null) ?: return null
        return try {
            Base64.decode(encoded, Base64.NO_WRAP)
        } catch (e: IllegalArgumentException) {
            null
        }
    }

    fun removePushToken() {
        sharedPrefs.edit { remove(PUSH_TOKEN_KEY) }
    }

    fun saveDeviceId(deviceId: String) {
        Log.d("VonageStorage", "saveDeviceId $deviceId")
        sharedPrefs.edit { putString(DEVICE_ID_KEY, deviceId) }
    }

    fun getDeviceId(): String? {
        val deviceId = sharedPrefs.getString(DEVICE_ID_KEY, null)
        Log.d("VonageStorage", "saveDeviceId deviceId: $deviceId")
        return deviceId
    }

    fun removeDeviceId() {
        Log.d("VonageStorage", "removeDeviceId")
        sharedPrefs.edit { remove(DEVICE_ID_KEY) }
    }
}
