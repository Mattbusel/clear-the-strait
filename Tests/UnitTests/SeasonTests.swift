import XCTest

@testable import ClearTheStrait

/// The Club Season: decided by the month alone, three open goals, seven Club
/// goals, and nothing harder than the game already proves winnable.
final class SeasonTests: XCTestCase {

    func testTheSameMonthAlwaysGivesTheSameSeason() {
        XCTAssertEqual(Season.of("2026-11"), Season.of("2026-11"))
        XCTAssertNotEqual(Season.of("2026-11").goals, Season.of("2026-12").goals)
    }

    func testSeasonNumbersCountFromTheFirstSeason() {
        XCTAssertEqual(Season.of("2026-10").number, 1)
        XCTAssertEqual(Season.of("2026-11").number, 2)
        XCTAssertEqual(Season.of("2027-10").number, 13)
        XCTAssertEqual(Season.monthsBetween("2026-12", "2027-01"), 1)
        XCTAssertEqual(Season.of("2026-11").monthName, "NOVEMBER 2026")
    }

    func testTenGoalsThreeOpenWithTheFreeBlowhard() {
        for m in ["2026-10", "2026-11", "2027-02", "2027-07", "2028-01"] {
            let s = Season.of(m)
            XCTAssertEqual(s.goals.count, Season.goalCount, m)
            XCTAssertEqual(s.goals.map(\.index), Array(0..<Season.goalCount), m)
            for g in s.goals.prefix(Season.openGoals) {
                XCTAssertEqual(g.cast, .blowhard, "\(m) goal \(g.number) must be playable without buying anything")
                XCTAssertFalse(g.isClub)
            }
            let club = s.goals.dropFirst(Season.openGoals)
            XCTAssertTrue(club.allSatisfy(\.isClub))
            // Every pack channel turns up in every season.
            XCTAssertTrue(Set([Blowhard.ID.windbag, .tycoon, .mayor]).isSubset(of: Set(club.map(\.cast))), m)
        }
    }

    /// A season goal may never bend the rules further than a pack character or a
    /// daily condition is already allowed to, and never asks for more than the
    /// game's own medals do.
    func testNoGoalIsUnwinnable() {
        for y in 2026...2029 {
            for mo in 1...12 {
                let s = Season.of(String(format: "%04d-%02d", y, mo))
                for g in s.goals {
                    XCTAssertLessThanOrEqual(g.twist.escape, 1.2)
                    XCTAssertGreaterThan(g.twist.launch, 0.5)
                    XCTAssertGreaterThanOrEqual(2.6 * g.twist.bubbleReturn, 1.3)
                    switch g.goal {
                    case .launch(let m): XCTAssertLessThanOrEqual(m, 70_000)
                    case .clearUnder(let sec): XCTAssertGreaterThanOrEqual(sec, 50)
                    case .combo(let c): XCTAssertLessThanOrEqual(c, 30)
                    case .popped(let c): XCTAssertLessThanOrEqual(c, 16)
                    }
                    XCTAssertFalse(s.title.contains("\u{2014}"))
                }
            }
        }
    }

    func testANewSaveFieldDecodesFromAnOldSave() throws {
        let old = try JSONDecoder().decode(Career.self, from: Data(#"{"rounds": 12, "medals": ["first"]}"#.utf8))
        XCTAssertEqual(old.seasonDone, [])
        XCTAssertEqual(old.seasonBadges, [])
        XCTAssertEqual(old.clubShieldMonth, "")
    }

    func testTheSeasonMedalUnlocksTheStarsTrail() {
        XCTAssertEqual(TrailStyle.stars.medal?.id, "season")
        XCTAssertFalse(TrailStyle.stars.isPaid)
    }

    func testGoalSentencesReadAsSentences() {
        XCTAssertEqual(Goal.combo(count: 10).sentence, "Hit a x10 combo")
        XCTAssertEqual(Goal.popped(count: 6).sentence, "Pop 6 bubbles")
    }
}
