import SwiftUI
import SpriteKit
import PhotosUI

enum HubTab: String, CaseIterable {
    case home, levels, battle, friends, me
}

struct PlayRequest {
    var mode: PlayMode
    var levelId: Int
    var seed: Int
}

struct ContentView: View {
    @StateObject private var profile = ProfileManager()
    @State private var tab: HubTab = .home
    @State private var play: PlayRequest?
    @State private var picker: PhotosPickerItem?
    @State private var showSettings = false
    @State private var showBoard = false

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            if let play {
                GameContainer(profile: profile, request: play) {
                    self.play = nil
                }
            } else {
                ZStack(alignment: .bottom) {
                    Group {
                        switch tab {
                        case .home:
                            HomeHub(
                                profile: profile,
                                picker: $picker,
                                showSettings: $showSettings,
                                showBoard: $showBoard,
                                onArcade: startArcade,
                                onLevel: { startLevel(profile.highestLevel) }
                            )
                        case .levels:
                            LevelsHub(profile: profile, onPlay: startLevel)
                        case .battle:
                            BattleHub(onCPU: startCPU)
                        case .friends:
                            FriendsHub(code: profile.friendCode)
                        case .me:
                            ProfileHub(profile: profile, picker: $picker)
                        }
                    }
                    .padding(.bottom, 72)
                    HubTabBar(tab: $tab)
                }
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
        .sheet(isPresented: $showSettings) {
            SettingsSheet(profile: profile)
        }
        .sheet(isPresented: $showBoard) {
            ArcadeBoardSheet(best: profile.arcadeBest)
        }
    }

    private func startArcade() {
        play = PlayRequest(mode: .arcade, levelId: 1, seed: ArcadeWeek.seed())
    }

    private func startLevel(_ id: Int) {
        let lvl = max(1, min(LevelsCatalog.count, id))
        play = PlayRequest(mode: .level, levelId: lvl, seed: lvl * 997 + 13)
    }

    private func startCPU() {
        play = PlayRequest(mode: .battle, levelId: 6, seed: 6 * 997 + 13)
    }
}

struct HomeHub: View {
    @ObservedObject var profile: ProfileManager
    @Binding var picker: PhotosPickerItem?
    @Binding var showSettings: Bool
    @Binding var showBoard: Bool
    var onArcade: () -> Void
    var onLevel: () -> Void

    var body: some View {
        ZStack {
            StarryBackdrop()
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BUBBLE SHOOTER")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .tracking(2.4)
                            .foregroundStyle(Palette.muted)
                        Text("Bubble Me")
                            .font(.display(34, weight: .bold))
                            .foregroundStyle(Palette.fg)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Text("Guest")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .background(Palette.surface.opacity(0.9), in: Capsule())
                            .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .background(Palette.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Palette.border, lineWidth: 1)
                                )
                        }
                        .foregroundStyle(Palette.fg)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()
                BubbleCluster(photo: profile.photo, picker: $picker)
                Spacer()

                VStack(spacing: 12) {
                    Button(action: onArcade) {
                        Text("Play Arcade")
                    }
                    .buttonStyle(PrimaryButton())

                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        HStack(spacing: 6) {
                            Text("Resets in \(ArcadeWeek.formatCountdown(until: ArcadeWeek.nextReset(), now: context.date))")
                            Text("·")
                            Button("Leaderboard") { showBoard = true }
                                .foregroundStyle(Palette.aqua)
                        }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.muted)
                    }

                    Button(action: onLevel) {
                        Text(profile.highestLevel > LevelsCatalog.count
                             ? "Replay levels"
                             : "Play level \(min(LevelsCatalog.count, profile.highestLevel))")
                    }
                    .buttonStyle(SecondaryButton())

                    Text("\(profile.username.isEmpty ? "Guest" : profile.username) · \(profile.wins)W \(profile.losses)L · \(profile.coins) coins")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.muted)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
}

struct BubbleCluster: View {
    var photo: UIImage?
    @Binding var picker: PhotosPickerItem?

    var body: some View {
        ZStack {
            ForEach(Array(cluster.enumerated()), id: \.offset) { i, item in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.55), item.color],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: 38
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
                    .offset(x: item.x, y: item.y)
            }
            PhotosPicker(selection: $picker, matching: .images) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.5), Palette.accent],
                                center: .topLeading,
                                startRadius: 4,
                                endRadius: 50
                            )
                        )
                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "camera")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 84, height: 84)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 2))
                .shadow(color: Palette.accent.opacity(0.35), radius: 16, y: 6)
            }
            .accessibilityLabel("Change shooter photo")
        }
        .frame(width: 280, height: 170)
    }

    private var cluster: [(color: Color, x: CGFloat, y: CGFloat)] {
        [
            (Palette.bubble[0], -38, -8),
            (Palette.bubble[1], 8, 28),
            (Palette.bubble[2], 48, -18),
            (Palette.bubble[3], 22, 42),
            (Palette.bubble[4], -8, 36),
        ]
    }
}

struct HubTabBar: View {
    @Binding var tab: HubTab

    var body: some View {
        HStack {
            tabBtn(.home, "Home", "gamecontroller.fill")
            tabBtn(.levels, "Levels", "square.stack.3d.up.fill")
            tabBtn(.battle, "Battle", "bolt.shield.fill")
            tabBtn(.friends, "Friends", "person.2.fill")
            tabBtn(.me, "Me", "person.crop.circle.fill")
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .padding(.horizontal, 4)
        .background(.ultraThinMaterial.opacity(0.35))
        .background(Palette.surface.opacity(0.92))
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }

    private func tabBtn(_ t: HubTab, _ label: String, _ icon: String) -> some View {
        Button {
            tab = t
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: tab == t ? .semibold : .regular))
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(tab == t ? Palette.accent : Palette.muted)
            .frame(maxWidth: .infinity)
        }
    }
}

struct GameContainer: View {
    @ObservedObject var profile: ProfileManager
    var request: PlayRequest
    var onHome: () -> Void
    @StateObject private var session: GameSession

    init(profile: ProfileManager, request: PlayRequest, onHome: @escaping () -> Void) {
        self.profile = profile
        self.request = request
        self.onHome = onHome
        _session = StateObject(wrappedValue: GameSession(profile: profile, request: request))
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: session.scene).ignoresSafeArea()
            VStack {
                HStack {
                    chip("\(session.score)")
                    Spacer()
                    Button("Home", action: finish)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.fg)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(Palette.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Spacer()
                    chip("\(session.shots)")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if request.mode == .arcade {
                    Text("Wave \(session.wave)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.muted)
                } else {
                    Text(LevelsCatalog.info(request.levelId).goal)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }

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
        .onChange(of: session.won) { _, won in
            if won { finish() }
        }
    }

    private func chip(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(Palette.fg)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Palette.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Palette.border, lineWidth: 1)
            )
    }

    private func finish() {
        if request.mode == .arcade {
            profile.recordArcade(score: session.score)
        } else if session.won {
            profile.clearLevel(request.levelId)
            profile.wins += 1
            profile.save()
        }
        onHome()
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
                Text(title).font(.system(size: 11, weight: .semibold, design: .rounded))
                Text("\(count)").font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                selected ? Palette.accent : Color.white.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
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
    @Published var won = false
    @Published var wave = 1

    init(profile: ProfileManager, request: PlayRequest) {
        bombs = profile.inventory.bombs
        fire = profile.inventory.fireballs
        face = profile.inventory.faceBalls
        let size = UIScreen.main.bounds.size
        let scene = GameScene(
            size: size,
            inventory: profile.inventory,
            seed: request.seed,
            mode: request.mode,
            levelId: request.levelId
        )
        scene.scaleMode = .resizeFill
        scene.profile = profile
        self.scene = scene
        scene.onHud = { [weak self] score, shots, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.score = score
                self.shots = shots
                self.wave = self.scene.wave
                let inv = self.scene.powers.inventory
                self.bombs = inv.bombs
                self.fire = inv.fireballs
                self.face = inv.faceBalls
                self.loaded = self.scene.powers.loaded
            }
        }
        scene.onWin = { [weak self] in
            DispatchQueue.main.async { self?.won = true }
        }
    }

    func load(_ power: PowerUp) {
        scene.loadPower(power)
        loaded = scene.powers.loaded
        Haptics.aimTick()
    }
}
