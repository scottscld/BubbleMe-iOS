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

/// Sign-in chip on the Me tab. Tapping starts Game Center auth so progress
/// (Bubbles, scores, cosmetics) can sync across the player's devices.
struct GameCenterRow: View {
    @ObservedObject private var cloud = CloudSync.shared

    var body: some View {
        Button {
            CloudSync.shared.authenticate()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: cloud.signedIn ? "checkmark.seal.fill" : "gamecontroller.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(cloud.signedIn ? Palette.aqua : Palette.fg)
                    .frame(width: 36, height: 36)
                    .background(Palette.surface2, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Game Center")
                        .font(.display(16))
                    Text(cloud.signedIn ? cloud.playerName : "Sign in to sync across devices")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Text(cloud.signedIn ? "On" : "Sign in")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Palette.surface2, in: Capsule())
                    .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
            }
            .foregroundStyle(Palette.fg)
            .padding(14)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Palette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

