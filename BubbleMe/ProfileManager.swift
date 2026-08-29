import UIKit
import PhotosUI

/// Crops an uploaded photo into a circular shooter skin + Face Ball, caches locally, syncs when online.
final class ProfileManager: ObservableObject {
    @Published var photo: UIImage?
    @Published var username = "Guest"
    @Published var friendCode = ""
    @Published var hapticEnabled = true
    @Published var musicEnabled = true
    @Published var sfxEnabled = true
    @Published var alertsEnabled = false
    @Published var inventory = Inventory(bombs: 3, fireballs: 3, faceBalls: 1)
    @Published var wins = 0
    @Published var losses = 0
    @Published var bubbles = 180
    @Published var highestLevel = 1
    @Published var arcadeBest = 0
    @Published var arcadeBestWave = 0
    @Published var arcadeWeek = ""
    @Published var streak = 0
    @Published var lastPlayDay = ""
    @Published var shooter: ShooterKind = .cannon
    @Published var palette: ColorPack = .classic
    @Published var style: BubbleStyle = .solid
    @Published var background: PlayBackground = .twilight
    @Published var ownedShooters: Set<String> = [ShooterKind.cannon.rawValue]
    @Published var ownedPalettes: Set<String> = [ColorPack.classic.rawValue]
    @Published var ownedStyles: Set<String> = [BubbleStyle.solid.rawValue]
    @Published var ownedBackgrounds: Set<String> = [PlayBackground.twilight.rawValue]
    @Published var stars: [String: Int] = [:]
    @Published var lastDailyDay = ""
    @Published var dailyDone = false
    @Published var savedRun: Data?
    @Published var battleCode = ""
    @Published var friendIds: [String] = []
    @Published var pendingFriendIds: [String] = []

    private let key = "bubbleme.profile"

    init() {
        load()
        if friendCode.isEmpty { friendCode = Self.makeCode() }
        Haptics.enabled = hapticEnabled
        AudioEngine.shared.musicOn = musicEnabled
        AudioEngine.shared.sfxOn = sfxEnabled
        rotateArcadeIfNeeded()
        rotateDailyIfNeeded()
        if alertsEnabled {
            NotificationManager.shared.request()
            NotificationManager.shared.streakWarning(streak: max(1, streak))
        }
    }

    func setHaptic(_ on: Bool) {
        hapticEnabled = on
        Haptics.enabled = on
        save()
    }

    func setMusic(_ on: Bool) {
        musicEnabled = on
        AudioEngine.shared.musicOn = on
        save()
    }

    func setSfx(_ on: Bool) {
        sfxEnabled = on
        AudioEngine.shared.sfxOn = on
        save()
    }

    func rotateDailyIfNeeded() {
        let day = ArcadeWeek.dayId()
        if lastDailyDay != day {
            lastDailyDay = day
            dailyDone = false
            save()
        }
    }

    func completeDaily() {
        dailyDone = true
        save()
    }

    func stars(for level: Int) -> Int { stars[String(level)] ?? 0 }

    @discardableResult
    func awardStars(_ earned: Int, level: Int) -> Int {
        let prev = stars(for: level)
        guard earned > prev else { return 0 }
        let table = [0, 25, 50, 75]
        let gain = table[min(3, earned)] - table[min(3, prev)]
        bubbles += gain
        stars[String(level)] = earned
        save()
        return gain
    }

    func cloudBlob() -> Data? {
        try? JSONEncoder().encode(Save.from(self))
    }

    func mergeCloud(_ data: Data) {
        guard let decoded = try? JSONDecoder().decode(Save.self, from: data) else { return }
        bubbles = max(bubbles, decoded.bubbles)
        highestLevel = max(highestLevel, decoded.highestLevel)
        wins = max(wins, decoded.wins)
        arcadeBest = max(arcadeBest, decoded.arcadeBest)
        for (k, v) in decoded.stars { stars[k] = max(stars[k] ?? 0, v) }
        save()
    }

    func setAlerts(_ on: Bool) {
        alertsEnabled = on
        if on {
            NotificationManager.shared.request()
            NotificationManager.shared.streakWarning(streak: max(1, streak))
        } else {
            NotificationManager.shared.cancelStreak()
        }
        save()
    }

    func importPhoto(_ image: UIImage) {
        photo = Self.circleCrop(image, size: 192)
        save()
    }

    func clearPhoto() {
        photo = nil
        save()
    }

    func addBubbles(_ n: Int) {
        bubbles += n
        save()
    }

    func notePlay() {
        let day = ArcadeWeek.dayId()
        if lastPlayDay != day {
            let y = ArcadeWeek.yesterdayId()
            streak = lastPlayDay == y ? streak + 1 : 1
            lastPlayDay = day
            save()
        }
        if alertsEnabled {
            NotificationManager.shared.streakWarning(streak: streak)
        }
    }

    func clearLevel(_ id: Int) {
        if id >= highestLevel { highestLevel = min(LevelsCatalog.count, id + 1) }
        save()
    }

    func recordArcade(score: Int, wave: Int = 1) {
        rotateArcadeIfNeeded()
        if score > arcadeBest {
            arcadeBest = score
            arcadeBestWave = max(1, wave)
        }
        save()
    }

    func rotateArcadeIfNeeded() {
        let week = ArcadeWeek.weekId()
        if arcadeWeek != week {
            if !arcadeWeek.isEmpty, arcadeBest > 0, alertsEnabled {
                NotificationManager.shared.weekWinner()
            }
            arcadeWeek = week
            arcadeBest = 0
            arcadeBestWave = 0
            save()
        }
    }

    func boardStatus(for id: String) -> String {
        if friendIds.contains(id) { return "friends" }
        if pendingFriendIds.contains(id) { return "pending" }
        return "none"
    }

    func addFromBoard(id: String, name: String) {
        if friendIds.contains(id) { return }
        pendingFriendIds.removeAll { $0 == id }
        friendIds.append(id)
        Haptics.ui()
        if alertsEnabled {
            NotificationManager.shared.friendRequest(from: name)
        }
        save()
    }

    func owns(shooter k: ShooterKind) -> Bool { ownedShooters.contains(k.rawValue) }
    func owns(palette k: ColorPack) -> Bool { ownedPalettes.contains(k.rawValue) }
    func owns(style k: BubbleStyle) -> Bool { ownedStyles.contains(k.rawValue) }
    func owns(background k: PlayBackground) -> Bool { ownedBackgrounds.contains(k.rawValue) }

    func buyOrEquip(shooter k: ShooterKind) {
        if owns(shooter: k) { shooter = k; save(); return }
        guard bubbles >= k.price else { return }
        bubbles -= k.price
        ownedShooters.insert(k.rawValue)
        shooter = k
        save()
        Haptics.win()
    }

    func buyOrEquip(palette k: ColorPack) {
        if owns(palette: k) { palette = k; save(); return }
        guard bubbles >= k.price else { return }
        bubbles -= k.price
        ownedPalettes.insert(k.rawValue)
        palette = k
        save()
        Haptics.win()
    }

    func buyOrEquip(style k: BubbleStyle) {
        if owns(style: k) { style = k; save(); return }
        guard bubbles >= k.price else { return }
        bubbles -= k.price
        ownedStyles.insert(k.rawValue)
        style = k
        save()
        Haptics.win()
    }

    func buyOrEquip(background k: PlayBackground) {
        if owns(background: k) { background = k; save(); return }
        guard bubbles >= k.price else { return }
        bubbles -= k.price
        ownedBackgrounds.insert(k.rawValue)
        background = k
        save()
        Haptics.win()
    }

    static func circleCrop(_ image: UIImage, size: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            UIBezierPath(ovalIn: rect).addClip()
            let scale = max(size / image.size.width, size / image.size.height)
            let w = image.size.width * scale
            let h = image.size.height * scale
            image.draw(in: CGRect(x: (size - w) / 2, y: (size - h) / 2, width: w, height: h))
            ctx.cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.4).cgColor)
            ctx.cgContext.setLineWidth(3)
            ctx.cgContext.strokeEllipse(in: rect.insetBy(dx: 1.5, dy: 1.5))
        }
    }

    static func makeCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Save.self, from: data) else { return }
        username = decoded.username
        friendCode = decoded.friendCode
        hapticEnabled = decoded.haptic
        musicEnabled = decoded.music
        sfxEnabled = decoded.sfx
        alertsEnabled = decoded.alerts
        inventory = decoded.inventory
        wins = decoded.wins
        losses = decoded.losses
        bubbles = decoded.bubbles > 0 ? decoded.bubbles : decoded.coins
        highestLevel = max(1, decoded.highestLevel)
        arcadeBest = decoded.arcadeBest
        arcadeBestWave = decoded.arcadeBestWave ?? 0
        arcadeWeek = decoded.arcadeWeek
        streak = decoded.streak
        lastPlayDay = decoded.lastPlayDay
        shooter = decoded.shooter
        palette = decoded.palette
        style = decoded.style
        background = decoded.background
        ownedShooters = Set(decoded.ownedShooters)
        ownedPalettes = Set(decoded.ownedPalettes)
        ownedStyles = Set(decoded.ownedStyles)
        ownedBackgrounds = Set(decoded.ownedBackgrounds)
        if ownedShooters.isEmpty { ownedShooters = [ShooterKind.cannon.rawValue] }
        if ownedPalettes.isEmpty { ownedPalettes = [ColorPack.classic.rawValue] }
        if ownedStyles.isEmpty { ownedStyles = [BubbleStyle.solid.rawValue] }
        if ownedBackgrounds.isEmpty { ownedBackgrounds = [PlayBackground.twilight.rawValue] }
        if let jpeg = decoded.photo, let img = UIImage(data: jpeg) { photo = img }
        stars = decoded.stars
        lastDailyDay = decoded.lastDailyDay
        dailyDone = decoded.dailyDone
        savedRun = decoded.savedRun
        battleCode = decoded.battleCode
        friendIds = decoded.friendIds ?? []
        pendingFriendIds = decoded.pendingFriendIds ?? []
    }

    func save() {
        let save = Save(
            username: username,
            friendCode: friendCode,
            haptic: hapticEnabled,
            music: musicEnabled,
            sfx: sfxEnabled,
            alerts: alertsEnabled,
            inventory: inventory,
            photo: photo?.jpegData(compressionQuality: 0.72),
            wins: wins,
            losses: losses,
            coins: bubbles,
            bubbles: bubbles,
            highestLevel: highestLevel,
            arcadeBest: arcadeBest,
            arcadeBestWave: arcadeBestWave,
            arcadeWeek: arcadeWeek,
            streak: streak,
            lastPlayDay: lastPlayDay,
            shooter: shooter,
            palette: palette,
            style: style,
            background: background,
            ownedShooters: Array(ownedShooters),
            ownedPalettes: Array(ownedPalettes),
            ownedStyles: Array(ownedStyles),
            ownedBackgrounds: Array(ownedBackgrounds),
            stars: stars,
            lastDailyDay: lastDailyDay,
            dailyDone: dailyDone,
            savedRun: savedRun,
            battleCode: battleCode,
            friendIds: friendIds,
            pendingFriendIds: pendingFriendIds
        )
        if let data = try? JSONEncoder().encode(save) {
            UserDefaults.standard.set(data, forKey: key)
        }
        CloudSync.shared.push(profile: self)
    }

    private struct Save: Codable {
        var username: String
        var friendCode: String
        var haptic: Bool
        var music: Bool
        var sfx: Bool
        var alerts: Bool = false
        var inventory: Inventory
        var photo: Data?
        var wins: Int = 0
        var losses: Int = 0
        var coins: Int = 0
        var bubbles: Int = 0
        var highestLevel: Int = 1
        var arcadeBest: Int = 0
        var arcadeBestWave: Int? = 0
        var arcadeWeek: String = ""
        var streak: Int = 0
        var lastPlayDay: String = ""
        var shooter: ShooterKind = .cannon
        var palette: ColorPack = .classic
        var style: BubbleStyle = .solid
        var background: PlayBackground = .twilight
        var ownedShooters: [String] = [ShooterKind.cannon.rawValue]
        var ownedPalettes: [String] = [ColorPack.classic.rawValue]
        var ownedStyles: [String] = [BubbleStyle.solid.rawValue]
        var ownedBackgrounds: [String] = [PlayBackground.twilight.rawValue]
        var stars: [String: Int] = [:]
        var lastDailyDay: String = ""
        var dailyDone: Bool = false
        var savedRun: Data? = nil
        var battleCode: String = ""
        var friendIds: [String]? = []
        var pendingFriendIds: [String]? = []

        static func from(_ p: ProfileManager) -> Save {
            Save(
                username: p.username, friendCode: p.friendCode, haptic: p.hapticEnabled,
                music: p.musicEnabled, sfx: p.sfxEnabled, alerts: p.alertsEnabled,
                inventory: p.inventory, photo: p.photo?.jpegData(compressionQuality: 0.72),
                wins: p.wins, losses: p.losses, coins: p.bubbles, bubbles: p.bubbles,
                highestLevel: p.highestLevel, arcadeBest: p.arcadeBest, arcadeBestWave: p.arcadeBestWave, arcadeWeek: p.arcadeWeek,
                streak: p.streak, lastPlayDay: p.lastPlayDay, shooter: p.shooter, palette: p.palette,
                style: p.style, background: p.background,
                ownedShooters: Array(p.ownedShooters), ownedPalettes: Array(p.ownedPalettes),
                ownedStyles: Array(p.ownedStyles), ownedBackgrounds: Array(p.ownedBackgrounds),
                stars: p.stars, lastDailyDay: p.lastDailyDay, dailyDone: p.dailyDone,
                savedRun: p.savedRun, battleCode: p.battleCode,
                friendIds: p.friendIds, pendingFriendIds: p.pendingFriendIds
            )
        }
    }
}
