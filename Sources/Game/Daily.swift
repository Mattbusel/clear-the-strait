import Foundation

/// The Daily Strait: one channel condition and one goal, the same for everyone
/// on the same day, decided by the date alone.
///
/// Pure arithmetic like Rules.swift, so a test can walk a year of days and
/// check that every condition is winnable and every goal is reachable.

/// A day's condition: a twist on the free blowhard's round.
struct Condition: Equatable {
    let id: String
    let name: String
    let line: String
    let twist: Twist

    static let all: [Condition] = [
        Condition(id: "calm", name: "Flat Calm", line: "Nothing odd today. Just him, stuck.", twist: .standard),
        Condition(id: "fog", name: "Fog Bank", line: "He can't stop talking. Small bubbles, lots of them.",
                  twist: Twist(bubbleInterval: 0.6, egoGain: 0.6, popLoss: 0.75)),
        Condition(id: "heavy", name: "Big Lunch", line: "Heavier to budge. Flies much further.",
                  twist: Twist(escape: 1.1, launch: 1.4)),
        Condition(id: "hotair", name: "Hot Air", line: "Every bubble puffs him up more. Pop hard.",
                  twist: Twist(egoGain: 1.3, popLoss: 1.3)),
        Condition(id: "echo", name: "Echo Canyon", line: "His bubbles come home fast.",
                  twist: Twist(bubbleReturn: 0.75)),
        Condition(id: "tailwind", name: "Tailwind", line: "Easier to shift. Shorter flight.",
                  twist: Twist(escape: 0.9, launch: 0.85)),
    ]
}

/// What has to happen in the round for the day to count.
enum Goal: Equatable {
    case launch(metres: Int)
    case clearUnder(seconds: Int)
    case combo(count: Int)
    case popped(count: Int)

    var text: String {
        switch self {
        case .launch(let m): return "LAUNCH HIM \(m.formatted()) m"
        case .clearUnder(let s): return "CLEAR IT IN UNDER \(s) SEC"
        case .combo(let c): return "HIT A x\(c) COMBO"
        case .popped(let c): return "POP \(c) BUBBLES"
        }
    }

    func isMet(by r: RoundResult) -> Bool {
        switch self {
        case .launch(let m): return r.launchMetres >= Double(m)
        case .clearUnder(let s): return r.clearSeconds < Double(s)
        case .combo(let c): return r.maxComboCount >= c
        case .popped(let c): return r.bubblesPopped >= c
        }
    }
}

struct DailyStrait: Equatable {
    /// yyyy-MM-dd in the player's own time zone.
    let day: String
    let condition: Condition
    let goal: Goal
    /// Day number since the game's first daily, for "DAILY #12".
    let number: Int

    static let epoch = "2026-10-09"

    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }

    static func date(_ key: String, calendar: Calendar = .current) -> Date? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    static func daysBetween(_ a: String, _ b: String, calendar: Calendar = .current) -> Int? {
        guard let da = date(a, calendar: calendar), let db = date(b, calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: da, to: db).day
    }

    /// The same day always gives the same strait. A simple integer hash of the
    /// date, not a random generator, so it is identical on every device and OS.
    static func on(_ day: String) -> DailyStrait {
        var h: UInt64 = 1469598103934665603
        for b in day.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        let condition = Condition.all[Int(h % UInt64(Condition.all.count))]
        let g = (h >> 8) % 4
        let step = Int((h >> 16) % 3)
        let goal: Goal
        switch g {
        case 0: goal = .launch(metres: [15_000, 25_000, 40_000][step])
        case 1: goal = .clearUnder(seconds: [80, 65, 55][step])
        case 2: goal = .combo(count: [10, 15, 20][step])
        default: goal = .popped(count: [6, 10, 14][step])
        }
        let number = max(1, (daysBetween(epoch, day) ?? 0) + 1)
        return DailyStrait(day: day, condition: condition, goal: goal, number: number)
    }

    static var today: DailyStrait { on(key(Date())) }
}

// MARK: - Medals

/// Earned by playing. Some of them unlock a launch trail.
struct Medal: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
    let symbol: String
    /// The trail it unlocks, if any.
    let unlocks: TrailStyle?

    static let all: [Medal] = [
        Medal(id: "first", name: "Cleared", detail: "Clear your first strait.", symbol: "flag.checkered", unlocks: nil),
        Medal(id: "combo15", name: "In the Groove", detail: "Hit a x15 combo.", symbol: "metronome.fill", unlocks: nil),
        Medal(id: "combo30", name: "Metronome", detail: "Hit a x30 combo.", symbol: "waveform.path", unlocks: .comet),
        Medal(id: "tremendous", name: "Tremendous", detail: "Let his ego reach Tremendous Mode.", symbol: "crown.fill", unlocks: nil),
        Medal(id: "needle", name: "Needle", detail: "Pop 15 bubbles in one round.", symbol: "pin.fill", unlocks: nil),
        Medal(id: "quick", name: "Quick Shove", detail: "Clear a strait in under 50 seconds.", symbol: "bolt.fill", unlocks: nil),
        Medal(id: "far", name: "Long Haul", detail: "Launch him 30,000 m.", symbol: "arrow.up.right", unlocks: nil),
        Medal(id: "moon", name: "Moonshot", detail: "Launch him 100,000 m.", symbol: "moon.stars.fill", unlocks: .gold),
        Medal(id: "ships", name: "Harbour Master", detail: "Free 25 ships in one round.", symbol: "ferry.fill", unlocks: nil),
        Medal(id: "rounds10", name: "Regular", detail: "Clear 10 straits.", symbol: "10.circle.fill", unlocks: .smoke),
        Medal(id: "rounds50", name: "Old Salt", detail: "Clear 50 straits.", symbol: "50.circle.fill", unlocks: nil),
        Medal(id: "daily", name: "Daily Driver", detail: "Beat a Daily Strait.", symbol: "calendar", unlocks: nil),
        Medal(id: "streak7", name: "Week Streak", detail: "Beat the Daily Strait 7 days running.", symbol: "flame.fill", unlocks: nil),
    ]

    /// Medals a finished round earns, given career totals after it.
    static func earned(by r: RoundResult, rounds: Int, dailyWon: Bool, streak: Int) -> [String] {
        var out: [String] = ["first"]
        if r.maxComboCount >= 15 { out.append("combo15") }
        if r.maxComboCount >= 30 { out.append("combo30") }
        if r.maxEgoPercent >= Ego.tremendousThreshold { out.append("tremendous") }
        if r.bubblesPopped >= 15 { out.append("needle") }
        if r.clearSeconds < 50 { out.append("quick") }
        if r.launchMetres >= 30_000 { out.append("far") }
        if r.launchMetres >= 100_000 { out.append("moon") }
        if r.shipsFreed >= 25 { out.append("ships") }
        if rounds >= 10 { out.append("rounds10") }
        if rounds >= 50 { out.append("rounds50") }
        if dailyWon { out.append("daily") }
        if streak >= 7 { out.append("streak7") }
        return out
    }
}

/// What streams behind him once he is airborne.
enum TrailStyle: String, CaseIterable, Identifiable {
    case spray, smoke, comet, gold, rainbow, fireworks, confetti
    var id: String { rawValue }

    var name: String {
        switch self {
        case .spray: return "Sea Spray"
        case .smoke: return "Smoke"
        case .comet: return "Comet"
        case .gold: return "Gold Coins"
        case .rainbow: return "Rainbow"
        case .fireworks: return "Fireworks"
        case .confetti: return "Confetti"
        }
    }

    /// Part of the Trail Pack purchase rather than earned.
    var isPaid: Bool { self == .rainbow || self == .fireworks || self == .confetti }

    /// The medal that unlocks it, for the locker's "how to get it" line.
    var medal: Medal? { Medal.all.first { $0.unlocks == self } }
}
