import Foundation

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
