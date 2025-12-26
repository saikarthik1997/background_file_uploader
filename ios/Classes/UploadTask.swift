import Foundation

struct UploadTaskData: Codable {
    let uploadId: String
    let filePath: String
    let url: String
    let method: String
    let headers: [String: String]
    let fields: [String: String]
    let fileFieldName: String
    let notificationTitle: String?
    let notificationDescription: String?
    let showNotification: Bool
    
    init(from dict: [String: Any]) {
        self.uploadId = dict["uploadId"] as? String ?? ""
        self.filePath = dict["filePath"] as? String ?? ""
        self.url = dict["url"] as? String ?? ""
        self.method = dict["method"] as? String ?? "POST"
        self.headers = dict["headers"] as? [String: String] ?? [:]
        self.fields = dict["fields"] as? [String: String] ?? [:]
        self.fileFieldName = dict["fileFieldName"] as? String ?? "file"
        self.notificationTitle = dict["notificationTitle"] as? String
        self.notificationDescription = dict["notificationDescription"] as? String
        self.showNotification = dict["showNotification"] as? Bool ?? true
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "uploadId": uploadId,
            "filePath": filePath,
            "url": url,
            "method": method,
            "headers": headers,
            "fields": fields,
            "fileFieldName": fileFieldName,
            "notificationTitle": notificationTitle as Any,
            "notificationDescription": notificationDescription as Any,
            "showNotification": showNotification
        ]
    }
}

enum UploadStatusEnum: String {
    case queued
    case uploading
    case completed
    case failed
    case cancelled
}

struct UploadProgressData {
    let uploadId: String
    let bytesUploaded: Int64
    let totalBytes: Int64
    let status: UploadStatusEnum
    
    func toDictionary() -> [String: Any] {
        return [
            "uploadId": uploadId,
            "bytesUploaded": bytesUploaded,
            "totalBytes": totalBytes,
            "status": status.rawValue
        ]
    }
}

struct UploadResultData {
    let uploadId: String
    let status: UploadStatusEnum
    let statusCode: Int?
    let response: String?
    let error: String?
    
    func toDictionary() -> [String: Any?] {
        return [
            "uploadId": uploadId,
            "status": status.rawValue,
            "statusCode": statusCode,
            "response": response,
            "error": error
        ]
    }
}
