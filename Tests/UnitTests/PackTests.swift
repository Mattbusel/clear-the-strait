import XCTest

@testable import ClearTheStrait

/// The Blowhard Pack: that every twist is still a fair round, that the lines
/// fit in a bubble, and that only people who bought the paid app get the pack
/// for nothing.
final class PackTests: XCTestCase {

    func testThereIsOneFreeBlowhardAndThreeInThePack() {
        XCTAssertEqual(Blowhard.all.count, 4)
        XCTAssertEqual(Blowhard.all.filter { !$0.isPack }.map(\.id), [.blowhard])
        XCTAssertEqual(Blowhard.pack.count, 3)
        XCTAssertEqual(Blowhard.with(.blowhard).twist, .standard, "the free round must play exactly as it did")
    }

    func testNoTwistMakesARoundUnwinnableOrTrivial() {
        for who in Blowhard.all {
            let t = who.twist
            // The escape bar may rise a little, never a lot, and never drop.
            XCTAssertGreaterThanOrEqual(t.escape, 1, who.name)
            XCTAssertLessThanOrEqual(t.escape, 1.2, who.name)
            // Unpopped, bubbles may not inflate him much faster than the
            // original does, or TREMENDOUS MODE arrives before the rhythm can.
            for phase in [Phase.ego, .traffic, .tremendous] {
                let base = Twist.standard.unpoppedEgoRate(in: phase)
                XCTAssertLessThanOrEqual(t.unpoppedEgoRate(in: phase), base * 1.1, "\(who.name) in \(phase)")
            }
            // Popping always helps, and a returning bubble always gives time
            // to react.
            XCTAssertGreaterThan(Ego.popLoss * t.popLoss, 3, who.name)
            XCTAssertGreaterThanOrEqual(2.6 * t.bubbleReturn, 1.8, who.name)
            XCTAssertGreaterThanOrEqual(t.launch, 1, who.name)
        }
    }

    func testTheTycoonsHeftPaysOffInDistance() {
        var ego = Ego()
        ego.absorb()
        let plain = Escape.distance(momentum: 4000, ego: ego, comboBest: 10)
        let tycoon = plain * Blowhard.tycoon.twist.launch
        XCTAssertGreaterThan(tycoon, plain * 1.3)
    }

    func testTheMayorsPopsHitHarder() {
        var plain = Ego()
        var mayor = Ego()
        for _ in 0..<5 { plain.absorb(); mayor.absorb() }
        plain.pop()
        mayor.pop(scale: Blowhard.mayor.twist.popLoss)
        XCTAssertLessThan(mayor.percent, plain.percent)
    }

    func testEveryLineFitsABubbleAndHasNoDashes() {
        for who in Blowhard.all {
            XCTAssertGreaterThanOrEqual(who.quotes.count, 10, who.name)
            for line in who.quotes {
                XCTAssertLessThanOrEqual(line.count, 42, line)
                XCTAssertEqual(line, line.uppercased(), line)
                XCTAssertFalse(line.contains("\u{2014}"), line)
                XCTAssertFalse(line.contains("\u{2013}"), line)
            }
            XCTAssertFalse(who.twistLine.contains("\u{2014}"))
            XCTAssertFalse(who.blurb.contains("\u{2014}"))
        }
    }

    func testOnlyPaidBuildsAreGrandfathered() {
        // Builds 1 and 2 were the $1.99 app.
        XCTAssertTrue(PackStore.isPaidEra(originalAppVersion: "1"))
        XCTAssertTrue(PackStore.isPaidEra(originalAppVersion: "2"))
        // The first free build and everything after pay for the pack.
        XCTAssertFalse(PackStore.isPaidEra(originalAppVersion: "3"))
        XCTAssertFalse(PackStore.isPaidEra(originalAppVersion: "12"))
        // Anything unreadable is not guessed to be a paid install.
        XCTAssertFalse(PackStore.isPaidEra(originalAppVersion: ""))
        XCTAssertFalse(PackStore.isPaidEra(originalAppVersion: "beta"))
    }
}
