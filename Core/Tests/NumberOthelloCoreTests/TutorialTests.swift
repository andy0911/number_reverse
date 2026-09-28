import Testing
@testable import NumberOthelloCore

/// コーチモードのシナリオが、実際の `GameState`（エンジン）の挙動と食い違っていないことを検証する。
///
/// 3 層で保証する:
/// 1. `TutorialClaimsTests`: 全シナリオの全主張（説明文に併記した事実）が `run()` で実エンジンの結果と一致する
/// 2. `TutorialNarrationTests`: 説明文が述べる主要な事実を、`run()` を介さず `GameState` を直接動かして独立に確認する
/// 3. `TutorialVerificationTests`: 主張の検証機構が、嘘の主張を実際に検出できる（空振りしない）
@Suite("コーチモード: 主張の検証")
struct TutorialClaimsTests {
    @Test("全シナリオの主張が実際の GameState の結果と一致する", arguments: TutorialTopic.allCases)
    func allClaimsHold(topic: TutorialTopic) {
        let run = Tutorial.scenario(topic).run()
        #expect(run.failures.isEmpty, "\(run.failures)")
    }

    @Test("説明項目（TutorialTopic）とシナリオが 1 対 1 で対応する")
    func topicsAreCoveredExactlyOnce() {
        #expect(Tutorial.scenarios.map(\.id) == TutorialTopic.allCases)
    }

    @Test("実演には結果の主張（裏返り / 拒否）が必ず付いている", arguments: TutorialTopic.allCases)
    func everyDemoDeclaresItsOutcome(topic: TutorialTopic) {
        for step in Tutorial.scenario(topic).steps {
            guard let demo = step.demo else { continue }
            let declaresOutcome = demo.after.contains {
                switch $0 {
                case .flipped, .rejected: true
                default: false
                }
            }
            #expect(declaresOutcome, "\(topic)「\(step.title)」の実演が結果を主張していない")
        }
    }

    @Test("ハイライトは実行結果から求める: 裏返った駒・置かれた駒・ゾーン")
    func focusCellsComeFromTheRun() throws {
        let run = Tutorial.scenario(.flip).run()
        let demoStep = run.steps[1]
        // 実演前は裏返った駒を指さず、実演後は実際に裏返った (5,2) を指す
        #expect(demoStep.cells(for: .flipped, afterDemo: false).isEmpty)
        #expect(demoStep.cells(for: .flipped, afterDemo: true) == [Position(5, 2)])
        #expect(demoStep.cells(for: .placed, afterDemo: true) == [Position(4, 3)])
        #expect(demoStep.cells(for: .zone(.red), afterDemo: false).count == 4)
        #expect(demoStep.cells(for: .divider, afterDemo: false).isEmpty)
        // 爆発方向の選択は events に追記されるが、この手順で新しく起きた裏返りだけを返す
        let bomb = Tutorial.scenario(.bombExplosion).run()
        #expect(bomb.steps[1].flipped == [Position(4, 2)])
        #expect(bomb.steps[2].flipped.count == 5)
    }
}

/// 説明文が述べる事実を、`run()` の検証機構を使わず `GameState` を直接動かして確認する。
/// 各テストの `#expect` が、対応するシナリオの説明文の主張に 1 対 1 で対応する。
@Suite("コーチモード: 説明文の主張をエンジンで独立検証")
struct TutorialNarrationTests {
    private func at(_ row: Int, _ col: Int) -> Position { Position(row, col) }

    /// `before` と `after` で内容が変わったマス
    private func changed(_ before: Board, _ after: Board) -> Set<Position> {
        Set(Board.allPositions.filter { before[$0] != after[$0] })
    }

    @Test("マスの色と点線: マス数、初期配置の制約、6 手で本戦へ")
    func zones() throws {
        func count(_ zone: Zone) -> Int { Board.allPositions.filter { Board.zone(of: $0) == zone }.count }
        #expect(count(.red) == 4)
        #expect(count(.blue) == 32)
        #expect(count(.gray) == 28)
        #expect(Board.side(of: at(3, 0)) == .second)
        #expect(Board.side(of: at(4, 0)) == .first)

        var state = Tutorial.scenario(.zones).initial
        #expect(state.phase == .setup(step: 0))
        // 赤マスでも相手の陣には置けない / 初期配置に T は使えない
        #expect(throws: MoveError.invalidSetupCell) { try state.place(.number(5), at: Position(3, 3)) }
        #expect(throws: MoveError.numberRequiredInSetup) { try state.place(.tank, at: Position(4, 3)) }
        // 赤に 1 枚ずつ → 青に 2 枚ずつの 6 手。裏返しは起きない
        try state.place(.number(5), at: at(4, 3))
        try state.place(.number(5), at: at(3, 4))
        try state.place(.number(4), at: at(5, 2))
        try state.place(.number(4), at: at(2, 5))
        try state.place(.number(6), at: at(6, 6))
        try state.place(.number(6), at: at(1, 1))
        #expect(state.phase == .playing)
        #expect(state.current == .first)
        #expect(state.score(of: .first) == 3)
        #expect(state.score(of: .second) == 3)
        #expect(state.events.allSatisfy { if case .flipped = $0 { false } else { true } })
    }

    @Test("駒の裏返り: 9 と 5 で 6 を挟むと先行の 4、3 と 3 で 4 を挟むと後攻の 6")
    func flip() throws {
        var state = Tutorial.scenario(.flip).initial
        try state.place(.number(9), at: at(4, 3))
        #expect(state.board[at(5, 2)] == piece(.first, .number(4)))
        try state.place(.number(3), at: at(5, 1))
        #expect(state.board[at(5, 2)] == piece(.second, .number(6)))
    }

    @Test("同値: 2 + 3 = 5 は 5 に等しく裏返らない。3 なら 3 + 3 = 6 で裏返る")
    func tie() throws {
        let initial = Tutorial.scenario(.tie).initial
        var equal = initial
        try equal.place(.number(2), at: at(4, 3))
        #expect(equal.board[at(4, 2)] == piece(.second, .number(5)))
        var greater = initial
        try greater.place(.number(3), at: at(4, 3))
        #expect(greater.board[at(4, 2)] == piece(.first, .number(5)))
    }

    @Test("背後の自軍: 3 + 2 + 5 = 10 > 9 で裏返るが、背後の 3 が無ければ 2 + 5 = 7 で裏返らない")
    func behindArmy() throws {
        var state = Tutorial.scenario(.behindArmy).initial
        try state.place(.number(2), at: at(4, 2))
        #expect(state.board[at(4, 3)] == piece(.first, .number(1)))

        var withoutBehind = GameState(
            board: makeBoard([
                emptyRow, emptyRow, emptyRow, emptyRow,
                ". . . b9 a5 . . .",
                emptyRow, emptyRow, emptyRow,
            ]), current: .first)
        try withoutBehind.place(.number(2), at: at(4, 2))
        #expect(withoutBehind.board[at(4, 3)] == piece(.second, .number(9)))
    }

    @Test("相手の軍: 4 + 5 = 9 を 1 + 9 = 10 で挟むとまとめて裏返る（6 と 5）")
    func enemyArmy() throws {
        var state = Tutorial.scenario(.enemyArmy).initial
        try state.place(.number(1), at: at(4, 4))
        #expect(state.board[at(4, 2)] == piece(.first, .number(6)))
        #expect(state.board[at(4, 3)] == piece(.first, .number(5)))
    }

    @Test("T: 数字の 9 では裏返らないが T なら 9 が 2 枚とも先行の 1 になり、後で挟まれて × になる")
    func tank() throws {
        let initial = Tutorial.scenario(.tank).initial
        #expect(initial.hand(of: .first).count(of: .tank) == 1)
        #expect(initial.hand(of: .second).count(of: .tank) == 1)

        var withNumber = initial
        try withNumber.place(.number(9), at: at(4, 1))
        #expect(withNumber.board[at(4, 2)] == piece(.second, .number(9)))
        #expect(withNumber.board[at(4, 3)] == piece(.second, .number(9)))

        var state = initial
        try state.place(.tank, at: at(4, 1))
        #expect(state.board[at(4, 2)] == piece(.first, .number(1)))
        #expect(state.board[at(4, 3)] == piece(.first, .number(1)))
        try state.place(.number(1), at: at(5, 1))
        #expect(state.board[at(4, 1)] == .wasteland)
    }

    @Test("B: 置いても何も裏返らないが、数字の 1 なら裏返る。使える枚数は先行 1・後攻 2")
    func bombNoAttack() throws {
        let initial = Tutorial.scenario(.bombNoAttack).initial
        #expect(initial.hand(of: .first).count(of: .bomb) == 1)
        #expect(initial.hand(of: .second).count(of: .bomb) == 2)

        var bomb = initial
        try bomb.place(.bomb, at: at(4, 3))
        #expect(bomb.board[at(4, 2)] == piece(.second, .number(1)))
        var number = initial
        try number.place(.number(1), at: at(4, 3))
        #expect(number.board[at(4, 2)] == piece(.first, .number(9)))
    }

    @Test("爆発: 持ち主（後攻）が選び、上下左右なら 5 枚・斜めなら 2 枚が裏返り、自駒は裏返らない")
    func bombExplosion() throws {
        var state = Tutorial.scenario(.bombExplosion).initial
        try state.place(.number(1), at: at(4, 3))
        #expect(state.board[at(4, 2)] == .wasteland)
        #expect(state.phase == .awaitingBombDirection(owner: .second, at: at(4, 2)))
        #expect(state.current == .first)

        var diagonal = state
        try diagonal.chooseBombDirection(.diagonal)
        #expect(changed(state.board, diagonal.board) == [at(1, 5), at(6, 4)])

        try state.chooseBombDirection(.cross)
        #expect(state.phase == .playing)
        #expect(state.current == .second)
        #expect(state.board[at(0, 2)] == piece(.second, .number(8)))
        #expect(state.board[at(7, 2)] == piece(.second, .number(3)))
        #expect(state.board[at(4, 1)] == piece(.second, .number(1)))
        #expect(state.board[at(4, 3)] == piece(.second, .number(9)))
        #expect(state.board[at(4, 5)] == piece(.second, .number(6)))
        #expect(state.board[at(2, 2)] == piece(.second, .number(3)))
        // 斜め上の (1,5) は上下左右では裏返らない
        #expect(state.board[at(1, 5)] == piece(.first, .number(8)))
    }

    @Test("×: スコアに数えず、軍を分断して挟めず、駒も置けない")
    func wasteland() throws {
        var state = Tutorial.scenario(.wasteland).initial
        #expect(state.score(of: .first) == 1)
        #expect(state.score(of: .second) == 1)
        try state.place(.number(9), at: at(4, 4))
        #expect(state.board[at(4, 3)] == piece(.second, .number(1)))
        #expect(throws: MoveError.occupied) { try state.place(.number(1), at: Position(4, 2)) }
    }

    @Test("灰マス: 1 でも B でも置けないが、9 なら 10 > 9 で裏返して置ける")
    func grayCell() throws {
        var state = Tutorial.scenario(.grayCell).initial
        #expect(Board.zone(of: at(4, 0)) == .gray)
        #expect(state.validate(Move(.number(1), at: at(4, 0))) == .grayRequiresCapture)
        #expect(state.validate(Move(.bomb, at: at(4, 0))) == .grayRequiresCapture)
        try state.place(.number(9), at: at(4, 0))
        #expect(state.board[at(4, 0)] == piece(.first, .number(9)))
        #expect(state.board[at(4, 1)] == piece(.first, .number(1)))
    }

    @Test("パスと終了: 後攻は置けずパス、先行が灰マスで 3 枚裏返して 32 対 28 で終了（(7,7) は空いたまま）")
    func passAndEnd() throws {
        var state = Tutorial.scenario(.passAndEnd).initial
        #expect(Set(state.board.emptyPositions) == [at(6, 3), at(0, 3), at(7, 7)])
        try state.place(.number(1), at: at(6, 3))
        #expect(state.events.contains(.passed(.second)))
        #expect(state.current == .first)
        // 後攻が置ける場所が本当に無いこと（手番を後攻にして合法手を数える）
        #expect(GameState(board: state.board, current: .second).legalMoves().isEmpty)

        let before = state.board
        try state.place(.number(9), at: at(0, 3))
        #expect(changed(before, state.board) == [at(0, 3), at(1, 3), at(2, 3), at(3, 3)])
        #expect(state.phase == .finished)
        #expect(state.score(of: .first) == 32)
        #expect(state.score(of: .second) == 28)
        #expect(state.outcome == .win(.first))
        #expect(state.board.emptyPositions == [at(7, 7)])
    }
}

/// 検証機構そのものの確認。嘘の主張を書いたら `failures` に載ること
@Suite("コーチモード: 検証機構が嘘の主張を検出する")
struct TutorialVerificationTests {
    /// 「先行が 2 を置く」（同値なので裏返らない）だけの手順を持つシナリオを実行する
    private func run(
        actions: [TutorialAction] = [.place(.first, .number(2), at: Position(4, 3))],
        before: [TutorialClaim] = [],
        after: [TutorialClaim]
    ) -> TutorialRun {
        let demo = TutorialDemo(buttonTitle: "", actions: actions, result: "", resultFocus: .none, after: after)
        let step = TutorialStep(title: "検証用", lead: "", focus: .none, demo: demo, before: before)
        let base = Tutorial.scenario(.tie)
        return TutorialScenario(id: .tie, title: "", summary: "", initial: base.initial, steps: [step]).run()
    }

    private let truth: [TutorialClaim] = [
        .sandwich(from: Position(4, 3), direction: Direction(dr: 0, dc: -1), behind: 2, far: 3, enemy: 5),
        .flipped([]),
        .cell(Position(4, 2), .piece(Piece(.second, .number(5)))),
        .whatIf(.place(.first, .number(3), at: Position(4, 3)), flipped: [Position(4, 2)]),
    ]

    @Test("正しい主張は通る（検証が常に失敗する状態ではない）")
    func truthPasses() {
        #expect(run(after: truth).failures.isEmpty)
    }

    @Test("嘘の主張は検出される", arguments: [
        TutorialClaim.flipped([Position(4, 2)]),
        .cell(Position(4, 2), .piece(Piece(.first, .number(5)))),
        .sandwich(from: Position(4, 3), direction: Direction(dr: 0, dc: -1), behind: 2, far: 3, enemy: 4),
        .sandwich(from: Position(4, 3), direction: Direction(dr: 0, dc: -1), behind: 3, far: 3, enemy: 5),
        .whatIf(.place(.first, .number(3), at: Position(4, 3)), flipped: []),
        .whatIf(.place(.first, .number(2), at: Position(4, 3)), flipped: [Position(4, 2)]),
        .rejected(.grayRequiresCapture),
        .passed(.second),
        .score(.first, 99),
        .phase(.finished),
    ])
    func falseClaimsAreDetected(claim: TutorialClaim) {
        #expect(!run(after: truth + [claim]).failures.isEmpty)
    }

    @Test("実演前の嘘の主張も検出される")
    func falseBeforeClaimIsDetected() {
        #expect(!run(before: [.cell(Position(4, 2), .empty)], after: truth).failures.isEmpty)
        #expect(!run(before: [.current(.second)], after: truth).failures.isEmpty)
    }

    @Test("宣言していない拒否は失敗として検出される")
    func unexpectedRejectionIsDetected() {
        // 既に駒がある (4,2) には置けない。.rejected を主張していなければ失敗
        let occupied: [TutorialAction] = [.place(.first, .number(2), at: Position(4, 2))]
        #expect(!run(actions: occupied, after: [.flipped([])]).failures.isEmpty)
        #expect(run(actions: occupied, after: [.rejected(.occupied), .flipped([])]).failures.isEmpty)
    }

    @Test("実行者が実際の手番と違えば検出され、操作は適用されない")
    func wrongActorIsDetected() {
        let wrongActor: [TutorialAction] = [.place(.second, .number(2), at: Position(4, 3))]
        let result = run(actions: wrongActor, after: [.flipped([])])
        #expect(!result.failures.isEmpty)
        #expect(result.steps[0].after.board[Position(4, 3)] == .empty)
    }
}
