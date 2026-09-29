import SwiftUI
import NumberOthelloCore

/// 盤の外形（角丸）。`BoardFrame` の角丸クリップ・接地影と、コーチモードのスポットライトの切り抜きで共有する
enum BoardOutline {
    static let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
}

/// 盤面の入れ物: 8×8 のグリッド・外枠・点線（陣の境界）・角丸クリップ・接地影。
/// マスの中身は呼び出し側が `cell` で渡す。対局用の `BoardView` とコーチモードの `CoachBoardView` が共有する
/// （盤の見た目を 1 か所に保ち、どちらか一方だけが古くならないようにするため）。
struct BoardFrame<CellContent: View>: View {
    let cell: (Position) -> CellContent

    init(@ViewBuilder cell: @escaping (Position) -> CellContent) {
        self.cell = cell
    }

    var body: some View {
        Grid(horizontalSpacing: 1, verticalSpacing: 1) {
            ForEach(0..<Board.size, id: \.self) { r in
                GridRow {
                    ForEach(0..<Board.size, id: \.self) { c in
                        cell(Position(r, c))
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
        .clipShape(BoardOutline.shape)
        // 接地影は、盤の外形の角丸矩形 1 枚（背後）から作り、盤の内側は抜いて外側だけに描く。
        // 内側まで影を通すと、半透明の枠色 `boardFrame`（マス目の隙間・外枠）が影の分だけ濃くなり、
        // 見た目が変わってしまう（灰マス間の隙間の実測: 影を通すと RGB 68 前後、外側だけにすると 90 前後）。
        // 盤の中身（セル・駒・×・点線）には `.shadow` を掛けない
        .background {
            BoardOutline.shape.fill(.black)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
                .mask {
                    Rectangle().padding(-32)
                        .overlay { BoardOutline.shape.blendMode(.destinationOut) }
                        .compositingGroup()
                }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
