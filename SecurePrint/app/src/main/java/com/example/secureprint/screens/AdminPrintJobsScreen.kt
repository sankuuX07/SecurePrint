package com.example.secureprint.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.secureprint.ui.admin.AdminJobDetailUiState
import com.example.secureprint.ui.admin.AdminJobsUiState
import com.example.secureprint.ui.admin.AdminJobsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminPrintJobsScreen(
    onJobClick: (Int) -> Unit,
    viewModel: AdminJobsViewModel = viewModel()
) {
    val uiState = viewModel.listUiState
    
    LaunchedEffect(Unit) {
        viewModel.loadJobs(reset = true)
    }

    Scaffold(
        topBar = { TopAppBar(title = { Text("Admin Print Jobs Monitoring") }) }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().padding(16.dp)) {
            when (val state = uiState) {
                is AdminJobsUiState.Loading -> {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
                is AdminJobsUiState.Success -> {
                    if (state.jobs.isEmpty()) {
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Text("No print jobs found.")
                        }
                    } else {
                        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            items(state.jobs) { job ->
                                Card(
                                    modifier = Modifier.fillMaxWidth(),
                                    shape = RoundedCornerShape(12.dp),
                                    onClick = { onJobClick(job.id) }
                                ) {
                                    Column(modifier = Modifier.padding(16.dp)) {
                                        Text("SP-${job.id}", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                                        Text("Status: ${job.status}")
                                        Text("Customer: ${job.customer_id} | Shop: ${job.shop_id}")
                                        Text("₹${job.price}")
                                    }
                                }
                            }
                        }
                    }
                }
                is AdminJobsUiState.Error -> {
                    Text(state.message, color = MaterialTheme.colorScheme.error)
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminPrintJobDetailScreen(
    jobId: Int,
    onBack: () -> Unit,
    viewModel: AdminJobsViewModel = viewModel()
) {
    val uiState = viewModel.detailUiState
    
    LaunchedEffect(jobId) {
        viewModel.loadJobDetail(jobId)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Admin Job Details") },
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
                is AdminJobDetailUiState.Loading -> {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
                is AdminJobDetailUiState.Success -> {
                    val job = state.job
                    Text("Job #SP-${job.id}", style = MaterialTheme.typography.headlineMedium)
                    Spacer(modifier = Modifier.height(16.dp))
                    Text("Customer ID: ${job.customer_id}")
                    Text("Shop ID: ${job.shop_id}")
                    Text("Total Price: ₹${job.price}")
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    Text("Timeline", fontWeight = FontWeight.Bold)
                    LazyColumn {
                        items(job.status_history) { history ->
                            Text("${history.changed_at}: ${history.from_status} -> ${history.to_status}")
                        }
                    }
                }
                is AdminJobDetailUiState.Error -> {
                    Text(state.message, color = MaterialTheme.colorScheme.error)
                }
            }
        }
    }
}
