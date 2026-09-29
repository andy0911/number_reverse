# TestFlight 配布手順

このリポジトリで用意済みの設定と、Apple のアカウント側で本人が行う作業をまとめる。

## リポジトリ側（設定済み）

| 項目 | 値 | 場所 |
|---|---|---|
| 表示名 | トオカエシ | `project.yml` `INFOPLIST_KEY_CFBundleDisplayName` |
| 製品名 / 実行ファイル | Tokaeshi | `project.yml` `PRODUCT_NAME` |
| Bundle ID | `jp.andygrave.tokaeshi` | `project.yml` `PRODUCT_BUNDLE_IDENTIFIER` |
| チーム | `377M4Z6S57`（Individual） | `project.yml` `DEVELOPMENT_TEAM`、`scripts/ExportOptions.plist` |
| 対象 OS | iOS 26.5 以上、iPhone のみ、縦向きのみ | `project.yml` |
| バージョン | 1.0（`MARKETING_VERSION`） | `project.yml` |
| ビルド番号 | アーカイブ時に git のコミット数を渡す。アップロードは main から行う（PR ブランチは squash マージで main より数が多くなるため）。番号が使えない場合はアップロード時に Xcode が繰り上げる | `scripts/testflight.sh`、`scripts/ExportOptions.plist` |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（通信・独自暗号なし） | `project.yml` |
| アイコン | 1024×1024（アルファなし）1 枚 | `App/Assets.xcassets/AppIcon.appiconset`（生成元 `scripts/make_icon.swift`） |
| デバッグ用起動引数 | `-demo` / `-bombScenario` は Debug ビルドのみ有効 | `App/NumberOthelloApp.swift` |

Bundle ID は App Store Connect にアプリを作成すると変更できない前提で扱う。変える場合はアプリ作成より前に `project.yml` を直す。

## 本人が行う作業

1. **Xcode のアカウント確認**: Xcode › Settings › Accounts に、チーム `377M4Z6S57` の Apple ID でサインインしていること。未サインインだと書き出しが `No Accounts` / `No profiles for 'jp.andygrave.tokaeshi'` で失敗する（アーカイブまでは成功する）。
2. **App Store Connect でアプリを作成**（[新規 App の追加](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)。Account Holder / App Manager / Admin の権限が必要）
   - プラットフォーム: iOS
   - 名前: トオカエシ（App Store 上で他のアプリと重複すると登録できない）
   - プライマリ言語: 日本語
   - Bundle ID: `jp.andygrave.tokaeshi`（一覧に無ければ、先に `scripts/testflight.sh export` を 1 回実行すると Xcode が App ID を登録する）
   - SKU: 任意（例 `tokaeshi`）
   - 作成後、App 情報でカテゴリを「ゲーム」（サブカテゴリ「ボード」）に設定する（[App 情報](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)）
3. **ビルドのアップロード**
   ```bash
   scripts/testflight.sh export   # 署名付き .ipa を build/export に書き出すだけ（送信しない）
   scripts/testflight.sh upload   # App Store Connect に送信
   ```
   Xcode のサインインを使わない場合は、App Store Connect API キーを `ASC_KEY_PATH` / `ASC_KEY_ID` / `ASC_ISSUER_ID` で渡す。
4. **テスターの追加**（[TestFlight の概要](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)）
   - 内部テスター: App Store Connect のユーザー最大 100 人。ビルドの審査は不要。
   - 外部テスター: 最大 10,000 人。グループに最初のビルドを追加したときに審査がある（以降のビルドは完全な審査が不要な場合がある）。
   - テスト情報（ベータ版の説明、テストしてほしい点、フィードバック用メールアドレス）を入力する。
   - ビルドは最長 90 日間テストできる。

## アプリ名について

- 原案の「数字オセロ」の「オセロ」は株式会社メガハウスの登録商標（登録第2287072号）のため使わない。説明文やキーワードにも入れない。一般名称の「リバーシ」は説明語として使ってよい。
- 「トオカエシ（十返し）」の事前確認（2026-09-29 実施、法的な商標クリアランスではない）
  - J-PlatPat 商標検索の称呼（類似検索）「トオカエシ」: 7 件ヒット、同一の称呼なし。近いものは「陶画絵師 中村一代」（称呼トーガエシ、第35類）、「スマホおかえしプログラム」（第9・36・38類）。ゲーム関連区分（第9・28・41類）で同一・近似の称呼なし。
  - App Store（iTunes Search API、jp / us）: 同名アプリなし。
- 一般公開の前に、弁理士による商標調査・出願の検討を推奨する。
