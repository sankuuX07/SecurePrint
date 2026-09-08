package com.example.secureprint.data.repository

import com.example.secureprint.data.api.RetrofitClient
import com.example.secureprint.data.model.DocumentResponse
import okhttp3.MultipartBody
import retrofit2.Response

class DocumentRepository {
    private val documentApi = RetrofitClient.documentApi

    suspend fun uploadDocument(file: MultipartBody.Part): Response<DocumentResponse> {
        return documentApi.uploadDocument(file)
    }

    suspend fun getMyDocuments(status: String? = null, search: String? = null): Response<List<DocumentResponse>> {
        return documentApi.getMyDocuments(status, search)
    }

    suspend fun getDocument(id: String): Response<DocumentResponse> {
        return documentApi.getDocument(id)
    }

    suspend fun deleteDocument(id: String): Response<Unit> {
        return documentApi.deleteDocument(id)
    }
}
