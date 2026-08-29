import Foundation
import GameKit
import SwiftUI
import UIKit

/// Game Center sign-in + saved-game sync (progress, Bubbles, cosmetics, scores).
final class CloudSync: NSObject, ObservableObject {
    static let shared = CloudSync()
    @Published var signedIn = false
    @Published var playerName = "Guest"
    @Published var authVC: UIViewController?

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, error in
            DispatchQueue.main.async {
                if let vc { self?.authVC = vc; return }
                self?.authVC = nil
                if GKLocalPlayer.local.isAuthenticated {
                    self?.signedIn = true
                    self?.playerName = GKLocalPlayer.local.displayName
                    self?.pull()
                } else {
                    self?.signedIn = false
                    if error != nil { self?.playerName = "Guest" }
                }
            }
        }
    }

    func push(profile: ProfileManager) {
        guard GKLocalPlayer.local.isAuthenticated, let data = profile.cloudBlob() else { return }
        GKLocalPlayer.local.saveGameData(data, withName: "bubbleme.profile") { _, _ in }
    }

    func pull() {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        GKLocalPlayer.local.fetchSavedGames { games, _ in
            let match = games?.first { $0.name == "bubbleme.profile" }
            match?.loadData { data, _ in
                guard let data else { return }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .bubbleMeCloud, object: data)
                }
            }
        }
    }
}

extension Notification.Name {
    static let bubbleMeCloud = Notification.Name("bubbleMeCloud")
}

struct GameCenterAuthView: UIViewControllerRepresentable {
    let vc: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { vc }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
