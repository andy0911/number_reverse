import SwiftUI
import NumberOthelloCore

/// 8×8 盤面。点線（陣の境界）はオーバーレイで描画する
struct BoardView: View {
    let model: GameViewModel

    private static let boardShape = RoundedRectangle(cornerRadius: 6, style: .continuous)

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
        // 盤の角を丸める（セルの中身・タップ領域は変えない）
        .clipShape(Self.boardShape)
        // 接地影は、盤の外形の角丸矩形 1 枚（背後）から作り、盤の内側は抜いて外側だけに描く。
        // 内側まで影を通すと、半透明の枠色 `boardFrame`（マス目の隙間・外枠）が影の分だけ濃くなり、
        // 見た目が変わってしまう（灰マス間の隙間の実測: 影を通すと RGB 68 前後、外側だけにすると 90 前後）。
        // 盤の中身（セル・駒・×・点線）には `.shadow` を掛けない
        .background {
            Self.boardShape.fill(.black)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
                .mask {
                    Rectangle().padding(-32)
                        .overlay { Self.boardShape.blendMode(.destinationOut) }
                        .compositingGroup()
                }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
