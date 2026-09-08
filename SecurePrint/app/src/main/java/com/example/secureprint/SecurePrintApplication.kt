package com.example.secureprint

import android.app.Application
import com.example.secureprint.data.auth.SessionManager

class SecurePrintApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        SessionManager.init(this)
    }
}
