# 数字オセロ (iOS)

数字の合計で相手の「軍」を挟んで裏返す、オセロ派生ゲームの iOS アプリ。

- 仕様: [docs/spec.md](docs/spec.md)（曖昧点レジスタ・整合性検証を含む）
- 実装計画: [docs/plan.md](docs/plan.md)

## 構成
- `Core/` — ルールエンジンと CPU（Swift Package、UI 非依存）
- `App/` — SwiftUI アプリ
- `project.yml` — XcodeGen 定義

## 開発
```bash
cd Core && swift test          # ルールのテスト
xcodegen generate              # NumberOthello.xcodeproj を生成
xcodebuild -project NumberOthello.xcodeproj -scheme NumberOthello \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

起動引数 `-demo` で CPU 同士の対局を観戦できる（動作確認用）。

タイトル画面の「遊び方を見る」でコーチモード（コーチマークで盤面を指し示しながらルールを説明）を開ける。説明は実際の `GameState` を動かして作り、内容は `swift test` で検証している（説明範囲は spec §10）。
