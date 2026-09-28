import Testing
@testable import NumberOthelloCore

/// 再現可能な乱数（SplitMix64）
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Suite("CPU spec §9")
struct AITests {
    @Test("CPU 同士の対局は必ず終了し、盤上の駒と手駒の枚数が保存される", arguments: 0..<30)
    func selfPlayTerminates(seed: UInt64) throws {
        var rng = SeededRNG(state: seed)
        let ai = GreedyAI()
        var state = GameState()
        var turns = 0

        while state.phase != .finished {
            turns += 1
            try #require(turns < 200)
            if case .awaitingBombDirection = state.phase {
                try state.chooseBombDirection(ai.chooseBombDirection(in: state))
                continue
            }
            let move = try #require(ai.chooseMove(in: state, using: &rng))
            #expect(state.validate(move) == nil)
            try state.place(move.kind, at: move.position)

            // 保存則: 盤上の駒 + × + 手駒 = 初期手駒の総数 (32 + 33)
            let onBoard = Board.allPositions.filter { state.board[$0] != .empty }.count
            let inHands = state.hand(of: .first).total + state.hand(of: .second).total
            #expect(onBoard + inHands == 65)
        }
        #expect(state.outcome != nil)
        #expect(state.legalMoves().isEmpty)
    }

    @Test("取れる手があれば取る")
    func prefersCapture() throws {
        let state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow, emptyRow,
            ". . . a9 b1 . . .",
            emptyRow, emptyRow, emptyRow,
        ]), current: .first)
        var rng = SeededRNG(state: 1)
        let move = try #require(GreedyAI().chooseMove(in: state, using: &rng))
        var sim = state
        try sim.place(move.kind, at: move.position)
        #expect(sim.score(of: .second) == 0)
    }

    @Test("自分の爆弾の方向は相手駒を多く裏返す方を選ぶ")
    func bombDirectionChoice() throws {
        var state = GameState(board: makeBoard([
            emptyRow, emptyRow, emptyRow,
            ". a1 . a1 . . . .",
            ". a9 bB . . . . .",
            ". a1 . a1 . . . .",
            emptyRow, emptyRow,
        ]), current: .first)
        try state.place(.number(1), at: Position(4, 3))
        #expect(GreedyAI().chooseBombDirection(in: state) == .diagonal)
    }

    @Test("赤・青の空きが B の残数以下なら B を使い切る")
    func spendsBombsBeforeOnlyGrayRemains() throws {
        var board = Board()
        for p in Board.allPositions { board[p] = .wasteland }
        board[Position(0, 0)] = .empty
        board[Position(1, 1)] = .empty
        board[Position(2, 2)] = piece(.first, .number(5))
        let state = GameState(board: board, current: .first)
        var rng = SeededRNG(state: 3)
        let move = try #require(GreedyAI().chooseMove(in: state, using: &rng))
        #expect(move == Move(.bomb, at: Position(1, 1)))
    }
}
