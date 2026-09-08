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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.secureprint.ui.shop.ShopJobDetailUiState
import com.example.secureprint.ui.shop.ShopJobsViewModel
import com.example.secureprint.ui.shop.ShopDocumentAccessViewModel
import com.example.secureprint.ui.shop.AccessState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShopPrintJobDetailScreen(
    jobId: Int,
    onBack: () -> Unit,
    onNavigateToSecureScanner: () -> Unit,
    viewModel: ShopJobsViewModel = viewModel(),
    accessViewModel: ShopDocumentAccessViewModel = viewModel()
) {
    val uiState = viewModel.detailUiState
    val accessState by accessViewModel.accessState.collectAsStateWithLifecycle()
    val currentAccess by accessViewModel.currentAccess.collectAsStateWithLifecycle()
    
    LaunchedEffect(jobId) {
        viewModel.loadJobDetail(jobId)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Shop Job Details") },
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
                is ShopJobDetailUiState.Loading -> {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
                is ShopJobDetailUiState.Success -> {
                    val job = state.job
                    Text("Job #SP-${job.id}", style = MaterialTheme.typography.headlineMedium)
                    Spacer(modifier = Modifier.height(16.dp))
                    Text("Configuration", fontWeight = FontWeight.Bold)
                    Text("Customer ID: ${job.customer_id}")
                    Text("Copies: ${job.copies}")
                    Text("Color Mode: ${job.color_mode}")
                    Text("Paper Size: ${job.paper_size}")
                    Text("Side: ${job.print_side}")
                    job.selected_page_count?.let { Text("Pages: $it") }
                    Text("Total Revenue: ₹${job.price}", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
                    
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    if (state.payment != null) {
                        Card(
                            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                        ) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Text("Payment Info", fontWeight = FontWeight.Bold)
                                Text("Status: ${state.payment.status}")
                                Text("Method: ${state.payment.method}")
                                if (state.payment.status == "UNPAID" && state.payment.method == "PAY_AT_SHOP") {
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Button(
                                        onClick = { viewModel.markPaymentPaid(job.id) },
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text("Mark as Paid")
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (job.status == "CREATED" || job.status == "SENT_TO_SHOP") {
                            Button(onClick = { viewModel.updateJobStatus(job.id, "accept") }) { Text("Accept") }
                        }
                        if (job.status == "ACCEPTED") {
                            Button(onClick = { viewModel.updateJobStatus(job.id, "start") }) { Text("Start Printing") }
                        }
                        if (job.status == "PRINTING") {
                            Button(onClick = { viewModel.updateJobStatus(job.id, "complete") }) { Text("Mark Completed") }
                        }
                    }
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    if (job.status == "ACCEPTED" || job.status == "PRINTING") {
                        Text("Document Access", fontWeight = FontWeight.Bold)
                        Card(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                when (val state = accessState) {
                                    is AccessState.Idle -> {
                                        Button(onClick = { onNavigateToSecureScanner() }) {
                                            Text("Scan Secure Print QR")
                                        }
                                        Text("Only active for ACCEPTED or PRINTING jobs.", style = MaterialTheme.typography.bodySmall)
                                    }
                                    is AccessState.Loading -> CircularProgressIndicator()
                                    is AccessState.Granted -> {
                                        Text("Access Granted until ${currentAccess?.expires_at}")
                                        Spacer(modifier = Modifier.height(8.dp))
                                        Button(onClick = { accessViewModel.downloadAndOpenDocument(currentAccess!!.id, job.document_id + ".pdf") }) {
                                            Text("Download & View PDF")
                                        }
                                    }
                                    is AccessState.Downloading -> {
                                        Text("Downloading securely...")
                                        CircularProgressIndicator()
                                    }
                                    is AccessState.Downloaded -> {
                                        Text("Access Granted until ${currentAccess?.expires_at}")
                                        Spacer(modifier = Modifier.height(8.dp))
                                        Button(onClick = { accessViewModel.downloadAndOpenDocument(currentAccess!!.id, job.document_id + ".pdf") }) {
                                            Text("Re-open PDF")
                                        }
                                        Text("Saved to cache", style = MaterialTheme.typography.bodySmall)
                                    }
                                    is AccessState.Error -> {
                                        Text(state.message, color = MaterialTheme.colorScheme.error)
                                        Button(onClick = { onNavigateToSecureScanner() }) {
                                            Text("Retry Scan")
                                        }
                                    }
                                }
                            }
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
                is ShopJobDetailUiState.Error -> {
                    Text(state.message, color = MaterialTheme.colorScheme.error)
                }
            }
        }
    }
}
