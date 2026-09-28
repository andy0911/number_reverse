import SwiftUI
import NumberOthelloCore

/// コーチモードの進行状態。本編の `GameViewModel` / `GameState` とは一切共有しない独立した状態。
/// 盤面・ハイライト・説明文はすべて Core の `TutorialRun`（実際に `GameState` を動かした結果）から求める。
@MainActor
@Observable
final class CoachSession {
    private let scenarios = Tutorial.scenarios
    private(set) var lessonIndex = 0
    private(set) var stepIndex = 0
    /// 現在の手順の実演を実行済みか（実演の無い手順では常に false）
    private(set) var hasPerformed = false
    private(set) var run: TutorialRun

    init() {
        run = Tutorial.scenarios[0].run()
        reportFailures()
    }

    // MARK: - 現在の手順

    var lessonCount: Int { scenarios.count }
    var scenario: TutorialScenario { scenarios[lessonIndex] }
    var lessonTitles: [String] { scenarios.map(\.title) }
    var step: TutorialStep { scenario.steps[stepIndex] }
    var outcome: TutorialStepOutcome { run.steps[stepIndex] }

    var isFirstStep: Bool { lessonIndex == 0 && stepIndex == 0 }
    var isLastLesson: Bool { lessonIndex == scenarios.count - 1 }
    var isLastStep: Bool { isLastLesson && stepIndex == scenario.steps.count - 1 }
    var canPerform: Bool { step.demo != nil && !hasPerformed }

    /// 実演後の結果を表示している間だけ true
    private var showsResult: Bool { hasPerformed && step.demo != nil }

    /// 画面に描く盤面。実演前は `before`、実演後は実際に `GameState` を動かした `after`
    var boardState: GameState { showsResult ? outcome.after : outcome.before }
    var flipped: Set<Position> { showsResult ? outcome.flipped : [] }
    var placed: Set<Position> { showsResult ? outcome.placed : [] }

    var focus: TutorialFocus { showsResult ? step.demo?.resultFocus ?? .none : step.focus }
    /// スポットライトで明るく見せるマス。指し示す対象に加え、実演で置いた駒は常に見えるようにする
    var focusCells: Set<Position> { outcome.cells(for: focus, afterDemo: showsResult).union(placed) }
    var text: String { showsResult ? step.demo?.result ?? step.lead : step.lead }

    /// 実演がエンジンに拒否された（置けなかった）とき、その理由
    var rejection: MoveError? { showsResult ? outcome.rejection : nil }

    /// 説明文の主張が実エンジンの結果と一致しなかった手順があるか（テストで防いでいるため通常は起きない）
    var hasVerificationFailure: Bool { !run.failures.isEmpty }

    // MARK: - 操作

    /// 実演を実際の `GameState` に適用した結果を見せる（結果は `run` で計算済み。裏返り演出を付けて切り替える）
    func perform() {
        guard canPerform else { return }
        withAnimation(.easeInOut(duration: 0.7)) { hasPerformed = true }
    }

    func replay() {
        hasPerformed = false
    }

    func next() {
        if stepIndex + 1 < scenario.steps.count {
            stepIndex += 1
            hasPerformed = false
        } else if !isLastLesson {
            load(lesson: lessonIndex + 1)
        }
    }

    /// 前の手順へ。直前に見ていた結果の状態で戻る
    func back() {
        if stepIndex > 0 {
            stepIndex -= 1
        } else if lessonIndex > 0 {
            load(lesson: lessonIndex - 1, lastStep: true)
        } else {
            return
        }
        hasPerformed = step.demo != nil
    }

    /// 今のレッスンを飛ばして次のレッスンへ
    func skipLesson() {
        guard !isLastLesson else { return }
        load(lesson: lessonIndex + 1)
    }

    func jump(to lesson: Int) {
        guard scenarios.indices.contains(lesson) else { return }
        load(lesson: lesson)
    }

    private func load(lesson: Int, lastStep: Bool = false) {
        lessonIndex = lesson
        run = scenarios[lesson].run()
        stepIndex = lastStep ? scenarios[lesson].steps.count - 1 : 0
        hasPerformed = false
        reportFailures()
    }

    private func reportFailures() {
        assert(run.failures.isEmpty, "コーチモードの説明が実際の挙動と一致しません: \(run.failures)")
    }
}
