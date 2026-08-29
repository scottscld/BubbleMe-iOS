import SwiftUI
import SpriteKit
import PhotosUI

struct ContentView: View {
    @StateObject private var profile = ProfileManager()
    @State private var playing = false
    @State private var picker: PhotosPickerItem?
    @State private var showFriends = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color(red: 0.027, green: 0.043, blue: 0.078).ignoresSafeArea()
            if playing {
                GameContainer(profile: profile) { playing = false }
            } else {
                HomeView(
                    profile: profile,
                    playing: $playing,
                    picker: $picker,
                    showFriends: $showFriends,
                    showSettings: $showSettings
                )
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: picker) { _, item in
            Task {
                guard let item,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let img = UIImage(data: data) else { return }
                profile.importPhoto(img)
            }
        }
        .sheet(isPresented: $showFriends) {
            FriendsSheet(code: profile.friendCode)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(profile: profile)
        }
    }
}

struct HomeView: View {
    @ObservedObject var profile: ProfileManager
    @Binding var playing: Bool
    @Binding var picker: PhotosPickerItem?
    @Binding var showFriends: Bool
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BUBBLE SHOOTER")
                        .font(.caption.weight(.semibold))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                    Text("Bubble Me")
                        .font(.largeTitle.weight(.semibold))
                }
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer()

            PhotosPicker(selection: $picker, matching: .images) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 1, green: 0.55, blue: 0.65), Color(red: 1, green: 0.35, blue: 0.48)],
                                center: .topLeading,
                                startRadius: 4,
                                endRadius: 70
                            )
                        )
                        .frame(width: 128, height: 128)
                        .shadow(color: Color(red: 1, green: 0.35, blue: 0.48).opacity(0.45), radius: 24, y: 8)
                    if let photo = profile.photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 128, height: 128)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
            }
            .accessibilityLabel("Change shooter photo")

            Text(profile.username)
                .font(.title2.weight(.semibold))
                .padding(.top, 16)
            Text("Friend code \(profile.friendCode)")
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    playing = true
                } label: {
                    Text("Play")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 1, green: 0.35, blue: 0.48))

                Button {
                    showFriends = true
                } label: {
                    Text("Friends")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Toggle("Haptic rumble", isOn: Binding(
                    get: { profile.hapticEnabled },
                    set: { profile.setHaptic($0) }
                ))
                .padding(.horizontal, 8)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }
}

struct SettingsSheet: View {
    @ObservedObject var profile: ProfileManager
    @Environment(\.dismiss) private var dismiss
    @State private var alerts = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Shooter") {
                    Text("Tap the circle on the home screen to change your photo. It skins the launcher and Face Ball.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section("Feel") {
                    Toggle("Haptic rumble", isOn: Binding(
                        get: { profile.hapticEnabled },
                        set: { profile.setHaptic($0) }
                    ))
                    Toggle("Friend alerts", isOn: $alerts)
                        .onChange(of: alerts) { _, on in
                            if on {
                                FriendsManager(friendCode: profile.friendCode).requestAlertPermission()
                            }
                        }
                }
                Section("You") {
                    TextField("Display name", text: $profile.username)
                        .onChange(of: profile.username) { _, _ in profile.save() }
                    LabeledContent("Friend code", value: profile.friendCode)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct FriendsSheet: View {
    let code: String
    @State private var alertsEnabled = false
    @Environment(\.dismiss) private var dismiss

    private var friends: FriendsManager { FriendsManager(friendCode: code) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Friends are other Bubble Me players — not X or Google contacts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(code)
                    .font(.largeTitle.monospaced())
                    .textSelection(.enabled)
                Text("Send this code with Messages or email. They open Bubble Me, go to Friends, and tap Request. You get an in-game alert.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button("Messages") { friends.openMessages() }
                        .buttonStyle(.borderedProminent)
                    Button("Email") { friends.openMail() }
                        .buttonStyle(.bordered)
                    ShareLink(item: friends.inviteText) {
                        Label("More", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
                Toggle("Friend alerts", isOn: $alertsEnabled)
                    .onChange(of: alertsEnabled) { _, on in
                        if on { friends.requestAlertPermission() }
                    }
                Spacer()
            }
            .padding()
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct GameContainer: View {
    @ObservedObject var profile: ProfileManager
    var onHome: () -> Void
    @StateObject private var session: GameSession

    init(profile: ProfileManager, onHome: @escaping () -> Void) {
        self.profile = profile
        self.onHome = onHome
        _session = StateObject(wrappedValue: GameSession(profile: profile))
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: session.scene)
                .ignoresSafeArea()
            VStack {
                HStack {
                    Text("\(session.score)")
                        .font(.title2.monospacedDigit().weight(.semibold))
                    Spacer()
                    Button("Home", action: onHome)
                        .buttonStyle(.bordered)
                        .tint(.white)
                    Spacer()
                    Text("\(session.shots)")
                        .font(.title2.monospacedDigit().weight(.semibold))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                HStack(spacing: 10) {
                    PowerButton(title: "Bomb", count: session.bombs, selected: session.loaded == .bomb) {
                        session.load(.bomb)
                    }
                    PowerButton(title: "Fire", count: session.fire, selected: session.loaded == .fire) {
                        session.load(.fire)
                    }
                    PowerButton(title: "Face", count: session.face, selected: session.loaded == .face) {
                        session.load(.face)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        }
        .statusBarHidden(true)
    }
}

private struct PowerButton: View {
    let title: String
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).font(.caption.weight(.semibold))
                Text("\(count)").font(.headline.monospacedDigit())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(selected ? Color(red: 1, green: 0.35, blue: 0.48) : Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        }
        .foregroundStyle(.white)
        .disabled(count <= 0)
        .opacity(count <= 0 ? 0.4 : 1)
    }
}

final class GameSession: ObservableObject {
    let scene: GameScene
    @Published var score = 0
    @Published var shots = 24
    @Published var bombs: Int
    @Published var fire: Int
    @Published var face: Int
    @Published var loaded: PowerUp?

    init(profile: ProfileManager) {
        bombs = profile.inventory.bombs
        fire = profile.inventory.fireballs
        face = profile.inventory.faceBalls
        let size = UIScreen.main.bounds.size
        let scene = GameScene(size: size, inventory: profile.inventory)
        scene.scaleMode = .resizeFill
        scene.profile = profile
        self.scene = scene
        scene.onHud = { [weak self] score, shots, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.score = score
                self.shots = shots
                let inv = self.scene.powers.inventory
                self.bombs = inv.bombs
                self.fire = inv.fireballs
                self.face = inv.faceBalls
                self.loaded = self.scene.powers.loaded
            }
        }
    }

    func load(_ power: PowerUp) {
        scene.loadPower(power)
        loaded = scene.powers.loaded
        Haptics.aimTick()
    }
}
