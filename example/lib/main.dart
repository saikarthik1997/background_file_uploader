import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:background_file_uploader/background_file_uploader.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Background File Uploader Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _uploader = BackgroundFileUploader();
  final Map<String, UploadProgress> _uploadProgress = {};
  final Map<String, String> _uploadFiles = {};
  StreamSubscription<UploadProgress>? _progressSubscription;
  StreamSubscription<UploadResult>? _resultSubscription;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _progressSubscription = _uploader.progressStream.listen((progress) {
      setState(() {
        _uploadProgress[progress.uploadId] = progress;
      });
    });

    _resultSubscription = _uploader.resultStream.listen((result) {
      setState(() {
        _uploadProgress.remove(result.uploadId);
      });

      // Show result dialog
      _showResultDialog(result);
    });
  }

  Future<void> _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;

        // Show upload configuration dialog
        _showUploadDialog(filePath, fileName);
      }
    } catch (e) {
      _showErrorDialog('Failed to pick file: $e');
    }
  }

  void _showUploadDialog(String filePath, String fileName) {
    final urlController = TextEditingController(
      text:
          'https://1348cfa4-6228-4242-8511-0c22c5de2c12.mock.pstmn.io/uploadFile', // Test endpoint
    );
    final headerKeyController = TextEditingController(text: 'Authorization');
    final headerValueController = TextEditingController(
      text: 'Bearer token123',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Configuration'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File: $fileName',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Upload URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: headerKeyController,
                decoration: const InputDecoration(
                  labelText: 'Header Key (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: headerValueController,
                decoration: const InputDecoration(
                  labelText: 'Header Value (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startUpload(
                filePath,
                fileName,
                urlController.text,
                headerKeyController.text.isNotEmpty
                    ? {headerKeyController.text: headerValueController.text}
                    : null,
              );
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  Future<void> _startUpload(
    String filePath,
    String fileName,
    String url,
    Map<String, String>? headers,
  ) async {
    try {
      final uploadId = await _uploader.uploadFile(
        filePath: filePath,
        url: url,
        headers: headers,
        notificationTitle: 'Uploading $fileName',
        notificationDescription: 'Upload in progress...',
        showNotification: true,
      );

      if (uploadId != null) {
        setState(() {
          _uploadFiles[uploadId] = fileName;
          _uploadProgress[uploadId] = UploadProgress(
            uploadId: uploadId,
            bytesUploaded: 0,
            totalBytes: File(filePath).lengthSync(),
            status: UploadStatus.queued,
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload started for $fileName')),
          );
        }
      } else {
        _showErrorDialog('Failed to start upload');
      }
    } catch (e) {
      _showErrorDialog('Error starting upload: $e');
    }
  }

  void _cancelUpload(String uploadId) async {
    final success = await _uploader.cancelUpload(uploadId);
    if (success) {
      setState(() {
        _uploadProgress.remove(uploadId);
        _uploadFiles.remove(uploadId);
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Upload cancelled')));
      }
    }
  }

  void _showResultDialog(UploadResult result) {
    final fileName = _uploadFiles[result.uploadId] ?? 'Unknown file';
    _uploadFiles.remove(result.uploadId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          result.status == UploadStatus.completed
              ? 'Upload Complete'
              : 'Upload Failed',
          style: TextStyle(
            color: result.status == UploadStatus.completed
                ? Colors.green
                : Colors.red,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: $fileName'),
            const SizedBox(height: 8),
            Text('Status: ${result.status.name}'),
            if (result.statusCode != null) ...[
              const SizedBox(height: 8),
              Text('HTTP Status: ${result.statusCode}'),
            ],
            if (result.error != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error: ${result.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _resultSubscription?.cancel();
    _uploader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Background File Uploader'),
      ),
      body: _uploadProgress.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload, size: 100, color: Colors.grey[400]),
                  const SizedBox(height: 24),
                  Text(
                    'No active uploads',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tap the + button to select a file',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _uploadProgress.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final uploadId = _uploadProgress.keys.elementAt(index);
                final progress = _uploadProgress[uploadId]!;
                final fileName = _uploadFiles[uploadId] ?? 'Unknown file';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                fileName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () => _cancelUpload(uploadId),
                              tooltip: 'Cancel upload',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: progress.percentage / 100,
                          backgroundColor: Colors.grey[200],
                          minHeight: 8,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${progress.percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                            Text(
                              '${_formatBytes(progress.bytesUploaded)} / ${_formatBytes(progress.totalBytes)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Status: ${progress.status.name}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndUploadFile,
        tooltip: 'Pick and upload file',
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
