import Foundation
import UserNotifications
import SwiftUI

// MARK: - NotificationManager

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    /// Called when a user taps "Review Task" on a notification. Carries the task ID.
    var onReviewRequested: ((UUID) -> Void)?

    private override init() {
        super.init()
        center.delegate = self
        registerCategories()
    }

    // MARK: Categories & Actions

    private func registerCategories() {
        let reviewAction = UNNotificationAction(
            identifier: "REVIEW_TASK",
            title: "Review Task",
            options: .foreground
        )

        let category = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [reviewAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])
    }

    // MARK: Authorization

    func requestAuthorization() {
        Task {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    print("[NotificationManager] Authorization granted")
                } else {
                    print("[NotificationManager] Authorization denied")
                }
            } catch {
                print("[NotificationManager] Authorization error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Scheduling

    func scheduleNotification(for task: LifeTask) {
        guard task.startTime > Date() else {
            print("[NotificationManager] Skipping notification for past task: \(task.title)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Life OS"
        content.body = notificationBody(for: task)
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"
        content.userInfo = ["taskId": task.id.uuidString]

        let triggerDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: task.startTime
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("[NotificationManager] Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("[NotificationManager] Scheduled notification for: \(task.title) at \(task.startTime)")
            }
        }
    }

    /// Remove a pending notification for a specific task.
    func cancelNotification(for taskId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [taskId.uuidString])
    }

    // MARK: UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        defer { completionHandler() }

        guard response.actionIdentifier == "REVIEW_TASK" ||
              response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let taskIdString = userInfo["taskId"] as? String,
              let taskId = UUID(uuidString: taskIdString) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.onReviewRequested?(taskId)
        }
    }

    // Allow notifications to show in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // MARK: Helpers

    private func notificationBody(for task: LifeTask) -> String {
        if let location = task.location, !location.isEmpty {
            return "\(task.title) at \(location)"
        }
        return task.title
    }
}
