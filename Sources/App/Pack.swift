import SpriteKit
import SwiftUI

// MARK: - Portraits

/// A still portrait of one blowhard, drawn by the same node the game uses, so
/// the title screen and the store can never disagree with the round about what
/// he looks like.
final class PortraitScene: SKScene {
    private let who: Blowhard

    init(who: Blowhard, side: CGFloat) {
        self.who = who
        super.init(size: CGSize(width: side, height: side))
        backgroundColor = .clear
        scaleMode = .aspectFit

        let node = Blocker(who: who)
        // Nothing moves here. A physics body would drift under the tiniest
        // force, and a portrait has no business doing that.
        node.physicsBody = nil
        // Everything he wears spans about 1.1 radii below the middle (legs)
        // to 1.6 above (the tall hat), and 1.2 either side.
        let r = Blocker.baseRadius
        let scale = side / (r * 2.9)
        node.setScale(scale)
        node.position = CGPoint(x: side / 2, y: side / 2 - r * 0.22 * scale)
        addChild(node)
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}

struct Portrait: View {
    let who: Blowhard
    var side: CGFloat

    var body: some View {
        SpriteView(scene: PortraitScene(who: who, side: side), options: [.allowsTransparency])
            .frame(width: side, height: side)
            .allowsHitTesting(false)
            .id(who.id)
    }
}

extension Blowhard {
    var waterColor: Color { Color(uiColor: theme.water) }
    var accentColor: Color { Color(uiColor: accent) }
}

// MARK: - Picker

/// The four blowhards in a row under the title. The pack ones carry a lock
/// until the pack is owned; tapping a locked one opens the pack sheet.
struct CastPicker: View {
    @Binding var selected: Blowhard.ID
    let owned: Bool
    var onLocked: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Blowhard.all) { who in
                let locked = who.isPack && !owned
                Button {
                    if locked {
                        onLocked()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = who.id }
                        Haptics.pop()
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(who.waterColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(selected == who.id ? UI.sun : UI.foam.opacity(0.25),
                                                lineWidth: selected == who.id ? 4 : 2)
                                )
                            Portrait(who: who, side: 62)
                                .opacity(locked ? 0.55 : 1)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            if locked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundStyle(UI.ink)
                                    .padding(6)
                                    .background(Circle().fill(UI.sun))
                                    .offset(x: 5, y: -5)
                            }
                        }
                        .frame(width: 70, height: 70)
                        Text(who.name.replacingOccurrences(of: "The ", with: "").uppercased())
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .kerning(0.8)
                            .foregroundStyle(selected == who.id ? UI.sun : UI.foam.opacity(0.85))
                    }
                    .scaleEffect(selected == who.id ? 1.06 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(locked ? "\(who.name), locked, part of the Blowhard Pack" : who.name)
            }
        }
    }
}

// MARK: - The pack sheet

struct PackSheet: View {
    @ObservedObject var store: PackStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            UI.deep.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(UI.foam)
                                .padding(11)
                                .background(Circle().fill(UI.foam.opacity(0.14)))
                        }
                        .accessibilityLabel("Close")
                    }
                    .padding(.top, 14)

                    Text("THE BLOWHARD")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .kerning(3)
                        .foregroundStyle(UI.foam)
                    Text("PACK")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .kerning(5)
                        .foregroundStyle(UI.sun)
                    Text("Three more blowhards, each stuck in his own channel, each with his own twist.")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(UI.foam.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                        .padding(.bottom, 18)

                    VStack(spacing: 12) {
                        ForEach(Blowhard.pack) { who in card(who) }
                    }

                    buyArea
                        .padding(.top, 20)

                    Text("One purchase, yours for good. The base game stays free, with no adverts.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(UI.foam.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 20)
            }
        }
        .task { await store.refresh() }
    }

    private func card(_ who: Blowhard) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(who.waterColor)
                Portrait(who: who, side: 84)
            }
            .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 4) {
                Text(who.name.uppercased())
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(UI.foam)
                Text(who.channel)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .kerning(0.6)
                    .foregroundStyle(UI.sun)
                Text(who.twistLine)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(UI.foam.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(UI.foam.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(UI.foam.opacity(0.14), lineWidth: 2))
        )
    }

    @ViewBuilder private var buyArea: some View {
        if store.owned {
            VStack(spacing: 8) {
                Text(store.isThankYou ? "YOURS, ON THE HOUSE" : "UNLOCKED")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .kerning(2)
                    .foregroundStyle(UI.sun)
                if store.isThankYou {
                    Text("You bought Clear the Strait when it cost money, so the pack is free for you. Thank you.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(UI.foam.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                Button("PLAY THEM") { dismiss() }
                    .buttonStyle(ArcadeButton())
                    .padding(.top, 6)
            }
        } else {
            VStack(spacing: 12) {
                Button {
                    Task { await store.buy() }
                } label: {
                    HStack(spacing: 10) {
                        if store.isBusy { ProgressView().tint(UI.ink) }
                        Text("UNLOCK  \(store.displayPrice)")
                    }
                }
                .buttonStyle(ArcadeButton())
                .disabled(store.isBusy)

                Button("RESTORE PURCHASES") { Task { await store.restore() } }
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .kerning(1)
                    .foregroundStyle(UI.foam.opacity(0.85))
                    .disabled(store.isBusy)
            }
        }
        if let message = store.message {
            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(UI.foam)
                .multilineTextAlignment(.center)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 14).fill(UI.foam.opacity(0.1)))
                .padding(.top, 12)
        }
    }
}
