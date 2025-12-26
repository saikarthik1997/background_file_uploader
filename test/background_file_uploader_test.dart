import 'package:flutter_test/flutter_test.dart';
import 'package:background_file_uploader/background_file_uploader.dart';
import 'package:background_file_uploader/upload_task.dart';

void main() {
  test('UploadTask serialization', () {
    final task = UploadTask(
      uploadId: 'test123',
      filePath: '/path/to/file.txt',
      url: 'https://example.com/upload',
      method: 'POST',
      headers: {'Authorization': 'Bearer token'},
      fields: {'user_id': '123'},
      fileFieldName: 'file',
      notificationTitle: 'Test Upload',
      showNotification: true,
    );

    final map = task.toMap();
    expect(map['uploadId'], 'test123');
    expect(map['filePath'], '/path/to/file.txt');
    expect(map['url'], 'https://example.com/upload');
    expect(map['method'], 'POST');
    expect(map['headers'], {'Authorization': 'Bearer token'});
    expect(map['fields'], {'user_id': '123'});
    expect(map['fileFieldName'], 'file');
    expect(map['notificationTitle'], 'Test Upload');
    expect(map['showNotification'], true);

    final deserialized = UploadTask.fromMap(map);
    expect(deserialized.uploadId, task.uploadId);
    expect(deserialized.filePath, task.filePath);
    expect(deserialized.url, task.url);
  });

  test('UploadProgress calculation', () {
    final progress = UploadProgress(
      uploadId: 'test123',
      bytesUploaded: 50,
      totalBytes: 100,
      status: UploadStatus.uploading,
    );

    expect(progress.percentage, 50.0);
  });

  test('UploadResult success check', () {
    final successResult = UploadResult(
      uploadId: 'test123',
      status: UploadStatus.completed,
      statusCode: 200,
    );

    expect(successResult.isSuccess, true);

    final failedResult = UploadResult(
      uploadId: 'test123',
      status: UploadStatus.failed,
      statusCode: 500,
    );

    expect(failedResult.isSuccess, false);
  });
}
