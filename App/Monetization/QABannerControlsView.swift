#if MEDIATION_QA
import SwiftUI

struct QABannerControlsView: View {
    @Environment(Monetization.self) private var monetization
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("表示条件の確認") {
                    ForEach(QABannerScenario.allCases) { scenario in
                        Button(scenario.rawValue) {
                            monetization.ads.qaBannerScenario = scenario
                            monetization.ads.qaBannerStatus = scenario.removesAds ? "購入済み条件・枠非表示" : "切替中"
                            dismiss()
                        }.accessibilityIdentifier("qaScenario_\(String(describing: scenario))")
                    }
                    Text("模擬条件はQA画面だけに適用します。購入・同意・ネットワークの設定自体は変更しません。実際の購入済み状態は優先し、広告枠を表示しません。")
                }
                Section("状態") {
                    Text("ビルド: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")")
                    Text(monetization.ads.qaBannerGeometry)
                    Text("条件: \(monetization.ads.qaBannerScenario.rawValue)")
                    Text("状態: \(monetization.store.hasRemovedAds ? "購入済み・枠非表示" : monetization.ads.qaBannerStatus)")
                    Text("起動試行: \(monetization.ads.qaStartupAttempts)")
                    Text("SDK準備: \(monetization.ads.isSDKReady ? "完了" : "待機")")
                    Text("実所有権: \(monetization.store.hasRemovedAds ? "購入済み" : "未購入") / 照合: \(monetization.store.hasLoadedEntitlements ? "完了" : "待機")")
                    Text("自社案内: \(monetization.ads.bannerMetrics.localPromos) / テスト広告impression: \(monetization.ads.bannerMetrics.demoImpressions)")
                    Text("本番広告impression: \(monetization.ads.bannerMetrics.networkImpressions) / 本番paidイベント: \(monetization.ads.bannerMetrics.paidEvents)")
                }
            }.navigationTitle("テスト広告の状態")
            .toolbar { Button("閉じる") { dismiss() } }
        }
    }
}
#endif
