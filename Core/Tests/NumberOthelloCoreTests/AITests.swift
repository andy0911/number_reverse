import Foundation
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

struct HardVsClassicTests {
    /// 位置評価＋終盤全読みの新「つよい」が旧「つよい」に勝ち越すかを計測する
    @Test("新つよい vs 旧つよい（先後入れ替え）")
    func newHardBeatsClassic() throws {
        var newWins = 0, oldWins = 0, draws = 0
        let games = 12
        for seed in 0..<UInt64(games) {
            for newIsFirst in [true, false] {
                var rng = SeededRNG(state: seed &+ 100)
                var state = GameState()
                var model = [Player.first: OpponentModel(), .second: OpponentModel()]
                let newAI = ReadingAI(profile: .hard), oldAI = ReadingAI(profile: .hardClassic)
                var guardCount = 0
                while state.outcome == nil, guardCount < 400 {
                    guardCount += 1
                    if case .awaitingBombDirection = state.phase {
                        try state.chooseBombDirection(GreedyAI.bestDirection(in: state, for: state.current))
                        continue
                    }
                    let p = state.current
                    let useNew = (p == .first) == newIsFirst
                    let ai = useNew ? newAI : oldAI
                    let r = ai.chooseMove(in: state, opponentModel: model[p]!, using: &rng)
                    model[p] = r.updatedModel
                    guard let m = r.move else { break }
                    try state.place(m.kind, at: m.position)
                }
                let newP: Player = newIsFirst ? .first : .second
                let a = state.score(of: newP), b = state.score(of: newP.opponent)
                if a > b { newWins += 1 } else if b > a { oldWins += 1 } else { draws += 1 }
            }
        }
        print("新つよい \(newWins) 勝 / 旧つよい \(oldWins) 勝 / 引分 \(draws)（\(games * 2) 局）")
        #expect(newWins >= oldWins)
    }
}

struct HardVsPreviousTests {
    /// 強化した「つよい」が 1 つ前の「つよい」に勝ち越すこと、1 手の思考時間が現実的なことを計測する
    @Test("新つよい vs 前のつよい（先後入れ替え）")
    func newHardBeatsPrevious() throws {
        var newWins = 0, oldWins = 0, draws = 0
        var maxMove = 0.0, totalMove = 0.0, moveCount = 0
        let games = 6
        for seed in 0..<UInt64(games) {
            for newIsFirst in [true, false] {
                var rng = SeededRNG(state: seed &+ 500)
                var state = GameState()
                var model = [Player.first: OpponentModel(), .second: OpponentModel()]
                let newAI = ReadingAI(profile: .hard), oldAI = ReadingAI(profile: .hardPrevious)
                var guardCount = 0
                while state.outcome == nil, guardCount < 400 {
                    guardCount += 1
                    if case .awaitingBombDirection = state.phase {
                        let ai = ((state.current == .first) == newIsFirst) ? newAI : oldAI
                        try state.chooseBombDirection(ai.chooseBombDirection(in: state, using: &rng))
                        continue
                    }
                    let p = state.current
                    let useNew = (p == .first) == newIsFirst
                    let ai = useNew ? newAI : oldAI
                    let t0 = Date()
                    let r = ai.chooseMove(in: state, opponentModel: model[p]!, using: &rng)
                    if useNew {
                        let dt = Date().timeIntervalSince(t0)
                        maxMove = max(maxMove, dt); totalMove += dt; moveCount += 1
                    }
                    model[p] = r.updatedModel
                    guard let m = r.move else { break }
                    try state.place(m.kind, at: m.position)
                }
                let newP: Player = newIsFirst ? .first : .second
                let a = state.score(of: newP), b = state.score(of: newP.opponent)
                if a > b { newWins += 1 } else if b > a { oldWins += 1 } else { draws += 1 }
            }
        }
        print("新つよい \(newWins) 勝 / 前のつよい \(oldWins) 勝 / 引分 \(draws)（\(games * 2) 局） 1手 平均 \(totalMove / Double(max(1, moveCount))) 秒 / 最大 \(maxMove) 秒")
        #expect(newWins >= oldWins)
    }
}
