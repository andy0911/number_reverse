# 実装計画

## 構成
```
number_reverse/
├─ docs/            spec.md（仕様）/ plan.md（本書）
├─ Core/            Swift Package `NumberOthelloCore`（ルールエンジン・CPU、UI 非依存）
│   ├─ Sources/NumberOthelloCore/
│   └─ Tests/NumberOthelloCoreTests/   Swift Testing（`swift test` で macOS 上で実行）
├─ App/             SwiftUI アプリ（Core に依存）
└─ project.yml      XcodeGen（`xcodegen` で NumberOthello.xcodeproj 生成）
```

## Core の設計
| 型 | 役割 |
|---|---|
| `Player` | `.first` / `.second` |
| `Position`, `Zone` | 座標とゾーン（gray/blue/red）、陣（点線の上下） |
| `PieceKind` | `.number(Int)` / `.tank` / `.bomb` |
| `Cell` | `.empty` / `.piece(Piece)` / `.wasteland` |
| `Hand` | 駒種ごとの残数 |
| `Phase` | `.setup(step)` / `.playing` / `.awaitingBombDirection(owner, at)` / `.finished` |
| `GameState` | 盤・手駒・手番・フェーズ・爆発キュー。値型 |
| `GameState.place(_:at:)` | 合法性検査 → 配置 → §5 判定 → 爆発キュー処理 → 手番進行（自動パス） |
| `GameState.chooseBombDirection(_:)` | 割り込み状態の解決 |
| `GreedyAI` | 1 手先読みの貪欲 CPU（§9） |

割り込み状態 `awaitingBombDirection(owner:)` を最初から持たせ、UI と CPU の両方がこの状態を見て方向を供給する。

## マイルストーン
1. **Core モデル＋判定**: 盤・駒・手駒・§5 判定・爆発キュー・パス/終了
2. **Core テスト**: spec §8 の受け入れテスト全件を Swift Testing で実装、`swift test` 緑
3. **CPU**: GreedyAI とテスト（常に合法手を返す、自動対局が必ず終了する）
4. **App**: タイトル（モード選択）→ 盤面画面（盤・手駒ピッカー・スコア・手番表示・爆弾方向ダイアログ・結果）
5. **検証**: `xcodebuild` でシミュレータビルド、起動・スクリーンショットで確認

## リスク
- 爆弾の割り込みで手番の進行が複雑化 → Core の状態機械に閉じ込め、UI は `phase` を描画するだけ
- CPU の先読みで爆弾連鎖が起きる場合 → 方向選択は各持ち主にとって貪欲で解決するシミュレーション関数を用意
