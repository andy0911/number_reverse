import Foundation

/// 広告・課金の識別子。spec §11
enum MonetizationConfig {
    static var isQABuild: Bool {
        #if MEDIATION_QA
        true
        #else
        false
        #endif
    }

    /// 「広告を削除」（非消耗型・買い切り）。App Store Connect に登録済み（Apple ID 6817246790、¥300）
    static let removeAdsProductID = "jp.andygrave.tokaeshi.removeads"

    /// 明示起動時だけアカウントのマッピングを検証。実機Debugは常にGoogleテストID。
    /// SimulatorはGoogleが自動でテスト端末扱いし、UnityはAdsManagerでtestMode=true。
    static var isMediationTest: Bool {
        #if DEBUG && targetEnvironment(simulator)
        ProcessInfo.processInfo.arguments.contains("-mediationTest")
        #else
        false
        #endif
    }

    /// インタースティシャル広告のユニット ID。
    /// Debug では Google 公式のテスト用 ID を使う（開発中に本番 ID の広告を表示・タップすると
    /// 無効なトラフィックとしてアカウントが停止され得るため）。https://developers.google.com/admob/ios/test-ads
    /// Release（TestFlight・App Store）では AdMob コンソールで発行した本番 ID を使う
    #if MEDIATION_QA
    static let previewFixedBannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"
    static let previewBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let interstitialAdUnitID = "" // QAでは全画面要求を禁止
    #elseif DEBUG
    static var interstitialAdUnitID: String { isMediationTest ? "ca-app-pub-5364369331405756/1465124825" : "ca-app-pub-3940256099942544/4411468910" }
    #else
    static let interstitialAdUnitID = "ca-app-pub-5364369331405756/1465124825"
    #endif

    /// 対局画面のバナー広告。Debug では Google 公式テスト ID を使う。
    #if MEDIATION_QA
    static let bannerAdUnitID = "" // 通常画面は要求禁止。QA専用画面だけが照合後に専用枠を要求する
    #elseif DEBUG
    static var bannerAdUnitID: String { isMediationTest ? "ca-app-pub-5364369331405756/8224074481" : "ca-app-pub-3940256099942544/2435281174" }
    #else
    static let bannerAdUnitID = "ca-app-pub-5364369331405756/8224074481"
    #endif
}
