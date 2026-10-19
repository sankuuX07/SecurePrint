package com.example.secureprint.ui.customer

import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.secureprint.data.model.DocumentResponse
import com.example.secureprint.data.repository.DocumentRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.ByteArrayOutputStream
import java.io.IOException

sealed class DocumentUiState {
    object Idle : DocumentUiState()
    object Loading : DocumentUiState()
    data class Success(val documents: List<DocumentResponse>) : DocumentUiState()
    data class Error(val message: String) : DocumentUiState()
}

class DocumentViewModel(
    private val repository: DocumentRepository = DocumentRepository()
) : ViewModel() {

    var uiState by mutableStateOf<DocumentUiState>(DocumentUiState.Idle)
        private set
        
    var searchQuery by mutableStateOf("")
        private set
        
    var statusFilter by mutableStateOf<String?>(null)
        private set
        
    var deleteError by mutableStateOf<String?>(null)
        private set

    var uploadError by mutableStateOf<String?>(null)
        private set

    fun updateSearchQuery(query: String) {
        searchQuery = query
        loadDocuments()
    }
    
    fun updateStatusFilter(status: String?) {
        statusFilter = status
        loadDocuments()
    }
    
    fun clearDeleteError() {
        deleteError = null
    }

    fun clearUploadError() {
        uploadError = null
    }

    fun loadDocuments() {
        val token = com.example.secureprint.data.auth.SessionManager.getToken()
        if (token.isNullOrBlank()) {
            uiState = DocumentUiState.Error("Authentication token is missing. Please log in.")
            return
        }

        viewModelScope.launch {
            uiState = DocumentUiState.Loading
            uiState = try {
                val response = repository.getMyDocuments(statusFilter, searchQuery.ifBlank { null })
                if (response.isSuccessful && response.body() != null) {
                    DocumentUiState.Success(response.body()!!)
                } else {
                    val errorMessage = com.example.secureprint.data.api.NetworkErrorParser.parseError(response, "Failed to load documents")
                    DocumentUiState.Error(errorMessage)
                }
            } catch (e: Exception) {
                val errorMessage = com.example.secureprint.data.api.NetworkErrorParser.parseException(e)
                DocumentUiState.Error(errorMessage)
            }
        }
    }

    fun uploadPdfFromUri(contentResolver: ContentResolver, uri: Uri) {
        viewModelScope.launch {
            uploadError = null

            val result: Result<MultipartBody.Part> = withContext(Dispatchers.IO) {
                try {
                    // 1. Validate MIME type where available
                    val mimeType = contentResolver.getType(uri)
                    if (mimeType != null &&
                        !mimeType.equals("application/pdf", ignoreCase = true) &&
                        !mimeType.equals("application/x-pdf", ignoreCase = true)
                    ) {
                        return@withContext Result.failure(
                            IllegalArgumentException("Selected file is not a PDF (detected type: $mimeType). Only PDF documents can be uploaded.")
                        )
                    }

                    // 2. Query file metadata (display name and reported size)
                    var displayName: String? = null
                    var reportedSize: Long? = null

                    contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                            if (nameIndex != -1 && !cursor.isNull(nameIndex)) {
                                displayName = cursor.getString(nameIndex)
                            }
                            val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                            if (sizeIndex != -1 && !cursor.isNull(sizeIndex)) {
                                reportedSize = cursor.getLong(sizeIndex)
                            }
                        }
                    }

                    // 3. Validate file extension
                    val rawFilename = displayName?.trim()
                    if (rawFilename != null) {
                        if (!rawFilename.endsWith(".pdf", ignoreCase = true)) {
                            return@withContext Result.failure(
                                IllegalArgumentException("Selected file '$rawFilename' is not a PDF. Only files with a .pdf extension are allowed.")
                            )
                        }
                    } else if (mimeType == null) {
                        return@withContext Result.failure(
                            IllegalArgumentException("Cannot determine file type. Please select a valid PDF file.")
                        )
                    }

                    val sanitizedFileName = rawFilename?.substringAfterLast('/')?.substringAfterLast('\\')
                        ?.takeIf { it.isNotBlank() } ?: "document.pdf"

                    val maxSizeBytes = 10 * 1024 * 1024L // 10 MB

                    // 4. Pre-check reported size if metadata is available
                    if (reportedSize != null) {
                        if (reportedSize <= 0) {
                            return@withContext Result.failure(
                                IllegalArgumentException("Selected file is empty (0 bytes).")
                            )
                        }
                        if (reportedSize > maxSizeBytes) {
                            val sizeMb = String.format("%.2f", reportedSize / (1024.0 * 1024.0))
                            return@withContext Result.failure(
                                IllegalArgumentException("File exceeds the 10 MB limit (file size: $sizeMb MB).")
                            )
                        }
                    }

                    // 5. Safe bounded reading off the main thread (handles unknown size safely)
                    val inputStream = contentResolver.openInputStream(uri)
                        ?: return@withContext Result.failure(
                            IOException("Unable to open the selected file for reading.")
                        )

                    val buffer = ByteArray(8192)
                    val outputStream = ByteArrayOutputStream()
                    var bytesReadTotal = 0L

                    inputStream.use { input ->
                        while (true) {
                            val count = input.read(buffer)
                            if (count == -1) break
                            bytesReadTotal += count
                            if (bytesReadTotal > maxSizeBytes) {
                                return@withContext Result.failure(
                                    IllegalArgumentException("File exceeds the 10 MB upload limit.")
                                )
                            }
                            outputStream.write(buffer, 0, count)
                        }
                    }

                    val fileBytes = outputStream.toByteArray()
                    if (fileBytes.isEmpty()) {
                        return@withContext Result.failure(
                            IllegalArgumentException("Selected file is empty (0 bytes).")
                        )
                    }

                    // 6. Build multipart part with application/pdf MIME type
                    val requestBody = fileBytes.toRequestBody("application/pdf".toMediaTypeOrNull())
                    val part = MultipartBody.Part.createFormData("file", sanitizedFileName, requestBody)
                    Result.success(part)
                } catch (e: Exception) {
                    Result.failure(e)
                }
            }

            result.fold(
                onSuccess = { part ->
                    uploadDocument(part)
                },
                onFailure = { error ->
                    uploadError = error.localizedMessage ?: "Failed to process selected file."
                }
            )
        }
    }

    fun uploadDocument(filePart: MultipartBody.Part) {
        val token = com.example.secureprint.data.auth.SessionManager.getToken()
        if (token.isNullOrBlank()) {
            uploadError = "Authentication token is missing. Please log in."
            return
        }

        viewModelScope.launch {
            uiState = DocumentUiState.Loading
            try {
                val response = repository.uploadDocument(filePart)
                if (response.isSuccessful) {
                    loadDocuments()
                } else {
                    val errorMessage = com.example.secureprint.data.api.NetworkErrorParser.parseError(response, "Upload failed")
                    uploadError = "Upload failed: $errorMessage"
                    loadDocuments()
                }
            } catch (e: Exception) {
                val errorMessage = com.example.secureprint.data.api.NetworkErrorParser.parseException(e)
                uploadError = errorMessage
                loadDocuments()
            }
        }
    }
    
    fun deleteDocument(id: String) {
        val token = com.example.secureprint.data.auth.SessionManager.getToken()
        if (token.isNullOrBlank()) {
            deleteError = "Authentication token is missing. Please log in."
            return
        }

        viewModelScope.launch {
            try {
                val response = repository.deleteDocument(id)
                if (response.isSuccessful) {
                    loadDocuments()
                } else {
                    val errorMessage = com.example.secureprint.data.api.NetworkErrorParser.parseError(response, "Failed to delete")
                    deleteError = errorMessage
                }
            } catch (e: Exception) {
                val errorMessage = com.example.secureprint.data.api.NetworkErrorParser.parseException(e)
                deleteError = errorMessage
            }
        }
    }
}

