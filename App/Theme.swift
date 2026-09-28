import SwiftUI
import NumberOthelloCore

/// 配色トークン。システムの外観設定（ライト/ダーク）に追従する動的カラーで定義する。
/// ライト値は従来配色そのまま。ダーク値は「3 ゾーンの判別」「点線の視認性」「駒と文字のコントラスト」を保つよう調整している。
/// Asset Catalog は使わない（JSON の diff が肥大化し他ブランチと衝突しやすいため）。
enum Theme {
    // MARK: - 盤面ゾーン（spec §2）
    // 赤・青=本戦では常に配置可（spec §4.2。赤は初期配置の 1〜2 手目の置き場所でもある、spec §4.1）、
    // 灰=置くと 1 枚以上裏返る場合のみ配置可（spec §4.2 R-2）、という意味を色で伝えている。
    // ダークでも 3 ゾーンを判別できるよう、灰は無彩色、青・赤は色相で分けたうえで、
    // 明度（CIE L*）も 灰 約33 > 青 約24 > 赤 約17 と段差をつけ、色相だけに頼らないようにしている。
    /// 灰ゾーン（外周 28 マス、spec §2）。ダークは無彩色で 3 ゾーン中もっとも明るい。
    static let zoneGray = Color(light: UIColor(white: 0.78, alpha: 1), dark: UIColor(white: 0.30, alpha: 1))
    /// 青ゾーン（内側 32 マス、spec §2）。ダークは濃紺。
    static let zoneBlue = Color(light: UIColor(red: 0.84, green: 0.9, blue: 0.97, alpha: 1), dark: UIColor(red: 0.12, green: 0.22, blue: 0.40, alpha: 1))
    /// 赤ゾーン（中央 4 マス、spec §2）。ダークは暗赤で 3 ゾーン中もっとも暗い。
    static let zoneRed = Color(light: UIColor(red: 0.98, green: 0.8, blue: 0.8, alpha: 1), dark: UIColor(red: 0.28, green: 0.105, blue: 0.12, alpha: 1))

    // MARK: - 盤の枠・区切り線
    /// 盤の外枠であり、Grid の 1pt の隙間としてマス目の境界線にもなる。
    /// 全ゾーンより暗くして境界を出す（ダークでは、背景（ChromeBackdrop のほぼ黒の暗色グラデーション）から浮かない程度の暗灰）。
    static let boardFrame = Color(light: UIColor(white: 0, alpha: 0.6), dark: UIColor(white: 0.1, alpha: 1))
    /// 先行/後攻の陣の境界（点線、spec §2）。ダーク背景では黒が見えないため明るい色にする。
    static let boardDivider = Color(light: .black, dark: UIColor(white: 0.92, alpha: 1))

    // MARK: - 駒
    /// 駒・選択中の手駒ボタン上の文字色。ダークでは駒色が明るいため暗色にしてコントラストを確保する。
    static let chipText = Color(light: .white, dark: UIColor(white: 0.08, alpha: 1))
    /// 直前に裏返った駒の縁取り。ダークでは背景・駒色の双方に負けないよう少し明るい赤にする。
    static let flippedRing = Color(light: .systemRed, dark: UIColor(red: 1.0, green: 0.32, blue: 0.32, alpha: 1))
    /// 直前に置いた駒の縁取り。ライト/ダークとも白（ダークでは暗い盤面に映え、ライトは従来値）。
    static let lastPlacedRing = Color.white

    // MARK: - プレイヤー色
    // 先行=暖色（オレンジ）、後攻=寒色（グリーン）の色系統はライト/ダークで保つ。
    // ダークでは暗い盤面で映えるよう明度を上げ、HSV の彩度はやや下げる（色相のずれは数度以内）。
    /// 先行（spec §1）の駒色
    static let playerFirst = Color(light: UIColor(red: 0.95, green: 0.68, blue: 0.1, alpha: 1), dark: UIColor(red: 1.0, green: 0.74, blue: 0.20, alpha: 1))
    /// 後攻（spec §1）の駒色
    static let playerSecond = Color(light: UIColor(red: 0.1, green: 0.55, blue: 0.4, alpha: 1), dark: UIColor(red: 0.22, green: 0.78, blue: 0.58, alpha: 1))

    // MARK: - オーバーレイ
    /// ダイアログ背後の暗幕。ダークは盤面がもともと暗いため、ライトより濃くしてダイアログを浮かせる。
    static let dialogScrim = Color(light: UIColor(white: 0, alpha: 0.35), dark: UIColor(white: 0, alpha: 0.55))
}

private extension Color {
    /// 外観（ライト/ダーク）に応じて値を切り替える動的カラー。
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

extension Player {
    /// プレイヤーを表す色（先行=オレンジ、後攻=グリーン）
    var color: Color { self == .first ? Theme.playerFirst : Theme.playerSecond }
}

// MARK: - チップデザイン
// チップ（ChipView）とガラス chrome（ChromeStyle）用のトークン。上の既存トークンの値は変えていない。
// 駒の陰影は `Player.color`（ライト/ダークで別値）に白/黒の半透明を重ねて派生させるので、プレイヤー色の変更に追従する。
// 数字の色 `chipText` はライトで白・ダークで暗色になる。数字の背後の窪み（chipRecess）と文字影（chipTextShadow）には、
// その明暗に対応する値を外観ごとに設定して、どちらの外観でも数字と背景のコントラストを保つ（chipText とは独立した
// トークンなので、chipText を変えるときはこの 2 つも見直すこと）。下のトークンで light/dark 別の値を持つのは
// chipRecess・chipTextShadow・backdrop の 4 つで、それ以外は白/黒の半透明でライト/ダーク共通。
extension Theme {
    /// 駒の側面（厚み）。駒色の上に重ねて暗くする
    static let chipSide = Color.black.opacity(0.42)
    /// 駒の外周の帯を締める暗色
    static let chipShade = Color.black.opacity(0.22)
    /// 数字の背後の窪み。ライトは暗くして白文字を、ダークは明るくして暗色の文字を際立たせる（chipText の明暗と逆向き）。
    /// ライトの 0.30 は、光沢（左上寄り）が重なる位置でも数字のコントラストが平らな円（変更前）以上になる値
    static let chipRecess = Color(light: UIColor(white: 0, alpha: 0.30), dark: UIColor(white: 1, alpha: 0.22))
    /// 数字の影。ライトは暗い影で白文字を締める。ダークの文字は暗色なので影は付けない
    static let chipTextShadow = Color(light: UIColor(white: 0, alpha: 0.45), dark: .clear)
    /// 縁の刻み・内側の細線。駒色に重ねる白（数字と last-placed リングの白より控えめにする）
    static let chipInlay = Color.white.opacity(0.5)
    /// 光沢（外周の左上に寄せて置く）
    static let chipSheen = Color.white.opacity(0.4)
    /// 状態リング（flipped / last-placed）の内側に引く縁取り。白リングも赤リングも刻みと見分けられるようにする
    static let chipRingKeyline = Color.black.opacity(0.6)

    /// 画面背景（ChromeBackdrop）の上端・下端。ガラス chrome の背後に敷く。ダークはほぼ黒の暗色グラデーション
    static let backdropTop = Color(light: UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1), dark: UIColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1))
    static let backdropBottom = Color(light: UIColor(red: 0.87, green: 0.90, blue: 0.95, alpha: 1), dark: UIColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1))
}
