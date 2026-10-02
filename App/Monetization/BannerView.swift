import SwiftUI
import GoogleMobileAds

/// 対局画面のバナー枠。小さい画面ではビューも余白も作らず、SE の盤の高さを維持する。
/// AdMob の広告が届かない間（同意前・在庫なし・読み込み失敗）は同じ枠に「広告を削除」の自社バナーを出し、
/// 枠を常に埋めて広告削除の訴求ができるようにする。
struct GameBannerView: View {
    let availableWidth: CGFloat
    let screenHeight: CGFloat
    @Environment(Monetization.self) private var monetization
    @State private var adLoaded = false

    var body: some View {
        if screenHeight >= 850, availableWidth > 0, !monetization.store.hasRemovedAds {
            let size = largeAnchoredAdaptiveBanner(width: availableWidth)
            ZStack {
                if !adLoaded {
                    RemoveAdsPromoBanner()
                }
                if monetization.ads.canRequestAds {
                    AdaptiveBannerView(adSize: size) { adLoaded = $0 }
                        .opacity(adLoaded ? 1 : 0)
                        .allowsHitTesting(adLoaded)
                }
            }
            .frame(width: size.size.width, height: size.size.height)
        }
    }
}

/// AdMob の広告が出せないときに表示する自社バナー。タップで「広告を削除」を購入する
private struct RemoveAdsPromoBanner: View {
    @Environment(Monetization.self) private var monetization

    var body: some View {
        Button {
            Task { await monetization.store.purchaseRemoveAds() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "nosign")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("広告を削除")
                        .font(.headline)
                    Text("買い切りで、対局中のバナーと全画面広告をすべて非表示にします")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if let product = monetization.store.removeAdsProduct {
                    Text(product.displayPrice)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.tint, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(monetization.store.removeAdsProduct == nil || monetization.store.isLoading)
    }
}

private struct AdaptiveBannerView: UIViewControllerRepresentable {
    let adSize: AdSize
    let onLoadChange: (Bool) -> Void

    func makeUIViewController(context: Context) -> BannerViewController {
        BannerViewController()
    }

    func updateUIViewController(_ controller: BannerViewController, context: Context) {
        controller.onLoadChange = onLoadChange
        controller.load(adSize: adSize)
    }
}

private final class BannerViewController: UIViewController {
    /// 読み込みに失敗したときに再要求するまでの秒数（在庫切れ・通信断からの復帰用）
    private static let retryDelay: Duration = .seconds(30)

    private let banner = GoogleMobileAds.BannerView()
    private var loadedSize: CGSize?
    private var retryTask: Task<Void, Never>?
    var onLoadChange: ((Bool) -> Void)?

    deinit {
        retryTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        banner.adUnitID = MonetizationConfig.bannerAdUnitID
        banner.rootViewController = self
        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            banner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    func load(adSize: AdSize) {
        loadViewIfNeeded()
        // SwiftUI の再描画では再要求せず、利用可能な幅が変わったときだけ読み直す。
        guard loadedSize != adSize.size else { return }
        loadedSize = adSize.size
        banner.adSize = adSize
        requestAd()
    }

    private func requestAd() {
        retryTask?.cancel()
        banner.load(Request())
    }
}

extension BannerViewController: BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: GoogleMobileAds.BannerView) {
        onLoadChange?(true)
    }

    func bannerView(_ bannerView: GoogleMobileAds.BannerView, didFailToReceiveAdWithError error: Error) {
        adsLogger.error("バナーの読み込みに失敗: \(error.localizedDescription, privacy: .public)")
        onLoadChange?(false)
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: Self.retryDelay)
            guard !Task.isCancelled else { return }
            self?.requestAd()
        }
    }
}
