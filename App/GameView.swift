import SwiftUI
import NumberOthelloCore

struct GameView: View {
    let model: GameViewModel
    let exit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
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
                Spacer()
            }
            .padding(.horizontal)
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
            DialogCard(title: "\(owner.displayName)の爆弾が爆発", subtitle: "相手の駒を盤端まですべて裏返す方向を選んでください") {
                Button("上下左右 ✚") { model.chooseBombDirection(.cross) }
                    .buttonStyle(.borderedProminent)
                Button("斜め ✕") { model.chooseBombDirection(.diagonal) }
                    .buttonStyle(.borderedProminent)
            }
        case .finished:
            DialogCard(title: resultText, subtitle: "先行 \(model.state.score(of: .first)) − \(model.state.score(of: .second)) 後攻") {
                Button("タイトルへ", action: exit).buttonStyle(.borderedProminent)
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
