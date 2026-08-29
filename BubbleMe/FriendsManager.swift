import UIKit
import UserNotifications

/// In-game friends only — not X or Google contacts.
/// Share a friend code over iMessage / Mail, and post a local notification
/// when a request arrives (swap the notify hook for your backend later).
final class FriendsManager: NSObject, ObservableObject {
    @Published var friendCode: String
    @Published var alertsEnabled = false

    init(friendCode: String) {
        self.friendCode = friendCode
        super.init()
    }

    var inviteText: String {
        "Add me on Bubble Me! I’m a player in the game — friend code \(friendCode). https://bubbleme.fun/friends?invite=\(friendCode)"
    }

    /// Native share sheet (Messages, Mail, and everything else).
    func presentShare(from viewController: UIViewController) {
        let av = UIActivityViewController(activityItems: [inviteText], applicationActivities: nil)
        if let pop = av.popoverPresentationController {
            pop.sourceView = viewController.view
            pop.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.maxY - 40, width: 1, height: 1)
        }
        viewController.present(av, animated: true)
    }

    /// Opens the Messages app with the invite pre-filled (iMessage if the contact uses it).
    func openMessages() {
        let body = inviteText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "sms:&body=\(body)") else { return }
        UIApplication.shared.open(url)
    }

    /// Opens Mail with the invite pre-filled.
    func openMail() {
        let subject = "Add me on Bubble Me".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = inviteText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "mailto:?subject=\(subject)&body=\(body)") else { return }
        UIApplication.shared.open(url)
    }

    /// Ask once for banners. Call this from Settings → Friend alerts.
    func requestAlertPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
            DispatchQueue.main.async { self.alertsEnabled = ok }
        }
    }

    /// In-app + lock-screen banner for a friend request. The web game posts the
    /// same event to `notifications`; on iOS, call this when a realtime payload arrives.
    func announceFriendRequest(from username: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(username) wants to be friends"
        content.body = "Open Bubble Me to accept. Requests stay inside the game."
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "friend-\(username)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.4, repeats: false)
        )
        UNUserNotificationCenter.current().add(req)
    }
}
