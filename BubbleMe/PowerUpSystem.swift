import Foundation

enum PowerUp: String, Codable {
    case bomb, fire, face
}

enum BattlePower: String, Codable {
    case zigzag, mirror, shuffle
}

struct Inventory: Codable {
    var bombs: Int
    var fireballs: Int
    var faceBalls: Int
}

final class PowerUpSystem {
    var loaded: PowerUp?
    var inventory: Inventory
    var battle = (zigzag: 1, mirror: 1, shuffle: 1)

    init(inventory: Inventory) {
        self.inventory = inventory
    }

    func toggle(_ power: PowerUp) {
        if loaded == power { loaded = nil; return }
        switch power {
        case .bomb where inventory.bombs > 0,
             .fire where inventory.fireballs > 0,
             .face where inventory.faceBalls > 0:
            loaded = power
        default:
            break
        }
    }

    func consume() -> PowerUp? {
        guard let p = loaded else { return nil }
        switch p {
        case .bomb: inventory.bombs = max(0, inventory.bombs - 1)
        case .fire: inventory.fireballs = max(0, inventory.fireballs - 1)
        case .face: inventory.faceBalls = max(0, inventory.faceBalls - 1)
        }
        loaded = nil
        return p
    }

    func award(forCombo n: Int) {
        if n >= 8 { inventory.faceBalls += 1 }
        else if n >= 6 { inventory.fireballs += 1 }
        else if n >= 4 { inventory.bombs += 1 }
    }
}
