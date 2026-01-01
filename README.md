# background_file_uploader

A Flutter plugin for uploading files in the background with progress notifications on both Android and iOS.

## Features

✅ **Background Upload** - Files continue uploading even when the app is in the background  
✅ **Progress Tracking** - Real-time upload progress updates via streams  
✅ **Native Notifications** - Platform-native notifications showing upload progress  
✅ **Android WorkManager** - Reliable background uploads using WorkManager  
✅ **iOS URLSession** - Background uploads using URLSession background tasks  
✅ **Multipart Form Data** - Support for additional form fields with file uploads  
✅ **Custom Headers** - Add custom HTTP headers (e.g., Authorization tokens)  
✅ **Upload Cancellation** - Cancel ongoing uploads programmatically  
✅ **Error Handling** - Comprehensive error handling and retry logic  

## Platform Support

| Platform | Minimum Version |
|----------|----------------|
| Android  | API 24 (Android 7.0) |
| iOS      | iOS 12.0+ |

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  background_file_uploader: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## Platform-Specific Setup

### Android

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Required for network access -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <!-- Required for foreground service (Android 9+) -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
    
    <!-- Required for notifications (Android 13+) -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    
    <application>
        ...
    </application>
</manifest>
```

### iOS

1. **Enable Background Modes** in Xcode:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select your project target
   - Go to "Signing & Capabilities"
   - Click "+ Capability" and add "Background Modes"
   - Check "Background fetch" and "Remote notifications"

2. **Request Notification Permissions**:
   The plugin automatically requests notification permissions, but you can also request them manually in your app.

## Usage

### Basic Upload

```dart
import 'package:background_file_uploader/background_file_uploader.dart';

final uploader = BackgroundFileUploader();

// Start an upload
final uploadId = await uploader.uploadFile(
  filePath: '/path/to/file.jpg',
  url: 'https://your-server.com/upload',
  notificationTitle: 'Uploading image',
  showNotification: true,
);
```

### Upload with Custom Headers

```dart
final uploadId = await uploader.uploadFile(
  filePath: '/path/to/file.pdf',
  url: 'https://your-server.com/upload',
  headers: {
    'Authorization': 'Bearer your_token_here',
    'Custom-Header': 'value',
  },
  notificationTitle: 'Uploading document',
);
```

### Upload with Form Fields

```dart
final uploadId = await uploader.uploadFile(
  filePath: '/path/to/file.jpg',
  url: 'https://your-server.com/upload',
  fields: {
    'user_id': '12345',
    'description': 'Profile picture',
  },
  fileFieldName: 'photo', // Default is 'file'
);
```

### Track Upload Progress

```dart
// Listen to progress updates
uploader.progressStream.listen((progress) {
  print('Upload ${progress.uploadId}: ${progress.percentage}%');
  print('${progress.bytesUploaded} / ${progress.totalBytes} bytes');
  print('Status: ${progress.status}');
});

// Listen to upload results
uploader.resultStream.listen((result) {
  if (result.status == UploadStatus.completed) {
    print('Upload completed! Status code: ${result.statusCode}');
    print('Response: ${result.response}');
  } else {
    print('Upload failed: ${result.error}');
  }
});
```

### Cancel an Upload

```dart
final success = await uploader.cancelUpload(uploadId);
if (success) {
  print('Upload cancelled');
}
```

### Check Upload Status

```dart
final progress = await uploader.getUploadStatus(uploadId);
if (progress != null) {
  print('Status: ${progress.status}');
  print('Progress: ${progress.percentage}%');
}
```

### Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:background_file_uploader/background_file_uploader.dart';
import 'package:file_picker/file_picker.dart';

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _uploader = BackgroundFileUploader();
  String? _currentUploadId;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Listen to progress
    _uploader.progressStream.listen((progress) {
      if (progress.uploadId == _currentUploadId) {
        setState(() {
          _progress = progress.percentage;
        });
      }
    });

    // Listen to results
    _uploader.resultStream.listen((result) {
      if (result.uploadId == _currentUploadId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.status == UploadStatus.completed
                  ? 'Upload completed!'
                  : 'Upload failed: ${result.error}',
            ),
          ),
        );
      }
    });
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles();
    
    if (result != null && result.files.single.path != null) {
      final uploadId = await _uploader.uploadFile(
        filePath: result.files.single.path!,
        url: 'https://your-server.com/upload',
        notificationTitle: 'Uploading ${result.files.single.name}',
      );
      
      setState(() {
        _currentUploadId = uploadId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('File Upload')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_currentUploadId != null) ...[
              CircularProgressIndicator(value: _progress / 100),
              SizedBox(height: 16),
              Text('${_progress.toStringAsFixed(1)}%'),
            ],
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _pickAndUpload,
              child: Text('Pick and Upload File'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _uploader.dispose();
    super.dispose();
  }
}
```

## API Reference

### BackgroundFileUploader

#### Methods

- **`uploadFile()`** - Start a background file upload
  - `filePath` (required): Absolute path to the file
  - `url` (required): Upload endpoint URL
  - `method`: HTTP method (default: 'POST')
  - `headers`: Custom HTTP headers
  - `fields`: Additional form fields
  - `fileFieldName`: Name of the file field (default: 'file')
  - `notificationTitle`: Notification title
  - `notificationDescription`: Notification description
  - `showNotification`: Show upload notifications (default: true)
  - Returns: Upload ID or null if failed

- **`cancelUpload(uploadId)`** - Cancel an ongoing upload
  - Returns: true if cancelled successfully

- **`getUploadStatus(uploadId)`** - Get current upload status
  - Returns: UploadProgress or null

#### Streams

- **`progressStream`** - Stream of upload progress updates
- **`resultStream`** - Stream of upload results (completion/failure)

### Data Models

#### UploadStatus
- `queued` - Upload is queued
- `uploading` - Upload in progress
- `completed` - Upload completed successfully
- `failed` - Upload failed
- `cancelled` - Upload was cancelled

#### UploadProgress
- `uploadId`: Unique upload identifier
- `bytesUploaded`: Bytes uploaded so far
- `totalBytes`: Total bytes to upload
- `percentage`: Upload progress (0-100)
- `status`: Current upload status

#### UploadResult
- `uploadId`: Unique upload identifier
- `status`: Final upload status
- `statusCode`: HTTP status code (if completed)
- `response`: Server response body (if completed)
- `error`: Error message (if failed)

## Troubleshooting

### Android

**Notifications not showing:**
- Ensure `POST_NOTIFICATIONS` permission is granted on Android 13+
- Check that notification channel is created properly

**Upload not continuing in background:**
- Verify WorkManager dependencies are included
- Check that battery optimization is disabled for your app

### iOS

**Upload stops when app is backgrounded:**
- Ensure Background Modes capability is enabled in Xcode
- Verify "Background fetch" is checked in Background Modes

**Notifications not appearing:**
- Check that notification permissions are granted
- Verify notification authorization in iOS Settings

## Limitations

- **iOS**: Background uploads may be suspended by the system if the device is low on battery
- **Android**: WorkManager may delay uploads based on system constraints (battery, network)
- Maximum file size depends on server configuration and network conditions

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues, feature requests, or questions, please file an issue on the [GitHub repository](https://github.com/saikarthik1997/background_file_uploader).
