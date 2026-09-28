import SwiftUI
import NumberOthelloCore

/// 盤上の駒（チップ）。実物のチップ（碁石・カジノチップ）のように、厚み・光沢・縁の刻みを
/// グラデーションとストロークの重ねで描く（画像アセットは使わない）。
///
/// 数字/T/B の可読性を最優先する（spec §3）:
/// - 光沢は外周の左上に寄せる。数字の背後は窪みにして、数字の色（`Theme.chipText`: ライト=白 / ダーク=暗色）とのコントラストを
///   保つ（窪みはライトで暗く、ダークで明るく。文字影もライトのみ。`Theme.chipRecess` / `chipTextShadow`）
/// - 数字は通常 18pt（直径 30pt 未満では直径の 0.6 倍に縮める）。窪みが数字（外接円）より小さくならないよう、
///   縁の刻みの長さを直径に応じて縮め、直径が小さい（小さい画面・盤面が縮んだ）ときは刻みと内側の細線を省く（`ChipLayout`）
/// - 状態リング（flipped=赤 / last-placed=白）は光沢・斜光より手前の最外周に描き、内側に暗い縁取りを引いて刻みと区別する
struct ChipView: View {
    let piece: Piece
    /// 直前の手で裏返った駒（赤リング）。last-placed より優先する
    let isFlipped: Bool
    /// 直前に置かれた駒（白リング）
    let isLastPlaced: Bool

    private var ringColor: Color? {
        isFlipped ? Theme.flippedRing : (isLastPlaced ? Theme.lastPlacedRing : nil)
    }

    var body: some View {
        ChipBase(color: piece.owner.color, thickness: 2) {
            GeometryReader { proxy in
                let layout = ChipLayout(diameter: min(proxy.size.width, proxy.size.height))
                ZStack {
                    // 外周の帯（状態リングもここに重なる）
                    Circle().strokeBorder(Theme.chipShade, lineWidth: ChipLayout.bandWidth)
                    if let notch = layout.notchDepth {
                        // 縁の刻み（カジノチップ風）と内側の細線
                        ChipNotches(count: ChipLayout.notchCount, inset: ChipLayout.bandInset, depth: notch, width: ChipLayout.notchWidth)
                            .fill(Theme.chipInlay)
                        Circle().inset(by: layout.recessInset - ChipLayout.inlayWidth)
                            .strokeBorder(Theme.chipInlay, lineWidth: ChipLayout.inlayWidth)
                    }
                    // 数字の背後の窪みと文字影は、数字の色（chipText）の明暗に合わせて外観ごとに切り替わる
                    Circle().inset(by: layout.recessInset).fill(Theme.chipRecess)
                    Text(piece.kind.description)
                        .font(.system(size: layout.fontSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.chipText)
                        .shadow(color: Theme.chipTextShadow, radius: 0.5, y: 0.5)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        } top: {
            if let ringColor {
                Circle().strokeBorder(ringColor, lineWidth: ChipLayout.bandWidth)
                Circle().inset(by: ChipLayout.bandWidth).strokeBorder(Theme.chipRingKeyline, lineWidth: ChipLayout.keylineWidth)
            }
        }
    }
}

/// チップの直径から、縁の刻み・内側の細線・数字の窪みの寸法を決める。
/// 直径 21.25pt 以上（セルで約 29pt 以上。iPhone SE 相当の画面でセル約 39.6pt）では、窪みの半径が数字の外接円
/// （`glyphRadius`）以上になり、細線が数字を横切らない。
private struct ChipLayout {
    /// 最外周の帯の幅。状態リングはこの帯に重ねる
    static let bandWidth: CGFloat = 3
    /// 状態リングの内側の縁取りの幅
    static let keylineWidth: CGFloat = 0.75
    /// 刻みの外縁の位置（外周からの距離）。帯と縁取りの内側に余白を挟んで置く
    static let bandInset: CGFloat = bandWidth + keylineWidth + 0.5
    /// 刻みの周方向の幅・個数と、内側の細線の幅
    static let notchWidth: CGFloat = 4
    static let notchCount = 12
    static let inlayWidth: CGFloat = 0.75
    /// 刻みの径方向の長さの上限（十分な大きさのときの値）と、これ未満なら刻みを描かない下限
    private static let maxNotchDepth: CGFloat = 3
    private static let minNotchDepth: CGFloat = 1.5
    /// 刻みと細線の間の余白
    private static let inlayGap: CGFloat = 1
    /// 数字の最大サイズ（読みやすさのため、通常サイズではこの値で固定する）
    private static let maxFontSize: CGFloat = 18

    let diameter: CGFloat

    /// 数字のフォントサイズ。直径が 30pt 未満のときだけ縮める（フォント 18pt のとき外接円の半径は約 9pt）
    var fontSize: CGFloat { min(Self.maxFontSize, diameter * 0.6) }
    /// 数字（最大で約 11×13pt）の外接円の半径＋余白
    private var glyphRadius: CGFloat { fontSize / 2 }

    /// 刻みの長さ。窪みを数字の外接円より小さくしない範囲で 3pt まで取り、1.5pt に満たなければ刻みと細線を省く（nil）
    var notchDepth: CGFloat? {
        let spare = diameter / 2 - glyphRadius - Self.inlayWidth - Self.bandInset - Self.inlayGap
        return spare >= Self.minNotchDepth ? min(Self.maxNotchDepth, spare) : nil
    }

    /// 数字の窪みの外周から駒の外周までの距離。
    /// 刻みがあるときは刻み・余白・細線の内側、省いたときは帯の内側に少し余白を置く
    var recessInset: CGFloat {
        if let notchDepth {
            Self.bandInset + notchDepth + Self.inlayGap + Self.inlayWidth
        } else {
            Self.bandInset
        }
    }
}

/// 手番表示などに使う小さなチップ（刻み・数字なし）
struct ChipDot: View {
    let owner: Player

    var body: some View {
        ChipBase(color: owner.color, thickness: 1) {} top: {}
    }
}

/// チップの土台: 側面（厚み）＋ドーム状の陰影＋左上の光沢＋縁の斜光。
/// `content` は円の内側（上面）で斜光より下に、`top` は斜光より手前に重ねる。
private struct ChipBase<Content: View, Top: View>: View {
    let color: Color
    /// 側面の厚み（pt）。下方向にずらした暗い円で表現する
    let thickness: CGFloat
    @ViewBuilder let content: Content
    @ViewBuilder let top: Top

    var body: some View {
        ZStack {
            // 側面（厚み）と接地影。隣のセルに滲まないよう影は小さくする
            Circle()
                .fill(color)
                .overlay(Circle().fill(Theme.chipSide))
                .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
                .offset(y: thickness)
            // 上面
            Circle()
                .fill(color)
                // ドーム状の陰影（縁ほど暗い）
                .overlay(Circle().fill(EllipticalGradient(
                    stops: [.init(color: .clear, location: 0.6), .init(color: .black.opacity(0.3), location: 1)],
                    center: .center)))
                // 光沢（外周の左上寄り。中央の数字の背後にはごく薄くしか届かず、数字は光沢の上に描く）
                .overlay(Circle().fill(EllipticalGradient(
                    colors: [Theme.chipSheen, .clear],
                    center: UnitPoint(x: 0.28, y: 0.2),
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.5)))
                .overlay { content }
                // 縁の斜光（左上が明るく右下が暗い）
                .overlay(Circle().strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.7), .clear, .black.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1))
                // 状態リングは斜光に潰されないよう最前面に置く
                .overlay { top }
        }
        // 側面の分だけ下を空け、駒全体の高さを元のセル内に収める
        .padding(.bottom, thickness)
    }
}

/// 縁の刻み。外周から `inset` 内側に、放射状の短冊を `count` 個等間隔で並べる
private struct ChipNotches: Shape {
    let count: Int
    let inset: CGFloat
    let depth: CGFloat
    let width: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2 - inset
        // 中心を原点に、真上（12 時）の短冊を作って回転させる
        let notch = Path(roundedRect: CGRect(x: -width / 2, y: -outerRadius, width: width, height: depth), cornerRadius: 0.8)
        var path = Path()
        for i in 0..<count {
            let transform = CGAffineTransform(rotationAngle: 2 * .pi * Double(i) / Double(count))
                .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
            path.addPath(notch, transform: transform)
        }
        return path
    }
}
