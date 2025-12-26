/// Represents the status of an upload task.
enum UploadStatus {
  /// Upload is queued and waiting to start
  queued,

  /// Upload is currently in progress
  uploading,

  /// Upload completed successfully
  completed,

  /// Upload failed
  failed,

  /// Upload was cancelled
  cancelled,
}

/// Represents the progress of an upload.
class UploadProgress {
  /// Unique identifier for the upload task
  final String uploadId;

  /// Number of bytes uploaded so far
  final int bytesUploaded;

  /// Total number of bytes to upload
  final int totalBytes;

  /// Upload progress as a percentage (0-100)
  double get percentage =>
      totalBytes > 0 ? (bytesUploaded / totalBytes) * 100 : 0;

  /// Current status of the upload
  final UploadStatus status;

  const UploadProgress({
    required this.uploadId,
    required this.bytesUploaded,
    required this.totalBytes,
    required this.status,
  });

  factory UploadProgress.fromMap(Map<String, dynamic> map) {
    return UploadProgress(
      uploadId: map['uploadId'] as String,
      bytesUploaded: map['bytesUploaded'] as int,
      totalBytes: map['totalBytes'] as int,
      status: UploadStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => UploadStatus.queued,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uploadId': uploadId,
      'bytesUploaded': bytesUploaded,
      'totalBytes': totalBytes,
      'status': status.name,
    };
  }

  @override
  String toString() {
    return 'UploadProgress(uploadId: $uploadId, bytesUploaded: $bytesUploaded, totalBytes: $totalBytes, percentage: ${percentage.toStringAsFixed(1)}%, status: $status)';
  }
}

/// Configuration for an upload task.
class UploadTask {
  /// Unique identifier for this upload task
  final String uploadId;

  /// Absolute path to the file to upload
  final String filePath;

  /// Upload URL endpoint
  final String url;

  /// HTTP method (default: POST)
  final String method;

  /// HTTP headers to include in the request
  final Map<String, String> headers;

  /// Additional form fields to include in the multipart request
  final Map<String, String> fields;

  /// Name of the file field in the multipart request (default: 'file')
  final String fileFieldName;

  /// Notification title (optional)
  final String? notificationTitle;

  /// Notification description (optional)
  final String? notificationDescription;

  /// Whether to show notifications (default: true)
  final bool showNotification;

  const UploadTask({
    required this.uploadId,
    required this.filePath,
    required this.url,
    this.method = 'POST',
    this.headers = const {},
    this.fields = const {},
    this.fileFieldName = 'file',
    this.notificationTitle,
    this.notificationDescription,
    this.showNotification = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'uploadId': uploadId,
      'filePath': filePath,
      'url': url,
      'method': method,
      'headers': headers,
      'fields': fields,
      'fileFieldName': fileFieldName,
      'notificationTitle': notificationTitle,
      'notificationDescription': notificationDescription,
      'showNotification': showNotification,
    };
  }

  factory UploadTask.fromMap(Map<String, dynamic> map) {
    return UploadTask(
      uploadId: map['uploadId'] as String,
      filePath: map['filePath'] as String,
      url: map['url'] as String,
      method: map['method'] as String? ?? 'POST',
      headers: Map<String, String>.from(map['headers'] as Map? ?? {}),
      fields: Map<String, String>.from(map['fields'] as Map? ?? {}),
      fileFieldName: map['fileFieldName'] as String? ?? 'file',
      notificationTitle: map['notificationTitle'] as String?,
      notificationDescription: map['notificationDescription'] as String?,
      showNotification: map['showNotification'] as bool? ?? true,
    );
  }

  @override
  String toString() {
    return 'UploadTask(uploadId: $uploadId, filePath: $filePath, url: $url, method: $method)';
  }
}

/// Result of an upload operation.
class UploadResult {
  /// Unique identifier for the upload task
  final String uploadId;

  /// Final status of the upload
  final UploadStatus status;

  /// HTTP status code (if completed)
  final int? statusCode;

  /// Response body (if completed)
  final String? response;

  /// Error message (if failed)
  final String? error;

  const UploadResult({
    required this.uploadId,
    required this.status,
    this.statusCode,
    this.response,
    this.error,
  });

  factory UploadResult.fromMap(Map<String, dynamic> map) {
    return UploadResult(
      uploadId: map['uploadId'] as String,
      status: UploadStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => UploadStatus.failed,
      ),
      statusCode: map['statusCode'] as int?,
      response: map['response'] as String?,
      error: map['error'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uploadId': uploadId,
      'status': status.name,
      'statusCode': statusCode,
      'response': response,
      'error': error,
    };
  }

  /// Whether the upload was successful
  bool get isSuccess => status == UploadStatus.completed && statusCode == 200;

  @override
  String toString() {
    return 'UploadResult(uploadId: $uploadId, status: $status, statusCode: $statusCode, error: $error)';
  }
}
