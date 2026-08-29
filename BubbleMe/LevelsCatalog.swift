import Foundation

struct LevelPack: Identifiable {
    let id: Int
    let name: String
    let blurb: String
}

enum LevelGoal: Equatable {
    case clear
    case score(Int)
    case popColor(BubbleColor, Int)
    case wipeColor(BubbleColor)
    case waves(Int)
    case noPowers
    case popCount(Int)
    case combo(Int)

    var label: String {
        switch self {
        case .clear: return "Clear the board"
        case .score(let n): return "Score \(n)"
        case .popColor(let c, let n): return "Pop \(n) \(c.rawValue)"
        case .wipeColor(let c): return "Clear all \(c.rawValue)"
        case .waves(let n): return "Reach wave \(n)"
        case .noPowers: return "Clear — no powers"
        case .popCount(let n): return "Pop \(n) bubbles"
        case .combo(let n): return "Land a \(n)-combo"
        }
    }

    func shotLimit(base: Int) -> Int {
        switch self {
        case .waves(let n): return base + n * 10
        case .noPowers: return max(12, base - 4)
        case .score: return base + 8
        case .popCount: return base + 6
        default: return base
        }
    }
}

struct LevelInfo: Identifiable {
    let id: Int
    let name: String
    let goal: String
    let pack: Int
    var objective: LevelGoal = .clear
    var rows: Int = 5
    var shotLimit: Int = 24
    var parShots: Int = 14
    var seed: Int = 1
}

enum LevelsCatalog {
    static let count = 500
    static let packSize = 25

    static let packs: [LevelPack] = [
        .init(id: 0, name: "First Cluster", blurb: "Learn the pop"),
        .init(id: 1, name: "Score Chase", blurb: "Hit the number"),
        .init(id: 2, name: "Color Hunt", blurb: "Pop a chosen hue"),
        .init(id: 3, name: "Wave Breakers", blurb: "Clear board after board"),
        .init(id: 4, name: "Clean Shots", blurb: "No powers allowed"),
        .init(id: 5, name: "Color Wipe", blurb: "Erase a whole color"),
        .init(id: 6, name: "Shape Shift", blurb: "Wild board layouts"),
        .init(id: 7, name: "Pop Count", blurb: "Rack up pops"),
        .init(id: 8, name: "Combo Lab", blurb: "String clusters together"),
        .init(id: 9, name: "Deep Waves", blurb: "Ride further"),
        .init(id: 10, name: "Ceiling Pressure", blurb: "The roof drops faster"),
        .init(id: 11, name: "Tight Angles", blurb: "Few shots, no powers"),
        .init(id: 12, name: "Prism Field", blurb: "Six-color hunts"),
        .init(id: 13, name: "Mixed Signals", blurb: "Every objective"),
        .init(id: 14, name: "Tide Rush", blurb: "Longer wave runs"),
        .init(id: 15, name: "Hollow Boards", blurb: "Rings, frames, gaps"),
        .init(id: 16, name: "Chain Reaction", blurb: "Pops and combos"),
        .init(id: 17, name: "Wave Gauntlet", blurb: "Reach the late waves"),
        .init(id: 18, name: "No Mercy", blurb: "Clean shots, hard boards"),
        .init(id: 19, name: "Bubble Legend", blurb: "Everything at once"),
    ]

    private static let adj = [
        "First", "Bright", "Rapid", "Deep", "Twin", "Hollow", "Sharp", "Quiet", "Glass", "Neon",
        "Drift", "Pulse", "Cascade", "Ricochet", "Ceiling", "Crystal", "Orbit", "Tide", "Spark", "Lunar",
        "Swift", "Frozen", "Heavy", "Loose", "Prime",
    ]
    private static let noun = [
        "Pop", "Cluster", "Burst", "Drop", "Lane", "Ring", "Field", "Rush", "Wave", "Shot",
        "Chain", "Bloom", "Break", "Clear", "Bounce", "Arc", "Swarm", "Grid", "Peak", "Coil",
    ]

    static func packIndex(for level: Int) -> Int { (max(1, level) - 1) / packSize }

    static func info(_ id: Int) -> LevelInfo {
        let i = max(1, min(count, id))
        let pack = packIndex(for: i)
        let inPack = (i - 1) % packSize
        let colors = Array(BubbleColor.allCases.prefix(min(6, 3 + pack / 4)))
        let goal = objective(id: i, pack: pack, inPack: inPack, colors: colors)
        let rows = min(10, max(3, 3 + (i - 1) / 55 + (i <= 3 ? i - 1 : 0)))
        let baseShots = max(10, 30 - i / 28)
        return LevelInfo(
            id: i,
            name: "\(adj[(i - 1) % adj.count]) \(noun[((i - 1) / 25) % noun.count])",
            goal: goal.label,
            pack: pack,
            objective: goal,
            rows: { if case .waves = goal { return min(rows, 6) }; return rows }(),
            shotLimit: goal.shotLimit(base: baseShots),
            parShots: max(6, baseShots - 8 - pack / 4),
            seed: i * 997 + 13
        )
    }

    private static func objective(id: Int, pack: Int, inPack: Int, colors: [BubbleColor]) -> LevelGoal {
        if id <= 3 { return .clear }
        if id == 4 { return .score(500) }
        if id == 5 { return .popColor(colors[0], 8) }
        let types: [Int] = [0, 1, 2, 3, 4, 5, 6, 7]
        let t = types[(pack * 3 + inPack + id) % types.count]
        let c = colors[inPack % colors.count]
        switch t {
        case 1: return .score(420 + id * 8 + pack * 28)
        case 2: return .popColor(c, 8 + id / 12 + pack)
        case 3: return .wipeColor(colors[0])
        case 4: return .waves(min(8, (pack < 5 ? 2 : pack < 10 ? 3 : 4) + (inPack % 3 == 0 ? 1 : 0)))
        case 5: return .noPowers
        case 6: return .popCount(14 + id * 28 / 100 + pack * 2)
        case 7: return .combo(min(5, 2 + pack / 8 + (inPack % 4 == 0 ? 1 : 0)))
        default: return .clear
        }
    }

    static func levels(in pack: Int) -> [LevelInfo] {
        let start = pack * packSize + 1
        return (start..<(start + packSize)).map(info)
    }
}
