package com.example.secureprint.screens

import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.secureprint.data.model.DocumentResponse
import com.example.secureprint.ui.customer.DocumentUiState
import com.example.secureprint.ui.customer.DocumentViewModel
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomerDashboardScreen(
    onNavigateToShopSelection: (String) -> Unit,
    onNavigateToMyJobs: () -> Unit,
    viewModel: DocumentViewModel = viewModel()
) {
    val uiState = viewModel.uiState
    val context = LocalContext.current
    var showDeleteConfirm by remember { mutableStateOf<String?>(null) }

    val filePickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let {
            val contentResolver = context.contentResolver
            val fileName = contentResolver.query(it, null, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                cursor.moveToFirst()
                cursor.getString(nameIndex)
            } ?: "document"

            val bytes = contentResolver.openInputStream(it)?.readBytes()
            if (bytes != null) {
                val requestFile = bytes.toRequestBody("application/octet-stream".toMediaTypeOrNull())
                val body = MultipartBody.Part.createFormData("file", fileName, requestFile)
                viewModel.uploadDocument(body)
            }
        }
    }

    LaunchedEffect(Unit) {
        viewModel.loadDocuments()
    }

    if (viewModel.deleteError != null) {
        AlertDialog(
            onDismissRequest = { viewModel.clearDeleteError() },
            title = { Text("Cannot Delete") },
            text = { Text(viewModel.deleteError!!) },
            confirmButton = {
                TextButton(onClick = { viewModel.clearDeleteError() }) { Text("OK") }
            }
        )
    }

    if (showDeleteConfirm != null) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = null },
            title = { Text("Delete Document?") },
            text = { Text("This document will be permanently removed from your account.") },
            confirmButton = {
                Button(
                    onClick = { 
                        viewModel.deleteDocument(showDeleteConfirm!!)
                        showDeleteConfirm = null
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                ) { Text("Delete") }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = null }) { Text("Cancel") }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("My Documents") },
                actions = {
                    IconButton(onClick = onNavigateToMyJobs) {
                        Icon(Icons.Default.ReceiptLong, contentDescription = "My Print Jobs")
                    }
                }
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { filePickerLauncher.launch("*/*") },
                containerColor = MaterialTheme.colorScheme.primary
            ) {
                Icon(Icons.Default.Add, contentDescription = "Upload Document", tint = MaterialTheme.colorScheme.onPrimary)
            }
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().padding(16.dp)) {
            
            OutlinedTextField(
                value = viewModel.searchQuery,
                onValueChange = { viewModel.updateSearchQuery(it) },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("Search documents...") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                singleLine = true,
                shape = RoundedCornerShape(12.dp)
            )
            
            Spacer(modifier = Modifier.height(8.dp))
            
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                val filters = listOf(null to "All", "ACTIVE" to "Active", "IN_PRINT_JOB" to "In Print Job", "PRINTED" to "Printed")
                items(filters) { (status, label) ->
                    FilterChip(
                        selected = viewModel.statusFilter == status,
                        onClick = { viewModel.updateStatusFilter(status) },
                        label = { Text(label) }
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))

            when (uiState) {
                is DocumentUiState.Loading -> Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                is DocumentUiState.Success -> {
                    if (uiState.documents.isEmpty()) {
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("No documents found.", style = MaterialTheme.typography.titleMedium)
                                Text("Upload a document to get started.", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    } else {
                        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            items(uiState.documents) { doc ->
                                DocumentItem(
                                    doc = doc, 
                                    onPrintClick = onNavigateToShopSelection,
                                    onDeleteClick = { showDeleteConfirm = it }
                                )
                            }
                        }
                    }
                }
                is DocumentUiState.Error -> {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                        Text(uiState.message, color = MaterialTheme.colorScheme.error)
                        Button(onClick = { viewModel.loadDocuments() }) { Text("Retry") }
                    }
                }
                else -> {}
            }
        }
    }
}

@Composable
fun DocumentItem(doc: DocumentResponse, onPrintClick: (String) -> Unit, onDeleteClick: (String) -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Default.Description, contentDescription = null, modifier = Modifier.size(40.dp), tint = MaterialTheme.colorScheme.primary)
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(doc.original_filename, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                Text("Status: ${doc.status} • Pages: ${doc.page_count ?: "?"} • Size: ${(doc.file_size ?: 0) / 1024} KB", style = MaterialTheme.typography.bodySmall)
                Text(doc.created_at.split("T")[0], style = MaterialTheme.typography.labelSmall)
            }
            if (doc.status == "ACTIVE" || doc.status == "PENDING" || doc.status == "PRINTED" || doc.status == "UPLOADED") {
                Button(onClick = { onPrintClick(doc.id) }, modifier = Modifier.padding(end = 8.dp)) {
                    Text("Print")
                }
            }
            IconButton(onClick = { onDeleteClick(doc.id) }) {
                Icon(Icons.Default.Delete, contentDescription = "Delete", tint = MaterialTheme.colorScheme.error)
            }
        }
    }
}
