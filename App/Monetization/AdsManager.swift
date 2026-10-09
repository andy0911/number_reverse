import Foundation
import UIKit
import GoogleMobileAds
import UserMessagingPlatform
import AppTrackingTransparency
import os
import UnityAds
import UnityAdapter

let adsLogger = Logger(subsystem: "jp.andygrave.tokaeshi", category: "Ads")

/// 同意取得（UMP）・広告 SDK の初期化・インタースティシャルの読み込みと表示・対局カウントを担う。spec §11.1, §11.3
@MainActor
@Observable
final class AdsManager: NSObject {
    private(set) var canRequestAds = false
    private(set) var isPrivacyOptionsRequired = false
    private(set) var isUpdatingPrivacy = false
    private(set) var privacyError: String?
    private(set) var adGeneration = 0
    private(set) var unityPersonalizationAllowed = UserDefaults.standard.bool(forKey: "ads.unityPersonalizationAllowed")
    private(set) var isSDKReady = false
    let bannerMetrics = BannerMetrics()
    #if MEDIATION_QA
    // 明示的な対局プレビューだけで使用。購入状態と本番の要求許可は変更しない。
    var isQABannerPreviewEnabled = false
    var qaBannerScenario: QABannerScenario = .liveDemo
    var qaBannerStatus = "要求前"
    var qaBannerGeometry = "未計測"
    private(set) var qaStartupAttempts = 0
    var canShowQABannerPreview: Bool {
        isQABannerPreviewEnabled && isSDKReady && !isUpdatingPrivacy
            && ConsentInformation.shared.canRequestAds
    }
    #endif
    private var sdkStarted = false
    private var startup = AdStartupRecovery()
    private var startupRetryTask: Task<Void, Never>?
    private var appliedUnityPersonalization: Bool?
    private var interstitial: InterstitialAd?
    private let policy = AdPolicy.default
    private let store: StoreManager

    /// 課金対象モードで `.finished` に達した回数。UserDefaults に永続化する（要求理由 API・PrivacyInfo.xcprivacy 参照）
    private var finishedGameCount: Int {
        get { UserDefaults.standard.integer(forKey: "monetization.finishedGameCount") }
        set { UserDefaults.standard.set(newValue, forKey: "monetization.finishedGameCount") }
    }

    /// 実際に表示を開始した時刻のみ保存する。表示失敗では更新しない。
    private var lastInterstitialShownAt: Date? {
        get { UserDefaults.standard.object(forKey: "monetization.lastInterstitialShownAt") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "monetization.lastInterstitialShownAt") }
    }

    private var isPresentingInterstitial = false

    init(store: StoreManager) {
        self.store = store
        super.init()
    }

    /// 起動・復帰・失敗後の待機終了時。重複と短時間の再試行を抑制する。
    func start() async {
        guard store.hasLoadedEntitlements, !isUpdatingPrivacy, startup.begin(at: Date()) else { return }
        startupRetryTask?.cancel()
        startupRetryTask = nil
        isUpdatingPrivacy = true
        #if MEDIATION_QA
        qaStartupAttempts += 1
        #endif
        #if DEBUG
        // 日本からは EEA 向けの同意フォームが出ないため、Debug ビルドではジオグラフィーを EEA に固定して動作確認する
        let debugSettings = DebugSettings()
        debugSettings.geography = .EEA
        let parameters = RequestParameters()
        parameters.debugSettings = debugSettings
        #else
        let parameters = RequestParameters()
        #endif

        #if DEBUG && MEDIATION_QA
        // UI統合試験専用。最初だけ通信失敗と要求不可を模擬し、次回は実UMPへ進む。
        // 許可への書換えはしない。TestFlight/通常Releaseにはこの入口を含めない。
        let injectFailure = ProcessInfo.processInfo.arguments.contains("-qaFailFirstConsent") && qaStartupAttempts == 1
        #else
        let injectFailure = false
        #endif
        defer { isUpdatingPrivacy = false; updatePrivacyRequirement() }
        let mayRequest = await AdConsentReadiness.resolve(update: {
            if injectFailure { throw URLError(.notConnectedToInternet) }
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            if ConsentInformation.shared.consentStatus == .required {
                resetUnityPersonalization()
            }
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        }, canRequest: { !injectFailure && ConsentInformation.shared.canRequestAds })

        guard mayRequest.canRequestAds else {
            // 正常に確定した拒否は再提示しない。通信等の失敗だけを復旧対象にする。
            if mayRequest.failed { startup.failed(at: Date()); scheduleStartupRetry() }
            else { startup.succeeded() }
            adsLogger.error("UMP: canRequestAds が false（consentStatus=\(ConsentInformation.shared.consentStatus.rawValue, privacy: .public)）")
            return
        }

        // ATT は UMP の後、画面がアクティブな状態で要求する（非アクティブ中に要求するとダイアログが出ずに終わる）
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            await waitUntilActive()
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }

        await resumeAdsWithCurrentPrivacy()
        if isSDKReady { startup.succeeded() }
        else { startup.failed(at: Date()); scheduleStartupRetry() }
    }

    private func scheduleStartupRetry() {
        guard let retryAt = startup.retryAt else { return }
        startupRetryTask?.cancel()
        startupRetryTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(max(0, retryAt.timeIntervalSinceNow))) }
            catch { return }
            guard let self, UIApplication.shared.applicationState == .active else { return }
            self.startupRetryTask = nil
            await self.start()
        }
    }

    private func updatePrivacyRequirement() {
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    /// UMP の「広告要求可能」はパーソナライズへの同意ではない。
    /// Unity の privacy.consent は GDPR より優先されるため、GDPR 対象/不明時は true を送らない。
    private var effectiveUnityPersonalization: Bool {
        UnityPrivacyPolicy.permitsPersonalization(
            explicitlyAllowed: unityPersonalizationAllowed,
            gdprApplies: UserDefaults.standard.object(forKey: "IABTCF_gdprApplies") as? Int,
            trackingAuthorized: ATTrackingManager.trackingAuthorizationStatus == .authorized)
    }

    private func applyUnityPrivacy() {
        let allowed = effectiveUnityPersonalization
        appliedUnityPersonalization = allowed
        let metadata = UADSMetaData()
        metadata.set("privacy.consent", value: allowed)
        metadata.commit()
    }

    private func resetUnityPersonalization() {
        unityPersonalizationAllowed = false
        UserDefaults.standard.set(false, forKey: "ads.unityPersonalizationAllowed")
    }

    private func suspendAdsForPrivacyChange() {
        canRequestAds = false
        adGeneration += 1
        interstitial = nil
    }

    private func resumeAdsWithCurrentPrivacy() async {
        applyUnityPrivacy()
        guard ConsentInformation.shared.canRequestAds else { return }
        if !sdkStarted {
            sdkStarted = true
            #if DEBUG || MEDIATION_QA
            GADMediationAdapterUnity.testMode = true
            #endif
            MobileAds.shared.requestConfiguration.maxAdContentRating = .general
            await MobileAds.shared.start()
        }
        isSDKReady = true
        // QA版の通常広告は停止。診断画面だけが端末照合後にQA専用枠を要求できる。
        guard !MonetizationConfig.isQABuild else {
            canRequestAds = false
            return
        }
        canRequestAds = true
        await loadInterstitial()
    }

    /// システム設定でATTを変更して戻った場合も、古い許可と広告を保持しない。
    func refreshPrivacyAfterActivation() async {
        guard !isUpdatingPrivacy else { return }
        if !isSDKReady {
            await start()
            return
        }
        guard appliedUnityPersonalization != effectiveUnityPersonalization else { return }
        isUpdatingPrivacy = true
        suspendAdsForPrivacyChange()
        await resumeAdsWithCurrentPrivacy()
        isUpdatingPrivacy = false
    }

    func presentPrivacyOptions() async {
        guard !isUpdatingPrivacy else { return }
        isUpdatingPrivacy = true
        privacyError = nil
        // UMP内の包括的な拒否と、以前の独立したUnity許可が矛盾しないよう再選択を必要とする。
        resetUnityPersonalization()
        suspendAdsForPrivacyChange()
        defer { isUpdatingPrivacy = false; updatePrivacyRequirement() }
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        } catch {
            privacyError = "プライバシー設定を開けませんでした。時間をおいて再度お試しください。"
        }
        await resumeAdsWithCurrentPrivacy()
    }

    func setUnityPersonalizationAllowed(_ allowed: Bool) async {
        guard !isUpdatingPrivacy else { return }
        isUpdatingPrivacy = true
        suspendAdsForPrivacyChange()
        unityPersonalizationAllowed = allowed
        UserDefaults.standard.set(allowed, forKey: "ads.unityPersonalizationAllowed")
        await resumeAdsWithCurrentPrivacy()
        isUpdatingPrivacy = false
    }

    #if DEBUG || MEDIATION_QA
    func presentAdInspector() async {
        do {
            try await MobileAds.shared.presentAdInspector(from: nil)
        } catch {
            privacyError = "広告診断を開けませんでした: \(error.localizedDescription)"
        }
    }
    #endif

    /// アプリがアクティブになるまで待つ（起動直後や UMP フォームを閉じた直後は非アクティブのことがある）
    private func waitUntilActive() async {
        guard UIApplication.shared.applicationState != .active else { return }
        for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
            return
        }
    }

    private func loadInterstitial() async {
        guard !MonetizationConfig.isQABuild, canRequestAds, !store.hasRemovedAds else { return }
        let generation = adGeneration
        do {
            let loaded = try await InterstitialAd.load(with: MonetizationConfig.interstitialAdUnitID, request: Request())
            guard generation == adGeneration, canRequestAds else { return }
            interstitial = loaded
        } catch {
            adsLogger.error("インタースティシャルの読み込みに失敗: \(error.localizedDescription, privacy: .public)")
        }
        interstitial?.fullScreenContentDelegate = self
    }

    /// 対局終了ダイアログの「タイトルへ」で呼ぶ（spec §11.1）。広告を出したら次回に備えて再読み込みする
    func handleReturnToTitle(mode: GameModeCategory, isMidGameExit: Bool, didReachFinished: Bool, from viewController: UIViewController?) {
        let trigger = AdTrigger(mode: mode, isMidGameExit: isMidGameExit, didReachFinished: didReachFinished)
        guard trigger.isCountable, !isPresentingInterstitial else { return }
        finishedGameCount += 1
        // 起動時の読み込みに失敗していた場合に備え、次回の表示機会に向けて読み直す
        if interstitial == nil {
            Task { await loadInterstitial() }
        }

        guard canRequestAds, policy.shouldShowAd(finishedGameCount: finishedGameCount, hasRemovedAds: store.hasRemovedAds, adLoaded: interstitial != nil, lastShownAt: lastInterstitialShownAt, now: Date()) else { return }
        guard let viewController, let ad = interstitial else { return }
        isPresentingInterstitial = true
        ad.present(from: viewController)
    }
}

extension AdsManager: FullScreenContentDelegate {
    nonisolated func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            lastInterstitialShownAt = Date()
        }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            isPresentingInterstitial = false
            interstitial = nil
            await loadInterstitial()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            isPresentingInterstitial = false
            interstitial = nil
            await loadInterstitial()
        }
    }
}
