package com.example.secureprint.data.api

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ApiConfigTest {

    @Before
    fun setUp() {
        // Reset to physical device default before each test
        ApiConfig.setEnvironment(null, ApiConfig.TargetEnvironment.PHYSICAL_DEVICE)
    }

    @Test
    fun testDefaultBaseUrlIsPhysicalDevice() {
        assertEquals("http://127.0.0.1:8000/", ApiConfig.baseUrl)
        assertEquals(ApiConfig.TargetEnvironment.PHYSICAL_DEVICE, ApiConfig.currentEnvironment)
    }

    @Test
    fun testSwitchToEmulatorEnvironment() {
        ApiConfig.setEnvironment(null, ApiConfig.TargetEnvironment.EMULATOR)
        assertEquals("http://10.0.2.2:8000/", ApiConfig.baseUrl)
        assertEquals(ApiConfig.TargetEnvironment.EMULATOR, ApiConfig.currentEnvironment)
    }

    @Test
    fun testSwitchBackToPhysicalDeviceEnvironment() {
        ApiConfig.setEnvironment(null, ApiConfig.TargetEnvironment.EMULATOR)
        assertEquals("http://10.0.2.2:8000/", ApiConfig.baseUrl)

        ApiConfig.setEnvironment(null, ApiConfig.TargetEnvironment.PHYSICAL_DEVICE)
        assertEquals("http://127.0.0.1:8000/", ApiConfig.baseUrl)
    }

    @Test
    fun testExplicitUrlNormalization() {
        ApiConfig.setExplicitUrl(null, "http://192.168.1.100:8000")
        assertEquals("http://192.168.1.100:8000/", ApiConfig.baseUrl)

        ApiConfig.setExplicitUrl(null, "http://192.168.1.100:8000/")
        assertEquals("http://192.168.1.100:8000/", ApiConfig.baseUrl)
    }

    @Test
    fun testRetrofitClientExposesActiveBaseUrl() {
        ApiConfig.setEnvironment(null, ApiConfig.TargetEnvironment.PHYSICAL_DEVICE)
        assertEquals(ApiConfig.baseUrl, RetrofitClient.currentBaseUrl)

        ApiConfig.setEnvironment(null, ApiConfig.TargetEnvironment.EMULATOR)
        assertEquals(ApiConfig.baseUrl, RetrofitClient.currentBaseUrl)
    }
}
