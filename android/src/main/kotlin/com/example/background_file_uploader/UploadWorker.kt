package com.example.background_file_uploader

import android.content.Context
import android.content.pm.ServiceInfo
import android.os.Build
import androidx.work.CoroutineWorker
import androidx.work.ForegroundInfo
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

class UploadWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    private val notificationHelper = NotificationHelper(context)
    private var currentUploadId: String? = null

    companion object {
        const val KEY_UPLOAD_REQUEST = "upload_request"
        const val KEY_UPLOAD_ID = "upload_id"
        const val KEY_BYTES_UPLOADED = "bytes_uploaded"
        const val KEY_TOTAL_BYTES = "total_bytes"
        const val KEY_STATUS = "status"
        const val KEY_STATUS_CODE = "status_code"
        const val KEY_RESPONSE = "response"
        const val KEY_ERROR = "error"
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val requestJson = inputData.getString(KEY_UPLOAD_REQUEST)
            ?: return@withContext Result.failure()

        val uploadRequest = try {
            UploadRequest.fromJson(requestJson)
        } catch (e: Exception) {
            return@withContext Result.failure(
                workDataOf(KEY_ERROR to "Invalid upload request: ${e.message}")
            )
        }

        currentUploadId = uploadRequest.uploadId

        // Set foreground if showing notification
        if (uploadRequest.showNotification) {
            setForeground(createForegroundInfo(uploadRequest, 0))
        }

        try {
            performUpload(uploadRequest)
        } catch (e: Exception) {
            Result.failure(
                workDataOf(
                    KEY_UPLOAD_ID to uploadRequest.uploadId,
                    KEY_STATUS to UploadStatus.FAILED.toMap(),
                    KEY_ERROR to (e.message ?: "Unknown error")
                )
            )
        }
    }

    private suspend fun performUpload(request: UploadRequest): Result {
        val file = File(request.filePath)
        if (!file.exists()) {
            return Result.failure(
                workDataOf(
                    KEY_UPLOAD_ID to request.uploadId,
                    KEY_STATUS to UploadStatus.FAILED.toMap(),
                    KEY_ERROR to "File not found: ${request.filePath}"
                )
            )
        }

        val totalBytes = file.length()
        var uploadedBytes = 0L

        try {
            val client = OkHttpClient.Builder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
                .readTimeout(30, TimeUnit.SECONDS)
                .build()

            // Build multipart request
            val requestBodyBuilder = MultipartBody.Builder()
                .setType(MultipartBody.FORM)

            // Add form fields
            request.fields.forEach { (key, value) ->
                requestBodyBuilder.addFormDataPart(key, value)
            }

            // Add file with progress tracking
            val fileBody = file.asRequestBody("application/octet-stream".toMediaTypeOrNull())
            val progressRequestBody = ProgressRequestBody(fileBody, totalBytes) { bytesWritten ->
                uploadedBytes = bytesWritten
                val progress = ((bytesWritten.toFloat() / totalBytes) * 100).toInt()
                
                // Update notification
                if (request.showNotification) {
                    updateNotification(request, progress)
                }

                // Update progress data
                setProgressAsync(
                    workDataOf(
                        KEY_UPLOAD_ID to request.uploadId,
                        KEY_BYTES_UPLOADED to bytesWritten,
                        KEY_TOTAL_BYTES to totalBytes,
                        KEY_STATUS to UploadStatus.UPLOADING.toMap()
                    )
                )
            }

            requestBodyBuilder.addFormDataPart(
                request.fileFieldName,
                file.name,
                progressRequestBody
            )

            val requestBody = requestBodyBuilder.build()

            // Build HTTP request
            val httpRequestBuilder = Request.Builder()
                .url(request.url)
                .method(request.method, requestBody)

            // Add headers
            request.headers.forEach { (key, value) ->
                httpRequestBuilder.addHeader(key, value)
            }

            val httpRequest = httpRequestBuilder.build()

            // Execute request
            val response = client.newCall(httpRequest).execute()
            val responseBody = response.body?.string()

            return if (response.isSuccessful) {
                // Show success notification
                if (request.showNotification) {
                    showCompletionNotification(request, true)
                }

                Result.success(
                    workDataOf(
                        KEY_UPLOAD_ID to request.uploadId,
                        KEY_STATUS to UploadStatus.COMPLETED.toMap(),
                        KEY_STATUS_CODE to response.code,
                        KEY_RESPONSE to responseBody
                    )
                )
            } else {
                // Show failure notification
                if (request.showNotification) {
                    showCompletionNotification(request, false)
                }

                Result.failure(
                    workDataOf(
                        KEY_UPLOAD_ID to request.uploadId,
                        KEY_STATUS to UploadStatus.FAILED.toMap(),
                        KEY_STATUS_CODE to response.code,
                        KEY_ERROR to "HTTP ${response.code}: ${response.message}"
                    )
                )
            }
        } catch (e: IOException) {
            if (request.showNotification) {
                showCompletionNotification(request, false)
            }

            return Result.retry()
        } catch (e: Exception) {
            if (request.showNotification) {
                showCompletionNotification(request, false)
            }

            return Result.failure(
                workDataOf(
                    KEY_UPLOAD_ID to request.uploadId,
                    KEY_STATUS to UploadStatus.FAILED.toMap(),
                    KEY_ERROR to (e.message ?: "Unknown error")
                )
            )
        }
    }

    private fun createForegroundInfo(request: UploadRequest, progress: Int): ForegroundInfo {
        val title = request.notificationTitle ?: "Uploading file"
        val description = request.notificationDescription ?: "Upload in progress..."
        val notification = notificationHelper.buildProgressNotification(
            request.uploadId,
            title,
            description,
            progress
        )

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ForegroundInfo(
                notificationHelper.getNotificationId(request.uploadId),
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            ForegroundInfo(
                notificationHelper.getNotificationId(request.uploadId),
                notification
            )
        }
    }

    private fun updateNotification(request: UploadRequest, progress: Int) {
        val title = request.notificationTitle ?: "Uploading file"
        val description = "$progress% complete"
        val notification = notificationHelper.buildProgressNotification(
            request.uploadId,
            title,
            description,
            progress
        )
        notificationHelper.showNotification(
            notificationHelper.getNotificationId(request.uploadId),
            notification
        )
    }

    private fun showCompletionNotification(request: UploadRequest, isSuccess: Boolean) {
        val title = if (isSuccess) "Upload complete" else "Upload failed"
        val description = request.notificationTitle ?: File(request.filePath).name
        val notification = notificationHelper.buildCompletedNotification(
            title,
            description,
            isSuccess
        )
        notificationHelper.showNotification(
            notificationHelper.getNotificationId(request.uploadId),
            notification
        )
    }
}

// Helper class to track upload progress
class ProgressRequestBody(
    private val requestBody: okhttp3.RequestBody,
    private val totalBytes: Long,
    private val onProgress: (Long) -> Unit
) : okhttp3.RequestBody() {

    override fun contentType() = requestBody.contentType()

    override fun contentLength() = totalBytes

    override fun writeTo(sink: okio.BufferedSink) {
        val progressSink = object : okio.ForwardingSink(sink) {
            var bytesWritten = 0L

            override fun write(source: okio.Buffer, byteCount: Long) {
                super.write(source, byteCount)
                bytesWritten += byteCount
                onProgress(bytesWritten)
            }
        }

        val bufferedSink = okio.buffer(progressSink)
        requestBody.writeTo(bufferedSink)
        bufferedSink.flush()
    }
}
