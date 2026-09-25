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
    ///
    /// Set from the channel when the scene builds, rather than fixed: he has to
    /// nearly fill the gap for the wedge to read, and the gap is a fraction of
    /// whatever screen this is. At a fixed 86 points he was a third of the
    /// channel on a modern phone and looked like a marble in a canal.
    static var baseRadius: CGFloat = 150

    /// The largest he may ever be drawn, whatever his ego says.
    ///
    /// Set from the channel. Without it a high ego inflated him past both
    /// shores at once, and the collision resolution squeezed him sideways out
    /// of the pinch and off the screen. Being *nearly* too big for the channel
    /// is the joke; being bigger than the water is a bug.
    static var maxRadius: CGFloat = 400

    /// The visual container. Squash and stretch is applied here, so the physics
    /// body is never scaled and the simulation stays stable.
    private let art = SKNode()

    private var body: SKShapeNode!
    private var shirt: SKShapeNode!
    private var tie: SKNode!
    private var hair: SKNode!
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

    /// Who he is. Decides the colours, the headgear and the neckwear.
    let who: Blowhard

    init(who: Blowhard = .blowhard) {
        self.who = who
        super.init()
        addChild(art)
        buildArt()
        makePhysics(radius: Blocker.baseRadius, massScale: 1)
    }

    required init?(coder: NSCoder) {
        who = .blowhard
        super.init(coder: coder)
    }

    // MARK: - Art

    private func buildArt() {
        let r = Blocker.baseRadius

        // The body. One big sphere, because the joke is the sphere.
        body = SKShapeNode(circleOfRadius: r)
        body.fillColor = who.suit
        body.strokeColor = who.suitEdge
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
        shirt.fillColor = who.shirt
        shirt.strokeColor = .clear
        art.addChild(shirt)

        tie = Blocker.neckwear(who, radius: r)
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

        // Whatever sits on top: hair, hat, or a shine. It trails the motion
        // one beat behind the limbs, so it is kept as one node. Spectacles and
        // moustaches go on the face, which does not trail.
        hair = SKNode()
        let face = SKNode()
        Blocker.decorateTop(hair, face: face, who: who, radius: r)
        art.addChild(face)
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

        for limb in [leftArm, rightArm, leftLeg, rightLeg] {
            limb?.fillColor = who.suit
            limb?.strokeColor = who.suitEdge
        }
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
        node.fillColor = .clear
        node.strokeColor = .clear
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
        // Shores only. In 1.0 he also collided with the ships, and the queue
        // that stacks up behind him shoved him slowly off the right of the
        // screen. Ships still nudge him through their wakes.
        pb.collisionBitMask = Category.shore
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
        let newRadius = min(Blocker.baseRadius * scale, Blocker.maxRadius)
        guard abs(newRadius - radius) > 0.5 else { return }

        radius = newRadius
        art.setScale(newRadius / Blocker.baseRadius)

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

        // Counter-rotate, so the face stays the right way up while the body
        // rolls underneath it.
        //
        // A physics body this shape has to be allowed to rotate or it slides
        // instead of rolling, but a chibi face tumbling through 360 degrees
        // reads as a ragdoll being thrown rather than as a character. Every
        // cute mobile game does this: the motion is carried by squash, the
        // trailing limbs and the swinging tie, not by spinning the eyes.
        art.zRotation = -zRotation

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

// MARK: - Wardrobe

extension Blocker {
    private static func shape(_ path: CGPath, fill: SKColor, stroke: SKColor = .clear, width: CGFloat = 0) -> SKShapeNode {
        let node = SKShapeNode(path: path)
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = width
        return node
    }

    /// The tie, the bow, the waistcoat or the sash.
    static func neckwear(_ who: Blowhard, radius r: CGFloat) -> SKNode {
        let holder = SKNode()
        switch who.neck {
        case .longTie:
            // Absurdly long, which is the one caricature detail doing the most
            // work for the least ink.
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: r * 0.38))
            p.addLine(to: CGPoint(x: r * 0.11, y: r * 0.20))
            p.addLine(to: CGPoint(x: r * 0.09, y: -r * 0.70))
            p.addQuadCurve(to: CGPoint(x: -r * 0.09, y: -r * 0.70), control: CGPoint(x: 0, y: -r * 0.80))
            p.addLine(to: CGPoint(x: -r * 0.11, y: r * 0.20))
            p.closeSubpath()
            holder.addChild(shape(p, fill: who.accent))

        case .bowTie:
            // A floppy bow, far too big, with polka dots.
            for side in [-1.0, 1.0] as [CGFloat] {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 0, y: r * 0.30))
                p.addQuadCurve(to: CGPoint(x: side * r * 0.34, y: r * 0.44), control: CGPoint(x: side * r * 0.16, y: r * 0.50))
                p.addQuadCurve(to: CGPoint(x: side * r * 0.32, y: r * 0.14), control: CGPoint(x: side * r * 0.42, y: r * 0.28))
                p.addQuadCurve(to: CGPoint(x: 0, y: r * 0.30), control: CGPoint(x: side * r * 0.16, y: r * 0.12))
                p.closeSubpath()
                holder.addChild(shape(p, fill: who.accent, stroke: who.suitEdge, width: 2))
                let dots: [(CGFloat, CGFloat)] = [(0.20, 0.36), (0.26, 0.22)]
                for (dx, dy) in dots {
                    let dot = SKShapeNode(circleOfRadius: r * 0.028)
                    dot.fillColor = SKColor(white: 1, alpha: 0.8)
                    dot.strokeColor = .clear
                    dot.position = CGPoint(x: side * r * dx, y: r * dy)
                    holder.addChild(dot)
                }
            }
            let knot = SKShapeNode(ellipseOf: CGSize(width: r * 0.13, height: r * 0.15))
            knot.fillColor = who.accent
            knot.strokeColor = who.suitEdge
            knot.lineWidth = 2
            knot.position = CGPoint(x: 0, y: r * 0.29)
            holder.addChild(knot)

        case .waistcoat:
            // A gold waistcoat over the shirt, straining at three buttons.
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -r * 0.36, y: r * 0.30))
            p.addLine(to: CGPoint(x: 0, y: -r * 0.12))
            p.addLine(to: CGPoint(x: r * 0.36, y: r * 0.30))
            p.addLine(to: CGPoint(x: r * 0.40, y: -r * 0.56))
            p.addQuadCurve(to: CGPoint(x: -r * 0.40, y: -r * 0.56), control: CGPoint(x: 0, y: -r * 0.80))
            p.closeSubpath()
            holder.addChild(shape(p, fill: who.accent, stroke: SKColor(red: 0.62, green: 0.44, blue: 0.08, alpha: 1), width: 3))
            for i in 0..<3 {
                let button = SKShapeNode(circleOfRadius: r * 0.035)
                button.fillColor = who.suit
                button.strokeColor = .clear
                button.position = CGPoint(x: 0, y: -r * 0.24 - CGFloat(i) * r * 0.14)
                holder.addChild(button)
            }
            // A fob chain across the tummy.
            let chain = CGMutablePath()
            chain.move(to: CGPoint(x: -r * 0.30, y: -r * 0.30))
            chain.addQuadCurve(to: CGPoint(x: 0, y: -r * 0.36), control: CGPoint(x: -r * 0.16, y: -r * 0.46))
            let fob = SKShapeNode(path: chain)
            fob.strokeColor = SKColor(red: 1.0, green: 0.90, blue: 0.50, alpha: 1)
            fob.lineWidth = 3
            holder.addChild(fob)

        case .sash:
            // A ceremonial sash from shoulder to hip, clipped to the sphere,
            // and a chain of office with a medallion.
            let crop = SKCropNode()
            let mask = SKShapeNode(circleOfRadius: r - 2)
            mask.fillColor = .white
            crop.maskNode = mask
            let band = SKShapeNode(rectOf: CGSize(width: r * 2.4, height: r * 0.26))
            band.fillColor = who.accent
            band.strokeColor = SKColor(white: 1, alpha: 0.9)
            band.lineWidth = 3
            band.zRotation = -0.62
            band.position = CGPoint(x: 0, y: -r * 0.10)
            crop.addChild(band)
            holder.addChild(crop)

            let gold = SKColor(red: 0.98, green: 0.80, blue: 0.28, alpha: 1)
            let chain = CGMutablePath()
            chain.move(to: CGPoint(x: -r * 0.44, y: r * 0.34))
            chain.addQuadCurve(to: CGPoint(x: r * 0.44, y: r * 0.34), control: CGPoint(x: 0, y: -r * 0.10))
            let link = SKShapeNode(path: chain)
            link.strokeColor = gold
            link.lineWidth = r * 0.05
            link.lineCap = .round
            holder.addChild(link)
            let medal = SKShapeNode(circleOfRadius: r * 0.10)
            medal.fillColor = gold
            medal.strokeColor = SKColor(red: 0.62, green: 0.44, blue: 0.08, alpha: 1)
            medal.lineWidth = 3
            medal.position = CGPoint(x: 0, y: r * 0.12)
            holder.addChild(medal)
        }
        return holder
    }

    /// Hair, hat or shine on `top` (which trails the motion), and anything that
    /// must sit still on the face, such as spectacles, on `face`.
    static func decorateTop(_ top: SKNode, face: SKNode, who: Blowhard, radius r: CGFloat) {
        switch who.top {
        case .swoop:
            // One confident swoop, drawn as a single closed curve.
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -r * 0.62, y: r * 0.62))
            p.addQuadCurve(to: CGPoint(x: r * 0.10, y: r * 1.06), control: CGPoint(x: -r * 0.50, y: r * 1.10))
            p.addQuadCurve(to: CGPoint(x: r * 0.74, y: r * 0.70), control: CGPoint(x: r * 0.86, y: r * 1.02))
            p.addQuadCurve(to: CGPoint(x: r * 0.40, y: r * 0.74), control: CGPoint(x: r * 0.52, y: r * 0.62))
            p.addQuadCurve(to: CGPoint(x: -r * 0.62, y: r * 0.62), control: CGPoint(x: -r * 0.10, y: r * 0.86))
            p.closeSubpath()
            top.addChild(shape(p, fill: who.hair, stroke: who.hairEdge, width: 3))

        case .tufts:
            // Two magnificent white tufts over the ears, nothing in between.
            let puffs: [(CGFloat, CGFloat, CGFloat)] = [(0.66, 0.70, 0.17), (0.78, 0.52, 0.15), (0.52, 0.84, 0.13), (0.84, 0.72, 0.12)]
            for side in [-1.0, 1.0] as [CGFloat] {
                for (dx, dy, rr) in puffs {
                    let puff = SKShapeNode(circleOfRadius: r * rr)
                    puff.fillColor = who.hair
                    puff.strokeColor = who.hairEdge
                    puff.lineWidth = 2
                    puff.position = CGPoint(x: side * r * dx, y: r * dy)
                    top.addChild(puff)
                }
            }
            // Eyebrows like hedges.
            for side in [-1.0, 1.0] as [CGFloat] {
                let brow = SKShapeNode(ellipseOf: CGSize(width: r * 0.24, height: r * 0.08))
                brow.fillColor = who.hair
                brow.strokeColor = who.hairEdge
                brow.lineWidth = 1.5
                brow.position = CGPoint(x: side * r * 0.26, y: r * 0.70)
                brow.zRotation = side * -0.18
                face.addChild(brow)
            }
            // Round spectacles on the eyes.
            for side in [-1.0, 1.0] as [CGFloat] {
                let lens = SKShapeNode(circleOfRadius: r * 0.15)
                lens.fillColor = SKColor(white: 1, alpha: 0.12)
                lens.strokeColor = Palette.ink
                lens.lineWidth = 3
                lens.position = CGPoint(x: side * r * 0.26, y: r * 0.50)
                face.addChild(lens)
            }
            let bridge = CGMutablePath()
            bridge.move(to: CGPoint(x: -r * 0.11, y: r * 0.52))
            bridge.addQuadCurve(to: CGPoint(x: r * 0.11, y: r * 0.52), control: CGPoint(x: 0, y: r * 0.58))
            let b = SKShapeNode(path: bridge)
            b.strokeColor = Palette.ink
            b.lineWidth = 3
            face.addChild(b)

        case .topHat:
            let hat = SKNode()
            let crown = SKShapeNode(rect: CGRect(x: -r * 0.40, y: r * 0.84, width: r * 0.80, height: r * 0.74), cornerRadius: r * 0.06)
            crown.fillColor = who.hair
            crown.strokeColor = who.hairEdge
            crown.lineWidth = 3
            hat.addChild(crown)
            let band = SKShapeNode(rect: CGRect(x: -r * 0.40, y: r * 0.90, width: r * 0.80, height: r * 0.14))
            band.fillColor = who.accent
            band.strokeColor = .clear
            hat.addChild(band)
            let brim = SKShapeNode(ellipseOf: CGSize(width: r * 1.30, height: r * 0.20))
            brim.fillColor = who.hair
            brim.strokeColor = who.hairEdge
            brim.lineWidth = 3
            brim.position = CGPoint(x: 0, y: r * 0.84)
            hat.addChild(brim)
            // Worn at a jaunty angle.
            hat.zRotation = -0.12
            top.addChild(hat)
            // A monocle on the right eye, on a gold chain.
            let monocle = SKShapeNode(circleOfRadius: r * 0.16)
            monocle.fillColor = SKColor(white: 1, alpha: 0.15)
            monocle.strokeColor = who.accent
            monocle.lineWidth = 4
            monocle.position = CGPoint(x: r * 0.26, y: r * 0.50)
            face.addChild(monocle)
            let chain = CGMutablePath()
            chain.move(to: CGPoint(x: r * 0.40, y: r * 0.44))
            chain.addQuadCurve(to: CGPoint(x: r * 0.62, y: r * 0.06), control: CGPoint(x: r * 0.64, y: r * 0.32))
            let c = SKShapeNode(path: chain)
            c.strokeColor = who.accent
            c.lineWidth = 2
            face.addChild(c)
            face.addChild(moustache(width: r * 0.46, droop: r * 0.06, radius: r, color: who.hair))

        case .bald:
            // A gleaming dome, a fringe round the back, and a moustache you
            // could hang washing on.
            let shine = SKShapeNode(ellipseOf: CGSize(width: r * 0.42, height: r * 0.18))
            shine.fillColor = SKColor(white: 1, alpha: 0.35)
            shine.strokeColor = .clear
            shine.position = CGPoint(x: -r * 0.28, y: r * 0.80)
            shine.zRotation = 0.35
            top.addChild(shine)
            for side in [-1.0, 1.0] as [CGFloat] {
                let fringe = SKShapeNode(ellipseOf: CGSize(width: r * 0.20, height: r * 0.34))
                fringe.fillColor = who.hair
                fringe.strokeColor = who.hairEdge
                fringe.lineWidth = 2
                fringe.position = CGPoint(x: side * r * 0.84, y: r * 0.40)
                fringe.zRotation = side * 0.3
                top.addChild(fringe)
            }
            face.addChild(moustache(width: r * 0.70, droop: -r * 0.10, radius: r, color: who.hair))
        }
    }

    /// A moustache under the eyes. Negative droop curls the ends upward.
    private static func moustache(width w: CGFloat, droop: CGFloat, radius r: CGFloat, color: SKColor) -> SKShapeNode {
        let y = r * 0.28
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: y + r * 0.02))
        p.addQuadCurve(to: CGPoint(x: -w / 2, y: y - droop), control: CGPoint(x: -w * 0.30, y: y + r * 0.10))
        p.addQuadCurve(to: CGPoint(x: 0, y: y - r * 0.06), control: CGPoint(x: -w * 0.26, y: y - r * 0.08))
        p.addQuadCurve(to: CGPoint(x: w / 2, y: y - droop), control: CGPoint(x: w * 0.26, y: y - r * 0.08))
        p.addQuadCurve(to: CGPoint(x: 0, y: y + r * 0.02), control: CGPoint(x: w * 0.30, y: y + r * 0.10))
        p.closeSubpath()
        let node = SKShapeNode(path: p)
        node.fillColor = color
        node.strokeColor = Palette.ink.withAlphaComponent(0.6)
        node.lineWidth = 2
        return node
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
