package com.vonagevoice.deprecated

interface ContactService {
    fun resetCallInfo()

    fun prepareCallInfo(callInfo: CallInfo, supabaseInfo: SupabaseInfo): Contact
}

data class SupabaseInfo(val token: String)

data class CallInfo(val number: Int)

data class Contact(val name: String)