import SpriteKit

/// The round.
///
/// Thin on purpose. Every number that decides how this feels lives in
/// `Rules.swift` as testable arithmetic; this file's job is to turn taps into
/// impulses, draw the consequences, and notice when he comes loose.
final class GameScene: SKScene, SKPhysicsContactDelegate {

    /// Called when the round ends, with everything the result screen needs.
    var onFinished: ((RoundResult) -> Void)?

    // Model
    private var ego = Ego()
    private var combo = Combo()
    private var phase: Phase = .settling
    private var elapsed: TimeInterval = 0
    private var shipsFreed = 0

    /// True once he is out of the channel and flying.
    private var isLaunched = false
    private var launchStarted: TimeInterval = 0
    private var launchOrigin: CGFloat = 0

    // Nodes
    private let channel = Channel()
    private let blocker = Blocker()
    private var bubbles: [Bubble] = []
    private let hud = HUD()

    private var lastUpdate: TimeInterval = 0
    private var nextBubble: TimeInterval = 0
    private var nextShip: TimeInterval = 0
    private var ships: [Ship] = []

    /// The speed at which timing counts as maximal. Also the yardstick the
    /// combo judge measures against.
    private let peakSpeed: Double = 620

    /// Multiplies the escape threshold. One in the real game.
    private var escapeScale: Double = 1

    /// Where the channel pinches, and where he is stuck.
    private var wedgeX: CGFloat = 0

    /// How hard the wedge pulls him back, per point of displacement.
    ///
    /// This *is* the wedge. Without it he does not rock, he slides: a shove sent
    /// him off in that direction forever, the combo judge had no oscillation to
    /// read, and he wandered off the edge of the screen without ever launching.
    /// Scaled by mass so a bigger ego is a tighter wedge, which is the whole
    /// mechanic expressed as one number.
    private let wedgeStiffness: CGFloat = 26

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = Palette.water
        scaleMode = .resizeFill

        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        channel.build(in: size)
        addChild(channel)

        // He is sized to the channel so the wedge reads. A fixed radius made
        // him a marble in a canal on a tall phone.
        Blocker.baseRadius = channel.halfGap * 0.72
        // Never wider than the channel he is stuck in.
        Blocker.maxRadius = channel.halfGap * 1.04
        wedgeX = size.width * 0.52

        blocker.position = CGPoint(x: wedgeX, y: size.height / 2)
        blocker.zPosition = 10
        addChild(blocker)

        hud.build(in: size)
        hud.zPosition = 500
        addChild(hud)

        // Nothing floats off the top or bottom of the world; the shores handle
        // that. The left and right are open, because leaving to the right is
        // the entire objective.
        Haptics.prepare()

        // Screenshot runs need to reach the launch, which is the payoff and the
        // one thing a store listing has to show. Reaching it legitimately takes
        // a minute of well-timed play, which a UI test cannot perform. This
        // lowers the bar so the capture can get there, and is reachable only
        // through a launch argument the shipped app is never started with.
        if ProcessInfo.processInfo.arguments.contains("-fastLaunch") {
            escapeScale = 0.06
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 1, isNodeInTree else { return }
        channel.build(in: size)
        hud.build(in: size)
    }

    private var isNodeInTree: Bool { scene != nil && channel.parent != nil }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        // Bubbles first. If a tap lands on one, it pops rather than shoving,
        // because that is the decision the game is about and it should never
        // feel ambiguous.
        for bubble in bubbles where bubble.contains(tap: point) {
            bubble.pop()
            return
        }

        guard !isLaunched else { return }
        shove(at: point)
    }

    private func shove(at point: CGPoint) {
        let side: TapSide = point.x < blocker.position.x ? .left : .right
        let velocity = Double(blocker.physicsBody?.velocity.dx ?? 0)
        let tier = judge(tap: side, velocityX: velocity, peakSpeed: peakSpeed)
        combo.register(tier)

        let strength = CGFloat(240 * tier.impulseScale * combo.streakBonus)
        blocker.shove(direction: side.push, strength: strength, tier: tier)

        hud.flash(tier: tier, combo: combo)
        Haptics.tap(tier)
        Audio.shared.thump(tier: tier)
        spawnImpact(at: point, tier: tier)
    }

    private func spawnImpact(at point: CGPoint, tier: ComboTier) {
        let count = 4 + tier.rawValue * 3
        for i in 0..<count {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.5...6))
            dot.fillColor = tier >= .perfect ? Palette.hullAlt : Palette.foam
            dot.strokeColor = .clear
            dot.position = point
            dot.zPosition = 60
            addChild(dot)
            let angle = CGFloat(i) / CGFloat(count) * .pi * 2
            let reach = CGFloat.random(in: 30...80) * (1 + CGFloat(tier.rawValue) * 0.2)
            dot.run(.sequence([
                .group([
                    .move(by: CGVector(dx: cos(angle) * reach, dy: sin(angle) * reach), duration: 0.35),
                    .fadeOut(withDuration: 0.35),
                ]),
                .removeFromParent(),
            ]))
        }
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        // A frame the app was suspended for arrives as one enormous dt and
        // launches him into the next county.
        let dt = lastUpdate == 0 ? 1.0 / 60.0 : min(currentTime - lastUpdate, 1.0 / 20.0)
        lastUpdate = currentTime

        blocker.tick(dt: CGFloat(dt))
        for bubble in bubbles { bubble.clamp() }

        if isLaunched {
            updateLaunch(currentTime: currentTime)
            return
        }

        elapsed += dt
        ego.tick(seconds: dt, phase: phase)

        let newPhase = Phase.at(elapsed: elapsed, ego: ego)
        if newPhase != phase {
            phase = newPhase
            if let banner = phase.banner { hud.banner(banner) }
            Audio.shared.phase()
        }

        applyWedge(dt: dt)
        blocker.apply(ego: ego)
        pruneBubbles()
        maybeSpawnBubble(now: currentTime)
        maybeSpawnShip(now: currentTime)
        updateShips(dt: dt)

        hud.update(ego: ego, combo: combo, elapsed: elapsed)

        checkEscape()
    }

    /// Hold him in the pinch, and let him rock about it.
    private func applyWedge(dt: TimeInterval) {
        guard let pb = blocker.physicsBody else { return }
        let offset = wedgeX - blocker.position.x
        let restoring = offset * wedgeStiffness * CGFloat(ego.massScale)
        pb.applyForce(CGVector(dx: restoring, dy: 0))

        // Also keep him inside the channel vertically. The shores collide, but
        // a wake can push him into one and leave him grinding along it.
        let midY = size.height / 2
        pb.applyForce(CGVector(dx: 0, dy: (midY - blocker.position.y) * 6))
    }

    /// Has he come loose?
    ///
    /// Momentum here is the physics body's own, so it accounts for everything:
    /// shoves, wakes, and the mass the ego has piled on.
    private func checkEscape() {
        guard let pb = blocker.physicsBody else { return }
        let momentum = Double(hypot(pb.velocity.dx, pb.velocity.dy)) * Double(pb.mass)
        hud.setEscape(progress: momentum / (Escape.threshold(ego: ego) * escapeScale))

        guard momentum >= Escape.threshold(ego: ego) * escapeScale else { return }
        beginLaunch(momentum: momentum)
    }

    private func beginLaunch(momentum: Double) {
        isLaunched = true
        launchStarted = elapsed
        launchOrigin = blocker.position.x

        let distance = Escape.distance(momentum: momentum, ego: ego, comboBest: combo.best)
        pendingDistance = distance

        // Everything at once: he pops out, the camera pulls back, the bubbles
        // scatter, and he keeps talking the whole way.
        blocker.launch(direction: 1, power: CGFloat(min(momentum * 0.7, 5200)))
        for bubble in bubbles { bubble.pop() }
        bubbles.removeAll()

        hud.banner("STRAIT CLEARED!")
        Haptics.launch()
        Audio.shared.launch()

        // Chase him, zooming out as he goes, so the skip reads as distance.
        let pull = SKAction.customAction(withDuration: 3.2) { [weak self] _, t in
            guard let self else { return }
            let k = min(t / 3.2, 1)
            self.channel.setScale(1 - 0.35 * k)
            self.blocker.setScale(1 - 0.35 * k)
        }
        run(pull)

        // Keep yelling on the way out. It is the payoff of the whole joke.
        run(.repeat(.sequence([
            .wait(forDuration: 0.55),
            .run { [weak self] in self?.shoutMidflight() },
        ]), count: 4))

        run(.sequence([.wait(forDuration: 3.4), .run { [weak self] in self?.finish() }]))
    }

    private var pendingDistance: Double = 0

    private func shoutMidflight() {
        let bubble = Bubble(text: Quotes.random(),
                            from: CGPoint(x: blocker.position.x, y: blocker.position.y + blocker.radius + 40),
                            drift: CGVector(dx: -40, dy: 60))
        bubble.homeProvider = { [weak self] in self?.blocker.position ?? .zero }
        addChild(bubble)
        Audio.shared.quote()
    }

    private func updateLaunch(currentTime: TimeInterval) {
        // Skip off the water like a stone, losing a little each bounce.
        guard let pb = blocker.physicsBody else { return }
        if blocker.position.y < size.height * 0.30, pb.velocity.dy < 0 {
            pb.velocity.dy = abs(pb.velocity.dy) * 0.62
            splash(at: blocker.position)
            Haptics.bounce()
            Audio.shared.splash()
        }
    }

    private func splash(at point: CGPoint) {
        for i in 0..<12 {
            let drop = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...9))
            drop.fillColor = Palette.foam
            drop.strokeColor = .clear
            drop.position = point
            drop.zPosition = 30
            addChild(drop)
            let angle = -CGFloat.pi + CGFloat(i) / 12 * .pi
            drop.run(.sequence([
                .group([
                    .move(by: CGVector(dx: cos(angle) * 120, dy: abs(sin(angle)) * 150), duration: 0.5),
                    .fadeOut(withDuration: 0.5),
                ]),
                .removeFromParent(),
            ]))
        }
    }

    private func finish() {
        let result = RoundResult(
            clearSeconds: launchStarted,
            launchMetres: pendingDistance,
            maxComboCount: combo.best,
            maxComboTier: combo.bestTier,
            maxEgoPercent: ego.peak,
            shipsFreed: shipsFreed
        )
        onFinished?(result)
    }

    // MARK: - Bubbles

    private func maybeSpawnBubble(now: TimeInterval) {
        guard phase.bubbleInterval.isFinite else { return }
        guard now >= nextBubble else { return }
        nextBubble = now + phase.bubbleInterval * Double.random(in: 0.8...1.2)

        // Spawned at the edge of him and thrown clear, not from his middle.
        // Starting at 0.6 of the radius put the balloon on top of his face for
        // the first second of its life, which is the one second the player most
        // needs to see his expression.
        let up = Bool.random()
        let side: CGFloat = Bool.random() ? -1 : 1
        let start = CGPoint(
            x: blocker.position.x + side * blocker.radius * 0.7,
            y: blocker.position.y + (up ? 1 : -1) * (blocker.radius + 26)
        )
        let drift = CGVector(dx: side * CGFloat.random(in: 60...170),
                             dy: up ? CGFloat.random(in: 130...210) : CGFloat.random(in: -210 ... -130))
        let bubble = Bubble(text: Quotes.random(), from: start, drift: drift)
        // Clear of the HUD at the top, and inside the screen everywhere else.
        bubble.bounds = CGRect(x: 8, y: 8, width: size.width - 16, height: size.height - 150)
        bubble.homeProvider = { [weak self] in self?.blocker.position ?? .zero }
        bubble.onLanded = { [weak self] in
            guard let self else { return }
            self.ego.absorb()
            self.blocker.setExpression(.smug)
            Haptics.inflate()
            Audio.shared.inflate()
            self.hud.pulseEgo()
        }
        bubble.onPopped = { [weak self] in
            guard let self else { return }
            self.ego.pop()
            Haptics.pop()
            Audio.shared.pop()
        }
        addChild(bubble)
        bubbles.append(bubble)
        Audio.shared.quote()
    }

    private func pruneBubbles() {
        bubbles.removeAll { $0.isPopped || $0.hasLanded || $0.parent == nil }
    }

    // MARK: - Ships

    private func maybeSpawnShip(now: TimeInterval) {
        guard now >= nextShip else { return }
        nextShip = now + phase.shipInterval * Double.random(in: 0.85...1.15)

        let laneSpread = channel.halfGap * 0.55
        let laneY = size.height / 2 + CGFloat.random(in: -laneSpread...laneSpread)
        let ship = Ship(width: CGFloat.random(in: 130...210),
                        laneY: laneY,
                        tint: Bool.random() ? Palette.hull : Palette.hullAlt)
        ship.position = CGPoint(x: -140, y: laneY)
        addChild(ship)
        ships.append(ship)
    }

    private func updateShips(dt: TimeInterval) {
        let speed: CGFloat = phase == .settling ? 90 : 130

        for ship in ships {
            // Ships queue behind him rather than driving through, which is the
            // visual statement of the problem.
            let blocked = !isLaunched
                && ship.position.x + 110 > blocker.position.x - blocker.radius
                && ship.position.x < blocker.position.x
                && abs(ship.laneY - blocker.position.y) < blocker.radius + 40

            if !blocked {
                ship.position.x += speed * CGFloat(dt)
                // A passing ship drags water with it, which nudges him. Small,
                // but it means the channel is never entirely still.
                if abs(ship.position.x - blocker.position.x) < 220 {
                    let pull = (ship.laneY - blocker.position.y) > 0 ? -1.0 : 1.0
                    blocker.physicsBody?.applyForce(
                        CGVector(dx: 14, dy: CGFloat(pull) * 10)
                    )
                }
            }

            if !ship.hasPassed, ship.position.x > blocker.position.x + 60 {
                ship.markPassed()
                shipsFreed += 1
                hud.tickShips(shipsFreed)
            }
        }

        ships.removeAll { ship in
            if ship.position.x > size.width + 200 {
                ship.removeFromParent()
                return true
            }
            return false
        }
    }
}
