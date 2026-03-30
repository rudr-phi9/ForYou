import Foundation
import UserNotifications

/// Manages native macOS notifications for new research content.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    /// Posted when the user taps a notification. `userInfo` contains `"itemId"`.
    static let showItemNotification = Notification.Name("GeminiResearch.showItem")

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("[Notifications] Permission error: \(error.localizedDescription)")
            } else {
                print("[Notifications] Permission granted: \(granted)")
            }
        }
    }

    // MARK: - Send

    func notifyNewContent(itemId: UUID, tagName: String, title: String, summaryFirstSentence: String) {
        let content = UNMutableNotificationContent()
        content.title = "New \(tagName) Research Found"
        content.body = "\(title)\n\(summaryFirstSentence)"
        content.sound = .default
        content.userInfo = ["itemId": itemId.uuidString]

        let request = UNNotificationRequest(
            identifier: itemId.uuidString,
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[Notifications] Delivery error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show notifications even when app is in foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Handle notification tap — open the popover and scroll to the item.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        NotificationCenter.default.post(
            name: Self.showItemNotification,
            object: nil,
            userInfo: userInfo
        )
    }
}
