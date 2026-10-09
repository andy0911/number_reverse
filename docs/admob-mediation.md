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

1. 2026-10-04に同意連携・選択画面を追加済み（末尾参照）。米国向けUMPメッセージの公開設定と実機での同意伝播を確認する。
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


## 2026-10-04 追加実装・現状照合

- App Store Connectの配信準備完了版は1.1.2（24）。ローカル配布アーカイブのASCビルドUUIDと一致し、アーカイブにはGoogleMobileAds/UMPのみ、Unityは未搭載。現在のUnity導入ブランチは未配布。
- AdMobグループ1875657772は一時停止、Unityは準備完了・提携有効。Game ID800387616 / BP_Banner_iOSを現画面で再確認。外部設定は変更していない。
- タイトルに「広告のプライバシー設定」を追加。広告削除購入済みでも表示し、UMPがrequiredを返すときは同意フォームを再表示できる。
- Unityの販売・共有/パーソナライズは初期拒否。明示的なアプリ内選択、最新UMP更新後のGDPR非対象(0)、ATT許可の3条件が揃った場合のみprivacy.consent=true。それ以外はfalse。canRequestAdsからパーソナライズ同意を推測しない。
- Unity privacy APIはGDPR APIより優先するため、GDPR対象・不明時は意図的にfalseを維持する。この段階では欧州でUnityのパーソナライズ広告を有効にしない。表示率/単価が下がる可能性はある。
- 同意変更時は広告要求を停止し、古いバナー/インタースティシャルを破棄。変更前の非同期ロード結果も世代番号で破棄。システム設定でATTを変えた後の復帰時も再評価する。
- DebugではUnityAdapterのtestMode=true。通常のDebugはGoogle公式テストIDを維持。Simulatorのみ起動引数 `-mediationTest` で既存本番広告枠IDを選択可能（GoogleはSimulatorを自動的にテスト端末扱い）。実機Debugでは同引数でも公式テストIDを維持する。
- Debugのプライバシー画面からAd Inspectorを開ける。Releaseには診断ボタンとUnityの強制テスト設定を含めない。

### 検証と残条件

- Xcode 27.0 / iOS 26.5 Simulator Debugビルド、iOSデバイス用Releaseコンパイル成功（署名/公開なし）。
- アプリの8テスト成功。Unity同意判定は明示選択2通り×GDPR4通り×ATT2通りの16組み合わせを検証。
- iPad Simulatorで設定画面、初期オフ、UMP同意フォームの再表示、Do not consent後の設定画面復帰、Ad Inspector起動を確認。
- Ad InspectorのAdaptersはNo adapters found。配信グループは停止状態で、Unity実広告要求・テスト広告表示はまだ未検証。リンク済みと実配信可能を混同しない。
- Google公式手順に合わせてUADSMetaDataを使用しているためUnity SDK 4.20.1では非推奨警告あり。将来のSDK更新時にsetUserOptOutなどへの移行を確認する。
- 米国向けAdMob UMPメッセージ・広告パートナー設定の確認、App Storeプライバシー回答/審査メモへのUnity追加、公開ポリシーと追加選択UIの照合は配布前に必要。
- 実機でUnityのテスト端末登録・テスト広告表示、ATT/同意の拒否と変更、広告削除購入済み、通信断/在庫なしを検証する。Simulatorのテスト経路だけで実機完了としない。
- 新バージョン/ビルドのレビュー・配布承認を得て、Unity SDK入りアプリを配布した後にバナーグループのみ有効化する。既存の全画面グループは本依頼では停止を維持する。

追加資料:
- https://developers.google.com/admob/ios/privacy
- https://docs.unity.com/en-us/grow/ads/privacy/ccpa-compliance

- 最終ソースを既存ブランチへ反映後も8テスト成功、デバイス向けReleaseビルド成功。`test-repository.log` / `release-repository.log` は `/Users/t.hanano/Documents/Codex/2026-10-04/task-2/` に保存。
- UMPの同意再取得が必要な場合、または同意変更画面を開いた場合は、以前の独立したUnity許可を解除する。包括的な拒否と以前の許可が競合するのを防ぐ。
- AdMobのプライバシー画面は欧州メッセージ1件有効、米国の州は「新しいメッセージを作成」「米国の州のプライバシー規制を始める」を表示。米国メッセージの新規公開は実施していない。米国広告パートナーは「アクティブな広告パートナー」334社。
- App Storeプライバシー回答は7データ種別（おおよその場所、デバイスID、製品の操作、広告データ、クラッシュ、パフォーマンス、その他診断）を申告済み。Unity追加に必要な変更の最終照合は未了。現在の審査メモの外部サービスはGoogle/UMP/StoreKitのみで、次回提出時にUnityの追記が必要。

## 内部TestFlight QA版 1.1.3 (30) — 2026-10-04

ユーザーの明示承認により内部グループ「内部」へ配布。App Store Connectで「テスト中」、内部2名を確認。`testFlightInternalTestingOnly=true` のため外部TestFlight/App Storeへは配布不可。新規認証キーは作らず既存キーと手動署名を使用。

- QA専用バナー: `ca-app-pub-5364369331405756/9486069744`。
- QAグループ: `4886751722`、名前「QA専用 トオカエシ iOS Unityバナー」、一時停止。対象はQAバナーのみ。
- Unity入札: Game ID `800387616` / Placement ID `BP_Banner_iOS`。既存アカウント・配置を使用。新規契約なし。
- ビルド時のみ `SWIFT_ACTIVE_COMPILATION_CONDITIONS=MEDIATION_QA` を指定。QA版は所有する広告枠IDを空文字とし、通常のバナー/インタースティシャル要求を停止。
- Unity adapter `testMode=true`。QA画面の手動ボタンだけがGoogle公式デモバナーを要求する。Unity経由の実表示確認ではない。
- OSLogから今回のGoogle SDKの `testDeviceIdentifiers` 行にある32桁ハッシュだけを端末内で表示。取得可否は実機未検証、取得失敗でもメディエーション要求は開放しない。IDFA取得API追加なし、抽出ハッシュの保存/自動送信なし。
- テスト端末の外部登録は識別子種類・登録先・目的を説明して別途確認する。ATT許可を検証条件にしない。

検証: アプリ8テスト、Core52テスト成功。署名アーカイブ・アップロード成功。実行ファイルの文字列検査では公式デモバナーIDのみで本番広告ユニットIDなし。iPadシミュレータでSDK初期化完了、要求停止表示、手動Googleテストバナー受信を確認。Unity実機表示は未確認。

アップロード時の非阻害警告: GoogleMobileAds / UnityAdapter / UnityAds / UserMessagingPlatformのvendor dSYMがアーカイブに含まれずシンボル送信に警告。アプリ自体の配布・Appleの処理は成功したが、これらSDK内部のクラッシュ解析には制約が残る。

本番メディエーショングループは一時停止、米国UMPメッセージは下書き、App Storeプライバシー申告・一般公開は未変更。実機のテスト安全性確認、Unity表示確認、同意/拒否/ATT拒否経路確認、プライバシー情報の確定と本番リリース承認が残る。

## QA更新版 1.1.3 (31)

ユーザーがSDKログのテスト端末ハッシュ利用と内部TestFlight再配布を承認。ハッシュはソース/この文書に記録せず、リポジトリ外の `QA_ENROLLMENT_FILE` をQAビルドの `QATestDevice.plist` として取り込む。通常Releaseはこのリソースを必ず除去する。

QA画面でGoogleデモ要求後、同一プロセス・今回のSDKログと承認済みハッシュが一致した場合だけ、`testDeviceIdentifiers` を設定しQA専用バナーの手動要求を許可。照合不可・不一致・UMP要求不可なら停止。UnityのtestModeも強制。通常画面の本番バナーとインタースティシャルは引き続き停止。受信時に配信元adapter名を表示するので、Google受信をUnity成功とは扱わない。

手順: TestFlightを31へ更新 → 広告QA → Google公式テストバナー → この端末のテスト設定を確認 → QAメディエーションバナー。広告をクリックしない。QAグループ4886751722の有効化が必要。本番グループ1875657772/1495466469は停止維持。必要ならAd Inspectorの単一広告ソーステストでUnityを選択して再起動後に確認する。ハッシュ照合ログが出ない場合はアプリを完全終了してやり直し、要求を強制しない。

検証: QAアプリテスト8件成功、署名付きarchive成功、QA専用IDのみ実行ファイルに存在。通常Releaseビルド成功、QAリソース/ハッシュ/QA広告ID不在を確認。端末ハッシュの新たな取得やIDFA/Unity管理画面への登録なし。

31の配布結果: ASC build ID `232882e1-fabd-49de-849a-fa937f7858bf`。APIで `processingState=VALID` / `buildAudienceType=INTERNAL_ONLY` / `internalBuildState=IN_BETA_TESTING` と内部グループ所属を確認。テスト内容も保存済み。SDK vendor dSYM警告は前回同様で非阻害。

残作業: この実行環境ではブラウザ操作ツールが利用できず、AdMob QAグループ4886751722の有効化は未実施。管理画面でこのQAグループだけを有効化してから実機検証する。本番・UMP公開は未変更。

## QA診断修正版 1.1.3 (32)

31でGoogleデモは成功したがSDK識別子ログを見つけられずQA要求が停止した実機画像を確認。原因候補は、デモボタン押下時刻による検索範囲の切捨てと、SDKが識別子案内を毎回は出力しないこと。実機の原因を断定せず、次の修正を行った。

- 現在プロセス内のSDK識別子ログ全体を検索。別プロセス/端末のログは読まない。
- ログ列挙をバックグラウンドで実行し、確認中は二重実行を防ぐ。
- 成功した照合を同じプロセスのメモリだけで保持。QA画面を開き直したとき、テスト登録済みSDKの再ログ出力に依存しない。アプリ再起動で未照合に戻る。
- 初回の無ログ・読取失敗・不一致・設定欠落は要求停止。検索期間拡大だけで全端末で直る保証はなく、32でも無ログの場合はその結果を受けて調査し、要求を強制しない。
- 個人ハッシュは追加取得せず、承認済みQAリソースを継続使用。

自動テスト: 追加6件を含め14件成功。先行ログ、無ログ、読取失敗、不一致/矛盾ログ、繰り返し、再起動、設定変更、無関係/不完全ログの除外を検証。署名archive成功、QA専用広告IDのみを確認。Unityの実表示成功はまだ未確認。

32の配布結果: ASC build ID `f88ba1e6-e78a-4998-869f-0165ce86482d`。APIで `VALID` / `INTERNAL_ONLY` / `IN_BETA_TESTING` と既存内部グループ所属を確認。テスト説明保存済み。新規識別子・送信先・権限なし。本番設定変更なし。

## QA 1.1.3 (33): 公式Ad Inspectorによるテスト状態確認

32相当の実機画面でもログ照合が成立しなかったため、OSLogを使うゲートを廃止。Googleの公開仕様とSDK13.10.0のGADMobileAds.hを確認: Ad InspectorはGoogleがテスト端末と判定した端末でのみ起動でき、completionはInspectorを閉じた時に返る。表示に問題があればerror、正常時はnil。API呼出し開始だけでは確認完了にしない。

QAハッシュをSDKへ指定しUnity testModeを強制 → SDK初期化/同意/アプリactive/表示可能なpresenterを確認 → Inspectorを表示 → 正常終了通知 → 利用者が画面を見た確認 → QA専用バナーの順に進む。SDKエラー、初期化未完、設定不整合、中断、古いcallback、未確認時は要求停止。二重タップと多重completionを無視し、background/inactiveやプライバシー変更で確認を無効にする。QA画面にversion/buildを表示。

この方法はGoogleのテスト端末判定の確認であり、特定ハッシュとの同一性の証明ではない。別の非テスト端末はSDKの起動エラーで停止する。既に別経路でテスト登録済みの端末もGoogleがテスト端末と扱う可能性があり、承認ハッシュの一致を確認したとは表示しない。ハッシュ・ID・権限の追加なし。

根拠: https://developers.google.com/admob/ios/api/reference/Classes/GADMobileAds と https://developers.google.com/admob/ios/ad-inspector/launch-ad-inspector 。自動テスト14件成功（正常終了＋人による確認、SDKエラー、初期化等の前提不成立、多重タップ/通知、中断後の古い通知、設定変化）。この環境のUI操作ツールが利用不可のため、Inspector実画面・実機のGoogle判定・Unity広告受信は自動テストで保証していない。初回実機検証で確認する。

33配布結果: ASC ID `4bc52ec4-64af-4beb-895b-6edc02a2b37c`、`VALID` / `INTERNAL_ONLY` / `IN_BETA_TESTING`、既存内部グループ所属と手順保存をAPIで確認。署名archive/upload成功。通常Releaseもビルド成功し、ハッシュ、QA設定リソース、QA広告ID、QAInspectorGateが成果物に不在であることを確認。広告SDKのvendor dSYM警告は非阻害で継続。変更は未コミット。

## Unity初期化例外の調査とリンク修正（QA 34向け）

実機画像IMG_1909ではAd InspectorのAdapters画面が表示され、Unityが `-[GADMediationServerConfiguration gameIds]: unrecognized selector` で初期化失敗。画像にはversion/buildとQAバナー要求結果は写っていないため、それらの成功・失敗は判定しない。

UnityAdapterの静的バイナリには `-[GADMediationServerConfiguration(Settings) gameIds]` があるが、配布済み33のdSYMには実装シンボルがない（Release本体のnmはローカルシンボル除去の影響を受けるため、dSYMも照合）。ビルド設定には `-ObjC` がなかった。Apple QA1490が説明する静的ライブラリのObjective-C category欠落と一致するため、app targetの `OTHER_LDFLAGS` に `$(inherited) -ObjC` を追加。SDKバージョンは変更しない。

回帰テストは、実行中アプリのクラスに当該メソッドがリンクされているかをObjective-C runtimeで調べるだけで、SDK内部メソッドの呼出しや広告要求は行わない。修正前はこのテストが失敗し、欠落を再現した。

参考: https://developer.apple.com/library/archive/qa/qa1490/_index.html

修正後: 全15テスト成功。34のdSYMには当該メソッドが現れ、その実装アドレスが配布バイナリのObjective-Cメソッド表に存在することも確認。QA専用IDのみ、既存承認リソース一致、署名検証成功。Unity初期化・広告受信の実機成功は別途確認が必要。

34配布結果: ASC ID `2bed462a-57d9-4a00-abc5-1caab52bb890`、`VALID` / `INTERNAL_ONLY` / `IN_BETA_TESTING`。既存内部グループ所属と更新したテスト手順の保存をAPIで確認。通常Releaseもビルド成功し、承認ハッシュ、QAリソース、QAユニット、QAInspectorGateの不在を検証。SDK vendor dSYM警告は従来同様で非阻害。変更は未コミット、本番グループ/UMP公開は変更していない。

次の実機手順: TestFlightで1.1.3 (34)へ更新 → 広告QAからAd Inspector → Unityの初期化結果を確認。失敗ならそこで停止しエラーを確認。成功した場合のみInspectorを閉じ、表示確認後にQAバナーを要求し、返ったネットワーク名を確認する。広告クリックは不要。

追加実機画像IMG_1910を実画素で確認: QA画面はGoogleテスト端末判定・診断画面確認済み、Unityテストモード有効を表示。Test mode付きバナーが表示され、「受信済み / 配信元: GADMAdapterGoogleAdMobAds」。これはGoogleからのQA広告受信成功でありUnity経由成功の証拠ではない。Unity Adapterの初期化状態、Single ad source test状態、version/buildはこの画像に写っていない。新たなエラー表示なし。画像のみを根拠に34と断定しない。

次の切り分けはAd InspectorのAdaptersでUnity状態を確認すること。成功していればSingle ad source testでUnityを選び、Google公式手順に従いアプリを完全終了・再起動し、再度テスト端末確認後にQAバナーを要求する（既存キャッシュ除外）。失敗時はそのエラーを確認する。通常リクエストでGoogleが返ることだけを新規実装不具合とは扱わず、この画像に対するコード変更・追加ビルドは行っていない。
参考: https://developers.google.com/admob/ios/ad-inspector/test-ad-units

追加Adapters画像（Library libfile_aa487369b5288191b872a02000708f60）の実画素でUnity初期化成功を確認: Adapter v4.20.1.0 initialized in 527ms、SDK v4.20.1、Google SDK v13.10.0。以前のgameIds例外はこの画像では表示されず、成功状態。アプリversion/buildは非表示なので34とは画像だけで断定しない。Single ad source testはInactive。残る確認はUnity単独テストでのQAバナー受信。追加コード変更・再配布なし。

## 実機Unityバナー受信成功 — 2026-10-04

単独テスト案内後の画像（Library libfile_16ace12c65f081918e3b0bbffe401653）を実画素確認。QA画面にUnity Adsバナーが描画され、「受信済み / 配信元: GADMediationAdapterUnity」。Googleテスト端末判定・診断画面の確認済み／Unityテストモード有効と表示。エラーなし。バナーそのものに「Test mode」という文字は写っていないが、QAコードは要求条件にUnity testMode=trueを含む。画像にはビルド番号とSingle ad source testの状態は写っていないため、それらを画像だけで断定しない。

検証済み: Ad InspectorでUnity adapter 4.20.1.0／SDK4.20.1の初期化成功、QAバナーのGoogle受信、QAバナーのUnity経由受信・実表示。未検証: 通常入札でのUnity選定率・本番fill/収益、同意変更・広告削除・通信断などの実機回帰。追加修正・再配布なし。

本番までの残条件: Single ad source testを停止して完全終了・再起動、残る実機回帰とプライバシー/UMP/ASC申告の最終確認、公開用通常Releaseの承認・提出・配布、その後の本番バナーグループ有効化。内部QAビルドは公開用ではない。本番・UMP・新規権限に変更なし。全画面グループは対象外で停止維持。

## 公開前照合（Unity実機成功後、2026-10-04）

### 検証結果と限界

| 項目 | 確認結果 | 未確認の範囲 |
| --- | --- | --- |
| Unity初期化・バナー | 実機画像で4.20.1.0/4.20.1初期化とGADMediationAdapterUnityからの受信・表示成功 | 通常入札の選定率・収益 |
| 同意拒否 | 明示許可2×GDPR4×ATT2の16条件で、3条件が揃う場合だけtrueになるテスト成功 | 実端末上のUnity送信内容を暗号化通信から観測してはいない |
| 同意変更 | 新規AdsPrivacyTransitionTestsで許可→撤回、保存値false、広告世代2回更新、再生成時false、QA通常広告停止を確認 | 既に表示中の広告を実機で破棄する視覚的確認、地域フォームのE2E |
| 古い広告と遅延応答 | バナーは世代IDで再生成、全画面は世代不一致を破棄。QAゲートは中断/同意変更/古いcompletionを無効化する既存テスト成功 | 実機のタイミング競合全体を保証しない |
| 広告削除 | 全画面ポリシーの購入済み/未ロード抑止テスト成功。バナーと購入案内は同じhasRemovedAdsで非表示。起動順は所有権取得→広告開始 | StoreKit購入・手動復元の実行は下記環境問題で未完 |
| 最終自動テスト | 16テスト/6 suites成功（prerelease/tests-final.log） | StoreKit統合テストは成功件数に含めない |

StoreKit統合テストを実StoreManagerに対して作成して実行したが、SKTestSessionの設定保存が `SKInternalErrorDomain Code=3` で失敗。未署名、ad-hoc署名、明示StoreKitテストプランで再現し、購入API結果まで確認できなかった。アプリ購入不具合とは断定しない。ユーザーの実アカウント認証を入力せず停止。一時テスト/テストプランは作業フォルダprereleaseへ移し、生成スキームはXcodeGenで復旧。失敗するテストを通常スイートには追加していない。

### 通常Releaseの確認

qa34/production-build.logの通常Release（QA34と同じアプリソース、追加変更はテスト/文書のみ）を検査。QAリソース、承認端末ハッシュ（app全ファイル走査）、QAユニット9486069744、QADiagnosticsView、QAInspectorGate、アプリ指定のGoogleデモバナー/全画面IDは不在。本番バナー8224074481/全画面1465124825は存在。証拠: prerelease/release-evidence.json。

Releaseアプリ自身にtestDeviceIdentifiers設定・Unity testMode強制・単独ソース指定の有効経路はない。Google SDKにはAd Inspector自体の機能が含まれるので、「単独テスト機能のバイト列がSDKから全部消える」とは主張しない。端末/サーバー側のSingle ad source test状態は別設定であり、ユーザーがOFF後に完全終了・再起動する必要がある。通常Releaseの広告表示は実行していない。署名済み公開用archive/アップロードも今回は作成していない。

### 実構成に基づくプライバシー照合

2026-10-04に公開App Storeページと公開ポリシーをHTTP200で再取得。公開ラベルは7種すべて「ユーザに関連付けられないデータ」、場所/ID/使用状況はトラッキング申告。公開ポリシーは10月3日版でUnityを今後の対応版で利用すると記載。今回の独立したUnity選択UI/撤回方法の追記は未公開。

実装はGoogle13.10.0、UMP3.1.0、UnityAds4.20.1、Adapter4.20.1.0。Unity IAP/Analytics/Authenticationは依存にない。アプリにはアカウント・外部ゲーム状態保存・独自ユーザーID設定・Unityへの購入/レシート明示送信がない。StoreKit所有権と設定は端末内処理。ただし「呼び出しがない」だけではSDKの自動収集なしとは証明できない。

| 申告項目 | 本構成で得られた根拠 | 公開前の判断 |
| --- | --- | --- |
| おおよその場所/デバイスID/製品の操作/広告データ | Google13.10.0同梱マニフェストは4種をLinked=trueと明記。デバイスIDはTracking=true。アプリ側に収集前匿名化実装なし | 現在の全件Not linkedとの不一致が具体的にある。4種のLinked変更案を公開前レビュー対象にする。ATT拒否経路だけで全ユーザー非関連付けとは扱わない |
| 性能/クラッシュ/その他診断 | GoogleマニフェストはいずれもLinked=false。Unity一般表は性能Linked、SDK4.20.1マニフェストは収集配列空 | 既存種別は維持候補。Unity性能の関連付け/用途は現SDK・設定での説明確認が必要 |
| アプリ機能の用途 | UMP3.1.0は場所/性能/製品操作にAppFunctionality、Linked=falseを明記 | アプリ全体の用途にはUMP分も照合。GoogleマニフェストのDeveloperAdvertising等をアプリ独自マーケティングと無条件に同一視しない |
| ユーザーID/購入履歴 | UnityのApple一般表は収集あり。一方、アプリは明示送信せずUnity IAP/Authenticationも未導入 | 追加とも不要とも未確定。SDK自動生成ID/購入検知の機能別条件をUnityに確認する |
| その他使用状況/その他データ | Unity一般表は収集あり。Android向け補助資料には使用時間収集がAcquire Optimization有効時との条件あり | Android資料をiOSへ転記しない。対象UnityプロジェクトのAcquire Optimization設定とiOS4.20.1の該当性を確認する |
| カスタマーサポート | Unity一般表は広告クリエイティブ報告時に収集する場合あり | 本バナーの報告UI/送信先と任意開示条件を確認する。アプリにフォームがないことだけで除外しない |
| 支払情報/精密位置/連絡先/ゲーム内容 | アプリの明示送信なし。カード情報はApple側、ゲーム状態は端末内 | 本構成の明示送信について追加根拠なし。SDK全般の非収集保証とは別 |

Unity4.20.1のPrivacyInfo.xcprivacyは収集配列が空でRequired Reason API3種のみ。空配列は一般表の「収集あり」を覆す証拠ではない。Apple一般表は2021年時点と明記され現SDKの機能別条件が不足。通信傍受用証明書/新規端末識別子/権限は追加していない。公開回答は未変更。

一次資料:
- Google: https://developers.google.com/admob/ios/privacy/data-disclosure
- Unity iOS申告: https://docs.unity.com/en-us/grow/ads/privacy/apple-privacy-survey
- Unity同意API: https://docs.unity.com/en-us/grow/ads/privacy/ccpa-compliance
- Unity補助資料（Android、iOS確定回答に使わない）: https://docs.unity.com/en-us/grow/ads/privacy/google-data-safety
- Appleの収集/関連付け/任意同意の定義: https://developer.apple.com/app-store/app-privacy-details/
- 現行公開ラベル: https://apps.apple.com/jp/app/id6817160128
- 現行公開ポリシー: https://andy0911.github.io/tokaeshi/privacy.html

Unityへの照会文案（未送信）:
「iOS Unity Ads 4.20.1 + AdMob adapter 4.20.1.0、Banner Biddingのみ、Unity IAP/Analytics/Authenticationなし、独自user ID/購入metadata送信なし。privacy.consentは既定false、trueは明示同意・GDPR非対象・ATT許可時のみ。この構成の(1)User IDの自動生成/収集と分類、(2)購入履歴の自動検出有無と有効条件、(3)Acquire OptimizationによるiOS使用時間収集、(4)性能データの関連付け、(5)広告報告情報、(6)必要なApp Store収集カテゴリ/目的/関連付け/トラッキングを、各オプトアウト経路も含め説明してください。4.20.1の収集マニフェスト空配列と一般表の関係も確認したいです。」

### ユーザー実機操作を一度にまとめる最小案

現在の内部QA34だけを使う。広告はクリックしない。新しい同意/ATT許可やアカウント作成を強制しない。
1. InspectorのSingle ad source testがInactiveになったことを確認しアプリを完全終了・再起動。広告のプライバシー設定でUnityをオフにし、一度閉じて再表示してオフが保持されること、対局を始められることを確認。ATTは現在拒否ならそのまま。Googleの地域フォームが出ない地域では出ないことを不具合にしない。
2. TestFlight版で「広告を削除」を1回テスト購入（既に購入済みなら再購入不要）。購入ボタンと通常対局画面の「広告を削除」自社バナーが消え、再起動後も消えていることを確認。TestFlightの購入はAppleのsandboxで実課金なし。実App Store版では行わない。
3. 過去のsandbox購入を持つのに未購入表示の端末がある場合だけ「購入を復元」→同じ表示抑止を確認。購入済み起動では所有権が先に反映されボタン自体が消えるため、復元を試す目的でアプリ削除/ゲームデータ消去を求めない。起動復元と手動AppStore.syncの検証は別として記録する。

重要なQA限界: QA34は購入前から通常広告を停止しているため、実広告の非表示だけを購入成功の証拠にしない。手動診断バナーは購入状態を参照しない開発用経路であり、広告削除判定には使わない。購入UI/自社バナー/起動時所有権は確認可能だが、通常Release相当の表示中SDK広告の撤去、購入済み全画面の実機E2Eは未確認。必要なら実機接続済みDebug（GoogleデモID）でまとめて検証し、現QAで合格したことにしない。米国UMPの未公開フォーム検証も保留。

### 次の承認をまとめるための準備

現時点では公開承認を要求しない。先に上記StoreKit/実機とUnity申告の未確定点を解消する。承認前に公開用通常Releaseの最終archive/差分/最終ラベル回答とポリシー全文をレビュー可能に揃える。QA34はINTERNAL_ONLYでApp Storeへ流用できない。

その後、同じレビューで次の操作を明示して承認範囲をまとめる:
- 確定したApp Storeプライバシー回答の公開（特にGoogle4種Linkedの修正）と更新ポリシーの公開。
- 米国UMP下書き「トオカエシ iOS 米国州プライバシー」の公開時期。対象は同じAdMobアプリIDで旧1.1.2にも影響し得るため、旧版利用者の入口不足を含め確認して独立項目とする。欧州既存設定は維持。
- QAを除いた通常Releaseの新ビルド番号を確定し、App Store審査へ提出。一般公開は手動リリースを選ぶなど提出と公開を区別。
- 承認版が配布されたことを確認した後に本番バナーグループ1875657772だけを有効化し、表示率/エラーを確認。全画面1495466469は停止維持。停止による切戻し対象も同じバナーグループ。
- マージは別途明示対象。現在は未コミット/未マージ、既存review-reply-2.1.md保持。

今回App Store提出、一般公開、UMP公開、本番group有効化、ラベル更新、追加TestFlight配布は行っていない。

### 追補: StoreKit再調査・公開阻害要因の絞り込み

一時的に新規iPhoneシミュレータを作り再検証してもSKTestSession保存時のSKInternalErrorDomain Code=3が再現。既存端末のデータ状態だけが原因ではない。Xcode27/既存iOS26.5 runtime上のローカルテストサービス問題の可能性はあるが断定しない。新規アカウント、権限変更、証明書信頼追加はせず、今回の一時端末だけを削除。ログprerelease/storekit-fresh.log。一時テスト追加も戻した。

親から利用者へ送れる購入確認文:
「TestFlightを開き、トオカエシ1.1.3 (34)の『開く』から起動してください。タイトルの『広告を削除（¥300）』を押し、Appleの購入画面で商品名『広告を削除』とトオカエシを確認してテスト購入してください。TestFlightの購入はsandboxで実課金されません（価格表示は残ることがあります）。Sandbox／テスト購入／請求されない旨の表示があれば確認し、TestFlight版か不明なら確定せずその画面で止めてください。完了後、タイトルの購入案内と通常対局の『広告を削除』バナーが消え、再起動後も消えているかを教えてください。既に購入済みなら再購入不要です。未購入表示なのに同じsandbox環境で過去に購入済みの場合だけ『購入を復元』を押してください。アプリ削除は不要です。」
対象SKU: jp.andygrave.tokaeshi.removeads（非消耗型）。本番App Store版での購入操作は依頼しない。QA診断バナーは購入抑止検証に使わない。復元ボタンは購入済み認識後は非表示なので、購入直後に必ず押せるとは案内しない。現在未購入の人が購入前に復元を押しても、所有権なしの経路しか検証できない。
Apple根拠: https://developer.apple.com/documentation/storekit/testing-at-all-stages-of-development-with-xcode-and-the-sandbox （TestFlightはsandbox、テスト環境の購入には課金なし）。

公式のUnity問い合わせ先: https://dashboard.unity3d.com/dashboard-support （公式 https://unity.com/support-services のUnity Gaming Services supportからのリンク。現在cloud.unity.com/dashboard-supportへ転送）。既存UnityアカウントでUnity Ads/Monetizationについて投稿する。代替公式受付 https://support.unity.com/hc/en-us/requests/new?ticket_form_id=65905 。未ログインの取得結果ではフォーム詳細は確認できず、アカウント固有の投稿可否は未検証。メールアドレスは推測しない。未送信。

照会文案（短縮版）:
Subject: iOS Unity Ads 4.20.1 — App Store privacy disclosure for AdMob banner bidding
We use Unity Ads iOS 4.20.1 with Google’s adapter 4.20.1.0 for banner bidding (bundle jp.andygrave.tokaeshi). We do not integrate Unity IAP, Analytics or Authentication, and pass no custom user ID, purchase metadata or receipts. privacy.consent defaults to false; true is sent only after explicit permission, GDPR-not-applicable and ATT authorization.
Does this configuration automatically collect User ID or Purchase History? Is Other Usage Data collection conditional on Acquire Optimization for this iOS version? Please identify the applicable collected-data categories, purposes, linked-to-user and tracking flags, including opt-out behavior. The SDK’s collected-data manifest is empty while the Apple privacy survey describes collection; please provide the current, configuration-specific guidance. Thank you.

必要条件の整理: SDKの全通信を復号できること、全SDK記述の実測を公開条件にしない。Googleの4種（場所/デバイスID/製品操作/広告）のLinked=trueは現バージョンの直接資料とアプリ側に匿名化なしの事実で修正提案を作れるため、Unity回答を待つ事項ではない。現ラベルをそのまま使うことは避け、公開前にこの差分を承認対象にする。
Unityで回答確定に不足する中心はUser ID・Purchase Historyの自動収集と、Other Usage Dataの条件/プロジェクト設定。アプリに明示送信がないことだけでNoとはしない。その他データ（端末言語/モデル等）や性能については既存のUnity公式ガイドを申告案の根拠として扱えるが、現SDK固有条件を確認できたとは書かない。報告機能は利用可能性と任意開示条件の確認項目であり、これ単独で全公開作業を無期限停止と扱わない。実装/QA/公開用ビルド準備は並行可能。実機購入・復元と最終プライバシー回答のレビューが終わるまで審査提出は行わない。

## QA35: 通常対局画面の公式テストバナープレビュー

ユーザーの「広告が表示されている状態を確認したい」に対応。タイトルの「テスト広告を表示して対局」から2人対局へ入り、既存GameBannerView/AdaptiveBannerView/BannerViewControllerをそのまま用いた同じ幅・largeAnchoredAdaptiveBanner・SafeArea配置でGoogle公式デモバナーを表示する。QAナビゲーションに「テスト広告プレビュー」、広告クリエイティブにもGoogleのTest mode表示。広告タップは無効、盤面/手駒/終了操作は有効。タイトルへ戻るとプレビュー解除し通常対局へ引き継がない。

購入済み状態は変更しない。明示的なプレビュー入口だけで購入済みでも見え方を確認でき、通常対局は従来のhasRemovedAds判定を維持。小画面（850pt未満）の広告枠省略も本番と同じ。プレビューは購入・復元の検証には使わない。

配布準備構成: Release + MEDIATION_QA BANNER_PREVIEW_QA、1.1.3 (35)。旧Inspector/Unity診断入口を除外し、公式ID ca-app-pub-3940256099942544/2435281174だけを要求。旧QAユニット9486069744、本番8224074481/1465124825、承認端末ハッシュ/リソースはarchiveから不在を確認。通常の全画面要求はQAとして停止。Unityの本番広告要求はしない。地域別UMPの通常同意フローは維持し、未完時は準備中表示。

検証: 単体16件成功、iPhone17 Pro Max/iOS26.5シミュレータのUIテスト成功。実SDKから公式テストバナーを受信し、コンテナ幅=画面幅-24pt、下端が画面下端から20pt以上内側、盤とバナー非重複、盤タップと終了、通常対局でプレビューが解除されることを確認。テスト証拠qa35/preview-final-tests.log、qa35/ui-tests.log。表示画像qa35/tokaeshi-game-test-banner.png。

署名archive Tokaeshi-QA-1.1.3-35.xcarchive作成・署名検証成功。通常Releaseのビルドも成功し、プレビュー入口/バッジ/公式デモID/QAユニット/QAリソース不在、本番IDの保持を確認（qa35/production-evidence.json）。既存内部グループ用の説明qa35/notes.txt、配信確認スクリプトqa35/finalize.pyを準備。現時点ではアップロード未実施。本番/UMP/プライバシー公開/マージは変更なし。

最終UI追加確認: Googleテストバナー表示中に手駒「1」を選択して盤へ配置し、「初期配置2-2」への手番進行まで成功（qa35/ui-gameplay.log）。その状態の画像をLibraryへ保存: libfile_ce53f06ad86c81919c6a4edba6b6e17f / tokaeshi-game-test-banner.png。テスト以外のアプリソースは署名archive作成時と同一。未アップロード。

QA35内部配布完了: 明示指示により既存認証でアップロード。ASC build ID94fca650-f055-4e15-b90f-f621782cecf6、VALID / INTERNAL_ONLY / IN_BETA_TESTING、既存内部グループ所属とテスト説明保存をAPIで確認（qa35/distribution-evidence.json）。TestFlightで1.1.3 (35)へ更新し、タイトルの「テスト広告を表示して対局」を押すだけで開始。Inspector操作不要。SDK vendor dSYM警告は従来同様、アップロード/処理/内部配布は成功。App Store本番・外部配布なし。


## QA36: 850pt未満の明示プレビュー修正

ユーザー画像ではプレビューバッジは見えるが広告枠/準備中文字ともない。実機の論理画面高は画像から断定しない。QA35の850pt条件による枠省略をiPhone17e 390×844ptで再現（qa36/small-before.log、baseline成功）。明示QAプレビューだけ高さ条件を外し、同じadaptive bannerの枠を表示。通常公開構成の850pt条件と購入判定は維持。本番1.1.2相当commit0044b01でも同条件を確認でき、850pt未満ではGoogle要求自体が起きない。小画面の本番UI変更は別提案とし未実施。

枠右上「状態」からビルド番号、実際の判定画面高/広告サイズ、SDK準備、要求可否、受信/エラーdomain・code・messageを表示。未受信時も枠内に準備/読込状態を表示。広告はタップ不可のまま、状態ボタンだけ操作可能。

検証: 16単体テスト成功。844ptのUIテストは初回EEA同意のDo not consentを操作して成功。大画面iPhone17 Pro Maxも成功。両方で実Google公式demo受信、幅=画面幅-24、画面下20pt以上内側、盤との非重複、手駒1選択→配置→初期配置2-2、診断sheetの受信済み表示、タイトル→通常対局ではプレビュー解除→再びプレビューで再受信を確認。初期失敗はUMPフォーム/既存Apple Account確認にテストが遮られたもの。テストに拒否/キャンセルを追加し、認証情報入力/新規権限許可は行っていない。

証拠qa36/small-final.log、qa36/large-retest.log、qa36/small-screenshots、qa36/large-screenshots。両スクリーンショット実画素確認済み。844ptの画像Library: libfile_2687555f3a188191b7807d05716e6057。

QA36署名archive成功。公式demoIDあり、旧QA/本番banner・interstitialIDなし、端末登録リソースなし（qa36/binary-evidence.json）。通常Releaseもbuild成功、プレビューバッジ/状態UI/demoIDなし、本番ID保持（qa36/production-evidence.json）。本番広告設定・公開UI・UMP公開・App Store提出・マージは変更していない。

QA36内部配布完了: ASC build ID 1d5f06c0-ce38-4363-96c0-06bfdc8cceb0、VALID / INTERNAL_ONLY / IN_BETA_TESTING。既存内部グループ所属、テスト説明保存、autoNotifyEnabled=trueを確認（qa36/distribution-evidence.json）。署名verify成功。1.1.3 (36)でタイトル「テスト広告を表示して対局」を選ぶ。表示できない場合も枠右上「状態」で実測画面高と準備/受信状況を確認可能。実ユーザー端末での再確認は未実施。本番850pt制限の変更案は、小画面向け標準anchored adaptiveサイズと盤/手駒の最小寸法を先に検証し、条件を見直す別変更として扱う。未実装。


## QA37 / 常時バナー枠のリリース準備（公開前）

ユーザー承認: 未購入者は広告を取得できたら収益広告、取得前/失敗/在庫なし/同意による要求不可時は既存「広告を削除」のローカル案内を出す。850ptによる枠省略を廃止。購入済みには両方と枠を表示しない。初回の所有権照合中も既購入者への一瞬の表示を避けるため枠を作らず、照合後の未購入者に案内を表示する。広告の供給・収益は保証しない。

実装: BannerPresentationでloading/received/failed/stoppedを管理。広告世代・要求許可・サイズの変化でSDKビューと状態を一緒に破棄し、遅いcallbackは無効化。更新失敗時は旧広告を隠しローカル案内へ切替。失敗SDKビューを破棄後に30秒待って再生成するためSDK自動更新と並走させない。バックグラウンド中の失敗再試行は停止、復帰時に再開。購入/復元/返金の所有権更新に追従。StoreManagerの所有権再読込では古いtrueを持ち越さない。

レイアウト: 850pt未満は標準320×50、以上は従来largeAnchoredAdaptiveBanner。750pt未満ではプレイヤー行の縦余白を減らし、手駒を44pt高/48pt幅の横スクロールにする。通常の手駒も44pt高へ変更。案内は既存の文言/商品価格を再利用し、外部リンクを追加しない。
根拠: Google公式test-adsは固定バナー2934735716、adaptive2435281174を区別（https://developers.google.com/admob/ios/test-ads）。Unity iOS公式banner例は320×50とSafe Area内配置（https://docs.unity.com/en-us/grow/ads/ios-sdk/banner-ads）。Google13.10の旧standard-adaptiveサイズAPIは非推奨のため固定サイズを採用。SDK自動更新と失敗時要求の注意: https://developers.google.com/admob/ios/banner 。

計測: localPromo露出、SDK impression、SDK paidイベントを別のカウンタ/OSログにする。テストimpressionは本番impressionと別、デモpaidは本番paidへ数えない。新しい外部分析SDK・識別子・外部送信は追加しない。カウンタはセッション内のみであり、AdMob売上集計の代替ではない。AdMob課金impressionを自社案内から擬似生成しない。

QA: 既存preview入口からGoogle公式テスト広告のみ。上部プレビューボタンで在庫なし/通信失敗/SDK待ち/同意停止/購入済み/復元済みを模擬。実ネットワーク・同意・購入設定は変えない。失敗はネットワークを使わず同じ失敗callbackへ注入。実際に購入済みの場合はQAでも枠非表示を優先。プレビューで広告と購入案内はタップ不可。通常QA対局は本番広告要求を禁止したままローカル案内を表示。

公開前の未確定事項: Unityサポート00938523の回答待ち（親から受付番号を受領）。User ID/Purchase History自動収集とOther Usage Data条件の不確定点を維持。StoreKit実購入/復元は今回の表示模擬テストと区別し未完了。過去のローカルSKTestSessionはSKInternalErrorDomain code3で成立していない。公開プライバシー/UMP公開/本番メディエーショングループ有効化/審査提出/一般公開/マージは未承認のまま変更しない。


QA37検証結果: 単体20件/7suite成功（qa37/small-retest.log）。最終UIは667pt（qa37/se-final.log）、844pt（qa37/844-final.log）、956pt（qa37/large-final.log）で成功。実Google公式demo受信、模擬no-fill/offline、SDK準備/同意停止、購入/復元済み条件で枠・案内非表示、再受信、バックグラウンドから復帰、駒選択・配置・手番進行、タイトル往復を確認。667ptでは右端のB駒まで横スクロールで到達できることを追加確認。実測: 667ptの盤351×351・手駒48×44・広告320×50、844ptの盤366×366・広告320×50、956ptの盤約396×396・広告416×130。下端/盤面との重複なし。最小画面と844pt・大画面の自社案内画像を実画素確認。画像Library libfile_8abddb328cf08191ad351269693ad477。

途中の初回同意フォーム遅延/非表示要素の取得、およびXcodeの結果集約停止はテスト操作/実行環境として切り分け、操作可能な拒否ボタンの選択とcollect-test-diagnostics neverで最終実行が成功。アプリの同意を迂回せず、認証情報入力や新規権限許可なし。成功ログと失敗ログ双方を保持。

最終通常Release build成功（qa37/production-final.log）、テストID2種/QA UI/登録リソース不在、本番ID保持（qa37/production-evidence.json）。署名QA37archive成功・署名verify成功。QA37は公式demoID2種のみで本番/旧QA枠/端末ハッシュ不在（qa37/binary-evidence.json）。公開前の未確定事項は上記のまま。

通常Release署名アーカイブをローカル準備: Tokaeshi-Release-1.1.3-38.xcarchive（未アップロード）。署名verify成功、通常本番ID保持、公式demo/旧QA ID・QA UI・端末ハッシュ不在、自社案内あり（qa37/release-archive-evidence.json）。公開候補の準備物であり、前述のプライバシー/実取引確認・公開承認が完了したことを意味しない。

QA37内部配布完了: ASC build ID 2d63ad6f-2ae5-44be-9cbd-875982ec907f、VALID / INTERNAL_ONLY / IN_BETA_TESTING。既存内部グループ所属、テスト説明保存、通知有効を確認（qa37/distribution-evidence.json）。App Store提出/一般公開、UMP/プライバシー公開、本番メディエーショングループ有効化、マージは行っていない。既存未コミット変更とreview-reply-2.1.mdを保持。


## 1.1.3 (38) 審査申請準備

ユーザーが「じゃあ申請まで進んでください」と明示承認。申請までの承認で、一般公開は手動で止める。本番メディエーショングループ有効化/UMP公開は含めない。

申請前確認: ASCに1.1.3なし・38なし・進行中審査なしを確認。通常Release38署名verify、QA ID/UI不在、本番ID保持、QA37検証時のBannerソースhash一致。ユーザー実機画像libfile_1937d18debf8819185bf4a4f44c4c550ではQA37「実所有権:購入済み/照合:完了」「SDK準備:完了」「状態:購入済み・枠非表示」を確認。今回の枠非表示は購入抑止どおりであり、ownership待機仮説はこの端末の原因ではなかった。購入日時/実課金/購入・復元操作そのものは未確認。

1.1.3ドラフトをAPI作成: version ID724ef29a-2803-4694-81cb-5c30992b7a3f、releaseTypeMANUAL。日本語更新説明と審査メモを保存。既存連絡先/description等を保持。6.5インチ既存スクリーンショット3枚はCOMPLETE。審査メモは小画面320×50・手駒スクロール・自社案内・所有権照合中の抑止・Unity SDK含有とグループ無効を説明し、購入/復元試験済みや広告常時供給を断定しない。review-reply-2.1.mdはユーザー既存文書として変更しない。

通常Release38をApp Store eligibleとしてアップロード成功。証拠と文案はsubmission38/配下。ブラウザツールがないため、親指定のブラウザ担当向け手順をsubmission38/browser-handoff.txtに作成。App Privacyの現行回答/未回答質問を読み取り確認し、Google4種Linked false→trueを具体的修正案として提示する。現在の公開申告に影響するため、親に内容を返し確定前にPublishしない。Unity照会00938523は親11:44UTC確認で受付自動返信のみ。User ID/Purchase History等の未確定をNoとして提出しない。

実購入/復元の未実行は確認範囲の限界であり、新バージョンの必須実取引試験を完了したという申告はしない。既存承認済みSKUの継続、所有権抑止の実機確認、単体/UI模擬試験とは区別する。申告未確定を解決せず一般公開/審査送信は行わず、現在は準備段階として報告する。

38処理完了・関連付け済み: ASC build ID53bc9465-ed14-40f9-b707-8f91756eb763、VALID / APP_STORE_ELIGIBLE。1.1.3へbuild38設定済み、releaseTypeMANUAL、versionStatePREPARE_FOR_SUBMISSION（submission38/prepared-evidence.json）。審査待ち/審査中ではなく、申請送信は未実施。最終プライバシー回答と公開差分の判断を親へ返す。


### 2026-10-04 表示機会の復旧修正とPangle準備（未配信）

ユーザー「全部やって」に基づき、Unityを維持して表示処理の問題を修正。UMP失敗時もSDK自身のcanRequestAdsを確認し、要求不可の通信失敗だけ30/60/120/240/300秒で再試行する。正常に確定した同意拒否は繰り返さない。前面復帰にも重複/期限ガードを適用。StoreKit価格取得を所有権照合後の独立Taskへ分離し、価格取得遅延による広告開始待ちを解消。

バナーは取得失敗時も可視のSDKビューを保持し、AdMob設定の自動更新に一任。独自30秒再loadと前面復帰時の即再loadを削除。案内はSDKビューの背面に置き、広告クリエイティブを覆わない。保持されたViewの再表示時はstoppedからloadingへ復帰。購入/未照合の非表示、同意変更による世代更新は維持。

検証: 単体25件/8 suites、Google公式テスト広告UI（844pt、受信後foreground/模擬失敗/購入済み非表示/再入場）、通常Release arm64ビルドに成功。実際の通信断からのSDK自動更新間隔とStoreKit実取引は未実測。build39はローカル検証番号でアップロードなし。既存申請下書きbuild38は変更していない。証拠は /Users/t.hanano/Documents/Codex/2026-10-04/task-2/revenue-recovery/ 内のevidence.json、unit-final.log、ui.log、release.log。

Pangle ROWはiOSバナー入札対応。Google公式adapter c7c1a3c5072e56e213cfc1fc2c83b79785a98c74（8.3.0.8.0）/Pangle8.3.0.8/Google13.10.0を隔離プロジェクトでビルドし、PAConsent.noConsent APIを検証。本体への追加・SDK実行・広告要求なし。Pangleアカウント/契約/アプリID/入札枠IDは未確認。AdMobのAcknowledge & agree、新規登録情報・契約の承認が必要。ブラウザ担当向け詳細は同作業領域 pangle-preparation/handoff.txt。

Pangleの同梱宣言（UserID/DeviceID/AdvertisingData/CrashData/PerformanceData/CoarseLocation/OtherDataTypesはいずれもLinked=true）、アプリの実構成・同意伝播・ポリシー/申告を照合してから組み込む。公式SKAdNetwork例のうち現行にないdbu4b84rxf.skadnetworkは追加候補として記録のみ。320x50と大画面adaptiveのsingle-source表示確認、QA設定から本番へ進める条件確認が残る。Unityサポート00938523の実質回答待ちは継続。AdGenerationは別担当で新規契約要件を確認中。

公式根拠: https://developers.google.com/admob/ios/privacy / https://developers.google.com/admob/ios/banner / https://developers.google.com/admob/ios/mediation/pangle / https://www.pangleglobal.com/integration/ios-initialize-pangle-sdk / https://www.pangleglobal.com/integration/ios-banner-ads


### 2026-10-04 QA39内部配布完了 / 通常Release40候補（未アップロード）

表示復旧修正をQA39へ含め、追加の統合UIテスト後に内部TestFlightへ配布。build ID 2da5e5f5-9cf9-4c04-a666-6e2f79498517、VALID / INTERNAL_ONLY / IN_BETA_TESTING、既存内部グループへの反映・日本語テスト説明保存を確認。

単体25件/8 suitesとUI2件が成功。DEBUG限定の初回UMP通信失敗注入→30秒cooldown→実UMP→Google公式テスト広告受信を確認し、期限前のforegroundで再試行しないことも検証。QAの「失敗→Googleテスト広告（模擬）」は同じcontrollerを保持したまま5秒後にGoogle公式デモへ初回通信し受信する。受信後foreground、案内、購入/復元済み非表示、対局再入場も通過。実回線断やSDK自動更新の実時間間隔は未実測であり、この模擬試験と区別する。

QA39署名済みバイナリにはGoogle公式バナーID2個のみ含まれ、本番バナー8224074481・全画面1465124825・旧QA枠9486069744と端末登録リソース/ハッシュは含まれない。DEBUG専用の初回同意失敗注入引数もTestFlight版には含まれない。Unityは維持、Pangle/AdGeneration SDKは追加していない。

通常Release40は署名付きarchiveとIPAをローカル生成済み。/Users/t.hanano/Documents/Codex/2026-10-04/task-2/release40/export/Tokaeshi.ipa。本番IDの存在、GoogleテストID全prefix/QA UI/失敗注入の除外、署名、build38からPrivacyInfo.xcprivacyが不変であることを検証。アップロード/申請提出なし。既存1.1.3下書きはbuild38（53bc9465-ed14-40f9-b707-8f91756eb763）/PREPARE_FOR_SUBMISSIONのまま。App Privacy・Unity条件の確認完了後に差替候補をアップロードする。

検証/配布証拠: 作業領域qa39/test-evidence.json、binary-evidence.json、distribution-evidence.json、tests.log、upload.log、screenshots/。通常候補はrelease40/binary-evidence.json、ipa-evidence.json、privacy-evidence.json。アップロードではGoogleMobileAds/UnityAdapter/UnityAds/UMPのベンダーdSYM不足警告が出たが、アップロードとApple処理は成功。アプリ自身のdSYMはarchive内に生成済み。SDK内部クラッシュのシンボル解決はこの制約が残る。
