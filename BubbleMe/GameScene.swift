import SpriteKit

enum PlayMode: String { case arcade, level, battle, daily }

/// Core match-3 bubble shooter. Aim, bounce, stick, pop, drop.
final class GameScene: SKScene {
    let board = Board()
    let powers: PowerUpSystem
    weak var profile: ProfileManager?
    var onHud: ((Int, Int, Int) -> Void)?
    var onWin: (() -> Void)?
    var onLose: (() -> Void)?
    var onWave: ((Int, Int) -> Void)?
    var onPickup: ((PowerUp) -> Void)?
    var onStars: ((Int) -> Void)?
    var onCpu: ((Int) -> Void)?
    var mode: PlayMode = .arcade
    var levelId = 1
    var seed: Int = 1
    var wave = 1
    var objective: LevelGoal = .clear
    var parShots = 14
    var stars = 0
    var cpuScore = 0
    private var colorCleared = 0
    private var popped = 0
    private var maxCombo = 0
    private var powersUsed = 0
    private var targetColor: BubbleColor?
    private var cpuBoard: Board?
    private var lastCPU: TimeInterval = 0
    private var incomingZigzag = 0
    private var incomingMirror = 0
    var pendingRestore: RunSnapshot?
    var vsFriend = false
    var cpuEnabled = true
    var opponentName = "CPU"
    var battleBanner: ((String) -> Void)?
    private var cpuZigzag = 0
    private var cpuMirror = 0
    private var cpuPowers = (zigzag: 1, mirror: 1, shuffle: 1)

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
        cannon = makeBubbleSprite(color: currentColor, diameter: d + 8, name: "cannon")
        shooter.addChild(cannon)
        refreshCannonSkin()
        mountBarrel()
        nextDot = makeBubbleSprite(color: nextColor, diameter: 20, name: "next")
        nextDot.position = CGPoint(x: 46, y: -8)
        shooter.addChild(nextDot)
        setLoadedBadge(nil)

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

        if mode == .level {
            let info = LevelsCatalog.info(levelId)
            objective = info.objective
            shotsLeft = info.shotLimit
            parShots = info.parShots
        } else if mode == .daily {
            let info = DailyCatalog.info()
            objective = info.objective
            shotsLeft = info.shotLimit
            parShots = info.parShots
        } else if mode == .arcade || mode == .battle {
            shotsLeft = 9999
        }
        seedBoard(wave: 1)
        if mode == .battle, cpuEnabled, !vsFriend { bootCPU() }
        if let snap = pendingRestore {
            restore(snap)
            pendingRestore = nil
        }
        redrawBoard()
        onHud?(score, shotsLeft, dropIn)
        AudioEngine.shared.start()
    }

    func seedBoard(wave: Int) {
        self.wave = wave
        board.clear()
        let colors = min(6, 4 + (wave - 1) / 2 + (mode == .level ? levelId / 80 : 0))
        let palette = Array(BubbleColor.allCases.prefix(max(3, colors)))
        let catalogRows: Int = {
            if mode == .daily { return DailyCatalog.info().rows }
            if mode == .level { return LevelsCatalog.info(levelId).rows }
            return min(8, 5 + wave / 2)
        }()
        let rows = catalogRows
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
        plantPickups(rows: rows, colors: palette)
    }

    private func plantPickups(rows: Int, colors: [BubbleColor]) {
        let kinds: [PowerUp] = [.bomb, .fire, .face]
        let n = min(3, 1 + wave / 3)
        var placed = 0
        var guardCount = 0
        while placed < n, guardCount < 40 {
            guardCount += 1
            let row = Int(rng.next() % UInt64(max(1, rows)))
            let col = Int(rng.next() % UInt64(HexGrid.colCount(row)))
            guard let b = board.get(col: col, row: row), b.pickup == nil else { continue }
            _ = board.remove(col: col, row: row)
            let kind = kinds[Int(rng.next() % 3)]
            _ = board.spawn(col: col, row: row, color: b.color, pickup: kind)
            placed += 1
        }
    }

    private var zigzagShots = 0
    private var mirrorAim = false

    func loadPower(_ p: PowerUp) {
        powers.toggle(p)
        setLoadedBadge(powers.loaded)
    }

    func useBattle(_ p: BattlePower) {
        switch p {
        case .zigzag where powers.battle.zigzag > 0:
            powers.battle.zigzag -= 1
            hurtCPU(.zigzag)
        case .mirror where powers.battle.mirror > 0:
            powers.battle.mirror -= 1
            hurtCPU(.mirror)
        case .shuffle where powers.battle.shuffle > 0:
            powers.battle.shuffle -= 1
            hurtCPU(.shuffle)
        default:
            break
        }
        AudioEngine.shared.load()
    }

    private func hurtCPU(_ p: BattlePower) {
        switch p {
        case .shuffle:
            guard let cpu = cpuBoard else { return }
            cpu.shuffleColors(&rng)
        case .zigzag:
            cpuZigzag = 8
        case .mirror:
            cpuMirror = 6
        }
        battleBanner?(p.rawValue.uppercased() + " on opponent")
    }

    func setLoadedBadge(_ power: PowerUp?) {
        shooter?.childNode(withName: "powerBadge")?.removeFromParent()
        guard let power, let shooter else { return }
        let label = SKLabelNode(text: power == .bomb ? "💣" : power == .fire ? "🔥" : "🙂")
        label.name = "powerBadge"
        label.fontSize = 22
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 18)
        label.zPosition = 12
        shooter.addChild(label)
    }

    private func makeBubbleSprite(color: BubbleColor, diameter: CGFloat, name: String) -> SKSpriteNode {
        BubbleArt.sprite(
            color: color,
            diameter: diameter,
            name: name,
            palette: profile?.palette ?? .classic,
            style: profile?.style ?? .solid
        )
    }

    private func refreshCannonSkin() {
        let d = HexGrid.diameter
        let pal = profile?.palette ?? .classic
        let st = profile?.style ?? .solid
        if let photo = profile?.photo {
            cannon.texture = SKTexture(image: BubbleArt.render(
                color: pal.uiColor(currentColor),
                size: (d + 8) * UIScreen.main.scale,
                photo: photo,
                style: st
            ))
        } else {
            cannon.texture = BubbleArt.texture(for: currentColor, diameter: (d + 8) * UIScreen.main.scale, palette: pal, style: st)
        }
    }

    private func mountBarrel() {
        shooter.childNode(withName: "barrel")?.removeFromParent()
        let kind = profile?.shooter ?? .cannon
        let barrel = BubbleArt.shooterNode(kind: kind, color: SKColor(cgColor: (profile?.palette ?? .classic).uiColor(currentColor).cgColor))
        barrel.zPosition = -1
        barrel.position = CGPoint(x: 0, y: -8)
        shooter.addChild(barrel)
    }

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
        if incomingMirror > 0 { a = .pi - a }
        aimAngle = a
        if abs(a - lastAim) > 0.05 {
            Haptics.aimTick()
            lastAim = a
        }
        drawPath()
    }

    private func drawPath() {
        clearAimDots()
        let wall = HexGrid.radius + 3
        var x = shooter.position.x
        var y = shooter.position.y + 22
        var vx = cos(aimAngle) * 8
        let vy = sin(aimAngle) * 8
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: y))
        var target: GridBubble?
        var i = 0
        while i < 110 {
            x += vx
            y += vy
            i += 1
            if x < wall { x = wall; vx *= -1 }
            if x > size.width - wall { x = size.width - wall; vx *= -1 }
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
        let pvy = sin(aimAngle) * 8
        for j in 1...i {
            px += pvx
            py += pvy
            if px < wall { px = wall; pvx *= -1 }
            if px > size.width - wall { px = size.width - wall; pvx *= -1 }
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
        if mode != .arcade && mode != .battle, shotsLeft <= 0 { return }
        if powers.loaded != nil, case .noPowers = objective {
            powersUsed += 1
            AudioEngine.shared.lose()
            triggerLose()
            return
        }
        var shootAngle = aimAngle
        if incomingZigzag > 0 {
            shootAngle += CGFloat.random(in: -0.35...0.35)
            incomingZigzag -= 1
        }
        if incomingMirror > 0 {
            incomingMirror -= 1
        }
        if mirrorAim {
            shootAngle = .pi - shootAngle
            mirrorAim = false
        }
        let power = powers.consume()
        if power != nil { powersUsed += 1 }
        let node = makeBubbleSprite(color: currentColor, diameter: HexGrid.diameter, name: "shot")
        node.position = CGPoint(x: shooter.position.x, y: shooter.position.y + 22)
        node.zPosition = 9
        node.userData = [
            "vx": NSNumber(value: Double(cos(shootAngle) * 780)),
            "vy": NSNumber(value: Double(sin(shootAngle) * 780)),
            "zigzag": NSNumber(value: zigzagShots > 0),
            "color": currentColor.rawValue,
            "power": power?.rawValue ?? "",
        ]
        addChild(node)
        flying = node
        if zigzagShots > 0 { zigzagShots -= 1 }
        if mode != .arcade && mode != .battle { shotsLeft -= 1 }
        AudioEngine.shared.shoot()
        Haptics.shoot()
        currentColor = nextColor
        nextColor = BubbleColor.allCases[Int(rng.next() % 6)]
        refreshCannonSkin()
        nextDot.texture = BubbleArt.texture(
            for: nextColor,
            diameter: 20 * UIScreen.main.scale,
            palette: profile?.palette ?? .classic,
            style: profile?.style ?? .solid
        )
        setLoadedBadge(nil)
        onHud?(score, shotsLeft, dropIn)
    }

    override func update(_ currentTime: TimeInterval) {
        if mode == .battle, cpuEnabled, !pausedGame, !won, !lost, flying == nil {
            if lastCPU == 0 { lastCPU = currentTime + 2.4 }
            else if currentTime - lastCPU > 3.2 {
                lastCPU = currentTime
                cpuAct()
            }
        }
        guard let shot = flying else { return }
        let n = 8
        let wall = HexGrid.radius + 3
        for _ in 0..<n {
            let vx = CGFloat((shot.userData?["vx"] as? NSNumber)?.doubleValue ?? 0)
            let vy = CGFloat((shot.userData?["vy"] as? NSNumber)?.doubleValue ?? 0)
            let speed = hypot(vx, vy)
            guard speed > 0 else { return }
            let hunk = (speed / 60) / CGFloat(n)
            shot.position.x += (vx / speed) * hunk
            shot.position.y += (vy / speed) * hunk
            if (shot.userData?["zigzag"] as? NSNumber)?.boolValue == true {
                shot.position.x += sin(shot.position.y / 14) * 2.2
            }
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
                    if let kind = hit.pickup {
                        collectPickup(hit, kind: kind)
                    } else {
                        pop([hit], kind: .fire)
                    }
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
        let vx = CGFloat((shot.userData?["vx"] as? NSNumber)?.doubleValue ?? 0)
        let vy = CGFloat((shot.userData?["vy"] as? NSNumber)?.doubleValue ?? 0)
        shot.removeFromParent()
        flying = nil
        let color = BubbleColor(rawValue: shot.userData?["color"] as? String ?? "red") ?? .red
        let power = shot.userData?["power"] as? String ?? ""
        if let hit, let kind = hit.pickup {
            collectPickup(hit, kind: kind)
            finishShot()
            checkLose()
            return
        }
        guard let cell = nearestEmptyCell(hit: hit, near: pos, vx: vx, vy: vy) else {
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
        if mode != .arcade && mode != .battle, shotsLeft <= 0, !won, !lost {
            triggerLose()
        }
        checkObjective()
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
        let pickups = bubbles.filter { $0.pickup != nil }
        let rest = bubbles.filter { $0.pickup == nil }
        for p in pickups {
            if let kind = p.pickup { collectPickup(p, kind: kind) }
        }
        let mul = mode == .arcade ? wave : 1
        score += rest.count * 10 * mul
        popped += rest.count
        maxCombo = max(maxCombo, rest.count)
        if case .popColor(let c, _) = objective {
            colorCleared += rest.filter { $0.color == c }.count
        }
        burst(at: rest)
        for b in rest { _ = board.remove(col: b.col, row: b.row) }
        AudioEngine.shared.pop()
        var dropped: [GridBubble] = []
        for _ in 0..<6 {
            let batch = board.floating()
            if batch.isEmpty { break }
            for b in batch {
                _ = board.remove(col: b.col, row: b.row)
                dropped.append(b)
            }
        }
        if !dropped.isEmpty {
            Haptics.drop()
            score += dropped.count * 20 * mul
            for b in dropped { _ = board.remove(col: b.col, row: b.row) }
        }
        powers.award(forCombo: bubbles.count + dropped.count)
        redrawBoard()
        onHud?(score, shotsLeft, dropIn)
        if board.all().isEmpty {
            let waveGoal: Bool = { if case .waves = objective { return true }; return false }()
            if mode == .arcade || ((mode == .level || mode == .daily) && waveGoal) {
                if (mode == .level || mode == .daily), case .waves(let need) = objective, wave >= need {
                    triggerWin()
                    return
                }
                wave += 1
                seedBoard(wave: wave)
                dropIn = max(3, 6 - wave)
                skipNextDrop = true
                score += 80 * wave
                bubblesAward(8)
                redrawBoard()
                Haptics.win()
                AudioEngine.shared.combo(wave)
                onWave?(wave, score)
            } else if mode != .arcade {
                triggerWin()
            }
        }
        checkObjective()
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
        AudioEngine.shared.lose()
        onLose?()
    }

    func applyOpponentPower(_ p: BattlePower) {
        switch p {
        case .zigzag: incomingZigzag = 8
        case .mirror: incomingMirror = 6
        case .shuffle:
            board.shuffleColors(&rng)
            redrawBoard()
        }
        Haptics.shuffle()
        AudioEngine.shared.load()
        battleBanner?(p.rawValue.uppercased() + " incoming")
    }

    func snapshot() -> RunSnapshot {
        RunSnapshot(
            mode: mode.rawValue, levelId: levelId, seed: seed, score: score,
            shots: shotsLeft, wave: wave, dropIn: dropIn, dropIndex: dropIndex,
            current: currentColor.rawValue, next: nextColor.rawValue, bubbles: board.all(),
            bombs: powers.inventory.bombs, fire: powers.inventory.fireballs, face: powers.inventory.faceBalls,
            zigzag: powers.battle.zigzag, mirror: powers.battle.mirror, shuffle: powers.battle.shuffle,
            colorCleared: colorCleared, popped: popped, maxCombo: maxCombo, powersUsed: powersUsed,
            targetColor: targetColor?.rawValue
        )
    }

    func restore(_ s: RunSnapshot) {
        score = s.score
        shotsLeft = s.shots
        wave = s.wave
        dropIn = s.dropIn
        dropIndex = s.dropIndex
        currentColor = BubbleColor(rawValue: s.current) ?? .red
        nextColor = BubbleColor(rawValue: s.next) ?? .amber
        powers.inventory = Inventory(bombs: s.bombs, fireballs: s.fire, faceBalls: s.face)
        powers.battle = (s.zigzag, s.mirror, s.shuffle)
        colorCleared = s.colorCleared
        popped = s.popped
        maxCombo = s.maxCombo
        powersUsed = s.powersUsed
        board.clear()
        for b in s.bubbles {
            _ = board.spawn(col: b.col, row: b.row, color: b.color, face: b.face, pickup: b.pickup)
        }
        redrawBoard()
        refreshCannonSkin()
        if mode == .battle, cpuEnabled { bootCPU() }
        onHud?(score, shotsLeft, dropIn)
    }

    private func checkObjective() {
        guard !won, !lost, mode == .level || mode == .daily else { return }
        var met = false
        switch objective {
        case .clear, .noPowers:
            met = board.all().isEmpty
        case .score(let n):
            met = score >= n
        case .popColor(_, let n):
            met = colorCleared >= n
        case .wipeColor(let c):
            met = board.all().filter { $0.color == c }.isEmpty
        case .waves(let n):
            met = wave >= n && board.all().isEmpty
        case .popCount(let n):
            met = popped >= n
        case .combo(let n):
            met = maxCombo >= n
        }
        if met { triggerWin() }
    }

    private func triggerWin() {
        guard !won, !lost else { return }
        won = true
        pausedGame = true
        let used: Int
        if mode == .level {
            used = max(0, LevelsCatalog.info(levelId).shotLimit - shotsLeft)
            let par = parShots
            stars = used <= par - 4 ? 3 : used <= par ? 2 : 1
            if case .noPowers = objective, powersUsed == 0 { stars = 3 }
        } else if mode == .daily {
            stars = score > 800 ? 3 : score > 400 ? 2 : 1
        } else {
            stars = 1
        }
        Haptics.win()
        AudioEngine.shared.win()
        onStars?(stars)
        onWin?()
    }

    func bootCPU() {
        cpuEnabled = true
        let cpu = Board()
        for b in board.all() {
            _ = cpu.spawn(col: b.col, row: b.row, color: b.color, face: b.face)
        }
        cpuBoard = cpu
        cpuPowers = (1, 1, 1)
        cpuZigzag = 0
        cpuMirror = 0
        lastCPU = 0
    }

    func stopCPU() {
        cpuEnabled = false
    }

    private func cpuAct() {
        guard mode == .battle, cpuEnabled, let cpu = cpuBoard, !won, !lost else { return }
        let all = cpu.all()
        guard !all.isEmpty else {
            cpuScore += 400
            onCpu?(cpuScore)
            triggerLose()
            return
        }

        // Occasionally fire a battle power at the player (same loadout as bubbleme.fun).
        if Int(rng.next() % 8) == 0 {
            if cpuPowers.shuffle > 0 {
                cpuPowers.shuffle -= 1
                applyOpponentPower(.shuffle)
                return
            }
            if cpuPowers.zigzag > 0 {
                cpuPowers.zigzag -= 1
                applyOpponentPower(.zigzag)
                return
            }
            if cpuPowers.mirror > 0 {
                cpuPowers.mirror -= 1
                applyOpponentPower(.mirror)
                return
            }
        }

        var best: [GridBubble] = []
        var seen = Set<Int>()
        for b in all {
            if seen.contains(b.id) { continue }
            let cluster = cpu.cluster(fromCol: b.col, row: b.row)
            for c in cluster { seen.insert(c.id) }
            if cluster.count > best.count { best = cluster }
        }

        var miss = false
        if cpuZigzag > 0 {
            cpuZigzag -= 1
            miss = Int(rng.next() % 2) == 0
        }
        if cpuMirror > 0 {
            cpuMirror -= 1
            miss = true
        }

        spawnCPUShotVisual(color: best.first?.color ?? all[0].color)

        if !miss, best.count >= 3, Int(rng.next() % 3) == 0 {
            for b in best { _ = cpu.remove(col: b.col, row: b.row) }
            for b in cpu.floating() { _ = cpu.remove(col: b.col, row: b.row) }
            cpuScore += best.count * 12
            AudioEngine.shared.pop()
        } else if let anchor = all.randomElement() {
            var placed = false
            for n in HexGrid.neighbors(col: anchor.col, row: anchor.row) {
                if cpu.spawn(col: n.0, row: n.1, color: anchor.color) != nil {
                    placed = true
                    break
                }
            }
            cpuScore += placed ? 4 : 2
        }
        onCpu?(cpuScore)
        if cpu.all().isEmpty {
            cpuScore += 500
            onCpu?(cpuScore)
            triggerLose()
        }
    }

    private func spawnCPUShotVisual(color: BubbleColor) {
        let n = makeBubbleSprite(color: color, diameter: 18, name: "cpuShot")
        n.position = CGPoint(x: size.width - 28, y: size.height - 36)
        n.zPosition = 22
        addChild(n)
        n.run(.sequence([
            .group([
                .move(to: CGPoint(x: size.width * 0.55, y: size.height * 0.55), duration: 0.32),
                .scale(to: 1.3, duration: 0.32),
            ]),
            .fadeOut(withDuration: 0.14),
            .removeFromParent(),
        ]))
        AudioEngine.shared.shoot()
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

    private func collectPickup(_ b: GridBubble, kind: PowerUp) {
        _ = board.remove(col: b.col, row: b.row)
        switch kind {
        case .bomb: powers.inventory.bombs += 1
        case .fire: powers.inventory.fireballs += 1
        case .face: powers.inventory.faceBalls += 1
        }
        let fly = makeBubbleSprite(color: b.color, diameter: HexGrid.diameter - 1, name: "fly")
        fly.position = position(of: b)
        addChild(fly)
        let badge = SKLabelNode(text: kind == .bomb ? "💣" : kind == .fire ? "🔥" : "🙂")
        badge.fontSize = 16
        badge.verticalAlignmentMode = .center
        fly.addChild(badge)
        let dest = CGPoint(x: size.width / 2, y: 70)
        fly.run(.sequence([
            .group([
                .move(to: dest, duration: 0.45),
                .scale(to: 0.4, duration: 0.45),
            ]),
            .fadeOut(withDuration: 0.12),
            .removeFromParent(),
        ]))
        Haptics.win()
        onPickup?(kind)
        redrawBoard()
    }

    private func bubblesAward(_ n: Int) {
        profile?.addBubbles(n)
    }

    private func redrawBoard() {
        enumerateChildNodes(withName: "cell") { n, _ in n.removeFromParent() }
        enumerateChildNodes(withName: "pickupMark") { n, _ in n.removeFromParent() }
        for b in board.all() {
            let node = makeBubbleSprite(color: b.color, diameter: HexGrid.diameter - 1, name: "cell")
            node.position = position(of: b)
            addChild(node)
            if let kind = b.pickup {
                let mark = SKLabelNode(text: kind == .bomb ? "💣" : kind == .fire ? "🔥" : "🙂")
                mark.fontSize = 14
                mark.verticalAlignmentMode = .center
                mark.horizontalAlignmentMode = .center
                mark.position = node.position
                mark.zPosition = 4
                mark.name = "pickupMark"
                addChild(mark)
            }
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
        let limit = HexGrid.radius * 1.92
        var best: GridBubble?
        var bestD = limit
        for b in board.all() {
            let pos = position(of: b)
            let d = hypot(p.x - pos.x, p.y - pos.y)
            if d < bestD {
                bestD = d
                best = b
            }
        }
        return best
    }

    private func nearest(to p: CGPoint) -> GridBubble? {
        board.all().min { a, b in
            let pa = position(of: a), pb = position(of: b)
            return hypot(p.x - pa.x, p.y - pa.y) < hypot(p.x - pb.x, p.y - pb.y)
        }
    }

    /// Stick to an empty hex neighbor of the bubble we actually hit — never a hole in the middle of the board.
    private func nearestEmptyCell(hit: GridBubble?, near p: CGPoint, vx: CGFloat = 0, vy: CGFloat = 0) -> (col: Int, row: Int)? {
        let contact: CGPoint
        if let hit {
            let hc = position(of: hit)
            let spd = hypot(vx, vy)
            if spd > 1 {
                contact = CGPoint(x: hc.x - (vx / spd) * HexGrid.diameter, y: hc.y - (vy / spd) * HexGrid.diameter)
            } else {
                let dx = p.x - hc.x, dy = p.y - hc.y
                let d = hypot(dx, dy)
                if d < 0.5 {
                    contact = p
                } else {
                    contact = CGPoint(x: hc.x + (dx / d) * HexGrid.diameter, y: hc.y + (dy / d) * HexGrid.diameter)
                }
            }
        } else {
            contact = p
        }

        var scored: [(Int, Int, CGFloat, Bool)] = []
        func consider(_ c: Int, _ r: Int, fromHit: Bool) {
            guard board.inBounds(col: c, row: r), board.get(col: c, row: r) == nil else { return }
            if scored.contains(where: { $0.0 == c && $0.1 == r }) { return }
            let pos = position(ofCol: c, row: r)
            var score = hypot(contact.x - pos.x, contact.y - pos.y)
            if let hit, hypot(vx, vy) > 1 {
                let hc = position(of: hit)
                let dot = (pos.x - hc.x) * vx + (pos.y - hc.y) * vy
                if dot > 0 { score += HexGrid.diameter }
            }
            if !fromHit { score += HexGrid.radius }
            scored.append((c, r, score, fromHit))
        }

        if let hit {
            for n in HexGrid.neighbors(col: hit.col, row: hit.row) { consider(n.0, n.1, fromHit: true) }
            if scored.isEmpty {
                for n in HexGrid.neighbors(col: hit.col, row: hit.row) {
                    guard board.get(col: n.0, row: n.1) != nil else { continue }
                    for m in HexGrid.neighbors(col: n.0, row: n.1) { consider(m.0, m.1, fromHit: false) }
                }
            }
        }
        if p.y > size.height - 120 || hit == nil {
            for c in 0..<HexGrid.colCount(0) { consider(c, 0, fromHit: hit == nil) }
        }
        if scored.isEmpty {
            for b in board.all() {
                for n in HexGrid.neighbors(col: b.col, row: b.row) { consider(n.0, n.1, fromHit: false) }
            }
        }
        return scored.min(by: { $0.2 < $1.2 }).map { ($0.0, $0.1) }
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
        let bgId = profile?.background ?? .twilight
        if bgId == .twilight, let img = UIImage(named: "Twilight") {
            let bg = SKSpriteNode(texture: SKTexture(image: img))
            bg.size = size
            bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
            bg.zPosition = -20
            bg.alpha = 0.55
            addChild(bg)
        } else {
            let top = SKSpriteNode(color: SKColor(cgColor: bgId.top.cgColor), size: size)
            top.position = CGPoint(x: size.width / 2, y: size.height / 2)
            top.zPosition = -20
            addChild(top)
        }
        let dim = SKSpriteNode(color: SKColor(cgColor: bgId.bottom.withAlphaComponent(0.45).cgColor), size: size)
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
