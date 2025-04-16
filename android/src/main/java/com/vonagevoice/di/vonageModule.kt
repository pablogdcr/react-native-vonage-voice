package com.vonagevoice.di

import com.vonage.android_core.VGClientInitConfig
import com.vonage.clientcore.core.api.LoggingLevel
import com.vonage.voice.api.VoiceClient
import com.vonagevoice.auth.IVonageAuthenticationService
import com.vonagevoice.auth.VonageAuthenticationService
import com.vonagevoice.call.CallActionsHandler
import com.vonagevoice.call.ICallActionsHandler
import com.vonagevoice.js.EventEmitter
import com.vonagevoice.audio.SpeakerController
import com.vonagevoice.notifications.NotificationManager
import com.vonagevoice.storage.CallRepository
import com.vonagevoice.storage.VonageStorage
import org.koin.core.module.dsl.singleOf
import org.koin.dsl.bind
import org.koin.dsl.module

/**
 * Defines a Koin module that provides dependency injection for various services and components
 * related to Vonage functionality.
 *
 * This module is used to configure and provide instances of several classes in the Vonage
 * functionality, including services, controllers, storage, authentication, and event handling.
 * Each service is provided as a singleton to ensure that only one instance of each service
 * is used throughout the application.
 */
val vonageModule = module {
    singleOf(::SpeakerController)
    single { VoiceClient(ctx = get(), VGClientInitConfig(loggingLevel = LoggingLevel.Error)) }
    singleOf(::VonageAuthenticationService) bind IVonageAuthenticationService::class
    singleOf(::CallActionsHandler) bind ICallActionsHandler::class
    singleOf(::EventEmitter)
    singleOf(::VonageStorage)
    singleOf(::CallRepository)
    singleOf(::NotificationManager)
}
