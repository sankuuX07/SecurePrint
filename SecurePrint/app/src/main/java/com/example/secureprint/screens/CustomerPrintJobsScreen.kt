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
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.secureprint.ui.customer.PrintJobsUiState
import com.example.secureprint.ui.customer.PrintJobViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomerPrintJobsScreen(
    onJobClick: (Int) -> Unit,
    viewModel: PrintJobViewModel = viewModel()
) {
    val uiState = viewModel.listUiState
    
    LaunchedEffect(Unit) {
        viewModel.loadJobs(reset = true)
    }

    Scaffold(
        topBar = { TopAppBar(title = { Text("My Print Jobs") }) }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().padding(16.dp)) {
            when (val state = uiState) {
                is PrintJobsUiState.Loading -> {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
                is PrintJobsUiState.Success -> {
                    if (state.jobs.isEmpty()) {
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Text("No print jobs yet.")
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
                                        Text("Status: ${job.status}", color = MaterialTheme.colorScheme.primary)
                                        Text("${job.copies} Copies | ₹${job.price}")
                                        Text("Created: ${job.created_at}")
                                    }
                                }
                            }
                        }
                    }
                }
                is PrintJobsUiState.Error -> {
                    Text(state.message, color = MaterialTheme.colorScheme.error)
                }
            }
        }
    }
}
