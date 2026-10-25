import SwiftUI
import UIKit
import NumberOthelloCore

struct GameView: View {
    let model: GameViewModel
    let exit: () -> Void
    @Environment(Monetization.self) private var monetization

    /// 対局終了後に結果ダイアログを閉じて最終盤面を見ている状態（感想戦）
    @State private var isReviewing = false

    #if MEDIATION_QA
    @State private var showBannerQA = false
    #endif

    var body: some View {
        // 小画面でも広告枠を維持。手駒は横スクロールにして44pt以上の操作領域を確保。
        GeometryReader { geometry in
            let compact = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom < 750
            VStack(spacing: compact ? 4 : 7) {
                PlayerBar(model: model, player: .second, compact: compact)
                statusLine
                    .frame(minHeight: 44)
                BoardView(model: model)
                    #if MEDIATION_QA
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("qaGameBoard")
                    #endif
                if let message = model.message {
                    Text(message).font(.footnote).foregroundStyle(.red)
                }
                if case .awaitingBombDirection(let owner, _) = model.state.phase {
                    BombDirectionPicker(model: model, owner: owner)
                } else if isReviewing {
                    ReviewBar(showResult: { isReviewing = false }, backToTitle: exitAfterResult)
                } else {
                    HandPicker(model: model, compact: compact)
                }
                PlayerBar(model: model, player: .first, compact: compact)
                GameBannerView(
                    availableWidth: max(0, geometry.size.width - 24),
                    screenHeight: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
                )
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .overlay { overlay }
            .safeAreaInset(edge: .top) {
                HStack {
                    Button("タイトルへ", systemImage: "chevron.left", action: model.state.phase == .finished ? exitAfterResult : exit)
                        .labelStyle(.titleAndIcon)
                        .chromeButtonStyle()
                    Spacer()
                    #if MEDIATION_QA
                    if monetization.ads.isQABannerPreviewEnabled {
                        Button { showBannerQA = true } label: {
                            Text("テスト広告プレビュー")
                                .font(.caption.bold())
                                .accessibilityIdentifier("qaBannerPreviewBadge")
                        }.accessibilityIdentifier("qaBannerStatus")
                    }
                    #endif
                }
                .padding(.horizontal)
                // ガラスのボタンの影が直下のプレイヤーバーに重ならないための余白（高さは上の VStack の間隔で相殺している）
                .padding(.bottom, 4)
            }
        }
        #if MEDIATION_QA
        .sheet(isPresented: $showBannerQA) { QABannerControlsView() }
        #endif
        // 置いた瞬間の手応え（人間・CPU どちらの手でも）
        .sensoryFeedback(.impact(weight: .medium), trigger: model.lastPlaced)
        // 勝敗が決まった瞬間に 1 回だけ（結果カードへ戻るたびには鳴らさない）
        .sensoryFeedback(.success, trigger: model.state.phase == .finished) { _, finished in
            finished && model.state.outcome != .draw
        }
    }

    /// 手番の駒と文言。駒の色で誰の番かを一目で示す（高さは文言のみのときと同じ）
    private var statusLine: some View {
        HStack(spacing: 8) {
            if let player = model.actingPlayer {
                ChipDot(owner: player).frame(width: 20, height: 20)
            }
            VStack(spacing: 2) {
                Text(statusText)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                // 初期配置が終わった直後だけ、本戦の核（spec §5.1: 挟んだ自軍の合計が挟まれた相手軍の合計より大きいと返せる）を 1 行で伝える
                if model.showsMainPhaseNotice, case .playing = model.state.phase {
                    Text("ここから本戦。挟んだ自分の駒の合計が、相手の駒の合計より大きいと返せます")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: statusText)
    }

    private var statusText: String {
        switch model.state.phase {
        case .setup(let step):
            let player = model.state.current
            let zone = step < 2 ? "赤" : "青"
            return "初期配置 6手中\(step + 1)手目：\(player.displayName)が自分の側の\(zone)いマスに数字駒を置く"
        case .playing:
            return model.isCPUThinking ? "CPU 思考中…" : "\(model.state.current.displayName)の番"
        case .awaitingBombDirection(let owner, _):
            return model.isCPUThinking ? "CPU が爆発方向を選択中…" : "\(owner.displayName)の爆弾が裏返された！爆発方向を選択"
        case .finished:
            return "\(resultText)　先行 \(model.state.score(of: .first)) − \(model.state.score(of: .second)) 後攻"
        }
    }

    @ViewBuilder private var overlay: some View {
        switch model.state.phase {
        case .finished where !isReviewing:
            ResultCard(
                outcome: model.state.outcome,
                firstScore: model.state.score(of: .first),
                secondScore: model.state.score(of: .second)
            ) {
                Button(action: { isReviewing = true }) {
                    Text("盤面を見る").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                Button(action: exitAfterResult) {
                    Text("タイトルへ").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
            }
        default:
            EmptyView()
        }
    }

    private var resultText: String {
        switch model.state.outcome {
        case .win(let p): "\(p.displayName)の勝ち！"
        case .draw: "引き分け"
        case nil: ""
        }
    }

    /// 対局終了ダイアログの「タイトルへ」。ここだけが広告のカウント対象（spec §11.1）
    private func exitAfterResult() {
        monetization.ads.handleReturnToTitle(
            mode: model.mode.monetizationCategory,
            isMidGameExit: false,
            didReachFinished: true,
            from: UIViewController.topMost()
        )
        exit()
    }
}

/// 感想戦中に手駒ピッカーの位置へ出す操作バー（結果文は上部の statusText が持つ）
private struct ReviewBar: View {
    let showResult: () -> Void
    let backToTitle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("感想戦中（盤面を確認できます）")
                .font(.caption)
                .foregroundStyle(.secondary)
            GlassEffectContainer {
                HStack(spacing: 12) {
                    Button(action: showResult) {
                        Text("結果を表示").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glass)
                    Button(action: backToTitle) {
                        Text("タイトルへ").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .controlSize(.large)
        }
    }
}
