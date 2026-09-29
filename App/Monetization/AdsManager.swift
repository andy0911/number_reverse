import Foundation
import UIKit
import GoogleMobileAds
import UserMessagingPlatform
import AppTrackingTransparency

/// 同意取得（UMP）・広告 SDK の初期化・インタースティシャルの読み込みと表示・対局カウントを担う。spec §11.1, §11.3
@MainActor
@Observable
final class AdsManager: NSObject {
    private(set) var canRequestAds = false
    private var interstitial: InterstitialAd?
    private let policy = AdPolicy.default
    private let store: StoreManager

    /// 課金対象モードで `.finished` に達した回数。UserDefaults に永続化する（要求理由 API・PrivacyInfo.xcprivacy 参照）
    private var finishedGameCount: Int {
        get { UserDefaults.standard.integer(forKey: "monetization.finishedGameCount") }
        set { UserDefaults.standard.set(newValue, forKey: "monetization.finishedGameCount") }
    }

    init(store: StoreManager) {
        self.store = store
        super.init()
    }

    /// 起動時に 1 回呼ぶ。UMP の同意フローを経てから広告 SDK を初期化する（spec §11.3）
    func start() async {
        #if DEBUG
        // 日本からは EEA 向けの同意フォームが出ないため、Debug ビルドではジオグラフィーを EEA に固定して動作確認する
        let debugSettings = DebugSettings()
        debugSettings.geography = .EEA
        let parameters = RequestParameters()
        parameters.debugSettings = debugSettings
        #else
        let parameters = RequestParameters()
        #endif

        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            // 同意フローが失敗した場合は広告を要求しない（安全側に倒す）
            return
        }

        guard ConsentInformation.shared.canRequestAds else { return }
        canRequestAds = true

        // ATT は UMP の後、画面がアクティブな状態で要求する（早すぎるとダイアログが出ない）
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }

        MobileAds.shared.requestConfiguration.maxAdContentRating = .general
        await MobileAds.shared.start()
        await loadInterstitial()
    }

    private func loadInterstitial() async {
        guard canRequestAds else { return }
        interstitial = try? await InterstitialAd.load(with: MonetizationConfig.interstitialAdUnitID, request: Request())
        interstitial?.fullScreenContentDelegate = self
    }

    /// 対局終了ダイアログの「タイトルへ」で呼ぶ（spec §11.1）。広告を出したら次回に備えて再読み込みする
    func handleReturnToTitle(mode: GameModeCategory, isMidGameExit: Bool, didReachFinished: Bool, from viewController: UIViewController?) {
        let trigger = AdTrigger(mode: mode, isMidGameExit: isMidGameExit, didReachFinished: didReachFinished)
        guard trigger.isCountable else { return }
        finishedGameCount += 1

        guard policy.shouldShowAd(finishedGameCount: finishedGameCount, hasRemovedAds: store.hasRemovedAds, adLoaded: interstitial != nil) else { return }
        guard let viewController, let ad = interstitial else { return }
        ad.present(from: viewController)
    }
}

extension AdsManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            interstitial = nil
            await loadInterstitial()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            interstitial = nil
            await loadInterstitial()
        }
    }
}
