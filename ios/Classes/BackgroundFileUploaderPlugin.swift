import Flutter
import UIKit

public class BackgroundFileUploaderPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var progressEventSink: FlutterEventSink?
    private var resultEventSink: FlutterEventSink?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "background_file_uploader", binaryMessenger: registrar.messenger())
        let instance = BackgroundFileUploaderPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // Set up progress event channel
        let progressEventChannel = FlutterEventChannel(name: "background_file_uploader/progress", binaryMessenger: registrar.messenger())
        progressEventChannel.setStreamHandler(instance)
        
        // Set up result event channel
        let resultEventChannel = FlutterEventChannel(name: "background_file_uploader/result", binaryMessenger: registrar.messenger())
        resultEventChannel.setStreamHandler(instance)
        
        // Set up callbacks for upload manager
        UploadManager.shared.addProgressCallback { progress in
            instance.progressEventSink?(progress.toDictionary())
        }
        
        UploadManager.shared.addResultCallback { result in
            instance.resultEventSink?(result.toDictionary())
        }
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "uploadFile":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
                return
            }
            uploadFile(args: args, result: result)
            
        case "cancelUpload":
            guard let args = call.arguments as? [String: Any],
                  let uploadId = args["uploadId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "uploadId is required", details: nil))
                return
            }
            cancelUpload(uploadId: uploadId, result: result)
            
        case "getUploadStatus":
            guard let args = call.arguments as? [String: Any],
                  let uploadId = args["uploadId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "uploadId is required", details: nil))
                return
            }
            getUploadStatus(uploadId: uploadId, result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func uploadFile(args: [String: Any], result: @escaping FlutterResult) {
        let taskData = UploadTaskData(from: args)
        
        do {
            let uploadId = try UploadManager.shared.uploadFile(taskData: taskData)
            result(uploadId)
        } catch {
            result(FlutterError(code: "UPLOAD_FAILED", message: error.localizedDescription, details: nil))
        }
    }
    
    private func cancelUpload(uploadId: String, result: @escaping FlutterResult) {
        let success = UploadManager.shared.cancelUpload(uploadId: uploadId)
        result(success)
    }
    
    private func getUploadStatus(uploadId: String, result: @escaping FlutterResult) {
        if let progress = UploadManager.shared.getUploadStatus(uploadId: uploadId) {
            result(progress.toDictionary())
        } else {
            result(nil)
        }
    }
    
    // MARK: - FlutterStreamHandler
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        // Determine which stream this is based on the channel
        if progressEventSink == nil {
            progressEventSink = events
        } else {
            resultEventSink = events
        }
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        progressEventSink = nil
        resultEventSink = nil
        return nil
    }
}
