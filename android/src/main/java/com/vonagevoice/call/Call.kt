package com.vonagevoice.call

sealed class Call {
    abstract val id: String
    abstract val phoneNumber: String
    abstract val status: CallStatus
    abstract val startedAt: Double?

    val isOutbound: Boolean
        get() = this is Outbound

    val isInbound: Boolean
        get() = this is Inbound

    data class Inbound(
        override val id: String,
        val from: String,
        override val status: CallStatus,
        override val startedAt: Double? = null,
    ) : Call() {
        override val phoneNumber: String
            get() = from
    }

    data class Outbound(
        override val id: String,
        val to: String,
        override val status: CallStatus,
        override val startedAt: Double? = null,
    ) : Call() {
        override val phoneNumber: String
            get() = to
    }

    fun withUpdatedStatus(newStatus: CallStatus): Call =
        when (this) {
            is Inbound -> copy(status = newStatus)
            is Outbound -> copy(status = newStatus)
        }

    fun withStartedAt(startTimestamp: Double): Call =
        when (this) {
            is Inbound -> copy(startedAt = startTimestamp)
            is Outbound -> copy(startedAt = startTimestamp)
        }
}
