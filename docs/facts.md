# 共通の事実データ（合議で全員に渡してよい唯一の材料。意見・評価は書かない）

更新するときは、出典と取得日を必ず書く。

## 実績値（取得: 2026-10-25）
- 出典: App Store Connect Sales API、AdMob。
- 直近30日（9/25〜10/24）: 新規DL 3件、AdMob収益 約25円、表示 164回、eCPM 約152円（AdMob単独。Unityグループは一時停止中の記録＝10/4時点、最新は未確認）。
- 配信中のビルドは1.1.6（build 33、2026-10-11からREADY_FOR_SALE。出典: App Store Connect、2026-10-25確認）。Unity Adsアダプター（コミット 9fd6cb9）は1.1.4より前から入っており、Unity入りビルドが配信済み。
- Apple Ads（トオカエシ）は未出稿。同アカウントの他アプリのCPI実績は 376〜801円。
- 外部分析SDKはなく、DAU・継続率は未計測。

## 直近の週（取得: 2026-10-27）
- 出典: scripts/weekly_kpi.py（ASC Sales）、scripts/admob_report.py。
- 10/20〜10/26: 新規DL 1件（10/26は未公開で欠損）、IAP 0。AdMob 表示 5回、収益 約1円、eCPM 約209円。
- 未マージの準備物: Search Ads案B（campaign 2件、PAUSED、費用なし）、ストア表現の決定案、Xの自動投稿スクリプト（approved=false）、App Analytics取得スクリプト（report request未作成）。初回導線の文言・候補マス・本戦前の1行はmain反映済み（#29）。1.1.7は未提出。
- 先行する順序の決定: 1.1.7にストア表現を同乗 → 反映確認 → Xの初投稿 → 8日目にSearch Ads案B。

## 週の途中（取得: 2026-10-30、暫定）
- 出典: scripts/weekly_kpi.py、scripts/admob_report.py。
- 10/22〜10/28のASC Sales: 新規DL 0件、IAP 0（10/29以降は未公開）。AdMob 10/23〜10/29: 表示 5回（10/23のみ）、収益 約1円。10/27〜10/29は表示0。

## 固定条件
- 目標: 広告収入で毎月5,000円。予算は月1万円まで（トオカエシ個別）。撤退ライン3ヶ月（撤退＝投資停止、アプリは消さない）。
- 算術: 月5,000円＝日約167円＝eCPM 152円で日約1,100表示。
- お金がかかる操作・広告の変更・審査提出・App Storeメタデータ反映は、あんでぃさんの明示の承認後。
- 原案者クレジット「原案: @bdgame_」。「オセロ」は商標のため使わない。

## 読んでよいリポジトリ資料
docs/spec.md、docs/admob-mediation.md、README.md、App/ 配下。運用レビューは /mnt/project-files/reviews/tokaeshi-ops-review-2026-10-24.md（事実の参照のみ。結論の提案部分は意見なので鵜呑みにしない）。
