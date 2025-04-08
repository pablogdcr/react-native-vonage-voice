package com.vonagevoice.deprecated

/*
class VonageConnectionService : ConnectionService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val activeConnections = mutableMapOf<String, VonageConnection>()

    private val callController: CallController by inject()

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle,
        request: ConnectionRequest,
    ): Connection {
        val callId =
            request.extras.getString("call_id")
                ?: throw IllegalStateException("No call ID provided")
        val phoneNumber = request.extras.getString(TelecomManager.EXTRA_INCOMING_CALL_ADDRESS) ?: ""

        return VonageConnection(callId, phoneNumber).also { activeConnections[callId] = it }
    }

    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle,
        request: ConnectionRequest,
    ): Connection {
        val callId =
            request.extras.getString("call_id")
                ?: throw IllegalStateException("No call ID provided")
        val phoneNumber = request.address?.schemeSpecificPart ?: ""

        return VonageConnection(callId, phoneNumber).also { activeConnections[callId] = it }
    }

    inner class VonageConnection(private val callId: String, private val phoneNumber: String) :
        Connection() {

        init {
            connectionProperties = PROPERTY_SELF_MANAGED
            audioModeIsVoip = true
            setAddress(Uri.fromParts("tel", phoneNumber, null), TelecomManager.PRESENTATION_ALLOWED)
        }

        override fun onAnswer() {
            super.onAnswer()
            scope.launch {
                val call = callController.activeCalls.first()[callId]
                if (call != null) {
                    setActive()
                } else {
                    setDisconnected(DisconnectCause(DisconnectCause.ERROR))
                }
            }
        }

        override fun onReject() {
            super.onReject()
            scope.launch {
                val call = callController.activeCalls.first()[callId]
                if (call != null) {
                    setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
                }
            }
        }

        override fun onDisconnect() {
            super.onDisconnect()
            scope.launch {
                val call = callController.activeCalls.first()[callId]
                if (call != null) {
                    setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
                }
            }
            activeConnections.remove(callId)
        }

        override fun onHold() {
            super.onHold()
            setOnHold()
        }

        override fun onUnhold() {
            super.onUnhold()
            setActive()
        }

        override fun onPlayDtmfTone(c: Char) {
            super.onPlayDtmfTone(c)
          callController.sendDTMF(c.toString()) { error ->
                if (error != null) {
                    // Handle DTMF error
                }
            }
        }

        override fun onShowIncomingCallUi() {
            super.onShowIncomingCallUi()
            setRinging()
        }

        override fun onStateChanged(state: Int) {
            super.onStateChanged(state)
            when (state) {
                STATE_ACTIVE -> {
                    audioModeIsVoip = true
                }
                STATE_DISCONNECTED -> {
                    destroy()
                }
            }
        }
    }

    companion object {
        fun getConnection(callId: String): VonageConnection? {
            return activeConnections[callId]
        }
    }
}

 */