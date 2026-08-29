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
    var resume: Bool = false
    var roomCode: String = ""
    var hosting: Bool = false
}

struct ContentView: View {
    @StateObject private var profile = ProfileManager()
    @State private var tab: HubTab = .home
    @State private var play: PlayRequest?
    @State private var picker: PhotosPickerItem?
    @State private var showSettings = false
    @State private var showBoard = false
    @State private var showCustomize = false
    @ObservedObject private var cloud = CloudSync.shared

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
                                showCustomize: $showCustomize,
                                onArcade: startArcade,
                                onLevel: { startLevel(profile.highestLevel) },
                                onDaily: startDaily,
                                onContinue: continueRun
                            )
                        case .levels:
                            LevelsHub(profile: profile, onPlay: startLevel)
                        case .battle:
                            BattleHub(profile: profile, onCPU: startCPU, onFriend: startFriend)
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
        .sheet(isPresented: $showCustomize) {
            CustomizeHub(profile: profile)
        }
        .onAppear {
            AudioEngine.shared.start()
            AudioEngine.shared.musicOn = profile.musicEnabled
            AudioEngine.shared.sfxOn = profile.sfxEnabled
            CloudSync.shared.authenticate()
        }
        .onReceive(NotificationCenter.default.publisher(for: .bubbleMeCloud)) { note in
            if let data = note.object as? Data { profile.mergeCloud(data) }
        }
        .background(CloudAuthHost())
    }

    private func startArcade() {
        play = PlayRequest(mode: .arcade, levelId: 1, seed: ArcadeWeek.seed())
    }

    private func startLevel(_ id: Int) {
        let lvl = max(1, min(LevelsCatalog.count, id))
        play = PlayRequest(mode: .level, levelId: lvl, seed: lvl * 997 + 13)
    }

    private func startCPU() {
        play = PlayRequest(mode: .battle, levelId: 6, seed: Int.random(in: 1...999_999))
    }

    private func startFriend(code: String, hosting: Bool) {
        let trimmed = code.uppercased().filter { $0.isLetter || $0.isNumber }
        guard trimmed.count >= 4 else { return }
        play = PlayRequest(
            mode: .battle,
            levelId: 6,
            seed: RoomCode.seed(trimmed),
            roomCode: String(trimmed.prefix(4)),
            hosting: hosting
        )
    }

    private func startDaily() {
        let info = DailyCatalog.info()
        play = PlayRequest(mode: .daily, levelId: info.id, seed: info.seed)
    }

    private func continueRun() {
        guard let data = profile.savedRun,
              let snap = try? JSONDecoder().decode(RunSnapshot.self, from: data) else { return }
        let mode = PlayMode(rawValue: snap.mode) ?? .arcade
        play = PlayRequest(mode: mode, levelId: snap.levelId, seed: snap.seed, resume: true)
    }
}

private struct CloudAuthHost: UIViewControllerRepresentable {
    @ObservedObject var cloud = CloudSync.shared

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        vc.view.isUserInteractionEnabled = false
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let auth = cloud.authVC, uiViewController.presentedViewController == nil {
            uiViewController.present(auth, animated: true)
        }
    }
}

struct HomeHub: View {
    @ObservedObject var profile: ProfileManager
    @Binding var picker: PhotosPickerItem?
    @Binding var showSettings: Bool
    @Binding var showBoard: Bool
    @Binding var showCustomize: Bool
    var onArcade: () -> Void
    var onLevel: () -> Void
    var onDaily: () -> Void
    var onContinue: () -> Void
    @ObservedObject private var cloud = CloudSync.shared

    private var cloudName: String {
        cloud.signedIn ? cloud.playerName : (profile.username.isEmpty ? "Guest" : profile.username)
    }

    private var streakCopy: String {
        let today = ArcadeWeek.dayId()
        if profile.lastPlayDay == today, profile.streak > 0 {
            return "Streak \(profile.streak) days · you’re good for today"
        }
        if profile.streak > 0 {
            return "Play today to keep your \(profile.streak)-day streak"
        }
        return "Play today to start a streak"
    }

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
                        Button { showCustomize = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "circle.fill")
                                Text("\(profile.bubbles)")
                            }
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.aqua)
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .background(Palette.surface.opacity(0.9), in: Capsule())
                            .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
                        }
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
                    if profile.savedRun != nil {
                        Button("Continue", action: onContinue)
                            .buttonStyle(PrimaryButton())
                    }
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

                    Button(action: onDaily) {
                        Text(profile.dailyDone ? "Replay Daily Board" : "Play today’s Daily Board")
                    }
                    .buttonStyle(SecondaryButton())
                    Text("\(DailyCatalog.info().name) · \(DailyCatalog.info().goal)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.muted)

                    Button("Customize shooter") { showCustomize = true }
                        .buttonStyle(SecondaryButton())

                    Text(streakCopy)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.aqua)

                    Text("\(cloudName) · \(profile.wins)W \(profile.losses)L · \(profile.bubbles) Bubbles")
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
    @State private var bagOpen = false

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
                    chip("\(session.score)", label: "Score")
                    Spacer()
                    Button("Pause") { session.paused = true; session.scene.isPaused = true; session.persist() }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.fg)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(Palette.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Button("Home") { session.persist(); finish() }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.fg)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(Palette.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Spacer()
                    if request.mode == .arcade {
                        chip("\(session.wave)", label: "Wave")
                    } else if request.mode == .battle {
                        chip("\(session.cpuScore)", label: session.oppLabel)
                    } else {
                        chip("\(session.shots)", label: "Shots")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if request.mode == .arcade {
                    Text("Play for high score · waves get harder")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.muted)
                } else if request.mode == .daily {
                    Text(DailyCatalog.info().goal)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.muted)
                } else if request.mode == .battle {
                    Text(request.roomCode.isEmpty
                         ? "Duel · first to clear — or highest score — wins"
                         : "Room \(request.roomCode) · ZigZag / Mirror / Shuffle hit them")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.muted)
                } else {
                    Text(LevelsCatalog.info(request.levelId).goal)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }

                Spacer()

                if bagOpen {
                    TabView {
                        HStack(spacing: 10) {
                            PowerButton(kind: .bomb, count: session.bombs, selected: session.loaded == .bomb, photo: profile.photo) {
                                session.load(.bomb)
                            }
                            PowerButton(kind: .fire, count: session.fire, selected: session.loaded == .fire, photo: profile.photo) {
                                session.load(.fire)
                            }
                            PowerButton(kind: .face, count: session.face, selected: session.loaded == .face, photo: profile.photo) {
                                session.load(.face)
                            }
                        }
                        .padding(.horizontal, 16)
                        if request.mode == .battle {
                            HStack(spacing: 10) {
                                BattleChip(title: "ZigZag", icon: "〰️", count: session.zigzag) { session.useBattle(.zigzag) }
                                BattleChip(title: "Mirror", icon: "🪞", count: session.mirror) { session.useBattle(.mirror) }
                                BattleChip(title: "Shuffle", icon: "🔀", count: session.shuffle) { session.useBattle(.shuffle) }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(height: 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { bagOpen.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        Text("🎒").font(.system(size: 20))
                        bagIcon("💣", session.bombs)
                        bagIcon("🔥", session.fire)
                        bagIcon("🙂", session.face)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Palette.muted)
                            .opacity(0.7)
                    }
                    .foregroundStyle(Palette.fg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Palette.surface.opacity(0.92), in: Capsule())
                    .overlay(Capsule().stroke(session.loaded == nil ? Palette.border : Palette.accent, lineWidth: 1.2))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }

            if let wave = session.waveBanner, !session.lost {
                Color.black.opacity(0.4).ignoresSafeArea()
                VStack(spacing: 10) {
                    Text("WAVE \(wave)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(Palette.aqua)
                    Text(waveCopy(wave))
                        .font(.display(28, weight: .bold))
                        .multilineTextAlignment(.center)
                    Text("Board cleared · keep popping")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.muted)
                    Text("\(session.score)")
                        .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                    Button("Let’s go") { session.waveBanner = nil }
                        .buttonStyle(PrimaryButton())
                        .padding(.horizontal, 40)
                }
                .foregroundStyle(Palette.fg)
                .padding(24)
                .background(Palette.surface.opacity(0.95), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(28)
            }

            if session.paused && !session.lost && !session.won && session.waveBanner == nil {
                Color.black.opacity(0.55).ignoresSafeArea()
                VStack(spacing: 12) {
                    Text("Paused").font(.display(32, weight: .bold))
                    Text("Progress is saved. Head home, battle, or quit — Continue on Home brings you back.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                    Button("Resume") {
                        session.paused = false
                        session.scene.isPaused = false
                    }
                    .buttonStyle(PrimaryButton())
                    Button("Save & Home") { session.persist(); finish() }
                        .buttonStyle(SecondaryButton())
                }
                .padding(24)
                .foregroundStyle(Palette.fg)
            }

            if let msg = session.banner, !session.lost, !session.won {
                Text(msg)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Palette.accent.opacity(0.92), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.top, 88)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
            }

            if session.waiting {
                Color.black.opacity(0.55).ignoresSafeArea()
                VStack(spacing: 12) {
                    Text("Room \(request.roomCode)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.aqua)
                    Text("Waiting for a friend nearby")
                        .font(.display(26, weight: .bold))
                    Text(session.link?.status ?? "Share this code. They join on the Battle tab.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                    ShareLink(item: "Battle me in Bubble Me — room \(request.roomCode)") {
                        Text("Share code").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButton())
                    Button("Play a stand-in") { session.startStandIn() }
                        .buttonStyle(SecondaryButton())
                    Button("Cancel") { session.link?.stop(); finish() }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }
                .padding(24)
                .foregroundStyle(Palette.fg)
            }

            if session.won {
                Color.black.opacity(0.55).ignoresSafeArea()
                VStack(spacing: 12) {
                    Text("Cleared").font(.display(32, weight: .bold))
                    if request.mode == .level || request.mode == .daily {
                        HStack(spacing: 6) {
                            ForEach(1...3, id: \.self) { i in
                                Image(systemName: i <= session.earnedStars ? "star.fill" : "star")
                                    .foregroundStyle(i <= session.earnedStars ? Palette.accent : Palette.muted)
                            }
                        }
                        .font(.system(size: 28))
                        Text(session.earnedStars == 3 ? "+75 Bubbles" : session.earnedStars == 2 ? "+50 Bubbles" : "+25 Bubbles")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.aqua)
                    }
                    Text("\(session.score)")
                        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Palette.accent)
                    Button("Home") { finish() }
                        .buttonStyle(PrimaryButton())
                        .padding(.horizontal, 40)
                }
                .padding(24)
                .foregroundStyle(Palette.fg)
            }

            if session.lost {
                Color.black.opacity(0.55).ignoresSafeArea()
                VStack(spacing: 14) {
                    Text(request.mode == .battle ? "They cleared first" : "Board full")
                        .font(.display(28, weight: .bold))
                    Text(request.mode == .battle
                         ? "First to clear — or highest score — wins."
                         : "The bubbles reached the line.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.muted)
                    Text("\(session.score)")
                        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Palette.accent)
                    if request.mode == .arcade {
                        Text("Wave \(session.wave)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.muted)
                    }
                    Button("Home") { finish() }
                        .buttonStyle(PrimaryButton())
                        .padding(.horizontal, 40)
                }
                .foregroundStyle(Palette.fg)
                .padding(24)
            }
        }
        .statusBarHidden(true)
        .onAppear {
            if session.waiting { session.scene.isPaused = true }
        }
        .onChange(of: session.waiting) { _, wait in
            if wait { session.scene.isPaused = true }
        }
        .onChange(of: session.waveBanner) { _, banner in
            session.scene.isPaused = banner != nil
        }
        .onDisappear { session.link?.stop() }
    }

    private func waveCopy(_ w: Int) -> String {
        switch w % 5 {
        case 2: return "Nice clear!"
        case 3: return "You’re on fire!"
        case 4: return "Unstoppable."
        default: return "Keep going!"
        }
    }

    private func bagIcon(_ emoji: String, _ n: Int) -> some View {
        HStack(spacing: 3) {
            Text(emoji)
            Text("\(n)")
                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
        }
    }

    private var bagLabel: String {
        switch session.loaded {
        case .bomb: return "Bomb loaded"
        case .fire: return "Fire loaded"
        case .face: return "Face loaded"
        case nil: return "Bubble Bag"
        }
    }

    private func chip(_ t: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(Palette.muted)
            Text(t)
                .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.fg)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Palette.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Palette.border, lineWidth: 1)
        )
    }

    private func finish() {
        profile.inventory = session.scene.powers.inventory
        if request.mode == .arcade {
            profile.recordArcade(score: session.score)
        } else if request.mode == .daily, session.won {
            profile.completeDaily()
            _ = profile.awardStars(max(1, session.earnedStars), level: 10_000 + DailyCatalog.index())
        } else if request.mode == .level, session.won {
            profile.clearLevel(request.levelId)
            _ = profile.awardStars(max(1, session.earnedStars), level: request.levelId)
            profile.wins += 1
        } else if request.mode == .battle, session.won {
            profile.wins += 1
            profile.addBubbles(40)
        } else if session.lost {
            profile.losses += 1
        }
        if session.won || session.lost { session.clearSave() }
        session.link?.stop()
        profile.save()
        onHome()
    }
}

private struct PowerButton: View {
    let kind: PowerUp
    let count: Int
    let selected: Bool
    var photo: UIImage?
    let action: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                art
                    .frame(height: 34)
                Text("\(count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                selected ? Palette.accent.opacity(0.35) : Color.white.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Palette.accent : Palette.border, lineWidth: selected ? 2 : 1)
            )
        }
        .foregroundStyle(.white)
        .disabled(count <= 0)
        .opacity(count <= 0 ? 0.4 : 1)
        .onAppear { pulse = true }
    }

    @ViewBuilder
    private var art: some View {
        switch kind {
        case .bomb:
            Text("💣")
                .font(.system(size: 28))
                .shadow(color: .orange.opacity(0.55), radius: selected ? 8 : 0)
        case .fire:
            Text("🔥")
                .font(.system(size: 28))
        case .face:
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 36, height: 36)
                    .scaleEffect(pulse ? 1.18 : 0.92)
                    .opacity(pulse ? 1 : 0.55)
                    .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: pulse)
                Group {
                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Text("🙂")
                            .font(.system(size: 18))
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            }
        }
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
    @Published var lost = false
    @Published var wave = 1
    @Published var waveBanner: Int? = nil
    @Published var zigzag = 1
    @Published var mirror = 1
    @Published var shuffle = 1
    @Published var paused = false
    @Published var cpuScore = 0
    @Published var earnedStars = 0
    @Published var waiting = false
    @Published var banner: String?
    @Published var oppLabel = "CPU"
    let profile: ProfileManager
    let request: PlayRequest
    private(set) var link: FriendBattleLink?

    init(profile: ProfileManager, request: PlayRequest) {
        self.profile = profile
        self.request = request
        let inv = (request.mode == .arcade || request.mode == .daily)
            ? Inventory(bombs: 2, fireballs: 2, faceBalls: 1)
            : profile.inventory
        bombs = inv.bombs
        fire = inv.fireballs
        face = inv.faceBalls
        let size = UIScreen.main.bounds.size
        let scene = GameScene(
            size: size,
            inventory: inv,
            seed: request.seed,
            mode: request.mode,
            levelId: request.levelId
        )
        scene.scaleMode = .resizeFill
        scene.profile = profile
        scene.vsFriend = !request.roomCode.isEmpty
        scene.cpuEnabled = request.roomCode.isEmpty
        scene.opponentName = request.roomCode.isEmpty ? "CPU" : request.roomCode
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
                self.link?.sendScore(score, over: nil)
            }
        }
        scene.onWin = { [weak self] in
            DispatchQueue.main.async {
                self?.link?.sendScore(self?.score ?? 0, over: "win")
                self?.won = true
            }
        }
        scene.onLose = { [weak self] in
            DispatchQueue.main.async { self?.lost = true }
        }
        scene.onWave = { [weak self] wave, score in
            DispatchQueue.main.async {
                self?.wave = wave
                self?.score = score
                self?.waveBanner = wave
            }
        }
        scene.onPickup = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                let inv = self.scene.powers.inventory
                self.bombs = inv.bombs
                self.fire = inv.fireballs
                self.face = inv.faceBalls
            }
        }
        scene.onStars = { [weak self] n in
            DispatchQueue.main.async { self?.earnedStars = n }
        }
        scene.onCpu = { [weak self] n in
            DispatchQueue.main.async { self?.cpuScore = n }
        }
        scene.battleBanner = { [weak self] msg in
            DispatchQueue.main.async {
                self?.banner = msg
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    if self?.banner == msg { self?.banner = nil }
                }
            }
        }
        if request.resume, let data = profile.savedRun,
           let snap = try? JSONDecoder().decode(RunSnapshot.self, from: data) {
            scene.pendingRestore = snap
        }
        if request.mode == .battle, !request.roomCode.isEmpty, !request.resume {
            waiting = true
            scene.cpuEnabled = false
            let link = FriendBattleLink(
                code: request.roomCode,
                hosting: request.hosting,
                name: profile.username.isEmpty ? "Player" : profile.username
            )
            self.link = link
            oppLabel = request.roomCode
            link.onPower = { [weak scene] p in scene?.applyOpponentPower(p) }
            link.onScore = { [weak self] n in
                DispatchQueue.main.async { self?.cpuScore = n }
            }
            link.onOpponentWin = { [weak self] in
                DispatchQueue.main.async { self?.lost = true }
            }
            link.onDropped = { [weak self] in
                DispatchQueue.main.async { self?.startStandIn() }
            }
            link.onConnected = { [weak self] in
                guard let self else { return }
                self.waiting = false
                self.scene.isPaused = false
                self.scene.stopCPU()
                self.oppLabel = self.link?.opponentName ?? "Friend"
            }
            link.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                guard let self, self.waiting else { return }
                self.startStandIn()
            }
        }
        profile.notePlay()
    }

    func startStandIn() {
        waiting = false
        oppLabel = "Stand-in"
        scene.vsFriend = false
        scene.bootCPU()
        scene.isPaused = false
        banner = "Stand-in joined"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            if self?.banner == "Stand-in joined" { self?.banner = nil }
        }
    }

    func persist() {
        if let data = try? JSONEncoder().encode(scene.snapshot()) {
            profile.savedRun = data
            profile.save()
        }
    }

    func clearSave() {
        profile.savedRun = nil
        profile.save()
    }

    func load(_ power: PowerUp) {
        scene.loadPower(power)
        loaded = scene.powers.loaded
        AudioEngine.shared.load()
        Haptics.aimTick()
    }

    func useBattle(_ p: BattlePower) {
        scene.useBattle(p)
        zigzag = scene.powers.battle.zigzag
        mirror = scene.powers.battle.mirror
        shuffle = scene.powers.battle.shuffle
        link?.sendPower(p)
        Haptics.aimTick()
    }
}

private struct BattleChip: View {
    let title: String
    let icon: String
    let count: Int
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(icon).font(.system(size: 22))
                Text(title).font(.system(size: 11, weight: .semibold, design: .rounded))
                Text("\(count)").font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .foregroundStyle(.white)
        .disabled(count <= 0)
        .opacity(count <= 0 ? 0.4 : 1)
    }
}
