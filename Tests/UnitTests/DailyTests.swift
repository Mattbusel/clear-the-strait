import XCTest

@testable import ClearTheStrait

/// The Daily Strait, medals and the 1.2 save file.
final class DailyTests: XCTestCase {

    private func key(_ offset: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: offset, to: DailyStrait.date("2026-10-09")!)!
        return DailyStrait.key(d)
    }

    func testTheSameDayAlwaysGivesTheSameStrait() {
        XCTAssertEqual(DailyStrait.on("2026-11-02"), DailyStrait.on("2026-11-02"))
    }

    func testAYearOfDaysUsesEveryConditionAndEveryKindOfGoal() {
        var conditions = Set<String>()
        var kinds = Set<String>()
        for i in 0..<365 {
            let d = DailyStrait.on(key(i))
            conditions.insert(d.condition.id)
            switch d.goal {
            case .launch: kinds.insert("launch")
            case .clearUnder: kinds.insert("clear")
            case .combo: kinds.insert("combo")
            case .popped: kinds.insert("popped")
            }
            XCTAssertEqual(d.number, i + 1)
        }
        XCTAssertEqual(conditions.count, Condition.all.count)
        XCTAssertEqual(kinds.count, 4)
    }

    /// No condition may bend the rules further than a pack character already does,
    /// which the Loosening tests prove still ends every round.
    func testNoConditionIsHarderThanThePackTwists() {
        let hardestEscape = Blowhard.all.map(\.twist.escape).max() ?? 1
        for c in Condition.all {
            XCTAssertLessThanOrEqual(c.twist.escape, hardestEscape, c.name)
            XCTAssertGreaterThan(c.twist.launch, 0.5, c.name)
            XCTAssertFalse(c.line.contains("\u{2014}"), "no em dashes: \(c.name)")
        }
    }

    func testGoalsAreJudgedOnTheRightNumber() {
        let r = RoundResult(clearSeconds: 52, launchMetres: 26_000, maxComboCount: 16,
                            maxComboTier: .perfect, maxEgoPercent: 140, shipsFreed: 20, bubblesPopped: 11)
        XCTAssertTrue(Goal.launch(metres: 25_000).isMet(by: r))
        XCTAssertFalse(Goal.launch(metres: 40_000).isMet(by: r))
        XCTAssertTrue(Goal.clearUnder(seconds: 55).isMet(by: r))
        XCTAssertFalse(Goal.clearUnder(seconds: 52).isMet(by: r))
        XCTAssertTrue(Goal.combo(count: 15).isMet(by: r))
        XCTAssertTrue(Goal.popped(count: 10).isMet(by: r))
        XCTAssertFalse(Goal.popped(count: 14).isMet(by: r))
    }

    func testMedalsAndTheTrailsTheyUnlock() {
        let r = RoundResult(clearSeconds: 45, launchMetres: 120_000, maxComboCount: 31,
                            maxComboTier: .tremendous, maxEgoPercent: 230, shipsFreed: 30, bubblesPopped: 16)
        let got = Set(Medal.earned(by: r, rounds: 10, dailyWon: true, streak: 7))
        XCTAssertEqual(got, Set(Medal.all.map(\.id)).subtracting(["rounds50", "season"]))
        for t in TrailStyle.allCases where !t.isPaid && t != .spray {
            XCTAssertNotNil(t.medal, "\(t.name) has no way to earn it")
        }
    }

    /// An install from 1.1 has no career at all, and a later field may be missing.
    func testAnEmptyOrPartialSaveDecodes() throws {
        let empty = try JSONDecoder().decode(Career.self, from: Data("{}".utf8))
        XCTAssertEqual(empty, Career())
        let partial = try JSONDecoder().decode(Career.self, from: Data(#"{"rounds": 4, "streak": 2}"#.utf8))
        XCTAssertEqual(partial.rounds, 4)
        XCTAssertEqual(partial.streak, 2)
        XCTAssertEqual(partial.trail, TrailStyle.spray.rawValue)
    }

    func testDaysBetweenCountsCalendarDays() {
        XCTAssertEqual(DailyStrait.daysBetween("2026-10-09", "2026-10-10"), 1)
        XCTAssertEqual(DailyStrait.daysBetween("2026-12-31", "2027-01-02"), 2)
        XCTAssertNil(DailyStrait.daysBetween("", "2027-01-02"))
    }
}
