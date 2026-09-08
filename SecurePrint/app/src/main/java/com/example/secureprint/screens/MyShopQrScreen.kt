package com.example.secureprint.screens

import android.graphics.Bitmap
import android.graphics.Color
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
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
import com.example.secureprint.data.model.ShopQrResponse
import com.example.secureprint.data.repository.ShopQrRepository
import com.google.zxing.BarcodeFormat
import com.google.zxing.MultiFormatWriter
import kotlinx.coroutines.launch

sealed class MyShopQrUiState {
    object Loading : MyShopQrUiState()
    data class Success(val qrResponse: ShopQrResponse, val qrBitmap: Bitmap) : MyShopQrUiState()
    data class Error(val message: String) : MyShopQrUiState()
}

class MyShopQrViewModel : ViewModel() {
    private val repository = ShopQrRepository()
    
    var uiState by mutableStateOf<MyShopQrUiState>(MyShopQrUiState.Loading)
        private set
        
    fun loadQr() {
        uiState = MyShopQrUiState.Loading
        viewModelScope.launch {
            try {
                val response = repository.getMyShopQr()
                val bitmap = generateQrCode(response.qr_identifier, 512, 512)
                uiState = MyShopQrUiState.Success(response, bitmap)
            } catch (e: Exception) {
                uiState = MyShopQrUiState.Error(e.message ?: "Failed to load QR code")
            }
        }
    }
    
    fun regenerateQr() {
        uiState = MyShopQrUiState.Loading
        viewModelScope.launch {
            try {
                val response = repository.regenerateShopQr()
                val bitmap = generateQrCode(response.qr_identifier, 512, 512)
                uiState = MyShopQrUiState.Success(response, bitmap)
            } catch (e: Exception) {
                uiState = MyShopQrUiState.Error(e.message ?: "Failed to regenerate QR code")
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
fun MyShopQrScreen(
    onBack: () -> Unit,
    viewModel: MyShopQrViewModel = viewModel()
) {
    val uiState = viewModel.uiState
    
    LaunchedEffect(Unit) {
        viewModel.loadQr()
    }
    
    Scaffold(
        topBar = {
            TopAppBar(title = { Text("My Shop QR") })
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
            when (uiState) {
                is MyShopQrUiState.Loading -> {
                    CircularProgressIndicator()
                }
                is MyShopQrUiState.Success -> {
                    Text(
                        text = "Show this to customers so they can easily find your shop.",
                        style = MaterialTheme.typography.bodyLarge,
                        modifier = Modifier.padding(bottom = 24.dp)
                    )
                    
                    Image(
                        bitmap = uiState.qrBitmap.asImageBitmap(),
                        contentDescription = "Shop QR Code",
                        modifier = Modifier.size(256.dp)
                    )
                    
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    Text("Status: ${uiState.qrResponse.status}", fontWeight = FontWeight.Bold)
                    
                    Spacer(modifier = Modifier.height(32.dp))
                    
                    Button(onClick = { viewModel.regenerateQr() }) {
                        Text("Regenerate QR Code")
                    }
                    
                    Text(
                        text = "Regenerating will invalidate the old QR code.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
                is MyShopQrUiState.Error -> {
                    Text(uiState.message, color = MaterialTheme.colorScheme.error)
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(onClick = { viewModel.loadQr() }) {
                        Text("Retry")
                    }
                }
            }
        }
    }
}
