import SwiftUI
import NumberOthelloCore

/// 手番・スコア・手駒枚数を表示するプレイヤー行
struct PlayerBar: View {
    let model: GameViewModel
    let player: Player

    var body: some View {
        let isActive = model.actingPlayer == player
        HStack {
            Circle().fill(player.color).frame(width: 16, height: 16)
            Text(player.displayName + (model.mode.isCPU(player) ? "（CPU）" : ""))
                .fontWeight(isActive ? .bold : .regular)
            Spacer()
            Text("手駒 \(model.state.hand(of: player).total)")
                .foregroundStyle(.secondary)
            Text("\(model.state.score(of: player)) マス")
                .font(.title3.monospacedDigit().bold())
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isActive ? player.color : .clear, lineWidth: 3)
        )
    }
}
