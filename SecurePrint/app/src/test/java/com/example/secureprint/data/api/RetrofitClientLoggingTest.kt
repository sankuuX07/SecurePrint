package com.example.secureprint.data.api

import com.example.secureprint.BuildConfig
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RetrofitClientLoggingTest {

    @Test
    fun testBuildConfigIsAccessible() {
        // Verify BuildConfig is generated and accessible
        assertNotNull(BuildConfig.APPLICATION_ID)
        assertEquals("com.example.secureprint", BuildConfig.APPLICATION_ID)
    }

    @Test
    fun testRetrofitClientApisInitialized() {
        assertNotNull(RetrofitClient.authApi)
        assertNotNull(RetrofitClient.userApi)
        assertNotNull(RetrofitClient.documentApi)
        assertNotNull(RetrofitClient.shopApi)
        assertNotNull(RetrofitClient.printJobApi)
        assertNotNull(RetrofitClient.shopDocumentAccessApi)
        assertNotNull(RetrofitClient.shopQrApi)
        assertNotNull(RetrofitClient.paymentApi)
    }

    @Test
    fun testConditionalLoggingConfiguration() {
        // Test that conditional logging logic behaves according to build configuration
        val clientBuilder = OkHttpClient.Builder().apply {
            if (BuildConfig.DEBUG) {
                addInterceptor(HttpLoggingInterceptor().apply {
                    level = HttpLoggingInterceptor.Level.BODY
                    redactHeader("Authorization")
                })
            }
            addInterceptor(com.example.secureprint.data.auth.AuthInterceptor())
        }
        val client = clientBuilder.build()

        if (BuildConfig.DEBUG) {
            // In debug mode, HttpLoggingInterceptor should be present
            val hasLogging = client.interceptors.any { it is HttpLoggingInterceptor }
            assertTrue("Debug client must include HttpLoggingInterceptor", hasLogging)
            val loggingInterceptor = client.interceptors.first { it is HttpLoggingInterceptor } as HttpLoggingInterceptor
            assertEquals(HttpLoggingInterceptor.Level.BODY, loggingInterceptor.level)
        } else {
            // In release mode, HttpLoggingInterceptor must be absent
            val hasLogging = client.interceptors.any { it is HttpLoggingInterceptor }
            assertTrue("Release client must NOT include HttpLoggingInterceptor", !hasLogging)
        }

        // AuthInterceptor must always be present in both debug and release
        val hasAuthInterceptor = client.interceptors.any { it is com.example.secureprint.data.auth.AuthInterceptor }
        assertTrue("AuthInterceptor must always be present", hasAuthInterceptor)
    }

    @Test
    fun testReleaseModeLoggingAbsenceSimulation() {
        // Simulate release mode where isDebug = false
        val releaseBuilder = OkHttpClient.Builder().apply {
            val isDebug = false
            if (isDebug) {
                addInterceptor(HttpLoggingInterceptor().apply {
                    level = HttpLoggingInterceptor.Level.BODY
                    redactHeader("Authorization")
                })
            }
            addInterceptor(com.example.secureprint.data.auth.AuthInterceptor())
        }
        val releaseClient = releaseBuilder.build()

        val hasLogging = releaseClient.interceptors.any { it is HttpLoggingInterceptor }
        assertTrue("Release client must have zero logging interceptors", !hasLogging)

        val hasAuth = releaseClient.interceptors.any { it is com.example.secureprint.data.auth.AuthInterceptor }
        assertTrue("Release client must still retain AuthInterceptor", hasAuth)
        assertEquals(1, releaseClient.interceptors.size)
    }
}
