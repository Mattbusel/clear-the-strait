import Foundation
import StoreKit

/// The Strait Club: the auto-renewable subscription (monthly, or yearly with a
/// one-week free trial).
///
/// Kept apart from PackStore and Extras, so the Blowhard Pack's purchase and
/// its paid-era grandfathering, and the 99-cent corner, are untouched. Nothing
/// anyone bought is taken away by joining or leaving: the Club only adds.
///
/// While a member:
/// - all four blowhards (the Blowhard Pack's three included)
/// - every trail and every app icon
/// - unlimited Daily Strait retries and unlimited postcards
/// - three Streak Shields a month (the free one plus `monthlyShields`)
/// - all ten goals of each month's Club Season (everyone gets the first three)
@MainActor
final class Club: ObservableObject {
    static let shared = Club()

    static let monthlyID = "com.mattbusel.clearthestrait.club.monthly"
    static let yearlyID = "com.mattbusel.clearthestrait.club.yearly"
    static let ids = [yearlyID, monthlyID]
    /// Shields a member gets each month on top of everyone's free one.
    static let monthlyShields = 2

    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://tensorust.com/apps/clear-the-strait/privacy/")!

    @Published private(set) var isMember: Bool
    @Published private(set) var products: [Product] = []
    /// The plan in force, and when it renews or ends.
    @Published private(set) var activeID: String?
    @Published private(set) var renews: Date?
    @Published private(set) var willRenew = true
    @Published private(set) var trialEligible = true
    @Published private(set) var busy = false
    @Published var message: String?
    /// True once StoreKit has answered at least once, so nothing is taken away on a guess.
    private(set) var checked = false

    private let memberKey = "club.member"
    private var updates: Task<Void, Never>?
    private let demo: Bool

    var yearly: Product? { products.first { $0.id == Club.yearlyID } }
    var monthly: Product? { products.first { $0.id == Club.monthlyID } }

    private init() {
        let args = ProcessInfo.processInfo.arguments
        #if DEBUG
        demo = args.contains("-shot") || args.contains("-demoAutoplay") || args.contains("-FASTLANE_SNAPSHOT")
        #else
        demo = false
        #endif
        if demo {
            isMember = args.contains("-club")
            checked = true
            if isMember { activeID = Club.yearlyID; renews = Calendar.current.date(byAdding: .day, value: 214, to: Date()) }
            return
        }
        isMember = UserDefaults.standard.bool(forKey: memberKey)
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            for await result in Transaction.unfinished { await handle(result) }
            await refresh()
        }
    }

    deinit { updates?.cancel() }

    func load() async {
        guard !demo, products.count < Club.ids.count else { return }
        if let ps = try? await Product.products(for: Club.ids) {
            products = ps.sorted { ($0.id == Club.yearlyID ? 0 : 1) < ($1.id == Club.yearlyID ? 0 : 1) }
        }
        if let sub = yearly?.subscription {
            trialEligible = await sub.isEligibleForIntroOffer
        }
    }

    /// Re-read what StoreKit says is in force.
    func refresh() async {
        guard !demo else { return }
        var active: Transaction?
        for await r in Transaction.currentEntitlements {
            guard case .verified(let t) = r, Club.ids.contains(t.productID), t.revocationDate == nil else { continue }
            if let end = t.expirationDate, end < Date() { continue }
            active = t
        }
        let was = isMember
        isMember = active != nil
        activeID = active?.productID
        renews = active?.expirationDate
        willRenew = true
        if let p = products.first(where: { $0.id == active?.productID }) ?? yearly ?? monthly,
           let statuses = try? await p.subscription?.status {
            for s in statuses {
                if case .verified(let info) = s.renewalInfo, info.currentProductID == active?.productID {
                    willRenew = info.willAutoRenew
                }
            }
        }
        checked = true
        UserDefaults.standard.set(isMember, forKey: memberKey)
        if isMember != was || isMember {
            // Hand out this month's member shields, and redraw anything that depends on the Club.
            Logbook.shared.rollDay()
        }
        await load()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let t) = result, Club.ids.contains(t.productID) else { return }
        await t.finish()
        await refresh()
    }

    @discardableResult
    func buy(_ product: Product) async -> Bool {
        guard !busy else { return false }
        message = nil
        busy = true
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let r):
                guard case .verified(let t) = r else {
                    message = "Apple could not confirm that purchase."
                    return false
                }
                await t.finish()
                await refresh()
                if isMember { message = "Welcome to the Strait Club." }
                return isMember
            case .pending:
                message = "Waiting for approval. The Club opens as soon as it is approved."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "The purchase did not go through. Nothing was charged. Please try again."
        }
        return false
    }

    func restore() async {
        guard !demo else { return }
        busy = true
        defer { busy = false }
        message = nil
        do { try await AppStore.sync() } catch {
            message = "Could not reach the App Store to restore. Please try again."
            return
        }
        await refresh()
        message = isMember ? "Restored. Welcome back to the Club." : "No active Strait Club subscription was found on this Apple Account."
    }

    /// "$14.99 a year", "$2.99 a month".
    static func priceLine(_ p: Product?) -> String {
        guard let p else { return "" }
        let unit: String
        switch p.subscription?.subscriptionPeriod.unit {
        case .year: unit = "year"
        case .month: unit = "month"
        case .week: unit = "week"
        default: unit = "period"
        }
        return "\(p.displayPrice) a \(unit)"
    }

    /// "1-week free trial", from the product itself so the text always matches the offer.
    static func trialLine(_ p: Product?) -> String? {
        guard let offer = p?.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let n = offer.period.value
        let unit: String
        switch offer.period.unit {
        case .day: unit = n == 1 ? "day" : "days"
        case .week: unit = n == 1 ? "week" : "weeks"
        case .month: unit = n == 1 ? "month" : "months"
        case .year: unit = n == 1 ? "year" : "years"
        @unknown default: unit = "period"
        }
        return n == 1 ? "1-\(unit) free trial" : "\(n)-\(unit) free trial"
    }
}
