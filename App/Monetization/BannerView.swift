import SwiftUI
import GoogleMobileAds

/// 未購入者の広告枠。広告未取得時はローカルの購入案内を表示する。
struct GameBannerView: View {
    let availableWidth: CGFloat
    let screenHeight: CGFloat
    @Environment(Monetization.self) private var monetization
    private var isPreview: Bool {
        #if MEDIATION_QA
        monetization.ads.isQABannerPreviewEnabled
        #else
        false
        #endif
    }
    private var showsSlot: Bool {
        #if MEDIATION_QA
        if isPreview {
            // 模擬所有権はQA入口内だけ。実際の購入状態は書き換えない。
            return monetization.store.hasLoadedEntitlements && !monetization.store.hasRemovedAds && !monetization.ads.qaBannerScenario.removesAds
        }
        #endif
        return BannerVisibility.showsSlot(entitlementsLoaded: monetization.store.hasLoadedEntitlements,
                                          hasRemovedAds: monetization.store.hasRemovedAds)
    }
    private var canLoad: Bool {
        #if MEDIATION_QA
        if isPreview { return monetization.ads.qaBannerScenario.allowsRequest && monetization.ads.canShowQABannerPreview }
        #endif
        return monetization.ads.canRequestAds
    }
    private var unitID: String {
        #if MEDIATION_QA
        if isPreview { return screenHeight < 850 ? MonetizationConfig.previewFixedBannerAdUnitID : MonetizationConfig.previewBannerAdUnitID }
        #endif
        return MonetizationConfig.bannerAdUnitID
    }
    private var scenarioKey: String {
        #if MEDIATION_QA
        isPreview ? monetization.ads.qaBannerScenario.rawValue : ""
        #else
        ""
        #endif
    }
    private var simulatedFailure: String? {
        #if MEDIATION_QA
        if isPreview { return monetization.ads.qaBannerScenario.simulatedFailure }
        #endif
        return nil
    }
    var body: some View {
        if showsSlot, availableWidth > 0 {
            // 小画面はGoogle/Unity対応の320×50、大画面は従来のlarge adaptive。
            let size = screenHeight < 850
                ? AdSizeBanner
                : largeAnchoredAdaptiveBanner(width: availableWidth)
            BannerSlotView(size: size, canLoad: canLoad, unitID: unitID, isPreview: isPreview,
                           simulatedFailure: simulatedFailure)
                // 世代・幅・要求許可の変化で古いSDKビュー/状態/リトライを同時に破棄する。
                .id("\(monetization.ads.adGeneration)-\(canLoad)-\(size.size)-\(unitID)-\(scenarioKey)")
                #if MEDIATION_QA
                .onAppear { monetization.ads.qaBannerGeometry = "画面高: \(Int(screenHeight))pt / 広告枠: \(Int(size.size.width)) × \(Int(size.size.height))pt" }
                #endif
        }
    }
}

private struct BannerSlotView: View {
    let size: AdSize
    let canLoad: Bool
    let unitID: String
    let isPreview: Bool
    let simulatedFailure: String?
    @Environment(Monetization.self) private var monetization
    @State private var presentation = BannerPresentation()
    private var isTestTraffic: Bool {
        #if DEBUG || MEDIATION_QA
        true
        #else
        false
        #endif
    }

    var body: some View {
        ZStack {
            if !canLoad || !presentation.showsAd {
                RemoveAdsPromoBanner(isPreview: isPreview, compact: size.size.height < 90)
                    .onAppear { monetization.ads.bannerMetrics.promo() }
            }
            if canLoad, presentation.phase != .stopped {
                AdaptiveBannerView(adSize: size, unitID: unitID,
                                   simulatedFailure: simulatedFailure,
                                   received: { presentation.receive() },
                                   failed: { presentation.fail($0) },
                                   impression: { monetization.ads.bannerMetrics.impression(isDemo: isTestTraffic) },
                                   paid: { monetization.ads.bannerMetrics.paid(isDemo: isTestTraffic) })
                    // 透明化・失敗時の削除はSDK自動更新を止めるため、空のSDKビューも可視のまま保持する。
                    .allowsHitTesting(presentation.showsAd && !isPreview)
            }
        }
        .frame(width: size.size.width, height: size.size.height)
        .accessibilityElement(children: .contain)
        #if MEDIATION_QA
        .accessibilityIdentifier(isPreview ? "qaPreviewBannerContainer" : "gameBannerContainer")
        #else
        .accessibilityIdentifier("gameBannerContainer")
        #endif
        .accessibilityValue(presentation.showsAd && canLoad ? "loaded" : "local-promo")
        .task(id: presentation.phase) {
            #if MEDIATION_QA
            if isPreview {
                monetization.ads.qaBannerStatus = !canLoad ? "要求停止・自社案内" :
                    (presentation.showsAd ? "受信済み" : presentation.failure ?? "読み込み中・自社案内")
            }
            #endif
            // AdMobで設定されたSDK自動更新に一任する。手動再要求は重ねない。
        }
        .onAppear { presentation.restartIfStopped() }
        .onDisappear { presentation.stop() }
    }
}

private struct RemoveAdsPromoBanner: View {
    let isPreview: Bool
    let compact: Bool
    @Environment(Monetization.self) private var monetization
    var body: some View {
        Button {
            guard !isPreview else { return }
            Task { await monetization.store.purchaseRemoveAds() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "nosign").font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("広告を削除").font(.subheadline.bold())
                    Text("買い切りで、対局中のバナーと全画面広告をすべて非表示にします")
                        .font(compact ? .system(size: 10) : .caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if let product = monetization.store.removeAdsProduct {
                    Text(product.displayPrice).font(.caption.bold())
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(monetization.store.removeAdsProduct == nil || monetization.store.isLoading)
        .allowsHitTesting(!isPreview)
        .accessibilityIdentifier("localRemoveAdsPromo")
    }
}

private struct AdaptiveBannerView: UIViewControllerRepresentable {
    let adSize: AdSize
    let unitID: String
    let simulatedFailure: String?
    let received: () -> Void
    let failed: (String) -> Void
    let impression: () -> Void
    let paid: () -> Void
    func makeUIViewController(context: Context) -> BannerViewController { BannerViewController(unitID: unitID) }
    func updateUIViewController(_ controller: BannerViewController, context: Context) {
        controller.received = received
        controller.failed = failed
        controller.impression = impression
        controller.paid = paid
        controller.load(adSize: adSize, simulatedFailure: simulatedFailure)
    }
    static func dismantleUIViewController(_ controller: BannerViewController, coordinator: ()) { controller.stop() }
}

private final class BannerViewController: UIViewController, BannerViewDelegate {
    private var banner: GoogleMobileAds.BannerView?
    private let unitID: String
    private var started = false
    private var active = true
    var received: (() -> Void)?
    var failed: ((String) -> Void)?
    var impression: (() -> Void)?
    var paid: (() -> Void)?
    init(unitID: String) { self.unitID = unitID; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func load(adSize: AdSize, simulatedFailure: String?) {
        guard !started, active else { return }
        started = true
        #if MEDIATION_QA
        if let simulatedFailure {
            Task { @MainActor [weak self] in
                guard let self, self.active else { return }
                self.failed?(simulatedFailure)
                if simulatedFailure == QABannerScenario.recovering.simulatedFailure {
                    do { try await Task.sleep(for: .seconds(5)) } catch { return }
                    guard self.active else { return }
                    // 失敗時に同じcontrollerが保持されることを確認。通信は公式デモへの初回要求だけ。
                    self.loadSDKBanner(adSize: adSize)
                }
            }
            return
        }
        #endif
        loadSDKBanner(adSize: adSize)
    }
    private func loadSDKBanner(adSize: AdSize) {
        guard active else { return }
        loadViewIfNeeded()
        let banner = GoogleMobileAds.BannerView(adSize: adSize)
        self.banner = banner
        banner.adUnitID = unitID
        banner.rootViewController = self
        banner.delegate = self
        banner.paidEventHandler = { [weak self] _ in
            guard let self, self.active else { return }; self.paid?()
        }
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            banner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        banner.load(Request())
    }
    func stop() {
        active = false
        banner?.delegate = nil
        banner?.paidEventHandler = nil
        banner?.removeFromSuperview()
        banner = nil
        received = nil; failed = nil; impression = nil; paid = nil
    }
    func bannerViewDidReceiveAd(_ bannerView: GoogleMobileAds.BannerView) {
        guard active else { return }; received?()
    }
    func bannerView(_ bannerView: GoogleMobileAds.BannerView, didFailToReceiveAdWithError error: Error) {
        guard active else { return }
        let failure = error as NSError
        adsLogger.error("banner_load_failed domain=\(failure.domain, privacy: .public) code=\(failure.code)")
        failed?("\(failure.domain) / \(failure.code): \(failure.localizedDescription)")
    }
    func bannerViewDidRecordImpression(_ bannerView: GoogleMobileAds.BannerView) {
        guard active else { return }; impression?()
    }
}
