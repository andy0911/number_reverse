import SwiftUI
import NumberOthelloCore

/// 爆弾が爆発したときの方向選択。盤面全体を覆うダイアログではなく HandPicker の位置に
/// インライン表示することで、盤面（どの駒が爆発したか・周囲の駒）を見ながら選べるようにする
struct BombDirectionPicker: View {
    let model: GameViewModel
    let owner: Player

    var body: some View {
        VStack(spacing: 6) {
            Text("各方向の隣接1マスにある相手の駒だけを裏返します（空きマス・×・自分の駒なら不発・最大4枚）")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button("上下左右 ✚") { model.chooseBombDirection(.cross) }
                    .buttonStyle(.glassProminent)
                Button("斜め ✕") { model.chooseBombDirection(.diagonal) }
                    .buttonStyle(.glassProminent)
            }
            .disabled(!model.isHumanTurn)
            .opacity(model.isHumanTurn ? 1 : 0.5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
