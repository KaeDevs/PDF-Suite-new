package com.example.pdfscanner

import android.content.ContentValues
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.net.toFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.File
import java.io.InputStream
import java.io.OutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.pdfscanner/media_store"
    private val INTENT_CHANNEL = "com.example.pdfscanner/intents"
    private var intentChannel: MethodChannel? = null
    private var pendingPdfPath: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Cache any incoming intent so we can send it to Flutter after engine is ready
        pendingPdfPath = extractPdfFromIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val fileName = call.argument<String>("fileName")
                    val bytes = call.argument<ByteArray>("bytes")
                    val mimeType = call.argument<String>("mimeType")
                    
                    if (fileName != null && bytes != null && mimeType != null) {
                        val success = saveToDownloads(fileName, bytes, mimeType)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
                    }
                }
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        scanFile(path)
                        result.success(true)
                    } else {
                        result.error("INVALID_PATH", "File path is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Set up intent channel and push any pending PDF path
        intentChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTENT_CHANNEL)
        intentChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialPdfPath" -> {
                    result.success(pendingPdfPath)
                    pendingPdfPath = null
                }
                else -> result.notImplemented()
            }
        }
        // Also proactively push if Flutter is already listening
        pendingPdfPath?.let { path ->
            intentChannel?.invokeMethod("openPdf", path)
            pendingPdfPath = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val path = extractPdfFromIntent(intent)
        if (path != null) {
            intentChannel?.invokeMethod("openPdf", path)
                ?: run { pendingPdfPath = path }
        }
    }

    private fun saveToDownloads(fileName: String, bytes: ByteArray, mimeType: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+ - Use MediaStore API
                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    put(MediaStore.MediaColumns.IS_PENDING, 1) // Mark as pending
                }

                val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                uri?.let { fileUri ->
                    contentResolver.openOutputStream(fileUri)?.use { outputStream ->
                        outputStream.write(bytes)
                    }
                    
                    // Mark as not pending - this makes it visible to other apps
                    val updateValues = ContentValues().apply {
                        put(MediaStore.MediaColumns.IS_PENDING, 0)
                    }
                    contentResolver.update(fileUri, updateValues, null, null)
                    
                    // Send broadcast to refresh Downloads app
                    sendBroadcast(Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, fileUri))
                    
                    true
                } ?: false
            } else {
                // Android 9 and below - Direct file system access
                val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                val file = java.io.File(downloadsDir, fileName)
                file.writeBytes(bytes)
                
                // Scan the file so it appears in Downloads app
                scanFile(file.absolutePath)
                true
            }
        } catch (e: IOException) {
            e.printStackTrace()
            false
        }
    }
    
    private fun extractPdfFromIntent(intent: Intent?): String? {
        if (intent == null) return null
        val action = intent.action ?: return null

        fun copyContentUriToCache(uri: Uri): String? {
            return try {
                val input: InputStream? = contentResolver.openInputStream(uri)
                val cacheFile = File.createTempFile("shared_", ".pdf", cacheDir)
                input.use { inp ->
                    if (inp != null) {
                        cacheFile.outputStream().use { out -> inp.copyTo(out) }
                        cacheFile.absolutePath
                    } else null
                }
            } catch (e: Exception) {
                null
            }
        }

        return when (action) {
            Intent.ACTION_VIEW -> {
                val uri = intent.data ?: return null
                val mime = intent.type
                if (mime == "application/pdf" || uri.toString().endsWith(".pdf", ignoreCase = true)) {
                    when (uri.scheme) {
                        "file" -> uri.path
                        "content" -> copyContentUriToCache(uri)
                        else -> null
                    }
                } else null
            }
            Intent.ACTION_SEND -> {
                val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM) ?: return null
                val mime = intent.type
                if (mime == "application/pdf" || uri.toString().endsWith(".pdf", ignoreCase = true)) {
                    when (uri.scheme) {
                        "file" -> uri.path
                        "content" -> copyContentUriToCache(uri)
                        else -> null
                    }
                } else null
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                // For now, open first PDF if multiple are shared
                val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                val first = uris?.firstOrNull() ?: return null
                when (first.scheme) {
                    "file" -> first.path
                    "content" -> copyContentUriToCache(first)
                    else -> null
                }
            }
            else -> null
        }
    }

    private fun scanFile(filePath: String) {
        MediaScannerConnection.scanFile(
            this,
            arrayOf(filePath),
            null
        ) { path, uri ->
            // File has been scanned and added to MediaStore
        }
    }
}