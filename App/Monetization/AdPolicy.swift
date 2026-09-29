import Foundation

/// 広告を出すかどうかの判定（spec §11.1）。SDK に一切依存せず、`swift test` 相当のロジックテストができる形にする。
struct AdPolicy: Sendable {
    /// 何局に 1 回、広告を出すか
    var everyNGames: Int

    static let `default` = AdPolicy(everyNGames: 3)

    /// - Parameters:
    ///   - finishedGameCount: 課金対象モードで `.finished` まで進んだ対局の累計数（この対局を含む）
    ///   - hasRemovedAds: 「広告を削除」購入済みか
    ///   - adLoaded: 広告の読み込みが完了しているか
    /// - Returns: 広告を表示すべきか
    func shouldShowAd(finishedGameCount: Int, hasRemovedAds: Bool, adLoaded: Bool) -> Bool {
        guard !hasRemovedAds, adLoaded, finishedGameCount > 0 else { return false }
        return finishedGameCount.isMultiple(of: everyNGames)
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
