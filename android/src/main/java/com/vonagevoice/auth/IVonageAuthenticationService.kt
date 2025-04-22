package com.vonagevoice.auth

interface IVonageAuthenticationService {
    suspend fun login(jwt: String)

    suspend fun logout()

    suspend fun registerVonageVoipToken(newTokenFirebase: String)

    fun setRegion(region: String)
}
