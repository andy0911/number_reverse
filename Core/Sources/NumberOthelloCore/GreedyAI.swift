/// 1 手先読みの貪欲 CPU（spec §9）
public struct GreedyAI: Sendable {
    public init() {}

    /// 手番プレイヤーの手を選ぶ。合法手が無ければ nil
    public func chooseMove<R: RandomNumberGenerator>(in state: GameState, using rng: inout R) -> Move? {
        let moves = state.legalMoves()
        guard !moves.isEmpty else { return nil }

        if case .setup = state.phase {
            let kind = setupKind(in: state.hand(of: state.current))
            let cells = Set(moves.map(\.position))
            return Move(kind, at: cells.randomElement(using: &rng)!)
        }

        let me = state.current
        var candidates = moves
        // B は灰マスに置けないため、赤・青の空きが B の残数以下になったら B を優先して使い切る
        let bombs = state.hand(of: me).count(of: .bomb)
        let openCells = state.board.emptyPositions.filter { Board.zone(of: $0) != .gray }.count
        if openCells > 0, openCells <= bombs {
            candidates = moves.filter { $0.kind == .bomb }
        }

        var best: [Move] = []
        var bestScore = Int.min
        for move in candidates {
            var sim = state
            try? sim.place(move.kind, at: move.position)
            GreedyAI.resolveBombsGreedily(&sim)
            let score = GreedyAI.evaluate(sim, for: me) * 100 - cost(of: move.kind)
            if score > bestScore {
                bestScore = score
                best = [move]
            } else if score == bestScore {
                best.append(move)
            }
        }
        return best.randomElement(using: &rng)
    }

    public func chooseMove(in state: GameState) -> Move? {
        var rng = SystemRandomNumberGenerator()
        return chooseMove(in: state, using: &rng)
    }

    /// 割り込み状態で、爆弾の持ち主にとって最良の方向を選ぶ
    public func chooseBombDirection(in state: GameState) -> BombDirection {
        guard case .awaitingBombDirection(let owner, _) = state.phase else { return .cross }
        return GreedyAI.bestDirection(in: state, for: owner)
    }

    // MARK: - 評価

    static func evaluate(_ state: GameState, for player: Player) -> Int {
        state.score(of: player) - state.score(of: player.opponent)
    }

    /// 先読み中に発生した爆発を、各持ち主にとって貪欲な方向で解決する（連鎖は最大 3 回）
    static func resolveBombsGreedily(_ state: inout GameState) {
        while case .awaitingBombDirection(let owner, _) = state.phase {
            let direction = bestDirection(in: state, for: owner)
            try? state.chooseBombDirection(direction)
        }
    }

    static func bestDirection(in state: GameState, for owner: Player) -> BombDirection {
        var best = BombDirection.cross
        var bestScore = Int.min
        for direction in BombDirection.allCases {
            var sim = state
            try? sim.chooseBombDirection(direction)
            resolveBombsGreedily(&sim)
            let score = evaluate(sim, for: owner)
            if score > bestScore {
                bestScore = score
                best = direction
            }
        }
        return best
    }

    /// 同じ評価なら安い駒を使い、T・B・極端な数字を温存する
    private func cost(of kind: PieceKind) -> Int {
        switch kind {
        case .tank: 60
        case .bomb: 20
        case .number(let n): abs(n - 5) * 3
        }
    }

    /// 初期配置は中位の数字を優先
    private func setupKind(in hand: Hand) -> PieceKind {
        let preference = [5, 6, 4, 7, 3, 8, 2, 9, 1]
        for n in preference where hand.count(of: .number(n)) > 0 {
            return .number(n)
        }
        return hand.availableKinds.first(where: \.isNumber)!
    }
}
