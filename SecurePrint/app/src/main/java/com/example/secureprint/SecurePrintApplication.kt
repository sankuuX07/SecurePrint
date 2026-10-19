package com.example.secureprint

import android.app.Application
import com.example.secureprint.data.api.ApiConfig
import com.example.secureprint.data.auth.SessionManager

class SecurePrintApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ApiConfig.init(this)
        SessionManager.init(this)
    }
}
