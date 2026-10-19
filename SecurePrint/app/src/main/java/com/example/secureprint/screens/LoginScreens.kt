package com.example.secureprint.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.secureprint.R
import com.example.secureprint.ui.login.LoginUiState
import com.example.secureprint.ui.login.LoginViewModel

@Composable
fun CustomerLoginScreen(
    onLoginSuccess: (String, String) -> Unit,
    onRegisterClick: () -> Unit,
    viewModel: LoginViewModel = viewModel()
) {
    LoginBaseScreen(
        title = stringResource(R.string.customer_login),
        onLoginSuccess = onLoginSuccess,
        onRegisterClick = onRegisterClick,
        viewModel = viewModel
    )
}

@Composable
fun ShopLoginScreen(
    onLoginSuccess: (String, String) -> Unit,
    onRegisterClick: () -> Unit,
    viewModel: LoginViewModel = viewModel()
) {
    LoginBaseScreen(
        title = stringResource(R.string.shop_login),
        onLoginSuccess = onLoginSuccess,
        onRegisterClick = onRegisterClick,
        viewModel = viewModel
    )
}

@Composable
fun AdminLoginScreen(
    onLoginSuccess: (String, String) -> Unit,
    viewModel: LoginViewModel = viewModel()
) {
    LoginBaseScreen(
        title = stringResource(R.string.admin_login),
        onLoginSuccess = onLoginSuccess,
        onRegisterClick = null,
        viewModel = viewModel
    )
}

@Composable
fun LoginBaseScreen(
    title: String,
    onLoginSuccess: (String, String) -> Unit,
    onRegisterClick: (() -> Unit)?,
    viewModel: LoginViewModel
) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    val uiState = viewModel.uiState

    LaunchedEffect(uiState) {
        if (uiState is LoginUiState.Success) {
            onLoginSuccess(uiState.response.role, uiState.response.access_token)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.headlineLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )

        Spacer(modifier = Modifier.height(32.dp))

        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("Email") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("Password") },
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        Spacer(modifier = Modifier.height(32.dp))

        if (uiState is LoginUiState.Error) {
            Text(
                text = uiState.message,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.padding(bottom = 16.dp)
            )
        }

        Button(
            onClick = { viewModel.login(email, password) },
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            shape = RoundedCornerShape(16.dp),
            enabled = uiState !is LoginUiState.Loading
        ) {
            if (uiState is LoginUiState.Loading) {
                CircularProgressIndicator(color = MaterialTheme.colorScheme.onPrimary)
            } else {
                Text(text = "Login", style = MaterialTheme.typography.labelLarge)
            }
        }
        
        if (onRegisterClick != null) {
            TextButton(onClick = onRegisterClick) {
                Text("Don't have an account? Register")
            }
        }

        ApiTargetBadge()
    }
}

@Composable
fun ApiTargetBadge() {
    val context = androidx.compose.ui.platform.LocalContext.current
    var showDialog by remember { mutableStateOf(false) }
    var currentEnv by remember { mutableStateOf(com.example.secureprint.data.api.ApiConfig.currentEnvironment) }
    var currentUrl by remember { mutableStateOf(com.example.secureprint.data.api.ApiConfig.baseUrl) }

    Surface(
        onClick = { showDialog = true },
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f),
        modifier = Modifier.padding(top = 16.dp)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Target: ${if (currentEnv == com.example.secureprint.data.api.ApiConfig.TargetEnvironment.PHYSICAL_DEVICE) "Physical (127.0.0.1:8000)" else "Emulator (10.0.2.2:8000)"}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(text = "⚙️", style = MaterialTheme.typography.labelSmall)
        }
    }

    if (showDialog) {
        AlertDialog(
            onDismissRequest = { showDialog = false },
            title = { Text("API Target Configuration") },
            text = {
                Column {
                    Text(
                        text = "Active Base URL:\n$currentUrl",
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = "Select test environment:",
                        style = MaterialTheme.typography.bodyMedium
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Button(
                        onClick = {
                            com.example.secureprint.data.api.ApiConfig.setEnvironment(
                                context,
                                com.example.secureprint.data.api.ApiConfig.TargetEnvironment.PHYSICAL_DEVICE
                            )
                            currentEnv = com.example.secureprint.data.api.ApiConfig.currentEnvironment
                            currentUrl = com.example.secureprint.data.api.ApiConfig.baseUrl
                            showDialog = false
                        },
                        modifier = Modifier.fillMaxWidth(),
                        colors = if (currentEnv == com.example.secureprint.data.api.ApiConfig.TargetEnvironment.PHYSICAL_DEVICE)
                            ButtonDefaults.buttonColors()
                        else
                            ButtonDefaults.outlinedButtonColors()
                    ) {
                        Text("Physical Phone via USB (127.0.0.1:8000)")
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Button(
                        onClick = {
                            com.example.secureprint.data.api.ApiConfig.setEnvironment(
                                context,
                                com.example.secureprint.data.api.ApiConfig.TargetEnvironment.EMULATOR
                            )
                            currentEnv = com.example.secureprint.data.api.ApiConfig.currentEnvironment
                            currentUrl = com.example.secureprint.data.api.ApiConfig.baseUrl
                            showDialog = false
                        },
                        modifier = Modifier.fillMaxWidth(),
                        colors = if (currentEnv == com.example.secureprint.data.api.ApiConfig.TargetEnvironment.EMULATOR)
                            ButtonDefaults.buttonColors()
                        else
                            ButtonDefaults.outlinedButtonColors()
                    ) {
                        Text("Android Emulator (10.0.2.2:8000)")
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showDialog = false }) { Text("Close") }
            }
        )
    }
}

