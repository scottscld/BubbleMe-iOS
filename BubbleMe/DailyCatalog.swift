import Foundation

/// 90 unique Daily boards. Index rotates by calendar day (Chicago).
enum DailyCatalog {
    static let count = 90

    static func index(from now: Date = .now) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = ArcadeWeek.timeZone
        let day = cal.ordinality(of: .day, in: .era, for: now) ?? 1
        return ((day % count) + count) % count
    }

    static func info(_ now: Date = .now) -> LevelInfo {
        let i = index(from: now)
        let id = i + 1
        let colors: [BubbleColor] = Array(BubbleColor.allCases.prefix(3 + (i % 4)))
        let goal: LevelGoal
        switch i % 9 {
        case 0: goal = .clear
        case 1: goal = .score(400 + i * 12)
        case 2: goal = .popColor(colors[0], 10 + i / 8)
        case 3: goal = .waves(2 + (i % 3))
        case 4: goal = .noPowers
        case 5: goal = .wipeColor(colors[0])
        case 6: goal = .popCount(20 + i / 3)
        case 7: goal = .combo(3 + (i % 3))
        default: goal = .clear
        }
        return LevelInfo(
            id: id,
            name: "Daily \(id)/\(count)",
            goal: goal.label,
            pack: 0,
            objective: goal,
            rows: min(8, 4 + i / 18),
            shotLimit: goal.shotLimit(base: 22),
            parShots: 12 + i / 10,
            seed: 4100 + i * 97
        )
    }
}

struct RunSnapshot: Codable {
    var mode: String
    var levelId: Int
    var seed: Int
    var score: Int
    var shots: Int
    var wave: Int
    var dropIn: Int
    var dropIndex: Int
    var current: String
    var next: String
    var bubbles: [GridBubble]
    var bombs: Int
    var fire: Int
    var face: Int
    var zigzag: Int
    var mirror: Int
    var shuffle: Int
    var colorCleared: Int
    var popped: Int
    var maxCombo: Int
    var powersUsed: Int
    var targetColor: String?
}
