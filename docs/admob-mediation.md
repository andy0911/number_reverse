# AdMob Mediation 導入状況（2026-10-03）

## アプリ側の準備

- `project.yml` に Google 公式 Unity Ads アダプターを追加。コミット `e7d16cc0820c89154969844801a71b1172b368fa` に固定。
- Unity Ads SDK 4.20.1 / アダプター 4.20.1.0。既存の Google Mobile Ads 13.10.0 / UMP 3.1.0 を維持。
- Unity 公式の SKAdNetwork 一覧から、既存と重複しない 39 件を追加。生成後の `App/Info.plist` は 89 件。
- XcodeGen でプロジェクト生成済み。UnityAdapterTarget のリンク設定を確認済み。
- 既存の UMP → ATT → MobileAds 初期化の順序、広告削除購入時の表示抑止を維持。
- 隔離した検証用Swift PackageでGoogle Mobile Ads 13.10.0・UMP 3.1.0・Unity Ads 4.20.1・アダプター4.20.1.0の依存解決とバイナリ取得が成功。
- Xcode 27.0 の画面から iPad Pro 13-inch (M5) / iPadOS 26.5 向けビルド成功と起動を確認。広告への同意とATTを拒否しても対局画面へ進めた。Unity広告の実表示・実機は未検証。
- 通常のビルドコマンドはSwiftPM標準キャッシュへの書き込み制限で失敗したが、Xcodeでのビルド成功を確認。

## AdMob 側の準備

- バナー: 「トオカエシ iOS バナー」、グループID 1875657772、対象「対局画面バナー」。一時停止。
- インタースティシャル: 「トオカエシ iOS インタースティシャル」、グループID 1495466469、対象「対局終了後インタースティシャル」。一時停止。
- 両グループは全地域・IDFA使用の可否すべて。AdMob NetworkとUnity Ads Biddingを登録済み。Unity Adsは準備完了・パートナーシップ有効を画面で確認。
- Unity登録・広告契約・AdMob入札契約はユーザーの個別同意を経て完了。
- Unity Game ID: `800387616`。バナー: `BP_Banner_iOS`。全画面: `BP_Interstitial_iOS`。各グループにマッピングして保存済み。
- 一般向け（子ども向けではない）として設定済み。
- Unity開発者サイトを `https://andy0911.github.io` に保存済み。
- Unity画面に発行された販売者情報160行を既存Googleの1行へ追加し、公開URLで直接販売者行を確認。サイトコミット: `7df0d326fd7008e2c949d097f647a3ae472239e4`。
- 公開プライバシーポリシーに今後のUnity利用を追記済み。
- 欧州の広告パートナー設定で Unity Technologies SF（GVL 1549）が選択済みであることを確認。設定変更不要。

## 配信開始までに必要な作業

1. 米国州法の同意情報連携とプライバシー選択画面を実装・確認。Google公式資料ではUnityへ手動で伝える必要がある。アプリの同意を推測でtrueに設定しない。
2. App Storeのプライバシー回答と実際のSDK動作を照合。
3. 登録済みテスト端末で、登録済みテスト端末とUnityテスト広告でバナー・全画面広告を確認。DebugのGoogle公式テストIDではこのアカウントのメディエーション設定を検証できないため、実際の広告枠IDをテスト端末で使う。
4. 同意拒否・ATT拒否・広告削除購入済み・通信断・広告在庫なしを確認。バナーのサイズと読み込み結果も確認する。UnityのBiddingでは4.14.1.1以降サイズチェックが撤廃されているが、実表示を確認する。
5. テスト設定を本番向けに切り替え、SDK組み込み済みのアプリを配布してからグループを有効化する。既存バージョンへの影響と収益・表示率・読み込み時間を確認する。

## 公式資料

- https://developers.google.com/admob/ios/mediation/unity
- https://github.com/googleads/googleads-mobile-ios-mediation-unity
- https://docs.unity.com/en-us/grow/ads/ios-sdk/ios14/configure-ad-network-ids
- https://skan.mz.unity3d.com/v3/partner/skadnetworks.plist.json

Unityのウォーターフォール方式は公式案内で2026-01-31にサポート終了とされているため、この導入ではBiddingを使う。登録・契約・IDのマッピングは完了。アプリ配布・広告実表示・同意連携の確認が完了するまでグループは一時停止。
