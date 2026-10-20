import Foundation

/// The Club Season: ten goals a month, the same for everyone in the same month,
/// decided by the month alone (like the Daily Strait is decided by the day).
///
/// The first three goals are open to every player and always use the free
/// blowhard. Goals four to ten are the Strait Club's: they move through every
/// channel and get harder towards the end. Finishing all ten earns that
/// month's season badge, which is kept for good.
struct SeasonGoal: Identifiable, Equatable {
    /// 0 ... 9.
    let index: Int
    let cast: Blowhard.ID
    let condition: Condition
    let goal: Goal

    var id: Int { index }
    var number: Int { index + 1 }
    /// Needs the Strait Club.
    var isClub: Bool { index >= Season.openGoals }
    var twist: Twist {
        // The channel's own twist, bent by the condition, so a goal in the
        // Tycoon's marina still plays like the marina.
        let base = Blowhard.with(cast).twist
        let c = condition.twist
        return Twist(bubbleInterval: base.bubbleInterval * c.bubbleInterval,
                     egoGain: base.egoGain * c.egoGain,
                     popLoss: base.popLoss * c.popLoss,
                     bubbleReturn: base.bubbleReturn * c.bubbleReturn,
                     escape: min(base.escape * c.escape, 1.2),
                     launch: base.launch * c.launch)
    }
}

struct Season: Equatable {
    static let goalCount = 10
    static let openGoals = 3
    /// The first season.
    static let epoch = "2026-10"

    /// yyyy-MM.
    let month: String
    /// Season number since the first one, for "SEASON 2".
    let number: Int
    let title: String
    let goals: [SeasonGoal]

    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        String(DailyStrait.key(date, calendar: calendar).prefix(7))
    }

    static var current: Season { of(key(Date())) }

    /// Months between two yyyy-MM keys.
    static func monthsBetween(_ a: String, _ b: String) -> Int? {
        func parts(_ s: String) -> (Int, Int)? {
            let p = s.split(separator: "-").compactMap { Int($0) }
            return p.count == 2 ? (p[0], p[1]) : nil
        }
        guard let x = parts(a), let y = parts(b) else { return nil }
        return (y.0 - x.0) * 12 + (y.1 - x.1)
    }

    static let titles = [
        "Fog Season", "Regatta Season", "Ribbon Season", "Gold Rush Season", "Tide Season", "Storm Season",
        "Lighthouse Season", "Harbour Season", "Moonshot Season", "Ferry Season", "Canal Season", "Gala Season",
    ]

    static func of(_ month: String) -> Season {
        var h: UInt64 = 14695981039346656037
        for b in "season:\(month)".utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        let number = max(1, (monthsBetween(epoch, month) ?? 0) + 1)
        let title = titles[Int(h % UInt64(titles.count))]
        let club: [Blowhard.ID] = [.windbag, .tycoon, .mayor, .blowhard, .windbag, .tycoon, .mayor]
        // Rotate the pack order each month so a season does not always start in the fog.
        let shift = Int((h >> 4) % 3)
        var goals: [SeasonGoal] = []
        for i in 0..<goalCount {
            var g = h &+ UInt64(i + 1) &* 0x9E3779B97F4A7C15
            g ^= g >> 29
            g = g &* 0xBF58476D1CE4E5B9
            g ^= g >> 32
            let cast: Blowhard.ID
            if i < openGoals {
                cast = .blowhard
            } else {
                let k = (i - openGoals + shift) % club.count
                cast = club[k]
            }
            let condition = Condition.all[Int(g % UInt64(Condition.all.count))]
            // Difficulty climbs through the season: 0 for the first goals, 3 at the end.
            let tier = min(3, i * 4 / goalCount)
            let kind = Int((g >> 12) % 4)
            let goal: Goal
            switch kind {
            case 0: goal = .launch(metres: [20_000, 35_000, 50_000, 70_000][tier])
            case 1: goal = .clearUnder(seconds: [75, 65, 58, 52][tier])
            case 2: goal = .combo(count: [10, 14, 18, 24][tier])
            default: goal = .popped(count: [7, 10, 13, 16][tier])
            }
            goals.append(SeasonGoal(index: i, cast: cast, condition: condition, goal: goal))
        }
        return Season(month: month, number: number, title: title, goals: goals)
    }

    /// "OCTOBER 2026".
    var monthName: String {
        let p = month.split(separator: "-").compactMap { Int($0) }
        guard p.count == 2, (1...12).contains(p[1]) else { return month }
        let names = ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST",
                     "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]
        return "\(names[p[1] - 1]) \(p[0])"
    }
}
