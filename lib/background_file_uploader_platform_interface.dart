import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'background_file_uploader_method_channel.dart';
import 'upload_task.dart';

abstract class BackgroundFileUploaderPlatform extends PlatformInterface {
  /// Constructs a BackgroundFileUploaderPlatform.
  BackgroundFileUploaderPlatform() : super(token: _token);

  static final Object _token = Object();

  static BackgroundFileUploaderPlatform _instance =
      MethodChannelBackgroundFileUploader();

  /// The default instance of [BackgroundFileUploaderPlatform] to use.
  ///
  /// Defaults to [MethodChannelBackgroundFileUploader].
  static BackgroundFileUploaderPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [BackgroundFileUploaderPlatform] when
  /// they register themselves.
  static set instance(BackgroundFileUploaderPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Start a background upload task.
  ///
  /// Returns the upload ID if successful, null otherwise.
  Future<String?> uploadFile(UploadTask task) {
    throw UnimplementedError('uploadFile() has not been implemented.');
  }

  /// Cancel an ongoing upload.
  ///
  /// Returns true if the upload was successfully cancelled.
  Future<bool> cancelUpload(String uploadId) {
    throw UnimplementedError('cancelUpload() has not been implemented.');
  }

  /// Get the current status of an upload.
  Future<UploadProgress?> getUploadStatus(String uploadId) {
    throw UnimplementedError('getUploadStatus() has not been implemented.');
  }

  /// Stream of upload progress updates.
  Stream<UploadProgress> get progressStream {
    throw UnimplementedError('progressStream has not been implemented.');
  }

  /// Stream of upload results (completion/failure).
  Stream<UploadResult> get resultStream {
    throw UnimplementedError('resultStream has not been implemented.');
  }
}
