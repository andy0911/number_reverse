import SwiftUI
import NumberOthelloCore

/// 対局用の 8×8 盤面。グリッド・枠・点線・影は共通の `BoardFrame` が描き、ここではマスの中身とタップだけを渡す
struct BoardView: View {
    let model: GameViewModel

    var body: some View {
        let highlighted = model.highlightedCells
        BoardFrame { p in
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
