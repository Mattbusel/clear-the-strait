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
    @ObservedObject private var store = PackStore.shared
    @ObservedObject private var progress = Logbook.shared
    @ObservedObject private var extras = Extras.shared
    @AppStorage("cast.selected") private var selectedRaw = Blowhard.ID.blowhard.rawValue
    @State private var showPack = false
    @State private var showLocker = false
    @State private var showRetry = false
    /// True while the round being played is today's Daily Strait.
    @State private var isDaily = false
    @State private var news = RoundNews()
    @State private var roundID = 0
    @Environment(\.scenePhase) private var phase

    /// The blowhard for the next round. A pack character whose purchase was
    /// refunded falls back to the free one rather than staying playable.
    private var who: Blowhard {
        let chosen = Blowhard.with(Blowhard.ID(rawValue: selectedRaw) ?? .blowhard)
        return chosen.isPack && !store.owned ? .blowhard : chosen
    }

    private var selection: Binding<Blowhard.ID> {
        Binding(get: { who.id }, set: { selectedRaw = $0.rawValue })
    }

    var body: some View {
        ZStack {
            // The title takes on the chosen channel's water.
            who.waterColor.ignoresSafeArea()
                .animation(.easeInOut(duration: 0.35), value: who.id)

            switch screen {
            case .title:
                TitleView(who: who, selection: selection, owned: store.owned, progress: progress,
                          onPack: { showPack = true }, onLocker: { showLocker = true },
                          onDaily: playDaily) { play(daily: false) }
                    .transition(.opacity)

            case .playing:
                GameHost(who: isDaily ? .blowhard : who,
                         twist: isDaily ? progress.daily.condition.twist : nil,
                         trail: progress.trail, roundID: roundID) { result in
                    Scores.record(result)
                    news = progress.record(result, cast: isDaily ? .blowhard : who.id, daily: isDaily)
                    withAnimation(.easeOut(duration: 0.3)) {
                        screen = .result(result)
                    }
                }
                .ignoresSafeArea()
                .transition(.opacity)

            case .result(let result):
                ResultView(result: result, who: isDaily ? .blowhard : who, news: news,
                           daily: isDaily ? progress.daily : nil, progress: progress, extras: extras) {
                    if isDaily { playDaily() } else { play(daily: false) }
                } onTitle: {
                    withAnimation(.easeOut(duration: 0.25)) { screen = .title }
                }
                .transition(.opacity)
            }
        }
        .statusBarHidden()
        .sheet(isPresented: $showPack) { PackSheet(store: store) }
        .sheet(isPresented: $showLocker) { LockerSheet(progress: progress, extras: extras) }
        .sheet(isPresented: $showRetry) { RetrySheet(extras: extras, progress: progress) { playDaily() } }
        .task(id: screenKey) { await demoStep() }
        .onAppear(perform: applyLaunchArguments)
        .onChange(of: phase) { _, p in if p == .active { progress.rollDay() } }
    }

    /// A fresh round. The id makes the scene holder build a new scene even when
    /// the same blowhard plays twice in a row.
    private func play(daily: Bool) {
        isDaily = daily
        roundID += 1
        withAnimation(.easeOut(duration: 0.25)) { screen = .playing }
    }

    /// Today's strait, if there is a try left; the retry sheet if not.
    private func playDaily() {
        if progress.career.dailyWon && !progress.hasFreeAttempt && progress.career.retries == 0 {
            // Already beaten: play it again for fun, without spending anything.
            play(daily: true)
            return
        }
        if progress.startDaily() { play(daily: true) } else { showRetry = true }
    }

    /// Screenshot and review-recording switches. Debug builds only.
    private func applyLaunchArguments() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-cast"), i + 1 < args.count,
           let id = Blowhard.ID(rawValue: args[i + 1]) {
            selectedRaw = id.rawValue
        }
        if args.contains("-showPack") { showPack = true }
        if let i = args.firstIndex(of: "-shot"), i + 1 < args.count {
            switch args[i + 1] {
            case "locker": showLocker = true
            case "retry": showRetry = true
            case "result", "dailyresult":
                let r = RoundResult(clearSeconds: 47.3, launchMetres: 112_480, maxComboCount: 31,
                                    maxComboTier: .tremendous, maxEgoPercent: 214, shipsFreed: 38, bubblesPopped: 15)
                isDaily = args[i + 1] == "dailyresult"
                news = RoundNews(newMedals: isDaily ? [] : [Medal.all[7]], dailyWon: isDaily, dailyFailed: false, streak: 10)
                screen = .result(r)
            default: break
            }
        }
        #endif
    }

    private var screenKey: Int {
        switch screen {
        case .title: return 0
        case .playing: return 1
        case .result: return 2
        }
    }

    #if DEBUG
    @State private var demoFinished = false
    #endif

    /// Presses the buttons for the App Review recording, alongside the scene's
    /// autoplay: title, one round, the result, back to the title. Debug builds
    /// only, and only when launched with `-demoAutoplay`.
    private func demoStep() async {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-demoAutoplay") else { return }
        switch screen {
        case .title:
            try? await Task.sleep(for: .seconds(3))
            if demoFinished {
                // Tells the recording workflow it can stop.
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                FileManager.default.createFile(atPath: url.appendingPathComponent("demo_done").path,
                                               contents: nil)
                return
            }
            withAnimation(.easeOut(duration: 0.25)) { screen = .playing }
        case .playing:
            break
        case .result:
            try? await Task.sleep(for: .seconds(6))
            demoFinished = true
            withAnimation(.easeOut(duration: 0.25)) { screen = .title }
        }
        #endif
    }
}

struct TitleView: View {
    let who: Blowhard
    @Binding var selection: Blowhard.ID
    let owned: Bool
    @ObservedObject var progress: Logbook
    var onPack: () -> Void
    var onLocker: () -> Void
    var onDaily: () -> Void
    var onPlay: () -> Void
    @State private var bob = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onLocker) {
                    HStack(spacing: 6) {
                        Image(systemName: "medal.fill").font(.system(size: 14, weight: .black))
                        Text("\(progress.career.medals.count)/\(Medal.all.count)").font(.system(size: 14, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(UI.ink)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(UI.sun))
                }
                .accessibilityLabel("The Locker: medals, records, trails and shop")
            }
            .padding(.horizontal, 20).padding(.top, 14)

            Spacer()

            Text("CLEAR THE")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .kerning(4)
                .foregroundStyle(UI.foam)
            Text("STRAIT")
                .font(.system(size: 68, weight: .black, design: .rounded))
                .kerning(6)
                .foregroundStyle(UI.sun)

            // The chosen blowhard, bobbing, drawn by the same node the game uses.
            Portrait(who: who, side: 170)
                .offset(y: bob ? -10 : 10)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: bob)
                .padding(.top, 14)
                .padding(.bottom, 6)

            Text(who.channel.uppercased())
                .font(.system(size: 13, weight: .black, design: .rounded))
                .kerning(2)
                .foregroundStyle(UI.sun)
            Text(who.isPack ? who.twistLine : "He is stuck. Shove him out.")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(UI.foam.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.top, 4)

            Spacer()

            if let n = progress.notice {
                Text(n).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(UI.ink)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(UI.sun))
                    .padding(.bottom, 8)
                    .onTapGesture { progress.notice = nil }
            }

            DailyCard(progress: progress, onPlay: onDaily)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            CastPicker(selected: $selection, owned: owned, onLocked: onPack)
                .padding(.bottom, 10)

            if !owned {
                Button(action: onPack) {
                    Text("GET THE BLOWHARD PACK")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .kerning(1.2)
                        .foregroundStyle(UI.sun)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Capsule().stroke(UI.sun.opacity(0.8), lineWidth: 2))
                }
                .padding(.bottom, 16)
            } else {
                Color.clear.frame(height: 12)
            }

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

struct ResultView: View {
    let result: RoundResult
    let who: Blowhard
    let news: RoundNews
    let daily: DailyStrait?
    @ObservedObject var progress: Logbook
    @ObservedObject var extras: Extras
    var onAgain: () -> Void
    var onTitle: () -> Void
    @State private var shown: Double = 0
    @State private var card: UIImage?
    @State private var showBuyPostcards = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            Text(daily.map { "DAILY STRAIT #\($0.number)" } ?? "STRAIT")
                .font(.system(size: daily != nil ? 22 : 34, weight: .black, design: .rounded))
                .kerning(4)
                .foregroundStyle(UI.foam)
            Text("CLEARED!")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .kerning(4)
                .foregroundStyle(UI.sun)

            // The distance counts up, because the number is the payoff.
            Text("\(Int(shown).formatted()) m")
                .font(.system(size: 46, weight: .black, design: .rounded))
                .foregroundStyle(UI.foam)
                .contentTransition(.numericText(value: shown))
                .padding(.bottom, 14)

            if let daily {
                dailyBanner(daily)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 12)
            }

            VStack(spacing: 10) {
                row("CLEAR TIME", String(format: "%.2f sec", result.clearSeconds))
                row("MAX COMBO", "\(result.maxComboTier.label) x\(result.maxComboCount)")
                row("MAX EGO", "\(Int(result.maxEgoPercent))%")
                row("BUBBLES POPPED", "\(result.bubblesPopped)")
                row("SHIPS FREED", "\(result.shipsFreed)")
            }
            .padding(.horizontal, 30)

            if result.launchMetres >= Scores.bestLaunch, result.launchMetres > 0, daily == nil {
                pill("NEW BEST LAUNCH")
            }
            ForEach(news.newMedals) { m in
                HStack(spacing: 8) {
                    Image(systemName: m.symbol).font(.system(size: 14, weight: .black))
                    Text("MEDAL: \(m.name.uppercased())").font(.system(size: 14, weight: .black, design: .rounded)).kerning(1)
                    if let t = m.unlocks { Text("+ \(t.name.uppercased()) TRAIL").font(.system(size: 12, weight: .black, design: .rounded)) }
                }
                .foregroundStyle(UI.ink)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Capsule().fill(UI.sun))
                .padding(.top, 8)
            }

            Spacer(minLength: 16)

            VStack(spacing: 12) {
                Button(againLabel, action: onAgain)
                    .buttonStyle(ArcadeButton())
                HStack(spacing: 10) {
                    ShareLink(item: result.shareText) {
                        Text("SHARE").outlined()
                    }
                    if let card {
                        ShareLink(item: Image(uiImage: card), preview: SharePreview("Clear the Strait postcard", image: Image(uiImage: card))) {
                            Text("SEND IT").outlined()
                        }
                    } else {
                        Button { makePostcard() } label: {
                            Text(postcardLabel).outlined()
                        }
                    }
                }
                Button("TITLE", action: onTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(UI.foam.opacity(0.8))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 34)

            Spacer().frame(height: 24)
        }
        .background(UI.deep.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) { shown = result.launchMetres }
        }
        .sheet(isPresented: $showBuyPostcards) { postcardSheet }
    }

    private var againLabel: String {
        guard daily != nil else { return "PLAY AGAIN" }
        if progress.career.dailyWon { return "PLAY IT AGAIN" }
        return progress.attemptsLeft > 0 ? "RETRY (\(progress.attemptsLeft) LEFT)" : "GET RETRIES"
    }

    private var postcardLabel: String {
        if !progress.career.freePostcardUsed { return "POSTCARD: FREE" }
        if progress.career.postcards > 0 { return "POSTCARD (\(progress.career.postcards))" }
        return "POSTCARDS"
    }

    /// Spends the free postcard or a credit, then draws it ready to send.
    private func makePostcard() {
        if progress.canMakePostcard {
            card = PostcardView.render(result, who: who, daily: daily)
            if card != nil { progress.spendPostcard() }
        } else {
            showBuyPostcards = true
        }
    }

    private var postcardSheet: some View {
        ZStack {
            UI.deep.ignoresSafeArea()
            VStack(spacing: 16) {
                PostcardView(result: result, who: who, daily: daily).scaleEffect(0.82)
                Text("Three more postcards of your best launches.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam)
                PriceButton(extras: extras, id: Extras.postcardsID, label: "3 POSTCARDS  \(extras.price(Extras.postcardsID))")
                if let m = extras.message { Text(m).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam) }
            }
            .padding(20)
        }
        .presentationDetents([.medium])
        .onChange(of: progress.career.postcards) { _, n in if n > 0 { showBuyPostcards = false; makePostcard() } }
    }

    @ViewBuilder private func dailyBanner(_ d: DailyStrait) -> some View {
        if news.dailyWon {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill").foregroundStyle(UI.coral)
                Text("BEATEN!  \(news.streak)-DAY STREAK").font(.system(size: 16, weight: .black, design: .rounded)).kerning(1).foregroundStyle(UI.ink)
            }
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(Capsule().fill(UI.sun))
        } else if progress.career.dailyWon {
            Text("ALREADY BEATEN TODAY").font(.system(size: 14, weight: .black, design: .rounded)).kerning(1).foregroundStyle(UI.sun)
        } else {
            VStack(spacing: 2) {
                Text("NOT QUITE: \(d.goal.text)").font(.system(size: 14, weight: .black, design: .rounded)).kerning(0.8).foregroundStyle(UI.coral)
                Text(progress.attemptsLeft > 0 ? "You have another go." : "Retries are in the Locker, or try again tomorrow.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(UI.foam.opacity(0.75))
            }
        }
    }

    private func pill(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 14, weight: .black, design: .rounded))
            .kerning(2)
            .foregroundStyle(UI.ink)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Capsule().fill(UI.sun))
            .padding(.top, 12)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .kerning(1.4)
                .foregroundStyle(UI.foam.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(UI.foam)
        }
    }
}

extension Text {
    /// The outlined secondary button on the result screen.
    func outlined() -> some View {
        self.font(.system(size: 18, weight: .black, design: .rounded))
            .kerning(1.2)
            .foregroundStyle(UI.foam)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(UI.foam.opacity(0.7), lineWidth: 3))
    }
}

/// Holds the scene across SwiftUI body evaluations.
///
/// Without this the scene is rebuilt every time the view updates, which resets
/// the round on the first tap.
final class SceneHolder: ObservableObject {
    private var scene: GameScene?
    private var round = -1

    func scene(size: CGSize, who: Blowhard, twist: Twist?, trail: TrailStyle, roundID: Int,
               onFinished: @escaping (RoundResult) -> Void) -> GameScene {
        if let scene, abs(scene.size.width - size.width) < 1, scene.who == who, round == roundID {
            return scene
        }
        round = roundID
        let made = GameScene(size: size, who: who, twist: twist, trail: trail)
        made.scaleMode = .resizeFill
        made.onFinished = onFinished
        scene = made
        return made
    }
}

/// Hosts the SpriteKit scene.
///
/// SpriteView rather than a UIViewRepresentable wrapping SKView.
///
/// The wrapper version presented its scene from `updateUIView`, guarded on the
/// view having a non-zero width. SwiftUI creates the view at zero size and does
/// not reliably call that again after layout, so the guard never passed, no
/// scene was ever presented, and the whole game screen rendered as SKView's
/// default grey. SpriteView is given a size by GeometryReader and handles the
/// presentation itself.
struct GameHost: View {
    let who: Blowhard
    var twist: Twist? = nil
    var trail: TrailStyle = .spray
    var roundID = 0
    var onFinished: (RoundResult) -> Void
    @StateObject private var holder = SceneHolder()

    var body: some View {
        GeometryReader { geo in
            SpriteView(
                scene: holder.scene(size: geo.size, who: who, twist: twist, trail: trail, roundID: roundID, onFinished: onFinished),
                options: [.ignoresSiblingOrder]
            )
            .ignoresSafeArea()
        }
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
