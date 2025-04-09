package com.vonagevoice.auth

data class LoginResponse(val x: String)

interface IVonageAuthenticationService {
    suspend fun login(jwt: String)

    suspend fun logout()

    suspend fun registerVonageVoipToken(newTokenFirebase: String)

    fun setRegion(region: String)
}

data class DeviceId(val value: String)
