import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'background_file_uploader_platform_interface.dart';
import 'upload_task.dart';

/// An implementation of [BackgroundFileUploaderPlatform] that uses method channels.
class MethodChannelBackgroundFileUploader
    extends BackgroundFileUploaderPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('background_file_uploader');

  /// The event channel for upload progress updates.
  @visibleForTesting
  final progressEventChannel =
      const EventChannel('background_file_uploader/progress');

  /// The event channel for upload results.
  @visibleForTesting
  final resultEventChannel =
      const EventChannel('background_file_uploader/result');

  Stream<UploadProgress>? _progressStream;
  Stream<UploadResult>? _resultStream;

  @override
  Future<String?> uploadFile(UploadTask task) async {
    try {
      final result = await methodChannel.invokeMethod<String>(
        'uploadFile',
        task.toMap(),
      );
      return result;
    } on PlatformException catch (e) {
      debugPrint('Failed to start upload: ${e.message}');
      return null;
    }
  }

  @override
  Future<bool> cancelUpload(String uploadId) async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'cancelUpload',
        {'uploadId': uploadId},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to cancel upload: ${e.message}');
      return false;
    }
  }

  @override
  Future<UploadProgress?> getUploadStatus(String uploadId) async {
    try {
      final result = await methodChannel.invokeMethod<Map>(
        'getUploadStatus',
        {'uploadId': uploadId},
      );
      if (result != null) {
        return UploadProgress.fromMap(Map<String, dynamic>.from(result));
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint('Failed to get upload status: ${e.message}');
      return null;
    }
  }

  @override
  Stream<UploadProgress> get progressStream {
    _progressStream ??= progressEventChannel
        .receiveBroadcastStream()
        .map((event) => UploadProgress.fromMap(Map<String, dynamic>.from(event as Map)));
    return _progressStream!;
  }

  @override
  Stream<UploadResult> get resultStream {
    _resultStream ??= resultEventChannel
        .receiveBroadcastStream()
        .map((event) => UploadResult.fromMap(Map<String, dynamic>.from(event as Map)));
    return _resultStream!;
  }
}
