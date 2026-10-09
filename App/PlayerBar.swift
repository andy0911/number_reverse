import SwiftUI
import NumberOthelloCore

/// 手番・スコア・手駒枚数を表示するプレイヤー行
struct PlayerBar: View {
    let model: GameViewModel
    let player: Player
    var compact = false

    var body: some View {
        let isActive = model.actingPlayer == player
        HStack {
            ChipDot(owner: player).frame(width: 18, height: 18)
            Text(player.displayName + (model.mode.isCPU(player) ? "（CPU）" : ""))
                .fontWeight(isActive ? .bold : .regular)
            Spacer()
            Text("手駒 \(model.state.hand(of: player).total)")
                .foregroundStyle(.secondary)
            Text("\(model.state.score(of: player)) マス")
                .font(.title3.monospacedDigit().bold())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, compact ? 4 : 10)
        // ガラスの上に、手番の強調（プレイヤー色の枠）を重ねる
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isActive ? player.color : .clear, lineWidth: 3)
        )
    }
}
