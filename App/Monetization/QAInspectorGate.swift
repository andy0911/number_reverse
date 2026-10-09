#if MEDIATION_QA
/// SDKの表示・終了成功と、人による画面確認を分離する。起動/画面をまたぐ永続化はしない。
struct QAInspectorGate {
    enum Phase: Equatable { case blocked, presenting, awaitingConfirmation, ready }
    private(set) var phase: Phase = .blocked
    private var generation = 0

    mutating func begin(prerequisitesMet: Bool) -> Int? {
        guard phase != .presenting else { return nil }
        invalidate()
        guard prerequisitesMet else { return nil }
        phase = .presenting
        return generation
    }

    mutating func complete(attempt: Int, sdkReturnedWithoutError: Bool, prerequisitesMet: Bool) {
        guard generation == attempt, phase == .presenting else { return }
        phase = sdkReturnedWithoutError && prerequisitesMet ? .awaitingConfirmation : .blocked
    }

    mutating func confirmVisible(prerequisitesMet: Bool) {
        guard phase == .awaitingConfirmation, prerequisitesMet else { invalidate(); return }
        phase = .ready
    }

    mutating func invalidate() { generation += 1; phase = .blocked }

    func permitsRequest(prerequisitesMet: Bool) -> Bool {
        phase == .ready && prerequisitesMet
    }
}
#endif
