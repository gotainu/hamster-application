# 個性レポート v1 本番適用候補・rollback手順

更新日: 2026-10-08。これは適用計画であり、本番操作は現時点で未承認・未実行。deploy、Firestore本番書込み、SQL実行、配布は行っていない。仕様とローカル検証結果は [personality_report_v1.md](personality_report_v1.md) を参照する。本番操作は、この文書と具体的な隔離候補・実行対象をレビューし、実行が明示的に許可された後に行う。

## 適用する変更と対象

| 区分 | release候補ファイル | 本番での対象・変更内容 |
| --- | --- | --- |
| Functions | `functions/src/health/personalityReport.ts`, `personalityTriggers.ts`, `referenceCohorts.ts`、`functions/src/index.ts` の新export | 新規 `personalityHealthFeaturesWritten` 1関数のみ。Asia/Tokyoの当日 `daily_health_features` を根拠に新report・pointer・metadata生成eventを保存する。region=`asia-northeast1`、timeout=120s、memory=256MiB、retry=true。 |
| Firestore Rules | `firestore.rules` の `personality_reports/{reportId}`、`report_pointers/personality`、`reference_cohorts/{cohortId}` とそのversionsの追加 | report/pointerは本人read、guest/他人read拒否、clientのcreate/update/delete拒否。trial期限に依存しない。研究pointer/versionはclient read/writeとも拒否し、Admin SDKのみで管理する。 |
| 研究seed | `functions/scripts/seed_reference_cohorts.cjs`、`referenceCohorts.ts` | 4種のpointer 4件＋immutable version 4件。現スクリプトは本番実行不可。承認済みの本番migration経路が別途必要。 |
| 既存ユーザー補完 | `functions/src/health/personalityBackfill.ts`、`functions/scripts/personality_backfill.cjs` | 既存source reader/feature builderで欠落当日Silverだけcreateし、確定Silverからreportを発行する。既存Silverは上書きしない。CLIは本番実行不可。 |
| A3 SQL | `docs/analytics/server_events_normalized.sql`, `trial_journey.sql` | 既存生成eventに `personality_report_generated` を追加。生成時刻/pet/report/revisionと閲覧の厳密JOINを維持。BigQuery raw schemaや既存ingest Functionの変更は不要。 |
| Flutter | `lib/models/personality_report.dart`, `lib/services/personality_reports_repo.dart`, `personality_report_view_service.dart`, `lib/screens/personality_report_screen.dart`, `lib/widgets/personality_report_entry.dart`、`lib/screens/home.dart`、`lib/services/app_analytics.dart` | Home導線→latest pointer→immutable report。実描画後の既存閲覧event、初回A3保存、期限後閲覧、アカウント切替の保護。APK/IPAやストア配布はまだ行っていない。 |
| ローカル検証・文書 | 新規Functionsテスト、Flutterテスト/fixture（下記一覧）、`docs/personality_report_v1.md`, 本書、`PROJECT_STATUS.md` | テストとレビュー資料。データ移行・既存Functionの再deploy対象にしない。 |

Functionsテスト: `personality_report.test.cjs`, `personality_trigger.test.cjs`, `personality_emulator.test.cjs`, `personality_backfill.test.cjs`, `personality_backfill_silver.test.cjs`, `personality_backfill_emulator.test.cjs`, `reference_cohorts.test.cjs`, `personality_analytics_fixture.test.cjs`, `personality_security_rules.test.cjs`。Flutterテスト/fixture: `personality_report_model_test.dart`, `personality_reports_repo_test.dart`, `personality_report_screen_test.dart`, `personality_report_view_service_test.dart`, `personality_report_entry_test.dart`, `personality_report_release_candidate_test.dart`, `personality_report_fixtures.dart`。実Emulator Gold fixtureは `test/fixtures/personality_report_emulator_gold_body.json` と `personality_report_emulator_gold_both.json`。

現候補の既存変更はindex export、Rulesの新report/pointer/reference保護、Home、Analytics、SQL 2本、進捗文書に限る。`healthTriggers.ts`、`firstPersonalizedReport.ts`、既存Silver/健康評価/readiness計算、package/lock、課金/trial/AI、古いテストは今回の変更対象にしない。既存距離同期修正を含む現在の本番状態を基準にし、古いhealthソースへ戻さない。

## 適用開始前に満たす条件

1. **現在のdirty working treeからdeployしない。** 実行時点の本番source/configを読み取って基準を固定し、必要な差分だけを別ディレクトリに構成する。ソースZIPの世代・SHA、既存全ファイルのSHA、対象exports、Rules現release、SQL現view定義、使用CLI/Nodeをmanifestに記録する。本書の作成中にこれらの本番読取りは実施していない。
2. 隔離候補で依存lockを固定し、テスト、noEmit、compileを行う。現 `functions/package.json` のmainは `lib/index.js`、`firebase.json` にFunctionsのpredeploy buildはない。古いlibがあるだけでは新exportは反映されない。compileは隔離候補内だけで行い、既存compiled moduleが基準と一致すること、新しいindex exportと新4module（発行・trigger・研究基準・補完helper）だけが予定差分であることを確認する。
3. `firebase.json` のsource/Rulesパス、default database、project、Node 22を明示し、CLIの実パスと版、子プロセスが使うPATHも固定する。wrapper、env、service account、IAM、secret、スケーリング、Eventarc設定をレビューする。旧distance専用wrapperは対象Functionが固定されているため流用しない。既存全Functionのsource/configを変更しない。
4. 対象ユーザーの凍結済み `personalized_reports/first`、既存first/readiness event、Bronze、Silver、health assessment、billing、trial、AI使用量のdata hashとupdateTimeを読取りで記録する。既存firstのgenerated guardを保存し、本番補完にも旧発行処理を呼ばない。
5. seedのoffline JSONをレビューし、別途承認されたAdmin transactionによる本番投入手順を具体化する。今回、本番実行可能ツールは新設しない。補完coreを将来の許可済みoperatorが使う場合も、明示UID・dry-run/readback・許容write先をレビューする。現在のdemo/loopback guardは維持する。
6. SQLが参照するdataset/table/view、場所とACLを確認する。現SQL/ingestはtest-onlyであり、一般production UIDを集計できるようになったとは扱わない。GA4日次export到着と実event受信は別々に確認する。

`firebase.json` はdeploy内容を決め、別configは `--config` で指定できる。全体deployは複数サービスを対象にするため、このreleaseではサービス/Functionを個別に指定する。[公式Firebase CLI reference](https://firebase.google.com/docs/cli)

## 適用順序と各段階の停止条件

| 順序 | 適用・確認 | 次へ進む条件 |
| --- | --- | --- |
| 0 | 上記隔離候補、現状記録、検証結果、rollback用source/config/Rules/view定義を固定 | 本番適用の明示許可と、別途Admin seed投入/補完operator手順のレビュー完了。 |
| 1 | **研究seedを先行**。offline seed JSONをレビュー後、別途承認したAdmin transactionで4種×versionを投入し、全8docをreadback | version本文・単位g・weight指標・出典/年齢条件・IQR・metadataとpointerが予定どおり。既存の同version/pointerは同値ならno-op、異値なら全体を停止し上書きしない。 |
| 2 | Firestore Rulesのみ適用 | report/pointerのowner read、他人/guest拒否、client全write拒否、期限後read、reference pointer/versionのclient read/write拒否、既存の記録保存が維持される。Rules伝播完了を待って確認。 |
| 3 | 新 `personalityHealthFeaturesWritten` 1関数だけ適用 | 関数状態/region/runtime/trigger/source/configが候補と一致し、既存全Functionの変更なし。想定外の削除・policy変更・追加promptが出たら停止。 |
| 4 | 許可した少数UIDで既存ユーザー補完のdry-run→結果レビュー→write→readback | ready集合、source日付、当日Silver欠如の扱い、研究適用条件を確認。write先は新report/pointer/metadata eventと、事前に存在しなかった当日Silverのcreateだけ。既存Silver/保護docのhash/updateTime一致、重複runがno-op。対象UIDを増やす前に再レビュー。 |
| 5 | SQLを依存順に適用: `server_events_normalized.sql` → `trial_journey.sql` | 既存view定義との差分を確認し、旧・新eventの厳密JOIN、再閲覧MIN、after_trial、test-only境界、遅延export状態を確認。dataset/ACL/raw schema/ingestは変更しない。 |
| 6 | 対応Flutterを内部検証→配布 | bodyのみ/activityのみ/both、learning/loading/error、latest、account switch、期限後閲覧、実描画時のみA3を確認。既存first/AI/trial/課金の動作を維持。 |

研究基準がない場合でも個体内reportは生成できるが、そのsnapshotに後から集団比較を追加することはない。このためseed/readback未完了のまま新Functionや補完を開始しない。Chineseは正規化だけ対応し、初版seedは4種のみなので比較不可になる。

Rulesのみを適用する公式構文は `firebase deploy --only firestore:rules`、個別Functionは `firebase deploy --only functions:personalityHealthFeaturesWritten`。実行する場合はレビュー済み隔離ディレクトリで、承認したCLIを使い `--project hamster-breeding-app --config <reviewed-config-path>` を明示する。これらのコマンドは本書作成では実行していない。[Rules deployment](https://firebase.google.com/docs/rules/manage-deploy)、[Function deployment](https://firebase.google.com/docs/functions/manage-functions)

CLIのcleanup promptを処理するためにArtifact Registryの既存policyを変更しない。公式の `functions:artifacts:setpolicy` はクラウドpolicy操作なので本releaseの通常手順に含めない。削除promptに `--force` を付けて通過しない。[公式Function artifact cleanup](https://firebase.google.com/docs/functions/manage-functions#clean_up_deployment_artifacts)

## seedと補完の現状制限

`seed_reference_cohorts.cjs` は引数なし/`--dry-run` でoffline JSONだけを出す。writeには明示 `demo-*` project、`FIRESTORE_EMULATOR_HOST` のlocalhost/127.0.0.1/[::1]と有効portが必要で、Admin初期化より前に本番project/remote hostを拒否する。`personality_backfill.cjs` はdry-runでも同じdemo＋loopbackが必須で、明示UIDだけを扱う。本番用コマンドは現在存在しない。

補完core `personalityBackfill.ts` は今日のSilverがある場合はそれを使う。なければ既存の `fetchHealthSourceData` / `buildDailyHealthFeatures` で今日のfeaturesを作り、transactionでまだ不存在のときだけcreateする。並行pipeline/補完が先に作成したSilverは上書きせず、発行transactionでcommitted winnerを読み直す。旧health assessment/first/incident/notification処理を呼ばない。過去評価日は `historical_skipped`。当日Silverがないdry-runはmemory内previewを使い、Silver/report/pointer/eventへ書かない。

このhelperは新しい公開Functionではなく、将来の許可済みoperatorが再利用するcoreである。現CLIのdemo＋loopback境界は維持され、本番実行権限や本番ツールが追加されたことを意味しない。既存保護Silverの不変性と「欠落当日Silverの新規create」を区別する。release候補の固定前に新補完回帰とEmulator検証結果を仕様文書へ反映し、当日Silverあり/なし、ready/learning、重複・並行、dry-run、入力競合を確認する。

## rollback

異常があれば後続適用と補完を止め、原因/適用済み範囲を記録する。失敗後の自動再deploy、別sourceへの切替、データ上書きでの修復は行わない。rollback自体も具体的な対象と差分をレビューし、許可された操作だけを実行する。

| 対象 | rollback方法 | データの扱い・注意 |
| --- | --- | --- |
| Flutter | 内部配布停止、Home導線を含む前の承認済みアプリ構成で修正版を用意する。 | 現コードにremote kill switchはない。旧APK/IPAへの自動ダウングレードを前提にしない。既存first閲覧は維持。 |
| 新Function | 新発行を止める必要がある場合、同名/同triggerのレビュー済みno-op版を対象1関数だけへdeployする、または当該新関数だけ明示削除する。どちらを行うか先に許可を得る。 | 旧全Functions sourceを広域deployして暗黙削除しない。新関数を止めても既存health pipelineは動く。削除時にretry/deliveryの完全復旧を仮定しない。 |
| Rules | 適用前に保存した現production Rulesをreviewし、Rulesのみ再releaseする。 | 新アプリから新reportへのreadが拒否される場合があるため配布/導線と調整する。rollbackでclient write許可を加えない。 |
| SQL | 保存した元view定義を依存順に戻す。 | raw/normalized生成eventやGA4履歴は消さない。論理viewは保存SQLを問合せ時に実行するため、定義を戻すと過去期間の表示も変わる。 |
| 研究seed | immutable version本文を削除/編集しない。必要なら停止した発行処理に対してpointerだけを、保存した以前の状態へ戻す別migrationをレビューする。 | 初回投入で元pointerがない場合も、復元方式は個別に決める。報告済みsnapshotは基準のコピー/versionを保持し、pointer変更だけでは書き替わらない。 |
| 補完で新規作成した当日Silver | 原因調査と既存pipelineへの影響を確認し、通常rollbackでは削除/上書きしない。 | 作成済みreportの根拠と正常な既存health処理が参照する可能性がある。誤ったSilverの修正が必要なら、別の明示migrationとして扱う。 |
| 発行済みreport/pointer/event、初回A3 | 作成済みimmutable reportと生成履歴を保持する。誤りの修正は将来の新spec/versionと明示migrationの別課題にする。 | 旧reportのset/update/delete、firstの改版、onboarding時刻の削除・上書き、AI/trial/billingへの補償writeはrollback手順に含めない。 |

初回追加Functionには「前のpersonality revision」がないため、Cloud Run trafficを旧revisionへ戻すだけのrollbackは前提にしない。Firebaseの公式 `functions:delete <name> --region <region>` は対象を明示する削除操作で、通常deployとは別の許可対象である。Functions sourceから消して広域deployすると暗黙削除になる。[公式Function management](https://firebase.google.com/docs/functions/manage-functions)

Rules CLI releaseはConsoleの現Rulesを上書きする。適用/rollback直前に別のRules変更がないか確認し、伝播を待ってreadbackする。[公式Rules management](https://firebase.google.com/docs/rules/manage-deploy)

SQLのrollbackはデータ削除ではなくview定義の復元とする。[公式BigQuery logical views](https://docs.cloud.google.com/bigquery/docs/views-intro)

## release完了の記録

本番適用後に、隔離候補SHA、使用CLI/Node、対象Function source/trigger/config、Rules release、研究8doc、SQL定義、配布build、許可UIDの補完結果を記録する。旧firstと既存保護docはcanonical data hashとREST updateTimeを別々に比較し、新snapshotの生成時刻と混同しない。

A3のFirestore初回時刻、GA4受信、server ingest、日次export、SQL JOINは別の確認項目とする。生成時trialId=nullを後発trialへ推測帰属させず、test-only ingestのまま一般本番集計完了とは報告しない。各段階の未確認項目が残る場合はrelease完了としない。


## リリース候補のローカル合否（2026-10-08）

**PASS**。Functions95件、Bronze→Silver→Gold追加Emulator10件、既存Gold回帰9件、Rules58件、全Flutter128件が成功。全体analyze／TypeScript noEmitも終了コード0。実Home導線のWidget E2E6件では旧firstと新個性レポートを両順序で開き、独立表示と保存済みreport不変を確認した。

当日Silverなしのexact B demo再現では100g／628.3185307179585mの両指標reportを発行し、retry write0、legacy first canonical SHA／updateTime不変を確認。本番Bデータは読み書きしていない。このPASSはローカル／Emulatorのrelease候補判定であり、本番seed／operator準備、deploy、SQL適用、アプリ配布の実行済みを意味しない。
