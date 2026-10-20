import GameKit
import UIKit

/// Game Center: three leaderboards and an achievement for every medal.
///
/// Signing in is never forced. The system's sign-in sheet, if Game Center
/// wants one, is kept until the player taps LEADERBOARDS, rather than thrown
/// over the title screen on launch. Scores and achievements are only sent
/// when the player is signed in; nothing else changes either way.
@MainActor
final class GameCenter: NSObject, ObservableObject, GKGameCenterControllerDelegate {
    static let shared = GameCenter()

    /// IDs must match Store/gamecenter.py.
    static let longest = "clearthestrait.longest"
    static let fastest = "clearthestrait.fastest"
    static let daily = "clearthestrait.daily"
    static func achievement(_ medal: String) -> String { "clearthestrait.medal.\(medal)" }

    @Published private(set) var isAuthenticated = false
    private var signIn: UIViewController?
    private var started = false

    private var automated: Bool {
        let a = ProcessInfo.processInfo.arguments
        return a.contains("-shot") || a.contains("-demoAutoplay") || a.contains("-FASTLANE_SNAPSHOT")
    }

    func start() {
        guard !started, !automated else { return }
        started = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, _ in
            Task { @MainActor in
                guard let self else { return }
                self.signIn = vc
                let was = self.isAuthenticated
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if self.isAuthenticated && !was { self.syncMedals() }
            }
        }
    }

    /// A finished round: the all-time boards, and today's board for a Daily Strait.
    func submit(_ r: RoundResult, daily: Bool) {
        guard isAuthenticated, r.launchMetres > 0 else { return }
        var boards = [GameCenter.longest]
        if daily { boards.append(GameCenter.daily) }
        let metres = Int(r.launchMetres)
        let centis = Int((r.clearSeconds * 100).rounded())
        Task {
            try? await GKLeaderboard.submitScore(metres, context: 0, player: GKLocalPlayer.local, leaderboardIDs: boards)
            if centis > 0 {
                try? await GKLeaderboard.submitScore(centis, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [GameCenter.fastest])
            }
        }
    }

    /// Medals become achievements. Reporting one twice is harmless.
    func report(_ medals: [String]) {
        guard isAuthenticated, !medals.isEmpty else { return }
        let list = medals.map { id -> GKAchievement in
            let a = GKAchievement(identifier: GameCenter.achievement(id))
            a.percentComplete = 100
            a.showsCompletionBanner = true
            return a
        }
        GKAchievement.report(list) { _ in }
    }

    /// Everything earned before Game Center was signed in.
    private func syncMedals() {
        let have = Logbook.shared.career.medals
        guard !have.isEmpty else { return }
        let list = have.map { id -> GKAchievement in
            let a = GKAchievement(identifier: GameCenter.achievement(id))
            a.percentComplete = 100
            a.showsCompletionBanner = false
            return a
        }
        GKAchievement.report(list) { _ in }
    }

    /// The leaderboards, or Game Center's own sign-in if the player is not signed in yet.
    func show(_ state: GKGameCenterViewControllerState = .leaderboards) {
        guard let top = UIApplication.shared.topViewController else { return }
        if !isAuthenticated {
            if let vc = signIn {
                top.present(vc, animated: true)
            } else if let url = URL(string: UIApplication.openSettingsURLString) {
                // Signed out of Game Center in Settings and the sheet is not offered again.
                UIApplication.shared.open(url)
            }
            return
        }
        let vc = GKGameCenterViewController(state: state)
        vc.gameCenterDelegate = self
        top.present(vc, animated: true)
    }

    nonisolated func gameCenterViewControllerDidFinish(_ vc: GKGameCenterViewController) {
        Task { @MainActor in vc.dismiss(animated: true) }
    }
}
