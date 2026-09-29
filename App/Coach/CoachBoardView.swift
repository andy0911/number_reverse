import SwiftUI
import NumberOthelloCore

/// コーチモード用の盤面。盤の入れ物は本編と共通の `BoardFrame`、マスの描画も本編と同じ `CellView` を使い、
/// その上にコーチマーク（スポットライトとリング）を重ねる。マスの位置は描画結果（preference）から取得する。
struct CoachBoardView: View {
    let state: GameState
    let focus: TutorialFocus
    let focusCells: Set<Position>
    let flipped: Set<Position>
    let placed: Set<Position>
    /// 実演が拒否された（置けなかった）とき、置こうとしたマス。そのマスだけリングを赤にする
    /// （本編では赤は「直前に裏返った」を意味するため、他のマスには使わない）
    let rejectedCell: Position?
    /// 吹き出しの矢印が指す x 座標（盤面左端が 0）。指す対象が無いとき nil
    @Binding var anchorX: CGFloat?

    @State private var frames: [Position: CGRect] = [:]
    @State private var pulse = false

    private static let space = "coachBoard"

    var body: some View {
        // グリッド・枠・点線・角丸・影は本編と共通の BoardFrame。ここではマスの中身とコーチマークだけを担当する
        BoardFrame { p in cell(p) }
            .coordinateSpace(name: Self.space)
            .onPreferenceChange(CellFramesKey.self) { frames = $0 }
            .overlay { spotlight }
            .overlay { rings }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
                anchorX = anchor
            }
            .onChange(of: anchor) { _, new in anchorX = new }
    }

    private func cell(_ p: Position) -> some View {
        CellView(
            cell: state.board[p],
            zone: Board.zone(of: p),
            isHighlighted: false,
            isFlipped: flipped.contains(p),
            isLastPlaced: placed.contains(p)
        )
        // 実演で裏返るマスだけ、切り替わりの瞬間に 1 回転させる（perform() の withAnimation で駆動）
        .rotation3DEffect(.degrees(flipped.contains(p) ? 360 : 0), axis: (x: 0, y: 1, z: 0))
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: CellFramesKey.self, value: [p: geo.frame(in: .named(Self.space))])
            }
        )
    }

    // MARK: - コーチマーク

    /// 指し示す領域（マス、または点線の帯）
    private var focusRects: [CGRect] {
        var rects = focusCells.compactMap { frames[$0] }
        if focus == .divider, let y = dividerY, let top = frames[Position(0, 0)], let right = frames[Position(0, Board.size - 1)] {
            rects.append(CGRect(x: top.minX, y: y - 9, width: right.maxX - top.minX, height: 18))
        }
        return rects
    }

    /// 点線の y 座標（row 3 と row 4 の間）
    private var dividerY: CGFloat? {
        guard let upper = frames[Position(3, 0)], let lower = frames[Position(4, 0)] else { return nil }
        return (upper.maxY + lower.minY) / 2
    }

    private var anchor: CGFloat? {
        let rects = focusRects
        guard let first = rects.first else { return nil }
        let union = rects.dropFirst().reduce(first) { $0.union($1) }
        return union.midX
    }

    /// 指し示す領域以外を暗くする。領域は透明に抜く
    private var spotlight: some View {
        Canvas { context, size in
            let rects = focusRects
            guard !rects.isEmpty else { return }
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.55)))
            context.blendMode = .clear
            for rect in rects {
                context.fill(Path(roundedRect: rect.insetBy(dx: -1, dy: -1), cornerRadius: 4), with: .color(.black))
            }
        }
        // 盤の角丸に合わせて切る（暗幕が角からはみ出さないように）
        .clipShape(BoardOutline.shape)
        .allowsHitTesting(false)
    }

    /// 指し示すマスの縁取り。ゾーン全体（多数のマス）を指すときは付けず、スポットライトだけにする
    @ViewBuilder private var rings: some View {
        ZStack {
            if case .zones = focus {
                EmptyView()
            } else {
                ForEach(Array(focusCells), id: \.self) { p in
                    if let rect = frames[p] {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(.black, lineWidth: 5)
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(p == rejectedCell ? .red : .white, lineWidth: 3))
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    }
                }
            }
            if focus == .divider, let y = dividerY, let left = frames[Position(0, 0)], let right = frames[Position(0, Board.size - 1)] {
                Path { path in
                    path.move(to: CGPoint(x: left.minX, y: y))
                    path.addLine(to: CGPoint(x: right.maxX, y: y))
                }
                .stroke(.black, style: StrokeStyle(lineWidth: 6, dash: [8, 5]))
                Path { path in
                    path.move(to: CGPoint(x: left.minX, y: y))
                    path.addLine(to: CGPoint(x: right.maxX, y: y))
                }
                .stroke(.white, style: StrokeStyle(lineWidth: 3, dash: [8, 5]))
            }
        }
        .opacity(pulse ? 1 : 0.55)
        .allowsHitTesting(false)
    }
}

private struct CellFramesKey: PreferenceKey {
    static let defaultValue: [Position: CGRect] = [:]
    static func reduce(value: inout [Position: CGRect], nextValue: () -> [Position: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
