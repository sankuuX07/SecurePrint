package com.example.secureprint.data.api

import com.example.secureprint.BuildConfig
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Response
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import java.util.concurrent.TimeUnit

/**
 * Interceptor that dynamically routes requests to the active base URL in ApiConfig.
 * This allows switching between physical device (127.0.0.1:8000) and emulator (10.0.2.2:8000)
 * without recreating Retrofit instances or API services.
 */
class DynamicHostInterceptor : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        var request = chain.request()
        val currentBaseUrl = ApiConfig.baseUrl.toHttpUrlOrNull()
        if (currentBaseUrl != null) {
            val newUrl = request.url.newBuilder()
                .scheme(currentBaseUrl.scheme)
                .host(currentBaseUrl.host)
                .port(currentBaseUrl.port)
                .build()
            request = request.newBuilder().url(newUrl).build()
        }
        return chain.proceed(request)
    }
}

object RetrofitClient {

    val currentBaseUrl: String
        get() = ApiConfig.baseUrl

    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
    }

    private val okHttpClient = OkHttpClient.Builder().apply {
        connectTimeout(30, TimeUnit.SECONDS)
        readTimeout(60, TimeUnit.SECONDS)
        writeTimeout(60, TimeUnit.SECONDS)
        addInterceptor(DynamicHostInterceptor())
        if (BuildConfig.DEBUG) {
            addInterceptor(HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BODY
                redactHeader("Authorization")
            })
        }
        addInterceptor(com.example.secureprint.data.auth.AuthInterceptor())
    }.build()

    private val retrofit: Retrofit = Retrofit.Builder()
        .baseUrl(ApiConfig.PHYSICAL_DEVICE_URL)
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
