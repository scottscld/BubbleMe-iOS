import UIKit

/// Unique haptic patterns per action. Aim rumble fires while the player sweeps the pointer.
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notify = UINotificationFeedbackGenerator()
    private static let select = UISelectionFeedbackGenerator()
    private static var lastAim: TimeInterval = 0
    static var enabled = true

    static func prepare() {
        light.prepare()
        medium.prepare()
        heavy.prepare()
        select.prepare()
    }

    static func aimTick() {
        guard enabled else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastAim > 0.045 else { return }
        lastAim = now
        select.selectionChanged()
        select.prepare()
    }

    static func shoot() { guard enabled else { return }; light.impactOccurred(intensity: 0.7) }
    static func pop() { guard enabled else { return }; medium.impactOccurred(intensity: 0.8) }
    static func drop() { guard enabled else { return }; heavy.impactOccurred(intensity: 0.6) }
    static func bomb() { guard enabled else { return }; heavy.impactOccurred(); notify.notificationOccurred(.warning) }
    static func fire() {
        guard enabled else { return }
        light.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { light.impactOccurred() }
    }
    static func face() { guard enabled else { return }; notify.notificationOccurred(.success) }
    static func zigzag() { guard enabled else { return }; select.selectionChanged(); light.impactOccurred() }
    static func mirror() { guard enabled else { return }; medium.impactOccurred() }
    static func shuffle() { guard enabled else { return }; heavy.impactOccurred(intensity: 0.5) }
    static func win() { guard enabled else { return }; notify.notificationOccurred(.success) }
    static func lose() { guard enabled else { return }; notify.notificationOccurred(.error) }
}
