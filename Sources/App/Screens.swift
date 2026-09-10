import GameKit
import SpriteKit
import SwiftUI

/// The app's three states. There is no navigation stack because there is
/// nowhere to navigate: you are on the title, in a round, or looking at what
/// just happened.
enum Screen {
    case title
    case playing
    case result(RoundResult)
}

enum UI {
    static let sea = Color(red: 0.13, green: 0.60, blue: 0.82)
    static let deep = Color(red: 0.06, green: 0.33, blue: 0.52)
    static let sun = Color(red: 0.99, green: 0.78, blue: 0.24)
    static let coral = Color(red: 0.94, green: 0.30, blue: 0.30)
    static let foam = Color(red: 0.94, green: 0.99, blue: 1.00)
    static let ink = Color(red: 0.07, green: 0.12, blue: 0.22)
}

/// A big soft arcade button. The only button shape in the app.
struct ArcadeButton: ButtonStyle {
    var fill: Color = UI.sun
    var text: Color = UI.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 26, weight: .black, design: .rounded))
            .kerning(1.5)
            .foregroundStyle(text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(fill)
                    // A hard bottom edge instead of a shadow, which reads as a
                    // physical key rather than a floating card.
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(UI.ink.opacity(0.25), lineWidth: 4)
                            .offset(y: 4)
                            .mask(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct RootView: View {
    @State private var screen: Screen = .title

    var body: some View {
        ZStack {
            UI.sea.ignoresSafeArea()

            switch screen {
            case .title:
                TitleView { screen = .playing }
                    .transition(.opacity)

            case .playing:
                GameHost { result in
                    Scores.record(result)
                    GameCenter.submit(result)
                    withAnimation(.easeOut(duration: 0.3)) {
                        screen = .result(result)
                    }
                }
                .ignoresSafeArea()
                .transition(.opacity)

            case .result(let result):
                ResultView(result: result) {
                    withAnimation(.easeOut(duration: 0.25)) { screen = .playing }
                } onTitle: {
                    withAnimation(.easeOut(duration: 0.25)) { screen = .title }
                }
                .transition(.opacity)
            }
        }
        .statusBarHidden()
        .onAppear {
            GameCenter.authenticate { controller in
                UIApplication.shared.topViewController?.present(controller, animated: true)
            }
        }
    }
}

struct TitleView: View {
    var onPlay: () -> Void
    @State private var bob = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("CLEAR THE")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .kerning(4)
                .foregroundStyle(UI.foam)
            Text("STRAIT")
                .font(.system(size: 68, weight: .black, design: .rounded))
                .kerning(6)
                .foregroundStyle(UI.sun)

            // The blocker, bobbing, drawn with the same shapes the game uses.
            BlockerMark()
                .frame(width: 190, height: 190)
                .offset(y: bob ? -10 : 10)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: bob)
                .padding(.vertical, 26)

            Text("He is stuck. Shove him out.")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(UI.foam.opacity(0.9))

            Spacer()

            Button("PLAY", action: onPlay)
                .buttonStyle(ArcadeButton())
                .padding(.horizontal, 40)

            if Scores.bestLaunch > 0 {
                Text("BEST LAUNCH  \(Int(Scores.bestLaunch)) m")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .kerning(1.5)
                    .foregroundStyle(UI.foam.opacity(0.85))
                    .padding(.top, 18)
            } else {
                Color.clear.frame(height: 36)
            }

            Spacer().frame(height: 34)
        }
        .onAppear { bob = true }
    }
}

/// The character as a static mark, for the title screen.
///
/// Drawn in SwiftUI rather than reusing the SpriteKit node, because embedding a
/// whole scene to show one stationary shape is a lot of machinery for a picture.
struct BlockerMark: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .fill(Color(red: 0.16, green: 0.26, blue: 0.52))
                    .overlay(Circle().stroke(Color(red: 0.10, green: 0.16, blue: 0.36), lineWidth: 4))

                // Hair
                Ellipse()
                    .fill(Color(red: 0.98, green: 0.84, blue: 0.42))
                    .frame(width: s * 0.78, height: s * 0.30)
                    .offset(y: -s * 0.40)
                    .rotationEffect(.degrees(-6))

                // Shirt and tie
                Capsule()
                    .fill(UI.foam)
                    .frame(width: s * 0.26, height: s * 0.46)
                    .offset(y: s * 0.14)
                Capsule()
                    .fill(Color(red: 0.88, green: 0.16, blue: 0.22))
                    .frame(width: s * 0.10, height: s * 0.44)
                    .offset(y: s * 0.18)

                // Eyes
                HStack(spacing: s * 0.20) {
                    ForEach(0..<2, id: \.self) { _ in
                        Ellipse()
                            .fill(.white)
                            .overlay(Circle().fill(UI.ink).frame(width: s * 0.045))
                            .frame(width: s * 0.11, height: s * 0.14)
                    }
                }
                .offset(y: -s * 0.10)

                // Mouth
                Ellipse()
                    .fill(Color(red: 0.62, green: 0.20, blue: 0.26))
                    .frame(width: s * 0.20, height: s * 0.09)
                    .offset(y: s * 0.05)
            }
        }
    }
}

struct ResultView: View {
    let result: RoundResult
    var onAgain: () -> Void
    var onTitle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("STRAIT")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .kerning(4)
                .foregroundStyle(UI.foam)
            Text("CLEARED!")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .kerning(4)
                .foregroundStyle(UI.sun)
                .padding(.bottom, 28)

            VStack(spacing: 12) {
                row("CLEAR TIME", String(format: "%.2f sec", result.clearSeconds))
                row("LAUNCH DISTANCE", "\(Int(result.launchMetres)) m", highlight: true)
                row("MAX COMBO", "\(result.maxComboTier.label) x\(result.maxComboCount)")
                row("MAX EGO", "\(Int(result.maxEgoPercent))%")
                row("SHIPS FREED", "\(result.shipsFreed)")
            }
            .padding(.horizontal, 30)

            if result.launchMetres >= Scores.bestLaunch, result.launchMetres > 0 {
                Text("NEW BEST LAUNCH")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .kerning(2)
                    .foregroundStyle(UI.ink)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(UI.sun))
                    .padding(.top, 18)
            }

            Spacer()

            VStack(spacing: 12) {
                Button("PLAY AGAIN", action: onAgain)
                    .buttonStyle(ArcadeButton())
                ShareLink(item: result.shareText) {
                    Text("SHARE")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .kerning(1.5)
                        .foregroundStyle(UI.foam)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(UI.foam.opacity(0.7), lineWidth: 3)
                        )
                }
                Button("TITLE", action: onTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(UI.foam.opacity(0.8))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 34)

            Spacer().frame(height: 30)
        }
        .background(UI.deep.ignoresSafeArea())
    }

    private func row(_ label: String, _ value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .kerning(1.4)
                .foregroundStyle(UI.foam.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: highlight ? 26 : 19, weight: .black, design: .rounded))
                .foregroundStyle(highlight ? UI.sun : UI.foam)
        }
    }
}

/// Hosts the SpriteKit scene.
struct GameHost: UIViewRepresentable {
    var onFinished: (RoundResult) -> Void

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.isMultipleTouchEnabled = false
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        guard view.scene == nil, view.bounds.width > 1 else { return }
        let scene = GameScene(size: view.bounds.size)
        scene.scaleMode = .resizeFill
        scene.onFinished = onFinished
        view.presentScene(scene)
    }
}

extension UIApplication {
    /// The controller to present Game Center's sign-in over.
    var topViewController: UIViewController? {
        let scene = connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
