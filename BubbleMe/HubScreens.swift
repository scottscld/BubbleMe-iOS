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
                                    Button {
                                        if available { onPlay(lvl.id) }
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text("\(lvl.id)")
                                                .font(.display(16, weight: .bold))
                                            Text(lvl.goal)
                                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                        }
                                        .foregroundStyle(available ? Palette.fg : Palette.muted)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 64)
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
    var onCPU: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Battle")
                .font(.display(32, weight: .bold))
            Text("Same seeded board. First to clear — or highest score — wins.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.muted)
            Button("Duel the CPU", action: onCPU)
                .buttonStyle(PrimaryButton())
            Text("Invites")
                .font(.display(18))
                .padding(.top, 12)
            Text("Challenge a friend from the Friends tab. They’ll appear here.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Palette.border, lineWidth: 1)
                )
            Spacer()
        }
        .foregroundStyle(Palette.fg)
        .padding(20)
        .background(Palette.bg)
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
                TextField("Display name", text: $profile.username)
                    .font(.display(22))
                    .multilineTextAlignment(.center)
                    .onChange(of: profile.username) { _, _ in profile.save() }
                Text("Friend code \(profile.friendCode)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                HStack {
                    stat("\(profile.wins)", "Wins")
                    stat("\(profile.losses)", "Losses")
                    stat("\(profile.coins)", "Coins")
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
                    Text("Tap the circle on Home to change your photo. It skins the launcher and Face Ball.")
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
                            if on { FriendsManager(friendCode: profile.friendCode).requestAlertPermission() }
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
        .preferredColorScheme(.dark)
    }
}

struct ArcadeBoardSheet: View {
    var best: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("Resets in \(ArcadeWeek.formatCountdown(until: ArcadeWeek.nextReset(), now: context.date))")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }
                Text("This week’s best")
                    .font(.display(18))
                Text("\(best)")
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.accent)
                Text("Everyone plays the same generated boards this week. Waves get harder; points go up.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.muted)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Palette.bg)
            .foregroundStyle(Palette.fg)
            .navigationTitle("Leaderboard")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
