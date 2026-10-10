# うちの子の個性レポート v1（ローカル実装）

本番deploy、seed、バックフィル、SQL実行、実機操作は未実施。本番データを変更しない。

## データ契約と接続

既存Bronze、Silver schemaVersion=5、中央値/MAD/EWMAの計算式はそのまま。
`personalityHealthFeaturesWritten` が `users/{uid}/daily_health_features/{dateKey}` の書込みを受け、当日（Asia/Tokyo）の確定Silverだけをtransaction内で読み直す。
歴史日付のイベント、削除イベント、`analysis_readiness` の一時的なlearning/ready遷移を発行根拠にしない。既存firstの早期returnとは独立する。
現在のアプリが扱う個体は `pet_profiles/main_pet`。複数個体への拡張はこの仕様に含めない。

- `reference_cohorts/{speciesCode}_adult_weight`: currentReferenceVersionを持つ比較基準ポインタ。
- `reference_cohorts/{cohortId}/versions/{referenceVersion}`: immutable研究基準、中央値/IQR、適用条件、出典、データ品質。
- `users/{uid}/personality_reports/personality_v1_body|personality_v1_activity|personality_v1_body_activity`: immutableレポート。
- `users/{uid}/report_pointers/personality`: 最新reportIdと発行済みready指標集合。
- `users/{uid}/analysis_events/personality_report_<reportId>`: レポート発行と同時に作るmetadata-only生成イベント。

レポートはschemaVersion/analysisSpecVersion、評価日/Silver日付/生成日時、種と誕生日・年齢、ready指標、個体ベースライン/最新値/差、観察期間/件数、固定した研究基準/出典、解釈コード/日本語文/限界を保存する。個体名、memo、飼い主情報、AI質問/回答はコピーしない。
保存済みreportへのset/update/deleteはない。発行済みready集合の後退・再到達・日次更新・研究基準変更では追加発行しない。ready指標が増えたときにだけ新規作成しpointerを更新する。同じ構成のIDは決定的で、並行・再試行でも一つ。遅延した旧評価日は新しいpointerを戻さない。

## 比較基準

出典: O'Neill et al. (2022), Journal of Small Animal Practice, DOI 10.1111/jsap.13527。
https://pmc.ncbi.nlm.nih.gov/articles/PMC9796486/

英国VetCompassの2016年の獣医診療集団。生後3か月超の各個体の体重記録平均を取り、その種別分布の中央値/IQRを報告した研究であり、健康な一般集団の診断基準ではない。

| speciesCode | median g | p25 g | p75 g |
| --- | ---: | ---: | ---: |
| syrian | 133 | 100 | 160 |
| djungarian | 45 | 34.5 | 58 |
| roborovski | 25 | 20 | 30 |
| campbell | 46 | 38 | 50 |

生年月日が既知で、評価日と体重baseline最古日がともに生後3か月超の場合だけ比較する。幼齢期を含むbaseline、不明種、誕生日不明では個体内の説明のみ。
研究の個体別平均と、この子の記録中央値という統計量の違いを明記する。種別集団数と体重測定の有効標本数を区別し、後者は未公表なのでweightSampleN=null。キャンベルは少数集団として注意を表示する。
IQRとの位置関係のみを示し、percentile、肥満/健康診断、活動量の同種ランキングを算出しない。MAD=0から全記録が同じとは言わず、EWMAから長期傾向、日別記録から夜型とも言わない。

## ローカルseed／バックフィル

Node 22と既存functions依存物を使う。スクリプトはsourceをメモリ内で読み、既存libを上書きしない。

```sh
cd functions
/Users/gota/.nvm/versions/node/v22.23.1/bin/node scripts/seed_reference_cohorts.cjs --dry-run
```

このseed previewは完全offline。以下の書込み例は、別途起動した**専用ローカルFirestore Emulator**にしか使えない。

```sh
FIRESTORE_EMULATOR_HOST=127.0.0.1:19180 /Users/gota/.nvm/versions/node/v22.23.1/bin/node scripts/seed_reference_cohorts.cjs --write --project=demo-hamcare-personality
FIRESTORE_EMULATOR_HOST=127.0.0.1:19180 /Users/gota/.nvm/versions/node/v22.23.1/bin/node scripts/personality_backfill.cjs --project=demo-hamcare-personality --uids=fixture-a,fixture-b --dry-run
FIRESTORE_EMULATOR_HOST=127.0.0.1:19180 /Users/gota/.nvm/versions/node/v22.23.1/bin/node scripts/personality_backfill.cjs --project=demo-hamcare-personality --uids=fixture-a,fixture-b --write
```

両スクリプトともdemo- project＋loopback hostが必須で、本番projectやremote hostを拒否する。seedは同じversion/pointerの再実行がno-op、異なる既存値は上書きせず停止。バックフィルは現行発行処理と同じtransactionで冪等に処理し、既存first／記録／既存Silverには書かない。
当日Silverがない場合は `personalityBackfill.ts` が既存 `fetchHealthSourceData()` と `buildDailyHealthFeatures()` を再利用し、Bronzeから当日のSilverだけをcreateする。中央値/MAD/EWMAの計算式は再実装しない。既存の当日Silverが先に作られた場合は上書きせず、発行transactionで確定した実値を読み直す。
過去Silver／readinessを当日の結果として流用しない。`--evaluation-date=過去日` はhistorical_skipped。dry-runも当日分を再計算するがSilver／Goldへの書込みは0。full `rebuildHealthForDate()` は呼ばず、旧first、health assessment、incident、通知への副作用を避ける。

## 画面・アクセス・A3

Homeの「うちの子の個性レポート」から最新pointer→immutable reportを読む。既存初回レポートの閲覧経路は保持する。生成済みレポートはtrial期限後も本人が閲覧でき、AI相談回数を消費しない。
キャッシュ由来の未存在を確定させず、server確認まではloading、読取り失敗はretry。アカウント切替では前のレポートを消す。

レポートを実際に描画したpost-frameで閲覧callbackを実行し、navigation/loading/errorを閲覧扱いしない。onboardingの既存A3 `firstPersonalizedAnalysisViewedAt` と、新 `firstPersonalityReportViewedAt` はtransactionで未設定時だけ追加する。他のA1/A2状態や既存日時は維持する。
Analyticsの既存 `personalized_report_viewed` にreport/pet/revision/presentation、report_kind=personality、is_first_viewだけを付ける。個体名、species、数値、健康記録、自由記述を送らない。UIDは既存Analytics User-IDのみ。
新生成イベントは既存ingestAnalysisEventToBigQueryのmetadata契約を使い、trial_journey SQLは旧・新両生成イベントを厳密UID/pet/report/revisionで照合する。生成時trialId=nullのレポートを後発trialへ推測帰属させない。SQLはローカル変更のみでBigQuery未反映。

## 本番適用前

1. dirty working treeを直接deployせず、検証済み差分だけのsourceを隔離してレビューする。
2. 本番操作は別途明示的な許可のもと、新Function、Rules、比較基準、対応SQL、Flutterを適用する。現段階のseed/backfillは本番を拒否する。
3. 比較基準を投入してから新レポートを発行する。未投入でも個体内レポートは発行できるが、そのimmutableレポートに後から集団比較を追加しない。
4. 既存readyユーザーのバックフィルは、当日Silver欠落時のBronze再評価を含む。ローカルEmulatorで検証し、本番実行／既存データ移行は行わない。
5. 実機で部分レポート、latest導線、期限後閲覧、A3実表示を確認する。既存first、AI、課金、trialには変更を加えない。

## 今回の全変更ファイル

既存ファイルへの変更は7件。追加分を除いた既存Home／Analytics／Functions exports／Rules／SQLのbytesは変更前と一致し、その他の既存ファイルは変更前SHA-256と一致する。

| 区分 | ファイル |
| --- | --- |
| 既存変更 | `functions/src/index.ts`, `firestore.rules`, `lib/screens/home.dart`, `lib/services/app_analytics.dart` |
| 既存変更（A3/進捗） | `docs/analytics/trial_journey.sql`, `docs/analytics/server_events_normalized.sql`, `PROJECT_STATUS.md` |
| 新規Backend | `functions/src/health/personalityReport.ts`, `functions/src/health/personalityTriggers.ts`, `functions/src/health/referenceCohorts.ts`, `functions/src/health/personalityBackfill.ts` |
| 新規local scripts | `functions/scripts/seed_reference_cohorts.cjs`, `functions/scripts/personality_backfill.cjs` |
| 新規Functions tests | `functions/test/personality_report.test.cjs`, `personality_trigger.test.cjs`, `personality_emulator.test.cjs`, `personality_backfill.test.cjs`, `personality_backfill_silver.test.cjs`, `personality_backfill_emulator.test.cjs`, `reference_cohorts.test.cjs`, `personality_analytics_fixture.test.cjs`, `personality_security_rules.test.cjs`（同directory） |
| 新規Flutter | `lib/models/personality_report.dart`, `lib/services/personality_reports_repo.dart`, `lib/services/personality_report_view_service.dart`, `lib/screens/personality_report_screen.dart`, `lib/widgets/personality_report_entry.dart` |
| 新規Flutter tests | `test/personality_report_model_test.dart`, `personality_reports_repo_test.dart`, `personality_report_screen_test.dart`, `personality_report_view_service_test.dart`, `personality_report_entry_test.dart`, `personality_report_fixtures.dart`, `personality_report_release_candidate_test.dart`（同directory）＋ `test/fixtures/personality_report_emulator_gold_{body,both}.json` |
| 新規契約書 | `docs/personality_report_v1.md`, `docs/personality_report_release.md` |

## 検証結果（2026-10-08）

- Phase 1: テスト先行でRED確認後に実装。Functions単体／関連回帰89件PASS。既存compiled libを更新せず、現行TypeScriptをメモリ内で読み込んで実行。
- 実Firestore Emulator transaction統合9件PASS。10並行実行、ready追加、新旧report／pointer／eventの整合、冪等性、日付逆行拒否、seed／backfill、dryRun write呼出し0を確認。
- 新Rules58件＋既存Firestore Rules45件PASS。4契約状態のowner read／他人やguest拒否、client全write拒否、記録保存回帰。既存Storage7件は変更範囲外として未実行。全て専用demo Emulatorで実行し終了、共有8080は操作していない。
- Phase 2新規Flutter40件（model8／repo11／screen16／view service4／entry1）PASS。全Flutter122件PASS、終了コード0。既存onboarding、初回AI CTA、課金／trial gate、記録関連を含む。
- Flutter全体analyze: No issues found、終了コード0。Functions全体TypeScript noEmit: 終了コード0。
- 初回firstおよび旧first／readinessイベント、Silver／Bronze／billing／trial／AI使用量／validation countersはEmulatorでdata hashとupdateTimeが不変。通常発行のwriteは新report、pointer、metadata eventのみ。
- SQLはoffline fixtureで厳密JOINと初回判定を検証し、BigQuery上では未実行。実機／本番のE2E確認は未実施。

リリース候補の追加検証結果と本番適用順序／rollbackは `docs/personality_report_release.md` および `PROJECT_STATUS.md` を参照。


## リリース候補追加検証（2026-10-08）

- 欠落当日Silverの補完を既存Bronze reader／Silver feature builderで実装。テスト先行後に修正し、古いready Silverの流用を拒否。dry-runも再計算し、write呼出し0。
- Functions関連95/95 PASS。新backfill実Emulator10/10＋既存Gold回帰9/9、Rules再確認58/58 PASS。
- exact Test User B UIDを専用demoにだけ再現。両指標ready／当日Silverなしから体重100g、活動量628.3185307179585mのGoldを発行。再実行はwrite0。旧firstはcanonical SHAとFirestore updateTimeが完全不変。
- 実Emulatorが合成Bronzeから作ったGold JSONをFlutter fixtureに固定。実Homeの旧first／新個性レポートを両順序で開くWidget E2E6/6 PASS。部分表示、pointer更新、期限後owner閲覧、A1/A2保持を確認。Home／旧first／画面本体の追加変更は不要だった。
- 全Flutter128/128 PASS（終了コード0、5分44秒）。全Flutter analyzeはNo issues found、TypeScript全体noEmitは終了コード0。
- 開始時のdirty状態をSHAで照合し、意図した5ファイル変更＋7新規ファイル以外の541ファイルは同一、削除0。本番／Known Good／実機／AI API／deploy／依存取得は未実施。
- ローカル／Emulator判定: PASS。本番seed／補完CLIはdemo＋loopback限定を維持。本番適用には別途承認されたAdmin投入／operator手順と隔離済みsourceを用意する。
