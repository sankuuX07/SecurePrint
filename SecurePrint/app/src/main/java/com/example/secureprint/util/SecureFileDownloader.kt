package com.example.secureprint.util

import android.content.Context
import com.example.secureprint.data.repository.ShopDocumentAccessRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class SecureFileDownloader(
    private val context: Context,
    private val repository: ShopDocumentAccessRepository
) {
    suspend fun downloadSecureDocument(accessId: String, fileName: String): File? = withContext(Dispatchers.IO) {
        try {
            val response = repository.downloadDocument(accessId)
            if (response.isSuccessful) {
                val body = response.body() ?: return@withContext null
                
                // Save to app-private cache directory securely
                val secureDir = File(context.cacheDir, "secure_docs")
                if (!secureDir.exists()) {
                    secureDir.mkdirs()
                }
                
                val secureFile = File(secureDir, fileName)
                var inputStream: InputStream? = null
                var outputStream: FileOutputStream? = null
                
                try {
                    val fileReader = ByteArray(4096)
                    inputStream = body.byteStream()
                    outputStream = FileOutputStream(secureFile)
                    
                    while (true) {
                        val read = inputStream.read(fileReader)
                        if (read == -1) {
                            break
                        }
                        outputStream.write(fileReader, 0, read)
                    }
                    outputStream.flush()
                    return@withContext secureFile
                } finally {
                    inputStream?.close()
                    outputStream?.close()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return@withContext null
    }

    suspend fun clearSecureCache() = withContext(Dispatchers.IO) {
        val secureDir = File(context.cacheDir, "secure_docs")
        if (secureDir.exists()) {
            secureDir.listFiles()?.forEach { it.delete() }
        }
    }
}
