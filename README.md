# トオカエシ（十返し） iOS

数字の合計で相手の「軍」を挟んで裏返す、リバーシ系の iOS アプリ。駒の表と裏の数字の和が 10 になることから「十返し」と名付けた。対象 OS は iOS 26.5 以上。

原案の資料名は「数字オセロ」だが、「オセロ」は株式会社メガハウスの登録商標（登録第2287072号）のため、アプリ名・表示には使わない。コード内部の識別子（`NumberOthello` / `NumberOthelloCore`）は利用者に表示されない開発用の名前として残している。

- 仕様: [docs/spec.md](docs/spec.md)（曖昧点レジスタ・整合性検証を含む）
- 実装計画: [docs/plan.md](docs/plan.md)
- TestFlight 配布: [docs/testflight.md](docs/testflight.md)（`scripts/testflight.sh`）

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

起動引数 `-demo` で CPU 同士の対局を観戦できる（動作確認用。Debug ビルドのみ）。

タイトル画面の「遊び方を見る」でコーチモード（コーチマークで盤面を指し示しながらルールを説明）を開ける。盤面の変化は実際の `GameState` を動かして描く。説明文は固定の文章で、文が述べる主な事実は claim として併記し、`swift test` と実行時に実エンジンの結果と照合している（文章そのものを自動検証しているわけではない。詳細と説明範囲は spec §10）。
