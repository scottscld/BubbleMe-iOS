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

    private let key = "bubbleme.profile"

    init() {
        load()
        if friendCode.isEmpty { friendCode = Self.makeCode() }
        Haptics.enabled = hapticEnabled
        rotateArcadeIfNeeded()
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
        bubbles += 12
        save()
    }

    func recordArcade(score: Int) {
        rotateArcadeIfNeeded()
        if score > arcadeBest { arcadeBest = score }
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
            save()
        }
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
            ownedBackgrounds: Array(ownedBackgrounds)
        )
        if let data = try? JSONEncoder().encode(save) {
            UserDefaults.standard.set(data, forKey: key)
        }
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
    }
}
