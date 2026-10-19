package com.example.secureprint.data.api

import android.content.Context
import android.os.Build
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Centralized, configurable API URL configuration for SecurePrint Android.
 *
 * Supported environments:
 * - Physical Android phone over USB reverse: http://127.0.0.1:8000/ (via 'adb reverse tcp:8000 tcp:8000')
 * - Android emulator: http://10.0.2.2:8000/
 */
object ApiConfig {
    private const val TAG = "ApiConfig"

    const val PHYSICAL_DEVICE_URL = "http://127.0.0.1:8000/"
    const val EMULATOR_URL = "http://10.0.2.2:8000/"

    enum class TargetEnvironment(val baseUrl: String, val label: String) {
        PHYSICAL_DEVICE(PHYSICAL_DEVICE_URL, "Physical Phone (USB reverse 127.0.0.1:8000)"),
        EMULATOR(EMULATOR_URL, "Android Emulator (10.0.2.2:8000)")
    }

    private const val PREFS_NAME = "secureprint_api_config"
    private const val KEY_TARGET_ENV = "target_environment"
    private const val KEY_CUSTOM_URL = "custom_base_url"

    // Default target environment is PHYSICAL_DEVICE as required for USB testing
    @Volatile
    var currentEnvironment: TargetEnvironment = TargetEnvironment.PHYSICAL_DEVICE
        private set

    @Volatile
    var baseUrl: String = PHYSICAL_DEVICE_URL
        private set

    private val _baseUrlState = MutableStateFlow(baseUrl)
    val baseUrlState: StateFlow<String> = _baseUrlState.asStateFlow()

    fun init(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val savedEnv = prefs.getString(KEY_TARGET_ENV, null)
        val customUrl = prefs.getString(KEY_CUSTOM_URL, null)

        if (!customUrl.isNullOrBlank()) {
            baseUrl = ensureTrailingSlash(customUrl)
        } else if (savedEnv != null) {
            currentEnvironment = try {
                TargetEnvironment.valueOf(savedEnv)
            } catch (_: Exception) {
                TargetEnvironment.PHYSICAL_DEVICE
            }
            baseUrl = currentEnvironment.baseUrl
        } else {
            // First run: Default to PHYSICAL_DEVICE
            currentEnvironment = TargetEnvironment.PHYSICAL_DEVICE
            baseUrl = currentEnvironment.baseUrl

            if (isLikelyEmulator()) {
                safeLog(Log.WARN, "Device detected as emulator, but default is PHYSICAL_DEVICE ($PHYSICAL_DEVICE_URL). Switch to EMULATOR if testing on an emulator.")
            }
        }

        _baseUrlState.value = baseUrl
        safeLog(Log.INFO, "Initialized API Base URL: $baseUrl [Environment: ${currentEnvironment.name}]")
    }

    fun setEnvironment(context: Context?, env: TargetEnvironment) {
        currentEnvironment = env
        baseUrl = env.baseUrl
        _baseUrlState.value = baseUrl

        context?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)?.edit()?.apply {
            putString(KEY_TARGET_ENV, env.name)
            remove(KEY_CUSTOM_URL)
            apply()
        }

        safeLog(Log.INFO, "Switched API Base URL: $baseUrl [Environment: ${env.name}]")
    }

    fun setExplicitUrl(context: Context?, url: String) {
        val formatted = ensureTrailingSlash(url)
        baseUrl = formatted
        _baseUrlState.value = baseUrl

        context?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)?.edit()?.apply {
            putString(KEY_CUSTOM_URL, formatted)
            apply()
        }

        safeLog(Log.INFO, "Explicitly configured API Base URL: $baseUrl")
    }

    private fun ensureTrailingSlash(url: String): String {
        return if (url.endsWith("/")) url else "$url/"
    }

    fun isLikelyEmulator(): Boolean {
        return try {
            (Build.FINGERPRINT.startsWith("generic")
                    || Build.FINGERPRINT.startsWith("unknown")
                    || Build.MODEL.contains("google_sdk")
                    || Build.MODEL.contains("Emulator")
                    || Build.MODEL.contains("Android SDK built for x86")
                    || Build.MANUFACTURER.contains("Genymotion")
                    || (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
                    || "google_sdk" == Build.PRODUCT
                    || Build.HARDWARE.contains("goldfish")
                    || Build.HARDWARE.contains("ranchu"))
        } catch (_: Throwable) {
            false
        }
    }

    private fun safeLog(priority: Int, message: String) {
        try {
            when (priority) {
                Log.WARN -> Log.w(TAG, message)
                else -> Log.i(TAG, message)
            }
        } catch (_: Throwable) {
            // In unit tests android.util.Log throws RuntimeException if unmocked
            println("[$TAG] $message")
        }
    }
}
