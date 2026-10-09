#if MEDIATION_QA && !BANNER_PREVIEW_QA
import SwiftUI
import GoogleMobileAds
import UserMessagingPlatform
import UnityAdapter

struct QADiagnosticsView: View {
    @Environment(Monetization.self) private var monetization
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var gate = QAInspectorGate()
    @State private var showsMediation = false
    @State private var mediationStatus = "未要求"
    @State private var diagnosticMessage = "Ad Inspectorの確認前はQA広告を要求しません。"
    private let qaUnit = "ca-app-pub-5364369331405756/9486069744"

    var body: some View {
        NavigationStack {
            List {
                Section("\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "")) / 広告QA") {
                    Text("本番広告枠・全画面広告は停止しています。ATTの許可は不要です。")
                    Text("SDK初期化: \(monetization.ads.isSDKReady ? "完了" : "同意フロー待ち")")
                }
                Section("1. Googleのテスト端末判定を確認") {
                    Text("承認済みのテスト設定をGoogle SDKに指定し、Ad Inspectorを開きます。診断画面が表示されたら閉じて戻ってください。")
                    Text("これはGoogleのテスト端末判定です。端末ハッシュが一致したことの確認ではありません。")
                    Button(gate.phase == .presenting ? "Ad Inspectorの終了待ち…" : "Ad Inspectorでテスト状態を確認") {
                        Task { await verifyWithInspector() }
                    }.disabled(!sdkPrerequisites || gate.phase == .presenting)
                    Text(diagnosticMessage)
                    if gate.phase == .awaitingConfirmation {
                        Button("Ad Inspectorの画面を確認しました") {
                            gate.confirmVisible(prerequisitesMet: configuredPrerequisites)
                            diagnosticMessage = gate.phase == .ready
                                ? "Googleテスト端末判定・診断画面の確認済み。Unityテストモード有効。"
                                : "設定を確認できないため停止しました。"
                        }
                        Button("画面が表示されませんでした") { invalidate("診断画面を確認できないためQA要求は停止中です。") }
                    }
                }
                Section("2. Unityメディエーションを検証") {
                    Text("QA専用枠だけを要求します。広告はタップしないでください。")
                    Button("QAメディエーションバナーを表示") {
                        guard safeToRequest else { invalidate("テスト設定を確認できないため停止しました。"); return }
                        showsMediation = true
                    }.disabled(!safeToRequest || showsMediation)
                    if showsMediation && safeToRequest {
                        QATestBanner(unitID: qaUnit, isAllowed: { safeToRequest }) { mediationStatus = $0 }
                            .id(monetization.ads.adGeneration)
                            .frame(height: 50).allowsHitTesting(false)
                    }
                    Text(mediationStatus)
                    Text("配信元にUnityが表示されればUnity経由の受信成功です。Googleだけの場合はUnity成功とは判定しません。")
                }
            }
            .navigationTitle("広告QA")
            .toolbar { Button("閉じる") { invalidate("QAを終了しました。"); dismiss() } }
            .interactiveDismissDisabled(gate.phase == .presenting)
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { invalidate("アプリが中断されたためQA要求を停止しました。") }
            }
            .onChange(of: monetization.ads.adGeneration) { _, _ in
                invalidate("プライバシー設定が変わったため再確認が必要です。")
            }
        }
    }

    private var approvedHash: String? {
        guard let url = Bundle.main.url(forResource: "QATestDevice", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
              let value = dict["testDeviceHash"],
              value.range(of: "^[a-fA-F0-9]{32}$", options: .regularExpression) != nil else { return nil }
        return value.lowercased()
    }

    private var sdkPrerequisites: Bool {
        monetization.ads.isSDKReady && !monetization.ads.isUpdatingPrivacy
            && ConsentInformation.shared.canRequestAds && scenePhase == .active
            && UIApplication.shared.applicationState == .active && approvedHash != nil
    }

    private var configuredPrerequisites: Bool {
        guard sdkPrerequisites, let approvedHash, GADMediationAdapterUnity.testMode else { return false }
        return MobileAds.shared.requestConfiguration.testDeviceIdentifiers == [approvedHash]
    }

    private var safeToRequest: Bool { gate.permitsRequest(prerequisitesMet: configuredPrerequisites) }

    private func invalidate(_ message: String) {
        gate.invalidate()
        showsMediation = false
        diagnosticMessage = message
    }

    private func verifyWithInspector() async {
        guard gate.phase != .presenting, sdkPrerequisites, let approvedHash,
              let presenter = UIViewController.topMost(), presenter.viewIfLoaded?.window != nil,
              !presenter.isBeingPresented, !presenter.isBeingDismissed else { return }
        showsMediation = false
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [approvedHash]
        GADMediationAdapterUnity.testMode = true
        guard let attempt = gate.begin(prerequisitesMet: configuredPrerequisites) else { return }
        diagnosticMessage = "診断画面を表示中です。表示を確認して閉じてください。"
        do {
            // SDKの仕様: async完了はInspectorが閉じた時。単なる呼出し開始で許可しない。
            // 表示に問題がある場合はthrow。正常終了後にも画面の確認を必要とする。
            try await MobileAds.shared.presentAdInspector(from: presenter)
            gate.complete(attempt: attempt, sdkReturnedWithoutError: true,
                          prerequisitesMet: configuredPrerequisites)
            if gate.phase == .awaitingConfirmation {
                diagnosticMessage = "SDKから正常終了が返りました。Ad Inspectorの画面を実際に確認できましたか？"
            }
        } catch {
            gate.complete(attempt: attempt, sdkReturnedWithoutError: false, prerequisitesMet: false)
            let nsError = error as NSError
            diagnosticMessage = "Ad Inspectorを確認できませんでした（コード \(nsError.code)）。QA要求は停止中です。"
        }
    }
}

private struct QATestBanner: UIViewRepresentable {
    let unitID: String
    let isAllowed: () -> Bool
    let onStatus: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onStatus: onStatus) }
    func makeUIView(context: Context) -> GoogleMobileAds.BannerView {
        let banner = GoogleMobileAds.BannerView(adSize: AdSizeBanner)
        banner.adUnitID = unitID
        banner.rootViewController = UIViewController.topMost()
        banner.delegate = context.coordinator
        if isAllowed() { banner.load(Request()) }
        return banner
    }
    func updateUIView(_ view: GoogleMobileAds.BannerView, context: Context) {}
    static func dismantleUIView(_ view: GoogleMobileAds.BannerView, coordinator: Coordinator) {
        view.delegate = nil
        view.removeFromSuperview()
    }
    final class Coordinator: NSObject, BannerViewDelegate {
        let onStatus: (String) -> Void
        init(onStatus: @escaping (String) -> Void) { self.onStatus = onStatus }
        func bannerViewDidReceiveAd(_ bannerView: GoogleMobileAds.BannerView) {
            let network = bannerView.responseInfo?.loadedAdNetworkResponseInfo?.adNetworkClassName ?? "不明"
            onStatus("受信済み / 配信元: \(network)")
        }
        func bannerView(_ bannerView: GoogleMobileAds.BannerView, didFailToReceiveAdWithError error: Error) {
            onStatus("取得失敗: \(error.localizedDescription)")
        }
    }
}
#endif
