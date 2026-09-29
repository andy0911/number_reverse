import SwiftUI
import NumberOthelloCore

@main
struct NumberOthelloApp: App {
    var body: some Scene {
        WindowGroup {
            // タイトル・対局の両方に共通の背景を敷く（ガラス chrome の背後になる）
            RootView().background { ChromeBackdrop() }
        }
    }
}

struct RootView: View {
    @State private var model: GameViewModel? = RootView.debugModel()

    /// 動作確認用の起動引数: `-demo` CPU 同士の対局 / `-bombScenario` 爆弾が裏返る直前の盤面。
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
        #endif
        return nil
    }

    var body: some View {
        if let model {
            GameView(model: model) { self.model = nil }
                .id(ObjectIdentifier(model))
        } else {
            TitleView { model = GameViewModel(mode: $0) }
        }
    }
}

struct TitleView: View {
    let start: (GameMode) -> Void
    @State private var showsCoach = false

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
            Spacer()
        }
        .padding(24)
        // コーチモード（遊び方）。本編のゲーム状態とは独立
        .fullScreenCover(isPresented: $showsCoach) {
            CoachModeView { showsCoach = false }
        }
    }

    private func modeButton(_ title: String, _ mode: GameMode) -> some View {
        Button { start(mode) } label: {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
    }
}
