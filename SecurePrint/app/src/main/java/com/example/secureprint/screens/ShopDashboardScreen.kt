package com.example.secureprint.screens

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
import com.example.secureprint.data.model.PrintJobResponse
import kotlinx.coroutines.launch

sealed class ShopJobsUiState {
    object Idle : ShopJobsUiState()
    object Loading : ShopJobsUiState()
    data class Success(val jobs: List<PrintJobResponse>) : ShopJobsUiState()
    data class Error(val message: String) : ShopJobsUiState()
}

class ShopJobsViewModel : ViewModel() {
    var uiState by mutableStateOf<ShopJobsUiState>(ShopJobsUiState.Idle)
        private set

    fun loadJobs() {
        uiState = ShopJobsUiState.Loading
        viewModelScope.launch {
            try {
                val jobs = RetrofitClient.printJobApi.getShopPrintJobs()
                uiState = ShopJobsUiState.Success(jobs)
            } catch (e: Exception) {
                uiState = ShopJobsUiState.Error(e.message ?: "Failed to load jobs")
            }
        }
    }

    fun updateJobStatus(jobId: Int, action: String) {
        viewModelScope.launch {
            try {
                when (action) {
                    "accept" -> RetrofitClient.printJobApi.acceptPrintJob(jobId)
                    "start" -> RetrofitClient.printJobApi.startPrintJob(jobId)
                    "complete" -> RetrofitClient.printJobApi.completePrintJob(jobId)
                }
                loadJobs() // Reload list
            } catch (e: Exception) {
                // handle error
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShopDashboardScreen(
    shopName: String?,
    onJobClick: (Int) -> Unit = {},
    onMyShopQrClick: () -> Unit = {},
    viewModel: ShopJobsViewModel = viewModel()
) {
    val uiState = viewModel.uiState

    LaunchedEffect(Unit) {
        viewModel.loadJobs()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(shopName ?: "Shop Dashboard") },
                actions = {
                    Button(onClick = onMyShopQrClick) {
                        Text("My QR")
                    }
                }
            )
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().padding(16.dp)) {
            when (uiState) {
                is ShopJobsUiState.Loading -> Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                is ShopJobsUiState.Success -> {
                    if (uiState.jobs.isEmpty()) {
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Text("No jobs in the queue.")
                        }
                    } else {
                        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            items(uiState.jobs) { job ->
                                JobItem(
                                    job,
                                    onClick = { onJobClick(job.id) },
                                    onAction = { action -> viewModel.updateJobStatus(job.id, action) }
                                )
                            }
                        }
                    }
                }
                is ShopJobsUiState.Error -> Text(uiState.message, color = MaterialTheme.colorScheme.error)
                else -> {}
            }
        }
    }
}

@Composable
fun JobItem(job: PrintJobResponse, onClick: () -> Unit, onAction: (String) -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        onClick = onClick
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Job #${job.id}", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
            Text("Status: ${job.status}", color = MaterialTheme.colorScheme.primary)
            Text("${job.copies} Copies | ${job.paper_size} | ${job.color_mode} | ${job.print_side}")
            Text("Price: ₹${job.price}")
            
            Spacer(modifier = Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (job.status == "CREATED" || job.status == "SENT_TO_SHOP") {
                    Button(onClick = { onAction("accept") }) { Text("Accept") }
                }
                if (job.status == "ACCEPTED") {
                    Button(onClick = { onAction("start") }) { Text("Start Printing") }
                }
                if (job.status == "PRINTING") {
                    Button(onClick = { onAction("complete") }) { Text("Mark Completed") }
                }
            }
        }
    }
}
