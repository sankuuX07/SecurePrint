package com.example.secureprint.data.api

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import retrofit2.Response
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException

class NetworkErrorParserTest {

    @Test
    fun testParseFastApiStringDetail() {
        val errorJson = """{"detail": "Email already registered"}"""
        val response = Response.error<Unit>(
            400,
            errorJson.toResponseBody("application/json".toMediaType())
        )

        val message = NetworkErrorParser.parseError(response)
        assertEquals("Email already registered", message)
    }

    @Test
    fun testParseFastApiIncorrectPasswordDetail() {
        val errorJson = """{"detail": "Incorrect email or password"}"""
        val response = Response.error<Unit>(
            400,
            errorJson.toResponseBody("application/json".toMediaType())
        )

        val message = NetworkErrorParser.parseError(response)
        assertEquals("Incorrect email or password", message)
    }

    @Test
    fun testParseFastApiPendingApprovalDetail() {
        val errorJson = """{"detail": "Account pending approval"}"""
        val response = Response.error<Unit>(
            403,
            errorJson.toResponseBody("application/json".toMediaType())
        )

        val message = NetworkErrorParser.parseError(response)
        assertEquals("Account pending approval", message)
    }

    @Test
    fun testParseFastApiValidationArrayDetail() {
        val errorJson = """
            {
                "detail": [
                    {
                        "loc": ["body", "email"],
                        "msg": "value is not a valid email address",
                        "type": "value_error"
                    }
                ]
            }
        """.trimIndent()

        val response = Response.error<Unit>(
            422,
            errorJson.toResponseBody("application/json".toMediaType())
        )

        val message = NetworkErrorParser.parseError(response)
        assertTrue(message.contains("email"))
        assertTrue(message.contains("value is not a valid email address"))
    }

    @Test
    fun testParseConnectExceptionProvidesAdbReverseGuidance() {
        val ex = ConnectException("Failed to connect to /127.0.0.1:8000")
        val message = NetworkErrorParser.parseException(ex, "http://127.0.0.1:8000/")

        assertTrue(message.contains("Cannot connect to server at http://127.0.0.1:8000/"))
        assertTrue(message.contains("adb reverse tcp:8000 tcp:8000"))
    }

    @Test
    fun testParseTimeoutException() {
        val ex = SocketTimeoutException("timeout")
        val message = NetworkErrorParser.parseException(ex, "http://127.0.0.1:8000/")

        assertTrue(message.contains("timed out"))
    }

    @Test
    fun testParseUnknownHostException() {
        val ex = UnknownHostException("unknown host")
        val message = NetworkErrorParser.parseException(ex, "http://127.0.0.1:8000/")

        assertTrue(message.contains("Unable to resolve host"))
    }

    @Test
    fun testFallbackHttpStatusMessageWhenNoBody() {
        val emptyBody = "".toResponseBody("application/json".toMediaType())
        val response = Response.error<Unit>(500, emptyBody)

        val message = NetworkErrorParser.parseError(response)
        assertEquals("Internal server error. Please try again later.", message)
    }
}
