import 'dart:async';

import 'background_file_uploader_platform_interface.dart';
import 'upload_task.dart';

export 'upload_task.dart';

/// Main plugin class for background file uploads.
///
/// Provides methods to upload files in the background with progress tracking
/// and notifications on both Android and iOS.
class BackgroundFileUploader {
  /// Stream controller for managing progress subscriptions
  StreamController<UploadProgress>? _progressController;

  /// Stream controller for managing result subscriptions
  StreamController<UploadResult>? _resultController;

  /// Upload a file in the background.
  ///
  /// [filePath] - Absolute path to the file to upload
  /// [url] - Upload endpoint URL
  /// [method] - HTTP method (default: POST)
  /// [headers] - Optional HTTP headers
  /// [fields] - Optional form fields to include with the upload
  /// [fileFieldName] - Name of the file field in multipart request (default: 'file')
  /// [notificationTitle] - Optional notification title
  /// [notificationDescription] - Optional notification description
  /// [showNotification] - Whether to show upload notifications (default: true)
  ///
  /// Returns the upload ID if successful, null otherwise.
  Future<String?> uploadFile({
    required String filePath,
    required String url,
    String method = 'POST',
    Map<String, String>? headers,
    Map<String, String>? fields,
    String fileFieldName = 'file',
    String? notificationTitle,
    String? notificationDescription,
    bool showNotification = true,
  }) async {
    final uploadId = DateTime.now().millisecondsSinceEpoch.toString();

    final task = UploadTask(
      uploadId: uploadId,
      filePath: filePath,
      url: url,
      method: method,
      headers: headers ?? {},
      fields: fields ?? {},
      fileFieldName: fileFieldName,
      notificationTitle: notificationTitle,
      notificationDescription: notificationDescription,
      showNotification: showNotification,
    );

    return BackgroundFileUploaderPlatform.instance.uploadFile(task);
  }

  /// Cancel an ongoing upload.
  ///
  /// Returns true if the upload was successfully cancelled.
  Future<bool> cancelUpload(String uploadId) {
    return BackgroundFileUploaderPlatform.instance.cancelUpload(uploadId);
  }

  /// Get the current status of an upload.
  Future<UploadProgress?> getUploadStatus(String uploadId) {
    return BackgroundFileUploaderPlatform.instance.getUploadStatus(uploadId);
  }

  /// Stream of upload progress updates.
  ///
  /// Listen to this stream to receive real-time progress updates for all uploads.
  Stream<UploadProgress> get progressStream {
    _progressController ??= StreamController<UploadProgress>.broadcast(
      onListen: () {
        BackgroundFileUploaderPlatform.instance.progressStream.listen(
          (progress) => _progressController?.add(progress),
        );
      },
    );
    return _progressController!.stream;
  }

  /// Stream of upload results.
  ///
  /// Listen to this stream to receive completion/failure notifications for uploads.
  Stream<UploadResult> get resultStream {
    _resultController ??= StreamController<UploadResult>.broadcast(
      onListen: () {
        BackgroundFileUploaderPlatform.instance.resultStream.listen(
          (result) => _resultController?.add(result),
        );
      },
    );
    return _resultController!.stream;
  }

  /// Dispose of resources.
  void dispose() {
    _progressController?.close();
    _resultController?.close();
  }
}
