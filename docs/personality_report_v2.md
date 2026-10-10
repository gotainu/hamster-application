# 個性レポート v2 — ローカル実装・リリース前契約

2026-10-10。今回の対象はローカル実装・自動テストのみ。本番deploy、Firestore本番書込み、SQL実行、AI/RAG、APK build、実機操作は行わない。v1研究versionと生成済みGoldを保持する。

## 日次発行

- 日本時間の暦日。毎朝09:00 JSTの `personalityDailyReports` が、前日までの有効記録を採用する。
- `personalityHealthFeaturesWritten` は**現在日**の確定Silverで旧v1のready構成別発行を維持し、その後に日次queueを予約する。両処理は冪等。過去日のイベントpayloadやcurrentStatusの一時的な揺れをレポート確定に使わない。
- `personalityDistanceRecordWritten` は当日の活動記録のqueue-only bridge。既存health distance triggerの当日early returnを維持したまま、翌日の既存reader/builderによるmemory previewで予約する。Silver/健康評価/firstはこのbridgeから書き込まない。
- 発行条件は、ready指標の最新有効**記録日**が前回report/予約のwatermarkより進んだこと。同じ数値でも新しい記録日なら対象になる。
- SilverのupdatedAt/generatedAtだけの変化、同一日の数値訂正、既知の最新記録日より古い日を補うbackfillは新規発行理由にしない。複数記録・retry・並行処理でも評価日ごとに最大1件。
- schedulerは全usersを走査せず、dueAtが到達したqueueを1回最大100件、ユーザーごとに直列処理する。未処理分は待機を継続する。個別失敗はmetadataだけ記録し翌朝へ延期し、他ユーザーの処理を妨げない。
- 朝の処理では既存 `fetchHealthSourceData` / `buildDailyHealthFeatures` を再利用し、前日cutoffでfresh Bronzeを分析する。中央値/MAD/EWMA式を再実装しない。古いSilverを現在値と呼ばない。
- 当日Silverが欠けている場合だけtransaction createする。存在するSilverは上書きしない。Goldのcutoff分析がcurrent Silverと異なることは `featureSnapshotSource` とprovenanceで明示する。
- activityのD-1対象に記録がない場合、Goldのlatest pointだけ最新有効記録へ補完する。baselineは既存builderの結果をそのまま使う。
- report、生成metadata event、latest pointer、queue acknowledgmentをtransactionで確定する。読み取り中に入った次の記録日の予約を失わない。
- v1 publisherは従来の `personality` pointerだけを操作し、daily publisherは独立した `personality_daily` pointerだけを操作する。日次の前回観測watermarkはdailyを優先し、その不存在時だけv1を使う。既存v1 Goldとfirstは書き換えない。

## Firestore構造

| path | データ・権限 |
| --- | --- |
| `personality_report_queue/{uid}` | server-only。schemaVersion/uid/dueDateKey/dueAt/latestValidDates/sourceDateKey/queuedAt。失敗時attemptCount/lastAttemptAt/lastAttemptStatus。健康記録本文を持たない。 |
| `users/{uid}/personality_reports/daily_YYYY-MM-DD` | immutable Gold。schemaVersion=1/analysisSpecVersion=personality_v1を維持。reportKind=daily、evaluationDateKey/cutoffDateKey、入力fingerprint/latestValidDates、生成時のbaseline/latest値/比較研究version/解釈/provenanceを保存。owner read、client write禁止。 |
| `users/{uid}/report_pointers/personality` | v1のready構成別reportIdだけ。旧クライアントの契約を維持。server-only write、owner read。 |
| `users/{uid}/report_pointers/personality_daily` | 最新の日次reportId、評価日、readyMetrics等。v2が優先。server-only write、owner read。 |
| `users/{uid}/report_view_states/{reportId}` | reportId/viewedAtの2フィールドだけ。owner read、既存reportへのserverTimestamp付きcreateだけ許可。update/delete禁止。 |
| 旧 `personality_v1_body` / `personality_v1_activity` / `personality_v1_body_activity` | 新fieldなしでも従来schemaで閲覧可能。既存docを更新しない。 |
| `users/{uid}/personalized_reports/first` | 従来どおり完全不変。本日次処理は参照更新・再生成しない。 |

singletonのlastViewedReportIdは使わない。reportごとの不変markerにより、過去の閲覧・並行端末からの更新が最新未読を誤って既読にしたり、以前の既読を戻したりしない。

## UI / Home / 履歴

- `MetricComparisonBar` は保存済み2値と任意の参考範囲だけを表示する。値が範囲外なら軸を広げ、一致時は上下の別marker/凡例で区別する。finiteな2値が揃わなければplotを省略する。
- 体重は普段の値を大きく表示し、適用可能な場合にだけ研究中央値・IQRの比較を表示する。IQRは健康上の正常範囲、percentile、健康スコアではない。
- 活動量は個体内baselineと生成時のlatest pointを比較する。集団rankingやMAD=0からの正常範囲を作らない。628.318530…は通常表示628m/日、詳細も読みやすい桁数にする。
- AppTheme、StatusCard、既存icon/数値レイアウト、ExpansionTile、既存navigationを使う。HealthScoreGaugeは使わない。
- snapshotの作成日時、期間、記録数、中央値/MAD、分析spec、保存済み研究出典/DOI/適用条件/限界を詳細で確認できる。文字拡大、狭幅、light/dark、Semanticsに対応する。
- Homeはlatest pointerの**最新未読だけ**を表示する。Homeカード描画では書き込まない。レポート**詳細画面**の表示成功後だけ、そのreport IDの既読を保存する。既読後は常設入口も残さず消え、新しいreportで再表示する。健康heroと重要anomalyが先行する。
- v2 readerは `personality_daily` を優先し、サーバー確認済みの不存在時だけv1 `personality` に戻る。cache/pending/error/malformed値ではfallbackしない。日次到着・削除・owner切替に伴う遅延snapshotも分離する。旧v1 readerは従来pointerとv1 IDだけを読み続ける。
- 両指標readyなら旧常設firstカードをHomeから除く。不足指標がある場合は分析準備状況を維持する。
- Drawer「レポート履歴」から新旧個性レポート、既存firstへアクセスできる。生成日時降順/document ID降順、20件ごとのserver read。account switchで行/cursorを消し、別ownerへ引き継がない。
- 履歴detailは指定report IDを読み、現在の最新pointerを代用しない。過去reportの閲覧はそのreportのmarkerだけを作る。
- 詳細routeは開いたownerへ固定し、アカウントが切り替わっても別ownerの同一IDを表示・計測しない。旧firstもserver確認済み不存在を明示し、永久spinnerを避ける。
- A3初回markerとpersonalized_report_viewedのmetadata計測を維持する。個体名・記録数値・自由記述をAnalyticsへ送らず、AI相談枠も使用しない。
- 旧版はreport単位の既読markerを持っていないため、globalな初回A3日時から特定reportを既読と推測しない。

## 本番適用順序（今回は未実施）

1. 現行本番source/Rules/configと比較した**隔離候補**を構成する。通常dirty treeから直接deployしない。latest activity today修正とfirst freezeを維持し、health/課金/trial/RAG等の差分混入を確認する。既存 `personality` がv1 IDを指すことをread-onlyで確認する。daily ID等の予期しない既存値なら停止し、勝手にpointerを書き換えない。
2. 現行本番Rulesへ `personality_daily` のowner-read/server-write-only、`report_view_states`、server-only queueの必要な追加分だけを統合する。Emulator権限テスト後、Functions・新Flutterより先に適用する。既存record/プロフィール/billing権限を保持する。
3. queue `dueAt` と履歴 `generatedAt` / document IDのindex利用可能性、Scheduler/IAMを確認する。更新 `personalityHealthFeaturesWritten` と新 `personalityDistanceRecordWritten` / `personalityDailyReports` の3関数だけを隔離sourceから適用する。asia-northeast1/JST09時、trigger/retry/service accountをread-backする。既存health Functionsを一括deployしない。
4. 分離pointer・旧v1表示・日次発行・重複ゼロ・firstと既存v1 Goldの不変性をスモーク確認する。旧アプリは従来v1 pointerを読み、新アプリ公開前の日次発行でも壊れない。
5. 検証済みv2 Flutterを別承認のbuild/配布工程で適用する。最新未読→詳細表示→Home非表示→新report再表示→過去履歴の既読分離を実機で確認する。今回APK生成・導入は行わない。
6. 研究seed/version・既存SQLの変更は不要。既存event名とpet/report/revision identity JOINを再利用する。一般UIDの既存analytics ingest境界を勝手に広げない。

rollbackは新発行scheduler/queue bridgeを停止し、退避したv1 personality trigger/source、Flutterへ対象別に戻す。新v2 clientが残る間は追加のowner-read/client-write-deny Rulesを維持し、必要な読取権限を先に撤去しない。生成済みdaily/v1/first、研究version、既読markerは削除/書換しない。旧pointerを維持したので、v1アプリへのrollbackにデータ変換は不要。復元操作にはその時点の明示承認と隔離source確認が必要。

## リリース前最終調整の検証（2026-10-10）

- v1互換性：PASS。日次writerのpointer分離、旧v1 publisher継続、fallback/frontier、既存v1 Gold/firstのhashとupdateTime不変を検証。未変更の実staging v1 repo/modelに、現backendのEmulator生成Goldを渡す互換replayも2/2 PASS。
- 閲覧済み処理：PASS。既存production実装の変更は不要。actual Home/detail/history経路で描画write0、詳細表示後だけ対象report既読、カード完全消去、次report再表示、過去閲覧でlatest未読を維持を検証。
- queue上限：PASS。103件のうち初回100処理（99成功/1延期）・3件overflowを保持、別呼出で3成功、翌朝に失敗1件復旧。各UIDのdaily/eventは1件。並行実行と再試行も重複ゼロ。古い失敗workerはquery時updateTimeをtransactionで照合し、新しい予約を延期・変更しない。
- 関連Functions 108件（unit61、daily Emulator28、旧Gold/backfill Emulator19）、Rules88件（新pointer/既読30、既存権限58）、Flutter関連60件、実旧v1 reader互換2件：すべてPASS/exit0。Functions全source strict noEmit、Flutter全体analyzeもPASS/No issues。
- テスト先行：pointer/Rules/triggerの修正前失敗を確認後、最小source修正で成功を確認。今回の回帰は関連対象に限定し、前工程の全Flutter199件を再実行した数値として流用しない。
- 変更12ファイル（source4、Rules1、tests5、docs/status2）。開始時568ファイルの残り556はbyte不変、削除0、対象外変更0。first freeze/health/Silver統計/課金/trial/AI/onboarding/依存ファイルを維持。
- 本番/実機/Git/Known Good操作なし。専用loopback Emulatorのdemo projectとoffline mockだけを使用。証跡：`/private/tmp/hamcare-personality-v2-release-adjust-20261010/`。
- 残る運用制約：schedulerは1日1回・1回100件。overflowは消えず、通常は翌朝以降へ持ち越す。成功returnはScheduler retryを発生させず、同日2回目の自動drainはない。待ち時間と処理量を本番適用時に監視する。

### 今回変更したファイル（12）

- Functions source：`functions/src/health/personalityDaily.ts`、`personalityReport.ts`、`personalityTriggers.ts`。
- Flutter source：`lib/services/personality_reports_repo.dart`。
- Rules：`firestore.rules`。
- Backend tests：`functions/test/personality_daily_emulator.test.cjs`、`personality_trigger.test.cjs`、`personality_view_rules_v2.test.cjs`。
- Flutter tests：`test/personality_reports_repo_test.dart`、`personality_report_release_candidate_test.dart`。
- Documentation：`docs/personality_report_v2.md`、`PROJECT_STATUS.md`。

## Phase1–3の検証と保護（前工程）

- Backend: 単体97、旧Gold Emulator9、旧Bronze→Silver補完10、日次Emulator21、計137件PASS。
- Rules: 新既読24、既存個性/記録権限58、既存Firestore45、計127件PASS。変更していないStorage7ケースは対象外。
- Phase2: 比較bar/画面/旧UI回帰51件PASS。実Emulator daily Gold body/activity/bothからの表示も含む。
- 全Functions source strict noEmit PASS。通常repoの一部依存ファイル読取り待ちを避け、同versionの既存v1 staging dependency lookupだけを一時configで参照。通常package/lock/tsconfig/compiled libは変更しない。
- Phase3: model/repo/既読/履歴/旧first/Home E2E関連66件PASS。Phase2/3の部分実行数には全Flutterとの重複がある。
- Flutter全体 analyze --no-pub はNo issues／exit0。全Flutter test --no-pubは199件PASS／exit0（416秒）。
- 作業開始時553ファイルのうち、承認範囲23ファイル（進捗記録含む）を更新、530ファイルはbyte不変。新規15ファイル、既存削除0、対象外変更0。
- first freeze、health pipeline/trigger、Bronze読取、Silver統計、trial/billing/AI、onboarding repo、記録保存source、package/lock、compiled libは作業開始時からbyte不変。
- 専用loopback Emulatorのdemo projectとoffline Widget mockのみを使用。本番Test User B、他ユーザー、Known Goodには触れない。

## 追加・変更ファイル（38ファイル）

- `PROJECT_STATUS.md`
- `docs/personality_report_v2.md`
- `firestore.rules`
- `functions/src/health/personalityDaily.ts`
- `functions/src/health/personalityReport.ts`
- `functions/src/health/personalityTriggers.ts`
- `functions/src/index.ts`
- `functions/test/personality_daily_emulator.test.cjs`
- `functions/test/personality_trigger.test.cjs`
- `functions/test/personality_view_rules_v2.test.cjs`
- `lib/models/personality_report.dart`
- `lib/screens/home.dart`
- `lib/screens/personality_report_history_screen.dart`
- `lib/screens/personality_report_screen.dart`
- `lib/screens/personalized_report_screen.dart`
- `lib/screens/tabs.dart`
- `lib/services/app_analytics.dart`
- `lib/services/personality_report_view_service.dart`
- `lib/services/personality_reports_repo.dart`
- `lib/widgets/analysis_progress_card.dart`
- `lib/widgets/main_drawer.dart`
- `lib/widgets/metric_comparison_bar.dart`
- `lib/widgets/personality_report_entry.dart`
- `test/analysis_progress_card_test.dart`
- `test/fixtures/personality_v2_daily_gold_activity.json`
- `test/fixtures/personality_v2_daily_gold_body.json`
- `test/fixtures/personality_v2_daily_gold_both.json`
- `test/metric_comparison_bar_test.dart`
- `test/personality_report_entry_test.dart`
- `test/personality_report_history_test.dart`
- `test/personality_report_model_test.dart`
- `test/personality_report_release_candidate_test.dart`
- `test/personality_report_screen_test.dart`
- `test/personality_report_v2_ui_fixtures.dart`
- `test/personality_report_v2_ui_test.dart`
- `test/personality_report_view_service_test.dart`
- `test/personality_reports_repo_test.dart`
- `test/personalized_report_actual_view_test.dart`

前工程の検証ログ: `/private/tmp/hamcare-personality-v2-20261010/`。最終調整後も本番・実機での確認、本番index/Scheduler/IAM、100件上限による待機量確認は別承認の本番適用工程に残る。旧v1混在は独立pointerで互換性を維持する。未解決のテスト失敗・lintはない。
