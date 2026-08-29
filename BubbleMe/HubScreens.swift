import SwiftUI
import PhotosUI

struct LevelsHub: View {
    @ObservedObject var profile: ProfileManager
    var onPlay: (Int) -> Void
    @State private var open: Int

    init(profile: ProfileManager, onPlay: @escaping (Int) -> Void) {
        self.profile = profile
        self.onPlay = onPlay
        _open = State(initialValue: LevelsCatalog.packIndex(for: profile.highestLevel))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Levels")
                    .font(.display(32, weight: .bold))
                    .foregroundStyle(Palette.fg)
                Text("\(max(0, profile.highestLevel - 1)) / \(LevelsCatalog.count) popped · unique boards, shapes, and goals.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.muted)

                ForEach(LevelsCatalog.packs) { pack in
                    let start = pack.id * LevelsCatalog.packSize + 1
                    let locked = profile.highestLevel < start
                    let done = min(LevelsCatalog.packSize, max(0, profile.highestLevel - start))
                    let expanded = open == pack.id && !locked
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            if !locked { open = expanded ? -1 : pack.id }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pack.name).font(.display(18)).foregroundStyle(Palette.fg)
                                    Text(locked ? "Clear the previous pack" : "\(pack.blurb) · \(done)/\(LevelsCatalog.packSize)")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(Palette.muted)
                                }
                                Spacer()
                                Image(systemName: locked ? "lock.fill" : "chevron.down")
                                    .rotationEffect(.degrees(expanded ? 180 : 0))
                                    .foregroundStyle(Palette.muted)
                            }
                            .padding(16)
                        }
                        .disabled(locked)
                        if expanded {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                                ForEach(LevelsCatalog.levels(in: pack.id)) { lvl in
                                    let available = lvl.id <= profile.highestLevel
                                    let stars = profile.stars(for: lvl.id)
                                    Button {
                                        if available { onPlay(lvl.id) }
                                    } label: {
                                        VStack(spacing: 3) {
                                            Text("\(lvl.id)")
                                                .font(.display(16, weight: .bold))
                                            Text(lvl.goal)
                                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                            HStack(spacing: 2) {
                                                ForEach(1...3, id: \.self) { i in
                                                    Image(systemName: i <= stars ? "star.fill" : "star")
                                                        .font(.system(size: 8))
                                                        .foregroundStyle(i <= stars ? Palette.accent : Palette.muted.opacity(0.45))
                                                }
                                            }
                                        }
                                        .foregroundStyle(available ? Palette.fg : Palette.muted)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 78)
                                        .background(available ? Palette.surface2 : Palette.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .disabled(!available)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                        }
                    }
                    .background(locked ? Palette.surface2.opacity(0.6) : Palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Palette.border, lineWidth: 1)
                    )
                    .opacity(locked ? 0.7 : 1)
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(Palette.bg)
    }
}

struct BattleHub: View {
    @ObservedObject var profile: ProfileManager
    var onCPU: () -> Void
    var onFriend: (String, Bool) -> Void
    @State private var join = ""
    @State private var created = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Battle")
                    .font(.display(32, weight: .bold))
                Text("Same seeded board. First to clear — or highest score — wins. ZigZag, Mirror, and Shuffle hit the opponent, not you.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.muted)
                Button("Duel the CPU", action: onCPU)
                    .buttonStyle(PrimaryButton())
                Text("The CPU shoots back on its own copy of the board and will throw ZigZag / Mirror / Shuffle at you.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.muted)

                Text("Friend nearby")
                    .font(.display(18))
                    .padding(.top, 8)
                Text("Same Wi‑Fi or Bluetooth. You host a 4-letter room; they type it in Join. If nobody connects in 15 seconds, a stand-in plays that board.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.muted)

                if created.isEmpty {
                    Button("Create a room") {
                        created = RoomCode.make()
                        profile.battleCode = created
                        profile.save()
                    }
                    .buttonStyle(SecondaryButton())
                } else {
                    Text(created)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity)
                    ShareLink(item: "Battle me in Bubble Me — room \(created). Open Battle, tap Join, type \(created).") {
                        Label("Share code", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .foregroundStyle(Palette.fg)
                    Button("Start waiting") { onFriend(created, true) }
                        .buttonStyle(PrimaryButton())
                }

                HStack(spacing: 10) {
                    TextField("JOIN", text: $join)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Palette.border, lineWidth: 1)
                        )
                        .onChange(of: join) { _, v in
                            join = String(v.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(4))
                        }
                    Button("Join") { onFriend(join, false) }
                        .buttonStyle(PrimaryButton())
                        .opacity(join.count == 4 ? 1 : 0.45)
                        .disabled(join.count != 4)
                }
            }
            .foregroundStyle(Palette.fg)
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(Palette.bg)
        .onAppear {
            if created.isEmpty, !profile.battleCode.isEmpty {
                created = profile.battleCode
            }
        }
    }
}

struct FriendsHub: View {
    let code: String
    @State private var alertsEnabled = false

    private var friends: FriendsManager { FriendsManager(friendCode: code) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Friends")
                .font(.display(32, weight: .bold))
            Text("Friends are other Bubble Me players — not X or Google contacts.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.muted)
            Text(code)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .textSelection(.enabled)
            Text("Send this code with Messages or email. They open Bubble Me, go to Friends, and send a request.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.muted)
            HStack(spacing: 10) {
                Button("Messages") { friends.openMessages() }
                    .buttonStyle(PrimaryButton())
                Button("Email") { friends.openMail() }
                    .buttonStyle(SecondaryButton())
            }
            ShareLink(item: friends.inviteText) {
                Label("More", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .foregroundStyle(Palette.fg)
            Toggle("Friend alerts", isOn: $alertsEnabled)
                .tint(Palette.accent)
                .onChange(of: alertsEnabled) { _, on in
                    if on { friends.requestAlertPermission() }
                }
            Spacer()
        }
        .foregroundStyle(Palette.fg)
        .padding(20)
        .background(Palette.bg)
    }
}

struct ProfileHub: View {
    @ObservedObject var profile: ProfileManager
    @Binding var picker: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Me")
                    .font(.display(32, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                PhotosPicker(selection: $picker, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.white.opacity(0.5), Palette.accent],
                                    center: .topLeading,
                                    startRadius: 4,
                                    endRadius: 70
                                )
                            )
                        if let photo = profile.photo {
                            Image(uiImage: photo).resizable().scaledToFill()
                        } else {
                            Image(systemName: "camera.fill").font(.title).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 112, height: 112)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 2))
                }
                if profile.photo != nil {
                    Button("Remove photo") { profile.clearPhoto() }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.accent)
                }
                TextField("Display name", text: $profile.username)
                    .font(.display(22))
                    .multilineTextAlignment(.center)
                    .onChange(of: profile.username) { _, _ in profile.save() }
                Text("Friend code \(profile.friendCode)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                GameCenterRow()
                HStack {
                    stat("\(profile.wins)", "Wins")
                    stat("\(profile.losses)", "Losses")
                    stat("\(profile.bubbles)", "Bubbles")
                }
                ShareLink(item: FriendsManager(friendCode: profile.friendCode).inviteText) {
                    Text("Invite a player")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButton())
            }
            .foregroundStyle(Palette.fg)
            .padding(20)
        }
        .background(Palette.bg)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.display(22, weight: .bold))
            Text(label).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    Text("Tap the circle on Home to change your photo. Remove it on the Me tab to reset to default.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if profile.photo != nil {
                        Button("Remove photo") { profile.clearPhoto() }
                    }
                }
                Section("Alerts") {
                    Toggle("Streak, board, friends, battles", isOn: Binding(
                        get: { profile.alertsEnabled },
                        set: { profile.setAlerts($0) }
                    ))
                    Text("Streak warning at 8pm CT. Friend / battle / leaderboard alerts fire as local notifications (remote push needs a paid Apple account).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Feel") {
                    Toggle("Haptic rumble", isOn: Binding(
                        get: { profile.hapticEnabled },
                        set: { profile.setHaptic($0) }
                    ))
                    Toggle("Music", isOn: Binding(
                        get: { profile.musicEnabled },
                        set: { profile.setMusic($0) }
                    ))
                    Toggle("Sound effects", isOn: Binding(
                        get: { profile.sfxEnabled },
                        set: { profile.setSfx($0) }
                    ))
                    Toggle("Friend alerts", isOn: $alerts)
                        .onChange(of: alerts) { _, on in
                            if on { FriendsManager(friendCode: profile.friendCode).requestAlertPermission() }
                        }
                }
                Section("You") {
                    TextField("Display name", text: $profile.username)
                        .onChange(of: profile.username) { _, _ in profile.save() }
                    LabeledContent("Friend code", value: profile.friendCode)
                    LabeledContent("Game Center", value: CloudSync.shared.signedIn ? CloudSync.shared.playerName : "Not signed in")
                    Button(CloudSync.shared.signedIn ? "Sync now" : "Sign in with Game Center") {
                        CloudSync.shared.authenticate()
                        if CloudSync.shared.signedIn { CloudSync.shared.push(profile: profile) }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct ArcadeBoardSheet: View {
    @ObservedObject var profile: ProfileManager
    var onPlay: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""

    private var entries: [BoardPlayer] {
        WeeklyBoard.entries(player: profile.username, score: profile.arcadeBest, wave: profile.arcadeBestWave)
    }

    private var rank: Int? {
        WeeklyBoard.rank(player: profile.username, score: profile.arcadeBest, wave: profile.arcadeBestWave)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("WEEKLY RUN")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(2.4)
                        .foregroundStyle(Palette.muted)
                    Text("Arcade")
                        .font(.display(32, weight: .bold))
                    Text("Same boards for everyone. Add other Bubble Me players from this board — requests stay in the game.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.muted)

                    Button("Play Arcade") {
                        dismiss()
                        onPlay()
                    }
                    .buttonStyle(PrimaryButton())

                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("Resets in \(ArcadeWeek.formatCountdown(until: ArcadeWeek.nextReset(), now: context.date))")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.muted)
                            .frame(maxWidth: .infinity)
                    }

                    HStack(spacing: 8) {
                        stat("BEST", profile.arcadeBest > 0 ? "\(profile.arcadeBest)" : "0")
                        stat("WAVE", profile.arcadeBestWave > 0 ? "\(profile.arcadeBestWave)" : "—")
                        stat("RANK", rank.map { "\($0)" } ?? "—")
                    }

                    if !note.isEmpty {
                        Text(note)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.aqua)
                    }

                    HStack {
                        Text("Leaderboard")
                            .font(.display(18))
                        Spacer()
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(Palette.aqua)
                    }
                    .padding(.top, 4)

                    VStack(spacing: 8) {
                        ForEach(entries) { row in
                            boardRow(row)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(Palette.bg)
            .foregroundStyle(Palette.fg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(Palette.muted)
            Text(value)
                .font(.display(18, weight: .bold).monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Palette.border, lineWidth: 1)
        )
    }

    private func boardRow(_ row: BoardPlayer) -> some View {
        HStack(spacing: 12) {
            Text("\(row.rank)")
                .font(.display(18))
                .foregroundStyle(rankColor(row.rank))
                .frame(width: 28)
            ZStack {
                Circle().fill(row.tone)
                if row.you, let photo = profile.photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    Text(String(row.name.prefix(1)))
                        .font(.display(16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(row.you ? "\(row.name) (you)" : row.name)
                    .font(.display(16))
                    .lineLimit(1)
                Text("Wave \(row.wave)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 8)
            Text(row.score.formatted())
                .font(.display(16).monospacedDigit())
            if !row.you {
                friendChip(row)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(row.you ? Palette.aqua.opacity(0.4) : Palette.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func friendChip(_ row: BoardPlayer) -> some View {
        switch profile.boardStatus(for: row.id) {
        case "friends":
            Text("Friends")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.aqua)
        case "pending":
            Text("Requested")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.muted)
        default:
            Button {
                profile.addFromBoard(id: row.id, name: row.name)
                note = "\(row.name) is now your friend. They’ll get an in-game alert."
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.plus")
                    Text("Add")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(Palette.surface2, in: Capsule())
                .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
            }
            .foregroundStyle(Palette.fg)
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 0.94, green: 0.78, blue: 0.37)
        case 2: return Color(red: 0.79, green: 0.82, blue: 0.87)
        case 3: return Color(red: 0.83, green: 0.57, blue: 0.35)
        default: return Palette.muted
        }
    }
}
