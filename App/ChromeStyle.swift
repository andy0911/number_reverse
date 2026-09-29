import SwiftUI
import NumberOthelloCore

/// chrome（プレイヤーバー・手駒の背景・ダイアログ・ボタン）の質感。
///
/// 対象は iOS 26.5 以上（project.yml の deploymentTarget）なので、Liquid Glass の API
/// （`glassEffect(_:in:)` / `GlassEffectContainer` / `.glass` / `.glassProminent`）を各 View で直接使う。
/// 盤面セル（CellView / BoardView）は可読性を最優先し、ガラスを適用しない。
extension View {
    /// 副ボタン。`.glass` を `.small` で使い、盤の縦幅を削らない（GameView 冒頭の不変条件）
    func chromeButtonStyle() -> some View {
        buttonStyle(.glass).controlSize(.small)
    }
}

/// 画面全体の背景。淡いグラデーションに、上に後攻色・下に先行色の光を薄く差す
/// （プレイヤーバーの並びに対応。ガラスの背後に色の変化を作り、質感が見えるようにする）
struct ChromeBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.backdropTop, Theme.backdropBottom], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Player.second.color.opacity(0.22), .clear], center: .top, startRadius: 0, endRadius: 360)
            RadialGradient(colors: [Player.first.color.opacity(0.22), .clear], center: .bottom, startRadius: 0, endRadius: 360)
        }
        .ignoresSafeArea()
    }
}
