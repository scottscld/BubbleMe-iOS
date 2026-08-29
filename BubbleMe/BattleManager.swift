import Foundation

protocol BattleSyncing: AnyObject {
    func sendShot(angle: Double, color: String, power: String?)
    func sendPower(_ power: BattlePower)
    func onOpponentShot(_ handler: @escaping (Double, String, String?) -> Void)
    func onOpponentPower(_ handler: @escaping (BattlePower) -> Void)
}

/// Local / CPU stand-in. Swap this type for a Supabase realtime implementation later.
final class BattleManager: BattleSyncing {
    var seed: Int
    var opponentScore = 0
    private var shotHandler: ((Double, String, String?) -> Void)?
    private var powerHandler: ((BattlePower) -> Void)?

    init(seed: Int) {
        self.seed = seed
    }

    func sendShot(angle: Double, color: String, power: String?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            self.shotHandler?(angle + Double.random(in: -0.15...0.15), color, nil)
        }
    }

    func sendPower(_ power: BattlePower) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.powerHandler?(power)
        }
    }

    func onOpponentShot(_ handler: @escaping (Double, String, String?) -> Void) {
        shotHandler = handler
    }

    func onOpponentPower(_ handler: @escaping (BattlePower) -> Void) {
        powerHandler = handler
    }
}
