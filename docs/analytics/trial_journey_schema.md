# trial_journey：ローンチ計測とダッシュボード

更新: 2026-10-17。ローカル実装・架空検証を完了。本番反映とLooker Studio公開は別工程。
既存のFirebase Analytics／AppAnalytics、Firestore `analysis_events`／`journey_events`、
`hamcare_trial_analytics.server_events_raw`、GA4日次exportを再利用する。
新しい行動分析プラットフォームや研究データ基盤を作らない。

## 入力と結合

Serverの正は認証済みUID配下の受理イベント／確定済み課金状態。
GA4の正は標準`user_id`、イベント時刻、`event_id`／`presentation_id`。
匿名`user_pseudo_id`を推測でUIDへつなげない。
A3の実表示は`UID＋pet_id＋report_id＋revision`の全一致と生成後の時刻が必要。
表示成功のない遷移だけでは閲覧数にしない。

- Server: `source_event_id`ごとに最新取り込み1件。UIDもキーに含める。
- GA4: `UID＋event_name＋event_id`（旧表示イベントはpresentation ID）ごとに1件。
- 必要なキー欠落・旧分類不明は診断対象。一般ユーザーへの昇格／過去イベントの捏造をしない。
- 一般集計: server `environment=live, account_classification=general, test_only=false`。
  GA4も`analytics_environment=live, test_only=0, analytics_identity_version=firebase_uid_v1`。
- Sandbox契約は`billing_livemode=false`。一般の有料契約数はTRUEだけを採用。

列追加は[server_event_schema_migration.sql](server_event_schema_migration.sql)の3列のみ。
このDDLは今回実行しない。既存test-only preview viewは勝手に一般向けへ変更しない。
正規化後の一般分析は[trial_journey.sql](trial_journey.sql)の明示パラメーター付き期間クエリを使う。

## 4つのパネル

1. **ファネル**: 登録→trial→A1→A2→ready→生成→実表示→有料。
   前段の後に起きた最初のイベントを順番に選ぶ厳密な段階到達数。
   記録済みでもAI相談前など順序が違う利用は、独立したA3到達指標には残す。
   A1成功は価値実感の代理指標。A2は手入力の体重／活動量の受理。
2. **D1/D7/D14/D21継続**: 登録日のJST暦日をD0とする。
   サーバー受理済みmanual記録、成功したユーザーAI相談、生成情報と一致した実レポート表示を能動的利用とする。
   センサー取得、background、ready遷移、自動生成、課金Webhookは含めない。
   対象日の終了までserver／GA4双方の収集完了を確認できた人だけが分母。
3. **trial開始コホートの課金率**: 月別trial開始コホート。
   初期ダッシュボードは**trial開始から28日**（21日体験＋7日観察）の課金を評価する。
   これは変更可能な分析ポリシー初期値で、無料体験・課金権限の仕様変更ではない。
   horizonと取り込み完了が未到達なら未成熟として分母から除外する。
4. **A3の価値検証**: ready／生成／実表示の独立した到達率。
   閲覧後の比較はtrial14日目をlandmark、D21の継続とlandmark後〜28日目の課金に限定する。
   全群で同じ追跡期間を確保し、14日までに契約済みの人は後続課金のリスク集合から外す。
   「いつか見た人」と未閲覧をそのまま比べるimmortal-time混入を避ける。
   それでも交絡・選択差があり、因果効果は示さない。

`tools/analytics/dashboard_queries.sql`はSQLiteとBigQueryで共有する集計SQL。
各パネルは人数／分子／分母を返す。0人は0、分母0または未確定の率はNULL（画面N/A）。
同じ人が複数試行したtrialを重複分母にしないよう、登録UIDごとの最初のtrialを採用する。

## 明示的な時刻と収集完了

`as_of`、`server_complete_through`、`ga4_complete_through`、コホート期間、
conversion horizon、landmark、follow-up日を呼び出し元で明示する。
完了watermarkは`MAX(event_at)`で推測しない。完了不明ならNULLを渡し、率をN/Aに保つ。
イベント時刻とBigQuery取り込み時刻は別。server側は`ingested_at <= as_of`も適用する。
GA4日次exportは遅延追記され、信頼できるBQ受理時刻をイベントごとに持たない。
そのため過去as_ofの完全再現には、同じexport/source snapshotとhashの固定が別途必要。
現時刻のqueryとevent-timeの上限だけで、当時の取り込み状態を再現できたと断定しない。
GA4端末イベント時刻も信頼できるサーバー受理時刻と同一視しない。

## 再現可能なローカル実行

```sh
node tools/analytics/run.cjs
node --test tools/analytics/journey_metrics.test.cjs
node tools/analytics/render-dashboard.cjs tools/analytics/output/general-dashboard.json tools/analytics/output/synthetic-dashboard.json /tmp/hamcare-journey-preview.html
```

Node 22とPython 3標準ライブラリだけを使用。外部API／認証／DBなしで
完全架空fixture→UID/report照合→共有SQL→集計JSON→ダッシュボードまで生成する。
`tools/analytics/output/synthetic-dashboard.json`は架空検証、
`general-dashboard.json`は一般ユーザー0人という現状前提の未接続プレビュー。
後者を本番イベントの収集確認と混同しない。
manifestは入力／config／code／content hashを持ち、生成時刻は内容hashから除外する。
入力順を変えても同じ集計内容hashになる。公開ビューはUIDを返さない。

## BigQueryとLooker Studio

既存dataset: `hamcare_trial_analytics`、GA4: `analytics_549839505`（東京）。
2026-10-17の限定read-only確認ではGA4日次13テーブル（10/03〜10/16）、
server raw47件。UIDが一致したアカウント2件、完全なreportキーで一致する表示15機会／1アカウント。
これは既存テスト利用の接続証拠であり、一般ユーザーや新追加イベントの稼働証拠ではない。
以前の「GA4日次export未着」は2026-10-04時点の状態として保持する。

反映時は、追加BQ3列→明示的なlive/test分類とテストUID登録→対象計測Functions／アプリ
→新イベントの到着確認→期間指定クエリの順とする。既存データの一括移行はしない。
まず`trial_journey.sql`でprivate TEMP factsを生成し、同じjobへ共有集計SQLを追加する。
最大bytesを設定し、集計結果だけをrestricted analyst datasetへ必要に応じ保存する。
Looker Studioは集計結果を接続し、上記4パネル、cohort、環境、policy version、
as_of／watermark、未成熟件数、N/A理由を表示する。UID詳細を公開レポートへ渡さない。
新しいcloud view／定期job／Looker公開を今回自動作成しない。

一般公開前には計測利用の説明、同意方針、ストア申告、保持・削除と分析operator権限を確認する。
計測の成否を健康評価・無料体験・有料権限の判定へ利用しない。


### Looker Studioへ接続する最短手順（未実行）

1. 下記の反映対象を承認のうえ適用し、新しいメタデータの到着を確認する。
   BQ列追加より先に新ingestを動かさない。削除ガードは新イベントwriterより先に反映する。
2. `trial_journey.sql`の時刻／期間／watermarkを指定し、
   `tools/analytics/dashboard_queries.sql`の各`-- query:`を同じjobで実行する。
   個人別TEMP factsは公開せず、5種類の集計結果だけを制限された分析領域へ保存する。
   初回は手動実行とし、Schedulerや全件移行は追加しない。
3. Looker Studioの「作成→データソース→BigQuery」で同じproject・東京の
   集計table/viewを選ぶ。既存Analyticsリンクは再作成しない。
   [公式BigQuery接続手順](https://cloud.google.com/looker/docs/studio/connect-to-google-bigquery)を参照。
4. 次のフィールドを接続し、レポート共有は分析担当者へ限定する。
   接続時の認証情報・分析基盤ACLは今回変更していない。

| パネル | 入力query | ディメンション／並び | 指標 |
| --- | --- | --- | --- |
| ファネル | `funnel` | `stage_order`昇順、`label` | `users`、`eligible_users`、`rate` |
| 継続 | `retention` | `day`昇順 | `retained_users`、`eligible_users`、`rate` |
| trial課金 | `conversion_cohorts` | `cohort` | `converted_trials`、`eligible_trials`、`immature_trials`、`rate` |
| A3到達 | `a3` | 1行のscorecard | `ready`／`generated`／`viewed`と各`*_rate` |
| A3後の関連 | `landmark_segments` | `segment` | `retention_rate`、`conversion_rate`、両分母 |

率はSQLの分子／分母から求め、複数cohortの率を単純平均しない。
LookerのNULL表示をN/Aにし、未成熟件数、as_of、両watermark、分析policy version、
28日の転換観察窓を併記する。一般・testのsourceを同一スコアへ合算しない。

### 対象限定の反映一覧

- 新規: `analyticsAccountRegistered`、`analyticsWeightRevisionAccepted`、
  `analyticsActivityRevisionAccepted`、`analyticsObservationRevisionAccepted`、
  `analyticsCareRevisionAccepted`、`analyticsSubscriptionCommitted`。
- 更新: `ingestJourneyEventToBigQuery`／`ingestAnalysisEventToBigQuery`、
  `analyticsWeightRecordCreated`／`analyticsActivityRecordCreated`／
  `analyticsDailyCheckinCreated`／`analyticsSwitchbotReadingCreated`（元の受理時刻の保持）、
  `stripeWebhook`／`createStripeCustomerPortalSession`（trusted livemodeメタデータ）、
  `deleteMyAccountAndData`（追加metadataの削除競合ガード）。全Functions一括反映はしない。
- `ANALYTICS_ENVIRONMENT=live`とサーバー管理のテストUID一覧を確認する。
  debug APKはtest区分、必要時は`HAMCARE_ANALYTICS_ENVIRONMENT=emulator`を明示する。
  分類済みunknownを後日の再送でliveへ変えない。過去の不明データを埋めない。
- FlutterはAppAnalyticsのみの変更。レポート表示成功・Paywall・Checkout既存callsiteを再利用。
  観察回答・タグ数・メモ有無はGA4へ送らない。
- 正規削除は追加journeyイベントを既存recursive削除に含める。
  新writerは削除開始マーカーとsourceをtransactionで確認し、Auth削除完了までrootのガードを維持する。
  Auth失敗／`deleteAuthUser=false`では最小ガードを残し、遅いAuthイベントによる再作成を防ぐ。
  BigQuery／GA4側の保持・本人削除手順は一般公開前の運用確認事項のまま。


## 今回の検証結果

関連85 checks PASS（server22＋既存Stripe回帰1、Flutter15×debug／Emulator区分2環境、
集計27、HTML renderer5）。Functions全sourceの`tsc --noEmit`と変更DartのanalyzeもPASS。
BigQuery実エンジンではクラウドtableを参照しない完全架空CTEを使い、
同じ5集計（funnel／retention／conversion／A3／landmark）がSQLiteと一致した。

- ファネル: `5→4→4→2→2→2→2→2`。
- D1／D7／D14／D21: `2/4・1/4・2/4・1/4`。
- 28日課金率: 成熟3人中2人。未成熟1人は分母外。
- 一般0人: 各人数0、率NULL/N/A。収集完了watermark不明を維持。
- 初回BQ検証でreserved alias `AT`、10MiB未満の最大bytes、
  検証fixtureのGA4 `report_revision`→`analysis_revision`変換漏れを検出。
  SQLまたは検証adapterだけを限定修正し、期待値を変えず全5集計の一致を確認した。
- ブラウザのDOMで0人/N/A、架空切替、4パネルの期待値を確認。
  画像取得はブラウザcapture／native機能の失敗により未取得で、画像QA PASSとは記録しない。
  最終HTMLは`tools/analytics/output/dashboard.html`。

既存データ・Rules・Functions・Scheduler・課金設定・APKへ変更なし。
本番接続のread-only確認と新しい計測の反映・継続運用は区別する。

## 継続確認用の接続（2026-10-18）

既存HTMLを[ローカルBigQuery接続runner](../../tools/analytics/README.md#既存bigqueryへのローカル接続)へ接続する。
同じ期間SQL・共通集計をread-only jobで実行し、集計だけを127.0.0.1で表示する。
既定15分更新／手動再集計、取得成功日時、知識締切、更新失敗、30分経過の古さを表示する。
一般0人と、未接続・取得失敗を区別し、失敗時の旧キャッシュを最新とみなさない。
新しい公開API、Scheduler、重複したLookerダッシュボードは作らない。

`trial_journey.sql`の追加パラメーター`excluded_user_ids ARRAY<STRING>`は
確認済みテストUIDを全server rosterから除く。GA4はそのrosterだけに結合する。
実UIDはGit外の非公開設定に置き、画面／集計JSON／ログへ出さない。
既存のlive/general分類、Sandboxの`billing_livemode`、unknown除外も維持する。
watermarkは既定NULL。接続成功を取り込み完了と扱わず、率N/Aを維持する。

接続機能の限定12テストで、接続済み0人、未接続、失敗後の旧結果保持、古さ、
知識締切、除外一覧変更時のキャッシュ不採用、並行要求、個人情報拒否、
loopback／same-origin制限を確認した。実BigQueryへの到着確認と一般除外の結果は
リリース実行記録で別途確認する。

## 本番接続結果（2026-10-18）

上記2026-10-17のローカル工程から、次の接続・対象限定リリースを完了した。

- BigQueryのnullable3列を追加。旧42列・既存47行とACL／partition／clusteringは維持。
- 反映一覧の15件だけを配備し、実際のACTIVE、Gen2 traffic100%、配備source hashを確認。
  既存設定は保持し、旧4記録triggerの未設定maxがAPI上20へ正規化された点は、
  既存Runサービス上限20と実効上限が変わらない承認済み運用差分として記録した。
  第1段階のStripe最新状態CAS同期とPortal修正も同じ隔離sourceに含む。
- 一般0人という事業前提とAuth一覧から既存18accountをtest除外し、Bも含む。
  実UIDは非公開設定だけへ保存。unknown／Sandbox／Emulatorを一般へ昇格しない。
- 接続用metadata1件はFirestore→実Function→BQに到着し、UID・サーバー受理時刻一致、
  raw1／dedup1／一般採用0を確認。A1/A2/A3の到達としては数えず、飼育・report・billingを変更しない。
- 既存HTML＋同じ5集計SQLで実BQに接続し、一般0人を取得。
  runner実行中だけ15分更新し、停止後は再起動が必要。
  成功日時とas_ofを分離し、NULL watermarkを最新event時刻で置き換えない。
  GA4の既存日次exportとの結合証拠は前工程を再利用し、新APKのGA4到着とは区別する。
- 最新Flutter debug buildはPASS・前回配備APKとの署名一致。ADB未接続のため端末更新は待ち。
  live画面のブラウザ操作接続も停止しており、今回の画像／DOM確認は未実施。

復元情報と正確なrevision一覧：Git外の
`/Users/gota/hamcare-deploy-staging/journey-analytics-20261018/audit/release-result.md`。
同領域の`start-dashboard.sh`がprivate設定とcacheを使い、`http://127.0.0.1:8877`を開く。
外部公開せず、既存BQ閲覧権限を持つ担当者だけがこのMacで利用する。
公開前には分析利用説明／同意方針・ストア申告、保持・本人削除運用、
取り込み完了watermarkの確認手順、追加テストaccountの除外登録を確認する。
これらを実装済み・法的要件確定とは扱わない。
