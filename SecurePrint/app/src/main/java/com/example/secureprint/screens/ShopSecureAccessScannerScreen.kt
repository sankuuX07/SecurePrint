package com.example.secureprint.screens

import android.util.Log
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.secureprint.data.api.RetrofitClient
import com.example.secureprint.data.model.TemporaryDocumentAccessResponse
import com.example.secureprint.data.model.TokenRequest
import com.example.secureprint.data.repository.ShopDocumentAccessRepository
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import kotlinx.coroutines.launch
import java.util.concurrent.Executors

sealed class SecureAccessScanUiState {
    object Scanning : SecureAccessScanUiState()
    object Authorizing : SecureAccessScanUiState()
    data class Success(val access: TemporaryDocumentAccessResponse) : SecureAccessScanUiState()
    data class Error(val message: String) : SecureAccessScanUiState()
}

class SecureAccessScanViewModel : ViewModel() {
    private val repository = ShopDocumentAccessRepository(RetrofitClient.shopDocumentAccessApi)
    
    var uiState by mutableStateOf<SecureAccessScanUiState>(SecureAccessScanUiState.Scanning)
        private set

    fun authorizeToken(rawToken: String) {
        if (uiState != SecureAccessScanUiState.Scanning) return // Prevent multiple scans
        uiState = SecureAccessScanUiState.Authorizing
        viewModelScope.launch {
            try {
                val response = repository.authorizeSecureAccess(TokenRequest(token = rawToken))
                if (response.isSuccessful && response.body() != null) {
                    uiState = SecureAccessScanUiState.Success(response.body()!!)
                } else {
                    uiState = SecureAccessScanUiState.Error("Authorization failed: ${response.code()}")
                }
            } catch (e: Exception) {
                uiState = SecureAccessScanUiState.Error(e.message ?: "Failed to authorize token")
            }
        }
    }
    
    fun reset() {
        uiState = SecureAccessScanUiState.Scanning
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShopSecureAccessScannerScreen(
    onAccessGranted: (String) -> Unit,
    onBack: () -> Unit,
    viewModel: SecureAccessScanViewModel = viewModel()
) {
    val uiState = viewModel.uiState
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Scan Secure Print QR") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            when (uiState) {
                is SecureAccessScanUiState.Scanning -> {
                    val cameraProviderFuture = remember { ProcessCameraProvider.getInstance(context) }
                    val executor = remember { Executors.newSingleThreadExecutor() }
                    
                    AndroidView(
                        modifier = Modifier.fillMaxSize(),
                        factory = { ctx ->
                            val previewView = PreviewView(ctx)
                            cameraProviderFuture.addListener({
                                val cameraProvider = cameraProviderFuture.get()
                                val preview = Preview.Builder().build().also {
                                    it.setSurfaceProvider(previewView.surfaceProvider)
                                }
                                
                                val imageAnalysis = ImageAnalysis.Builder()
                                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                                    .build()
                                    
                                imageAnalysis.setAnalyzer(executor) { imageProxy ->
                                    processImageProxy(imageProxy) { qrValue ->
                                        if (qrValue != null) {
                                            viewModel.authorizeToken(qrValue)
                                        }
                                    }
                                }
                                
                                try {
                                    cameraProvider.unbindAll()
                                    cameraProvider.bindToLifecycle(
                                        lifecycleOwner,
                                        CameraSelector.DEFAULT_BACK_CAMERA,
                                        preview,
                                        imageAnalysis
                                    )
                                } catch (exc: Exception) {
                                    Log.e("SecureScan", "Use case binding failed", exc)
                                }
                            }, ContextCompat.getMainExecutor(ctx))
                            previewView
                        }
                    )
                }
                is SecureAccessScanUiState.Authorizing -> {
                    Column(
                        modifier = Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        CircularProgressIndicator()
                        Spacer(modifier = Modifier.height(16.dp))
                        Text("Authorizing Document Access...")
                    }
                }
                is SecureAccessScanUiState.Success -> {
                    val access = (uiState as SecureAccessScanUiState.Success).access
                    LaunchedEffect(Unit) {
                        onAccessGranted(access.id)
                    }
                }
                is SecureAccessScanUiState.Error -> {
                    Column(
                        modifier = Modifier.fillMaxSize().padding(16.dp),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text((uiState as SecureAccessScanUiState.Error).message, color = MaterialTheme.colorScheme.error)
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(onClick = { viewModel.reset() }) {
                            Text("Try Again")
                        }
                    }
                }
            }
        }
    }
}

@androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
private fun processImageProxy(imageProxy: ImageProxy, onQrFound: (String?) -> Unit) {
    val mediaImage = imageProxy.image
    if (mediaImage != null) {
        val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
        val scanner = BarcodeScanning.getClient()
        scanner.process(image)
            .addOnSuccessListener { barcodes ->
                for (barcode in barcodes) {
                    if (barcode.valueType == Barcode.TYPE_TEXT) {
                        onQrFound(barcode.displayValue)
                        return@addOnSuccessListener
                    }
                }
            }
            .addOnCompleteListener {
                imageProxy.close()
            }
    } else {
        imageProxy.close()
    }
}
