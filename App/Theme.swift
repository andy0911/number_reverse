import SwiftUI
import NumberOthelloCore

/// 配色トークン。現時点では既存のライトモード配色をそのまま名前付けしたもの。
/// ダークモード対応 PR でここに dark バリアントを追加する。
enum Theme {
    // MARK: - 盤面ゾーン（spec §2）
    static let zoneGray = Color(white: 0.78)
    static let zoneBlue = Color(red: 0.84, green: 0.9, blue: 0.97)
    static let zoneRed = Color(red: 0.98, green: 0.8, blue: 0.8)

    // MARK: - 盤の枠・区切り線
    static let boardFrame = Color.black.opacity(0.6)
    static let boardDivider = Color.black

    // MARK: - 駒
    static let chipText = Color.white
    static let flippedRing = Color.red
    static let lastPlacedRing = Color.white

    // MARK: - オーバーレイ
    static let dialogScrim = Color.black.opacity(0.35)
}

extension Player {
    /// プレイヤーを表す色（先行=オレンジ、後攻=グリーン）
    var color: Color { self == .first ? Color(red: 0.95, green: 0.68, blue: 0.1) : Color(red: 0.1, green: 0.55, blue: 0.4) }
}
