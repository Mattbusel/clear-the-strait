import SpriteKit

/// The place. Deliberately nowhere.
///
/// Blue water, two soft headlands, toy container ships, a couple of buoys. No
/// flags, no coastline anyone could name, no maps, no military anything. The
/// channel is called "the channel" in every string in this app, and that is a
/// content decision as much as an art one: the joke is a fat man stuck in some
/// water, and attaching it to a real place would make it a different and much
/// worse joke.
enum Palette {
    static let deepWater = SKColor(red: 0.06, green: 0.42, blue: 0.64, alpha: 1)
    static let water = SKColor(red: 0.13, green: 0.60, blue: 0.82, alpha: 1)
    static let shallow = SKColor(red: 0.35, green: 0.80, blue: 0.90, alpha: 1)
    static let foam = SKColor(red: 0.90, green: 0.98, blue: 1.00, alpha: 1)

    static let land = SKColor(red: 0.44, green: 0.78, blue: 0.44, alpha: 1)
    static let landEdge = SKColor(red: 0.30, green: 0.60, blue: 0.34, alpha: 1)
    static let sand = SKColor(red: 0.97, green: 0.89, blue: 0.66, alpha: 1)

    static let suit = SKColor(red: 0.16, green: 0.26, blue: 0.52, alpha: 1)
    static let suitEdge = SKColor(red: 0.10, green: 0.16, blue: 0.36, alpha: 1)
    static let shirt = SKColor(red: 0.98, green: 0.98, blue: 1.00, alpha: 1)
    static let tie = SKColor(red: 0.88, green: 0.16, blue: 0.22, alpha: 1)
    static let hair = SKColor(red: 0.98, green: 0.84, blue: 0.42, alpha: 1)
    static let hairEdge = SKColor(red: 0.86, green: 0.68, blue: 0.24, alpha: 1)
    static let blush = SKColor(red: 1.00, green: 0.52, blue: 0.52, alpha: 1)
    static let mouth = SKColor(red: 0.62, green: 0.20, blue: 0.26, alpha: 1)
    static let mouthEdge = SKColor(red: 0.36, green: 0.10, blue: 0.14, alpha: 1)
    static let ink = SKColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 1)

    static let hull = SKColor(red: 0.92, green: 0.30, blue: 0.28, alpha: 1)
    static let hullAlt = SKColor(red: 0.98, green: 0.72, blue: 0.20, alpha: 1)
    static let deck = SKColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1)

    static let bubble = SKColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.96)
    static let bubbleEdge = SKColor(red: 0.20, green: 0.30, blue: 0.50, alpha: 1)
}

/// The water, the land and the gap between them.
final class Channel: SKNode {

    /// Half the vertical opening, in points. The blocker at 100% ego is a
    /// comfortable fit; inflated, he jams.
    private(set) var halfGap: CGFloat = 0
    private(set) var size: CGSize = .zero

    func build(in size: CGSize) {
        removeAllChildren()
        self.size = size
        // A fraction of the screen with no low cap. Capped at 190 points this
        // was a thin band across a tall phone with most of the screen given
        // over to empty land.
        halfGap = size.height * 0.32

        let water = SKSpriteNode(color: Palette.water, size: size)
        water.position = CGPoint(x: size.width / 2, y: size.height / 2)
        water.zPosition = -100
        addChild(water)

        // A darker band down the middle reads as depth and, more usefully,
        // tells the player where the shipping lane is without a label.
        let lane = SKSpriteNode(color: Palette.deepWater, size: CGSize(width: size.width, height: halfGap * 2))
        lane.position = CGPoint(x: size.width / 2, y: size.height / 2)
        lane.alpha = 0.38
        lane.zPosition = -99
        addChild(lane)

        addHeadland(top: true, in: size)
        addHeadland(top: false, in: size)
        addBuoys(in: size)
        addSparkle(in: size)
    }

    private func addHeadland(top: Bool, in size: CGSize) {
        let midY = size.height / 2
        let edge = top ? midY + halfGap : midY - halfGap
        let outer = top ? size.height + 40 : -40

        // A soft lumpy coast rather than a straight wall, so it reads as land.
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -40, y: edge))
        let lumps = 7
        for i in 0...lumps {
            let t = CGFloat(i) / CGFloat(lumps)
            let x = -40 + t * (size.width + 80)
            let wobbleAmount: CGFloat = top ? 1 : -1
            let y = edge + sin(t * 7.3) * 16 * wobbleAmount
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: size.width + 40, y: outer))
        path.addLine(to: CGPoint(x: -40, y: outer))
        path.closeSubpath()

        let land = SKShapeNode(path: path)
        land.fillColor = Palette.land
        land.strokeColor = Palette.sand
        land.lineWidth = 7
        land.zPosition = -60
        addChild(land)

        // The physics edge is a straight line at the gap, not the lumpy art.
        // A wobbly collision edge would make the wedge feel random.
        let wall = SKNode()
        let body = SKPhysicsBody(edgeFrom: CGPoint(x: -60, y: edge),
                                 to: CGPoint(x: size.width + 60, y: edge))
        body.categoryBitMask = Category.shore
        body.friction = 0.7
        body.restitution = 0.3
        wall.physicsBody = body
        addChild(wall)
    }

    private func addBuoys(in size: CGSize) {
        for (x, top) in [(size.width * 0.18, true), (size.width * 0.72, false),
                         (size.width * 0.86, true)] {
            let buoy = SKNode()
            let ball = SKShapeNode(circleOfRadius: 9)
            ball.fillColor = Palette.hullAlt
            ball.strokeColor = Palette.ink
            ball.lineWidth = 2
            buoy.addChild(ball)
            let y = size.height / 2 + (top ? halfGap - 26 : -halfGap + 26)
            buoy.position = CGPoint(x: x, y: y)
            buoy.zPosition = -50
            buoy.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 5, duration: 1.1),
                .moveBy(x: 0, y: -5, duration: 1.1),
            ])))
            addChild(buoy)
        }
    }

    /// A few drifting highlights, so the water is not a flat rectangle.
    private func addSparkle(in size: CGSize) {
        for i in 0..<14 {
            let t = CGFloat(i) / 14
            let dash = SKShapeNode(rectOf: CGSize(width: 26, height: 4), cornerRadius: 2)
            dash.fillColor = Palette.shallow
            dash.strokeColor = .clear
            dash.alpha = 0.4
            dash.position = CGPoint(x: t * size.width + 20,
                                    y: size.height * (0.12 + 0.76 * ((t * 3.7).truncatingRemainder(dividingBy: 1))))
            dash.zPosition = -80
            dash.run(.repeatForever(.sequence([
                .moveBy(x: 30, y: 0, duration: 3.4 + Double(i % 5) * 0.4),
                .moveBy(x: -30, y: 0, duration: 0),
            ])))
            addChild(dash)
        }
    }
}

/// A toy container ship.
///
/// Cargo only. No naval vessels, no weapons, no flags, nothing with a nation
/// attached to it.
final class Ship: SKNode {

    let laneY: CGFloat
    private(set) var hasPassed = false

    init(width: CGFloat, laneY: CGFloat, tint: SKColor) {
        self.laneY = laneY
        super.init()

        let hullPath = CGMutablePath()
        let w = width
        let h = width * 0.32
        hullPath.move(to: CGPoint(x: -w / 2, y: h / 2))
        hullPath.addLine(to: CGPoint(x: w * 0.32, y: h / 2))
        hullPath.addQuadCurve(to: CGPoint(x: w / 2, y: 0),
                              control: CGPoint(x: w * 0.5, y: h * 0.42))
        hullPath.addQuadCurve(to: CGPoint(x: w * 0.32, y: -h / 2),
                              control: CGPoint(x: w * 0.5, y: -h * 0.42))
        hullPath.addLine(to: CGPoint(x: -w / 2, y: -h / 2))
        hullPath.closeSubpath()

        let hull = SKShapeNode(path: hullPath)
        hull.fillColor = tint
        hull.strokeColor = Palette.ink
        hull.lineWidth = 2.5
        addChild(hull)

        // Containers, because a ship without boxes is just a shoe.
        let colors: [SKColor] = [Palette.deck, Palette.hullAlt, Palette.shallow, Palette.foam]
        for i in 0..<5 {
            let box = SKShapeNode(rectOf: CGSize(width: w * 0.11, height: h * 0.34), cornerRadius: 2)
            box.fillColor = colors[i % colors.count]
            box.strokeColor = Palette.ink
            box.lineWidth = 1.5
            box.position = CGPoint(x: -w * 0.30 + CGFloat(i) * w * 0.13, y: h * 0.18)
            addChild(box)
        }

        let bridge = SKShapeNode(rectOf: CGSize(width: w * 0.12, height: h * 0.42), cornerRadius: 3)
        bridge.fillColor = Palette.deck
        bridge.strokeColor = Palette.ink
        bridge.lineWidth = 2
        bridge.position = CGPoint(x: -w * 0.40, y: h * 0.24)
        addChild(bridge)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: w, height: h))
        body.isDynamic = false
        body.categoryBitMask = Category.ship
        body.contactTestBitMask = Category.blocker
        body.collisionBitMask = 0
        physicsBody = body

        zPosition = -20
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func markPassed() { hasPassed = true }
}
