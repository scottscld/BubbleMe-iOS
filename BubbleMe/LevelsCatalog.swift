import Foundation

struct LevelPack: Identifiable {
    let id: Int
    let name: String
    let blurb: String
}

struct LevelInfo: Identifiable {
    let id: Int
    let name: String
    let goal: String
    let pack: Int
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
    private static let goals = [
        "Clear the board",
        "Reach the score",
        "Pop every red",
        "Reach wave 3",
        "No powers",
        "Wipe a color",
        "Clear the board",
        "Pop 40 bubbles",
        "Land a 6-combo",
        "Reach wave 4",
    ]

    static func packIndex(for level: Int) -> Int { (max(1, level) - 1) / packSize }

    static func info(_ id: Int) -> LevelInfo {
        let i = max(1, min(count, id))
        return LevelInfo(
            id: i,
            name: "\(adj[(i - 1) % adj.count]) \(noun[((i - 1) / 25) % noun.count])",
            goal: goals[(i - 1) % goals.count],
            pack: packIndex(for: i)
        )
    }

    static func levels(in pack: Int) -> [LevelInfo] {
        let start = pack * packSize + 1
        return (start..<(start + packSize)).map(info)
    }
}
