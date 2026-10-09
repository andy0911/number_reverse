import SwiftUI
import StoreKit
import NumberOthelloCore

@main
struct NumberOthelloApp: App {
    @State private var monetization = Monetization()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            // タイトル・対局の両方に共通の背景を敷く（ガラス chrome の背後になる）
            RootView()
                .background { ChromeBackdrop() }
                .environment(monetization)
                .task { await monetization.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await monetization.ads.refreshPrivacyAfterActivation() }
                    }
                }
        }
    }
}

struct RootView: View {
    @Environment(Monetization.self) private var monetization
    @State private var model: GameViewModel? = RootView.debugModel()

    /// 動作確認用の起動引数: `-demo` CPU 同士の対局 / `-bombScenario` 爆弾が裏返る直前の盤面 /
    /// `-almostFinished` 広告カウント（spec §11.1）の確認用に、あと 1 手で終局する盤面。
    /// Debug ビルド限定（TestFlight に出す Release ビルドでは常にタイトル画面から始まる）
    private static func debugModel() -> GameViewModel? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-demo") { return GameViewModel(mode: .cpuOnly) }
        if args.contains("-bombScenario") {
            var board = Board()
            board[Position(4, 1)] = .piece(Piece(.first, .number(9)))
            board[Position(4, 2)] = .piece(Piece(.second, .bomb))
            board[Position(4, 6)] = .piece(Piece(.first, .number(3)))
            board[Position(2, 2)] = .piece(Piece(.second, .number(6)))
            board[Position(1, 2)] = .piece(Piece(.first, .number(2)))
            board[Position(2, 4)] = .piece(Piece(.first, .number(7)))
            board[Position(3, 4)] = .piece(Piece(.second, .number(5)))
            return GameViewModel(mode: .twoPlayers, state: GameState(board: board, current: .first))
        }
        if args.contains("-almostFinished") {
            var board = Board()
            for p in Board.allPositions where p != Position(3, 3) {
                board[p] = .piece(Piece(.first, .number(5)))
            }
            let state = GameState(board: board, current: .first, hands: [.first: Hand(counts: [.number(5): 1]), .second: Hand(counts: [:])])
            return GameViewModel(mode: .vsCPU(human: .first), state: state)
        }
        #endif
        return nil
    }

    var body: some View {
        if let model {
            GameView(model: model) {
                self.model = nil
                #if MEDIATION_QA
                monetization.ads.isQABannerPreviewEnabled = false
                #endif
            }
                .id(ObjectIdentifier(model))
        } else {
            TitleView { model = GameViewModel(mode: $0) }
        }
    }
}

struct TitleView: View {
    let start: (GameMode) -> Void
    @Environment(Monetization.self) private var monetization
    @State private var showsCoach = false
    @State private var showsAdPrivacy = false
    #if MEDIATION_QA && !BANNER_PREVIEW_QA
    @State private var showsQA = false
    #endif

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("トオカエシ")
                .font(.largeTitle.bold())
            Text("十返し")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("数字の合計で相手の軍を挟んで裏返せ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            modeButton("2人で対戦", .twoPlayers)
            modeButton("CPUと対戦（自分が先行）", .vsCPU(human: .first))
            modeButton("CPUと対戦（自分が後攻）", .vsCPU(human: .second))
            Button("遊び方を見る") { showsCoach = true }
                .chromeButtonStyle()
            #if MEDIATION_QA
            Button("テスト広告を表示して対局") {
                monetization.ads.qaBannerScenario = .liveDemo
                monetization.ads.isQABannerPreviewEnabled = true
                start(.twoPlayers)
            }
            .accessibilityIdentifier("qaBannerPreviewStart")
            .accessibilityValue("起動試行: \(monetization.ads.qaStartupAttempts) / SDK: \(monetization.ads.isSDKReady ? "完了" : "待機")")
            .font(.footnote)
            Text("Google公式テスト広告の見え方を確認します。購入状態は変更しません。")
                .font(.caption2)
            #if !BANNER_PREVIEW_QA
            Button("広告QA（テスト端末専用）") { showsQA = true }
                .font(.footnote)
            #endif
            Text("広告表示確認 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))")
                .font(.caption2)
            #endif
            removeAdsSection
            Button("広告のプライバシー設定") { showsAdPrivacy = true }
                .font(.footnote)
            Spacer()
        }
        .padding(24)
        #if MEDIATION_QA && !BANNER_PREVIEW_QA
        .sheet(isPresented: $showsQA) { QADiagnosticsView() }
        #endif
        .sheet(isPresented: $showsAdPrivacy) { AdPrivacyView() }
        // コーチモード（遊び方）。本編のゲーム状態とは独立
        .fullScreenCover(isPresented: $showsCoach) {
            CoachModeView { showsCoach = false }
        }
    }

    private func modeButton(_ title: String, _ mode: GameMode) -> some View {
        Button {
            #if MEDIATION_QA
            monetization.ads.isQABannerPreviewEnabled = false
            #endif
            start(mode)
        } label: {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
    }

    /// 広告を削除（非消耗型課金）と購入の復元（spec §11.2）。購入済みなら何も出さない
    @ViewBuilder private var removeAdsSection: some View {
        if !monetization.store.hasRemovedAds {
            VStack(spacing: 8) {
                Button {
                    Task { await monetization.store.purchaseRemoveAds() }
                } label: {
                    if let product = monetization.store.removeAdsProduct {
                        Text("広告を削除（\(product.displayPrice)）")
                    } else {
                        Text("広告を削除")
                    }
                }
                .chromeButtonStyle()
                .disabled(monetization.store.removeAdsProduct == nil || monetization.store.isLoading)

                Button("購入を復元") {
                    Task { await monetization.store.restore() }
                }
                .font(.footnote)
                .disabled(monetization.store.isLoading)

                if let error = monetization.store.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }
        }
    }
}
