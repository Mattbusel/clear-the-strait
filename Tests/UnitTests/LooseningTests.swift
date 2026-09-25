import XCTest

@testable import ClearTheStrait

/// The escape meter that makes every round end.
///
/// Version 1.0 could run forever: momentum never built past about a third of
/// the bar. These tests pin the replacement to the design's claims: steady
/// rhythm frees him in a sensible time, a few shoves never do, mashing does
/// not work, and nothing goes on forever.
final class LooseningTests: XCTestCase {

    /// Seconds until he is free, tapping every `interval` seconds, or nil if
    /// he is still stuck after `limit` seconds. Ego is held fixed.
    private func timeToFree(interval: Double, tiers: [ComboTier], egoPercent: Double = 100,
                            twist: Twist = .standard, limit: Double = 400) -> Double? {
        var ego = Ego()
        while ego.percent < egoPercent { ego.absorb() }
        var loose = Loosening()
        var combo = Combo()
        let dt = 1.0 / 60
        var t = 0.0
        var nextTap = 0.0
        var lastTap = -10.0
        var i = 0
        while t < limit {
            loose.tick(seconds: dt)
            if t >= nextTap {
                let tier = tiers[i % tiers.count]
                i += 1
                combo.register(tier)
                let bar = Escape.threshold(ego: ego) * twist.escape * Loosening.relief(elapsed: t)
                loose.shove(tier: tier, streak: combo.streakBonus, bar: bar, sinceLast: t - lastTap)
                lastTap = t
                nextTap = t + interval
            }
            if loose.isFree { return t }
            t += dt
        }
        return nil
    }

    func testSteadyRhythmFreesHimInAFairTime() throws {
        let t = try XCTUnwrap(timeToFree(interval: 0.4, tiers: [.great]))
        XCTAssertGreaterThan(t, 8, "a few seconds of tapping should never be enough")
        XCTAssertLessThan(t, 60)
    }

    func testEvenPlainGoodTappingEndsTheRound() throws {
        // What the autoplayed App Review round does, and what a new player does.
        let t = try XCTUnwrap(timeToFree(interval: 0.47, tiers: [.good]))
        XCTAssertLessThan(t, 90)
    }

    func testBetterTimingIsFaster() throws {
        let good = try XCTUnwrap(timeToFree(interval: 0.4, tiers: [.good]))
        let perfect = try XCTUnwrap(timeToFree(interval: 0.4, tiers: [.perfect]))
        XCTAssertLessThan(perfect, good * 0.75)
    }

    func testAFewShovesAreNeverEnough() {
        var ego = Ego()
        let bar = Escape.threshold(ego: ego)
        var loose = Loosening()
        var combo = Combo()
        for _ in 0..<6 {
            combo.register(.tremendous)
            loose.shove(tier: .tremendous, streak: combo.streakBonus, bar: bar, sinceLast: 1)
        }
        XCTAssertFalse(loose.isFree)
        ego.pop()
    }

    func testMashingDoesNotWork() throws {
        // Ten taps a second, half of them on the wrong side.
        let mash = timeToFree(interval: 0.1, tiers: [.good, .miss], limit: 55)
        let rhythm = try XCTUnwrap(timeToFree(interval: 0.4, tiers: [.great]))
        if let mash {
            XCTAssertGreaterThan(mash, rhythm * 2)
        }
    }

    func testEveryRoundEndsEvenAtHighEgoWithTheHardestTwist() throws {
        let hardest = Blowhard.all.map(\.twist).max { $0.escape < $1.escape } ?? .standard
        let t = try XCTUnwrap(timeToFree(interval: 0.5, tiers: [.good], egoPercent: 160, twist: hardest))
        XCTAssertLessThan(t, 180)
    }

    func testEveryPackCharacterCanBeFreed() throws {
        for who in Blowhard.all {
            let t = try XCTUnwrap(timeToFree(interval: 0.45, tiers: [.good], twist: who.twist), who.name)
            XCTAssertLessThan(t, 100, who.name)
        }
    }

    func testReliefOnlyStartsLateAndHasAFloor() {
        XCTAssertEqual(Loosening.relief(elapsed: 0), 1)
        XCTAssertEqual(Loosening.relief(elapsed: 59), 1)
        XCTAssertLessThan(Loosening.relief(elapsed: 90), 1)
        XCTAssertEqual(Loosening.relief(elapsed: 10_000), Loosening.reliefFloor)
        XCTAssertEqual(Loosening.relief(elapsed: .nan), 1)
    }

    func testIgnoringBubblesOrMashingStillEndsTheRound() {
        // Ego at the ceiling (nobody popped a bubble), or half the taps missed:
        // the meter alone may never get there, so the clock has to.
        XCTAssertNil(timeToFree(interval: 0.47, tiers: [.good], egoPercent: Ego.maximum, limit: Loosening.giveUpAfter))
        XCTAssertFalse(Loosening.mustEnd(elapsed: Loosening.giveUpAfter - 0.1))
        XCTAssertTrue(Loosening.mustEnd(elapsed: Loosening.giveUpAfter))
        XCTAssertFalse(Loosening.mustEnd(elapsed: .nan))
        XCTAssertGreaterThan(Loosening.giveUpAfter, 120, "the cap is a backstop, not the normal ending")
    }

    func testTheWedgeTightensWhenLeftAlone() {
        var loose = Loosening()
        loose.shove(tier: .perfect, streak: 1.5, bar: 1000, sinceLast: 1)
        let before = loose.progress
        loose.tick(seconds: 10)
        XCTAssertLessThan(loose.progress, before)
        XCTAssertGreaterThanOrEqual(loose.progress, 0)
    }
}
