import SwiftUI
import UIKit
import NumberOthelloCore

struct GameView: View {
    let model: GameViewModel
    let exit: () -> Void
    @Environment(Monetization.self) private var monetization

    #if MEDIATION_QA
    @State private var showBannerQA = false
    #endif

    var body: some View {
        // 小画面でも広告枠を維持。手駒は横スクロールにして44pt以上の操作領域を確保。
        GeometryReader { geometry in
            let compact = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom < 750
            VStack(spacing: compact ? 4 : 7) {
                PlayerBar(model: model, player: .second, compact: compact)
                Text(statusText)
                    .font(.headline)
                    .multilineTextAlignment(.center)
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
                    Button("タイトルへ", systemImage: "chevron.left", action: exit)
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
    }

    private var statusText: String {
        switch model.state.phase {
        case .setup(let step):
            let player = model.state.current
            let zone = step < 2 ? "赤" : "青"
            return "初期配置 2-\(step + 1)：\(player.displayName)が\(zone)マスの自陣側に数字駒を置く"
        case .playing:
            return model.isCPUThinking ? "CPU 思考中…" : "\(model.state.current.displayName)の番"
        case .awaitingBombDirection(let owner, _):
            return model.isCPUThinking ? "CPU が爆発方向を選択中…" : "\(owner.displayName)の爆弾が裏返された！爆発方向を選択"
        case .finished:
            return "ゲーム終了"
        }
    }

    @ViewBuilder private var overlay: some View {
        switch model.state.phase {
        case .finished:
            DialogCard(title: resultText, subtitle: "先行 \(model.state.score(of: .first)) − \(model.state.score(of: .second)) 後攻") {
                Button("タイトルへ", action: exitAfterResult).buttonStyle(.glassProminent)
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
