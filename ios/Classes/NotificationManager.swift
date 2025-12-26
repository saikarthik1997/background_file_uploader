import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
        }
    }
    
    func showProgressNotification(uploadId: String, title: String, description: String, progress: Double) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = String(format: "%.0f%% complete", progress * 100)
        content.sound = nil
        
        let identifier = "upload_\(uploadId)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to show notification: \(error.localizedDescription)")
            }
        }
    }
    
    func showCompletionNotification(uploadId: String, title: String, description: String, isSuccess: Bool) {
        let content = UNMutableNotificationContent()
        content.title = isSuccess ? "Upload Complete" : "Upload Failed"
        content.body = description
        content.sound = .default
        
        let identifier = "upload_\(uploadId)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to show notification: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelNotification(uploadId: String) {
        let identifier = "upload_\(uploadId)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
