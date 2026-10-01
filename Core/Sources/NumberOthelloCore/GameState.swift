public enum Phase: Hashable, Sendable {
    /// 初期配置（spec §4.1）。step は 0...5
    case setup(step: Int)
    case playing
    /// 裏返された爆弾の持ち主が方向を選ぶまで進行を止める割り込み状態
    case awaitingBombDirection(owner: Player, at: Position)
    case finished
}

public struct Move: Hashable, Sendable {
    public let kind: PieceKind
    public let position: Position

    public init(_ kind: PieceKind, at position: Position) {
        self.kind = kind
        self.position = position
    }
}

public enum MoveError: Error, Equatable, Sendable {
    case wrongPhase
    case noPieceInHand
    case occupied
    case outOfBoard
    /// 初期配置で指定ゾーン・自陣以外に置こうとした
    case invalidSetupCell
    /// 初期配置で T/B を置こうとした
    case numberRequiredInSetup
    /// 灰マスは 1 枚以上裏返る時のみ置ける
    case grayRequiresCapture
}

public enum GameEvent: Hashable, Sendable {
    case placed(Position, Piece)
    case flipped([Position])
    case exploded(Position, owner: Player, BombDirection)
    case passed(Player)
    case finished
}

public enum Outcome: Hashable, Sendable {
    case win(Player)
    case draw
}

private struct PendingBomb: Hashable, Sendable {
    let owner: Player
    let position: Position
}

public struct GameState: Hashable, Sendable {
    public private(set) var board: Board
    public private(set) var hands: [Player: Hand]
    public private(set) var current: Player
    public private(set) var phase: Phase
    /// 直近の place / chooseBombDirection で起きた出来事（UI 表示用）
    public private(set) var events: [GameEvent] = []
    private var bombQueue: [PendingBomb] = []

    public init() {
        board = Board()
        hands = [.first: .initial(for: .first), .second: .initial(for: .second)]
        current = .first
        phase = .setup(step: 0)
    }

    /// テスト・検証用: 任意の盤面から本戦を開始する
    public init(board: Board, current: Player, hands: [Player: Hand]? = nil) {
        self.board = board
        self.hands = hands ?? [.first: .initial(for: .first), .second: .initial(for: .second)]
        self.current = current
        self.phase = .playing
    }

    public func hand(of player: Player) -> Hand { hands[player]! }

    public func score(of player: Player) -> Int { board.count(of: player) }

    public var outcome: Outcome? {
        guard phase == .finished else { return nil }
        let a = score(of: .first), b = score(of: .second)
        if a == b { return .draw }
        return .win(a > b ? .first : .second)
    }

    // MARK: - 合法手

    /// 初期配置で置けるセル
    public static func setupCells(step: Int) -> [Position] {
        let player: Player = step.isMultiple(of: 2) ? .first : .second
        let zone: Zone = step < 2 ? .red : .blue
        return Board.allPositions.filter { Board.zone(of: $0) == zone && Board.side(of: $0) == player }
    }

    public func validate(_ move: Move) -> MoveError? {
        let p = move.position
        guard p.isOnBoard else { return .outOfBoard }
        guard board[p] == .empty else { return .occupied }
        guard hand(of: current).count(of: move.kind) > 0 else { return .noPieceInHand }

        switch phase {
        case .setup(let step):
            guard move.kind.isNumber else { return .numberRequiredInSetup }
            guard GameState.setupCells(step: step).contains(p) else { return .invalidSetupCell }
            return nil
        case .playing:
            if Board.zone(of: p) == .gray {
                var trial = board
                trial[p] = .piece(Piece(current, move.kind))
                if trial.captures(from: p).isEmpty { return .grayRequiresCapture }
            }
            return nil
        case .awaitingBombDirection, .finished:
            return .wrongPhase
        }
    }

    public func legalMoves() -> [Move] {
        switch phase {
        case .setup(let step):
            let kinds = hand(of: current).availableKinds.filter(\.isNumber)
            return GameState.setupCells(step: step)
                .filter { board[$0] == .empty }
                .flatMap { p in kinds.map { Move($0, at: p) } }
        case .playing:
            return legalMoves(for: current, stopAtFirst: false)
        case .awaitingBombDirection, .finished:
            return []
        }
    }

    private func legalMoves(for player: Player, stopAtFirst: Bool) -> [Move] {
        let kinds = hand(of: player).availableKinds
        guard !kinds.isEmpty else { return [] }
        var moves: [Move] = []
        for p in board.emptyPositions {
            let isGray = Board.zone(of: p) == .gray
            for kind in kinds {
                if isGray {
                    // B も通常駒と同じ挟み判定を受けるため、灰マスの可否も合計次第（R-4 改訂）。
                    // 特別扱いで除外すると、B でしか挟めない局面で合法手が 0 になり誤ってパス・終了してしまう
                    var trial = board
                    trial[p] = .piece(Piece(player, kind))
                    if trial.captures(from: p).isEmpty { continue }
                }
                moves.append(Move(kind, at: p))
                if stopAtFirst { return moves }
            }
        }
        return moves
    }

    private func hasLegalMove(for player: Player) -> Bool {
        !legalMoves(for: player, stopAtFirst: true).isEmpty
    }

    // MARK: - 進行

    public mutating func place(_ kind: PieceKind, at p: Position) throws(MoveError) {
        if let error = validate(Move(kind, at: p)) { throw error }
        events = []
        let piece = Piece(current, kind)
        board[p] = .piece(piece)
        hands[current]!.remove(kind)
        events.append(.placed(p, piece))

        if case .setup(let step) = phase {
            let next = step + 1
            phase = next < 6 ? .setup(step: next) : .playing
            current = next < 6 ? current.opponent : .first
            return
        }

        let captured = board.captures(from: p).sorted()
        flip(captured)
        advance()
    }

    /// 割り込み状態で、爆弾の持ち主が方向を選ぶ（spec §5.4）
    public mutating func chooseBombDirection(_ direction: BombDirection) throws(MoveError) {
        guard case .awaitingBombDirection = phase, !bombQueue.isEmpty else { throw .wrongPhase }
        let bomb = bombQueue.removeFirst()
        events.append(.exploded(bomb.position, owner: bomb.owner, direction))

        // 各方向、隣接 1 マスの相手駒だけが対象（空セル・×・自駒なら不発、合計最大 4 枚）
        var targets: [Position] = []
        for d in direction.directions {
            let q = bomb.position.moved(d)
            guard q.isOnBoard, board[q].piece?.owner == bomb.owner.opponent else { continue }
            targets.append(q)
        }
        flip(targets.sorted())
        advance()
    }

    private mutating func flip(_ positions: [Position]) {
        guard !positions.isEmpty else { return }
        for q in positions {
            guard let piece = board[q].piece else { continue }
            switch piece.kind {
            case .number(let n):
                board[q] = .piece(Piece(piece.owner.opponent, .number(10 - n)))
            case .tank:
                board[q] = .wasteland
            case .bomb:
                board[q] = .wasteland
                bombQueue.append(PendingBomb(owner: piece.owner, position: q))
            }
        }
        events.append(.flipped(positions))
    }

    /// 爆発待ちがあれば割り込み、なければ手番を進める（自動パス・終了判定込み）
    private mutating func advance() {
        if let bomb = bombQueue.first {
            phase = .awaitingBombDirection(owner: bomb.owner, at: bomb.position)
            return
        }
        phase = .playing
        let next = current.opponent
        if hasLegalMove(for: next) {
            current = next
        } else if hasLegalMove(for: current) {
            events.append(.passed(next))
        } else {
            phase = .finished
            events.append(.finished)
        }
    }
}
