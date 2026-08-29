import SwiftUI
import SpriteKit
import UIKit

enum ShooterKind: String, CaseIterable, Codable, Identifiable {
    case cannon, twin, laser, rocket, wand, star
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cannon: return "Classic Cannon"
        case .twin: return "Twin Poppers"
        case .laser: return "Prism Laser"
        case .rocket: return "Rocket Pod"
        case .wand: return "Bubble Wand"
        case .star: return "Star Ray"
        }
    }
    var blurb: String {
        switch self {
        case .cannon: return "The original launcher."
        case .twin: return "Two barrels. Same aim. Extra flair."
        case .laser: return "A thin beam of pop energy."
        case .rocket: return "Fins, boosters, big attitude."
        case .wand: return "A sparkly wand that flicks bubbles."
        case .star: return "Shoots from a spinning star."
        }
    }
    var price: Int {
        switch self {
        case .cannon: return 0
        case .twin: return 250
        case .laser: return 400
        case .rocket: return 500
        case .wand: return 350
        case .star: return 600
        }
    }
    var emoji: String {
        switch self {
        case .cannon: return "💣"
        case .twin: return "🎯"
        case .laser: return "🔷"
        case .rocket: return "🚀"
        case .wand: return "🪄"
        case .star: return "⭐"
        }
    }
}

enum ColorPack: String, CaseIterable, Codable, Identifiable {
    case classic, sunset, ocean, neon, pastel, midnight
    var id: String { rawValue }
    var title: String {
        switch self {
        case .classic: return "Classic"
        case .sunset: return "Sunset"
        case .ocean: return "Tide Pool"
        case .neon: return "Neon Night"
        case .pastel: return "Cotton"
        case .midnight: return "Midnight"
        }
    }
    var price: Int {
        switch self {
        case .classic: return 0
        case .sunset, .ocean: return 200
        case .pastel: return 250
        case .midnight: return 300
        case .neon: return 350
        }
    }
    func uiColor(_ c: BubbleColor) -> UIColor {
        let hex: (CGFloat, CGFloat, CGFloat)
        switch (self, c) {
        case (.classic, .red): hex = (1.00, 0.35, 0.48)
        case (.classic, .amber): hex = (1.00, 0.69, 0.13)
        case (.classic, .lime): hex = (0.35, 0.84, 0.29)
        case (.classic, .azure): hex = (0.23, 0.63, 1.00)
        case (.classic, .violet): hex = (0.61, 0.42, 1.00)
        case (.classic, .aqua): hex = (0.18, 0.90, 0.77)

        case (.sunset, .red): hex = (1.00, 0.42, 0.28)
        case (.sunset, .amber): hex = (1.00, 0.62, 0.18)
        case (.sunset, .lime): hex = (1.00, 0.82, 0.28)
        case (.sunset, .azure): hex = (0.95, 0.35, 0.45)
        case (.sunset, .violet): hex = (0.72, 0.22, 0.48)
        case (.sunset, .aqua): hex = (1.00, 0.55, 0.62)

        case (.ocean, .red): hex = (0.12, 0.72, 0.82)
        case (.ocean, .amber): hex = (0.20, 0.88, 0.78)
        case (.ocean, .lime): hex = (0.45, 0.95, 0.70)
        case (.ocean, .azure): hex = (0.15, 0.48, 0.95)
        case (.ocean, .violet): hex = (0.25, 0.28, 0.72)
        case (.ocean, .aqua): hex = (0.55, 0.90, 1.00)

        case (.neon, .red): hex = (1.00, 0.12, 0.45)
        case (.neon, .amber): hex = (1.00, 0.92, 0.12)
        case (.neon, .lime): hex = (0.12, 1.00, 0.42)
        case (.neon, .azure): hex = (0.12, 0.85, 1.00)
        case (.neon, .violet): hex = (0.82, 0.20, 1.00)
        case (.neon, .aqua): hex = (0.20, 1.00, 0.88)

        case (.pastel, .red): hex = (1.00, 0.62, 0.70)
        case (.pastel, .amber): hex = (1.00, 0.82, 0.55)
        case (.pastel, .lime): hex = (0.70, 0.92, 0.58)
        case (.pastel, .azure): hex = (0.62, 0.78, 1.00)
        case (.pastel, .violet): hex = (0.78, 0.68, 1.00)
        case (.pastel, .aqua): hex = (0.62, 0.92, 0.88)

        case (.midnight, .red): hex = (0.72, 0.18, 0.32)
        case (.midnight, .amber): hex = (0.78, 0.48, 0.12)
        case (.midnight, .lime): hex = (0.22, 0.52, 0.28)
        case (.midnight, .azure): hex = (0.18, 0.32, 0.72)
        case (.midnight, .violet): hex = (0.38, 0.22, 0.62)
        case (.midnight, .aqua): hex = (0.12, 0.48, 0.48)
        }
        return UIColor(red: hex.0, green: hex.1, blue: hex.2, alpha: 1)
    }
    var swatches: [Color] {
        BubbleColor.allCases.map { Color(uiColor: uiColor($0)) }
    }
}

enum BubbleStyle: String, CaseIterable, Codable, Identifiable {
    case solid, matte, chrome
    var id: String { rawValue }
    var title: String {
        switch self {
        case .solid: return "Solid"
        case .matte: return "Matte"
        case .chrome: return "Chrome"
        }
    }
    var price: Int {
        switch self {
        case .solid: return 0
        case .matte: return 300
        case .chrome: return 500
        }
    }
}

enum PlayBackground: String, CaseIterable, Codable, Identifiable {
    case twilight, ocean, lava, candy, aurora, space
    var id: String { rawValue }
    var title: String {
        switch self {
        case .twilight: return "Twilight"
        case .ocean: return "Deep Tide"
        case .lava: return "Ember"
        case .candy: return "Cotton Sky"
        case .aurora: return "Aurora"
        case .space: return "Deep Space"
        }
    }
    var price: Int {
        switch self {
        case .twilight: return 0
        case .ocean, .lava, .candy: return 250
        case .aurora, .space: return 400
        }
    }
    var top: UIColor {
        switch self {
        case .twilight: return UIColor(red: 0.07, green: 0.09, blue: 0.18, alpha: 1)
        case .ocean: return UIColor(red: 0.02, green: 0.18, blue: 0.32, alpha: 1)
        case .lava: return UIColor(red: 0.28, green: 0.05, blue: 0.04, alpha: 1)
        case .candy: return UIColor(red: 0.28, green: 0.08, blue: 0.22, alpha: 1)
        case .aurora: return UIColor(red: 0.04, green: 0.16, blue: 0.14, alpha: 1)
        case .space: return UIColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 1)
        }
    }
    var bottom: UIColor {
        switch self {
        case .twilight: return UIColor(red: 0.03, green: 0.04, blue: 0.08, alpha: 1)
        case .ocean: return UIColor(red: 0.01, green: 0.05, blue: 0.12, alpha: 1)
        case .lava: return UIColor(red: 0.08, green: 0.02, blue: 0.02, alpha: 1)
        case .candy: return UIColor(red: 0.08, green: 0.03, blue: 0.10, alpha: 1)
        case .aurora: return UIColor(red: 0.02, green: 0.04, blue: 0.10, alpha: 1)
        case .space: return UIColor(red: 0.01, green: 0.01, blue: 0.04, alpha: 1)
        }
    }
}

enum BubblePack: String, CaseIterable, Identifiable {
    case pocket, pouch, bucket, chest, vault
    var id: String { "fun.bubbleme.bubbles.\(bubbles)" }
    var title: String {
        switch self {
        case .pocket: return "Pocket"
        case .pouch: return "Pouch"
        case .bucket: return "Bucket"
        case .chest: return "Chest"
        case .vault: return "Vault"
        }
    }
    var bubbles: Int {
        switch self {
        case .pocket: return 250
        case .pouch: return 800
        case .bucket: return 2_000
        case .chest: return 5_000
        case .vault: return 12_000
        }
    }
    var displayPrice: String {
        switch self {
        case .pocket: return "$0.99"
        case .pouch: return "$2.99"
        case .bucket: return "$4.99"
        case .chest: return "$9.99"
        case .vault: return "$19.99"
        }
    }
    var perHundred: String {
        let cents: Double
        switch self {
        case .pocket: cents = 99 / 2.5
        case .pouch: cents = 299 / 8.0
        case .bucket: cents = 499 / 20.0
        case .chest: cents = 999 / 50.0
        case .vault: cents = 1999 / 120.0
        }
        return String(format: "$%.2f / 100", cents / 100)
    }
}
