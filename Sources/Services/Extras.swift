import Foundation
import StoreKit
import UIKit

/// The 99-cent corner, kept apart from PackStore so the pack's purchase and its
/// paid-era grandfathering are untouched.
///
/// Three consumables, which top up Logbook credits and can be bought as often
/// as anyone likes, and two one-time cosmetics.
@MainActor
final class Extras: ObservableObject {
    static let shared = Extras()

    static let retriesID = "com.mattbusel.clearthestrait.retries"
    static let shieldsID = "com.mattbusel.clearthestrait.shields"
    static let postcardsID = "com.mattbusel.clearthestrait.postcards"
    static let trailsID = "com.mattbusel.clearthestrait.trails"
    static let iconsID = "com.mattbusel.clearthestrait.icons"
    static let all = [retriesID, shieldsID, postcardsID, trailsID, iconsID]

    /// How many credits each consumable adds.
    static let credits: [String: Int] = [retriesID: 3, shieldsID: 2, postcardsID: 3]

    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var owned: Set<String>
    @Published var busy: String?
    @Published var message: String?

    private var updates: Task<Void, Never>?
    private let demo: Bool

    var ownsTrails: Bool { owned.contains(Extras.trailsID) }
    var ownsIcons: Bool { owned.contains(Extras.iconsID) }
    func price(_ id: String) -> String { products[id]?.displayPrice ?? "$0.99" }

    private init() {
        let args = ProcessInfo.processInfo.arguments
        demo = args.contains("-shot") || args.contains("-demoAutoplay") || args.contains("-FASTLANE_SNAPSHOT")
        if demo {
            owned = args.contains("locked") ? [] : [Extras.trailsID]
            return
        }
        owned = Set(UserDefaults.standard.stringArray(forKey: "extras.owned") ?? [])
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            await refresh()
            for await result in Transaction.unfinished { await handle(result) }
        }
    }

    func load() async {
        guard !demo, products.count < Extras.all.count else { return }
        if let ps = try? await Product.products(for: Extras.all) {
            for p in ps { products[p.id] = p }
        }
    }

    func refresh() async {
        guard !demo else { return }
        var has: Set<String> = []
        for await r in Transaction.currentEntitlements {
            if case .verified(let t) = r, t.revocationDate == nil, t.productType == .nonConsumable, Extras.all.contains(t.productID) {
                has.insert(t.productID)
            }
        }
        owned = has
        UserDefaults.standard.set(Array(has), forKey: "extras.owned")
        // The Club also opens the icons. Only put the icon back once StoreKit has
        // answered for the Club too, so a member is never reset on a guess. A
        // paid trail is not reset at all: it simply plays as Sea Spray until it
        // is theirs again (see RootView.trail).
        await Club.shared.refresh()
        if !has.contains(Extras.iconsID), Club.shared.checked, !Club.shared.isMember, UIApplication.shared.alternateIconName != nil {
            try? await UIApplication.shared.setAlternateIconName(nil)
        }
        await load()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let t) = result, Extras.all.contains(t.productID) else { return }
        credit(t)
        await t.finish()
        await refresh()
    }

    /// Bank a consumable once per transaction, however many times StoreKit reports it.
    private func credit(_ t: Transaction) {
        guard let n = Extras.credits[t.productID], t.revocationDate == nil else { return }
        var seen = Set(UserDefaults.standard.stringArray(forKey: "extras.credited") ?? [])
        guard !seen.contains(String(t.id)) else { return }
        seen.insert(String(t.id))
        UserDefaults.standard.set(Array(seen), forKey: "extras.credited")
        apply(t.productID, n)
    }

    private func apply(_ id: String, _ n: Int) {
        switch id {
        case Extras.retriesID: Logbook.shared.add(retries: n)
        case Extras.shieldsID: Logbook.shared.add(shields: n)
        case Extras.postcardsID: Logbook.shared.add(postcards: n)
        default: break
        }
    }

    @discardableResult
    func buy(_ id: String) async -> Bool {
        message = nil
        if demo {
            if let n = Extras.credits[id] { apply(id, n) } else { owned.insert(id) }
            return true
        }
        await load()
        guard let product = products[id] else {
            message = "The App Store is not answering right now. Check your connection and try again."
            return false
        }
        busy = id
        defer { busy = nil }
        do {
            switch try await product.purchase() {
            case .success(let r):
                guard case .verified(let t) = r else {
                    message = "Apple could not confirm that purchase. Nothing was charged twice."
                    return false
                }
                credit(t)
                await t.finish()
                await refresh()
                Haptics.launch()
                return true
            case .pending:
                message = "Waiting for approval. It arrives by itself once approved."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "The purchase did not go through. Nothing was charged."
        }
        return false
    }

    func restore() async {
        guard !demo else { return }
        busy = "restore"
        defer { busy = nil }
        do { try await AppStore.sync() } catch {
            message = "Could not reach the App Store to restore. Please try again."
            return
        }
        await refresh()
        message = owned.isEmpty ? "No trail or icon purchase found. Credits are used as you go and do not restore." : "Restored."
    }
}

/// The alternate icons that come with the Icon Pack.
enum AltIcon: String, CaseIterable, Identifiable {
    case classic, night, marina, fog
    var id: String { rawValue }
    var name: String {
        switch self {
        case .classic: return "Classic"
        case .night: return "Night Canal"
        case .marina: return "Marina"
        case .fog: return "Fog"
        }
    }
    /// The asset name, nil for the default icon.
    var asset: String? {
        switch self {
        case .classic: return nil
        case .night: return "AppIcon-Night"
        case .marina: return "AppIcon-Marina"
        case .fog: return "AppIcon-Fog"
        }
    }
}
