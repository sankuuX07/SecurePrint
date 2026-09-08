package com.example.secureprint.data.model

import kotlinx.serialization.Serializable

@Serializable
data class PrintJobCreate(
    val document_id: String,
    val shop_id: Int,
    val copies: Int,
    val page_range: String? = null,
    val color_mode: String,
    val paper_size: String,
    val print_side: String,
    val orientation: String = "Portrait",
    val binding: String? = null,
    val stapling: String? = null
)

@Serializable
data class PrintJobResponse(
    val id: Int,
    val document_id: String,
    val shop_id: Int,
    val customer_id: Int,
    val copies: Int,
    val page_range: String?,
    val color_mode: String,
    val paper_size: String,
    val print_side: String,
    val orientation: String,
    val binding: String?,
    val stapling: String?,
    val price: Double,
    val status: String,
    val created_at: String,
    val accepted_at: String?,
    val printing_at: String?,
    val completed_at: String?,
    val cancelled_at: String?,
    val selected_page_count: Int? = null
)

@Serializable
data class PrintJobStatusHistoryResponse(
    val id: Int,
    val from_status: String? = null,
    val to_status: String,
    val changed_at: String,
    val notes: String? = null
)

@Serializable
data class PrintJobDetailResponse(
    val id: Int,
    val document_id: String,
    val shop_id: Int,
    val customer_id: Int,
    val copies: Int,
    val page_range: String?,
    val color_mode: String,
    val paper_size: String,
    val print_side: String,
    val orientation: String,
    val binding: String?,
    val stapling: String?,
    val price: Double,
    val status: String,
    val created_at: String,
    val accepted_at: String?,
    val printing_at: String?,
    val completed_at: String?,
    val cancelled_at: String?,
    val selected_page_count: Int? = null,
    val status_history: List<PrintJobStatusHistoryResponse> = emptyList()
)

@Serializable
data class PaymentResponse(
    val id: Int,
    val print_job_id: Int,
    val amount: Double,
    val status: String,
    val method: String,
    val paid_at: String? = null
)
