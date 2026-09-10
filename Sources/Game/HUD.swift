import SpriteKit

/// Two readouts and a banner. That is the whole interface during play.
///
/// Everything here competes with the thing the player is actually watching, so
/// it is kept to what cannot be inferred from the screen: how pleased with
/// himself he is, and how the current run is going. Ships freed and the clock
/// are shown small, because they are for the result screen rather than for
/// decisions.
final class HUD: SKNode {

    private let egoLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let egoTrack = SKShapeNode()
    private let egoFill = SKShapeNode()
    private let escapeFill = SKShapeNode()
    private let comboLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let statsLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let bannerLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")

    private var barWidth: CGFloat = 0

    func build(in size: CGSize) {
        removeAllChildren()

        let margin: CGFloat = 22
        let top = size.height - margin - 18
        barWidth = min(size.width * 0.42, 210)

        egoLabel.text = "EGO"
        egoLabel.fontSize = 13
        egoLabel.fontColor = .white
        egoLabel.horizontalAlignmentMode = .left
        egoLabel.position = CGPoint(x: margin, y: top)
        addChild(egoLabel)

        let trackRect = CGRect(x: margin + 44, y: top - 2, width: barWidth, height: 14)
        egoTrack.path = CGPath(roundedRect: trackRect, cornerWidth: 7, cornerHeight: 7, transform: nil)
        egoTrack.fillColor = SKColor.black.withAlphaComponent(0.28)
        egoTrack.strokeColor = SKColor.white.withAlphaComponent(0.5)
        egoTrack.lineWidth = 2
        addChild(egoTrack)

        egoFill.fillColor = Palette.tie
        egoFill.strokeColor = .clear
        addChild(egoFill)

        // The escape meter sits directly under the ego bar, because the two are
        // the same decision seen from opposite ends: his ego is the bar you are
        // trying to clear.
        escapeFill.fillColor = Palette.hullAlt
        escapeFill.strokeColor = .clear
        addChild(escapeFill)

        comboLabel.text = ""
        comboLabel.fontSize = 26
        comboLabel.fontColor = .white
        comboLabel.horizontalAlignmentMode = .left
        comboLabel.position = CGPoint(x: margin, y: top - 46)
        addChild(comboLabel)

        statsLabel.text = ""
        statsLabel.fontSize = 12
        statsLabel.fontColor = SKColor.white.withAlphaComponent(0.85)
        statsLabel.horizontalAlignmentMode = .right
        statsLabel.position = CGPoint(x: size.width - margin, y: top)
        addChild(statsLabel)

        bannerLabel.text = ""
        bannerLabel.fontSize = 44
        bannerLabel.fontColor = .white
        bannerLabel.horizontalAlignmentMode = .center
        bannerLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        bannerLabel.alpha = 0
        bannerLabel.zPosition = 10
        addChild(bannerLabel)

        updateBars(egoFraction: 0.25, escape: 0)
    }

    private var trackOrigin: CGPoint {
        CGPoint(x: egoTrack.frame.minX, y: egoTrack.frame.minY)
    }

    private func updateBars(egoFraction: CGFloat, escape: CGFloat) {
        let clampedEgo = max(0, min(egoFraction, 1))
        let egoRect = CGRect(x: trackOrigin.x + 2, y: trackOrigin.y + 2,
                             width: max(0, (barWidth - 4) * clampedEgo), height: 10)
        egoFill.path = CGPath(roundedRect: egoRect, cornerWidth: 5, cornerHeight: 5, transform: nil)

        let clampedEscape = max(0, min(escape, 1))
        let escapeRect = CGRect(x: trackOrigin.x + 2, y: trackOrigin.y - 10,
                                width: max(0, (barWidth - 4) * clampedEscape), height: 5)
        escapeFill.path = CGPath(roundedRect: escapeRect, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
        // Goes white when it is about to happen, so the player can feel the
        // launch coming and push for it.
        escapeFill.fillColor = clampedEscape > 0.9 ? .white : Palette.hullAlt
    }

    func update(ego: Ego, combo: Combo, elapsed: TimeInterval) {
        // 400% is the practical ceiling, so the bar maps to that.
        updateBars(egoFraction: CGFloat(ego.percent / 400), escape: lastEscape)

        egoLabel.text = "EGO \(Int(ego.percent))%"

        if combo.isActive {
            comboLabel.text = "\(combo.tier.label) x\(combo.count)"
            comboLabel.fontColor = HUD.color(for: combo.tier)
        } else {
            comboLabel.text = ""
        }

        statsLabel.text = String(format: "%.1fs   %d ships", elapsed, ships)
    }

    private var lastEscape: CGFloat = 0
    private var ships = 0

    func setEscape(progress: Double) {
        lastEscape = CGFloat(max(0, min(progress, 1)))
    }

    func tickShips(_ count: Int) {
        ships = count
    }

    static func color(for tier: ComboTier) -> SKColor {
        switch tier {
        case .miss: return SKColor.white.withAlphaComponent(0.6)
        case .good: return .white
        case .great: return Palette.shallow
        case .perfect: return Palette.hullAlt
        case .tremendous: return Palette.tie
        }
    }

    /// A tap landed. Punch the combo label so the tier registers in peripheral
    /// vision, without the player having to read it.
    func flash(tier: ComboTier, combo: Combo) {
        guard tier != .miss else {
            comboLabel.removeAllActions()
            comboLabel.run(.sequence([
                .group([.scale(to: 0.8, duration: 0.08), .fadeAlpha(to: 0.4, duration: 0.08)]),
                .group([.scale(to: 1, duration: 0.12), .fadeAlpha(to: 1, duration: 0.12)]),
            ]))
            return
        }
        comboLabel.removeAllActions()
        let punch = 1 + CGFloat(tier.rawValue) * 0.09
        comboLabel.run(.sequence([
            .scale(to: punch, duration: 0.07),
            .scale(to: 1, duration: 0.13),
        ]))
    }

    func pulseEgo() {
        egoTrack.removeAllActions()
        egoTrack.run(.sequence([
            .scale(to: 1.12, duration: 0.1),
            .scale(to: 1, duration: 0.16),
        ]))
    }

    func banner(_ text: String) {
        bannerLabel.removeAllActions()
        bannerLabel.text = text
        bannerLabel.setScale(0.6)
        bannerLabel.alpha = 0
        bannerLabel.run(.sequence([
            .group([.fadeIn(withDuration: 0.14), .scale(to: 1.08, duration: 0.18)]),
            .scale(to: 1, duration: 0.1),
            .wait(forDuration: 1.0),
            .fadeOut(withDuration: 0.4),
        ]))
    }
}
