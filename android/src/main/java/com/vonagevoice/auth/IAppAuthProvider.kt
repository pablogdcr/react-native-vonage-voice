package com.vonagevoice.auth

/**
 * Interface for app authentication, required to connect with vonage
 */
interface IAppAuthProvider {
    suspend fun getJwtToken(): String
}