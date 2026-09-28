import Testing
@testable import NumberOthelloCore

/// 盤面を文字列から作る。トークン: `.` 空, `x` 荒地, `a<k>` 先行, `b<k>` 後攻（k は 1-9/T/B）。
/// パーサは Core の `Board(diagram:)`（コーチモードのシナリオと共用）
func makeBoard(_ rows: [String]) -> Board { Board(diagram: rows) }

let emptyRow = ". . . . . . . ."

func piece(_ owner: Player, _ kind: PieceKind) -> Cell { .piece(Piece(owner, kind)) }

@Suite("挟み判定 spec §5.1")
struct CaptureTests {
    @Test("原文例: 5 と 9 で 6 を斜めに挟む → 先行の 4 になる")
    func pdfExample() throws {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow, emptyRow,
            emptyRow,
            ". . b6 . . . . .",
            ". a5 . . . . . .",
            emptyRow,
        ]), current: .first)
        try state.place(.number(9), at: Position(4, 3))
        #expect(state.board[Position(5, 2)] == piece(.first, .number(4)))
    }

    @Test("同値は裏返らない")
    func equalDoesNotFlip() throws {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow, emptyRow,
            ". a3 b5 . . . . .",
            emptyRow, emptyRow, emptyRow,
        ]), current: .first)
        try state.place(.number(2), at: Position(4, 3))
        #expect(state.board[Position(4, 2)] == piece(.second, .number(5)))
    }

    @Test("置いた駒の背後に連なる自駒も自軍に加算 (R-1)")
    func behindArmyCounts() throws {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow, emptyRow,
            ". a3 . b9 a5 . . .",
            emptyRow, emptyRow, emptyRow,
        ]), current: .first)
        try state.place(.number(2), at: Position(4, 2))
        #expect(state.board[Position(4, 3)] == piece(.first, .number(1)))
    }

    @Test("相手の軍は連続した全駒の合計で比較し、まとめて裏返る")
    func enemyArmySum() throws {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow, emptyRow,
            ". a9 b4 b5 . . . .",
            emptyRow, emptyRow, emptyRow,
        ]), current: .first)
        try state.place(.number(1), at: Position(4, 4))
        #expect(state.board[Position(4, 2)] == piece(.first, .number(6)))
        #expect(state.board[Position(4, 3)] == piece(.first, .number(5)))
    }

    @Test("複数方向は置いた直後の盤面で同時評価される")
    func simultaneousDirections() throws {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow,
            ". . . a9 . . . .",
            ". . . b1 . . . .",
            ". a9 b1 . b8 a1 . .",
            emptyRow, emptyRow, emptyRow,
        ]), current: .first)
        try state.place(.number(1), at: Position(4, 3))
        #expect(state.board[Position(3, 3)] == piece(.first, .number(9)))
        #expect(state.board[Position(4, 2)] == piece(.first, .number(9)))
        // 右: 自 1 + 1 = 2 < 8 なので不成立
        #expect(state.board[Position(4, 4)] == piece(.second, .number(8)))
    }

    @Test("空マスがあると挟めない")
    func gapBreaksSandwich() throws {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow, emptyRow,
            ". a9 . b1 . . . .",
            emptyRow, emptyRow, emptyRow,
        ]), current: .first)
        try state.place(.number(9), at: Position(4, 4))
        #expect(state.board[Position(4, 3)] == piece(.second, .number(1)))
    }
}

@Suite("特殊駒 spec §3.2, §5.3")
struct SpecialPieceTests {
    @Test("T を置くと数値を無視して挟んだ相手を裏返す")
    func tankIgnoresNumbers() throws {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow, emptyRow,
            ". . b9 b9 a1 . . .",
            emptyRow, emptyRow, emptyRow,
        ]), current: .first)
        try state.place(.tank, at: Position(4, 1))
        #expect(state.board[Position(4, 2)] == piece(.first, .number(1)))
        #expect(state.board[Position(4, 3)] == piece(.first, .number(1)))
    }

    @Test("T は守備値 0、裏返されると × になる")
    func tankBecomesWasteland() throws {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow, emptyRow,
            ". a1 bT . . . . .",
            emptyRow, emptyRow, emptyRow,
        ]), current: .first)
        try state.place(.number(1), at: Position(4, 3))
        #expect(state.board[Position(4, 2)] == .wasteland)
        #expect(state.score(of: .second) == 0)
    }

    @Test("× をまたいで軍は作れない")
    func wastelandBreaksArmy() throws {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow, emptyRow,
            ". a9 x b1 . . . .",
            emptyRow, emptyRow, emptyRow,
        ]), current: .first)
        try state.place(.number(9), at: Position(4, 4))
        #expect(state.board[Position(4, 3)] == piece(.second, .number(1)))
    }

    @Test("T は挟む側の軍にいても数値無視にはならず値 0 (R-3)")
    func tankInFarArmyIsZero() throws {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow, emptyRow,
            ". aT b5 . . . . .",
            emptyRow, emptyRow, emptyRow,
        ]), current: .first)
        try state.place(.number(4), at: Position(4, 3))
        #expect(state.board[Position(4, 2)] == piece(.second, .number(5)))
    }

    @Test("B を置いても攻撃しない (R-4)")
    func bombDoesNotAttack() throws {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow, emptyRow,
            ". a9 b1 . . . . .",
            emptyRow, emptyRow, emptyRow,
        ]), current: .first)
        try state.place(.bomb, at: Position(4, 3))
        #expect(state.board[Position(4, 2)] == piece(.second, .number(1)))
    }

    @Test("B は灰マスに置けない (R-4)")
    func bombNotOnGray() {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow, emptyRow,
            ". b1 a9 . . . . .",
            emptyRow, emptyRow, emptyRow,
        ]), current: .first)
        #expect(throws: MoveError.grayRequiresCapture) {
            try state.place(.bomb, at: Position(4, 0))
        }
    }
}

@Suite("爆弾 spec §5.4")
struct BombTests {
    @Test("B が裏返されると ×、持ち主が方向を選び相手駒だけ盤端まで裏返る (R-5, R-7)")
    func explosionCross() throws {
        var state = GameState(board: makeBoard([
            ". . a2 . . . . .",
            emptyRow,
            ". . b3 . . . . .",
            emptyRow,
            ". a9 bB . . a4 . a6",
            emptyRow,
            ". . . . . . . .",
            ". . a7 . . . . .",
        ]), current: .first)
        try state.place(.number(1), at: Position(4, 3))
        #expect(state.board[Position(4, 2)] == .wasteland)
        #expect(state.phase == .awaitingBombDirection(owner: .second, at: Position(4, 2)))
        #expect(state.current == .first)

        try state.chooseBombDirection(.cross)
        #expect(state.board[Position(4, 1)] == piece(.second, .number(1)))
        #expect(state.board[Position(4, 3)] == piece(.second, .number(9)))
        // 空マスを飛ばして盤端まで
        #expect(state.board[Position(4, 5)] == piece(.second, .number(6)))
        #expect(state.board[Position(4, 7)] == piece(.second, .number(4)))
        #expect(state.board[Position(0, 2)] == piece(.second, .number(8)))
        #expect(state.board[Position(7, 2)] == piece(.second, .number(3)))
        // 持ち主自身の駒は裏返らない
        #expect(state.board[Position(2, 2)] == piece(.second, .number(3)))
        #expect(state.phase == .playing)
        #expect(state.current == .second)
    }

    @Test("斜めを選ぶと斜め 4 方向のみ")
    func explosionDiagonal() throws {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow,
            ". a5 . . . . . .",
            ". a9 bB . . . . .",
            ". . . a2 . . . .",
            emptyRow, emptyRow,
        ]), current: .first)
        try state.place(.number(1), at: Position(4, 3))
        try state.chooseBombDirection(.diagonal)
        #expect(state.board[Position(3, 1)] == piece(.second, .number(5)))
        #expect(state.board[Position(5, 3)] == piece(.second, .number(8)))
        // 横方向は爆発対象外（通常の挟みで 9 は残る）
        #expect(state.board[Position(4, 1)] == piece(.first, .number(9)))
        #expect(state.board[Position(4, 3)] == piece(.first, .number(1)))
    }

    @Test("爆発で裏返った相手の B も連鎖爆発し、T は × になる (R-6)")
    func chainReaction() throws {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow, emptyRow,
            ". a9 bB . . aB . aT",
            emptyRow,
            ". . . . . b2 . .",
            emptyRow,
        ]), current: .first)
        try state.place(.number(1), at: Position(4, 3))
        try state.chooseBombDirection(.cross)
        #expect(state.board[Position(4, 7)] == .wasteland)
        #expect(state.board[Position(4, 5)] == .wasteland)
        #expect(state.phase == .awaitingBombDirection(owner: .first, at: Position(4, 5)))

        try state.chooseBombDirection(.cross)
        #expect(state.board[Position(6, 5)] == piece(.first, .number(8)))
        #expect(state.phase == .playing)
    }

    @Test("割り込み中は駒を置けない")
    func cannotPlaceWhileAwaiting() throws {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow, emptyRow,
            ". a9 bB . . . . .",
            emptyRow, emptyRow, emptyRow,
        ]), current: .first)
        try state.place(.number(1), at: Position(4, 3))
        #expect(throws: MoveError.wrongPhase) {
            try state.place(.number(1), at: Position(2, 2))
        }
    }
}

@Suite("配置ルール・進行 spec §4")
struct FlowTests {
    @Test("灰マスは裏返る時のみ置ける (R-2)")
    func grayRequiresCapture() throws {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow, emptyRow,
            ". b5 a9 . . . . .",
            emptyRow, emptyRow, emptyRow,
        ]), current: .first)
        #expect(throws: MoveError.grayRequiresCapture) { try state.place(.number(9), at: Position(0, 0)) }
        // 形は挟めているが 1 + 9 = 10 > 5 … 成立するので OK
        try state.place(.number(1), at: Position(4, 0))
        #expect(state.board[Position(4, 1)] == piece(.first, .number(5)))
    }

    @Test("灰マスで形だけ挟めても数で負けるなら置けない (R-2)")
    func grayFailedCaptureIsIllegal() {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow, emptyRow,
            ". b9 a1 . . . . .",
            emptyRow, emptyRow, emptyRow,
        ]), current: .first)
        #expect(throws: MoveError.grayRequiresCapture) { try state.place(.number(1), at: Position(4, 0)) }
        #expect(throws: Never.self) { try state.place(.tank, at: Position(4, 0)) }
    }

    @Test("初期配置: 手順・ゾーン・自陣・数字駒のみ")
    func setupSequence() throws {
        var state = GameState()
        #expect(throws: MoveError.invalidSetupCell) { try state.place(.number(5), at: Position(3, 3)) }
        #expect(throws: MoveError.invalidSetupCell) { try state.place(.number(5), at: Position(5, 5)) }
        #expect(throws: MoveError.numberRequiredInSetup) { try state.place(.tank, at: Position(4, 3)) }
        try state.place(.number(5), at: Position(4, 3))
        #expect(state.current == .second)
        try state.place(.number(5), at: Position(3, 4))
        #expect(throws: MoveError.invalidSetupCell) { try state.place(.number(5), at: Position(4, 4)) }
        try state.place(.number(4), at: Position(5, 2))
        try state.place(.number(4), at: Position(2, 5))
        try state.place(.number(6), at: Position(6, 6))
        #expect(state.phase == .setup(step: 5))
        try state.place(.number(6), at: Position(1, 1))
        #expect(state.phase == .playing)
        #expect(state.current == .first)
        #expect(state.hand(of: .first).total == 32 - 3)
    }

    @Test("先行は B を 1 枚、後攻は 2 枚")
    func bombCounts() {
        #expect(Hand.initial(for: .first).count(of: .bomb) == 1)
        #expect(Hand.initial(for: .second).count(of: .bomb) == 2)
        #expect(Hand.initial(for: .first).total == 32)
        #expect(Hand.initial(for: .second).total == 33)
    }

    @Test("相手に合法手が無ければパス、両者無ければ終了")
    func passAndFinish() throws {
        // 空きは灰マス (0,0) と青マス (1,1)(1,2) のみ。後攻の手駒は空
        var board = Board()
        for p in Board.allPositions { board[p] = .wasteland }
        board[Position(0, 0)] = .empty
        board[Position(1, 1)] = .empty
        board[Position(1, 2)] = .empty
        board[Position(2, 2)] = piece(.first, .number(5))
        let hands: [Player: Hand] = [.first: .initial(for: .first), .second: Hand(counts: [:])]
        var state = GameState(board: board, current: .first, hands: hands)

        try state.place(.number(5), at: Position(1, 1))
        #expect(state.events.contains(.passed(.second)))
        #expect(state.current == .first)
        #expect(state.phase == .playing)

        try state.place(.number(5), at: Position(1, 2))
        // 残りは灰マス (0,0) のみで誰も裏返せない → 終了
        #expect(state.phase == .finished)
        #expect(state.outcome == .win(.first))
        #expect(throws: MoveError.wrongPhase) { try state.place(.number(1), at: Position(0, 0)) }
    }
}
