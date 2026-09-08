package com.example.secureprint.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.secureprint.data.model.RegisterRequest
import com.example.secureprint.ui.register.RegisterUiState
import com.example.secureprint.ui.register.RegisterViewModel

@Composable
fun CustomerRegisterScreen(
    onRegisterSuccess: () -> Unit,
    onBackToLogin: () -> Unit,
    viewModel: RegisterViewModel = viewModel()
) {
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    
    val uiState = viewModel.uiState

    LaunchedEffect(uiState) {
        if (uiState is RegisterUiState.Success) {
            onRegisterSuccess()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "Create Account",
            style = MaterialTheme.typography.headlineLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )

        Spacer(modifier = Modifier.height(32.dp))

        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            label = { Text("Full Name") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("Email") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = phone,
            onValueChange = { phone = it },
            label = { Text("Phone Number") },
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

        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = confirmPassword,
            onValueChange = { confirmPassword = it },
            label = { Text("Confirm Password") },
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        Spacer(modifier = Modifier.height(32.dp))

        if (uiState is RegisterUiState.Error) {
            Text(text = uiState.message, color = MaterialTheme.colorScheme.error)
            Spacer(modifier = Modifier.height(16.dp))
        }

        Button(
            onClick = {
                if (password == confirmPassword) {
                    viewModel.register(RegisterRequest(name, email, phone, password, "CUSTOMER"))
                }
            },
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = RoundedCornerShape(16.dp),
            enabled = uiState !is RegisterUiState.Loading &&
                name.trim().isNotEmpty() && email.trim().isNotEmpty() &&
                phone.trim().isNotEmpty() && password.trim().isNotEmpty() &&
                confirmPassword.trim().isNotEmpty()
        ) {
            if (uiState is RegisterUiState.Loading) {
                CircularProgressIndicator(color = MaterialTheme.colorScheme.onPrimary)
            } else {
                Text("Create Account")
            }
        }

        TextButton(onClick = onBackToLogin) {
            Text("Already have an account? Login")
        }
    }
}

@Composable
fun ShopRegisterScreen(
    onRegisterSuccess: () -> Unit,
    onBackToLogin: () -> Unit,
    viewModel: RegisterViewModel = viewModel()
) {
    var ownerName by remember { mutableStateOf("") }
    var shopName by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("") }
    var address by remember { mutableStateOf("") }
    var city by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    
    // Pricing state (default to some valid values or blank)
    var priceA4BwSingle by remember { mutableStateOf("1.0") }
    var priceA4BwDouble by remember { mutableStateOf("1.5") }
    var priceA4ColorSingle by remember { mutableStateOf("5.0") }
    var priceA4ColorDouble by remember { mutableStateOf("8.0") }
    var priceA3BwSingle by remember { mutableStateOf("2.0") }
    var priceA3BwDouble by remember { mutableStateOf("3.0") }
    var priceA3ColorSingle by remember { mutableStateOf("10.0") }
    var priceA3ColorDouble by remember { mutableStateOf("15.0") }
    
    val uiState = viewModel.uiState

    LaunchedEffect(uiState) {
        if (uiState is RegisterUiState.Success) {
            onRegisterSuccess()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "Register Your Shop",
            style = MaterialTheme.typography.headlineLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )

        Spacer(modifier = Modifier.height(32.dp))

        OutlinedTextField(
            value = ownerName,
            onValueChange = { ownerName = it },
            label = { Text("Owner Name") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = shopName,
            onValueChange = { shopName = it },
            label = { Text("Shop Name") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("Email") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = phone,
            onValueChange = { phone = it },
            label = { Text("Phone Number") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = address,
            onValueChange = { address = it },
            label = { Text("Address") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = city,
            onValueChange = { city = it },
            label = { Text("City") },
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

        Spacer(modifier = Modifier.height(24.dp))
        Text(
            text = "Pricing Configuration (₹)",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(8.dp))
        
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(value = priceA4BwSingle, onValueChange = { priceA4BwSingle = it }, label = { Text("A4 B/W Single") }, modifier = Modifier.weight(1f))
            OutlinedTextField(value = priceA4BwDouble, onValueChange = { priceA4BwDouble = it }, label = { Text("A4 B/W Double") }, modifier = Modifier.weight(1f))
        }
        Spacer(modifier = Modifier.height(8.dp))
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(value = priceA4ColorSingle, onValueChange = { priceA4ColorSingle = it }, label = { Text("A4 Color Single") }, modifier = Modifier.weight(1f))
            OutlinedTextField(value = priceA4ColorDouble, onValueChange = { priceA4ColorDouble = it }, label = { Text("A4 Color Double") }, modifier = Modifier.weight(1f))
        }
        Spacer(modifier = Modifier.height(8.dp))
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(value = priceA3BwSingle, onValueChange = { priceA3BwSingle = it }, label = { Text("A3 B/W Single") }, modifier = Modifier.weight(1f))
            OutlinedTextField(value = priceA3BwDouble, onValueChange = { priceA3BwDouble = it }, label = { Text("A3 B/W Double") }, modifier = Modifier.weight(1f))
        }
        Spacer(modifier = Modifier.height(8.dp))
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(value = priceA3ColorSingle, onValueChange = { priceA3ColorSingle = it }, label = { Text("A3 Color Single") }, modifier = Modifier.weight(1f))
            OutlinedTextField(value = priceA3ColorDouble, onValueChange = { priceA3ColorDouble = it }, label = { Text("A3 Color Double") }, modifier = Modifier.weight(1f))
        }

        Spacer(modifier = Modifier.height(32.dp))

        if (uiState is RegisterUiState.Error) {
            Text(text = uiState.message, color = MaterialTheme.colorScheme.error)
            Spacer(modifier = Modifier.height(16.dp))
        }

        Button(
            onClick = {
                val pricing = com.example.secureprint.data.model.PricingSetup(
                    priceA4BwSingle.toDoubleOrNull() ?: 0.0,
                    priceA4BwDouble.toDoubleOrNull() ?: 0.0,
                    priceA4ColorSingle.toDoubleOrNull() ?: 0.0,
                    priceA4ColorDouble.toDoubleOrNull() ?: 0.0,
                    priceA3BwSingle.toDoubleOrNull() ?: 0.0,
                    priceA3BwDouble.toDoubleOrNull() ?: 0.0,
                    priceA3ColorSingle.toDoubleOrNull() ?: 0.0,
                    priceA3ColorDouble.toDoubleOrNull() ?: 0.0
                )
                viewModel.register(RegisterRequest(ownerName, email, phone, password, "SHOP", shopName, address, city, pricing))
            },
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = RoundedCornerShape(16.dp),
            enabled = uiState !is RegisterUiState.Loading &&
                ownerName.trim().isNotEmpty() && email.trim().isNotEmpty() &&
                phone.trim().isNotEmpty() && password.trim().isNotEmpty() &&
                shopName.trim().isNotEmpty() && address.trim().isNotEmpty() &&
                city.trim().isNotEmpty()
        ) {
            if (uiState is RegisterUiState.Loading) {
                CircularProgressIndicator(color = MaterialTheme.colorScheme.onPrimary)
            } else {
                Text("Submit for Approval")
            }
        }

        TextButton(onClick = onBackToLogin) {
            Text("Back to Login")
        }
    }
}
