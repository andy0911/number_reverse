import Foundation

/// 読み合い対応型 CPU（難易度別）
/// searchDepth 1 は 1 手評価、2 以上は α-β 付きミニマックス（反復深化・ビーム幅つき）で読む
public class ReadingAI {
    public let profile: CPUProfile

    /// 直近の chooseMove の探索統計（検証用）
    public struct SearchStats: Sendable {
        public var depthReached = 0
        public var nodes = 0
        public var endgameSolved = false
    }
    public private(set) var lastStats = SearchStats()

    /// 終局の勝敗を駒数差より優先するためのボーナス
    private static let winBonus = 100_000

    public init(profile: CPUProfile = .normal) {
        self.profile = profile
    }

    /// 手番プレイヤーの手を選ぶ。合法手が無ければ nil
    /// - Returns: (move, updatedModel) の タプル
    public func chooseMove<R: RandomNumberGenerator>(
        in state: GameState,
        opponentModel: OpponentModel,
        using rng: inout R
    ) -> (move: Move?, updatedModel: OpponentModel) {
        lastStats = SearchStats()
        let moves = state.legalMoves()
        guard !moves.isEmpty else { return (nil, opponentModel) }

        // 初期配置ではランダムに中位の数字を優先
        if case .setup = state.phase {
            let move = chooseSetupMove(from: moves, in: state, using: &rng)
            return (move, opponentModel)
        }

        // B は灰マスに置けないため、赤・青の空きが B の残数以下になったら B を優先して使い切る
        let me = state.current
        var candidates = moves
        let bombs = state.hand(of: me).count(of: .bomb)
        let openCells = state.board.emptyPositions.filter { Board.zone(of: $0) != .gray }.count
        if openCells > 0, openCells <= bombs {
            candidates = moves.filter { $0.kind == .bomb }
        }

        // 終盤は全読み（灰マスは取れる時しか置けないので、赤・青の空きだけを数える）
        if profile.endgameSolveCells > 0,
           openCells <= profile.endgameSolveCells,
           let best = solveEndgame(state: state, candidates: candidates, for: me) {
            lastStats.endgameSolved = true
            return (best, opponentModel)
        }

        let moveScores: [(move: Move, score: Int)]
        if profile.searchDepth <= 1 {
            moveScores = candidates.map { move in
                var sim = state
                try? sim.place(move.kind, at: move.position)
                GreedyAI.resolveBombsGreedily(&sim)
                return (move, staticEval(sim, for: me) - cost(of: move.kind))
            }
        } else {
            moveScores = deepScores(state: state, candidates: candidates, for: me)
        }

        // ゆらぎを適用して手を選ぶ
        let selectedMove = selectMoveByTemperature(
            candidates: moveScores,
            temperature: profile.selectionTemperature,
            using: &rng
        )

        // 相手モデルを更新（今は手数をカウントするだけ）
        let updatedModel = opponentModel.updated(
            observedMove: selectedMove,
            evaluationsByStrategy: moveScores.map(\.score)
        )

        return (selectedMove, updatedModel)
    }

    /// 割り込み状態で、爆弾の持ち主にとって最良の方向を選ぶ
    public func chooseBombDirection<R: RandomNumberGenerator>(
        in state: GameState,
        using rng: inout R
    ) -> BombDirection {
        guard case .awaitingBombDirection(let owner, _) = state.phase else { return .cross }

        // エラー率に応じて、最良でなく次善の方向を選ぶ
        if Double.random(in: 0..<1, using: &rng) < profile.bombDirectionErrorRate {
            // 次善の方向を選ぶ
            var scores: [(direction: BombDirection, score: Int)] = []
            for direction in BombDirection.allCases {
                var sim = state
                try? sim.chooseBombDirection(direction)
                GreedyAI.resolveBombsGreedily(&sim)
                let score = GreedyAI.evaluate(sim, for: owner)
                scores.append((direction, score))
            }
            scores.sort { $0.score > $1.score } // 降順でソート（最良が先）
            // インデックス 1 以降（最良以外）からランダムに選ぶ
            if scores.count > 1 {
                return scores[Int.random(in: 1..<scores.count, using: &rng)].direction
            }
        }

        // 最良の方向を選ぶ
        return GreedyAI.bestDirection(in: state, for: owner)
    }

    // MARK: - 位置評価・終盤全読み

    /// 駒数差 ×100 に位置評価を加えた静的評価
    func staticEval(_ state: GameState, for player: Player) -> Int {
        let base = GreedyAI.evaluate(state, for: player) * 100
        guard profile.positionalWeight > 0 else { return base }
        return base + profile.positionalWeight * positional(state.board, for: player)
    }

    /// 返されにくい駒の数の差 ×25 ＋ 次に取れる着手マス数の差 ×20（ともに自分 − 相手）
    private func positional(_ board: Board, for player: Player) -> Int {
        var stable = 0
        for p in Board.allPositions {
            guard let piece = board[p].piece else { continue }
            if isStable(p, in: board) { stable += piece.owner == player ? 1 : -1 }
        }
        var mine = 0, theirs = 0
        for p in board.emptyPositions {
            for (who, isMine) in [(player, true), (player.opponent, false)] {
                var t = board
                t[p] = .piece(Piece(who, .number(9)))
                if !t.captures(from: p).isEmpty {
                    if isMine { mine += 1 } else { theirs += 1 }
                }
            }
        }
        return stable * 25 + (mine - theirs) * 20
    }

    /// 4 軸すべてで挟まれ得ない駒（各軸で、盤端・荒地に接するか、両隣が埋まっている）
    private func isStable(_ p: Position, in board: Board) -> Bool {
        let axes: [(Direction, Direction)] = [
            (Direction(dr: 0, dc: 1), Direction(dr: 0, dc: -1)),
            (Direction(dr: 1, dc: 0), Direction(dr: -1, dc: 0)),
            (Direction(dr: 1, dc: 1), Direction(dr: -1, dc: -1)),
            (Direction(dr: 1, dc: -1), Direction(dr: -1, dc: 1)),
        ]
        for (a, b) in axes {
            let qa = p.moved(a), qb = p.moved(b)
            let blocked = { (q: Position) -> Bool in !q.isOnBoard || board[q] == .wasteland }
            if blocked(qa) || blocked(qb) { continue }
            if board[qa] != .empty && board[qb] != .empty { continue }
            return false
        }
        return true
    }

    /// 空きが少ない終盤を α-β で読み切る。ノード上限を超えたら nil（通常の読みへ）
    private func solveEndgame(state: GameState, candidates: [Move], for me: Player) -> Move? {
        var nodes = 0
        var bestMove: Move?
        var bestValue = Int.min
        for entry in ordered(candidates, in: state, mover: me) {
            let c = cost(of: entry.move.kind)
            let alpha = bestValue == Int.min ? Int.min : bestValue + c - 1
            guard let v = search(entry.sim, me: me, depth: 100, alpha: alpha, beta: Int.max,
                                 nodes: &nodes, budget: profile.endgameBudget, fullWidth: true) else {
                lastStats.nodes = nodes
                return nil
            }
            let adjusted = v - c
            if adjusted > bestValue { bestValue = adjusted; bestMove = entry.move }
        }
        lastStats.nodes = nodes
        return bestMove
    }

    // MARK: - 探索

    /// 反復深化で 2…searchDepth 手先まで読み、最後に完了した深さの評価値を返す
    /// ルートの手は 1 手評価の上位 rootBreadth 手に絞る。ゆらぎ 0 のときは窓を狭めて最善手だけ厳密に求める
    private func deepScores(state: GameState, candidates: [Move], for me: Player) -> [(move: Move, score: Int)] {
        var rootOrder = Array(ordered(candidates, in: state, mover: me).prefix(profile.rootBreadth))
        var result = rootOrder.map { (move: $0.move, score: $0.key) }
        let needExact = profile.selectionTemperature >= 0.01
        var totalNodes = 0

        for depth in 2...max(2, profile.searchDepth) {
            var nodes = 0
            var scores: [(move: Move, score: Int)] = []
            var bestAdjusted = Int.min
            var completed = true
            for entry in rootOrder {
                let c = cost(of: entry.move.kind)
                let alpha = (needExact || bestAdjusted == Int.min) ? Int.min : bestAdjusted + c - 1
                guard let v = search(entry.sim, me: me, depth: depth - 1, alpha: alpha, beta: Int.max,
                                     nodes: &nodes, budget: profile.nodeBudget, fullWidth: false) else {
                    completed = false
                    break
                }
                let adjusted = v - c
                scores.append((entry.move, adjusted))
                bestAdjusted = max(bestAdjusted, adjusted)
            }
            totalNodes += nodes
            guard completed else { break }
            result = scores
            lastStats.depthReached = depth
            // 次の深さでは前回の評価が高い手から読む（枝刈りが効く）
            rootOrder = zip(rootOrder, scores).sorted { $0.1.score > $1.1.score }.map(\.0)
        }
        lastStats.nodes = totalNodes
        return result
    }

    /// `me` 視点の評価値。手番が誰でも、`me` が最大化・相手が最小化する
    /// 予算（展開した手数）を超えたら nil
    private func search(
        _ s: GameState, me: Player, depth: Int, alpha: Int, beta: Int,
        nodes: inout Int, budget: Int, fullWidth: Bool
    ) -> Int? {
        if case .finished = s.phase { return terminal(s, for: me) }
        if depth == 0 { return staticEval(s, for: me) }
        var cands = fastMoves(s)
        if cands.isEmpty { return terminal(s, for: me) }
        if !fullWidth, cands.count > profile.searchBreadth {
            cands = Array(cands.prefix(profile.searchBreadth))
        }

        let mover = s.current
        let maximizing = mover == me
        var a = alpha, b = beta
        var best = maximizing ? Int.min : Int.max
        for cand in cands {
            nodes += 1
            if nodes > budget { return nil }
            var sim = s
            do { try sim.place(cand.move.kind, at: cand.move.position) } catch { continue }
            GreedyAI.resolveBombsGreedily(&sim)
            guard let v = search(sim, me: me, depth: depth - 1, alpha: a, beta: b,
                                 nodes: &nodes, budget: budget, fullWidth: fullWidth) else { return nil }
            if maximizing { best = max(best, v); a = max(a, best) } else { best = min(best, v); b = min(b, best) }
            if a >= b { break }
        }
        return best == Int.min || best == Int.max ? staticEval(s, for: me) : best
    }

    /// 合法手を、置く前に解析的に求めた「取れる枚数」で並べる（シミュレートしない）
    /// 方向ごとに、敵の列・向こう側の自駒の列・手前の自駒の列から数字の閾値 `n > 敵の合計 − 手前 − 向こう` を出す
    /// （Board.captures(from:) と同じ判定。灰マスは取れる時だけ置ける）
    struct Candidate {
        var move: Move
        var captured: Int
        var key: Int
    }

    func fastMoves(_ s: GameState) -> [Candidate] {
        guard case .playing = s.phase else { return [] }
        let me = s.current, opp = me.opponent
        let board = s.board
        let kinds = s.hand(of: me).availableKinds
        guard !kinds.isEmpty else { return [] }

        var out: [Candidate] = []
        out.reserveCapacity(kinds.count * 24)
        for p in board.emptyPositions {
            let isGray = Board.zone(of: p) == .gray
            var lines: [(count: Int, numbers: Int, threshold: Int)] = []
            for d in Direction.all {
                let enemy = board.run(from: p.moved(d), direction: d, owner: opp)
                guard let last = enemy.last else { continue }
                let far = board.run(from: last.moved(d), direction: d, owner: me)
                guard !far.isEmpty else { continue }
                let behind = board.run(from: p.moved(d.reversed), direction: d.reversed, owner: me)
                var numbers = 0
                for q in enemy where board[q].piece?.kind.isNumber == true { numbers += 1 }
                lines.append((enemy.count, numbers, board.sum(enemy) - board.sum(behind) - board.sum(far)))
            }
            for kind in kinds {
                var count = 0, numbers = 0
                for line in lines {
                    let captures: Bool
                    switch kind {
                    case .tank: captures = true
                    case .number(let n): captures = n > line.threshold
                    case .bomb: captures = 0 > line.threshold
                    }
                    if captures { count += line.count; numbers += line.numbers }
                }
                if isGray && count == 0 { continue }
                // 駒数差の増分: 置いた 1 枚 ＋ 数字は +2（相手から自分へ）、T/B は +1（荒地になる）
                let gain = 1 + 2 * numbers + (count - numbers)
                out.append(Candidate(move: Move(kind, at: p), captured: count, key: gain * 100 - cost(of: kind)))
            }
        }
        out.sort { $0.key > $1.key }
        return out
    }

    /// 終局の評価。勝敗を駒数差より優先する
    private func terminal(_ s: GameState, for me: Player) -> Int {
        let d = s.score(of: me) - s.score(of: me.opponent)
        return d * 100 + (d > 0 ? ReadingAI.winBonus : d < 0 ? -ReadingAI.winBonus : 0)
    }

    /// 合法手を打った後の局面を、手番側にとっての 1 手評価の降順に並べる
    private func ordered(
        _ moves: [Move], in s: GameState, mover: Player
    ) -> [(move: Move, sim: GameState, key: Int)] {
        var result: [(move: Move, sim: GameState, key: Int)] = []
        result.reserveCapacity(moves.count)
        for move in moves {
            var sim = s
            do { try sim.place(move.kind, at: move.position) } catch { continue }
            GreedyAI.resolveBombsGreedily(&sim)
            result.append((move, sim, GreedyAI.evaluate(sim, for: mover) * 100 - cost(of: move.kind)))
        }
        result.sort { $0.key > $1.key }
        return result
    }

    // MARK: - Private

    /// 初期配置で、中位の数字を優先してランダムに置く
    private func chooseSetupMove<R: RandomNumberGenerator>(
        from moves: [Move],
        in state: GameState,
        using rng: inout R
    ) -> Move? {
        let kind = setupKind(in: state.hand(of: state.current))
        let cells = Set(moves.map(\.position))
        return Move(kind, at: cells.randomElement(using: &rng)!)
    }

    /// softmax による温度付き選択
    /// 温度が高いほど、評価値の差が小さくなり、次善手も選ばれやすくなる
    /// スコアが大きく異なる場合、スコア差を正規化した上で温度を適用
    private func selectMoveByTemperature<R: RandomNumberGenerator>(
        candidates: [(move: Move, score: Int)],
        temperature: Double,
        using rng: inout R
    ) -> Move? {
        guard !candidates.isEmpty else { return nil }

        if temperature < 0.01 {
            // 確定的: 最高スコアの手を選ぶ
            let maxScore = candidates.map(\.score).max() ?? Int.min
            return candidates.filter { $0.score == maxScore }.randomElement(using: &rng)?.move
        }

        // 温度付き softmax
        // スコア差を [0, 1] 範囲に正規化してから温度を適用
        let scores = candidates.map(\.score)
        let minScore = scores.min() ?? 0
        let maxScore = scores.max() ?? 0
        let scoreRange = maxScore - minScore

        // スコアを [0, 1] に正規化
        let normalizedScores = scores.map { score in
            scoreRange > 0 ? Double(score - minScore) / Double(scoreRange) : 0.5
        }

        // 温度付き重みを計算
        let weights = normalizedScores.map { exp($0 / temperature) }
        let sumWeights = weights.reduce(0, +)
        let probs = weights.map { $0 / sumWeights }

        // 確率分布に基づいてサンプリング
        var cumulative = 0.0
        let r = Double.random(in: 0..<1, using: &rng)
        for (i, prob) in probs.enumerated() {
            cumulative += prob
            if r < cumulative {
                return candidates[i].move
            }
        }

        return candidates.last?.move
    }

    /// 駒の価値コスト
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
