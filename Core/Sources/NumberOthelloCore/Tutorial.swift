// コーチモード（遊び方の説明）のモデルと検証。
//
// 設計方針: 説明文が「〜すると裏返ります」と述べるとき、その主張は必ず実際の `GameState` を動かした結果と照合する。
// - シナリオは初期盤面と手順（`TutorialStep`）の列で、手順ごとに実演（`TutorialDemo`）を `GameState` へ適用する。
// - 説明文の主張は `TutorialClaim` として手順に併記し、`run()` が実行のたびに検証する。
//   不一致は `TutorialRun.failures` に載る（テストで空であることを保証し、アプリでも警告表示に使う）。
// - 画面のハイライトのうち、置いた駒・裏返った駒は宣言した座標ではなく実行で得た `GameEvent` から求める
//   （場所そのものを指す `.cells` だけは固定のマス。盤上のマスであることをテストで確認する）。
// 具体的なシナリオは TutorialScenarios.swift。

/// コーチモードで説明する項目（spec の節との対応は TutorialScenarios.swift の各シナリオを参照）
public enum TutorialTopic: String, CaseIterable, Sendable {
    case zones
    case flip
    case tie
    case behindArmy
    case enemyArmy
    case tank
    case bombNoAttack
    case bombExplosion
    case wasteland
    case grayCell
    case passAndEnd
}

/// 実演で行う操作。誰の操作かも明示し、実行時に `GameState` の手番と一致することを検証する
public enum TutorialAction: Hashable, Sendable {
    case place(Player, PieceKind, at: Position)
    /// 爆弾の持ち主による爆発方向の選択（spec §5.4）
    case chooseBomb(Player, BombDirection)
}

/// コーチマークで指し示す対象
public enum TutorialFocus: Hashable, Sendable {
    case none
    /// 盤上の固定のマス（その場所自体を説明するとき）
    case cells([Position])
    /// あるゾーンのマスすべて
    case zone(Zone)
    /// 陣の境目の点線
    case divider
    /// 実演で実際に置かれた駒（実行結果から求める）
    case placed
    /// 実演で実際に裏返った駒（実行結果から求める）
    case flipped
}

/// 説明文の主張。`TutorialScenario.run()` が実際の `GameState` に照らして成否を判定する
enum TutorialClaim: Hashable, Sendable {
    // 盤面・状態（実演前の主張は実演前の状態、実演後の主張は実演後の状態で判定）
    case cell(Position, Cell)
    case zone(Position, Zone)
    case side(Position, Player)
    case zoneCount(Zone, Int)
    case handCount(Player, PieceKind, Int)
    case current(Player)
    case phase(Phase)
    case score(Player, Int)
    case emptyCells(Set<Position>)
    case outcome(Outcome)
    /// 手番のプレイヤーが、その駒をそのゾーンの空きマスすべて（1 つ以上）に置ける（spec §4.2 赤・青マスは常に可）
    case canPlaceAnywhere(Zone, PieceKind)
    // 実演の結果（実演後の主張でのみ使える）
    /// この実演で裏返った（× になった）駒がちょうどこの集合
    case flipped(Set<Position>)
    /// 最後の操作がこの理由で拒否された（盤面は変わらない）
    case rejected(MoveError)
    /// この実演でこのプレイヤーがパスになった
    case passed(Player)
    /// 置いた直後（裏返す前）の盤面で、その方向の軍の合計。behind=置いた駒とその背後の自軍、far=挟んだ先の自軍、enemy=挟まれる相手の軍（spec §5.1, R-1）
    case sandwich(from: Position, direction: Direction, behind: Int, far: Int, enemy: Int)
    // 「もし〜だったら」の主張。実演前の状態から（`removing` のマスの駒を取り除いたうえで）操作を試算する
    /// 実演の代わりにこの操作をしていたら、裏返るのがちょうどこの集合
    case whatIf(TutorialAction, removing: Set<Position> = [], flipped: Set<Position>)
    /// 実演の代わりにこの操作（駒を置く手）をしていたら、置いた直後（裏返す前）のその方向の軍の合計がこの値
    case whatIfSums(TutorialAction, removing: Set<Position> = [], direction: Direction, behind: Int, far: Int, enemy: Int)
    /// 実演の代わりにこの操作をしていたら、この理由で拒否される
    case whatIfRejected(TutorialAction, MoveError)
}

/// 実演。`actions` を実際の `GameState` に順に適用する
public struct TutorialDemo: Sendable {
    public let buttonTitle: String
    let actions: [TutorialAction]
    /// 実演後の説明
    public let result: String
    public let resultFocus: TutorialFocus
    /// 実演後に成り立つべき主張
    let after: [TutorialClaim]
}

/// コーチマーク 1 枚分の手順
public struct TutorialStep: Sendable {
    public let title: String
    /// 実演前（実演の無い手順ではそのまま）の説明
    public let lead: String
    public let focus: TutorialFocus
    public let demo: TutorialDemo?
    /// 実演前の状態で成り立つべき主張（lead が盤面について述べる内容）
    let before: [TutorialClaim]
}

public struct TutorialScenario: Sendable, Identifiable {
    public let id: TutorialTopic
    public let title: String
    public let initial: GameState
    public let steps: [TutorialStep]

    /// 初期盤面から手順を順に実際の `GameState` で実行する。手順 i の実演後の状態が手順 i+1 の実演前になる
    public func run() -> TutorialRun {
        var state = initial
        var outcomes: [TutorialStepOutcome] = []
        for (index, step) in steps.enumerated() {
            let outcome = step.execute(from: state, label: "\(id.rawValue)#\(index + 1)「\(step.title)」")
            state = outcome.after
            outcomes.append(outcome)
        }
        return TutorialRun(steps: outcomes)
    }
}

/// 1 手順を実際に実行した結果
public struct TutorialStepOutcome: Sendable {
    public let before: GameState
    /// 実演後の状態。実演の無い手順では `before` と同じ。
    /// 拒否された操作自体は状態を変えない（複数操作の途中で拒否されたら、それまでに成功した操作の結果は残る）
    public let after: GameState
    /// 実演で起きた出来事（この手順の操作で新しく発生したもののみ）
    public let events: [GameEvent]
    /// 実演の操作がエンジンに拒否された場合の理由（拒否された操作は盤面を変えない）
    public let rejection: MoveError?
    /// 最後に置こうとした駒を置いた直後（裏返す前）の盤面。軍の合計の検証に使う
    let attemptedBoard: Board?
    /// 主張が実際の挙動と一致しなかった箇所（空であるべき）
    public internal(set) var failures: [String]

    public var flipped: Set<Position> { Self.flippedPositions(in: events) }

    public var placed: Set<Position> {
        Set(events.compactMap { if case .placed(let p, _) = $0 { p } else { nil } })
    }

    /// `focus` が指す実際のマス。`.divider` は特定のマスを持たないので空
    public func cells(for focus: TutorialFocus, afterDemo: Bool) -> Set<Position> {
        switch focus {
        case .none, .divider: []
        case .cells(let cells): Set(cells)
        case .zone(let zone): Set(Board.allPositions.filter { Board.zone(of: $0) == zone })
        case .placed: afterDemo ? placed : []
        case .flipped: afterDemo ? flipped : []
        }
    }

    static func flippedPositions(in events: [GameEvent]) -> Set<Position> {
        Set(events.flatMap { event -> [Position] in
            if case .flipped(let positions) = event { positions } else { [] }
        })
    }
}

public struct TutorialRun: Sendable {
    public let steps: [TutorialStepOutcome]
    public var failures: [String] { steps.flatMap(\.failures) }
}

// MARK: - 実行と検証

extension TutorialAction {
    var player: Player {
        switch self {
        case .place(let player, _, _), .chooseBomb(let player, _): player
        }
    }

    /// 今この操作を行うべきプレイヤー（置く手は手番、爆発方向は爆弾の持ち主）
    func actor(in state: GameState) -> Player? {
        switch self {
        case .place: state.current
        case .chooseBomb:
            if case .awaitingBombDirection(let owner, _) = state.phase { owner } else { nil }
        }
    }

    /// この操作の駒を置いた直後（裏返す前）の盤面。駒を置く手でなければ nil
    func placedBoard(in state: GameState) -> Board? {
        guard case .place(_, let kind, let position) = self else { return nil }
        var board = state.board
        board[position] = .piece(Piece(state.current, kind))
        return board
    }

    /// 実際の `GameState` に適用し、この操作で新しく起きたイベントを返す。
    /// `place` は events を作り直すが `chooseBombDirection` は追記するため、追記分だけを切り出す
    func apply(to state: inout GameState) throws(MoveError) -> [GameEvent] {
        switch self {
        case .place(_, let kind, let position):
            try state.place(kind, at: position)
            return state.events
        case .chooseBomb(_, let direction):
            let known = state.events.count
            try state.chooseBombDirection(direction)
            return Array(state.events.dropFirst(known))
        }
    }
}

extension TutorialStep {
    func execute(from start: GameState, label: String) -> TutorialStepOutcome {
        var failures = before
            .filter { !$0.holds(in: start, result: nil) }
            .map { "\(label): 実演前の主張が実際の状態と不一致 \($0)" }
        guard let demo else {
            return TutorialStepOutcome(
                before: start, after: start, events: [], rejection: nil, attemptedBoard: nil, failures: failures)
        }

        var state = start
        var events: [GameEvent] = []
        var rejection: MoveError?
        var attemptedBoard: Board?
        actions: for action in demo.actions {
            guard action.actor(in: state) == action.player else {
                failures.append("\(label): \(action) の実行者が実際の手番と不一致")
                break actions
            }
            attemptedBoard = action.placedBoard(in: state) ?? attemptedBoard
            do throws(MoveError) {
                events += try action.apply(to: &state)
            } catch {
                rejection = error
                break actions
            }
        }

        var outcome = TutorialStepOutcome(
            before: start, after: state, events: events, rejection: rejection,
            attemptedBoard: attemptedBoard, failures: failures)
        if let rejection, !demo.after.contains(.rejected(rejection)) {
            outcome.failures.append("\(label): 想定外の拒否 \(rejection)")
        }
        for claim in demo.after where !claim.holds(in: state, result: outcome) {
            outcome.failures.append("\(label): 実演後の主張が実際の結果と不一致 \(claim)")
        }
        return outcome
    }
}

extension TutorialClaim {
    /// `state` は実演前の主張なら実演前、実演後の主張なら実演後の状態。
    /// `result` は実演後の主張でのみ渡される（実演前の主張で結果系の主張を使うと不成立になる）
    func holds(in state: GameState, result: TutorialStepOutcome?) -> Bool {
        switch self {
        case .cell(let position, let cell): return state.board[position] == cell
        case .zone(let position, let zone): return Board.zone(of: position) == zone
        case .side(let position, let player): return Board.side(of: position) == player
        case .zoneCount(let zone, let count):
            return Board.allPositions.filter { Board.zone(of: $0) == zone }.count == count
        case .handCount(let player, let kind, let count): return state.hand(of: player).count(of: kind) == count
        case .current(let player): return state.current == player
        case .phase(let phase): return state.phase == phase
        case .score(let player, let score): return state.score(of: player) == score
        case .emptyCells(let cells): return Set(state.board.emptyPositions) == cells
        case .outcome(let outcome): return state.outcome == outcome
        case .canPlaceAnywhere(let zone, let kind):
            let cells = state.board.emptyPositions.filter { Board.zone(of: $0) == zone }
            return !cells.isEmpty && cells.allSatisfy { state.validate(Move(kind, at: $0)) == nil }
        case .flipped(let positions): return result?.flipped == positions
        case .rejected(let error): return result?.rejection == error
        case .passed(let player): return result?.events.contains(.passed(player)) ?? false
        case .sandwich(let from, let direction, let behind, let far, let enemy):
            guard let sums = result?.attemptedBoard?.armySums(from: from, direction: direction) else { return false }
            return sums == (behind, far, enemy)
        case .whatIf(let action, let removing, let flipped):
            guard let trial = result?.before.trial(action, removing: removing) else { return false }
            return TutorialStepOutcome.flippedPositions(in: trial.events) == flipped
        case .whatIfSums(let action, let removing, let direction, let behind, let far, let enemy):
            guard case .place(_, _, let from) = action,
                  let trial = result?.before.trial(action, removing: removing),
                  let sums = trial.placedBoard?.armySums(from: from, direction: direction) else { return false }
            return sums == (behind, far, enemy)
        case .whatIfRejected(let action, let expected):
            guard let before = result?.before, action.actor(in: before) == action.player else { return false }
            var state = before
            do throws(MoveError) {
                _ = try action.apply(to: &state)
                return false
            } catch {
                return error == expected
            }
        }
    }
}

extension GameState {
    /// この状態（から `removing` のマスの駒を取り除いた盤面）で `action` を試した結果。拒否される操作なら nil。
    /// 取り除くと本戦（`.playing`）の状態から始めることになるので、初期配置の状態では `removing` を使わない
    func trial(_ action: TutorialAction, removing: Set<Position>)
        -> (events: [GameEvent], placedBoard: Board?)?
    {
        guard action.actor(in: self) == action.player else { return nil }
        var state = self
        if !removing.isEmpty {
            var board = self.board
            for position in removing { board[position] = .empty }
            state = GameState(board: board, current: current, hands: hands)
        }
        let placedBoard = action.placedBoard(in: state)
        guard let events = try? action.apply(to: &state) else { return nil }
        return (events, placedBoard)
    }
}

extension Board {
    /// `p` に置かれた駒から `direction` 方向の軍の合計（spec §5.1, R-1）。相手が隣接していなければ nil。
    /// behind=置いた駒とその背後の自軍、far=挟んだ先の自軍、enemy=挟まれる相手の軍。判定（`captures`）と同じ `run` / `sum` で数える
    func armySums(from p: Position, direction: Direction) -> (behind: Int, far: Int, enemy: Int)? {
        guard let placed = self[p].piece else { return nil }
        let enemy = run(from: p.moved(direction), direction: direction, owner: placed.owner.opponent)
        guard let last = enemy.last else { return nil }
        let far = run(from: last.moved(direction), direction: direction, owner: placed.owner)
        let behind = run(from: p, direction: direction.reversed, owner: placed.owner)
        return (sum(behind), sum(far), sum(enemy))
    }

    /// 盤面を 8 行のテキストで記述する。トークンは空白区切りで
    /// `.` 空 / `x` 荒地 / `a<k>` 先行 / `b<k>` 後攻（k は 1-9・T・B）
    init(diagram rows: [String]) {
        self.init()
        precondition(rows.count == Board.size)
        for (r, line) in rows.enumerated() {
            let tokens = line.split(separator: " ")
            precondition(tokens.count == Board.size)
            for (c, token) in tokens.enumerated() {
                let cell: Cell
                switch token {
                case ".": cell = .empty
                case "x": cell = .wasteland
                default:
                    let owner: Player = token.first == "a" ? .first : .second
                    let k = token.dropFirst()
                    let kind: PieceKind = k == "T" ? .tank : k == "B" ? .bomb : .number(Int(k)!)
                    cell = .piece(Piece(owner, kind))
                }
                self[Position(r, c)] = cell
            }
        }
    }
}
