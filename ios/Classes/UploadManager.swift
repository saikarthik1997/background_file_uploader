import Foundation

class UploadManager: NSObject {
    static let shared = UploadManager()
    
    private var session: URLSession!
    private var activeTasks: [String: URLSessionUploadTask] = [:]
    private var uploadData: [String: UploadTaskData] = [:]
    private var progressCallbacks: [(UploadProgressData) -> Void] = []
    private var resultCallbacks: [(UploadResultData) -> Void] = []
    
    private override init() {
        super.init()
        
        let config = URLSessionConfiguration.background(withIdentifier: "com.example.background_file_uploader")
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func addProgressCallback(_ callback: @escaping (UploadProgressData) -> Void) {
        progressCallbacks.append(callback)
    }
    
    func addResultCallback(_ callback: @escaping (UploadResultData) -> Void) {
        resultCallbacks.append(callback)
    }
    
    func uploadFile(taskData: UploadTaskData) throws -> String {
        let fileURL = URL(fileURLWithPath: taskData.filePath)
        
        guard FileManager.default.fileExists(atPath: taskData.filePath) else {
            throw NSError(domain: "UploadManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found"])
        }
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        let multipartData = createMultipartBody(fileURL: fileURL, taskData: taskData, boundary: boundary)
        
        // Save multipart data to temp file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try multipartData.write(to: tempURL)
        
        // Create request
        var request = URLRequest(url: URL(string: taskData.url)!)
        request.httpMethod = taskData.method
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Add custom headers
        for (key, value) in taskData.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Create upload task
        let uploadTask = session.uploadTask(with: request, fromFile: tempURL)
        
        // Store task data
        activeTasks[taskData.uploadId] = uploadTask
        uploadData[taskData.uploadId] = taskData
        
        // Start upload
        uploadTask.resume()
        
        return taskData.uploadId
    }
    
    func cancelUpload(uploadId: String) -> Bool {
        guard let task = activeTasks[uploadId] else {
            return false
        }
        
        task.cancel()
        activeTasks.removeValue(forKey: uploadId)
        uploadData.removeValue(forKey: uploadId)
        
        NotificationManager.shared.cancelNotification(uploadId: uploadId)
        
        return true
    }
    
    func getUploadStatus(uploadId: String) -> UploadProgressData? {
        guard let task = activeTasks[uploadId] else {
            return nil
        }
        
        let status: UploadStatusEnum
        switch task.state {
        case .running:
            status = .uploading
        case .suspended:
            status = .queued
        case .canceling:
            status = .cancelled
        case .completed:
            status = .completed
        @unknown default:
            status = .queued
        }
        
        return UploadProgressData(
            uploadId: uploadId,
            bytesUploaded: task.countOfBytesSent,
            totalBytes: task.countOfBytesExpectedToSend,
            status: status
        )
    }
    
    private func createMultipartBody(fileURL: URL, taskData: UploadTaskData, boundary: String) -> Data {
        var body = Data()
        let boundaryPrefix = "--\(boundary)\r\n"
        
        // Add form fields
        for (key, value) in taskData.fields {
            body.append(boundaryPrefix.data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add file
        body.append(boundaryPrefix.data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(taskData.fileFieldName)\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        
        if let fileData = try? Data(contentsOf: fileURL) {
            body.append(fileData)
        }
        
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    private func notifyProgress(_ progress: UploadProgressData) {
        for callback in progressCallbacks {
            callback(progress)
        }
    }
    
    private func notifyResult(_ result: UploadResultData) {
        for callback in resultCallbacks {
            callback(result)
        }
    }
}

// MARK: - URLSessionDelegate
extension UploadManager: URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        // Find upload ID for this task
        guard let uploadId = activeTasks.first(where: { $0.value == task })?.key else {
            return
        }
        
        // Log progress
        let percentage = (Double(totalBytesSent) / Double(totalBytesExpectedToSend)) * 100
        NSLog("[UploadWorker] Upload Progress - ID: %@, Bytes: %lld/%lld (%.1f%%)", uploadId, totalBytesSent, totalBytesExpectedToSend, percentage)
        
        let progress = UploadProgressData(
            uploadId: uploadId,
            bytesUploaded: totalBytesSent,
            totalBytes: totalBytesExpectedToSend,
            status: .uploading
        )
        
        notifyProgress(progress)
        
        // Update notification
        if let taskData = uploadData[uploadId], taskData.showNotification {
            let percentage = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
            let title = taskData.notificationTitle ?? "Uploading file"
            let description = taskData.notificationDescription ?? URL(fileURLWithPath: taskData.filePath).lastPathComponent
            
            NotificationManager.shared.showProgressNotification(
                uploadId: uploadId,
                title: title,
                description: description,
                progress: percentage
            )
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let uploadId = activeTasks.first(where: { $0.value == task })?.key else {
            return
        }
        
        let taskData = uploadData[uploadId]
        
        if let error = error {
            // Log error
            NSLog("[UploadWorker] Upload Failed - ID: %@, Error: %@", uploadId, error.localizedDescription)
            
            // Upload failed
            let result = UploadResultData(
                uploadId: uploadId,
                status: .failed,
                statusCode: nil,
                response: nil,
                error: error.localizedDescription
            )
            
            notifyResult(result)
            
            if taskData?.showNotification == true {
                let title = taskData?.notificationTitle ?? "Upload failed"
                NotificationManager.shared.showCompletionNotification(
                    uploadId: uploadId,
                    title: title,
                    description: error.localizedDescription,
                    isSuccess: false
                )
            }
        } else if let httpResponse = task.response as? HTTPURLResponse {
            // Log success
            NSLog("[UploadWorker] Upload Completed - ID: %@, Status Code: %ld, URL: %@", uploadId, (long)httpResponse.statusCode, httpResponse.url?.absoluteString ?? "unknown")
            
            // Upload completed
            let isSuccess = (200...299).contains(httpResponse.statusCode)
            
            let result = UploadResultData(
                uploadId: uploadId,
                status: isSuccess ? .completed : .failed,
                statusCode: httpResponse.statusCode,
                response: nil,
                error: isSuccess ? nil : "HTTP \(httpResponse.statusCode)"
            )
            
            notifyResult(result)
            
            if taskData?.showNotification == true {
                let title = taskData?.notificationTitle ?? (isSuccess ? "Upload complete" : "Upload failed")
                let description = taskData?.notificationDescription ?? URL(fileURLWithPath: taskData?.filePath ?? "").lastPathComponent
                
                NotificationManager.shared.showCompletionNotification(
                    uploadId: uploadId,
                    title: title,
                    description: description,
                    isSuccess: isSuccess
                )
            }
        }
        
        // Cleanup
        activeTasks.removeValue(forKey: uploadId)
        uploadData.removeValue(forKey: uploadId)
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // Called when all background tasks have completed
        DispatchQueue.main.async {
            // Notify app delegate if needed
        }
    }
}
