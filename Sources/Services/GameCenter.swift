import GameKit

/// Game Center, kept to the two leaderboards the spec asks for and nothing else.
///
/// Entirely optional. Every call fails quietly: a player who declines to sign in,
/// or has no network, plays exactly the same game with local bests instead. That
/// is the only reasonable posture for a $1.99 offline arcade game, and it means
/// the app never needs an internet connection to work.
enum GameCenter {
    /// These IDs must match the leaderboards created in App Store Connect.
    /// Referenced from `Store/gamecenter.md`, which is the checklist for setting
    /// them up.
    static let fastestClear = "clearthestrait.fastest"
    static let longestLaunch = "clearthestrait.longest"

    private(set) static var isAvailable = false

    /// Sign in, if the player wants to.
    ///
    /// Apple requires the authenticate handler to be set early, and it may
    /// present a sign-in sheet. If it hands back a view controller the app is
    /// expected to show it; declining is a normal outcome and not an error.
    static func authenticate(present: @escaping (UIViewController) -> Void) {
        GKLocalPlayer.local.authenticateHandler = { viewController, _ in
            if let viewController {
                present(viewController)
                return
            }
            isAvailable = GKLocalPlayer.local.isAuthenticated
        }
    }

    static func submit(_ result: RoundResult) {
        guard isAvailable, GKLocalPlayer.local.isAuthenticated else { return }

        // Both leaderboards take integers. Time is submitted in hundredths so a
        // "fastest" board can be sorted ascending with useful precision.
        let clearHundredths = Int((result.clearSeconds * 100).rounded())
        let metres = Int(result.launchMetres.rounded())

        GKLeaderboard.submitScore(
            clearHundredths, context: 0, player: GKLocalPlayer.local,
            leaderboardIDs: [fastestClear], completionHandler: { _ in }
        )
        GKLeaderboard.submitScore(
            metres, context: 0, player: GKLocalPlayer.local,
            leaderboardIDs: [longestLaunch], completionHandler: { _ in }
        )
    }
}
