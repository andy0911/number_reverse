import SwiftUI
import NumberOthelloCore

/// 手番・スコア・手駒枚数を表示するプレイヤー行
struct PlayerBar: View {
    let model: GameViewModel
    let player: Player
    var compact = false

    var body: some View {
        let isActive = model.actingPlayer == player
        let score = model.state.score(of: player)
        HStack {
            ChipDot(owner: player).frame(width: 18, height: 18)
            Text(player.displayName + (model.mode.isCPU(player) ? "（CPU）" : ""))
                .fontWeight(isActive ? .bold : .regular)
            if isActive {
                // 色だけに頼らず、手番であることを文字でも示す
                Text("手番")
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.chipText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(player.color, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
            if model.state.outcome == .win(player) {
                Text("勝ち")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.chipText)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(player.color, in: Capsule())
            }
            Spacer()
            Text("手駒 \(model.state.hand(of: player).total)")
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
            Text("\(score) マス")
                .font(.title3.monospacedDigit().bold())
                .contentTransition(.numericText(value: Double(score)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, compact ? 4 : 10)
        // ガラスの上に、手番の強調（プレイヤー色の枠と光）を重ねる
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isActive ? player.color : .clear, lineWidth: 3)
        )
        .shadow(color: isActive ? player.color.opacity(0.5) : .clear, radius: 10)
        .animation(.snappy(duration: 0.3), value: isActive)
        .animation(.snappy(duration: 0.3), value: score)
    }
}
