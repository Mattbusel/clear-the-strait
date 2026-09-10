import SpriteKit

/// Things the blocker says about himself.
///
/// Every line is invented for this game. None is a quotation of anything anyone
/// has ever actually said, and the app never claims otherwise: the character is
/// unnamed, the lines are written to be obviously absurd, and the whole thing is
/// parody of a *type* rather than a transcript of a person.
///
/// Kept generic on purpose. Nothing here refers to a real country, conflict,
/// place, election, policy or event.
enum Quotes {
    static let lines: [String] = [
        "NOBODY BLOCKS A CHANNEL BETTER THAN ME!",
        "THIS CHANNEL IS TREMENDOUS!",
        "THEY'RE SAYING I'M THE GREATEST BLOCKADE!",
        "FRANKLY, THEY SHOULD NAME IT AFTER ME!",
        "THESE SHIPS LOVE ME!",
        "NOBODY UNDERSTANDS SHIPPING LIKE I DO!",
        "I'M VERY BUOYANT. EVERYONE SAYS SO.",
        "THE WATER IS HONESTLY LUCKY!",
        "I'M NOT STUCK. I'M NEGOTIATING.",
        "TREMENDOUS CIRCUMFERENCE. THE BEST.",
        "MANY PEOPLE ARE CALLING ME ROUND!",
        "I COULD BLOCK ANY CHANNEL. ANY ONE.",
        "THIS IS A PERFECT WEDGE!",
        "THE BOATS ARE HAVING A GREAT TIME!",
        "I'VE NEVER FLOATED BETTER!",
        "EXPERTS SAY I'M EXTREMELY WEDGED!",
        "I'M A VERY STABLE OBSTACLE!",
        "SOME SAY THE BIGGEST BLOCKAGE EVER!",
    ]

    static func random() -> String {
        lines.randomElement() ?? lines[0]
    }
}

/// A speech bubble drifting away from him, and then back.
///
/// The whole ego mechanic in one object: it floats out, turns around, and if it
/// gets home he believes it. Popping it is the counterplay, and it has to be
/// tappable for long enough to be a real choice rather than a reflex test.
final class Bubble: SKNode {

    /// Seconds it drifts outward before turning around.
    private static let outward: TimeInterval = 1.5
    /// Seconds it takes to come home once it turns.
    private static let returning: TimeInterval = 2.6

    private(set) var isPopped = false
    private(set) var hasLanded = false

    /// Radius used for tap hit-testing, generous on purpose.
    private(set) var tapRadius: CGFloat = 0

    private let label: SKLabelNode
    private let balloon: SKShapeNode

    init(text: String, from origin: CGPoint, drift: CGVector) {
        label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = 15
        label.fontColor = Palette.ink
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.preferredMaxLayoutWidth = 190
        label.numberOfLines = 3

        // Measure after configuring, so the balloon fits the words.
        let textSize = label.frame.size
        let padding: CGFloat = 18
        let size = CGSize(width: max(textSize.width, 60) + padding * 2,
                          height: max(textSize.height, 20) + padding * 1.4)

        balloon = SKShapeNode(
            path: CGPath(roundedRect: CGRect(origin: CGPoint(x: -size.width / 2, y: -size.height / 2),
                                             size: size),
                         cornerWidth: 16, cornerHeight: 16, transform: nil)
        )
        balloon.fillColor = Palette.bubble
        balloon.strokeColor = Palette.bubbleEdge
        balloon.lineWidth = 3

        super.init()

        tapRadius = max(size.width, size.height) * 0.58

        addChild(balloon)
        addChild(label)
        position = origin
        zPosition = 40
        setScale(0.2)

        run(.scale(to: 1, duration: 0.18))

        // Out, pause, then home. The pause is what gives the player a moment to
        // decide rather than react.
        let out = SKAction.move(by: drift, duration: Bubble.outward)
        out.timingMode = .easeOut
        let bob = SKAction.repeatForever(.sequence([
            .moveBy(x: 0, y: 7, duration: 0.7),
            .moveBy(x: 0, y: -7, duration: 0.7),
        ]))
        balloon.run(bob)
        run(.sequence([out, .wait(forDuration: 0.35)])) { [weak self] in
            self?.turnHome()
        }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Where to return to. Set by the scene each frame, because he moves.
    var homeProvider: (() -> CGPoint)?

    private func turnHome() {
        guard !isPopped else { return }
        // Tint as it turns, so an incoming bubble is visually distinct from one
        // still drifting out. Without this the player cannot tell which ones
        // are actually a threat.
        balloon.run(.customAction(withDuration: 0.25) { node, _ in
            (node as? SKShapeNode)?.strokeColor = Palette.tie
        })
        run(.repeatForever(.sequence([
            .scale(to: 1.06, duration: 0.3),
            .scale(to: 1.0, duration: 0.3),
        ])), withKey: "pulse")

        let step = SKAction.customAction(withDuration: Bubble.returning) { [weak self] node, elapsed in
            guard let self, let home = self.homeProvider?() else { return }
            let t = CGFloat(elapsed) / CGFloat(Bubble.returning)
            let eased = t * t
            let dx = home.x - node.position.x
            let dy = home.y - node.position.y
            // Chase rather than lerp from a fixed start, so it tracks him even
            // when the player is rolling him across the screen.
            node.position.x += dx * eased * 0.10
            node.position.y += dy * eased * 0.10
            if hypot(dx, dy) < 40 { self.land() }
        }
        run(.sequence([step, .run { [weak self] in self?.land() }]), withKey: "home")
    }

    private func land() {
        guard !isPopped, !hasLanded else { return }
        hasLanded = true
        removeAllActions()
        onLanded?()
        run(.sequence([.group([.scale(to: 0.1, duration: 0.2), .fadeOut(withDuration: 0.2)]),
                       .removeFromParent()]))
    }

    var onLanded: (() -> Void)?
    var onPopped: (() -> Void)?

    /// Whether a tap at this point hits the bubble.
    func contains(tap: CGPoint) -> Bool {
        guard !isPopped, !hasLanded else { return false }
        return hypot(tap.x - position.x, tap.y - position.y) <= tapRadius
    }

    func pop() {
        guard !isPopped, !hasLanded else { return }
        isPopped = true
        removeAllActions()
        onPopped?()

        // A burst of shards, which is most of why popping feels good.
        for i in 0..<10 {
            let shard = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...7))
            shard.fillColor = i % 2 == 0 ? Palette.foam : Palette.hullAlt
            shard.strokeColor = .clear
            shard.position = position
            shard.zPosition = 41
            parent?.addChild(shard)
            let angle = CGFloat(i) / 10 * .pi * 2 + CGFloat.random(in: -0.3...0.3)
            let distance = CGFloat.random(in: 50...110)
            shard.run(.sequence([
                .group([
                    .move(by: CGVector(dx: cos(angle) * distance, dy: sin(angle) * distance),
                          duration: 0.42),
                    .fadeOut(withDuration: 0.42),
                    .scale(to: 0.2, duration: 0.42),
                ]),
                .removeFromParent(),
            ]))
        }

        run(.sequence([
            .group([.scale(to: 1.5, duration: 0.12), .fadeOut(withDuration: 0.12)]),
            .removeFromParent(),
        ]))
    }
}
