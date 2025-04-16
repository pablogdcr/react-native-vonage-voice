package com.vonagevoice.deprecated

sealed class Call {
    data class Inbound(
        val id: String,
        val from: String,
        val status: CallStatus,
        val startedAt: Long? = null,
    ) : Call()

    data class Outbound(
        val id: String,
        val to: String,
        val status: CallStatus,
        val startedAt: Long? = null,
    ) : Call()

    val isOutbound: Boolean
        get() = this is Outbound

    val isInbound: Boolean
        get() = this is Inbound

    val phoneNumber: String
        get() =
            when (this) {
                is Inbound -> from
                is Outbound -> to
            }

    val sstartedAt: Long?
        get() =
            when (this) {
                is Inbound -> startedAt
                is Outbound -> startedAt
            }

    val callId: String
        get() =
            when (this) {
                is Inbound -> id
                is Outbound -> id
            }

    val sstatus: CallStatus
        get() =
            when (this) {
                is Inbound -> status
                is Outbound -> status
            }

    companion object {
        fun fromCallUpdate(existingCall: Call, newStatus: CallStatus): Call {
            return when (existingCall) {
                is Inbound -> existingCall.copy(status = newStatus)
                is Outbound -> existingCall.copy(status = newStatus)
            }
        }
    }
}
