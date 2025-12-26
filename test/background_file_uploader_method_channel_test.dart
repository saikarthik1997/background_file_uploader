import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:background_file_uploader/background_file_uploader_method_channel.dart';
import 'package:background_file_uploader/upload_task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelBackgroundFileUploader platform = MethodChannelBackgroundFileUploader();
  const MethodChannel channel = MethodChannel('background_file_uploader');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'uploadFile') {
          return 'test_upload_id';
        } else if (methodCall.method == 'cancelUpload') {
          return true;
        } else if (methodCall.method == 'getUploadStatus') {
          return {
            'uploadId': 'test_upload_id',
            'bytesUploaded': 50,
            'totalBytes': 100,
            'status': 'uploading',
          };
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('uploadFile returns upload ID', () async {
    final task = UploadTask(
      uploadId: 'test123',
      filePath: '/path/to/file.txt',
      url: 'https://example.com/upload',
    );
    
    expect(await platform.uploadFile(task), 'test_upload_id');
  });

  test('cancelUpload returns true', () async {
    expect(await platform.cancelUpload('test_upload_id'), true);
  });

  test('getUploadStatus returns progress', () async {
    final progress = await platform.getUploadStatus('test_upload_id');
    expect(progress, isNotNull);
    expect(progress!.uploadId, 'test_upload_id');
    expect(progress.bytesUploaded, 50);
    expect(progress.totalBytes, 100);
  });
}
