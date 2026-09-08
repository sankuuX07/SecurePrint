package com.example.secureprint.screens

import android.util.Log
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.*
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
import com.example.secureprint.data.repository.ShopQrRepository
import com.example.secureprint.data.model.ShopResponse
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import kotlinx.coroutines.launch
import java.util.concurrent.Executors

sealed class ShopQrScanUiState {
    object Scanning : ShopQrScanUiState()
    object Resolving : ShopQrScanUiState()
    data class Success(val shop: ShopResponse) : ShopQrScanUiState()
    data class Error(val message: String) : ShopQrScanUiState()
}

class ShopQrScanViewModel : ViewModel() {
    private val repository = ShopQrRepository()
    
    var uiState by mutableStateOf<ShopQrScanUiState>(ShopQrScanUiState.Scanning)
        private set

    fun resolveQr(qrIdentifier: String) {
        if (uiState != ShopQrScanUiState.Scanning) return // Prevent multiple scans
        uiState = ShopQrScanUiState.Resolving
        viewModelScope.launch {
            try {
                val shop = repository.resolveShopQr(qrIdentifier)
                uiState = ShopQrScanUiState.Success(shop)
            } catch (e: Exception) {
                uiState = ShopQrScanUiState.Error(e.message ?: "Failed to resolve Shop QR")
            }
        }
    }
    
    fun reset() {
        uiState = ShopQrScanUiState.Scanning
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShopQrScannerScreen(
    documentId: String,
    onShopFound: (shopId: Int, documentId: String) -> Unit,
    onBack: () -> Unit,
    viewModel: ShopQrScanViewModel = viewModel()
) {
    val uiState = viewModel.uiState
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    
    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Scan Shop QR") })
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            when (uiState) {
                is ShopQrScanUiState.Scanning -> {
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
                                            viewModel.resolveQr(qrValue)
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
                                    Log.e("ShopQrScanner", "Use case binding failed", exc)
                                }
                            }, ContextCompat.getMainExecutor(ctx))
                            previewView
                        }
                    )
                }
                is ShopQrScanUiState.Resolving -> {
                    Column(
                        modifier = Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        CircularProgressIndicator()
                        Spacer(modifier = Modifier.height(16.dp))
                        Text("Resolving Shop...")
                    }
                }
                is ShopQrScanUiState.Success -> {
                    val shop = (uiState as ShopQrScanUiState.Success).shop
                    LaunchedEffect(shop) {
                        onShopFound(shop.id, documentId)
                    }
                }
                is ShopQrScanUiState.Error -> {
                    Column(
                        modifier = Modifier.fillMaxSize().padding(16.dp),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text((uiState as ShopQrScanUiState.Error).message, color = MaterialTheme.colorScheme.error)
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
