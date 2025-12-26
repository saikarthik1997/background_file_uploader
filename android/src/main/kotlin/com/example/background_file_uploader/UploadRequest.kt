package com.example.background_file_uploader

import com.google.gson.Gson

data class UploadRequest(
    val uploadId: String,
    val filePath: String,
    val url: String,
    val method: String = "POST",
    val headers: Map<String, String> = emptyMap(),
    val fields: Map<String, String> = emptyMap(),
    val fileFieldName: String = "file",
    val notificationTitle: String? = null,
    val notificationDescription: String? = null,
    val showNotification: Boolean = true
) {
    fun toJson(): String = Gson().toJson(this)

    companion object {
        fun fromJson(json: String): UploadRequest = Gson().fromJson(json, UploadRequest::class.java)
        
        fun fromMap(map: Map<String, Any>): UploadRequest {
            return UploadRequest(
                uploadId = map["uploadId"] as String,
                filePath = map["filePath"] as String,
                url = map["url"] as String,
                method = map["method"] as? String ?: "POST",
                headers = (map["headers"] as? Map<*, *>)?.mapKeys { it.key.toString() }?.mapValues { it.value.toString() } ?: emptyMap(),
                fields = (map["fields"] as? Map<*, *>)?.mapKeys { it.key.toString() }?.mapValues { it.value.toString() } ?: emptyMap(),
                fileFieldName = map["fileFieldName"] as? String ?: "file",
                notificationTitle = map["notificationTitle"] as? String,
                notificationDescription = map["notificationDescription"] as? String,
                showNotification = map["showNotification"] as? Boolean ?: true
            )
        }
    }
}

enum class UploadStatus {
    QUEUED,
    UPLOADING,
    COMPLETED,
    FAILED,
    CANCELLED;

    fun toMap(): String = name.lowercase()
}

data class UploadProgressData(
    val uploadId: String,
    val bytesUploaded: Long,
    val totalBytes: Long,
    val status: UploadStatus
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "uploadId" to uploadId,
            "bytesUploaded" to bytesUploaded,
            "totalBytes" to totalBytes,
            "status" to status.toMap()
        )
    }
}

data class UploadResultData(
    val uploadId: String,
    val status: UploadStatus,
    val statusCode: Int? = null,
    val response: String? = null,
    val error: String? = null
) {
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "uploadId" to uploadId,
            "status" to status.toMap(),
            "statusCode" to statusCode,
            "response" to response,
            "error" to error
        )
    }
}
