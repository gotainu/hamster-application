# ローンチ前・限定接続検証

更新日: 2026-10-04  
状態: **既存環境へ限定反映済み。実機の利用・Analytics受信・GA4日次Exportは未確認。**

## 接続先と境界

この検証は新しいstaging群ではなく、所有者のテストUIDだけに制限した既存環境を
使用する。一般公開、ストア配布、GitHub pushは行わない。

| 系統 | 使用先 | 現在の状態 |
| --- | --- | --- |
| Firebase | `hamster-breeding-app` (`797691641198`)、asia-northeast1 | 認証・Functions・Firestoreを限定利用。テストUID A/B以外で体験開始を許可しない |
| Cloud Run RAG | `hamster-rag-api`、asia-northeast1、`https://hamster-rag-api-797691641198.asia-northeast1.run.app` | `hamster-rag-api-00016-zb6`、100% traffic。未認証直呼びは401。App Check強制は未有効 |
| Firebase Analytics / GA4 | Firebase Consoleでリンク済みと所有者確認。対象4アプリ、asia-northeast1、日次ON、ストリーミングOFF、広告ID OFF | DebugViewの実機受信は未確認 |
| GA4 BigQuery Export | Firebase管理データセット `analytics_549839505` を想定 | 2026-10-04時点でデータセット・テーブル未作成。到着待ち。リンクの再作成はしない |
| Server event BigQuery | `hamster-breeding-app.hamcare_trial_analytics`、asia-northeast1 | dataset、raw table、normalized/server journey/dashboard preview view 作成済み。厳格ACL |
| テストAPK | `build/app/outputs/apk/debug/app-debug.apk` | Debug署名。package `com.gotainu.hamster`。既存アプリをアンインストール・上書きせず、対象端末に同じpackageがないことを先に確認 |

Cloud Run revisionは現在も`00016-zb6`で100% traffic。未認証`/chat`直呼びの直近成功確認（前回 turn）は401。2026-10-04に同じ非認証probeを再確認しようとしたが、この実行環境からのHTTP接続が10秒timeoutし、応答コードは得られなかった。tokenは送信せず、AI/model呼び出しも行っていないため、この再probeは未検証として扱う。

クラウドの限定反映済み関数は、体験開始、日次/体重/活動量/SwitchBot記録イベント、分析イベント、AI利用量取り込み、BigQuery ingestである。AI回答時の利用・課金許可の正はCloud RunでのFirebase UID検証とサーバー利用枠であり、Flutterの事前判定ではない。

アカウントA/Bは所有者管理の次のテストUIDだけを対象にする。

- A: `uRgVakjkaqOxY6uiv0fH9B0d1wS2`
- B: `4sD1MUmi9OTM5SaRq66qGWW8q2p2`

アカウント切替前に、普段の飼育記録を持つUID（`suMUKXnF9xWd5sfxlOGyPnL0yGv2`）でサインインしない。既存飼育記録・設定の削除、初期化、上書きは行わない。

## AI上限・費用見積もり

承認済みの製品初期方針は21日、相談リクエスト20件、1相談につき$0.05予約、ユーザーあたり合計$1.00予約である。初回チュートリアルも1相談として数え、内部の2回生成でも1相談枠だけを消費する。同じrequest IDの再送は再消費しない。これは予約方式であり実費上限保証ではない。

Cloud Runの実測コード上、1相談あたり最大4つのOpenAI API呼び出しを見積もる: controller `gpt-4o-mini` (12,000 input / 256 output)、`text-embedding-3-small` (8,192 input)、answer `gpt-4o-mini` (32,000 input / 700 output)、任意のgrounding `gpt-4o-mini` (同上)。SDKの自動再試行は無効。標準API単価（Batch/Flexではない）を用いた最大見積もりは1相談 **$0.01255744**、承認済み4相談全体では **$0.05022976**。20相談なら推定最大 **$0.2511488** となり、$1.00予約内だが、この値もサービス全体の実費保証ではない。Firestore、Pinecone、Cloud Run等の費用は含めない。

検証環境側でもA/B合計4相談、予約総額$0.20をサーバー側で強制する。現在、実AI相談0件、provider呼出0件、使用量0、予約$0、usage receiptからの推定実費$0（呼出なし）である。実機で相談する前に、アプリが表示する対象アカウントを確認し、自由記述や実個人情報を送らない。

AI枠到達後も、体験期限内であれば記録保存、SwitchBot取得、分析・初回レポート閲覧を継続できる。AI相談上限だけでこれらの権限を止めない。体験終了後は未契約ユーザーの新規記録保存とAI生成を停止するが、既存データの閲覧/削除等のアカウント管理操作は維持する。

## BigQueryの確認結果と閲覧

- Consoleの既存Firebase→BigQueryリンクは再作成しない。
- BigQueryで見えるdatasetは`hamcare_trial_analytics`だけ。場所は`asia-northeast1`。
- `server_events_raw`は`ingested_at`日次partition、partition filter必須、`user_id,event_name,trial_id`でcluster。質問・回答本文や飼育メモを含めない。
- `server_events_normalized`、`trial_journey_server`、`trial_journey_preview_dashboard` viewを用意。
- Firestoreからの合成接続確認は3件raw / 3件異なるsource_event_id / 3件test_only。一般の体験Journeyには算入されず、実ユーザー行は0。
- previewの最新結果は`trial_starts=0`、report viewed/paywallはNULL、`awaiting_ga4_daily_export`。0到達と未計測を混同しない。
- GA4日次Exportのデータセットや`events_*`はまだ未着。`trial_journey`最終viewとGA連結ダッシュボードはExport到着後に限り有効化できる。

閲覧は所有者が[BigQuery Console](https://console.cloud.google.com/bigquery?project=hamster-breeding-app)で`hamcare_trial_analytics`の`trial_journey_preview_dashboard`をPreviewする。必要なら次の限定クエリを実行する。

```sql
SELECT *
FROM `hamster-breeding-app.hamcare_trial_analytics.trial_journey_preview_dashboard`;
```

これは一般公開されたダッシュボードではなく、UID A/Bの実利用結果が入ったものでもない。CSV/Looker Studio等で共有しない。

## 実機での確認手順

1. APKを別のテスト端末または空のAndroidユーザープロファイルにインストールする。`com.gotainu.hamster`が既にある場合はアンインストールしない。データ保持を優先し、その端末には入れず対象端末を相談する。
2. UID Aでログインし、無料体験開始を1度だけ行う。サーバーFirestoreの固定`trial_id`、policy version、`startedAt`、`endsAt`を確認する。
3. AI相談を最大4件の承認総枠内でだけ実施する。まず1相談の成功を確認し、アプリ上に質問文をAnalyticsへ送らないことと、サーバーusage記録が揃うことを確認する。失敗/結果不明のrequest IDは再生成でなく同じIDの状態確認を行う。
4. 初回記録を保存し、Analytics DebugViewとFirestore server eventを別々に確認する。実測データでreadyを待つ場合、過去データを作成・書換えず自然到達だけを観察する。fixtureで確認する場合は合成と明示し、実観察と呼ばない。
5. 初回レポート生成イベントと、レポート取得・画面表示後の閲覧イベントを別々に確認する。実表示前に閲覧を計上しない。
6. ConsoleのGA4日次Export dataset/tableが到着したら、`docs/analytics/trial_journey.sql`を期間限定・最大bytes指定で実行し、UIDとtrial_idによる結合を確認する。UID B、再閲覧、欠測値が混ざらないことも確認する。
7. DebugView受信、Firestore→BigQuery server ingest、GA4日次Export、trial_journey joinを別項目として記録する。日次Export未着の間は最終合格としない。

## 現時点の未完了項目

- 実機APKのインストールとA/Bログイン・Analytics DebugViewの実受信。
- 実AI相談（承認上限内）。現在は0件。
- 実観測データによる初回記録からmetric-ready/初回レポートまでの自然到達。
- Firebase管理のGA4 dataset/table到着、GA4イベントとの同一UID・trial_id join、最終`trial_journey`集計。
- プライバシー説明とApple/Googleストア申告の整合レビュー。今回一般公開はしない。

## 変更・復元情報

- GCP project: `hamster-breeding-app` (`797691641198`); region: `asia-northeast1`.
- Cloud Run: `hamster-rag-api-00016-zb6` (100% traffic; preceding revision retained by Cloud Run).
- Firestore active ruleset: `3d077ed6-ca33-4d86-82f7-3ca497228eba`.
- Gen2 Functions and BigQuery schema/view source are represented in this repository. Deployed function revisions can be listed with `gcloud functions list --v2 --project=hamster-breeding-app --regions=asia-northeast1`.
- Pre-deployment snapshot is retained at `docs/release/predeployment_snapshot_2026-10-03.md`. No rollback was performed.
