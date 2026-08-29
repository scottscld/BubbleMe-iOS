import SpriteKit

enum PlayMode { case arcade, level, battle }

/// Core match-3 bubble shooter. Aim, bounce, stick, pop, drop.
final class GameScene: SKScene {
    let board = Board()
    let powers: PowerUpSystem
    weak var profile: ProfileManager?
    var onHud: ((Int, Int, Int) -> Void)?
    var onWin: (() -> Void)?
    var onLose: (() -> Void)?
    var mode: PlayMode = .arcade
    var levelId = 1
    var seed: Int = 1
    var wave = 1

    private var shooter: SKNode!
    private var cannon: SKSpriteNode!
    private var nextDot: SKSpriteNode!
    private var currentColor: BubbleColor = .red
    private var nextColor: BubbleColor = .amber
    private var aimAngle: CGFloat = -.pi / 2
    private var lastAim: CGFloat = -.pi / 2
    private var trajectory = SKShapeNode()
    private var flying: SKSpriteNode?
    private var score = 0
    private var shotsLeft = 24
    private var dropIn = 5
    private var dropIndex = 0
    private var pausedGame = false
    private var won = false
    private var lost = false
    private var skipNextDrop = false
    private var cancelAim = false
    private var dangerY: CGFloat = 248
    private var rng: RNG = RNG(seed: 1)

    init(size: CGSize, inventory: Inventory, seed: Int, mode: PlayMode, levelId: Int) {
        self.powers = PowerUpSystem(inventory: inventory)
        self.seed = seed
        self.mode = mode
        self.levelId = levelId
        self.rng = RNG(seed: seed)
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.03, green: 0.04, blue: 0.08, alpha: 1)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:)") }

    override func didMove(to view: SKView) {
        Haptics.prepare()
        if childNode(withName: "shooter") != nil { return }
        addBackdrop()
        shooter = SKNode()
        shooter.name = "shooter"
        // Sit well above the Bubble Bag so the cannon isn't mixed with power-ups.
        shooter.position = CGPoint(x: size.width / 2, y: 196)
        dangerY = shooter.position.y + 58
        addChild(shooter)
        addDangerLine()

        let d = HexGrid.diameter
        cannon = BubbleArt.sprite(color: currentColor, diameter: d + 8, name: "cannon")
        shooter.addChild(cannon)
        if let photo = profile?.photo {
            cannon.texture = SKTexture(image: BubbleArt.render(color: BubbleArt.uiColor(currentColor), size: (d + 8) * UIScreen.main.scale, photo: photo))
        }

        nextDot = BubbleArt.sprite(color: nextColor, diameter: 20, name: "next")
        nextDot.position = CGPoint(x: 46, y: -8)
        shooter.addChild(nextDot)

        trajectory.lineWidth = 3
        trajectory.glowWidth = 5
        trajectory.lineCap = .round
        trajectory.zPosition = 8
        addChild(trajectory)

        let hint = SKLabelNode(fontNamed: "AvenirNext-Bold")
        hint.name = "cancelHint"
        hint.text = "Release to cancel"
        hint.fontSize = 13
        hint.fontColor = SKColor(red: 1, green: 0.35, blue: 0.48, alpha: 1)
        hint.position = CGPoint(x: size.width / 2, y: shooter.position.y - 36)
        hint.alpha = 0
        hint.zPosition = 12
        addChild(hint)

        seedBoard(wave: 1)
        redrawBoard()
        onHud?(score, shotsLeft, dropIn)
    }

    func seedBoard(wave: Int) {
        self.wave = wave
        board.clear()
        let colors = min(6, 4 + (wave - 1) / 2 + (mode == .level ? levelId / 80 : 0))
        let palette = Array(BubbleColor.allCases.prefix(max(3, colors)))
        let rows = min(8, 5 + wave / 2 + (mode == .level ? (levelId / 100) : 0))
        rng = RNG(seed: seed &+ wave &* 9973)
        for row in 0..<rows {
            for col in 0..<HexGrid.colCount(row) {
                if mode == .level, levelId % 7 == 0, row > 0, row < rows - 1, col > 0, col < HexGrid.colCount(row) - 1, rng.next() % 4 == 0 {
                    continue
                }
                let color = palette[Int(rng.next() % UInt64(palette.count))]
                _ = board.spawn(col: col, row: row, color: color)
            }
        }
    }

    func loadPower(_ p: PowerUp) { powers.toggle(p) }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard flying == nil, !pausedGame, !won, !lost, let t = touches.first else { return }
        cancelAim = false
        aim(at: t.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard flying == nil, !pausedGame, !won, !lost, let t = touches.first else { return }
        let p = t.location(in: self)
        // Slide down past the shooter to cancel.
        if p.y < shooter.position.y - 6 {
            cancelAim = true
            clearAimDots()
            trajectory.path = nil
            childNode(withName: "cancelHint")?.alpha = 1
            Haptics.aimTick()
            return
        }
        cancelAim = false
        childNode(withName: "cancelHint")?.alpha = 0
        aim(at: p)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        childNode(withName: "cancelHint")?.alpha = 0
        if cancelAim {
            cancelAim = false
            clearAimDots()
            trajectory.path = nil
            return
        }
        fire()
        clearAimDots()
        trajectory.path = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelAim = false
        childNode(withName: "cancelHint")?.alpha = 0
        clearAimDots()
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
        clearAimDots()
        var x = shooter.position.x
        var y = shooter.position.y + 22
        var vx = cos(aimAngle) * 8
        var vy = sin(aimAngle) * 8
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: y))
        var target: GridBubble?
        var i = 0
        while i < 110 {
            x += vx
            y += vy
            i += 1
            if x < 22 { x = 22; vx *= -1 }
            if x > size.width - 22 { x = size.width - 22; vx *= -1 }
            path.addLine(to: CGPoint(x: x, y: y))
            if y > size.height - 80 { break }
            if let hit = bubble(at: CGPoint(x: x, y: y)) {
                target = hit
                break
            }
        }
        // Face Ball previews the color it would wipe.
        let hue: UIColor
        if powers.loaded == .face, let target {
            hue = BubbleArt.uiColor(target.color)
        } else if powers.loaded == .face {
            hue = UIColor.white
        } else {
            hue = BubbleArt.uiColor(currentColor)
        }
        trajectory.strokeColor = hue.withAlphaComponent(0.9)
        trajectory.path = path
        var px = shooter.position.x
        var py = shooter.position.y + 22
        var pvx = cos(aimAngle) * 8
        var pvy = sin(aimAngle) * 8
        for j in 1...i {
            px += pvx
            py += pvy
            if px < 22 { px = 22; pvx *= -1 }
            if px > size.width - 22 { px = size.width - 22; pvx *= -1 }
            if j % 3 != 0 { continue }
            let t = CGFloat(j) / 110
            let dot = SKShapeNode(circleOfRadius: max(1.4, 3.1 - t * 1.4))
            dot.fillColor = hue.withAlphaComponent(0.85 * (1 - t * 0.45))
            dot.strokeColor = .clear
            dot.name = "aimdot"
            dot.zPosition = 8
            dot.position = CGPoint(x: px, y: py)
            addChild(dot)
        }
    }

    private func clearAimDots() {
        enumerateChildNodes(withName: "aimdot") { n, _ in n.removeFromParent() }
    }

    private func fire() {
        guard flying == nil, !pausedGame, !won, !lost else { return }
        if mode != .arcade, shotsLeft <= 0 { return }
        let power = powers.consume()
        let node = BubbleArt.sprite(color: currentColor, diameter: HexGrid.diameter, name: "shot")
        node.position = CGPoint(x: shooter.position.x, y: shooter.position.y + 26)
        node.zPosition = 9
        node.userData = [
            "vx": NSNumber(value: Double(cos(aimAngle) * 780)),
            "vy": NSNumber(value: Double(sin(aimAngle) * 780)),
            "color": currentColor.rawValue,
            "power": power?.rawValue ?? "",
        ]
        addChild(node)
        flying = node
        if mode != .arcade { shotsLeft -= 1 }
        Haptics.shoot()
        currentColor = nextColor
        nextColor = BubbleColor.allCases[Int(rng.next() % 6)]
        cannon.texture = BubbleArt.texture(for: currentColor, diameter: (HexGrid.diameter + 8) * UIScreen.main.scale)
        nextDot.texture = BubbleArt.texture(for: nextColor, diameter: 20 * UIScreen.main.scale)
        onHud?(score, shotsLeft, dropIn)
    }

    override func update(_ currentTime: TimeInterval) {
        guard let shot = flying else { return }
        let n = 8
        let wall = HexGrid.radius + 4
        for _ in 0..<n {
            var vx = CGFloat((shot.userData?["vx"] as? NSNumber)?.doubleValue ?? 0)
            var vy = CGFloat((shot.userData?["vy"] as? NSNumber)?.doubleValue ?? 0)
            let speed = hypot(vx, vy)
            guard speed > 0 else { return }
            let hunk = (speed / 60) / CGFloat(n)
            shot.position.x += (vx / speed) * hunk
            shot.position.y += (vy / speed) * hunk
            if shot.position.x < wall {
                shot.userData?["vx"] = NSNumber(value: Double(abs(vx)))
                shot.position.x = wall
            } else if shot.position.x > size.width - wall {
                shot.userData?["vx"] = NSNumber(value: Double(-abs(vx)))
                shot.position.x = size.width - wall
            }
            let power = shot.userData?["power"] as? String ?? ""
            if power == "fire" {
                if let hit = bubble(at: shot.position) {
                    pop([hit], kind: .fire)
                }
                if shot.position.y > size.height - 40 {
                    shot.removeFromParent()
                    flying = nil
                    finishShot()
                    return
                }
                continue
            }
            let hit = bubble(at: shot.position)
            let atCeil = shot.position.y > size.height - 70
            if hit != nil || atCeil {
                land(shot, near: hit ?? (atCeil ? nearest(to: shot.position) : nil))
                return
            }
        }
    }

    private func land(_ shot: SKSpriteNode, near hit: GridBubble?) {
        let pos = shot.position
        shot.removeFromParent()
        flying = nil
        let color = BubbleColor(rawValue: shot.userData?["color"] as? String ?? "red") ?? .red
        let power = shot.userData?["power"] as? String ?? ""
        guard let cell = nearestEmptyCell(hit: hit, near: pos) else {
            finishShot()
            return
        }
        if power == "bomb" {
            Haptics.bomb()
            let victims = board.all().filter { abs($0.col - cell.col) + abs($0.row - cell.row) <= 2 }
            pop(victims, kind: .bomb)
            finishShot()
            checkLose()
            return
        }
        if power == "face" {
            Haptics.face()
            let wipe = hit?.color ?? board.get(col: cell.col, row: cell.row)?.color
            if let wipe {
                pop(board.all().filter { $0.color == wipe }, kind: .face)
            }
            finishShot()
            checkLose()
            return
        }
        if let placed = board.spawn(col: cell.col, row: cell.row, color: color) {
            let cluster = board.cluster(fromCol: placed.col, row: placed.row)
            if cluster.count >= 3 {
                pop(cluster, kind: .pop)
            } else {
                redrawBoard()
            }
        }
        finishShot()
        checkLose()
    }

    /// Ceiling only drops after the shot is done — never while a bubble is in the air.
    private func finishShot() {
        if skipNextDrop {
            skipNextDrop = false
            onHud?(score, shotsLeft, dropIn)
            return
        }
        dropIn -= 1
        if dropIn <= 0 {
            dropIn = max(3, 6 - wave)
            applyCeilingDrop()
        }
        onHud?(score, shotsLeft, dropIn)
        if mode != .arcade, shotsLeft <= 0, !won, !lost {
            triggerLose()
        }
        checkLose()
    }

    private enum PopKind { case pop, bomb, fire, face }

    private func pop(_ bubbles: [GridBubble], kind: PopKind) {
        switch kind {
        case .pop: Haptics.pop()
        case .bomb: Haptics.bomb()
        case .fire: Haptics.fire()
        case .face: Haptics.face()
        }
        let mul = mode == .arcade ? wave : 1
        score += bubbles.count * 10 * mul
        burst(at: bubbles)
        for b in bubbles { _ = board.remove(col: b.col, row: b.row) }
        let dropped = board.floating()
        if !dropped.isEmpty {
            Haptics.drop()
            score += dropped.count * 20 * mul
            for b in dropped { _ = board.remove(col: b.col, row: b.row) }
        }
        powers.award(forCombo: bubbles.count + dropped.count)
        redrawBoard()
        onHud?(score, shotsLeft, dropIn)
        if board.all().isEmpty {
            if mode == .arcade {
                wave += 1
                seedBoard(wave: wave)
                dropIn = max(3, 6 - wave)
                skipNextDrop = true
                redrawBoard()
                Haptics.win()
            } else {
                won = true
                Haptics.win()
                onWin?()
            }
        }
    }

    private func applyCeilingDrop() {
        _ = board.shiftDown()
        dropIndex += 1
        var rowRng = RNG(seed: seed &+ wave &* 7919 &+ dropIndex &* 131)
        let colors = min(6, 4 + (wave - 1) / 2)
        let palette = Array(BubbleColor.allCases.prefix(max(3, colors)))
        for col in 0..<HexGrid.colCount(0) {
            if board.get(col: col, row: 0) == nil {
                let color = palette[Int(rowRng.next() % UInt64(palette.count))]
                _ = board.spawn(col: col, row: 0, color: color)
            }
        }
        redrawBoard()
        checkLose()
    }

    private func checkLose() {
        guard !won, !lost else { return }
        for b in board.all() {
            if position(of: b).y - HexGrid.radius <= dangerY {
                triggerLose()
                return
            }
        }
    }

    private func triggerLose() {
        guard !lost, !won else { return }
        lost = true
        pausedGame = true
        Haptics.lose()
        onLose?()
    }

    private func burst(at bubbles: [GridBubble]) {
        for b in bubbles.prefix(18) {
            let spark = BubbleArt.sprite(color: b.color, diameter: 10, name: "spark")
            spark.position = position(of: b)
            addChild(spark)
            spark.run(.sequence([
                .group([.scale(to: 2.4, duration: 0.22), .fadeOut(withDuration: 0.22)]),
                .removeFromParent(),
            ]))
        }
    }

    private func redrawBoard() {
        enumerateChildNodes(withName: "cell") { n, _ in n.removeFromParent() }
        for b in board.all() {
            let node = BubbleArt.sprite(color: b.color, diameter: HexGrid.diameter - 1)
            node.position = position(of: b)
            addChild(node)
        }
    }

    private func position(of b: GridBubble) -> CGPoint {
        position(ofCol: b.col, row: b.row)
    }

    private func position(ofCol col: Int, row: Int) -> CGPoint {
        let ox = (size.width - CGFloat(HexGrid.cols) * HexGrid.diameter) / 2
        let xOff: CGFloat = row % 2 == 1 ? HexGrid.radius : 0
        return CGPoint(
            x: ox + CGFloat(col) * HexGrid.diameter + HexGrid.radius + xOff,
            y: size.height - 88 - CGFloat(row) * HexGrid.rowH
        )
    }

    private func bubble(at p: CGPoint) -> GridBubble? {
        for b in board.all() {
            let pos = position(of: b)
            if hypot(p.x - pos.x, p.y - pos.y) < HexGrid.diameter * 0.88 { return b }
        }
        return nil
    }

    private func nearest(to p: CGPoint) -> GridBubble? {
        board.all().min { a, b in
            let pa = position(of: a), pb = position(of: b)
            return hypot(p.x - pa.x, p.y - pa.y) < hypot(p.x - pb.x, p.y - pb.y)
        }
    }

    /// Web-style landing: neighbors of the hit, then any empty neighbor of the board, then any empty cell.
    private func nearestEmptyCell(hit: GridBubble?, near p: CGPoint) -> (col: Int, row: Int)? {
        var candidates: [(Int, Int, CGFloat)] = []
        func consider(_ c: Int, _ r: Int) {
            guard board.inBounds(col: c, row: r), board.get(col: c, row: r) == nil else { return }
            let pos = position(ofCol: c, row: r)
            candidates.append((c, r, hypot(p.x - pos.x, p.y - pos.y)))
        }
        if let hit {
            for n in HexGrid.neighbors(col: hit.col, row: hit.row) { consider(n.0, n.1) }
        }
        if p.y > size.height - 120 {
            for c in 0..<HexGrid.colCount(0) { consider(c, 0) }
        }
        if candidates.isEmpty {
            for b in board.all() {
                for n in HexGrid.neighbors(col: b.col, row: b.row) { consider(n.0, n.1) }
            }
        }
        if candidates.isEmpty {
            for r in 0..<board.maxRows {
                for c in 0..<HexGrid.colCount(r) { consider(c, r) }
            }
        }
        return candidates.min(by: { $0.2 < $1.2 }).map { ($0.0, $0.1) }
    }

    private func addDangerLine() {
        let path = CGMutablePath()
        var x: CGFloat = 16
        while x < size.width - 16 {
            path.move(to: CGPoint(x: x, y: dangerY))
            path.addLine(to: CGPoint(x: min(x + 7, size.width - 16), y: dangerY))
            x += 14
        }
        let line = SKShapeNode(path: path)
        line.strokeColor = SKColor(red: 1, green: 0.35, blue: 0.48, alpha: 0.85)
        line.lineWidth = 1.6
        line.glowWidth = 1
        line.zPosition = 6
        line.name = "danger"
        addChild(line)
        line.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.35, duration: 0.7),
            .fadeAlpha(to: 0.9, duration: 0.7),
        ])))
        let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
        label.text = "danger"
        label.fontSize = 9
        label.fontColor = SKColor(red: 1, green: 0.35, blue: 0.48, alpha: 0.7)
        label.position = CGPoint(x: 36, y: dangerY + 6)
        label.zPosition = 6
        addChild(label)
    }

    private func addBackdrop() {
        if let img = UIImage(named: "Twilight") {
            let bg = SKSpriteNode(texture: SKTexture(image: img))
            bg.size = size
            bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
            bg.zPosition = -20
            bg.alpha = 0.55
            addChild(bg)
        }
        let dim = SKSpriteNode(color: SKColor(red: 0.03, green: 0.04, blue: 0.08, alpha: 0.45), size: size)
        dim.position = CGPoint(x: size.width / 2, y: size.height / 2)
        dim.zPosition = -19
        addChild(dim)
        for _ in 0..<40 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.6...1.6))
            star.fillColor = .white
            star.strokeColor = .clear
            star.alpha = CGFloat.random(in: 0.25...0.8)
            star.position = CGPoint(x: .random(in: 0...size.width), y: .random(in: 0...size.height))
            star.zPosition = -18
            addChild(star)
            star.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.15, duration: Double.random(in: 0.8...1.8)),
                .fadeAlpha(to: 0.85, duration: Double.random(in: 0.8...1.8)),
            ])))
        }
    }
}

struct RNG {
    private var state: UInt64
    init(seed: Int) { state = UInt64(truncatingIfNeeded: seed) | 1 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
