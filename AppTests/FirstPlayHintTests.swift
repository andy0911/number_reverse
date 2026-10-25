import Foundation
import Testing
import NumberOthelloCore
@testable import Tokaeshi

@MainActor
@Suite("初回導線のヒント（初期配置の候補マスと本戦前の案内）")
struct FirstPlayHintTests {
    @Test("初期配置で駒を選ぶ前は、置ける場所を弱く示す")
    func weakHintBeforeSelection() {
        let model = GameViewModel(mode: .twoPlayers)
        #expect(model.weakHintCells == Set(GameState.setupCells(step: 0)))
        #expect(model.highlightedCells.isEmpty)
    }

    @Test("駒を選ぶと弱い目印は消え、強い目印が出る")
    func strongHintAfterSelection() {
        let model = GameViewModel(mode: .twoPlayers)
        model.selectedKind = .number(5)
        #expect(model.weakHintCells.isEmpty)
        #expect(!model.highlightedCells.isEmpty)
    }

    @Test("本戦では弱い目印を出さない")
    func noWeakHintInPlaying() {
        let model = GameViewModel(mode: .twoPlayers, state: GameState(board: Board(), current: .first))
        #expect(model.weakHintCells.isEmpty)
    }

    @Test("初期配置が終わると案内が立ち、本戦の最初の 1 手で下りる")
    func mainPhaseNotice() {
        let model = GameViewModel(mode: .twoPlayers)
        #expect(!model.showsMainPhaseNotice)
        for _ in 0..<6 {
            let move = model.state.legalMoves()[0]
            model.selectedKind = move.kind
            model.tap(move.position)
        }
        #expect(model.state.phase == .playing)
        #expect(model.showsMainPhaseNotice)
        let move = model.state.legalMoves()[0]
        model.selectedKind = move.kind
        model.tap(move.position)
        #expect(!model.showsMainPhaseNotice)
    }
}
