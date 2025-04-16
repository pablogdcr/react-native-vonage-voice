package com.vonagevoice.di

import android.content.Context
import android.util.Log
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
    // single { VoiceClient(ctx = get(), VGClientInitConfig(loggingLevel = LoggingLevel.Error)) }
    singleOf(::VonageAuthenticationService) bind IVonageAuthenticationService::class
    singleOf(::CallActionsHandler) bind ICallActionsHandler::class
    singleOf(::CallConnection)
    singleOf(::EventEmitter)
    singleOf(::VonageStorage)
    singleOf(::CallRepository)
}

object VoiceClientHolder {

    @Volatile
    private var instance: VoiceClient? = null

    private val lock = Any()

    // Appelle ceci une seule fois, par exemple dans Application.onCreate()
    fun init(context: Context) {
        Log.d("VoiceClientHolder", "init")
        if (instance == null) {
            synchronized(lock) {
                if (instance == null) {
                    Log.d("VoiceClientHolder", "init create a new instance")
                    instance = VoiceClient(
                        ctx = context.applicationContext,
                        VGClientInitConfig(
                            loggingLevel = LoggingLevel.Error
                        )
                    )
                }
            }
        }
    }

    fun get(): VoiceClient {
        Log.d("VoiceClientHolder", "get")
        return instance ?: throw IllegalStateException("VoiceClient not initialized. Call VoiceClientHolder.init(context) first.")
    }
}
