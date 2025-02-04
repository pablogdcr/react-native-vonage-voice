package com.vonagevoice

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.Arguments
import android.media.AudioManager
import android.content.Context
import com.vonagevoice.controller.call.CallController
import com.vonagevoice.controller.call.CallControllerImpl
import com.vonagevoice.event.Event
import com.vonagevoice.event.EventEmitter
import com.vonagevoice.event.EventPayload
import com.vonagevoice.model.Call
import kotlinx.coroutines.*
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import android.media.AudioDeviceInfo

class VonageVoiceModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  private val callController: CallController by lazy {
    CallControllerImpl.getInstance(reactApplicationContext)
  }

  init {
    EventEmitter.getInstance().setup(reactContext)
  }

  override fun getName(): String {
    return NAME
  }

  override fun getConstants(): MutableMap<String, Any> {
    return hashMapOf()
  }

  @ReactMethod
  fun saveDebugAdditionalInfo(info: String) {
    callController.saveDebugInfo(info)
  }

  @ReactMethod
  fun setRegion(region: String) {
    callController.setRegion(region)
  }

  @ReactMethod
  fun login(jwt: String, promise: Promise) {
    callController.updateSessionToken(jwt) { error ->
      if (error == null) {
        promise.resolve(Arguments.createMap().apply {
          putBoolean("success", true)
        })
      } else {
        promise.reject("LOGIN_ERROR", error)
      }
    }
  }

  @ReactMethod
  fun logout(promise: Promise) {
    callController.updateSessionToken(null) { error ->
      if (error == null) {
        promise.resolve(Arguments.createMap().apply {
          putBoolean("success", true)
        })
      } else {
        promise.reject("LOGOUT_ERROR", error)
      }
    }
  }

  @ReactMethod
  fun registerVonageVoipToken(token: String, isSandbox: Boolean, promise: Promise) {
    callController.registerPushToken(token) { error, deviceId ->
      if (error == null && deviceId != null) {
        promise.resolve(deviceId)
      } else {
        promise.reject("REGISTER_ERROR", error)
      }
    }
  }

  @ReactMethod
  fun unregisterDeviceTokens(deviceId: String, promise: Promise) {
    callController.unregisterPushToken(deviceId) { error ->
      if (error == null) {
        promise.resolve(Arguments.createMap().apply {
          putBoolean("success", true)
        })
      } else {
        promise.reject("UNREGISTER_ERROR", error)
      }
    }
  }

  @ReactMethod
  fun answerCall(callId: String, promise: Promise) {
    scope.launch {
      try {
        callController.activeCalls.value[callId]?.let { call: Call ->
          // Handle via Telecom framework
          VonageConnectionService.getConnection(callId)?.onAnswer()
          promise.resolve(Arguments.createMap().apply {
            putBoolean("success", true)
          })
        } ?: throw IllegalStateException("No active call found")
      } catch (e: Exception) {
        promise.reject("ANSWER_ERROR", e)
      }
    }
  }

  @ReactMethod
  fun rejectCall(callId: String, promise: Promise) {
    scope.launch {
      try {
        callController.activeCalls.value[callId]?.let { call: Call ->
          VonageConnectionService.getConnection(callId)?.onReject()
          promise.resolve(Arguments.createMap().apply {
            putBoolean("success", true)
          })
        } ?: throw IllegalStateException("No active call found")
      } catch (e: Exception) {
        promise.reject("REJECT_ERROR", e)
      }
    }
  }

  @ReactMethod
  fun hangup(callId: String, promise: Promise) {
    scope.launch {
      try {
        callController.activeCalls.value[callId]?.let { call: Call ->
          VonageConnectionService.getConnection(callId)?.onDisconnect()
          promise.resolve(Arguments.createMap().apply {
            putBoolean("success", true)
          })
        } ?: throw IllegalStateException("No active call found")
      } catch (e: Exception) {
        promise.reject("HANGUP_ERROR", e)
      }
    }
  }

  @ReactMethod
  fun serverCall(to: String, customData: ReadableMap, promise: Promise) {
    val callData = mutableMapOf("to" to to)
    customData.toHashMap().forEach { (key, value) ->
      if (value is String) {
        callData[key] = value
      }
    }

    callController.startOutboundCall(callData) { error, callId ->
      if (error == null && callId != null) {
        promise.resolve(callId)
      } else {
        promise.reject("CALL_ERROR", error)
      }
    }
  }

  @ReactMethod
  fun sendDTMF(dtmf: String, promise: Promise) {
    callController.sendDTMF(dtmf) { error ->
      if (error == null) {
        promise.resolve(Arguments.createMap().apply {
          putBoolean("success", true)
        })
      } else {
        promise.reject("DTMF_ERROR", error)
      }
    }
  }

  @ReactMethod
  fun reconnectCall(callId: String, promise: Promise) {
    callController.reconnectCall(callId) { error ->
      if (error == null) {
        promise.resolve(Arguments.createMap().apply {
          putBoolean("success", true)
        })
      } else {
        promise.reject("RECONNECT_ERROR", error)
      }
    }
  }

  @ReactMethod
  fun getAvailableAudioDevices(promise: Promise) {
    val audioManager = reactApplicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    val devices = audioManager.getDevices(AudioManager.GET_DEVICES_ALL).map { device ->
      Arguments.createMap().apply {
        putString("name", device.productName.toString())
        putString("id", device.id.toString())
        putString("type", device.type.toString())
      }
    }
    promise.resolve(Arguments.createArray().apply {
      devices.forEach { deviceMap -> pushMap(deviceMap) }
    })
  }

  @ReactMethod
  fun setAudioDevice(deviceId: String, promise: Promise) {
    callController.setAudioDevice(deviceId) { error ->
      if (error == null) {
        promise.resolve(Arguments.createMap().apply {
          putBoolean("success", true)
        })
      } else {
        promise.reject("AUDIO_DEVICE_ERROR", error)
      }
    }
  }

  @ReactMethod
  fun subscribeToCallEvents() {
    scope.launch {
      callController.calls.collect { call: Call ->
        EventEmitter.getInstance().sendEvent(
          Event.CALL_EVENTS,
          EventPayload.createCallEventPayload(call)
        )
      }
    }
  }

  @ReactMethod
  fun unsubscribeFromCallEvents() {
    scope.cancel()
  }

  @ReactMethod
  fun addListener(eventName: String) {
    // Required for React Native event emitter
  }

  @ReactMethod
  fun removeListeners(count: Int) {
    // Required for React Native event emitter
  }

  @ReactMethod
  fun mute(callId: String, promise: Promise) {
    scope.launch {
      try {
        callController.activeCalls.value[callId]?.let { call: Call ->
          callController.mute(callId) { error: Exception? ->
            if (error == null) {
              EventEmitter.getInstance().sendEvent(
                Event.MUTE_CHANGED,
                EventPayload.createMuteChangedPayload(true)
              )
              promise.resolve(Arguments.createMap().apply {
                putBoolean("success", true)
              })
            } else {
              promise.reject("MUTE_ERROR", error)
            }
          }
        } ?: throw IllegalStateException("No active call found")
      } catch (e: Exception) {
        promise.reject("MUTE_ERROR", e.toString())
      }
    }
  }

  @ReactMethod
  fun unmute(callId: String, promise: Promise) {
    scope.launch {
      try {
        callController.activeCalls.value[callId]?.let { call: Call ->
          callController.unmute(callId) { error: Exception? ->
            if (error == null) {
              EventEmitter.getInstance().sendEvent(
                Event.MUTE_CHANGED,
                EventPayload.createMuteChangedPayload(false)
              )
              promise.resolve(Arguments.createMap().apply {
                putBoolean("success", true)
              })
            } else {
              promise.reject("UNMUTE_ERROR", error)
            }
          }
        } ?: throw IllegalStateException("No active call found")
      } catch (e: Exception) {
        promise.reject("UNMUTE_ERROR", e.toString())
      }
    }
  }

  @ReactMethod
  fun enableSpeaker(promise: Promise) {
    val audioManager = reactApplicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    audioManager.isSpeakerphoneOn = true
    promise.resolve(Arguments.createMap().apply {
      putBoolean("success", true)
    })
  }

  @ReactMethod
  fun disableSpeaker(promise: Promise) {
    val audioManager = reactApplicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    audioManager.isSpeakerphoneOn = false
    promise.resolve(Arguments.createMap().apply {
      putBoolean("success", true)
    })
  }

  override fun onCatalystInstanceDestroy() {
    super.onCatalystInstanceDestroy()
    scope.cancel() // Cancel all coroutines
    callController.updateSessionToken(null) { _ -> } // Cleanup session
  }

  companion object {
    const val NAME = "VonageVoice"
  }
}
