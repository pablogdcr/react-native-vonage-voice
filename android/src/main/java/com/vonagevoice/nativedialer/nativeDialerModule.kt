package com.vonagevoice.nativedialer

import org.koin.core.module.dsl.singleOf
import org.koin.dsl.module

val nativeDialerModule = module {
    single { TelecomHelper(context = get(), appName = "Allo Android Phone Account") }
    singleOf(::CallConnection)
}