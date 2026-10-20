import Foundation

/// Everything 1.2 keeps between launches: the career, medals, the Daily Strait
/// and the credits bought in the shop.
///
/// One JSON blob in UserDefaults under its own key. The 1.0 and 1.1 keys
/// (best launch, best clear, the pack) are untouched, and every field decodes
/// with a default, so an install from any version opens cleanly.
struct Career: Codable, Equatable {
    var rounds = 0
    var totalMetres: Double = 0
    var bestCombo = 0
    var mostPopped = 0
    var bestByCast: [String: Double] = [:]
    var medals: [String] = []
    var trail = TrailStyle.spray.rawValue
    // The Daily Strait
    var dailyDay = ""
    var dailyAttempts = 0
    var dailyBest: Double = 0
    var dailyWon = false
    var lastWonDay = ""
    var streak = 0
    var bestStreak = 0
    var wonDays: [String] = []
    // Credits, bought or given
    var retries = 0
    var shields = 0
    var postcards = 0
    var freePostcardUsed = false
    var freeShieldMonth = ""
    // The Club Season and the Strait Club (1.2)
    var seasonMonth = ""
    var seasonDone: [Int] = []
    var seasonBadges: [String] = []
    var clubShieldMonth = ""
    var reviewAskedVersion = ""

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func v<T: Decodable>(_ k: CodingKeys, _ d: T) -> T {
            if let got = try? c.decodeIfPresent(T.self, forKey: k) { return got }
            return d
        }
        rounds = v(.rounds, 0); totalMetres = v(.totalMetres, 0); bestCombo = v(.bestCombo, 0); mostPopped = v(.mostPopped, 0)
        bestByCast = v(.bestByCast, [:]); medals = v(.medals, []); trail = v(.trail, TrailStyle.spray.rawValue)
        dailyDay = v(.dailyDay, ""); dailyAttempts = v(.dailyAttempts, 0); dailyBest = v(.dailyBest, 0); dailyWon = v(.dailyWon, false)
        lastWonDay = v(.lastWonDay, ""); streak = v(.streak, 0); bestStreak = v(.bestStreak, 0); wonDays = v(.wonDays, [])
        retries = v(.retries, 0); shields = v(.shields, 0); postcards = v(.postcards, 0)
        freePostcardUsed = v(.freePostcardUsed, false); freeShieldMonth = v(.freeShieldMonth, "")
        seasonMonth = v(.seasonMonth, ""); seasonDone = v(.seasonDone, []); seasonBadges = v(.seasonBadges, [])
        clubShieldMonth = v(.clubShieldMonth, ""); reviewAskedVersion = v(.reviewAskedVersion, "")
    }
}

/// What a finished round changed, for the result screen.
struct RoundNews: Equatable {
    var newMedals: [Medal] = []
    var dailyWon = false
    var dailyFailed = false
    var streak = 0
    /// The season goal this round was for, and whether it was met.
    var seasonGoal: SeasonGoal?
    var seasonMet = false
    /// True when this round finished the whole season.
    var seasonComplete = false
    var newBest = false
}

@MainActor
final class Logbook: ObservableObject {
    static let shared = Logbook()

    /// Free attempts at each day's strait. More come from Daily Retries.
    static let freeAttempts = 1

    @Published private(set) var career: Career
    /// A line for the title screen after a shield quietly saved the streak.
    @Published var notice: String?

    private let key = "career.v1"

    private init() {
        if let d = UserDefaults.standard.data(forKey: key), let c = try? JSONDecoder().decode(Career.self, from: d) {
            career = c
        } else {
            career = Career()
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-shot") { career = Logbook.demo() }
        #endif
        rollDay()
    }

    private func save() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-shot") { return }
        #endif
        if let d = try? JSONEncoder().encode(career) { UserDefaults.standard.set(d, forKey: key) }
        Glance(streak: career.streak, wonDay: career.dailyWon ? career.dailyDay : career.lastWonDay,
               bestStreak: career.bestStreak, shields: career.shields, club: isClub).publish()
    }

    var daily: DailyStrait { DailyStrait.today }
    var trail: TrailStyle { TrailStyle(rawValue: career.trail) ?? .spray }
    var attemptsLeft: Int {
        if isClub { return 99 }
        return max(0, Logbook.freeAttempts - career.dailyAttempts) + career.retries
    }
    var hasFreeAttempt: Bool { career.dailyAttempts < Logbook.freeAttempts }
    /// Strait Club members: unlimited daily retries and postcards, more shields.
    var isClub: Bool { Club.shared.isMember }
    var season: Season { Season.current }
    /// Goals done in the current month's season.
    var seasonDone: Set<Int> { career.seasonMonth == season.month ? Set(career.seasonDone) : [] }
    func has(_ medal: String) -> Bool { career.medals.contains(medal) }

    func ownsTrail(_ t: TrailStyle, pack: Bool) -> Bool {
        if t == .spray { return true }
        if t.isPaid { return pack }
        return t.medal.map { has($0.id) } ?? false
    }

    func setTrail(_ t: TrailStyle) { career.trail = t.rawValue; save() }

    /// A new day: reset today's attempts, give the monthly free shield, and spend
    /// shields on missed days so a streak survives a day or two away.
    func rollDay(now: Date = Date()) {
        let today = DailyStrait.key(now)
        let month = String(today.prefix(7))
        if career.freeShieldMonth != month {
            career.freeShieldMonth = month
            career.shields += 1
        }
        if isClub, career.clubShieldMonth != month {
            career.clubShieldMonth = month
            career.shields += Club.monthlyShields
        }
        if career.seasonMonth != month {
            career.seasonMonth = month
            career.seasonDone = []
        }
        if career.dailyDay != today {
            career.dailyDay = today
            career.dailyAttempts = 0
            career.dailyBest = 0
            career.dailyWon = false
        }
        if career.streak > 0, !career.lastWonDay.isEmpty,
           let gap = DailyStrait.daysBetween(career.lastWonDay, today), gap > 1 {
            let missed = gap - 1
            if missed <= 2, career.shields >= missed {
                career.shields -= missed
                // Move the last-won day forward so the streak continues from yesterday.
                if let y = Calendar.current.date(byAdding: .day, value: -1, to: DailyStrait.date(today) ?? now) {
                    career.lastWonDay = DailyStrait.key(y)
                }
                notice = missed == 1 ? "A Streak Shield covered yesterday. Your \(career.streak)-day streak is safe."
                                     : "Two Streak Shields covered the days you missed. Streak safe."
            } else {
                career.streak = 0
            }
        }
        save()
    }

    /// Spend an attempt at today's strait. False when there are none left.
    func startDaily() -> Bool {
        rollDay()
        if career.dailyAttempts < Logbook.freeAttempts || isClub {
            career.dailyAttempts += 1
        } else if career.retries > 0 {
            career.retries -= 1
            career.dailyAttempts += 1
        } else {
            return false
        }
        save()
        return true
    }

    /// Fold in a finished round.
    func record(_ r: RoundResult, cast: Blowhard.ID, daily: Bool, season goal: SeasonGoal? = nil) -> RoundNews {
        var news = RoundNews()
        career.rounds += 1
        career.totalMetres += r.launchMetres
        career.bestCombo = max(career.bestCombo, r.maxComboCount)
        career.mostPopped = max(career.mostPopped, r.bubblesPopped)
        if !daily { career.bestByCast[cast.rawValue] = max(career.bestByCast[cast.rawValue] ?? 0, r.launchMetres) }

        if daily {
            career.dailyBest = max(career.dailyBest, r.launchMetres)
            if !career.dailyWon && self.daily.goal.isMet(by: r) {
                career.dailyWon = true
                let today = DailyStrait.key(Date())
                if let gap = DailyStrait.daysBetween(career.lastWonDay, today), gap == 1 {
                    career.streak += 1
                } else if career.lastWonDay != today {
                    career.streak = 1
                }
                career.lastWonDay = today
                career.bestStreak = max(career.bestStreak, career.streak)
                if !career.wonDays.contains(today) { career.wonDays = Array((career.wonDays + [today]).suffix(120)) }
                news.dailyWon = true
            } else if !career.dailyWon {
                news.dailyFailed = true
            }
        }
        news.streak = career.streak

        if let goal {
            rollDay()
            news.seasonGoal = goal
            if goal.goal.isMet(by: r), season.goals.contains(goal) {
                news.seasonMet = true
                if !career.seasonDone.contains(goal.index) {
                    career.seasonDone.append(goal.index)
                    if career.seasonDone.count >= Season.goalCount, !career.seasonBadges.contains(season.month) {
                        career.seasonBadges.append(season.month)
                        news.seasonComplete = true
                    }
                }
            }
        }

        var earned = Medal.earned(by: r, rounds: career.rounds, dailyWon: news.dailyWon, streak: career.streak)
        if !career.seasonBadges.isEmpty { earned.append("season") }
        for id in earned where !career.medals.contains(id) {
            career.medals.append(id)
            if let m = Medal.all.first(where: { $0.id == id }) { news.newMedals.append(m) }
        }
        save()
        return news
    }

    // MARK: Credits

    func add(retries n: Int) { career.retries += n; save() }
    func add(shields n: Int) { career.shields += n; save() }
    func add(postcards n: Int) { career.postcards += n; save() }

    /// Asked for an App Store rating in this version already?
    func shouldAskForReview(version: String) -> Bool { career.rounds >= 4 && career.reviewAskedVersion != version }
    func didAskForReview(version: String) { career.reviewAskedVersion = version; save() }

    /// The first postcard is free; after that they come in packs of three.
    var canMakePostcard: Bool { isClub || !career.freePostcardUsed || career.postcards > 0 }
    /// Postcards ready to make right now, for the result screen's button.
    var postcardsReady: Int { (career.freePostcardUsed ? 0 : 1) + career.postcards }
    func spendPostcard() {
        if isClub { return }
        if !career.freePostcardUsed { career.freePostcardUsed = true } else { career.postcards = max(0, career.postcards - 1) }
        save()
    }

    #if DEBUG
    /// A career that has been playing for a couple of weeks, for the store screenshots.
    static func demo() -> Career {
        var c = Career()
        c.rounds = 37; c.totalMetres = 1_284_400; c.bestCombo = 31; c.mostPopped = 16
        c.bestByCast = ["blowhard": 112_480, "windbag": 61_200, "tycoon": 148_900, "mayor": 74_300]
        c.medals = ["first", "combo15", "combo30", "tremendous", "needle", "quick", "far", "moon", "rounds10", "daily", "streak7"]
        c.trail = TrailStyle.gold.rawValue
        c.streak = 9; c.bestStreak = 9; c.lastWonDay = DailyStrait.key(Date().addingTimeInterval(-86_400))
        c.retries = 2; c.shields = 2; c.postcards = 3
        c.seasonMonth = Season.key(Date()); c.seasonDone = [0, 1, 2, 3, 5]; c.seasonBadges = []
        let args = ProcessInfo.processInfo.arguments
        if args.contains("dailywon") {
            c.dailyDay = DailyStrait.key(Date()); c.dailyAttempts = 1; c.dailyWon = true
            c.lastWonDay = DailyStrait.key(Date()); c.streak = 10; c.bestStreak = 10
        }
        return c
    }
    #endif
}
