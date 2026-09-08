package com.example.secureprint.data.model

import kotlinx.serialization.Serializable

@Serializable
data class DocumentResponse(
    val id: String,
    val original_filename: String,
    val mime_type: String? = null,
    val file_size: Long? = null,
    val page_count: Int? = null,
    val status: String,
    val created_at: String,
    val expires_at: String? = null,
    val deleted_at: String? = null
)

@Serializable
data class TemporaryDocumentAccessResponse(
    val id: String,
    val print_job_id: Int,
    val document_id: String,
    val status: String,
    val expires_at: String
)
