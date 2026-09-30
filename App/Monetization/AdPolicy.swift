import Foundation

/// 広告を出すかどうかの判定（spec §11.1）。SDK に一切依存せず、`swift test` 相当のロジックテストができる形にする。
struct AdPolicy: Sendable {
    /// 前回の表示から必要な最小間隔（秒）
    var minimumInterval: TimeInterval

    static let `default` = AdPolicy(minimumInterval: 3 * 60)

    /// - Parameters:
    ///   - finishedGameCount: 課金対象モードで `.finished` まで進んだ対局の累計数（この対局を含む）
    ///   - hasRemovedAds: 「広告を削除」購入済みか
    ///   - adLoaded: 広告の読み込みが完了しているか
    ///   - lastShownAt: 最終表示時刻。未表示なら nil（2局目以降は表示候補）
    ///   - now: 判定時刻。テストから注入できる
    /// - Returns: 広告を表示すべきか
    func shouldShowAd(finishedGameCount: Int, hasRemovedAds: Bool, adLoaded: Bool, lastShownAt: Date?, now: Date) -> Bool {
        guard !hasRemovedAds, adLoaded, finishedGameCount > 1 else { return false }
        guard let lastShownAt else { return true }
        return now.timeIntervalSince(lastShownAt) >= minimumInterval
    }
}

/// 「タイトルへ」操作が広告のカウント対象かどうか（spec §11.1）
struct AdTrigger: Sendable {
    let mode: GameModeCategory
    let isMidGameExit: Bool
    let didReachFinished: Bool

    /// カウント対象（＝広告表示の候補）になり得る操作か
    var isCountable: Bool {
        mode.isMonetized && !isMidGameExit && didReachFinished
    }
}

/// `GameMode` を Monetization 側で判定するための最小限の分類（`GameMode` 自体には依存しない）
enum GameModeCategory: Sendable {
    case twoPlayers
    case vsCPU
    case cpuOnly

    var isMonetized: Bool {
        switch self {
        case .twoPlayers, .vsCPU: true
        case .cpuOnly: false
        }
    }
}
