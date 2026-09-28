/// 8×8 の盤面。row 0 が上（後攻側）、row 7 が下（先行側）
public struct Board: Hashable, Sendable {
    public static let size = 8

    private var cells: [Cell]

    public init() {
        cells = Array(repeating: .empty, count: Board.size * Board.size)
    }

    public subscript(_ p: Position) -> Cell {
        get { cells[p.row * Board.size + p.col] }
        set { cells[p.row * Board.size + p.col] = newValue }
    }

    public static let allPositions: [Position] =
        (0..<size).flatMap { r in (0..<size).map { c in Position(r, c) } }

    public static func zone(of p: Position) -> Zone {
        if p.row == 0 || p.row == size - 1 || p.col == 0 || p.col == size - 1 { return .gray }
        if (3...4).contains(p.row) && (3...4).contains(p.col) { return .red }
        return .blue
    }

    /// 点線（row 3 と row 4 の間）で分けた陣。row 4–7 が先行、row 0–3 が後攻
    public static func side(of p: Position) -> Player {
        p.row >= size / 2 ? .first : .second
    }

    public func count(of player: Player) -> Int {
        cells.reduce(0) { $0 + ($1.piece?.owner == player ? 1 : 0) }
    }

    public var emptyPositions: [Position] {
        Board.allPositions.filter { self[$0] == .empty }
    }

    public var isFull: Bool { !cells.contains(.empty) }

    /// 位置 p に置かれた駒を起点に、裏返る相手駒を返す（spec §5.1, §5.2）。
    /// 盤面は変更しない（全方向を同じ盤面で評価する）。
    public func captures(from p: Position) -> Set<Position> {
        guard let placed = self[p].piece else { return [] }
        if placed.kind == .bomb { return [] }
        let me = placed.owner
        var result: Set<Position> = []

        for d in Direction.all {
            let enemy = run(from: p.moved(d), direction: d, owner: me.opponent)
            guard let last = enemy.last else { continue }
            let far = run(from: last.moved(d), direction: d, owner: me)
            guard !far.isEmpty else { continue }

            if placed.kind == .tank {
                result.formUnion(enemy)
                continue
            }
            let behind = run(from: p, direction: d.reversed, owner: me)
            let ownSum = sum(behind) + sum(far)
            if ownSum > sum(enemy) {
                result.formUnion(enemy)
            }
        }
        return result
    }

    /// start から direction 方向へ連続する owner の駒の位置。空・×・盤外・色替わりで止まる。
    /// コーチモードの検証（Tutorial.swift）も同じ関数で軍の合計を数える
    func run(from start: Position, direction: Direction, owner: Player) -> [Position] {
        var positions: [Position] = []
        var q = start
        while q.isOnBoard, let piece = self[q].piece, piece.owner == owner {
            positions.append(q)
            q = q.moved(direction)
        }
        return positions
    }

    func sum(_ positions: [Position]) -> Int {
        positions.reduce(0) { $0 + (self[$1].piece?.kind.value ?? 0) }
    }
}
