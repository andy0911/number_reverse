import Foundation

/// 広告・課金の識別子。spec §11
enum MonetizationConfig {
    /// 「広告を削除」（非消耗型・買い切り）。App Store Connect 側での商品登録が必要（未登録。実装者 TODO）
    static let removeAdsProductID = "jp.andygrave.tokaeshi.removeads"

    /// インタースティシャル広告のユニット ID。現在は Google 公式のテスト用 ID
    /// （自分のアカウントに無効なトラフィックとして計上されない）。https://developers.google.com/admob/ios/test-ads
    /// **TODO（実装者）**: 公開前に AdMob コンソールで発行した本番 ID に差し替えること。
    /// Info.plist の GADApplicationIdentifier（project.yml の info.properties）もテスト用サンプル ID のまま
    static let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
}
