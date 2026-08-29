import SpriteKit

/// Core match-3 bubble shooter. Aim, bounce, stick, pop, drop.
final class GameScene: SKScene {
    let board = Board()
    let powers: PowerUpSystem
    weak var profile: ProfileManager?
    var onHud: ((Int, Int, Int) -> Void)?

    private var shooter: SKNode!
    private var cannon: SKShapeNode!
    private var nextDot: SKShapeNode!
    private var currentColor: BubbleColor = .red
    private var nextColor: BubbleColor = .amber
    private var aimAngle: CGFloat = -.pi / 2
    private var lastAim: CGFloat = -.pi / 2
    private var trajectory = SKShapeNode()
    private var flying: SKShapeNode?
    private var score = 0
    private var shotsLeft = 24
    private var dropIn = 5
    private var pausedGame = false

    init(size: CGSize, inventory: Inventory) {
        self.powers = PowerUpSystem(inventory: inventory)
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.03, green: 0.04, blue: 0.08, alpha: 1)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:)") }

    override func didMove(to view: SKView) {
        Haptics.prepare()
        if childNode(withName: "shooter") != nil { return }

        shooter = SKNode()
        shooter.name = "shooter"
        shooter.position = CGPoint(x: size.width / 2, y: 108)
        addChild(shooter)

        cannon = SKShapeNode(circleOfRadius: HexGrid.radius + 3)
        cannon.fillColor = skColor(currentColor)
        cannon.strokeColor = .white
        cannon.lineWidth = 2
        shooter.addChild(cannon)

        nextDot = SKShapeNode(circleOfRadius: 9)
        nextDot.fillColor = skColor(nextColor)
        nextDot.strokeColor = SKColor.white.withAlphaComponent(0.5)
        nextDot.position = CGPoint(x: 42, y: -6)
        shooter.addChild(nextDot)

        trajectory.strokeColor = SKColor.white.withAlphaComponent(0.75)
        trajectory.lineWidth = 2
        trajectory.glowWidth = 1
        addChild(trajectory)

        seedBoard()
        redrawBoard()
        onHud?(score, shotsLeft, dropIn)
    }

    func seedBoard() {
        let palette = Array(BubbleColor.allCases.prefix(4))
        for row in 0..<6 {
            for col in 0..<HexGrid.colCount(row) {
                _ = board.spawn(col: col, row: row, color: palette[(col + row * 2) % palette.count])
            }
        }
    }

    func loadPower(_ p: PowerUp) { powers.toggle(p) }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        aim(at: t.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        aim(at: t.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        fire()
        trajectory.path = nil
    }

    private func aim(at p: CGPoint) {
        let s = shooter.position
        var a = atan2(p.y - s.y, p.x - s.x)
        let minA = CGFloat(12) * .pi / 180
        a = min(max(a, minA), .pi - minA)
        aimAngle = a
        if abs(a - lastAim) > 0.05 {
            Haptics.aimTick()
            lastAim = a
        }
        drawPath()
    }

    private func drawPath() {
        var x = shooter.position.x
        var y = shooter.position.y + 20
        var vx = cos(aimAngle) * 8
        var vy = sin(aimAngle) * 8
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: y))
        for _ in 0..<90 {
            x += vx
            y += vy
            if x < 20 { x = 20; vx *= -1 }
            if x > size.width - 20 { x = size.width - 20; vx *= -1 }
            path.addLine(to: CGPoint(x: x, y: y))
            if y > size.height - 80 { break }
        }
        trajectory.path = path
    }

    private func fire() {
        guard flying == nil, !pausedGame else { return }
        let power = powers.consume()
        let node = SKShapeNode(circleOfRadius: HexGrid.radius)
        node.fillColor = skColor(currentColor)
        node.strokeColor = .white
        node.lineWidth = 1
        node.position = CGPoint(x: shooter.position.x, y: shooter.position.y + 24)
        node.userData = [
            "vx": NSNumber(value: Double(cos(aimAngle) * 780)),
            "vy": NSNumber(value: Double(sin(aimAngle) * 780)),
            "color": currentColor.rawValue,
            "power": power?.rawValue ?? "",
        ]
        addChild(node)
        flying = node
        shotsLeft -= 1
        dropIn -= 1
        Haptics.shoot()
        currentColor = nextColor
        nextColor = BubbleColor.allCases.randomElement() ?? .red
        cannon.fillColor = skColor(currentColor)
        nextDot.fillColor = skColor(nextColor)
        onHud?(score, shotsLeft, dropIn)
    }

    override func update(_ currentTime: TimeInterval) {
        guard let shot = flying else { return }
        let vx = CGFloat((shot.userData?["vx"] as? NSNumber)?.doubleValue ?? 0)
        let vy = CGFloat((shot.userData?["vy"] as? NSNumber)?.doubleValue ?? 0)
        shot.position.x += vx / 60
        shot.position.y += vy / 60
        if shot.position.x < 20 {
            shot.userData?["vx"] = NSNumber(value: Double(-vx))
            shot.position.x = 20
        }
        if shot.position.x > size.width - 20 {
            shot.userData?["vx"] = NSNumber(value: Double(-vx))
            shot.position.x = size.width - 20
        }
        let power = shot.userData?["power"] as? String ?? ""
        if power == "fire" {
            if let hit = bubble(at: shot.position) {
                pop([hit], kind: .fire)
            }
            if shot.position.y > size.height - 40 {
                shot.removeFromParent()
                flying = nil
            }
            return
        }
        if let hit = bubble(at: shot.position) ?? (shot.position.y > size.height - 70 ? nearest(to: shot.position) : nil) {
            land(shot, near: hit)
        }
    }

    private func land(_ shot: SKShapeNode, near hit: GridBubble?) {
        shot.removeFromParent()
        flying = nil
        let color = BubbleColor(rawValue: shot.userData?["color"] as? String ?? "red") ?? .red
        let power = shot.userData?["power"] as? String ?? ""
        guard let cell = emptyNeighbor(of: hit, near: shot.position) else { return }
        if power == "bomb" {
            Haptics.bomb()
            let victims = board.all().filter { abs($0.col - cell.col) + abs($0.row - cell.row) <= 2 }
            pop(victims, kind: .bomb)
            return
        }
        if power == "face", let hit {
            Haptics.face()
            pop(board.all().filter { $0.color == hit.color }, kind: .face)
            return
        }
        guard let placed = board.spawn(col: cell.col, row: cell.row, color: color) else { return }
        let cluster = board.cluster(fromCol: placed.col, row: placed.row)
        if cluster.count >= 3 {
            pop(cluster, kind: .pop)
        } else {
            redrawBoard()
        }
    }

    private enum PopKind { case pop, bomb, fire, face }

    private func pop(_ bubbles: [GridBubble], kind: PopKind) {
        switch kind {
        case .pop: Haptics.pop()
        case .bomb: Haptics.bomb()
        case .fire: Haptics.fire()
        case .face: Haptics.face()
        }
        score += bubbles.count * 10
        burst(at: bubbles)
        for b in bubbles { _ = board.remove(col: b.col, row: b.row) }
        let dropped = board.floating()
        if !dropped.isEmpty {
            Haptics.drop()
            score += dropped.count * 20
            for b in dropped { _ = board.remove(col: b.col, row: b.row) }
        }
        powers.award(forCombo: bubbles.count + dropped.count)
        redrawBoard()
        onHud?(score, shotsLeft, dropIn)
        if board.all().isEmpty { Haptics.win() }
    }

    private func burst(at bubbles: [GridBubble]) {
        let ox = (size.width - CGFloat(HexGrid.cols) * HexGrid.diameter) / 2
        for b in bubbles.prefix(18) {
            let spark = SKShapeNode(circleOfRadius: 4)
            spark.fillColor = skColor(b.color)
            spark.strokeColor = .clear
            let xOff: CGFloat = b.row % 2 == 1 ? HexGrid.radius : 0
            spark.position = CGPoint(
                x: ox + CGFloat(b.col) * HexGrid.diameter + HexGrid.radius + xOff,
                y: size.height - 80 - CGFloat(b.row) * HexGrid.rowH
            )
            addChild(spark)
            spark.run(.sequence([
                .group([
                    .scale(to: 2.2, duration: 0.22),
                    .fadeOut(withDuration: 0.22),
                ]),
                .removeFromParent(),
            ]))
        }
    }

    private func redrawBoard() {
        enumerateChildNodes(withName: "cell") { n, _ in n.removeFromParent() }
        let ox = (size.width - CGFloat(HexGrid.cols) * HexGrid.diameter) / 2
        for b in board.all() {
            let node = SKShapeNode(circleOfRadius: HexGrid.radius - 0.5)
            node.name = "cell"
            node.fillColor = skColor(b.color)
            node.strokeColor = SKColor.white.withAlphaComponent(0.35)
            node.lineWidth = 1
            let xOff: CGFloat = b.row % 2 == 1 ? HexGrid.radius : 0
            node.position = CGPoint(
                x: ox + CGFloat(b.col) * HexGrid.diameter + HexGrid.radius + xOff,
                y: size.height - 80 - CGFloat(b.row) * HexGrid.rowH
            )
            addChild(node)
        }
    }

    private func skColor(_ c: BubbleColor) -> SKColor {
        switch c {
        case .red: return SKColor(red: 1, green: 0.35, blue: 0.48, alpha: 1)
        case .amber: return SKColor(red: 1, green: 0.69, blue: 0.13, alpha: 1)
        case .lime: return SKColor(red: 0.35, green: 0.84, blue: 0.29, alpha: 1)
        case .azure: return SKColor(red: 0.23, green: 0.63, blue: 1, alpha: 1)
        case .violet: return SKColor(red: 0.61, green: 0.42, blue: 1, alpha: 1)
        case .aqua: return SKColor(red: 0.18, green: 0.90, blue: 0.77, alpha: 1)
        }
    }

    private func bubble(at p: CGPoint) -> GridBubble? {
        let ox = (size.width - CGFloat(HexGrid.cols) * HexGrid.diameter) / 2
        for b in board.all() {
            let xOff: CGFloat = b.row % 2 == 1 ? HexGrid.radius : 0
            let x = ox + CGFloat(b.col) * HexGrid.diameter + HexGrid.radius + xOff
            let y = size.height - 80 - CGFloat(b.row) * HexGrid.rowH
            if hypot(p.x - x, p.y - y) < HexGrid.diameter * 0.9 { return b }
        }
        return nil
    }

    private func nearest(to p: CGPoint) -> GridBubble? {
        let ox = (size.width - CGFloat(HexGrid.cols) * HexGrid.diameter) / 2
        return board.all().min { a, b in
            func pos(_ g: GridBubble) -> CGPoint {
                let xOff: CGFloat = g.row % 2 == 1 ? HexGrid.radius : 0
                return CGPoint(
                    x: ox + CGFloat(g.col) * HexGrid.diameter + HexGrid.radius + xOff,
                    y: size.height - 80 - CGFloat(g.row) * HexGrid.rowH
                )
            }
            let pa = pos(a), pb = pos(b)
            return hypot(p.x - pa.x, p.y - pa.y) < hypot(p.x - pb.x, p.y - pb.y)
        }
    }

    private func emptyNeighbor(of hit: GridBubble?, near p: CGPoint) -> (col: Int, row: Int)? {
        if let hit {
            let options = HexGrid.neighbors(col: hit.col, row: hit.row)
                .filter { board.get(col: $0.0, row: $0.1) == nil && board.inBounds(col: $0.0, row: $0.1) }
            if let best = options.first { return (best.0, best.1) }
        }
        return (HexGrid.cols / 2, 0)
    }
}
