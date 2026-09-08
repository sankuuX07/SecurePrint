package com.example.secureprint.data.api

import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory

object RetrofitClient {
    private const val BASE_URL = "http://10.0.2.2:8000/"

    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
    }

    private val okHttpClient = OkHttpClient.Builder()
        .addInterceptor(HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
            redactHeader("Authorization")
        })
        .addInterceptor(com.example.secureprint.data.auth.AuthInterceptor())
        .build()

    private val retrofit = Retrofit.Builder()
        .baseUrl(BASE_URL)
        .client(okHttpClient)
        .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
        .build()

    val authApi: AuthApi = retrofit.create(AuthApi::class.java)
    val userApi: UserApi by lazy {
        retrofit.create(UserApi::class.java)
    }

    val documentApi: DocumentApi by lazy {
        retrofit.create(DocumentApi::class.java)
    }
    
    val shopApi: ShopApi by lazy {
        retrofit.create(ShopApi::class.java)
    }

    val printJobApi: PrintJobApi by lazy {
        retrofit.create(PrintJobApi::class.java)
    }

    val shopDocumentAccessApi: ShopDocumentAccessApi by lazy {
        retrofit.create(ShopDocumentAccessApi::class.java)
    }

    val shopQrApi: ShopQrApi by lazy {
        retrofit.create(ShopQrApi::class.java)
    }

    val paymentApi: PaymentApi by lazy {
        retrofit.create(PaymentApi::class.java)
    }
}
