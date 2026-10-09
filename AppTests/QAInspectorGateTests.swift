#if MEDIATION_QA
import Testing
@testable import Tokaeshi

@Suite("Ad Inspector QAは未確認時に要求を停止")
struct QAInspectorGateTests {
    @Test("呼出し開始だけでは許可せず、SDK正常終了と画面確認の両方が必要")
    func successNeedsTwoSteps() throws {
        var gate = QAInspectorGate()
        let attemptValue = gate.begin(prerequisitesMet: true)
        let attempt = try #require(attemptValue)
        #expect(!gate.permitsRequest(prerequisitesMet: true))
        gate.complete(attempt: attempt, sdkReturnedWithoutError: true, prerequisitesMet: true)
        #expect(gate.phase == .awaitingConfirmation)
        #expect(!gate.permitsRequest(prerequisitesMet: true))
        gate.confirmVisible(prerequisitesMet: true)
        #expect(gate.permitsRequest(prerequisitesMet: true))
    }
    @Test("別の非テスト端末などSDKエラー時は許可しない")
    func sdkFailure() throws {
        var gate = QAInspectorGate()
        let attemptValue = gate.begin(prerequisitesMet: true)
        let attempt = try #require(attemptValue)
        gate.complete(attempt: attempt, sdkReturnedWithoutError: false, prerequisitesMet: true)
        gate.confirmVisible(prerequisitesMet: true)
        #expect(!gate.permitsRequest(prerequisitesMet: true))
    }
    @Test("初期化未完・設定欠落・同意未完など前提不成立時は起動しない")
    func prerequisites() {
        var gate = QAInspectorGate()
        #expect(gate.begin(prerequisitesMet: false) == nil)
        gate.confirmVisible(prerequisitesMet: true)
        #expect(!gate.permitsRequest(prerequisitesMet: true))
    }
    @Test("複数タップと二重completionで許可を進めない")
    func duplicateCalls() throws {
        var gate = QAInspectorGate()
        let attemptValue = gate.begin(prerequisitesMet: true)
        let attempt = try #require(attemptValue)
        #expect(gate.begin(prerequisitesMet: true) == nil)
        gate.complete(attempt: attempt, sdkReturnedWithoutError: true, prerequisitesMet: true)
        gate.complete(attempt: attempt, sdkReturnedWithoutError: true, prerequisitesMet: true)
        #expect(gate.phase == .awaitingConfirmation)
    }
    @Test("バックグラウンド移行・中断後の遅延completionは無効")
    func interrupted() throws {
        var gate = QAInspectorGate()
        let oldValue = gate.begin(prerequisitesMet: true)
        let old = try #require(oldValue)
        gate.invalidate()
        let currentValue = gate.begin(prerequisitesMet: true)
        let current = try #require(currentValue)
        gate.complete(attempt: old, sdkReturnedWithoutError: true, prerequisitesMet: true)
        #expect(gate.phase == .presenting)
        gate.complete(attempt: current, sdkReturnedWithoutError: false, prerequisitesMet: true)
        #expect(gate.phase == .blocked)
    }
    @Test("完了後・確認後の設定変化でも要求を停止")
    func changedSettings() throws {
        var gate = QAInspectorGate()
        let attemptValue = gate.begin(prerequisitesMet: true)
        let attempt = try #require(attemptValue)
        gate.complete(attempt: attempt, sdkReturnedWithoutError: true, prerequisitesMet: false)
        #expect(gate.phase == .blocked)
        let nextValue = gate.begin(prerequisitesMet: true)
        let next = try #require(nextValue)
        gate.complete(attempt: next, sdkReturnedWithoutError: true, prerequisitesMet: true)
        gate.confirmVisible(prerequisitesMet: true)
        #expect(!gate.permitsRequest(prerequisitesMet: false))
        gate.invalidate()
        #expect(!gate.permitsRequest(prerequisitesMet: true))
    }
}
#endif
