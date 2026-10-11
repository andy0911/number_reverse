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
                // ブランドの緑（白文字が 5:1 以上）。ボタン・リンクの強調色をシステム青から差し替える
                .tint(Theme.brandTint)
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
