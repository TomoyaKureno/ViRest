import Foundation
@preconcurrency import UserNotifications

@MainActor
final class UserNotificationService: NotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func schedulePlanReminders(for plan: WeeklyPlan) {
        clearPlanReminders()

        let pendingCount = plan.sessions.filter { !$0.isCompleted }.count
        guard pendingCount > 0 else { return }

        let preferredTime = plan.sessions.first?.preferredTime ?? .flexible

        let content = UNMutableNotificationContent()
        content.title = "Weekly target pending"
        content.body = "You still have \(pendingCount) activity session(s) to complete this week."
        content.sound = .default

        var components = DateComponents()
        switch preferredTime {
        case .morning:
            components.hour = 7
            components.minute = 0
        case .midday:
            components.hour = 12
            components.minute = 15
        case .evening:
            components.hour = 18
            components.minute = 30
        case .flexible:
            components.hour = 19
            components.minute = 0
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "plan-reminder-weekly-target",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func scheduleTargetAchievedNotification(for activity: ActivityType) {
        let content = UNMutableNotificationContent()
        content.title = "Target achieved"
        content.body = "Great job finishing your \(activity.displayName) session."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "goal-achieved-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func clearPlanReminders() {
        let notificationCenter = center
        notificationCenter.getPendingNotificationRequests { requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("plan-reminder-") || $0 == "plan-reminder-weekly-target" }
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
}
