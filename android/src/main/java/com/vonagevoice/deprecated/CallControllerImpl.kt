package com.vonagevoice.deprecated

// import com.vonage.android_core.voice.VGVoiceClientDelegate

// import com.vonagevoice.utils.VGLogger

/*
@OptIn(ExperimentalCoroutinesApi::class)
class CallControllerImpl
private constructor(
    private val context: Context

    // private val logger: VGLogger? = null

) : CallController, VGVoiceCallbackAPI, KoinComponent {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val client =
        VoiceClient(this.context, VGClientInitConfig(loggingLevel = LoggingLevel.Error))

    private val telecomHelper: TelecomHelper by inject()

    // Flow controllers

    private val _calls = MutableSharedFlow<Call>()

    private val _callUpdates = MutableSharedFlow<Pair<String, CallStatus>>()

    private val _activeCalls = MutableStateFlow<Map<String, Call>>(emptyMap())

    override val calls: Flow<Call> = _calls.asSharedFlow()

    override val activeCalls = _activeCalls.asStateFlow()

    private var audioFocusRequest: AudioFocusRequest? = null

    init {

        // Initialize Vonage client

        // client = if (logger != null) {

        //     VoiceClient(VGClientInitConfig(logLevel = VGLogLevel.ERROR, customLoggers =

        // listOf(logger)))

        // } else {

        //            VoiceClient(VGClientInitConfig(loggingLevel = VGLogLevel.ERROR))

        // }

        // Load saved region

        context
            .getSharedPreferences("vonage_prefs", Context.MODE_PRIVATE)
            .getString("vonage.region", null)
            ?.let { region ->
                when (region) {
                    "EU" -> client.setConfig(VGClientConfig(region = ClientConfigRegion.EU))

                    "AP" -> client.setConfig(VGClientConfig(region = ClientConfigRegion.AP))

                    else -> client.setConfig(VGClientConfig(region = ClientConfigRegion.US))
                }
            }

        // Setup call monitoring

        scope.launch {
            calls
                .flatMapLatest { call ->
                    _callUpdates
                        .filter { it.first == call.callId }
                        .map { Call.fromCallUpdate(call, it.second) }
                        .onStart { emit(call) }
                        .distinctUntilChanged { old, new -> old.status == new.status }
                }
                .collect { call ->
                    when (call.status) {
                        CallStatus.COMPLETED ->
                            _activeCalls.update { calls ->
                                calls.toMutableMap().apply { remove(call.callId) }
                            }

                        else ->
                            _activeCalls.update { calls ->
                                calls.toMutableMap().apply { put(call.callId, call) }
                            }
                    }
                }
        }
    }

    override fun updateSessionToken(token: String?, completion: ((Exception?) -> Unit)?) {

        if (token == null || token.isEmpty()) {

            client.deleteSession { error -> completion?.invoke(error) }

            return
        }

        client.createSession(token) { error, session ->
            if (error != null) {

                // logger?.log(VGLogLevel.WARN, "Failed to create session: $error")

                completion?.invoke(error)
            } else {

                completion?.invoke(null)
            }
        }
    }

    override fun startOutboundCall(
        context: Map<String, String>,
        completion: (Exception?, String?) -> Unit,
    ) {

        client.serverCall(context) { error, callId ->
            if (error != null) {

                completion(error, null)

                return@serverCall
            }

            _calls.tryEmit(
                Call.Outbound(
                    id = callId!!,
                    to = context["to"] ?: "unknown",
                    status = CallStatus.RINGING,
                )
            )

            completion(null, callId)
        }
    }

    override fun registerPushToken(token: String, callback: (Exception?, String?) -> Unit) {

        client.registerDevicePushToken(token) { error, deviceId -> callback(error, deviceId) }
    }

    override fun unregisterPushToken(deviceId: String, callback: (Exception?) -> Unit) {

        client.unregisterDevicePushToken(deviceId) { error -> callback(error) }
    }

    override fun toggleNoiseSuppression(call: Call, isOn: Boolean) {

        if (isOn) {

            client.enableNoiseSuppression(call.callId) { /* Handle error if needed */ }
        } else {

            client.disableNoiseSuppression(call.callId) { /* Handle error if needed */ }
        }
    }

    override fun setAudioDevice(deviceId: String, completion: (Exception?) -> Unit) {

        try {

            //            AudioManager.

            completion(null)
        } catch (e: Exception) {

            completion(e)
        }
    }

    override fun setRegion(region: String?) {

        val config =
            when (region) {
                "EU" -> VGClientConfig(region = ClientConfigRegion.EU)

                "AP" -> VGClientConfig(region = ClientConfigRegion.AP)

                else -> VGClientConfig(region = ClientConfigRegion.US)
            }

        context
            .getSharedPreferences("vonage_prefs", Context.MODE_PRIVATE)
            .edit()
            .putString("vonage.region", region ?: "US")
            .apply()

        client.setConfig(config)
    }

    override fun mute(callId: String, completion: (Exception?) -> Unit) {

        activeCalls.value[callId]?.let { call ->
            client.mute(call.callId) { error -> completion(error) }
        } ?: completion(IllegalStateException("No active call found"))
    }

    override fun unmute(callId: String, completion: (Exception?) -> Unit) {

        activeCalls.value[callId]?.let { call ->
            client.unmute(call.callId) { error -> completion(error) }
        } ?: completion(IllegalStateException("No active call found"))
    }

    override fun sendDTMF(dtmf: String, completion: (Exception?) -> Unit) {

        activeCalls.value.values.firstOrNull()?.let { call ->
            client.sendDTMF(call.callId, dtmf) { error -> completion(error) }
        } ?: completion(IllegalStateException("No active call found"))
    }

    override fun reconnectCall(callId: String, completion: (Exception?) -> Unit) {

        client.reconnectCall(callId) { error ->
            if (error == null) {

                _callUpdates.tryEmit(callId to CallStatus.ANSWERED)
            }

            completion(error)
        }
    }

    override fun saveDebugInfo(info: String) {

        context
            .getSharedPreferences("vonage_prefs", Context.MODE_PRIVATE)
            .edit {
                putString("vonage.debug.info", info)
            }
    }

    override fun resetCallInfo() {

        // Implement any call info reset logic here

    }

    // VGVoiceClientDelegate implementation

    // override fun onVoiceClientStateChanged(state: VGClientState) {

    //     // Handle client state changes

    // }

    // override fun onVoiceClientError(error: VGError) {

    //     logger?.log(VGLogLevel.ERROR, "Voice client error: $error")

    // }

    override fun onCallInvite(callId: String, from: String) {

        _calls.tryEmit(Call.Inbound(id = callId, from = from, status = CallStatus.RINGING))

        telecomHelper.showIncomingCall(callId, from)
    }

    override fun onCallHangup(callId: String, reason: VGHangupReason) {

        _callUpdates.tryEmit(callId to CallStatus.COMPLETED)

        telecomHelper.endCall(callId)
    }

    override fun onCallMediaTimeout(callId: String) {

        _callUpdates.tryEmit(callId to CallStatus.COMPLETED)

        telecomHelper.endCall(callId)
    }

    override fun onCallAnswered(callId: String) {

        _callUpdates.tryEmit(callId to CallStatus.ANSWERED)
    }

    override fun onCallReconnecting(callId: String) {

        _callUpdates.tryEmit(callId to CallStatus.RECONNECTING)
    }

    override fun onCallReconnected(callId: String) {

        _callUpdates.tryEmit(callId to CallStatus.ANSWERED)
    }

    private fun requestAudioFocus() {

        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

            val focusRequest =
                AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                    )
                    .setAcceptsDelayedFocusGain(true)
                    .setOnAudioFocusChangeListener {}
                    .build()

            audioFocusRequest = focusRequest

            audioManager.requestAudioFocus(focusRequest)
        } else {

            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                null,
                AudioManager.STREAM_VOICE_CALL,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
            )
        }
    }

    private fun abandonAudioFocus() {

        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

            audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }

            audioFocusRequest = null
        } else {

            @Suppress("DEPRECATION") audioManager.abandonAudioFocus(null)
        }
    }
}

 */
