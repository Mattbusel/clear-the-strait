import AppIntents
import SwiftUI
import WidgetKit

@main
struct StraitWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyWidget()
        StreakWidget()
        if #available(iOS 18.0, *) { DailyControl() }
    }
}

private enum Ink {
    static let sea = Color(red: 0.13, green: 0.60, blue: 0.82)
    static let deep = Color(red: 0.06, green: 0.33, blue: 0.52)
    static let sun = Color(red: 0.99, green: 0.78, blue: 0.24)
    static let coral = Color(red: 0.94, green: 0.30, blue: 0.30)
    static let foam = Color(red: 0.94, green: 0.99, blue: 1.00)
    static let ink = Color(red: 0.07, green: 0.12, blue: 0.22)
    static let bg = LinearGradient(colors: [sea, deep], startPoint: .top, endPoint: .bottom)
}

struct Entry: TimelineEntry {
    let date: Date
    let strait: DailyStrait
    let glance: Glance

    var won: Bool { glance.wonToday(date) }
    var streak: Int { glance.liveStreak(date) }
}

/// One entry now and one at midnight, when the next day's strait appears.
struct Provider: TimelineProvider {
    func entry(_ d: Date) -> Entry { Entry(date: d, strait: DailyStrait.on(DailyStrait.key(d)), glance: Glance.load()) }

    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, strait: DailyStrait.today, glance: Glance(streak: 9, wonDay: "", bestStreak: 9, shields: 1, club: false))
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let real = entry(.now)
        completion(context.isPreview && real.glance.streak == 0 ? placeholder(in: context) : real)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        let entries = [entry(.now), entry(midnight.addingTimeInterval(5))]
        completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(86_400))))
    }
}

/// Today's strait: condition, goal and streak. Small, medium and the Lock Screen.
struct DailyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "daily", provider: Provider()) { e in
            DailyView(e: e)
                .containerBackground(Ink.bg, for: .widget)
                .widgetURL(Route.daily.url)
        }
        .configurationDisplayName("Daily Strait")
        .description("Today's challenge, the same for everyone, and your streak.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

/// The streak on its own: a flame for the Lock Screen and StandBy.
struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "streak", provider: Provider()) { e in
            StreakView(e: e)
                .containerBackground(Ink.bg, for: .widget)
                .widgetURL(Route.daily.url)
        }
        .configurationDisplayName("Daily Streak")
        .description("How many Daily Straits in a row, and whether today's is beaten.")
        .supportedFamilies([.accessoryCircular, .systemSmall])
    }
}

struct DailyView: View {
    let e: Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Label(e.won ? "Strait #\(e.strait.number) beaten" : "Strait #\(e.strait.number): \(e.strait.condition.name)",
                  systemImage: e.won ? "checkmark.circle" : "flame")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("STRAIT #\(e.strait.number) · \(e.strait.condition.name.uppercased())")
                    .font(.system(size: 11, weight: .heavy, design: .rounded)).lineLimit(1)
                Text(e.won ? "Beaten today" : e.strait.goal.sentence)
                    .font(.system(size: 14, weight: .black, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
                Label("\(e.streak)-day streak", systemImage: "flame.fill")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .widgetAccentable()
        case .systemMedium:
            HStack(spacing: 14) {
                today
                Spacer(minLength: 0)
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill").font(.system(size: 26, weight: .black)).foregroundStyle(Ink.coral)
                    Text("\(e.streak)").font(.system(size: 40, weight: .black, design: .rounded)).foregroundStyle(Ink.foam)
                        .contentTransition(.numericText())
                    Text("DAY STREAK").font(.system(size: 10, weight: .black, design: .rounded)).kerning(1).foregroundStyle(Ink.foam.opacity(0.8))
                    if e.glance.shields > 0 {
                        Label("\(e.glance.shields)", systemImage: "shield.lefthalf.filled")
                            .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Ink.sun).padding(.top, 2)
                    }
                }
                .frame(width: 96)
            }
        default:
            today
        }
    }

    private var today: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DAILY STRAIT #\(e.strait.number)")
                .font(.system(size: 11, weight: .black, design: .rounded)).kerning(0.8).foregroundStyle(Ink.sun)
            Text(e.strait.condition.name.uppercased())
                .font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(Ink.foam).lineLimit(1).minimumScaleFactor(0.7)
            Text(e.strait.goal.text)
                .font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundStyle(Ink.foam.opacity(0.9))
                .lineLimit(2).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                Image(systemName: e.won ? "checkmark.circle.fill" : "play.circle.fill")
                Text(e.won ? "BEATEN" : "PLAY").kerning(1)
            }
            .font(.system(size: 13, weight: .black, design: .rounded)).foregroundStyle(Ink.ink)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Ink.sun))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StreakView: View {
    let e: Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: e.won ? "checkmark" : "flame.fill").font(.system(size: 13, weight: .black))
                    Text("\(e.streak)").font(.system(size: 20, weight: .black, design: .rounded))
                }
            }
            .widgetAccentable()
        } else {
            VStack(spacing: 4) {
                Image(systemName: "flame.fill").font(.system(size: 34, weight: .black)).foregroundStyle(Ink.coral)
                Text("\(e.streak)").font(.system(size: 48, weight: .black, design: .rounded)).foregroundStyle(Ink.foam)
                Text(e.won ? "BEATEN TODAY" : "DAY STREAK").font(.system(size: 11, weight: .black, design: .rounded)).kerning(1)
                    .foregroundStyle(e.won ? Ink.sun : Ink.foam.opacity(0.85))
                Text("BEST \(max(e.glance.bestStreak, e.streak))").font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Ink.foam.opacity(0.7))
            }
        }
    }
}

/// Control Center, the Lock Screen and the Action button: straight into today's strait.
@available(iOS 18.0, *)
struct DailyControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.mattbusel.clearthestrait.daily") {
            ControlWidgetButton(action: PlayDailyStraitIntent()) {
                Label("Daily Strait", systemImage: "ferry.fill")
            }
        }
        .displayName("Daily Strait")
        .description("Opens Clear the Strait on today's challenge.")
    }
}
