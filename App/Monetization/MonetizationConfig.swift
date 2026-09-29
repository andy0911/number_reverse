import Foundation

/// 広告・課金の識別子。spec §11
enum MonetizationConfig {
    /// 「広告を削除」（非消耗型・買い切り）。App Store Connect に登録済み（Apple ID 6817246790、¥300）
    static let removeAdsProductID = "jp.andygrave.tokaeshi.removeads"

    /// インタースティシャル広告のユニット ID。
    /// Debug では Google 公式のテスト用 ID を使う（開発中に本番 ID の広告を表示・タップすると
    /// 無効なトラフィックとしてアカウントが停止され得るため）。https://developers.google.com/admob/ios/test-ads
    /// Release（TestFlight・App Store）では AdMob コンソールで発行した本番 ID を使う
    #if DEBUG
    static let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    #else
    static let interstitialAdUnitID = "ca-app-pub-5364369331405756/1465124825"
    #endif
}
