package com.example.secureprint.screens

import android.graphics.Bitmap
import android.graphics.Color
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.secureprint.data.api.RetrofitClient
import com.example.secureprint.data.model.SecureTokenResponse
import com.example.secureprint.data.repository.PrintJobRepository
import com.google.zxing.BarcodeFormat
import com.google.zxing.MultiFormatWriter
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.Duration

sealed class SecureAccessQrUiState {
    object Loading : SecureAccessQrUiState()
    data class Success(val tokenResponse: SecureTokenResponse, val qrBitmap: Bitmap) : SecureAccessQrUiState()
    data class Error(val message: String) : SecureAccessQrUiState()
}

class SecureAccessQrViewModel : ViewModel() {
    private val repository = PrintJobRepository(RetrofitClient.printJobApi)
    
    var uiState by mutableStateOf<SecureAccessQrUiState>(SecureAccessQrUiState.Loading)
        private set
        
    fun generateToken(jobId: Int) {
        uiState = SecureAccessQrUiState.Loading
        viewModelScope.launch {
            try {
                val response = repository.createSecureAccessToken(jobId)
                val bitmap = generateQrCode(response.token, 512, 512)
                uiState = SecureAccessQrUiState.Success(response, bitmap)
            } catch (e: Exception) {
                uiState = SecureAccessQrUiState.Error(e.message ?: "Failed to generate token")
            }
        }
    }
    
    private fun generateQrCode(text: String, width: Int, height: Int): Bitmap {
        val bitMatrix = MultiFormatWriter().encode(text, BarcodeFormat.QR_CODE, width, height)
        val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565)
        for (x in 0 until width) {
            for (y in 0 until height) {
                bmp.setPixel(x, y, if (bitMatrix[x, y]) Color.BLACK else Color.WHITE)
            }
        }
        return bmp
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SecurePrintAccessQrScreen(
    jobId: Int,
    onBack: () -> Unit,
    viewModel: SecureAccessQrViewModel = viewModel()
) {
    val uiState = viewModel.uiState
    var timeRemaining by remember { mutableStateOf("") }
    
    LaunchedEffect(jobId) {
        viewModel.generateToken(jobId)
    }
    
    // Timer UX
    LaunchedEffect(uiState) {
        if (uiState is SecureAccessQrUiState.Success) {
            val expiresAt = ZonedDateTime.parse(uiState.tokenResponse.expires_at)
            while (true) {
                val now = ZonedDateTime.now()
                val duration = Duration.between(now, expiresAt)
                if (duration.isNegative || duration.isZero) {
                    timeRemaining = "Expired"
                    break
                }
                val min = duration.toMinutes()
                val sec = duration.minusMinutes(min).seconds
                timeRemaining = String.format("%02d:%02d", min, sec)
                delay(1000)
            }
        }
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Secure Print Access") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            when (val state = uiState) {
                is SecureAccessQrUiState.Loading -> {
                    CircularProgressIndicator()
                }
                is SecureAccessQrUiState.Success -> {
                    Text(
                        text = "SECURE PRINT ACCESS",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.padding(bottom = 16.dp)
                    )
                    Text(
                        text = "Show this QR code to the shop to securely authorize document printing.",
                        style = MaterialTheme.typography.bodyLarge,
                        modifier = Modifier.padding(bottom = 24.dp)
                    )
                    
                    Image(
                        bitmap = state.qrBitmap.asImageBitmap(),
                        contentDescription = "Secure Access QR Code",
                        modifier = Modifier.size(256.dp)
                    )
                    
                    Spacer(modifier = Modifier.height(24.dp))
                    
                    Text("Expires in: $timeRemaining", fontWeight = FontWeight.Bold, color = if (timeRemaining == "Expired") MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface)
                    
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    Text("Print Job #SP-${jobId}", style = MaterialTheme.typography.bodyMedium)
                }
                is SecureAccessQrUiState.Error -> {
                    Text(state.message, color = MaterialTheme.colorScheme.error)
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(onClick = { viewModel.generateToken(jobId) }) {
                        Text("Retry")
                    }
                }
            }
        }
    }
}
