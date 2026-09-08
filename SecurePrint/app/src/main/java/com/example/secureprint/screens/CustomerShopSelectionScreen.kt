package com.example.secureprint.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.secureprint.data.api.RetrofitClient
import com.example.secureprint.data.model.ShopResponse
import kotlinx.coroutines.launch

sealed class ShopListUiState {
    object Idle : ShopListUiState()
    object Loading : ShopListUiState()
    data class Success(val shops: List<ShopResponse>) : ShopListUiState()
    data class Error(val message: String) : ShopListUiState()
}

class ShopListViewModel : ViewModel() {
    var uiState by mutableStateOf<ShopListUiState>(ShopListUiState.Idle)
        private set

    fun loadShops() {
        uiState = ShopListUiState.Loading
        viewModelScope.launch {
            try {
                val shops = RetrofitClient.shopApi.getShops()
                uiState = ShopListUiState.Success(shops)
            } catch (e: Exception) {
                uiState = ShopListUiState.Error(e.message ?: "Failed to load shops")
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomerShopSelectionScreen(
    documentId: String,
    onShopSelected: (shopId: Int, documentId: String) -> Unit,
    onScanQrClick: () -> Unit,
    onBack: () -> Unit,
    viewModel: ShopListViewModel = viewModel()
) {
    val uiState = viewModel.uiState

    LaunchedEffect(Unit) {
        viewModel.loadShops()
    }

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Select a Print Shop") })
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().padding(16.dp)) {
            Button(
                onClick = onScanQrClick,
                modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.secondary)
            ) {
                Text("Scan Shop QR")
            }
            
            Text("Or browse approved shops:", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(bottom = 8.dp))
            
            when (uiState) {
                is ShopListUiState.Loading -> Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                is ShopListUiState.Success -> {
                    if (uiState.shops.isEmpty()) {
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Text("No shops available.")
                        }
                    } else {
                        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            items(uiState.shops) { shop ->
                                Card(
                                    modifier = Modifier.fillMaxWidth().clickable {
                                        onShopSelected(shop.id, documentId)
                                    },
                                    shape = RoundedCornerShape(12.dp)
                                ) {
                                    Column(modifier = Modifier.padding(16.dp)) {
                                        Text(shop.shop_name, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                                        shop.address?.let { Text(it, style = MaterialTheme.typography.bodyMedium) }
                                        shop.city?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
                                    }
                                }
                            }
                        }
                    }
                }
                is ShopListUiState.Error -> Text(uiState.message, color = MaterialTheme.colorScheme.error)
                else -> {}
            }
        }
    }
}
