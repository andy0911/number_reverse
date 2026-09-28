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
                Circle().fill(Color.accentColor.opacity(0.35)).padding(12)
            }
            switch cell {
            case .empty:
                EmptyView()
            case .wasteland:
                Image(systemName: "xmark")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
            case .piece(let piece):
                Circle()
                    .fill(piece.owner.color)
                    .overlay(Circle().strokeBorder(isFlipped ? Theme.flippedRing : (isLastPlaced ? Theme.lastPlacedRing : .clear), lineWidth: 3))
                    .overlay(
                        Text(piece.kind.description)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.chipText)
                    )
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
