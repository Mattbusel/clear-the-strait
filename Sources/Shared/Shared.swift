import AppIntents
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// What the app and its widgets share: one small summary in the app group,
/// and the routes a widget, a control or Siri can open the app on.
enum AppGroup {
    static let id = "group.com.mattbusel.clearthestrait"
    static var defaults: UserDefaults { UserDefaults(suiteName: id) ?? .standard }
}

/// The few numbers a widget shows next to today's strait.
struct Glance: Codable, Equatable {
    var streak = 0
    /// The last day (yyyy-MM-dd) the Daily Strait was beaten.
    var wonDay = ""
    var bestStreak = 0
    var shields = 0
    var club = false

    static let key = "glance.v1"

    static func load() -> Glance {
        guard let d = AppGroup.defaults.data(forKey: key), let g = try? JSONDecoder().decode(Glance.self, from: d) else { return Glance() }
        return g
    }

    /// Write it for the widgets, and ask them to redraw only when something changed.
    func publish() {
        guard self != Glance.load(), let d = try? JSONEncoder().encode(self) else { return }
        AppGroup.defaults.set(d, forKey: Glance.key)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    func wonToday(_ now: Date = Date()) -> Bool { wonDay == DailyStrait.key(now) }

    /// The streak as it stands today: it survives until a day is missed.
    func liveStreak(_ now: Date = Date()) -> Int {
        guard streak > 0, let gap = DailyStrait.daysBetween(wonDay, DailyStrait.key(now)) else { return 0 }
        return gap <= 1 + min(shields, 2) ? streak : 0
    }
}

/// Where to land when the app is opened from outside.
enum Route: String {
    case daily, season, club

    static let pendingKey = "route.pending"

    static func set(_ r: Route) { AppGroup.defaults.set(r.rawValue, forKey: pendingKey) }

    /// The route waiting to be taken, removed as it is read.
    static func take() -> Route? {
        guard let raw = AppGroup.defaults.string(forKey: pendingKey) else { return nil }
        AppGroup.defaults.removeObject(forKey: pendingKey)
        return Route(rawValue: raw)
    }

    var url: URL { URL(string: "clearthestrait://\(rawValue)")! }
}

/// "Play today's Daily Strait": Siri, Shortcuts, Spotlight and the Control Center control.
struct PlayDailyStraitIntent: AppIntent {
    static var title: LocalizedStringResource = "Play the Daily Strait"
    static var description = IntentDescription("Opens Clear the Strait on today's Daily Strait challenge.")
    static var openAppWhenRun: Bool = true

    init() {}

    func perform() async throws -> some IntentResult {
        Route.set(.daily)
        return .result()
    }
}

/// "Open this month's Club Season".
struct OpenSeasonIntent: AppIntent {
    static var title: LocalizedStringResource = "Open the Club Season"
    static var description = IntentDescription("Opens this month's ten Club Season goals.")
    static var openAppWhenRun: Bool = true

    init() {}

    func perform() async throws -> some IntentResult {
        Route.set(.season)
        return .result()
    }
}
