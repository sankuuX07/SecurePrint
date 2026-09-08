package com.example.secureprint.navigation

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.example.secureprint.data.auth.SessionManager
import com.example.secureprint.screens.*

sealed class Screen(val route: String) {
    object Welcome : Screen("welcome")
    object RoleSelection : Screen("role_selection")
    object CustomerLogin : Screen("customer_login")
    object ShopLogin : Screen("shop_login")
    object AdminLogin : Screen("admin_login")
    object CustomerRegister : Screen("customer_register")
    object ShopRegister : Screen("shop_register")
    object CustomerDashboard : Screen("customer_dashboard")
    object ShopDashboard : Screen("shop_dashboard")
    object MyShopQr : Screen("my_shop_qr")
    object AdminDashboard : Screen("admin_dashboard")
    
    // Phase 8 screens
    object CustomerPrintJobs : Screen("customer_print_jobs")
    object AdminPrintJobs : Screen("admin_print_jobs")
}

@Composable
fun AppNavigation(
    modifier: Modifier = Modifier,
    navController: NavHostController = rememberNavController(),
    startDestination: String = Screen.Welcome.route
) {
    NavHost(
        navController = navController,
        startDestination = startDestination,
        modifier = modifier
    ) {
        composable(Screen.Welcome.route) {
            WelcomeScreen(
                onGetStartedClick = {
                    navController.navigate(Screen.RoleSelection.route)
                }
            )
        }
        
        composable(Screen.RoleSelection.route) {
            RoleSelectionScreen(
                onRoleSelected = { role ->
                    when (role) {
                        "customer" -> navController.navigate(Screen.CustomerLogin.route)
                        "shop" -> navController.navigate(Screen.ShopLogin.route)
                        "admin" -> navController.navigate(Screen.AdminLogin.route)
                    }
                }
            )
        }
        
        composable(Screen.CustomerLogin.route) {
            CustomerLoginScreen(
                onLoginSuccess = { role, token ->
                    SessionManager.saveSession(token, role)
                    navController.navigate(Screen.CustomerDashboard.route) {
                        popUpTo(Screen.Welcome.route) { inclusive = true }
                    }
                },
                onRegisterClick = {
                    navController.navigate(Screen.CustomerRegister.route)
                }
            )
        }
        
        composable(Screen.ShopLogin.route) {
            ShopLoginScreen(
                onLoginSuccess = { role, token ->
                    SessionManager.saveSession(token, role)
                    navController.navigate(Screen.ShopDashboard.route) {
                        popUpTo(Screen.Welcome.route) { inclusive = true }
                    }
                },
                onRegisterClick = {
                    navController.navigate(Screen.ShopRegister.route)
                }
            )
        }
        
        composable(Screen.AdminLogin.route) {
            AdminLoginScreen(
                onLoginSuccess = { role, token ->
                    SessionManager.saveSession(token, role)
                    navController.navigate(Screen.AdminDashboard.route) {
                        popUpTo(Screen.Welcome.route) { inclusive = true }
                    }
                }
            )
        }

        composable(Screen.CustomerRegister.route) {
            CustomerRegisterScreen(
                onRegisterSuccess = {
                    navController.navigate(Screen.CustomerLogin.route) {
                        popUpTo(Screen.CustomerRegister.route) { inclusive = true }
                    }
                },
                onBackToLogin = { navController.popBackStack() }
            )
        }

        composable(Screen.ShopRegister.route) {
            ShopRegisterScreen(
                onRegisterSuccess = {
                    navController.navigate(Screen.ShopLogin.route) {
                        popUpTo(Screen.ShopRegister.route) { inclusive = true }
                    }
                },
                onBackToLogin = { navController.popBackStack() }
            )
        }

        composable(Screen.CustomerDashboard.route) {
            CustomerDashboardScreen(
                onNavigateToShopSelection = { documentId ->
                    navController.navigate("shop_selection/$documentId")
                },
                onNavigateToMyJobs = {
                    navController.navigate(Screen.CustomerPrintJobs.route)
                }
            )
        }

        composable("shop_selection/{documentId}") { backStackEntry ->
            val documentId = backStackEntry.arguments?.getString("documentId") ?: ""
            CustomerShopSelectionScreen(
                documentId = documentId,
                onShopSelected = { shopId, docId ->
                    navController.navigate("print_settings/$shopId/$docId")
                },
                onScanQrClick = {
                    navController.navigate("shop_qr_scanner/$documentId")
                },
                onBack = { navController.popBackStack() }
            )
        }

        composable("shop_qr_scanner/{documentId}") { backStackEntry ->
            val documentId = backStackEntry.arguments?.getString("documentId") ?: ""
            ShopQrScannerScreen(
                documentId = documentId,
                onShopFound = { shopId, docId ->
                    navController.navigate("print_settings/$shopId/$docId") {
                        popUpTo("shop_selection/$docId") { inclusive = false }
                    }
                },
                onBack = { navController.popBackStack() }
            )
        }

        composable("print_settings/{shopId}/{documentId}") { backStackEntry ->
            val shopId = backStackEntry.arguments?.getString("shopId")?.toIntOrNull() ?: 0
            val documentId = backStackEntry.arguments?.getString("documentId") ?: ""
            CustomerPrintSettingsScreen(
                documentId = documentId,
                shopId = shopId,
                onJobCreated = {
                    navController.navigate(Screen.CustomerDashboard.route) {
                        popUpTo(Screen.CustomerDashboard.route) { inclusive = true }
                    }
                },
                onBack = { navController.popBackStack() }
            )
        }

        composable(Screen.ShopDashboard.route) {
            ShopDashboardScreen(
                shopName = null,
                onJobClick = { jobId ->
                    navController.navigate("shop_job_detail/$jobId")
                },
                onMyShopQrClick = {
                    navController.navigate(Screen.MyShopQr.route)
                }
            )
        }

        composable(Screen.MyShopQr.route) {
            MyShopQrScreen(
                onBack = { navController.popBackStack() }
            )
        }

        composable(Screen.AdminDashboard.route) {
            AdminDashboardScreen(
                onNavigateToJobs = {
                    navController.navigate(Screen.AdminPrintJobs.route)
                }
            )
        }
        
        composable(Screen.CustomerPrintJobs.route) {
            CustomerPrintJobsScreen(
                onJobClick = { jobId ->
                    navController.navigate("customer_job_detail/$jobId")
                }
            )
        }
        
        composable("customer_job_detail/{jobId}") { backStackEntry ->
            val jobId = backStackEntry.arguments?.getString("jobId")?.toIntOrNull() ?: 0
            CustomerPrintJobDetailScreen(
                jobId = jobId,
                onBack = { navController.popBackStack() },
                onNavigateToSecureQr = { jId ->
                    navController.navigate("customer_secure_qr/$jId")
                }
            )
        }
        
        composable("customer_secure_qr/{jobId}") { backStackEntry ->
            val jobId = backStackEntry.arguments?.getString("jobId")?.toIntOrNull() ?: 0
            SecurePrintAccessQrScreen(
                jobId = jobId,
                onBack = { navController.popBackStack() }
            )
        }
        
        composable("shop_job_detail/{jobId}") { backStackEntry ->
            val jobId = backStackEntry.arguments?.getString("jobId")?.toIntOrNull() ?: 0
            val accessId = backStackEntry.savedStateHandle.get<String>("accessId")
            
            val accessViewModel: com.example.secureprint.ui.shop.ShopDocumentAccessViewModel = viewModel()
            LaunchedEffect(accessId) {
                if (accessId != null) {
                    accessViewModel.getAccessMetadata(accessId)
                    backStackEntry.savedStateHandle.remove<String>("accessId")
                }
            }
            
            ShopPrintJobDetailScreen(
                jobId = jobId,
                onBack = { navController.popBackStack() },
                onNavigateToSecureScanner = { navController.navigate("shop_secure_scanner/$jobId") },
                accessViewModel = accessViewModel
            )
        }

        composable("shop_secure_scanner/{jobId}") { backStackEntry ->
            ShopSecureAccessScannerScreen(
                onAccessGranted = { accessId ->
                    navController.previousBackStackEntry?.savedStateHandle?.set("accessId", accessId)
                    navController.popBackStack()
                },
                onBack = { navController.popBackStack() }
            )
        }
        
        composable(Screen.AdminPrintJobs.route) {
            AdminPrintJobsScreen(
                onJobClick = { jobId ->
                    navController.navigate("admin_job_detail/$jobId")
                }
            )
        }
        
        composable("admin_job_detail/{jobId}") { backStackEntry ->
            val jobId = backStackEntry.arguments?.getString("jobId")?.toIntOrNull() ?: 0
            AdminPrintJobDetailScreen(
                jobId = jobId,
                onBack = { navController.popBackStack() }
            )
        }
    }
}
