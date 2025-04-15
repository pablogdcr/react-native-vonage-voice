package com.vonagevoice.di

import com.vonage.android_core.VGClientInitConfig
import com.vonage.clientcore.core.api.LoggingLevel
import com.vonage.voice.api.VoiceClient
import com.vonagevoice.auth.IVonageAuthenticationService
import com.vonagevoice.auth.VonageAuthenticationService
import com.vonagevoice.call.ICallActionsHandler
import com.vonagevoice.call.CallActionsHandler
import com.vonagevoice.call.CallConnection
import com.vonagevoice.deprecated.TelecomHelper
import com.vonagevoice.js.EventEmitter
import com.vonagevoice.speakers.SpeakerController
import com.vonagevoice.storage.CallRepository
import com.vonagevoice.storage.VonageStorage
import org.koin.core.module.dsl.singleOf
import org.koin.dsl.bind
import org.koin.dsl.module

val vonageModule = module {
    single { TelecomHelper(context = get(), appName = "Allo Android Phone Account") }
    singleOf(::SpeakerController)
    single { VoiceClient(ctx = get(), VGClientInitConfig(loggingLevel = LoggingLevel.Error)) }
    singleOf(::VonageAuthenticationService) bind IVonageAuthenticationService::class
    singleOf(::CallActionsHandler) bind ICallActionsHandler::class
    singleOf(::CallConnection)
    singleOf(::EventEmitter)
    singleOf(::VonageStorage)
    singleOf(::CallRepository)
}
