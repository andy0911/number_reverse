import SwiftUI
import NumberOthelloCore

/// chrome（プレイヤーバー・手駒の背景・ダイアログ・ボタン）の質感ヘルパー。
///
/// Liquid Glass は SDK（iPhoneSimulator27.0.sdk）の SwiftUI インターフェースで宣言を確認した
/// `glassEffect(_:in:)` / `GlassEffectContainer` / `.glass` / `.glassProminent`（いずれも iOS 26.0 以降）を使う。
/// iOS 17〜25 では Liquid Glass が無いため、背景は `.regularMaterial`、主ボタンは `.borderedProminent` に、
/// 副ボタンは既定のスタイルのままにフォールバックする（GlassEffectContainer は素通し）。
/// 盤面セル（CellView / BoardView）は可読性を最優先し、ここのスタイルを適用しない。
extension View {
    /// ガラス背景。iOS 26 以降は Liquid Glass（`.regular`）、それ未満は `.regularMaterial`
    @ViewBuilder
    func chromeGlass(in shape: some Shape) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
        }
    }

    /// 主ボタン。iOS 26 以降は `.glassProminent`、それ未満は `.borderedProminent`
    @ViewBuilder
    func chromeProminentButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    /// 副ボタン。iOS 26 以降は `.glass`（縦幅を抑えるため `.small`）、それ未満は既定のスタイル・サイズのまま
    @ViewBuilder
    func chromeButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass).controlSize(.small)
        } else {
            self
        }
    }
}

/// 隣り合うガラス要素をまとめる。iOS 26 以降は `GlassEffectContainer`、それ未満は素通し
struct ChromeGlassGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer { content }
        } else {
            content
        }
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
