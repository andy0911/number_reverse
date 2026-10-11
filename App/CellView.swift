import SwiftUI
import NumberOthelloCore

/// 盤上の 1 マス。空・荒地(×)・駒のいずれかを描画する
struct CellView: View {
    let cell: Cell
    let zone: Zone
    let isHighlighted: Bool
    let isFlipped: Bool
    let isLastPlaced: Bool

    var body: some View {
        ZStack {
            Rectangle().fill(background)
            if isHighlighted {
                HintMarker()
            }
            switch cell {
            case .empty:
                EmptyView()
            case .wasteland:
                Image(systemName: "xmark")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
            case .piece(let piece):
                ChipView(piece: piece, isFlipped: isFlipped, isLastPlaced: isLastPlaced)
                    .padding(3)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
    }

    private var background: Color {
        switch zone {
        case .gray: Theme.zoneGray
        case .blue: Theme.zoneBlue
        case .red: Theme.zoneRed
        }
    }
}

/// 置ける場所の目印。ゆっくり脈打つリング（動きを減らす設定では静止）。
/// 色は盤の点線と同じ動的カラー（ライト=黒 / ダーク=白）で、3 ゾーンのどの上でも見える
private struct HintMarker: View {
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(Theme.boardDivider.opacity(0.14))
            .overlay(Circle().strokeBorder(Theme.boardDivider.opacity(0.6), lineWidth: 2))
            .padding(10)
            .scaleEffect(pulse ? 1.08 : 0.92)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
            }
    }
}
