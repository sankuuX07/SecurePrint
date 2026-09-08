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
    }
}
