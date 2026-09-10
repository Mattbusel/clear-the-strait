import SpriteKit

/// The thing in the channel.
///
/// A generic, extremely round caricature of a self-important politician: blond
/// swoop, blue suit, red tie, tiny limbs, enormous everything else. He is never
/// named, here or anywhere else in the app, and he is a *type* rather than a
/// portrait. That is a deliberate legal posture as much as a comedic one.
///
/// Drawn entirely from shapes and paths. No image assets exist in this project,
/// which keeps the bundle tiny, makes every proportion tunable from a number,
/// and means the art is authored in the same place as everything else.
///
/// # Soft body without a soft-body engine
///
/// He reads as squishy but he is one circular physics body. All the softness is
/// visual: the container squashes and stretches in response to speed and
/// impacts, the limbs lag behind on springs, and the whole thing wobbles after
/// a hit. A real soft body here would be several times the code for an effect
/// nobody could tell apart at this size.
final class Blocker: SKNode {

    /// Radius at 100% ego, in points. Everything else is measured from this.
    static let baseRadius: CGFloat = 86

    /// The visual container. Squash and stretch is applied here, so the physics
    /// body is never scaled and the simulation stays stable.
    private let art = SKNode()

    private var body: SKShapeNode!
    private var shirt: SKShapeNode!
    private var tie: SKShapeNode!
    private var hair: SKShapeNode!
    private var leftEye: SKShapeNode!
    private var rightEye: SKShapeNode!
    private var mouth: SKShapeNode!
    private var leftArm: SKShapeNode!
    private var rightArm: SKShapeNode!
    private var leftLeg: SKShapeNode!
    private var rightLeg: SKShapeNode!
    private var blush: SKNode!

    /// Current drawn radius, after ego.
    private(set) var radius: CGFloat = Blocker.baseRadius

    /// Wobble state: an offset that decays, driven by impacts.
    private var wobble: CGFloat = 0
    private var wobblePhase: CGFloat = 0

    override init() {
        super.init()
        addChild(art)
        buildArt()
        makePhysics(radius: Blocker.baseRadius, massScale: 1)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Art

    private func buildArt() {
        let r = Blocker.baseRadius

        // The body. One big sphere, because the joke is the sphere.
        body = SKShapeNode(circleOfRadius: r)
        body.fillColor = Palette.suit
        body.strokeColor = Palette.suitEdge
        body.lineWidth = 4
        art.addChild(body)

        // Shirt: a rounded wedge down the middle, so the suit reads as a suit
        // rather than as a blue ball.
        let shirtPath = CGMutablePath()
        shirtPath.move(to: CGPoint(x: -r * 0.30, y: r * 0.42))
        shirtPath.addQuadCurve(
            to: CGPoint(x: r * 0.30, y: r * 0.42),
            control: CGPoint(x: 0, y: r * 0.20)
        )
        shirtPath.addLine(to: CGPoint(x: r * 0.20, y: -r * 0.62))
        shirtPath.addQuadCurve(
            to: CGPoint(x: -r * 0.20, y: -r * 0.62),
            control: CGPoint(x: 0, y: -r * 0.74)
        )
        shirtPath.closeSubpath()
        shirt = SKShapeNode(path: shirtPath)
        shirt.fillColor = Palette.shirt
        shirt.strokeColor = .clear
        art.addChild(shirt)

        // The tie. Absurdly long, which is the one caricature detail doing the
        // most work for the least ink.
        let tiePath = CGMutablePath()
        tiePath.move(to: CGPoint(x: 0, y: r * 0.38))
        tiePath.addLine(to: CGPoint(x: r * 0.11, y: r * 0.20))
        tiePath.addLine(to: CGPoint(x: r * 0.09, y: -r * 0.70))
        tiePath.addQuadCurve(
            to: CGPoint(x: -r * 0.09, y: -r * 0.70),
            control: CGPoint(x: 0, y: -r * 0.80)
        )
        tiePath.addLine(to: CGPoint(x: -r * 0.11, y: r * 0.20))
        tiePath.closeSubpath()
        tie = SKShapeNode(path: tiePath)
        tie.fillColor = Palette.tie
        tie.strokeColor = .clear
        art.addChild(tie)

        // Face. Sits high on the sphere; there is no separate head, which is
        // what makes him read as chibi rather than as a man on a ball.
        leftEye = Blocker.eye()
        leftEye.position = CGPoint(x: -r * 0.26, y: r * 0.50)
        art.addChild(leftEye)

        rightEye = Blocker.eye()
        rightEye.position = CGPoint(x: r * 0.26, y: r * 0.50)
        art.addChild(rightEye)

        blush = SKNode()
        for side in [-1.0, 1.0] as [CGFloat] {
            let cheek = SKShapeNode(ellipseOf: CGSize(width: r * 0.26, height: r * 0.15))
            cheek.fillColor = Palette.blush
            cheek.strokeColor = .clear
            cheek.alpha = 0.55
            cheek.position = CGPoint(x: side * r * 0.44, y: r * 0.34)
            blush.addChild(cheek)
        }
        art.addChild(blush)

        mouth = SKShapeNode(path: Blocker.mouthPath(.neutral, radius: r))
        mouth.fillColor = Palette.mouth
        mouth.strokeColor = Palette.mouthEdge
        mouth.lineWidth = 3
        art.addChild(mouth)

        // The hair. One confident swoop, drawn as a single closed curve.
        let hairPath = CGMutablePath()
        hairPath.move(to: CGPoint(x: -r * 0.62, y: r * 0.62))
        hairPath.addQuadCurve(
            to: CGPoint(x: r * 0.10, y: r * 1.06),
            control: CGPoint(x: -r * 0.50, y: r * 1.10)
        )
        hairPath.addQuadCurve(
            to: CGPoint(x: r * 0.74, y: r * 0.70),
            control: CGPoint(x: r * 0.86, y: r * 1.02)
        )
        hairPath.addQuadCurve(
            to: CGPoint(x: r * 0.40, y: r * 0.74),
            control: CGPoint(x: r * 0.52, y: r * 0.62)
        )
        hairPath.addQuadCurve(
            to: CGPoint(x: -r * 0.62, y: r * 0.62),
            control: CGPoint(x: -r * 0.10, y: r * 0.86)
        )
        hairPath.closeSubpath()
        hair = SKShapeNode(path: hairPath)
        hair.fillColor = Palette.hair
        hair.strokeColor = Palette.hairEdge
        hair.lineWidth = 3
        art.addChild(hair)

        // Tiny limbs, added last so they sit in front of the suit.
        leftArm = Blocker.limb(length: r * 0.42, thickness: r * 0.20)
        leftArm.position = CGPoint(x: -r * 0.86, y: -r * 0.02)
        leftArm.zRotation = 0.5
        art.addChild(leftArm)

        rightArm = Blocker.limb(length: r * 0.42, thickness: r * 0.20)
        rightArm.position = CGPoint(x: r * 0.86, y: -r * 0.02)
        rightArm.zRotation = -0.5
        art.addChild(rightArm)

        leftLeg = Blocker.limb(length: r * 0.34, thickness: r * 0.22)
        leftLeg.position = CGPoint(x: -r * 0.34, y: -r * 0.88)
        leftLeg.zRotation = 1.3
        art.addChild(leftLeg)

        rightLeg = Blocker.limb(length: r * 0.34, thickness: r * 0.22)
        rightLeg.position = CGPoint(x: r * 0.34, y: -r * 0.88)
        rightLeg.zRotation = 1.84
        art.addChild(rightLeg)
    }

    private static func eye() -> SKShapeNode {
        let node = SKShapeNode(ellipseOf: CGSize(width: 20, height: 26))
        node.fillColor = .white
        node.strokeColor = Palette.ink
        node.lineWidth = 3
        let pupil = SKShapeNode(circleOfRadius: 6.5)
        pupil.fillColor = Palette.ink
        pupil.strokeColor = .clear
        pupil.name = "pupil"
        node.addChild(pupil)
        return node
    }

    private static func limb(length: CGFloat, thickness: CGFloat) -> SKShapeNode {
        let rect = CGRect(x: 0, y: -thickness / 2, width: length, height: thickness)
        let node = SKShapeNode(path: CGPath(roundedRect: rect,
                                            cornerWidth: thickness / 2,
                                            cornerHeight: thickness / 2,
                                            transform: nil))
        node.fillColor = Palette.suit
        node.strokeColor = Palette.suitEdge
        node.lineWidth = 3
        return node
    }

    /// What his mouth is doing.
    enum Expression {
        case neutral
        case smug
        case yelling
        case strained
    }

    private static func mouthPath(_ expression: Expression, radius r: CGFloat) -> CGPath {
        switch expression {
        case .neutral:
            return CGPath(ellipseIn: CGRect(x: -r * 0.14, y: r * 0.08,
                                            width: r * 0.28, height: r * 0.10),
                          transform: nil)
        case .smug:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -r * 0.20, y: r * 0.18))
            p.addQuadCurve(to: CGPoint(x: r * 0.20, y: r * 0.18),
                           control: CGPoint(x: 0, y: r * 0.02))
            p.addQuadCurve(to: CGPoint(x: -r * 0.20, y: r * 0.18),
                           control: CGPoint(x: 0, y: r * 0.12))
            return p
        case .yelling:
            return CGPath(ellipseIn: CGRect(x: -r * 0.19, y: r * 0.00,
                                            width: r * 0.38, height: r * 0.26),
                          transform: nil)
        case .strained:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -r * 0.22, y: r * 0.10))
            p.addLine(to: CGPoint(x: -r * 0.06, y: r * 0.16))
            p.addLine(to: CGPoint(x: r * 0.06, y: r * 0.06))
            p.addLine(to: CGPoint(x: r * 0.22, y: r * 0.14))
            p.addLine(to: CGPoint(x: r * 0.22, y: r * 0.04))
            p.addLine(to: CGPoint(x: -r * 0.22, y: r * 0.00))
            p.closeSubpath()
            return p
        }
    }

    private var expression: Expression = .neutral

    func setExpression(_ next: Expression) {
        guard next != expression else { return }
        expression = next
        mouth.path = Blocker.mouthPath(next, radius: Blocker.baseRadius)
    }

    // MARK: - Physics

    private func makePhysics(radius: CGFloat, massScale: Double) {
        let pb = SKPhysicsBody(circleOfRadius: radius)
        pb.mass = CGFloat(3.0 * massScale)
        pb.restitution = 0.42
        // Enough friction to actually roll rather than slide, which is what
        // makes the rocking read as a body and not a sprite being nudged.
        pb.friction = 0.62
        pb.linearDamping = 0.9
        pb.angularDamping = 0.7
        pb.allowsRotation = true
        pb.categoryBitMask = Category.blocker
        pb.contactTestBitMask = Category.shore | Category.ship | Category.bubble
        pb.collisionBitMask = Category.shore | Category.ship
        physicsBody = pb
    }

    /// Resize him for a new ego reading.
    ///
    /// The physics body is rebuilt rather than scaled: SpriteKit does not scale
    /// bodies with their node, so scaling the node alone would leave the
    /// collision shape at its original size and he would visibly overlap the
    /// shores.
    func apply(ego: Ego) {
        let scale = CGFloat(ego.radiusScale)
        let newRadius = Blocker.baseRadius * scale
        guard abs(newRadius - radius) > 0.5 else { return }

        radius = newRadius
        art.setScale(scale)

        let velocity = physicsBody?.velocity ?? .zero
        let angular = physicsBody?.angularVelocity ?? 0
        makePhysics(radius: newRadius, massScale: ego.massScale)
        physicsBody?.velocity = velocity
        physicsBody?.angularVelocity = angular
    }

    // MARK: - Feel

    /// Shove him, and make him look shoved.
    func shove(direction: Double, strength: CGFloat, tier: ComboTier) {
        guard let pb = physicsBody else { return }
        let impulse = CGVector(dx: CGFloat(direction) * strength, dy: 0)
        pb.applyImpulse(impulse)
        // A shove off-centre also spins him, which is what lets a rhythm build
        // rotation rather than just sliding him back and forth.
        pb.applyAngularImpulse(CGFloat(-direction) * strength * 0.0016)

        wobble = min(wobble + strength * 0.0022, 0.34)
        wobblePhase = 0

        setExpression(tier >= .perfect ? .strained : .yelling)
        run(.sequence([.wait(forDuration: 0.28), .run { [weak self] in
            self?.setExpression(.smug)
        }]))
    }

    /// Called every frame to animate softness.
    func tick(dt: CGFloat) {
        guard let pb = physicsBody else { return }

        // Squash along the direction of travel, stretch across it. Driven by
        // speed so he flattens when he is really moving.
        let speed = hypot(pb.velocity.dx, pb.velocity.dy)
        let speedSquash = min(speed / 2600, 0.16)

        wobblePhase += dt * 17
        wobble *= pow(0.12, dt)
        let bounce = sin(wobblePhase) * wobble

        art.xScale = (1 + speedSquash + bounce) * (radius / Blocker.baseRadius)
        art.yScale = (1 - speedSquash - bounce) * (radius / Blocker.baseRadius)

        // The limbs lag, which is most of what sells him as soft.
        let lag = -pb.velocity.dx / 5200
        leftArm.zRotation = 0.5 + lag
        rightArm.zRotation = -0.5 + lag
        leftLeg.zRotation = 1.3 + lag * 0.5
        rightLeg.zRotation = 1.84 + lag * 0.5

        // Hair always trailing the motion, one beat behind the limbs.
        hair.zRotation = lag * 0.6

        // Eyes track the way he is going, so he looks alarmed in the right
        // direction.
        let look = max(-1, min(1, pb.velocity.dx / 900)) * 5
        for eye in [leftEye, rightEye] {
            eye?.childNode(withName: "pupil")?.position = CGPoint(x: look, y: 0)
        }
    }

    /// He is out. Stop simulating the wedge and let him fly.
    func launch(direction: CGFloat, power: CGFloat) {
        physicsBody?.collisionBitMask = 0
        physicsBody?.linearDamping = 0.06
        physicsBody?.angularDamping = 0.05
        physicsBody?.applyImpulse(CGVector(dx: direction * power, dy: power * 0.42))
        physicsBody?.applyAngularImpulse(-direction * power * 0.004)
        setExpression(.yelling)
    }
}

/// Physics categories, in one place so a typo is a compile error.
enum Category {
    static let blocker: UInt32 = 1 << 0
    static let shore: UInt32 = 1 << 1
    static let ship: UInt32 = 1 << 2
    static let bubble: UInt32 = 1 << 3
    static let water: UInt32 = 1 << 4
}
