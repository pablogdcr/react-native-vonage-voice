package com.vonagevoice.storage

import android.util.Log
import com.vonagevoice.call.Call
import com.vonagevoice.call.CallStatus
import com.vonagevoice.utils.nowDate

class CallRepository {
    private val calls: MutableList<Call> = mutableListOf()

    /**
     * Adds a new outbound call to the call list.
     *
     * When initiating an outbound call, we immediately add it to the list with:
     * - the given call ID and phone number,
     * - a status set to [CallStatus.RINGING],
     * - and a start timestamp set to the current time.
     *
     * @param callId The unique identifier of the outbound call.
     * @param phoneNumber The destination phone number for the call.
     */
    fun newOutbound(callId: String, phoneNumber: String) {
        calls.add(
            Call.Outbound(
                id = callId,
                to = phoneNumber,
                status = CallStatus.RINGING,
                startedAt = nowDate(),
            )
        )
    }

    /**
     * Adds a new inbound call to the call list.
     *
     * When receiving an inbound call, we add it to the list with:
     * - the given call ID (the phone number may not be known yet),
     * - a status set to [CallStatus.RINGING],
     * - and a `startedAt` timestamp set to `null` because the call hasn't been answered yet.
     *
     * The phone number can be updated later via [setInboundPhoneNumber], and the timestamp will be
     * set via [answerInboundCall] when the call is answered.
     *
     * @param callId The unique identifier of the inbound call.
     */
    fun newInbound(callId: String, from: String?) {
        calls.add(
            Call.Inbound(
                id = callId,
                from = from ?: "",
                status = CallStatus.RINGING,
                startedAt = null,
            )
        )
    }

    /**
     * Marks an inbound call as answered by updating its status and start time.
     *
     * This is called when the user accepts the incoming call. We update:
     * - the call's status to [CallStatus.ANSWERED]
     * - and the start timestamp to the current time.
     *
     * @param callId The unique identifier of the inbound call to update.
     */
    fun answerInboundCall(callId: String) {
        Log.d("CallRepository", "answerInboundCall callId: $callId")
        val index = calls.indexOfFirst { it is Call.Inbound && it.id == callId }
        if (index != -1) {
            val inboundCall = calls[index] as Call.Inbound
            val updatedCall = inboundCall.copy(status = CallStatus.ANSWERED, startedAt = nowDate())
            calls[index] = updatedCall
            Log.d("CallRepository", "answerInboundCall callId: $callId")
        } else {
            throw IllegalStateException("answerInboundCall can't find call $callId. Cannot update status and startedAt")
        }
    }

    /**
     * Vonage doesn't provide the caller's phone number immediately for inbound calls. We store the
     * call in a list and update its phone number later when it becomes available.
     *
     * @param callId The unique ID of the call to update.
     * @param phoneNumber The phone number to set for the corresponding inbound call.
     */
    fun setInboundPhoneNumber(callId: String, phoneNumber: String) {
        val index = calls.indexOfFirst { it is Call.Inbound && it.id == callId }
        if (index != -1) {
            val inboundCall = calls[index] as Call.Inbound
            val updatedCall = inboundCall.copy(from = phoneNumber)
            calls[index] = updatedCall
        }
    }

    fun getCall(callId: String): Call? {
        Log.d("CallRepository", "getCall callId: $callId , calls: $calls")
        return calls.find { it.id == callId }
    }

    /**
     * Removes a call (inbound or outbound) from the list based on the given call ID.
     *
     * This is typically called when a call has been hung up and should no longer be tracked.
     *
     * @param callId The unique identifier of the call to remove.
     */
    fun removeHangedUpCall(callId: String) {
        calls.removeAll { it.id == callId }
    }

    fun getActiveCall(): Call? {
        return calls.find { it.status == CallStatus.ANSWERED }
    }
}
