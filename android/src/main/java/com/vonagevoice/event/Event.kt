package com.vonagevoice.event

enum class Event(val value: String) {
    CALL_EVENTS("callEvents"),
    REGISTER("register"),
    VOIP_TOKEN_INVALIDATED("voipTokenInvalidated"),
    AUDIO_ROUTE_CHANGED("audioRouteChanged"),
    MUTE_CHANGED("muteChanged");

    companion object {
        fun supportedEvents(): List<String> = values().map { it.value }
    }
}
