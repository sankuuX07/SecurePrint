package com.example.secureprint.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.secureprint.ui.customer.PrintJobDetailUiState
import com.example.secureprint.ui.customer.PrintJobViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomerPrintJobDetailScreen(
    jobId: Int,
    onBack: () -> Unit,
    onNavigateToSecureQr: (Int) -> Unit,
    viewModel: PrintJobViewModel = viewModel()
) {
    val uiState = viewModel.detailUiState
    
    LaunchedEffect(jobId) {
        viewModel.loadJobDetail(jobId)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Job Details") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().padding(16.dp)) {
            when (val state = uiState) {
                is PrintJobDetailUiState.Loading -> {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
                is PrintJobDetailUiState.Success -> {
                    val job = state.job
                    Text("Job #SP-${job.id}", style = MaterialTheme.typography.headlineMedium)
                    Spacer(modifier = Modifier.height(16.dp))
                    Text("Configuration", fontWeight = FontWeight.Bold)
                    Text("Copies: ${job.copies}")
                    Text("Color Mode: ${job.color_mode}")
                    Text("Paper Size: ${job.paper_size}")
                    Text("Side: ${job.print_side}")
                    job.selected_page_count?.let { Text("Pages: $it") }
                    Text("Total Price: ₹${job.price}", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    if (job.status == "CREATED" || job.status == "SENT_TO_SHOP") {
                        Button(onClick = { viewModel.cancelJob(job.id) {} }) {
                            Text("Cancel Job")
                        }
                        Spacer(modifier = Modifier.height(16.dp))
                    }
                    
                    if (job.status == "ACCEPTED" || job.status == "PRINTING") {
                        Button(onClick = { onNavigateToSecureQr(job.id) }) {
                            Text("Show Secure Access QR")
                        }
                        Spacer(modifier = Modifier.height(16.dp))
                    }
                    
                    Text("Timeline", fontWeight = FontWeight.Bold)
                    LazyColumn {
                        items(job.status_history) { history ->
                            Text("${history.changed_at}: ${history.to_status}")
                        }
                    }
                }
                is PrintJobDetailUiState.Error -> {
                    Text(state.message, color = MaterialTheme.colorScheme.error)
                }
            }
        }
    }
}
