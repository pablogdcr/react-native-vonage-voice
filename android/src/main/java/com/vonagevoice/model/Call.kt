package com.vonagevoice.model

sealed class Call {
    data class Inbound(
        val id: String,
        val from: String,
        val status: CallStatus,
        val startedAt: Long? = null
    ) : Call()

    data class Outbound(
        val id: String,
        val to: String,
        val status: CallStatus,
        val startedAt: Long? = null
    ) : Call()

    val isOutbound: Boolean
        get() = this is Outbound

    val isInbound: Boolean
        get() = this is Inbound

    val phoneNumber: String
        get() = when (this) {
            is Inbound -> from
            is Outbound -> to
        }

    val callId: String
        get() = when (this) {
            is Inbound -> id
            is Outbound -> id
        }

    var status: CallStatus
        get() = when (this) {
            is Inbound -> status
            is Outbound -> status
        }
                
    companion object {
        fun fromCallUpdate(existingCall: Call, newStatus: CallStatus): Call {
            return when (existingCall) {
                is Call.Inbound -> existingCall.copy(status = newStatus)
                is Call.Outbound -> existingCall.copy(status = newStatus)
            }
        }
    }
}
