package com.vonagevoice.call

enum class CallStatus {
    RINGING,
    ANSWERED,
    RECONNECTING,
    COMPLETED;

    companion object {
        fun fromString(status: String): CallStatus = when (status.uppercase()) {
            "RINGING" -> RINGING
            "ANSWERED" -> ANSWERED
            "RECONNECTING" -> RECONNECTING
            "COMPLETED" -> COMPLETED
            else -> throw IllegalArgumentException("Unknown call status: $status")
        }
    }

    override fun toString(): String = name.lowercase()
}