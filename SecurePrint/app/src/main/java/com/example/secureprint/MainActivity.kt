package com.example.secureprint

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.ui.Modifier
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.LaunchedEffect
import androidx.navigation.compose.rememberNavController
import com.example.secureprint.data.auth.AuthState
import com.example.secureprint.data.auth.SessionManager
import com.example.secureprint.navigation.AppNavigation
import com.example.secureprint.navigation.Screen
import com.example.secureprint.ui.theme.SecurePrintTheme

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val authState by SessionManager.authState.collectAsState()
            val navController = rememberNavController()

            LaunchedEffect(Unit) {
                SessionManager.logoutEvent.collect {
                    navController.navigate(Screen.Welcome.route) {
                        popUpTo(0) { inclusive = true }
                    }
                }
            }

            val startDest = when (val state = authState) {
                is AuthState.LoggedIn -> {
                    when (state.role) {
                        "CUSTOMER" -> Screen.CustomerDashboard.route
                        "SHOP" -> Screen.ShopDashboard.route
                        "ADMIN" -> Screen.AdminDashboard.route
                        else -> Screen.Welcome.route
                    }
                }
                is AuthState.LoggedOut -> Screen.Welcome.route
            }

            SecurePrintTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    AppNavigation(
                        modifier = Modifier.padding(innerPadding),
                        navController = navController,
                        startDestination = startDest
                    )
                }
            }
        }
    }
}
