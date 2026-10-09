import SwiftUI
import UIKit

// MARK: - Shared bits

/// A rounded panel on the deep water, the one card shape of 1.2's screens.
struct Panel<Content: View>: View {
    var tint: Color = UI.foam
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(tint.opacity(0.09))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(tint.opacity(0.18), lineWidth: 2))
            )
    }
}

struct Kicker: View {
    let text: String
    var color: Color = UI.sun
    init(_ t: String, color: Color = UI.sun) { text = t; self.color = color }
    var body: some View {
        Text(text).font(.system(size: 12, weight: .black, design: .rounded)).kerning(1.8).foregroundStyle(color)
    }
}

/// The yellow price pill on anything for sale.
struct PriceButton: View {
    @ObservedObject var extras: Extras
    let id: String
    var label: String? = nil
    var body: some View {
        Button {
            Task { await extras.buy(id) }
        } label: {
            HStack(spacing: 6) {
                if extras.busy == id { ProgressView().tint(UI.ink) }
                Text(label ?? extras.price(id))
            }
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(UI.ink)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Capsule().fill(UI.sun))
        }
        .buttonStyle(.plain)
        .disabled(extras.busy != nil)
    }
}

struct CloseX: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark").font(.system(size: 15, weight: .black)).foregroundStyle(UI.foam)
                .padding(11).background(Circle().fill(UI.foam.opacity(0.14)))
        }
        .accessibilityLabel("Close")
    }
}

// MARK: - Daily card on the title

struct DailyCard: View {
    @ObservedObject var progress: Logbook
    var onPlay: () -> Void
    var body: some View {
        let d = progress.daily
        let won = progress.career.dailyWon
        Button(action: onPlay) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(won ? UI.sun : UI.foam.opacity(0.14))
                    Image(systemName: won ? "checkmark" : "calendar")
                        .font(.system(size: 20, weight: .black)).foregroundStyle(won ? UI.ink : UI.sun)
                }
                .frame(width: 50, height: 50)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DAILY STRAIT #\(d.number)  ·  \(d.condition.name.uppercased())")
                        .font(.system(size: 11, weight: .black, design: .rounded)).kerning(1).foregroundStyle(UI.sun)
                    Text(won ? "BEATEN. BACK TOMORROW." : d.goal.text)
                        .font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(UI.foam)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(status).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.75))
                }
                Spacer(minLength: 0)
                if progress.career.streak > 0 {
                    VStack(spacing: 0) {
                        Image(systemName: "flame.fill").font(.system(size: 16, weight: .black)).foregroundStyle(UI.coral)
                        Text("\(progress.career.streak)").font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(UI.foam)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(UI.ink.opacity(0.35))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(UI.sun.opacity(won ? 0.9 : 0.45), lineWidth: 2))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Daily Strait. \(won ? "Beaten today" : d.goal.text)")
    }

    var status: String {
        if progress.career.dailyWon { return "Best today \(Int(progress.career.dailyBest).formatted()) m. Keep it to beat on any round." }
        if progress.hasFreeAttempt { return "1 free try today. \(progress.daily.condition.line)" }
        if progress.career.retries > 0 { return "\(progress.career.retries) retr\(progress.career.retries == 1 ? "y" : "ies") left. Tap to go again." }
        return "Out of tries today. Tap for retries."
    }
}

// MARK: - Retry sheet

/// Shown when today's free try is used up and there are no retries banked.
struct RetrySheet: View {
    @ObservedObject var extras: Extras
    @ObservedObject var progress: Logbook
    var onRetry: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack(alignment: .topTrailing) {
            UI.deep.ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer().frame(height: 30)
                Image(systemName: "arrow.counterclockwise.circle.fill").font(.system(size: 54, weight: .bold)).foregroundStyle(UI.sun)
                Text("ONE MORE GO?").font(.system(size: 32, weight: .black, design: .rounded)).kerning(2).foregroundStyle(UI.foam)
                Text("Today's free try is used. Daily Retries give you three more shots at today's strait, and any you don't use carry over to tomorrow.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.85))
                    .multilineTextAlignment(.center).padding(.horizontal, 26)
                Panel {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("3 DAILY RETRIES").font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(UI.foam)
                            Text(progress.daily.goal.text).font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(UI.sun)
                        }
                        Spacer()
                        PriceButton(extras: extras, id: Extras.retriesID)
                    }
                }
                .padding(.horizontal, 20)
                if progress.career.retries > 0 {
                    Button("PLAY NOW") { dismiss(); onRetry() }.buttonStyle(ArcadeButton()).padding(.horizontal, 40)
                }
                Text("Free play is always unlimited. Retries are only for the Daily Strait.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.6))
                    .multilineTextAlignment(.center).padding(.horizontal, 30)
                if let m = extras.message { Text(m).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam).padding(.horizontal, 24) }
                Spacer()
            }
            CloseX { dismiss() }.padding(16)
        }
        .task { await extras.load() }
        .onChange(of: progress.career.retries) { _, n in if n > 0 { dismiss(); onRetry() } }
    }
}

// MARK: - The locker

struct LockerSheet: View {
    @ObservedObject var progress: Logbook
    @ObservedObject var extras: Extras
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var icon = AltIcon.allCases.first { $0.asset == UIApplication.shared.alternateIconName } ?? .classic

    var body: some View {
        ZStack(alignment: .topTrailing) {
            UI.deep.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("THE LOCKER").font(.system(size: 34, weight: .black, design: .rounded)).kerning(3).foregroundStyle(UI.foam)
                        .padding(.top, 22)
                    Picker("", selection: $tab) {
                        Text("Medals").tag(0); Text("Records").tag(1); Text("Trails").tag(2); Text("Shop").tag(3)
                    }
                    .pickerStyle(.segmented)
                    switch tab {
                    case 0: medals
                    case 1: records
                    case 2: trails
                    default: shop
                    }
                    if let m = extras.message {
                        Text(m).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam)
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 30)
            }
            CloseX { dismiss() }.padding(16)
        }
        .task { await extras.load() }
        .onAppear {
            let a = ProcessInfo.processInfo.arguments
            if a.contains("shop") { tab = 3 } else if a.contains("trails") { tab = 2 } else if a.contains("records") { tab = 1 }
        }
    }

    private var medals: some View {
        let have = progress.career.medals.count
        return VStack(alignment: .leading, spacing: 10) {
            Kicker("\(have) OF \(Medal.all.count) EARNED")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Medal.all) { m in
                    let got = progress.has(m.id)
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: m.symbol).font(.system(size: 22, weight: .black))
                            .foregroundStyle(got ? UI.ink : UI.foam.opacity(0.35))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(got ? UI.sun : UI.foam.opacity(0.08)))
                        Text(m.name.uppercased()).font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(got ? UI.foam : UI.foam.opacity(0.55))
                        Text(m.detail).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                        if let t = m.unlocks {
                            Text("UNLOCKS \(t.name.uppercased()) TRAIL").font(.system(size: 9, weight: .black, design: .rounded)).kerning(0.8).foregroundStyle(UI.sun)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(UI.foam.opacity(got ? 0.12 : 0.05)))
                }
            }
        }
    }

    private var records: some View {
        let c = progress.career
        return VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                stat("\(Int(Scores.bestLaunch).formatted()) m", "BEST LAUNCH")
                stat(Scores.bestClear > 0 ? String(format: "%.1f s", Scores.bestClear) : "-", "FASTEST CLEAR")
                stat("x\(c.bestCombo)", "BEST COMBO")
                stat("\(c.rounds)", "STRAITS CLEARED")
                stat("\(Int(c.totalMetres / 1000).formatted()) km", "TOTAL DISTANCE")
                stat("\(c.bestStreak)", "BEST DAILY STREAK")
            }
            Kicker("BEST LAUNCH, BY BLOWHARD")
            Panel {
                VStack(spacing: 8) {
                    ForEach(Blowhard.all) { who in
                        HStack {
                            Text(who.name.uppercased()).font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(UI.foam)
                            Spacer()
                            let best = c.bestByCast[who.id.rawValue] ?? 0
                            Text(best > 0 ? "\(Int(best).formatted()) m" : "-").font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(UI.sun)
                        }
                    }
                }
            }
            Kicker("LAST FOUR WEEKS OF DAILY STRAITS")
            Panel { DailyCalendar(won: Set(c.wonDays)) }
        }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.system(size: 24, weight: .black, design: .rounded)).foregroundStyle(UI.sun).lineLimit(1).minimumScaleFactor(0.6)
            Text(l).font(.system(size: 10, weight: .black, design: .rounded)).kerning(1).foregroundStyle(UI.foam.opacity(0.7))
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(UI.foam.opacity(0.08)))
    }

    private var trails: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker("WHAT HE LEAVES BEHIND IN FLIGHT")
            ForEach(TrailStyle.allCases) { t in
                let ok = progress.ownsTrail(t, pack: extras.ownsTrails)
                let on = progress.trail == t
                Button {
                    if ok { progress.setTrail(t); Haptics.pop() }
                } label: {
                    HStack(spacing: 12) {
                        TrailSwatch(style: t).frame(width: 64, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.name.uppercased()).font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(UI.foam)
                            Text(ok ? (on ? "In use" : "Tap to use") : t.isPaid ? "Trail Pack" : "Earn: \(t.medal?.name ?? "")")
                                .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.7))
                        }
                        Spacer()
                        if on { Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(UI.sun) }
                        else if !ok { Image(systemName: "lock.fill").foregroundStyle(UI.foam.opacity(0.5)) }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(UI.foam.opacity(on ? 0.14 : 0.06)))
                }
                .buttonStyle(.plain)
            }
            if !extras.ownsTrails {
                Panel(tint: UI.sun) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("TRAIL PACK").font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(UI.foam)
                            Text("Rainbow, Fireworks and Confetti, yours for good.").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.8))
                        }
                        Spacer()
                        PriceButton(extras: extras, id: Extras.trailsID)
                    }
                }
            }
        }
    }

    private var shop: some View {
        let c = progress.career
        return VStack(alignment: .leading, spacing: 10) {
            Kicker("TOP-UPS  ·  BUY AS OFTEN AS YOU LIKE")
            item("arrow.counterclockwise", "3 DAILY RETRIES", "Three more goes at the Daily Strait. Unused ones carry over. You have \(c.retries).", Extras.retriesID)
            item("shield.lefthalf.filled", "2 STREAK SHIELDS", "Each covers a missed day so your daily streak survives. One free every month. You have \(c.shields).", Extras.shieldsID)
            item("photo.on.rectangle.angled", "3 POSTCARDS", "A picture of your launch to send round, from the result screen. The first one is free. You have \(c.postcards).", Extras.postcardsID)
            Kicker("KEEPS")
            if extras.ownsTrails {
                Panel { Text("TRAIL PACK  ·  OWNED").font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(UI.sun) }
            } else {
                item("sparkles", "TRAIL PACK", "Rainbow, Fireworks and Confetti trails when he flies.", Extras.trailsID)
            }
            if extras.ownsIcons {
                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("APP ICON").font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(UI.sun)
                        HStack(spacing: 8) {
                            ForEach(AltIcon.allCases) { a in
                                Button {
                                    icon = a
                                    UIApplication.shared.setAlternateIconName(a.asset)
                                } label: {
                                    Text(a.name.uppercased()).font(.system(size: 10, weight: .black, design: .rounded))
                                        .foregroundStyle(icon == a ? UI.ink : UI.foam)
                                        .padding(.vertical, 8).frame(maxWidth: .infinity)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(icon == a ? UI.sun : UI.foam.opacity(0.1)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } else {
                item("app.badge.fill", "ICON PACK", "Night Canal, Marina and Fog home-screen icons.", Extras.iconsID)
            }
            Button("RESTORE PURCHASES") { Task { await extras.restore() } }
                .font(.system(size: 14, weight: .heavy, design: .rounded)).kerning(1).foregroundStyle(UI.foam.opacity(0.85))
                .padding(.top, 4)
            Text("No adverts, no loot boxes. Everything here says exactly what you get.")
                .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.6))
        }
    }

    private func item(_ symbol: String, _ title: String, _ detail: String, _ id: String) -> some View {
        Panel {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 18, weight: .black)).foregroundStyle(UI.ink)
                    .frame(width: 42, height: 42).background(RoundedRectangle(cornerRadius: 12).fill(UI.sun))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(UI.foam)
                    Text(detail).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                PriceButton(extras: extras, id: id)
            }
        }
    }
}

/// Four weeks of Daily Straits, a square per day.
struct DailyCalendar: View {
    let won: Set<String>
    var body: some View {
        let today = Date()
        let days = (0..<28).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: today) }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(days, id: \.self) { d in
                let k = DailyStrait.key(d)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(won.contains(k) ? UI.sun : UI.foam.opacity(0.1))
                    .frame(height: 26)
                    .overlay(Text("\(Calendar.current.component(.day, from: d))").font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(won.contains(k) ? UI.ink : UI.foam.opacity(0.5)))
            }
        }
    }
}

/// A still of a trail, for the locker.
struct TrailSwatch: View {
    let style: TrailStyle
    var body: some View {
        Canvas { ctx, size in
            let colours: [Color] = [UI.coral, UI.sun, Color(red: 0.44, green: 0.78, blue: 0.44), UI.sea, Color(red: 0.16, green: 0.26, blue: 0.52)]
            for i in 0..<9 {
                let x = size.width * (0.92 - CGFloat(i) * 0.1), y = size.height / 2 + CGFloat((i * 37) % 9) - 4
                let r: CGFloat = 3 + CGFloat(i % 3)
                let c: Color
                switch style {
                case .spray: c = UI.foam
                case .smoke: c = Color.white.opacity(0.6)
                case .comet: c = Color(red: 1, green: 0.9, blue: 0.55)
                case .gold: c = UI.sun
                case .rainbow, .fireworks, .confetti: c = colours[i % colours.count]
                }
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * (style == .rainbow ? 1 : 2))
                ctx.fill(style == .confetti ? Path(rect) : Path(ellipseIn: rect), with: .color(c.opacity(1 - Double(i) * 0.08)))
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(UI.sea))
    }
}

// MARK: - Postcard

/// A picture of the launch, drawn rather than captured, so it renders the same everywhere.
struct PostcardView: View {
    let result: RoundResult
    let who: Blowhard
    let daily: DailyStrait?
    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [who.waterColor, UI.deep], startPoint: .top, endPoint: .bottom)
            // The skip: a dotted arc of splashes across the card.
            Canvas { ctx, size in
                var p = Path()
                p.move(to: CGPoint(x: 40, y: size.height * 0.62))
                for i in 1...4 {
                    let x = 40 + CGFloat(i) * (size.width - 80) / 4
                    p.addQuadCurve(to: CGPoint(x: x, y: size.height * 0.62),
                                   control: CGPoint(x: x - (size.width - 80) / 8, y: size.height * (0.62 - 0.28 / CGFloat(i))))
                }
                ctx.stroke(p, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 3, dash: [2, 9]))
                let r: CGFloat = 34
                let c = CGPoint(x: size.width - 70, y: size.height * 0.62 - 10)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(who.accentColor))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.75, y: c.y - r * 0.9, width: r * 1.5, height: r * 1.2)), with: .color(Color(red: 1, green: 0.84, blue: 0.7)))
                ctx.fill(Path(CGRect(x: 0, y: size.height * 0.66, width: size.width, height: size.height * 0.34)), with: .color(UI.deep.opacity(0.55)))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("GREETINGS FROM").font(.system(size: 13, weight: .black, design: .rounded)).kerning(2).foregroundStyle(UI.foam.opacity(0.85))
                Text(who.channel.uppercased()).font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(UI.sun)
                Spacer()
                Text("\(Int(result.launchMetres).formatted()) m").font(.system(size: 54, weight: .black, design: .rounded)).foregroundStyle(UI.foam)
                Text("\(who.name.uppercased()), LAUNCHED IN \(String(format: "%.1f", result.clearSeconds)) SEC  ·  \(result.maxComboTier.label) x\(result.maxComboCount)")
                    .font(.system(size: 12, weight: .black, design: .rounded)).kerning(0.6).foregroundStyle(UI.foam.opacity(0.85))
                if let daily {
                    Text("DAILY STRAIT #\(daily.number)  ·  \(daily.condition.name.uppercased())")
                        .font(.system(size: 11, weight: .black, design: .rounded)).kerning(1).foregroundStyle(UI.sun)
                }
                Text("CLEAR THE STRAIT").font(.system(size: 11, weight: .black, design: .rounded)).kerning(2).foregroundStyle(UI.foam.opacity(0.6)).padding(.top, 4)
            }
            .padding(22)
        }
        .frame(width: 400, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    @MainActor static func render(_ result: RoundResult, who: Blowhard, daily: DailyStrait?) -> UIImage? {
        let r = ImageRenderer(content: PostcardView(result: result, who: who, daily: daily))
        r.scale = 3
        return r.uiImage
    }
}
