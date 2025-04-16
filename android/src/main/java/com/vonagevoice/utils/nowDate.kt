package com.vonagevoice.utils

fun nowDate(): Double {
    val nowTimestamp: Long = System.currentTimeMillis()
    return nowTimestamp.toDouble() / 1000
}
