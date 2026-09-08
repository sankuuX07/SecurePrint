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
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.secureprint.data.api.RetrofitClient
import com.example.secureprint.data.model.PrintJobCreate
import kotlinx.coroutines.launch

sealed class PrintJobUiState {
    object Idle : PrintJobUiState()
    object Loading : PrintJobUiState()
    object Success : PrintJobUiState()
    data class Error(val message: String) : PrintJobUiState()
}

class PrintJobViewModel : ViewModel() {
    var uiState by mutableStateOf<PrintJobUiState>(PrintJobUiState.Idle)
        private set

    fun createJob(request: PrintJobCreate) {
        uiState = PrintJobUiState.Loading
        viewModelScope.launch {
            try {
                RetrofitClient.printJobApi.createPrintJob(request)
                uiState = PrintJobUiState.Success
            } catch (e: Exception) {
                uiState = PrintJobUiState.Error(e.message ?: "Failed to create print job")
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomerPrintSettingsScreen(
    documentId: String,
    shopId: Int,
    onJobCreated: () -> Unit,
    onBack: () -> Unit,
    viewModel: PrintJobViewModel = viewModel()
) {
    var copies by remember { mutableStateOf("1") }
    var colorMode by remember { mutableStateOf("B/W") }
    var paperSize by remember { mutableStateOf("A4") }
    var printSide by remember { mutableStateOf("Single") }

    val uiState = viewModel.uiState

    LaunchedEffect(uiState) {
        if (uiState is PrintJobUiState.Success) {
            onJobCreated()
        }
    }

    Scaffold(
        topBar = { TopAppBar(title = { Text("Print Settings") }) }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            OutlinedTextField(
                value = copies,
                onValueChange = { copies = it },
                label = { Text("Copies") },
                modifier = Modifier.fillMaxWidth()
            )

            Text("Color Mode")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = colorMode == "B/W", onClick = { colorMode = "B/W" }, label = { Text("B/W") })
                FilterChip(selected = colorMode == "Color", onClick = { colorMode = "Color" }, label = { Text("Color") })
            }

            Text("Paper Size")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = paperSize == "A4", onClick = { paperSize = "A4" }, label = { Text("A4") })
                FilterChip(selected = paperSize == "A3", onClick = { paperSize = "A3" }, label = { Text("A3") })
            }

            Text("Print Side")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = printSide == "Single", onClick = { printSide = "Single" }, label = { Text("Single Sided") })
                FilterChip(selected = printSide == "Double", onClick = { printSide = "Double" }, label = { Text("Double Sided") })
            }

            if (uiState is PrintJobUiState.Error) {
                Text(uiState.message, color = MaterialTheme.colorScheme.error)
            }
            
            Spacer(modifier = Modifier.height(8.dp))
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(8.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Payment Method", fontWeight = FontWeight.Bold)
                    Text("Pay at Shop (Cash / UPI / Card)", style = MaterialTheme.typography.bodyMedium)
                }
            }

            Button(
                onClick = {
                    val copiesInt = copies.toIntOrNull() ?: 1
                    viewModel.createJob(
                        PrintJobCreate(
                            document_id = documentId,
                            shop_id = shopId,
                            copies = copiesInt,
                            color_mode = colorMode,
                            paper_size = paperSize,
                            print_side = printSide
                        )
                    )
                },
                modifier = Modifier.fillMaxWidth().height(56.dp),
                enabled = uiState !is PrintJobUiState.Loading,
                shape = RoundedCornerShape(16.dp)
            ) {
                if (uiState is PrintJobUiState.Loading) {
                    CircularProgressIndicator(color = MaterialTheme.colorScheme.onPrimary)
                } else {
                    Text("Submit Print Job")
                }
            }
        }
    }
}
