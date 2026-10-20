import StoreKit
import SwiftUI

// MARK: - The Strait Club sheet

/// The subscription screen. For members it is a status page with Manage
/// Subscription; for everyone else it shows every benefit, both plans with
/// their price and period, the trial terms, the renewal terms, the Terms of
/// Use and Privacy links, Restore Purchases and Redeem Code.
struct ClubSheet: View {
    @ObservedObject var club: Club
    @ObservedObject var pack: PackStore
    var onSeason: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var pick = Club.yearlyID
    @State private var redeeming = false
    @State private var managing = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [UI.deep, UI.ink], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    header.padding(.top, 34)
                    perks
                    if club.isMember { memberArea } else { joinArea }
                    if let m = club.message {
                        Text(m).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam)
                            .multilineTextAlignment(.center).padding(12).frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 14).fill(UI.foam.opacity(0.1)))
                    }
                    links
                }
                .padding(.horizontal, 20).padding(.bottom, 30)
            }
            CloseX { dismiss() }.padding(16)
        }
        .task { await club.load() }
        .offerCodeRedemption(isPresented: $redeeming) { _ in Task { await club.refresh() } }
        .manageSubscriptionsSheet(isPresented: $managing)
    }

    private var header: some View {
        VStack(spacing: 2) {
            Image(systemName: "crown.fill").font(.system(size: 34, weight: .black)).foregroundStyle(UI.sun)
                .symbolEffect(.bounce, value: club.isMember)
            Text("THE STRAIT").font(.system(size: 26, weight: .black, design: .rounded)).kerning(3).foregroundStyle(UI.foam)
            Text("CLUB").font(.system(size: 56, weight: .black, design: .rounded)).kerning(6).foregroundStyle(UI.sun)
            Text(club.isMember ? "You're in. Everything below is yours while you're a member."
                               : "Every blowhard, every trail, and a new season of goals every month.")
                .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.85))
                .multilineTextAlignment(.center).padding(.horizontal, 10)
        }
    }

    private var perks: some View {
        Panel(tint: UI.sun) {
            VStack(alignment: .leading, spacing: 12) {
                ClubPerk(symbol: "star.circle.fill", title: "A NEW SEASON EVERY MONTH", line: "Ten goals across every channel, and the Full Season medal for finishing them.")
                ClubPerk(symbol: "person.3.fill", title: "ALL FOUR BLOWHARDS", line: "The Windbag, the Tycoon and the Mayor, each in his own channel with his own twist.")
                ClubPerk(symbol: "arrow.counterclockwise", title: "UNLIMITED DAILY RETRIES", line: "Keep going at the Daily Strait until it falls.")
                ClubPerk(symbol: "shield.lefthalf.filled", title: "3 STREAK SHIELDS A MONTH", line: "Miss a day without losing your streak.")
                ClubPerk(symbol: "sparkles", title: "EVERY TRAIL AND APP ICON", line: "Rainbow, Fireworks, Confetti and the Night Canal, Marina and Fog icons.")
                ClubPerk(symbol: "photo.on.rectangle.angled", title: "UNLIMITED POSTCARDS", line: "Send every launch you are proud of.")
            }
        }
    }

    @ViewBuilder private var memberArea: some View {
        VStack(spacing: 10) {
            if let id = club.activeID {
                Text(id == Club.yearlyID ? "YEARLY PLAN" : "MONTHLY PLAN")
                    .font(.system(size: 15, weight: .black, design: .rounded)).kerning(1.5).foregroundStyle(UI.sun)
            }
            if let d = club.renews {
                Text("\(club.willRenew ? "Renews" : "Ends") \(d.formatted(date: .long, time: .omitted)).")
                    .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.8))
            }
            Button("PLAY THE SEASON") { dismiss(); onSeason() }.buttonStyle(ArcadeButton())
            Button("MANAGE SUBSCRIPTION") { managing = true }
                .font(.system(size: 14, weight: .heavy, design: .rounded)).kerning(1).foregroundStyle(UI.foam.opacity(0.9))
        }
        .padding(.top, 6)
    }

    @ViewBuilder private var joinArea: some View {
        VStack(spacing: 10) {
            if club.products.isEmpty && ProcessInfo.processInfo.arguments.contains("-mockplans") {
                // Debug screenshot runs only (no App Store on the CI simulator): the same cards with the real prices.
                mockPlan("YEARLY", "$14.99 a year", "Works out to $1.25 a month", "Starts with a 1-week free trial", on: true)
                mockPlan("MONTHLY", "$2.99 a month", nil, nil, on: false)
                Button("START FREE TRIAL") {}.buttonStyle(ArcadeButton()).padding(.top, 4)
                Text("1-week free trial, then $14.99 a year. Renews automatically until cancelled.")
                    .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(UI.foam).multilineTextAlignment(.center)
            } else if club.products.isEmpty {
                ProgressView().tint(UI.foam).padding(20)
                Text("Loading plans from the App Store...").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.7))
            } else {
                if let y = club.yearly { planCard(y, best: true) }
                if let m = club.monthly { planCard(m, best: false) }
                let chosen = club.products.first { $0.id == pick }
                let trial = pick == Club.yearlyID && club.trialEligible ? Club.trialLine(chosen) : nil
                Button {
                    guard let chosen else { return }
                    Task { await club.buy(chosen) }
                } label: {
                    HStack(spacing: 10) {
                        if club.busy { ProgressView().tint(UI.ink) }
                        Text(trial != nil ? "START FREE TRIAL" : "SUBSCRIBE")
                    }
                }
                .buttonStyle(ArcadeButton())
                .disabled(club.busy || chosen == nil)
                .padding(.top, 4)
                Text(termsLine(chosen, trial: trial))
                    .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(UI.foam)
                    .multilineTextAlignment(.center)
            }
            if pack.owned {
                Text("You own the Blowhard Pack. It stays yours whatever you choose here.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(UI.sun)
                    .multilineTextAlignment(.center).padding(.top, 2)
            }
            Text("Payment is charged to your Apple Account when you confirm the purchase. The subscription renews automatically at the same price and period unless it is cancelled at least 24 hours before the end of the current period; your account is charged for the renewal within the 24 hours before the period ends. Cancel or manage it any time in your Apple Account settings (Settings > your name > Subscriptions). If you start a free trial, any unused part of it ends when you subscribe. The Blowhard Pack, trails and icons you bought stay yours.")
                .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(UI.foam.opacity(0.65))
                .multilineTextAlignment(.center).padding(.top, 4)
        }
        .padding(.top, 4)
    }

    private func mockPlan(_ name: String, _ price: String, _ per: String?, _ trial: String?, on: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: on ? "largecircle.fill.circle" : "circle").font(.system(size: 22, weight: .bold)).foregroundStyle(on ? UI.sun : UI.foam.opacity(0.6))
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(UI.foam)
                Text(price).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(UI.sun)
                if let per { Text(per).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.75)) }
                if let trial { Text(trial).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(UI.foam) }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(UI.foam.opacity(on ? 0.14 : 0.06))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(on ? UI.sun : UI.foam.opacity(0.2), lineWidth: on ? 3 : 2)))
    }

    private func termsLine(_ p: Product?, trial: String?) -> String {
        guard let p else { return "" }
        if let trial { return "\(trial), then \(Club.priceLine(p)). Renews automatically until cancelled." }
        return "\(Club.priceLine(p)). Renews automatically until cancelled."
    }

    private func planCard(_ p: Product, best: Bool) -> some View {
        let on = pick == p.id
        let trial = best && club.trialEligible ? Club.trialLine(p) : nil
        return Button { pick = p.id; Haptics.pop() } label: {
            HStack(spacing: 12) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(on ? UI.sun : UI.foam.opacity(0.6))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(best ? "YEARLY" : "MONTHLY").font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(UI.foam)
                        if best {
                            Text("BEST VALUE").font(.system(size: 10, weight: .black, design: .rounded)).kerning(1).foregroundStyle(UI.ink)
                                .padding(.horizontal, 7).padding(.vertical, 3).background(Capsule().fill(UI.sun))
                        }
                    }
                    Text(Club.priceLine(p)).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(UI.sun)
                    if best, let monthly = perMonth(p) {
                        Text("Works out to \(monthly) a month").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.75))
                    }
                    if let trial {
                        Text("Starts with a \(trial)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(UI.foam)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(UI.foam.opacity(on ? 0.14 : 0.06))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(on ? UI.sun : UI.foam.opacity(0.2), lineWidth: on ? 3 : 2))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(best ? "Yearly" : "Monthly") plan, \(Club.priceLine(p))\(trial.map { ", \($0)" } ?? "")")
    }

    private func perMonth(_ p: Product) -> String? {
        let monthly = p.price / 12
        return monthly.formatted(p.priceFormatStyle)
    }

    private var links: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                Link("Terms of Use", destination: Club.terms)
                Link("Privacy Policy", destination: Club.privacy)
            }
            .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.9))
            HStack(spacing: 18) {
                Button("Restore Purchases") { Task { await club.restore(); await pack.restore() } }
                Button("Redeem Code") { redeeming = true }
            }
            .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.9))
            .disabled(club.busy)
        }
        .padding(.top, 6)
    }
}

struct ClubPerk: View {
    let symbol: String
    let title: String
    let line: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 16, weight: .black)).foregroundStyle(UI.ink)
                .frame(width: 36, height: 36).background(RoundedRectangle(cornerRadius: 10).fill(UI.sun))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(UI.foam)
                Text(line).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The small crown pill on the title screen.
struct ClubPill: View {
    let member: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill").font(.system(size: 13, weight: .black))
                Text(member ? "MEMBER" : "CLUB").font(.system(size: 14, weight: .black, design: .rounded))
            }
            .foregroundStyle(member ? UI.ink : UI.sun)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(member ? UI.sun : UI.ink.opacity(0.45)))
            .overlay(Capsule().stroke(UI.sun, lineWidth: member ? 0 : 2))
        }
        .accessibilityLabel(member ? "Strait Club, member" : "Strait Club")
    }
}

// MARK: - The Club Season

/// The season card under the Daily Strait on the title screen.
struct SeasonCard: View {
    @ObservedObject var progress: Logbook
    var onOpen: () -> Void
    var body: some View {
        let s = progress.season
        let done = progress.seasonDone.count
        Button(action: onOpen) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(UI.foam.opacity(0.18), lineWidth: 5)
                    Circle().trim(from: 0, to: CGFloat(done) / CGFloat(Season.goalCount))
                        .stroke(UI.sun, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                    Image(systemName: "star.fill").font(.system(size: 14, weight: .black)).foregroundStyle(UI.sun)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text("SEASON \(s.number)  ·  \(s.title.uppercased())")
                        .font(.system(size: 11, weight: .black, design: .rounded)).kerning(1).foregroundStyle(UI.sun)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text("\(done) OF \(Season.goalCount) GOALS")
                        .font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(UI.foam)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .black)).foregroundStyle(UI.foam.opacity(0.6))
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(UI.ink.opacity(0.35))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(UI.foam.opacity(0.25), lineWidth: 2))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Club Season \(s.number), \(done) of \(Season.goalCount) goals done")
    }
}

struct SeasonSheet: View {
    @ObservedObject var progress: Logbook
    @ObservedObject var club: Club
    var onPlay: (SeasonGoal) -> Void
    var onClub: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let s = progress.season
        let done = progress.seasonDone
        ZStack(alignment: .topTrailing) {
            UI.deep.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Kicker("SEASON \(s.number)  ·  \(s.monthName)")
                        Text(s.title.uppercased()).font(.system(size: 34, weight: .black, design: .rounded)).kerning(2).foregroundStyle(UI.foam)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text("\(done.count) of \(Season.goalCount) goals done. \(endsLine). Finish all ten for the Full Season medal and the Season Stars trail.")
                            .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 22).padding(.trailing, 40)

                    ForEach(s.goals) { g in row(g, done: done.contains(g.index)) }

                    if !club.isMember {
                        Panel(tint: UI.sun) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("GOALS 4 TO 10 ARE FOR THE STRAIT CLUB").font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(UI.foam)
                                Text("They take you through the Fog Channel, the Marina and the Night Canal. A new set every month.")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.8))
                                Button("SEE THE CLUB") { dismiss(); onClub() }
                                    .font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(UI.ink)
                                    .padding(.horizontal, 16).padding(.vertical, 9).background(Capsule().fill(UI.sun))
                            }
                        }
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 30)
            }
            CloseX { dismiss() }.padding(16)
        }
    }

    private var endsLine: String {
        let cal = Calendar.current
        let now = Date()
        guard let interval = cal.dateInterval(of: .month, for: now) else { return "" }
        let days = max(1, cal.dateComponents([.day], from: cal.startOfDay(for: now), to: interval.end).day ?? 1)
        return days == 1 ? "Ends tonight" : "\(days) days left"
    }

    private func row(_ g: SeasonGoal, done: Bool) -> some View {
        let who = Blowhard.with(g.cast)
        let locked = g.isClub && !club.isMember
        return Button {
            if locked { dismiss(); onClub() } else { dismiss(); onPlay(g) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(who.waterColor)
                    if done {
                        Image(systemName: "checkmark").font(.system(size: 18, weight: .black)).foregroundStyle(UI.sun)
                    } else {
                        Text("\(g.number)").font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(UI.foam)
                    }
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(who.name.uppercased())  ·  \(g.condition.name.uppercased())")
                        .font(.system(size: 10, weight: .black, design: .rounded)).kerning(0.8).foregroundStyle(UI.sun)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(g.goal.text).font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(UI.foam)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 4)
                if locked {
                    Image(systemName: "lock.fill").foregroundStyle(UI.foam.opacity(0.5))
                } else {
                    Image(systemName: done ? "arrow.counterclockwise" : "play.fill").font(.system(size: 14, weight: .black))
                        .foregroundStyle(UI.ink).frame(width: 34, height: 34).background(Circle().fill(UI.sun))
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(UI.foam.opacity(done ? 0.13 : 0.06)))
            .opacity(locked ? 0.75 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Goal \(g.number), \(who.name), \(g.condition.name): \(g.goal.text). \(done ? "Done." : locked ? "Strait Club." : "")")
    }
}
