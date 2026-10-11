import SwiftUI
import NumberOthelloCore

/// 対局終了のダイアログ。勝者の駒を大きく見せ、両者のスコアを並べる
struct ResultCard<Actions: View>: View {
    let outcome: Outcome?
    let firstScore: Int
    let secondScore: Int
    @ViewBuilder let actions: Actions

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var winner: Player? {
        if case .win(let p) = outcome { p } else { nil }
    }

    private var title: String {
        switch outcome {
        case .win(let p): "\(p.displayName)の勝ち！"
        case .draw: "引き分け"
        case nil: ""
        }
    }

    var body: some View {
        ZStack {
            Theme.dialogScrim.ignoresSafeArea()
            VStack(spacing: 18) {
                emblem
                Text(title)
                    .font(.system(.title, design: .rounded, weight: .heavy))
                HStack(spacing: 12) {
                    scoreColumn(.first, score: firstScore)
                    scoreColumn(.second, score: secondScore)
                }
                GlassEffectContainer {
                    HStack(spacing: 12) { actions }
                }
                .controlSize(.large)
            }
            .padding(24)
            // 背後の盤面（駒の模様）が透けて読みにくくならないよう、ガラスの下に地色を敷く
            .background(Color(uiColor: .systemBackground).opacity(0.6), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(32)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.88)
            .opacity(appeared || reduceMotion ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { appeared = true } }
        .sensoryFeedback(.success, trigger: appeared) { _, new in new && winner != nil }
        .accessibilityElement(children: .contain)
    }

    /// 勝者の駒に王冠。引き分けは両者の駒を並べる
    @ViewBuilder private var emblem: some View {
        if let winner {
            VStack(spacing: -6) {
                Image(systemName: "crown.fill")
                    .font(.title)
                    .foregroundStyle(Theme.playerFirst)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                ChipDot(owner: winner).frame(width: 64, height: 64)
            }
            .accessibilityHidden(true)
        } else {
            HStack(spacing: -12) {
                ChipDot(owner: .first).frame(width: 52, height: 52)
                ChipDot(owner: .second).frame(width: 52, height: 52)
            }
            .accessibilityHidden(true)
        }
    }

    private func scoreColumn(_ player: Player, score: Int) -> some View {
        let isWinner = winner == player
        return VStack(spacing: 2) {
            HStack(spacing: 6) {
                ChipDot(owner: player).frame(width: 14, height: 14)
                Text(player.displayName).font(.subheadline.weight(.semibold))
            }
            Text("\(score)")
                .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(isWinner ? Color.primary : Color.secondary)
            Text("マス").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isWinner ? player.color.opacity(0.22) : Color.secondary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isWinner ? player.color : .clear, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(player.displayName) \(score)マス")
    }
}
