import Foundation

/// The whole game, as arithmetic.
///
/// Nothing in this file imports SpriteKit, UIKit or Foundation beyond the basics.
/// That is deliberate and it is the most important architectural decision in the
/// project: every number that decides how the game *feels* lives here, in pure
/// functions, where a test can check it in milliseconds. The scene is then a
/// thin layer that draws the result.
///
/// The alternative, tuning feel inside a SpriteKit scene, means every tweak
/// costs a simulator boot. On a machine that cannot run Xcode at all, that is
/// the difference between a project that converges and one that does not.

// MARK: - Sides

/// Which half of the blocker was tapped.
///
/// Tapping the left side pushes him right, and vice versa, because you are
/// shoving him, not steering him.
enum TapSide {
    case left
    case right

    /// The direction the shove sends him, as a sign on x.
    var push: Double {
        switch self {
        case .left: return 1
        case .right: return -1
        }
    }
}

// MARK: - Combo

/// How good a tap was.
///
/// Four tiers because the spec asks for four, and because more than four stops
/// being readable at a glance in the middle of a rhythm.
enum ComboTier: Int, CaseIterable, Comparable {
    case miss = 0
    case good = 1
    case great = 2
    case perfect = 3
    case tremendous = 4

    static func < (a: ComboTier, b: ComboTier) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .miss: return "MISS"
        case .good: return "GOOD"
        case .great: return "GREAT"
        case .perfect: return "PERFECT"
        case .tremendous: return "TREMENDOUS"
        }
    }

    /// How much the tap's impulse is multiplied by.
    ///
    /// A miss is not zero. A shove in the wrong direction still moves him, it
    /// just moves him the wrong way, and feeling that is the lesson.
    var impulseScale: Double {
        switch self {
        case .miss: return 0.35
        case .good: return 0.8
        case .great: return 1.15
        case .perfect: return 1.5
        case .tremendous: return 1.9
        }
    }
}

/// Judge a tap against the blocker's current motion.
///
/// The rhythm this creates: he rocks in the channel, and a shove that agrees
/// with the way he is already going adds to it, while one that fights it kills
/// the momentum you had. So the skill is watching him rather than tapping fast,
/// and mashing self-defeats because roughly half of a mash lands on the wrong
/// side of the rock.
///
/// `velocityX` is his current horizontal speed, `peakSpeed` the speed at which
/// timing is considered maximal.
func judge(tap: TapSide, velocityX: Double, peakSpeed: Double) -> ComboTier {
    guard peakSpeed > 0, velocityX.isFinite else { return .good }

    let agreement = tap.push * velocityX          // positive when shoving with him
    let normalized = agreement / peakSpeed        // roughly -1 ... 1

    // From a standstill there is no wrong answer, so the first shove of a rock
    // is always credited. Without this the opening taps feel arbitrary.
    if abs(velocityX) < peakSpeed * 0.08 {
        return .good
    }

    switch normalized {
    case ..<(-0.05): return .miss
    case ..<0.25: return .good
    case ..<0.55: return .great
    case ..<0.85: return .perfect
    default: return .tremendous
    }
}

/// The running combo.
struct Combo {
    private(set) var count: Int = 0
    private(set) var tier: ComboTier = .good
    private(set) var best: Int = 0
    private(set) var bestTier: ComboTier = .good

    /// Whether a combo is currently worth showing.
    var isActive: Bool { count >= 2 }

    /// Fold in a tap and report what it scored.
    @discardableResult
    mutating func register(_ judged: ComboTier) -> ComboTier {
        if judged == .miss {
            // A miss ends the run rather than decrementing it. A combo that
            // survives mistakes is not a combo.
            count = 0
            tier = .miss
            return .miss
        }
        count += 1
        tier = judged
        if count > best {
            best = count
            bestTier = judged
        } else if count == best, judged > bestTier {
            bestTier = judged
        }
        return judged
    }

    /// Extra impulse earned by a long run, on top of the tier's own scale.
    ///
    /// Capped, because an uncapped combo makes the back half of a good run
    /// trivial and the whole thing anticlimactic.
    var streakBonus: Double {
        min(1.0 + Double(count) * 0.04, 1.6)
    }
}

// MARK: - Ego

/// The blocker's self-regard, which is also his size and his mass.
///
/// One number drives all three, which is the joke made mechanical: he is hard
/// to move because he is pleased with himself, and the way to move him is to
/// stop agreeing with him.
struct Ego {
    /// Percent. Starts at 100 and has no ceiling worth speaking of.
    private(set) var percent: Double = 100
    private(set) var peak: Double = 100

    static let minimum: Double = 55
    /// Where TREMENDOUS MODE takes over.
    static let tremendousThreshold: Double = 185

    /// What a returning speech bubble is worth if it reaches him.
    static let bubbleGain: Double = 9
    /// What popping one takes off.
    static let popLoss: Double = 7

    var isTremendous: Bool { percent >= Ego.tremendousThreshold }

    mutating func absorb() {
        percent = min(percent + Ego.bubbleGain, 400)
        peak = max(peak, percent)
    }

    mutating func pop() {
        percent = max(percent - Ego.popLoss, Ego.minimum)
    }

    /// Slow drift back up, so ignoring bubbles entirely is not a strategy.
    mutating func tick(seconds: Double, phase: Phase) {
        percent = min(percent + phase.egoDrift * seconds, 400)
        peak = max(peak, percent)
    }

    /// How much bigger he is drawn, relative to his starting size.
    ///
    /// Deliberately sub-linear. Ego doubling should read as visibly rounder
    /// without him filling the entire channel and hiding the ships.
    var radiusScale: Double {
        pow(percent / 100, 0.42)
    }

    /// How much harder he is to shift.
    ///
    /// Super-linear, unlike the radius, so a high ego is felt in the hands well
    /// before it is obvious in the silhouette.
    var massScale: Double {
        pow(percent / 100, 1.35)
    }
}

// MARK: - Phases

/// What stage of the round we are in.
///
/// Timed rather than score-gated, so a round is a predictable 45 to 120 seconds
/// and the escalation lands the same way every time.
enum Phase: Int, CaseIterable {
    /// Just physics. Learn the rock.
    case settling = 0
    /// Bubbles appear. Ego becomes a thing.
    case ego = 1
    /// Ships crowd in and their wakes shove him about.
    case traffic = 2
    /// Everything, faster.
    case tremendous = 3

    static func at(elapsed: Double, ego: Ego) -> Phase {
        // Ego can promote you early: inflate enough and the last phase starts
        // whether the clock agrees or not.
        if ego.isTremendous { return .tremendous }
        switch elapsed {
        case ..<8: return .settling
        case ..<22: return .ego
        case ..<45: return .traffic
        default: return .tremendous
        }
    }

    /// Seconds between speech bubbles.
    var bubbleInterval: Double {
        switch self {
        case .settling: return .infinity
        case .ego: return 3.4
        case .traffic: return 2.6
        case .tremendous: return 1.2
        }
    }

    /// Ego gained per second just for existing.
    var egoDrift: Double {
        switch self {
        case .settling: return 0
        case .ego: return 0.6
        case .traffic: return 1.1
        case .tremendous: return 2.4
        }
    }

    /// Seconds between ships arriving.
    var shipInterval: Double {
        switch self {
        case .settling: return 4.0
        case .ego: return 3.2
        case .traffic: return 2.0
        case .tremendous: return 1.5
        }
    }

    var banner: String? {
        switch self {
        case .settling, .ego, .traffic: return nil
        case .tremendous: return "TREMENDOUS MODE"
        }
    }
}

// MARK: - Breaking free

/// Whether he comes loose, and how hard he goes when he does.
enum Escape {
    /// Momentum needed to pop out, as a function of how wedged he is.
    ///
    /// Scales with mass rather than radius, so the counterplay is legible: pop
    /// bubbles and the bar you have to clear visibly drops.
    static func threshold(ego: Ego) -> Double {
        420 * ego.massScale
    }

    static func isFreed(momentum: Double, ego: Ego) -> Bool {
        momentum >= threshold(ego: ego)
    }

    /// How far he skips, in metres, once he is out.
    ///
    /// All the accumulated momentum converts at once. The exponent is above one
    /// so a great run is dramatically better than an adequate one, which is the
    /// entire reason to chase a good launch instead of just escaping.
    static func distance(momentum: Double, ego: Ego, comboBest: Int) -> Double {
        guard momentum.isFinite, momentum > 0 else { return 0 }
        let base = pow(momentum / 100, 1.35) * 260
        // A fat blocker carries further once airborne, which rewards the player
        // who deliberately let him inflate and then hit an enormous combo.
        let heft = 0.8 + ego.massScale * 0.35
        let skill = 1.0 + Double(comboBest) * 0.03
        return (base * heft * skill).rounded()
    }
}

// MARK: - Result

/// What the round produced.
struct RoundResult: Equatable {
    var clearSeconds: Double
    var launchMetres: Double
    var maxComboCount: Int
    var maxComboTier: ComboTier
    var maxEgoPercent: Double
    var shipsFreed: Int

    var shareText: String {
        """
        STRAIT CLEARED
        \(String(format: "%.2f", clearSeconds))s  •  \(Int(launchMetres))m
        \(maxComboTier.label) x\(maxComboCount)  •  Ego \(Int(maxEgoPercent))%
        """
    }
}
