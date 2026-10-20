import SwiftUI
import TipKit

/// The first two rounds teach the game while it plays: a line at the bottom of
/// the screen for the rock, then for the bubbles. It never blocks a tap.
struct Coach: View {
    /// Seconds into the round, ticked by the host.
    @State private var step = 0
    @State private var shown = true
    var body: some View {
        VStack {
            Spacer()
            if shown {
                VStack(spacing: 6) {
                    Image(systemName: step == 0 ? "hand.tap.fill" : step == 1 ? "metronome.fill" : "bubble.left.fill")
                        .font(.system(size: 26, weight: .black)).foregroundStyle(UI.sun)
                        .symbolEffect(.pulse)
                    Text(line).font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(UI.foam)
                        .multilineTextAlignment(.center)
                    Text(sub).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
                .frame(maxWidth: 360)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(UI.ink.opacity(0.78)))
                .padding(.bottom, 44)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(step)
            }
        }
        .allowsHitTesting(false)
        .task {
            // 0-6 s: the shove. 6-11 s: the rhythm. 11-20 s: the bubbles (they start at 8 s).
            try? await Task.sleep(for: .seconds(6))
            withAnimation(.spring) { step = 1 }
            try? await Task.sleep(for: .seconds(5))
            withAnimation(.spring) { step = 2 }
            try? await Task.sleep(for: .seconds(9))
            withAnimation(.easeOut) { shown = false }
        }
        .accessibilityElement(children: .combine)
    }

    private var line: String {
        switch step {
        case 0: return "TAP HIS LEFT SIDE TO SHOVE HIM RIGHT"
        case 1: return "SHOVE THE WAY HE IS ROCKING"
        default: return "POP THE BUBBLES THAT COME BACK"
        }
    }

    private var sub: String {
        switch step {
        case 0: return "And his right side to shove him left."
        case 1: return "In time with his swing builds a combo. Mashing fights it."
        default: return "Every compliment that reaches him makes him bigger and harder to move."
        }
    }

    /// Shown for a player's first two rounds.
    static var isDue: Bool {
        let a = ProcessInfo.processInfo.arguments
        if a.contains("-coach") { return true }
        if a.contains("-shot") || a.contains("-demoAutoplay") || a.contains("-FASTLANE_SNAPSHOT") { return false }
        return UserDefaults.standard.integer(forKey: "coach.rounds") < 2 && Logbook.shared.career.rounds < 2
    }

    /// A screenshot run or the review recording.
    static var isAutomated: Bool {
        let a = ProcessInfo.processInfo.arguments
        return a.contains("-shot") || a.contains("-demoAutoplay") || a.contains("-FASTLANE_SNAPSHOT")
    }

    static func roundStarted() {
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "coach.rounds") + 1, forKey: "coach.rounds")
    }
}

// MARK: - Tips

struct DailyTip: Tip {
    var title: Text { Text("A new strait every day") }
    var message: Text? { Text("The same challenge for everyone today. Beat it to start a streak.") }
    var image: Image? { Image(systemName: "calendar") }
}

struct SeasonTip: Tip {
    @Parameter static var roundsPlayed: Int = 0
    var title: Text { Text("This month's season") }
    var message: Text? { Text("Ten goals, a new set every month. The first three are open to everyone.") }
    var image: Image? { Image(systemName: "star.circle.fill") }
    var rules: [Rule] { [#Rule(Self.$roundsPlayed) { $0 >= 2 }] }
}

enum TipSetup {
    static func configure() {
        let a = ProcessInfo.processInfo.arguments
        if a.contains("-shot") || a.contains("-demoAutoplay") || a.contains("-FASTLANE_SNAPSHOT") {
            Tips.hideAllTipsForTesting()
        }
        try? Tips.configure([.displayFrequency(.immediate)])
    }
}
