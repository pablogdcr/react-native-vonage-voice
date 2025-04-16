package com.vonagevoice.call

interface CallLifecycleCallback {
    fun onCallEnded()
}

object CallLifecycleManager {
    var callback: CallLifecycleCallback? = null
}
