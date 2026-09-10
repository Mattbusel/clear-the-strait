import XCTest

@testable import ClearTheStrait

/// Tests for the game's feel, not just its arithmetic.
///
/// Every one of these checks a claim the design makes: that rhythm beats
/// mashing, that popping bubbles visibly helps, that a great run launches far
/// further than an adequate one. Those are the things that would quietly stop
/// being true after a tuning change, and on a machine that cannot run the game
/// they are the only way to know it still works.
final class RulesTests: XCTestCase {

    // MARK: - Timing

    func testShovingWithHisMotionBeatsShovingAgainstIt() {
        let peak = 300.0
        // He is moving right at speed. Tapping his left side pushes right, with
        // him.
        XCTAssertEqual(judge(tap: .left, velocityX: 280, peakSpeed: peak), .tremendous)
        // Tapping his right side pushes left, into him.
        XCTAssertEqual(judge(tap: .right, velocityX: 280, peakSpeed: peak), .miss)
    }

    func testTheFirstShoveOfARockIsAlwaysCredited() {
        // From a standstill neither side is wrong, and punishing the opening tap
        // would make the start of every round feel arbitrary.
        XCTAssertNotEqual(judge(tap: .left, velocityX: 0, peakSpeed: 300), .miss)
        XCTAssertNotEqual(judge(tap: .right, velocityX: 0, peakSpeed: 300), .miss)
    }

    func testTiersRiseWithHowWellTimedTheShoveIs() {
        let peak = 300.0
        let tiers = [30.0, 120.0, 210.0, 290.0].map {
            judge(tap: .left, velocityX: $0, peakSpeed: peak)
        }
        XCTAssertEqual(tiers, [.good, .great, .perfect, .tremendous])
    }

    func testMashingIsWorseThanRhythm() {
        // The central design claim. A player who taps in time with the rock
        // should meaningfully out-perform one who taps as fast as possible on
        // random sides.
        //
        // Simulated over one full oscillation, comparing total impulse earned.
        let peak = 300.0
        let samples = 400

        var rhythmic = 0.0
        var mashing = 0.0
        var seed: UInt64 = 0xC0FFEE

        func nextBool() -> Bool {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return (seed >> 33) & 1 == 0
        }

        var rhythmCombo = Combo()
        var mashCombo = Combo()

        for i in 0..<samples {
            let t = Double(i) / Double(samples) * 4 * .pi
            let velocity = sin(t) * peak

            // Rhythmic: always shoves the way he is already going.
            let smart: TapSide = velocity >= 0 ? .left : .right
            let smartTier = judge(tap: smart, velocityX: velocity, peakSpeed: peak)
            rhythmCombo.register(smartTier)
            rhythmic += smartTier.impulseScale * rhythmCombo.streakBonus

            // Mashing: picks a side without looking.
            let dumb: TapSide = nextBool() ? .left : .right
            let dumbTier = judge(tap: dumb, velocityX: velocity, peakSpeed: peak)
            mashCombo.register(dumbTier)
            mashing += dumbTier.impulseScale * mashCombo.streakBonus
        }

        XCTAssertGreaterThan(
            rhythmic, mashing * 1.8,
            "rhythm earned \(Int(rhythmic)) against mashing's \(Int(mashing)); "
                + "the gap is too small for players to feel the difference"
        )
    }

    // MARK: - Combo

    func testAMissEndsTheRunRatherThanDentingIt() {
        var combo = Combo()
        for _ in 0..<6 { combo.register(.perfect) }
        XCTAssertEqual(combo.count, 6)
        combo.register(.miss)
        XCTAssertEqual(combo.count, 0, "a combo that survives mistakes is not a combo")
        XCTAssertEqual(combo.best, 6, "but the best run still stands")
    }

    func testStreakBonusIsCapped() {
        var combo = Combo()
        for _ in 0..<500 { combo.register(.tremendous) }
        XCTAssertLessThanOrEqual(
            combo.streakBonus, 1.6,
            "an uncapped streak makes the back half of a good run trivial"
        )
    }

    // MARK: - Ego

    func testEgoMakesHimBiggerAndDisproportionatelyHeavier() {
        var ego = Ego()
        let startRadius = ego.radiusScale
        let startMass = ego.massScale

        for _ in 0..<10 { ego.absorb() }

        XCTAssertGreaterThan(ego.radiusScale, startRadius)
        XCTAssertGreaterThan(ego.massScale, startMass)
        // Mass has to outrun radius, or the player feels the difficulty spike
        // only after it has already buried them.
        let radiusGrowth = ego.radiusScale / startRadius
        let massGrowth = ego.massScale / startMass
        XCTAssertGreaterThan(
            massGrowth, radiusGrowth * 1.5,
            "he should get heavy faster than he gets fat"
        )
    }

    func testPoppingBubblesVisiblyLowersTheBarToEscape() {
        var ego = Ego()
        for _ in 0..<8 { ego.absorb() }
        let inflated = Escape.threshold(ego: ego)

        for _ in 0..<8 { ego.pop() }
        let deflated = Escape.threshold(ego: ego)

        XCTAssertLessThan(
            deflated, inflated * 0.8,
            "popping has to pay off obviously enough that players choose it"
        )
    }

    func testEgoHasAFloorSoHeIsNeverTrivial() {
        var ego = Ego()
        for _ in 0..<200 { ego.pop() }
        XCTAssertEqual(ego.percent, Ego.minimum)
        XCTAssertGreaterThan(Escape.threshold(ego: ego), 0)
    }

    func testPeakEgoIsRememberedForTheResultScreen() {
        var ego = Ego()
        for _ in 0..<12 { ego.absorb() }
        let high = ego.percent
        for _ in 0..<12 { ego.pop() }
        XCTAssertEqual(ego.peak, high)
        XCTAssertLessThan(ego.percent, ego.peak)
    }

    // MARK: - Phases

    func testPhasesAdvanceOnTheClock() {
        let calm = Ego()
        XCTAssertEqual(Phase.at(elapsed: 2, ego: calm), .settling)
        XCTAssertEqual(Phase.at(elapsed: 15, ego: calm), .ego)
        XCTAssertEqual(Phase.at(elapsed: 30, ego: calm), .traffic)
        XCTAssertEqual(Phase.at(elapsed: 60, ego: calm), .tremendous)
    }

    func testRunawayEgoPromotesToTremendousEarly() {
        var ego = Ego()
        for _ in 0..<20 { ego.absorb() }
        XCTAssertTrue(ego.isTremendous)
        XCTAssertEqual(
            Phase.at(elapsed: 3, ego: ego), .tremendous,
            "letting him inflate should escalate the round, not just slow it"
        )
    }

    func testTheSettlingPhaseSendsNoBubbles() {
        XCTAssertFalse(Phase.settling.bubbleInterval.isFinite)
        XCTAssertEqual(Phase.settling.egoDrift, 0)
    }

    // MARK: - Launch

    func testABetterRunLaunchesDramaticallyFurther() {
        let ego = Ego()
        let ordinary = Escape.distance(momentum: 500, ego: ego, comboBest: 4)
        let excellent = Escape.distance(momentum: 900, ego: ego, comboBest: 18)
        XCTAssertGreaterThan(
            excellent, ordinary * 2.5,
            "the launch is the payoff; a great run has to look like one"
        )
    }

    func testAFatterBlockerCarriesFurther() {
        var heavy = Ego()
        for _ in 0..<10 { heavy.absorb() }
        let light = Escape.distance(momentum: 700, ego: Ego(), comboBest: 8)
        let fat = Escape.distance(momentum: 700, ego: heavy, comboBest: 8)
        XCTAssertGreaterThan(
            fat, light,
            "deliberately inflating him then launching should be a real strategy"
        )
    }

    func testEscapeNeedsMoreMomentumWhenHeIsPleasedWithHimself() {
        var ego = Ego()
        let easy = Escape.threshold(ego: ego)
        for _ in 0..<10 { ego.absorb() }
        XCTAssertGreaterThan(Escape.threshold(ego: ego), easy * 1.3)
    }

    func testEscapeTakesSustainedRhythmNotAFewShoves() {
        // The bug this pins. With the threshold at 420 a round ended in four
        // seconds: two ordinary shoves cleared it, before a single speech
        // bubble had appeared. A round is meant to run 45 to 120 seconds.
        let ego = Ego()
        let bar = Escape.threshold(ego: ego)

        // A burst of mashing: five shoves, no combo to speak of.
        var mash = Combo()
        var mashMomentum = 0.0
        for _ in 0..<5 {
            mash.register(.good)
            mashMomentum += Escape.shoveMomentum(tier: .good, streak: mash.streakBonus)
        }
        XCTAssertLessThan(
            mashMomentum, bar,
            "a five shove burst should not clear the wedge"
        )

        // A sustained, well-timed run should get there.
        var rhythm = Combo()
        var rhythmMomentum = 0.0
        for _ in 0..<12 {
            rhythm.register(.perfect)
            rhythmMomentum += Escape.shoveMomentum(tier: .perfect, streak: rhythm.streakBonus)
        }
        XCTAssertGreaterThan(
            rhythmMomentum, bar,
            "a dozen perfect shoves should launch him, or the game is unwinnable"
        )
    }

    // MARK: - Safety

    func testNothingProducesANaN() {
        // Every one of these reaches the physics or the UI, and a NaN in either
        // is a frozen screen rather than a visible error.
        let egos = [Ego()]
        for ego in egos {
            for momentum in [0.0, -50, 1e9, .infinity, .nan] {
                let d = Escape.distance(momentum: momentum, ego: ego, comboBest: 3)
                XCTAssertTrue(d.isFinite, "distance from momentum \(momentum)")
                XCTAssertGreaterThanOrEqual(d, 0)
            }
            XCTAssertTrue(ego.radiusScale.isFinite)
            XCTAssertTrue(ego.massScale.isFinite)
            XCTAssertTrue(Escape.threshold(ego: ego).isFinite)
        }
        for v in [0.0, .infinity, .nan, -1e9] {
            _ = judge(tap: .left, velocityX: v, peakSpeed: 300)
        }
        _ = judge(tap: .left, velocityX: 100, peakSpeed: 0)
    }

    // MARK: - Result

    func testShareTextIsOneReadableBlock() {
        let result = RoundResult(
            clearSeconds: 43.72,
            launchMetres: 3481,
            maxComboCount: 18,
            maxComboTier: .tremendous,
            maxEgoPercent: 241,
            shipsFreed: 37
        )
        let text = result.shareText
        XCTAssertTrue(text.contains("43.72"))
        XCTAssertTrue(text.contains("3481"))
        XCTAssertTrue(text.contains("TREMENDOUS x18"))
        XCTAssertTrue(text.contains("241%"))
        XCTAssertLessThan(text.count, 200, "a share blurb nobody will read is not a share blurb")
    }
}
