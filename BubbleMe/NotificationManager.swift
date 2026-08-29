import Foundation
import UserNotifications

/// Local notifications that work on a free Apple ID.
/// Remote push (passing you on the live board, friend request from another phone)
/// needs a paid developer account + APNs — same methods, swap the delivery later.
enum NoteKind: String {
    case streak, passed, winner, friend, battle
}

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    func request() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func streakWarning(streak: Int) {
        guard streak > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Streak in danger"
        content.body = streak == 1
            ? "Play today to keep your streak alive."
            : "Your \(streak)-day streak breaks at midnight if you don’t pop a few."
        content.sound = .default
        content.threadIdentifier = NoteKind.streak.rawValue

        var date = DateComponents()
        date.hour = 20
        date.minute = 0
        date.timeZone = TimeZone(identifier: "America/Chicago")
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let req = UNNotificationRequest(identifier: NoteKind.streak.rawValue, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    func cancelStreak() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [NoteKind.streak.rawValue])
    }

    func passedOnBoard(by name: String) {
        fire(kind: .passed, title: "Passed on the board", body: "\(name) just jumped ahead of you in Arcade.")
    }

    func weekWinner() {
        fire(kind: .winner, title: "Arcade champ", body: "You finished first this week. New boards drop Saturday at midnight CT.")
    }

    func friendRequest(from name: String) {
        fire(kind: .friend, title: "Friend request", body: "\(name) wants to add you in Bubble Me.")
    }

    func battleChallenge(from name: String) {
        fire(kind: .battle, title: "Battle challenge", body: "\(name) challenged you to a 1v1.")
    }

    private func fire(kind: NoteKind, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = kind.rawValue
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(identifier: "\(kind.rawValue).\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
