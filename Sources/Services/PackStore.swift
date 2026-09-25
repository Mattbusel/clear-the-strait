import Foundation
import StoreKit

/// The one thing for sale: the Blowhard Pack.
///
/// StoreKit 2 only. The game itself is free; the pack adds three more
/// blowhards, each in his own channel with his own twist. Nothing else is ever
/// sold, and there are no adverts.
///
/// # People who bought the game when it cost money
///
/// Clear the Strait was a paid app before this version. Anyone who bought it
/// then gets the pack for nothing, forever. `AppTransaction` says which build
/// the person first downloaded; any build before `firstFreeBuild` was a paid
/// download. This only applies to the real App Store: in the sandbox (App
/// Review and TestFlight) the original build is reported as "1", which would
/// unlock the pack for every reviewer and hide the purchase they need to test.
@MainActor
final class PackStore: ObservableObject {
    static let shared = PackStore()

    static let productID = "com.mattbusel.clearthestrait.pack1"

    /// The first build number that was free to download. Builds 1 and 2 were
    /// the paid $1.99 release.
    static let firstFreeBuild = 3

    /// What the price says when the store has not answered yet.
    static let fallbackPrice = "$1.99"

    @Published private(set) var owned: Bool
    @Published private(set) var product: Product?
    @Published private(set) var isBusy = false
    /// A plain-English line for the store sheet, after something happened.
    @Published var message: String?
    /// True when the pack came free because they bought the old paid app.
    @Published private(set) var isThankYou = false

    private let ownedKey = "pack1.owned"
    private let thanksKey = "pack1.grandfathered"
    private var updates: Task<Void, Never>?

    var displayPrice: String { product?.displayPrice ?? PackStore.fallbackPrice }

    private init() {
        let defaults = UserDefaults.standard
        owned = defaults.bool(forKey: ownedKey) || defaults.bool(forKey: thanksKey)
        isThankYou = defaults.bool(forKey: thanksKey)

        #if DEBUG
        // Screenshot runs and the autoplayed rounds happen on a simulator with
        // no Apple Account, where asking StoreKit anything puts a sign-in
        // prompt over the screen. Debug builds only; the store build never
        // skips StoreKit.
        if ProcessInfo.processInfo.arguments.contains("-unlockPack") { owned = true }
        if PackStore.isAutomated { return }
        #endif

        // Purchases made on another device, Ask to Buy approvals and refunds
        // all arrive here, whenever they happen.
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.apply(result)
            }
        }
        Task { await refresh() }
    }

    deinit { updates?.cancel() }

    #if DEBUG
    /// A screenshot run or an autoplayed round.
    static var isAutomated: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-unlockPack") || args.contains("-FASTLANE_SNAPSHOT") || args.contains("-demoAutoplay")
    }
    #endif

    /// Load the product, re-read entitlements and check for a paid-era install.
    func refresh() async {
        #if DEBUG
        if PackStore.isAutomated { return }
        #endif
        if product == nil {
            product = try? await Product.products(for: [PackStore.productID]).first
        }
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == PackStore.productID, t.revocationDate == nil {
                entitled = true
            }
        }
        await checkPaidEraInstall()
        setOwned(entitled || isThankYou)
    }

    /// Buy the pack.
    func buy() async {
        guard !isBusy else { return }
        message = nil
        if product == nil {
            product = try? await Product.products(for: [PackStore.productID]).first
        }
        guard let product else {
            message = "The App Store is not answering right now. Check your connection and try again."
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
                if owned { message = "Unlocked. Three new blowhards are waiting." }
            case .pending:
                message = "Waiting for approval. The pack unlocks as soon as it is approved."
            case .userCancelled:
                break
            @unknown default:
                message = "Something unexpected happened. Nothing was charged."
            }
        } catch {
            message = "The purchase did not go through. Nothing was charged. Please try again."
        }
    }

    /// Restore Purchases.
    func restore() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        message = nil
        do {
            try await AppStore.sync()
        } catch {
            message = "Could not reach the App Store to restore. Please try again."
            return
        }
        await refresh()
        message = owned ? "Restored. The pack is unlocked." : "No earlier purchase of the pack was found on this Apple Account."
    }

    private func apply(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let t) = result, t.productID == PackStore.productID else { return }
        if t.revocationDate == nil {
            setOwned(true)
        } else {
            setOwned(isThankYou)
        }
        await t.finish()
    }

    private func setOwned(_ value: Bool) {
        owned = value
        UserDefaults.standard.set(value, forKey: ownedKey)
    }

    /// Bought the game while it still cost money? Then the pack is theirs.
    private func checkPaidEraInstall() async {
        guard !isThankYou else { return }
        guard let result = try? await AppTransaction.shared,
              case .verified(let app) = result,
              app.environment == .production
        else { return }
        if PackStore.isPaidEra(originalAppVersion: app.originalAppVersion) {
            isThankYou = true
            UserDefaults.standard.set(true, forKey: thanksKey)
        }
    }

    /// Whether the build someone first downloaded was from the paid era.
    ///
    /// On iOS `originalAppVersion` is the CFBundleVersion, which is a plain
    /// build number here ("1", "2", ...). Anything that is not a number is
    /// treated as not paid-era rather than guessed at.
    nonisolated static func isPaidEra(originalAppVersion: String) -> Bool {
        let head = originalAppVersion.split(separator: ".").first.map(String.init) ?? ""
        guard let build = Int(head) else { return false }
        return build < firstFreeBuild
    }
}
