import Foundation

/// 広告・課金の識別子。spec §11
enum MonetizationConfig {
    /// 「広告を削除」（非消耗型・買い切り）。App Store Connect 側での商品登録が必要（本 PR では未登録。実装者 TODO）
    static let removeAdsProductID = "jp.andygrave.tokaeshi.removeads"

    /// インタースティシャル広告のユニット ID。
    /// **TODO（実装者）**: 本番 ID は AdMob コンソールで発行し、Release ビルド用に差し替えること。
    /// 現在は Google 公式のテスト広告ユニット ID（自分のアカウントに無効なトラフィックとして計上されない）
    /// https://developers.google.com/admob/ios/test-ads
    static var interstitialAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/4411468910"
        #else
        return "ca-app-pub-3940256099942544/4411468910"
        #endif
    }

    /// Info.plist の GADApplicationIdentifier もテスト用サンプル ID のまま（**TODO: 本番 App ID に差し替え**）
}
