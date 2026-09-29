import SwiftUI
import NumberOthelloCore

struct GameView: View {
    let model: GameViewModel
    let exit: () -> Void

    var body: some View {
        // 不変条件: SE（375×667pt）で盤の高さを、ガラス chrome 導入前（328pt）から削らない（実測 327.5pt）。
        // 盤は高さに制約のある端末では残りの高さいっぱいに縮むため、ガラス chrome で増えた余白
        // （HandPicker の padding と「タイトルへ」ボタンの高さ・下の余白）を、要素間隔（導入前は 12pt）を詰めて相殺している。
        // これらの値を変えるときは SE 相当の画面で盤の高さを測り直すこと
        VStack(spacing: 7) {
            PlayerBar(model: model, player: .second)
            Text(statusText)
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(minHeight: 44)
            BoardView(model: model)
            if let message = model.message {
                Text(message).font(.footnote).foregroundStyle(.red)
            }
            HandPicker(model: model)
            PlayerBar(model: model, player: .first)
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
            }
            .padding(.horizontal)
            // ガラスのボタンの影が直下のプレイヤーバーに重ならないための余白（高さは上の VStack の間隔で相殺している）
            .padding(.bottom, 4)
        }
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
        case .awaitingBombDirection(let owner, _) where model.isHumanTurn:
            DialogCard(title: "\(owner.displayName)の爆弾が爆発", subtitle: "各方向、最初に見つかった相手の駒（最大4枚）を裏返す方向を選んでください") {
                Button("上下左右 ✚") { model.chooseBombDirection(.cross) }
                    .buttonStyle(.glassProminent)
                Button("斜め ✕") { model.chooseBombDirection(.diagonal) }
                    .buttonStyle(.glassProminent)
            }
        case .finished:
            DialogCard(title: resultText, subtitle: "先行 \(model.state.score(of: .first)) − \(model.state.score(of: .second)) 後攻") {
                Button("タイトルへ", action: exit).buttonStyle(.glassProminent)
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
}
