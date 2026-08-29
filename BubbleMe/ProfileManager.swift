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
    @Published var inventory = Inventory(bombs: 3, fireballs: 3, faceBalls: 1)

    private let key = "bubbleme.profile"

    init() {
        load()
        if friendCode.isEmpty { friendCode = Self.makeCode() }
        Haptics.enabled = hapticEnabled
    }

    func setHaptic(_ on: Bool) {
        hapticEnabled = on
        Haptics.enabled = on
        save()
    }

    func importPhoto(_ image: UIImage) {
        photo = Self.circleCrop(image, size: 192)
        save()
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
        inventory = decoded.inventory
        if let jpeg = decoded.photo, let img = UIImage(data: jpeg) { photo = img }
    }

    func save() {
        let save = Save(
            username: username,
            friendCode: friendCode,
            haptic: hapticEnabled,
            music: musicEnabled,
            sfx: sfxEnabled,
            inventory: inventory,
            photo: photo?.jpegData(compressionQuality: 0.72)
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
        var inventory: Inventory
        var photo: Data?
    }
}
