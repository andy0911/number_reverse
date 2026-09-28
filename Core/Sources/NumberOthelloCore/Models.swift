/// 先行（盤面下側）/ 後攻（盤面上側）
public enum Player: Int, Sendable, Hashable, CaseIterable {
    case first
    case second

    public var opponent: Player { self == .first ? .second : .first }
}

public struct Position: Hashable, Sendable, Comparable, CustomStringConvertible {
    public let row: Int
    public let col: Int

    public init(_ row: Int, _ col: Int) {
        self.row = row
        self.col = col
    }

    public var isOnBoard: Bool { (0..<Board.size).contains(row) && (0..<Board.size).contains(col) }

    public func moved(_ d: Direction) -> Position { Position(row + d.dr, col + d.dc) }

    public static func < (lhs: Position, rhs: Position) -> Bool {
        (lhs.row, lhs.col) < (rhs.row, rhs.col)
    }

    public var description: String { "(\(row),\(col))" }
}

public struct Direction: Hashable, Sendable {
    public let dr: Int
    public let dc: Int

    public var reversed: Direction { Direction(dr: -dr, dc: -dc) }

    public static let orthogonal: [Direction] = [
        Direction(dr: -1, dc: 0), Direction(dr: 1, dc: 0),
        Direction(dr: 0, dc: -1), Direction(dr: 0, dc: 1),
    ]
    public static let diagonal: [Direction] = [
        Direction(dr: -1, dc: -1), Direction(dr: -1, dc: 1),
        Direction(dr: 1, dc: -1), Direction(dr: 1, dc: 1),
    ]
    public static let all: [Direction] = orthogonal + diagonal
}

/// 盤面のゾーン（spec §2）
public enum Zone: Sendable, Hashable {
    case gray
    case blue
    case red
}

/// 駒の種類（表面）
public enum PieceKind: Hashable, Sendable, Comparable, CustomStringConvertible {
    case number(Int)
    case tank
    case bomb

    /// 軍の合計に使う値。T・B は 0（spec §5.1）
    public var value: Int {
        if case .number(let n) = self { return n }
        return 0
    }

    public var isNumber: Bool {
        if case .number = self { return true }
        return false
    }

    public static let allKinds: [PieceKind] = (1...9).map { .number($0) } + [.tank, .bomb]

    public var description: String {
        switch self {
        case .number(let n): "\(n)"
        case .tank: "T"
        case .bomb: "B"
        }
    }

    private var sortKey: Int {
        switch self {
        case .number(let n): n
        case .tank: 10
        case .bomb: 11
        }
    }

    public static func < (lhs: PieceKind, rhs: PieceKind) -> Bool { lhs.sortKey < rhs.sortKey }
}

public struct Piece: Hashable, Sendable {
    public var owner: Player
    public var kind: PieceKind

    public init(_ owner: Player, _ kind: PieceKind) {
        self.owner = owner
        self.kind = kind
    }
}

public enum Cell: Hashable, Sendable {
    case empty
    case piece(Piece)
    /// ×（荒地）。どちらの陣地でもなく、軍を分断する
    case wasteland

    public var piece: Piece? {
        if case .piece(let p) = self { return p }
        return nil
    }
}

/// 爆弾の爆発方向（spec §5.4）
public enum BombDirection: Sendable, Hashable, CaseIterable {
    /// 上下左右
    case cross
    /// 斜め 4 方向
    case diagonal

    public var directions: [Direction] {
        switch self {
        case .cross: Direction.orthogonal
        case .diagonal: Direction.diagonal
        }
    }
}

/// 手駒（spec §3.3）
public struct Hand: Hashable, Sendable {
    public private(set) var counts: [PieceKind: Int]

    public init(counts: [PieceKind: Int]) {
        self.counts = counts
    }

    public static func initial(for player: Player) -> Hand {
        let numberCounts = [1: 3, 2: 3, 3: 3, 4: 4, 5: 4, 6: 4, 7: 3, 8: 3, 9: 3]
        var counts: [PieceKind: Int] = [:]
        for (n, c) in numberCounts { counts[.number(n)] = c }
        counts[.tank] = 1
        counts[.bomb] = player == .first ? 1 : 2
        return Hand(counts: counts)
    }

    public func count(of kind: PieceKind) -> Int { counts[kind, default: 0] }

    public var total: Int { counts.values.reduce(0, +) }

    public var availableKinds: [PieceKind] {
        PieceKind.allKinds.filter { count(of: $0) > 0 }
    }

    mutating func remove(_ kind: PieceKind) {
        counts[kind, default: 0] -= 1
    }
}
