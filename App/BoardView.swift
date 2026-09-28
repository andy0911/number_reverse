import SwiftUI
import NumberOthelloCore

/// 8×8 盤面。点線（陣の境界）はオーバーレイで描画する
struct BoardView: View {
    let model: GameViewModel

    var body: some View {
        let highlighted = model.highlightedCells
        Grid(horizontalSpacing: 1, verticalSpacing: 1) {
            ForEach(0..<Board.size, id: \.self) { r in
                GridRow {
                    ForEach(0..<Board.size, id: \.self) { c in
                        let p = Position(r, c)
                        CellView(
                            cell: model.state.board[p],
                            zone: Board.zone(of: p),
                            isHighlighted: highlighted.contains(p),
                            isFlipped: model.lastFlipped.contains(p),
                            isLastPlaced: model.lastPlaced == p
                        )
                        .onTapGesture { model.tap(p) }
                    }
                }
            }
        }
        .padding(2)
        .background(Theme.boardFrame)
        .overlay {
            // 点線（先行・後攻の陣の境界）
            GeometryReader { geo in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
                .stroke(Theme.boardDivider, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            }
            .allowsHitTesting(false)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
