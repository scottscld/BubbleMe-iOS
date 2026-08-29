import Foundation
import SwiftUI

/// Saturday 00:00 America/Chicago → next Saturday. Countdown only — no date shown.
enum ArcadeWeek {
    static let timeZone = TimeZone(identifier: "America/Chicago")!

    static func weekStart(from now: Date = .now) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let weekday = cal.component(.weekday, from: now) // Sun=1 … Sat=7
        let daysSinceSaturday = weekday % 7
        let startOfDay = cal.startOfDay(for: now)
        return cal.date(byAdding: .day, value: -daysSinceSaturday, to: startOfDay) ?? startOfDay
    }

    static func nextReset(from now: Date = .now) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal.date(byAdding: .day, value: 7, to: weekStart(from: now)) ?? now
    }

    static func weekId(from now: Date = .now) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: weekStart(from: now))
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func dayId(from now: Date = .now) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func yesterdayId(from now: Date = .now) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let y = cal.date(byAdding: .day, value: -1, to: now) ?? now
        return dayId(from: y)
    }

    static func seed(from now: Date = .now) -> Int {
        var hash = 2166136261
        for b in weekId(from: now).utf8 {
            hash ^= Int(b)
            hash = hash &* 16777619
        }
        return abs(hash)
    }

    static func formatCountdown(until end: Date, now: Date) -> String {
        let total = max(0, Int(end.timeIntervalSince(now)))
        let d = total / 86400
        let h = (total % 86400) / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if d > 0 { return "\(d)d \(pad(h))h \(pad(m))m" }
        if h > 0 { return "\(h)h \(pad(m))m \(pad(s))s" }
        return "\(m)m \(pad(s))s"
    }

    private static func pad(_ n: Int) -> String { String(format: "%02d", n) }
}

struct BoardPlayer: Identifiable {
    let id: String
    let rank: Int
    let name: String
    let score: Int
    let wave: Int
    let you: Bool
    let tone: Color
}

enum WeeklyBoard {
    private static let bots: [(id: String, name: String, score: Int, wave: Int, tone: Color)] = [
        ("nova", "Nova", 18_400, 9, Color(red: 0.24, green: 0.84, blue: 0.55)),
        ("ripple", "Ripple", 15_120, 8, Color(red: 0.18, green: 0.90, blue: 0.77)),
        ("mango", "Mango", 12_880, 7, Color(red: 1, green: 0.69, blue: 0.13)),
        ("pixel", "Pixel", 9_340, 6, Color(red: 0.61, green: 0.42, blue: 1)),
        ("coral", "Coral", 7_120, 5, Color(red: 1, green: 0.35, blue: 0.48)),
    ]

    static func entries(player: String, score: Int, wave: Int) -> [BoardPlayer] {
        var rows: [(id: String, name: String, score: Int, wave: Int, you: Bool, tone: Color)] =
            bots.map { ($0.id, $0.name, $0.score, $0.wave, false, $0.tone) }
        if score > 0 {
            rows.append((
                "you",
                player.isEmpty ? "You" : player,
                score,
                max(1, wave),
                true,
                Color(red: 0.18, green: 0.90, blue: 0.77)
            ))
        }
        rows.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            return !a.you && b.you
        }
        return rows.enumerated().map { i, r in
            BoardPlayer(id: r.id, rank: i + 1, name: r.name, score: r.score, wave: r.wave, you: r.you, tone: r.tone)
        }
    }

    static func rank(player: String, score: Int, wave: Int) -> Int? {
        guard score > 0 else { return nil }
        return entries(player: player, score: score, wave: wave).first(where: \.you)?.rank
    }
}
