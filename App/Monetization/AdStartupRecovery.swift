import Foundation

/// 再接続や前面復帰が重なっても、同じ起動処理を重複・連打しない。
struct AdStartupRecovery {
    private(set) var isRunning = false
    private(set) var isComplete = false
    private(set) var retryAt: Date?
    private var failures = 0

    mutating func begin(at now: Date) -> Bool {
        guard !isRunning, !isComplete, retryAt.map({ now >= $0 }) ?? true else { return false }
        isRunning = true
        return true
    }
    mutating func failed(at now: Date) {
        isRunning = false
        failures += 1
        let delay = min(300.0, 30.0 * pow(2.0, Double(min(failures - 1, 4))))
        retryAt = now.addingTimeInterval(delay)
    }
    mutating func succeeded() {
        isRunning = false
        isComplete = true
        retryAt = nil
    }
}

@MainActor enum AdConsentReadiness {
    struct Result { let canRequestAds: Bool; let failed: Bool }
    /// 自前の保存値ではなく、失敗時もUMPが判断する前回セッションの許可を確認する。
    static func resolve(update: () async throws -> Void, canRequest: () -> Bool) async -> Result {
        var failed = false
        do { try await update() }
        catch { failed = true; adsLogger.error("UMP の同意フローに失敗: \(error.localizedDescription, privacy: .public)") }
        return Result(canRequestAds: canRequest(), failed: failed)
    }
}
