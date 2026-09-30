import SwiftUI
import GoogleMobileAds

/// 小さい画面ではビューも余白も作らず、SE の盤の高さを維持する。
struct GameBannerView: View {
    let availableWidth: CGFloat
    let screenHeight: CGFloat
    @Environment(Monetization.self) private var monetization

    var body: some View {
        if screenHeight >= 850, availableWidth > 0,
           !monetization.store.hasRemovedAds, monetization.ads.canRequestAds {
            let size = largeAnchoredAdaptiveBanner(width: availableWidth)
            AdaptiveBannerView(adSize: size)
                .frame(width: size.size.width, height: size.size.height)
        }
    }
}

private struct AdaptiveBannerView: UIViewControllerRepresentable {
    let adSize: AdSize

    func makeUIViewController(context: Context) -> BannerViewController {
        BannerViewController()
    }

    func updateUIViewController(_ controller: BannerViewController, context: Context) {
        controller.load(adSize: adSize)
    }
}

private final class BannerViewController: UIViewController {
    private let banner = GoogleMobileAds.BannerView()
    private var loadedSize: CGSize?

    override func viewDidLoad() {
        super.viewDidLoad()
        banner.adUnitID = MonetizationConfig.bannerAdUnitID
        banner.rootViewController = self
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
        banner.load(Request())
    }
}
