import SwiftUI

struct AdPrivacyView: View {
    @Environment(Monetization.self) private var monetization
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Googleなどの広告パートナー") {
                    if monetization.ads.isPrivacyOptionsRequired {
                        Button("同意の確認・変更") {
                            Task { await monetization.ads.presentPrivacyOptions() }
                        }
                    } else {
                        Text("この地域では、現在Googleの同意変更フォームは提供されていません。")
                    }
                }
                Section("Unity Ads") {
                    Toggle("個人情報の販売・共有による広告のパーソナライズを許可", isOn: Binding(
                        get: { monetization.ads.unityPersonalizationAllowed },
                        set: { allowed in Task { await monetization.ads.setUnityPersonalizationAllowed(allowed) } }
                    ))
                    Text("初期設定はオフです。オフの間はUnityに個人情報の販売・共有とターゲティングを拒否する情報を送ります。広告そのものは表示されます。")
                        .font(.footnote)
                    Text("Googleの同意を変更すると、この設定もオフに戻ります。オンにしても、端末のトラッキング許可がない場合や、欧州の同意規制の対象・地域の判定ができない場合は許可を送りません。")
                        .font(.footnote)
                }
                Section {
                    Link("プライバシーポリシー", destination: URL(string: "https://andy0911.github.io/tokaeshi/privacy.html")!)
                    if let error = monetization.ads.privacyError {
                        Text(error).foregroundStyle(.red)
                    }
                }
                #if DEBUG
                Section("開発用") {
                    Button("Ad Inspectorを開く") {
                        Task { await monetization.ads.presentAdInspector() }
                    }
                }
                #endif
            }
            .disabled(monetization.ads.isUpdatingPrivacy)
            .navigationTitle("広告のプライバシー")
            .toolbar { Button("閉じる") { dismiss() } }
        }
    }
}
