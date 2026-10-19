package com.example.secureprint.data.api

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonPrimitive
import retrofit2.Response
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException

object NetworkErrorParser {

    private val jsonParser = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    /**
     * Parses the error body from a Retrofit Response into a clear, user-facing error message.
     */
    fun parseError(response: Response<*>?, defaultMessage: String = "Request failed"): String {
        if (response == null) return defaultMessage

        val rawBody = try {
            response.errorBody()?.string()
        } catch (_: Exception) {
            null
        }

        if (!rawBody.isNullOrBlank()) {
            val parsedDetail = parseDetailFromJson(rawBody)
            if (!parsedDetail.isNullOrBlank()) {
                return parsedDetail
            }

            // If raw body is a short plain-text message (not HTML), use it
            if (!rawBody.trim().startsWith("<") && rawBody.length <= 150) {
                return rawBody.trim()
            }
        }

        val httpMsg = response.message()
        return when (response.code()) {
            400 -> if (httpMsg.isNotBlank()) httpMsg else "Invalid request data (Bad Request)"
            401 -> "Invalid credentials or session expired"
            403 -> "Access forbidden: Account pending approval or inactive"
            404 -> "Requested resource not found"
            409 -> "Resource already exists"
            422 -> "Validation error: Check submitted information"
            500 -> "Internal server error. Please try again later."
            else -> if (httpMsg.isNotBlank()) "Error ${response.code()}: $httpMsg" else "Error ${response.code()}"
        }
    }

    /**
     * Extracts FastAPI's "detail" field from JSON response bodies.
     * Supports both string details and Pydantic validation error lists.
     */
    private fun parseDetailFromJson(jsonString: String): String? {
        return try {
            val element = jsonParser.parseToJsonElement(jsonString)
            if (element is JsonObject && element.containsKey("detail")) {
                when (val detail = element["detail"]) {
                    is JsonPrimitive -> detail.content
                    is JsonArray -> {
                        val messages = detail.mapNotNull { item ->
                            if (item is JsonObject) {
                                val field = item["loc"]?.let { loc ->
                                    if (loc is JsonArray) loc.lastOrNull()?.jsonPrimitive?.content else null
                                }
                                val msg = item["msg"]?.jsonPrimitive?.content
                                if (field != null && msg != null) "$field: $msg" else msg
                            } else {
                                item.toString()
                            }
                        }
                        if (messages.isNotEmpty()) messages.joinToString("; ") else null
                    }
                    else -> null
                }
            } else {
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Translates network exceptions into actionable, diagnostic messages.
     */
    fun parseException(e: Throwable, targetUrl: String = ApiConfig.baseUrl): String {
        return when (e) {
            is ConnectException -> {
                "Cannot connect to server at $targetUrl\n\nEnsure backend is running and USB reverse forwarding is active:\nadb reverse tcp:8000 tcp:8000"
            }
            is SocketTimeoutException -> {
                "Connection to $targetUrl timed out. Check your USB connection or server responsiveness."
            }
            is UnknownHostException -> {
                "Unable to resolve host for $targetUrl. Verify your network or emulator configuration."
            }
            else -> {
                e.localizedMessage?.takeIf { it.isNotBlank() } ?: "An unexpected error occurred (${e.javaClass.simpleName})"
            }
        }
    }
}
