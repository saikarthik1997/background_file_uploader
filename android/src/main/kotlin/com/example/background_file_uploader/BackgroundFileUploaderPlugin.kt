package com.example.background_file_uploader

import android.content.Context
import androidx.work.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/** BackgroundFileUploaderPlugin */
class BackgroundFileUploaderPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var progressEventChannel: EventChannel
    private lateinit var resultEventChannel: EventChannel
    private lateinit var context: Context
    private lateinit var workManager: WorkManager

    private var progressEventSink: EventChannel.EventSink? = null
    private var resultEventSink: EventChannel.EventSink? = null

    // Track active uploads
    private val activeUploads = ConcurrentHashMap<String, UUID>()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        workManager = WorkManager.getInstance(context)

        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "background_file_uploader")
        channel.setMethodCallHandler(this)

        // Set up progress event channel
        progressEventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "background_file_uploader/progress"
        )
        progressEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                progressEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                progressEventSink = null
            }
        })

        // Set up result event channel
        resultEventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "background_file_uploader/result"
        )
        resultEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                resultEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                resultEventSink = null
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "uploadFile" -> {
                try {
                    val uploadRequest = UploadRequest.fromMap(call.arguments as Map<String, Any>)
                    startUpload(uploadRequest, result)
                } catch (e: Exception) {
                    result.error("INVALID_ARGUMENTS", "Failed to parse upload request: ${e.message}", null)
                }
            }
            "cancelUpload" -> {
                val uploadId = call.argument<String>("uploadId")
                if (uploadId != null) {
                    cancelUpload(uploadId, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "uploadId is required", null)
                }
            }
            "getUploadStatus" -> {
                val uploadId = call.argument<String>("uploadId")
                if (uploadId != null) {
                    getUploadStatus(uploadId, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "uploadId is required", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun startUpload(uploadRequest: UploadRequest, result: Result) {
        try {
            // Create work request
            val inputData = workDataOf(
                UploadWorker.KEY_UPLOAD_REQUEST to uploadRequest.toJson()
            )

            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val uploadWorkRequest = OneTimeWorkRequestBuilder<UploadWorker>()
                .setInputData(inputData)
                .setConstraints(constraints)
                .build()

            // Track the work
            activeUploads[uploadRequest.uploadId] = uploadWorkRequest.id

            // Observe work progress
            workManager.getWorkInfoByIdLiveData(uploadWorkRequest.id)
                .observeForever { workInfo ->
                    if (workInfo != null) {
                        handleWorkProgress(uploadRequest.uploadId, workInfo)
                    }
                }

            // Enqueue work
            workManager.enqueue(uploadWorkRequest)

            result.success(uploadRequest.uploadId)
        } catch (e: Exception) {
            result.error("UPLOAD_FAILED", "Failed to start upload: ${e.message}", null)
        }
    }

    private fun cancelUpload(uploadId: String, result: Result) {
        val workId = activeUploads[uploadId]
        if (workId != null) {
            workManager.cancelWorkById(workId)
            activeUploads.remove(uploadId)
            result.success(true)
        } else {
            result.success(false)
        }
    }

    private fun getUploadStatus(uploadId: String, result: Result) {
        val workId = activeUploads[uploadId]
        if (workId != null) {
            val workInfo = workManager.getWorkInfoById(workId).get()
            if (workInfo != null) {
                val progress = workInfo.progress
                val status = when (workInfo.state) {
                    WorkInfo.State.ENQUEUED -> UploadStatus.QUEUED
                    WorkInfo.State.RUNNING -> UploadStatus.UPLOADING
                    WorkInfo.State.SUCCEEDED -> UploadStatus.COMPLETED
                    WorkInfo.State.FAILED -> UploadStatus.FAILED
                    WorkInfo.State.CANCELLED -> UploadStatus.CANCELLED
                    else -> UploadStatus.QUEUED
                }

                val progressData = UploadProgressData(
                    uploadId = uploadId,
                    bytesUploaded = progress.getLong(UploadWorker.KEY_BYTES_UPLOADED, 0),
                    totalBytes = progress.getLong(UploadWorker.KEY_TOTAL_BYTES, 0),
                    status = status
                )

                result.success(progressData.toMap())
            } else {
                result.success(null)
            }
        } else {
            result.success(null)
        }
    }

    private fun handleWorkProgress(uploadId: String, workInfo: WorkInfo) {
        val progress = workInfo.progress

        // Send progress updates
        if (workInfo.state == WorkInfo.State.RUNNING) {
            val bytesUploaded = progress.getLong(UploadWorker.KEY_BYTES_UPLOADED, 0)
            val totalBytes = progress.getLong(UploadWorker.KEY_TOTAL_BYTES, 0)

            if (totalBytes > 0) {
                val progressData = UploadProgressData(
                    uploadId = uploadId,
                    bytesUploaded = bytesUploaded,
                    totalBytes = totalBytes,
                    status = UploadStatus.UPLOADING
                )
                progressEventSink?.success(progressData.toMap())
            }
        }

        // Send result when complete
        if (workInfo.state.isFinished) {
            val outputData = workInfo.outputData
            val status = when (workInfo.state) {
                WorkInfo.State.SUCCEEDED -> UploadStatus.COMPLETED
                WorkInfo.State.FAILED -> UploadStatus.FAILED
                WorkInfo.State.CANCELLED -> UploadStatus.CANCELLED
                else -> UploadStatus.FAILED
            }

            val resultData = UploadResultData(
                uploadId = uploadId,
                status = status,
                statusCode = outputData.getInt(UploadWorker.KEY_STATUS_CODE, -1).takeIf { it != -1 },
                response = outputData.getString(UploadWorker.KEY_RESPONSE),
                error = outputData.getString(UploadWorker.KEY_ERROR)
            )

            resultEventSink?.success(resultData.toMap())
            activeUploads.remove(uploadId)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        progressEventChannel.setStreamHandler(null)
        resultEventChannel.setStreamHandler(null)
    }
}
