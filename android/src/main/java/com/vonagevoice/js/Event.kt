package com.vonagevoice.js

enum class Event(val value: String) {
    // v1
    CALL_EVENTS("callEvents"),
    REGISTER("register"),
    VOIP_TOKEN_INVALIDATED("voipTokenInvalidated"),
    AUDIO_ROUTE_CHANGED("audioRouteChanged"),  // audio route = output bluetooth, internal device , speaker, etc

    // v2
    MUTE_CHANGED("muteChanged"),
    SessionError("sessionError");

    companion object {
        fun supportedEvents(): List<String> = entries.map { it.value }
    }
}
