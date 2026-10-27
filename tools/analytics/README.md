# HamCare journey dashboard

既存のGA4＋server metadataの集計を確認するローカルrunner。
ダッシュボードの方針は[既存schema文書](../../docs/analytics/trial_journey_schema.md)を正本とする。
研究・予測モデル・Feature Storeではない。

```sh
node run.cjs
node --test journey_metrics.test.cjs
```

リポジトリrootからなら`node tools/analytics/run.cjs`。
Python 3の標準SQLiteで`dashboard_queries.sql`を実行する。追加依存、通信、認証不要。
`fixtures/make_synthetic.cjs`だけがサンプル入力の出所で、すべて架空。

- `journey_metrics.cjs`: metadataの検証、分類、重複除去、正確なUID/report結合、user facts。
- `dashboard_queries.sql`: BQでも共有する4パネル＋landmark集計。UIDを出力しない。
- `execute_sql.py`: 標準SQLite実行だけ。
- `run.cjs`: 薄い実行／manifest／JSON出力。
- `build_bigquery_fixture.cjs`: exact BQ queryを架空CTEへ差し替えた検証scriptの生成。
  自動実行・cloud接続は行わない。cloud table参照が残れば拒否。

出力`output/`はsyntheticと明示したサンプルのみ。
`general-dashboard.json`の0人は現在の事業前提に沿う未接続プレビューで、
本番収集・完全性の検証結果ではない。NULLの率はN/Aにする。
標準の転換観察期間は28日（21日体験＋7日追跡）で変更可能な分析初期値。
分析用の期間は無料体験・課金権限を変更しない。

BigQuery利用時は[期間query](../../docs/analytics/trial_journey.sql)の必須引数と
取り込み完了watermarkを明示する。GA4のsnapshot固定なしで過去の取り込み状態を再現したとはしない。
BQ/Looker設定変更やFunctionsdeployはこのrunnerから行えない。

承認済みmetadata exportをローカル集計する場合は次の入口を使える。
自動のFirestore／GA4抽出、クラウド接続は含まない。

```sh
node tools/analytics/run.cjs --input /path/to/metadata.json --config /path/to/config.json --output /path/to/new-run
```

`config`はサンプルと同じ明示的な時刻／watermark／horizonを必要とする。
synthetic以外の入力は`source_classification=test_metadata_export`または
`production_metadata_export`を明示し、一般向けの集計はlive/general分類に限定する。
既存出力directoryは拒否する。出力は集計JSON・安全なconfig・manifestのみで、raw UID行をコピーしない。


表示確認用のHTMLは次で生成する（保存先は新しいファイルを指定）。

```sh
node tools/analytics/render-dashboard.cjs tools/analytics/output/general-dashboard.json tools/analytics/output/synthetic-dashboard.json /tmp/hamcare-journey-preview.html
node --test tools/analytics/render-dashboard.test.cjs
```

生成HTMLはネットワーク不要で直接開ける。一般0人／架空fixtureを切り替え、
4パネルと分析ポリシー、N/Aを確認できる。個人別データの読込みは拒否する。
`output/dashboard.html`はこの工程の確認用サンプル。Lookerの本番接続を意味しない。

## 既存BigQueryへのローカル接続

既存HTMLの表示部品・4パネルをそのまま使用する。新しい公開API、Lookerレポート、
Scheduler、認証基盤は作らない。ローカルで`bq`へ既存のGoogle Cloud認証を渡し、
`trial_journey.sql`と共通`dashboard_queries.sql`を同じread-only query jobで実行する。
ブラウザへ返すのは集計値だけで、UID facts、秘密情報、認証情報を返さない。

`live-config.example.json`を**Git外の非公開ファイル**へコピーし、
`excluded_user_ids`を確認済みテストアカウントのUID一覧に置き換える。
これは既存serverの分類に加えた除外で、GA4も除外済みrosterにだけ結合する。
実UIDをサンプル／リポジトリへ書き込まない。空配列を使う場合は、
除外対象が本当にない根拠を別の運用記録へ残す。
設定にAPIキーは不要。Cloud認証やアカウント設定をブラウザへ渡さない。

```sh
# Node 22、gcloud/bqの既存インストールをPATHへ含める
node tools/analytics/serve.cjs --config /private/path/journey-live.json --cache-dir /private/path/journey-cache --port 8877
```

ブラウザで`http://127.0.0.1:8877`を開く。127.0.0.1だけにbindし、
Host／Originを検証する。集計の閲覧はこのMacで実行できる分析担当者に限定する。
サーバーを外部公開、トンネル、LAN公開しない。クラウド側の閲覧権限も既存の分析担当者を使う。
接続中は15分ごとに再集計し、画面の「再集計」でも同じ処理を呼ぶ。
各queryは既定100MB上限、最大179日の登録コホートを対象とし、APIポーリングはしない。
runner終了後は自動更新も終了する。新しいクラウド定期jobは追加しない。

初回接続前／失敗は人数未確認。接続できて対象者が0人なら、**BigQuery接続済み・0人**と表示する。
取得成功日時と集計の知識締切を分け、30分以上経った結果は古いと表示する。
失敗後は前回の集計を残し、更新失敗を表示する。古い値を取得成功した最新値とみなさない。
成功キャッシュは0700 directory／0600 fileへ集計値だけを保存する。
異なる接続設定・除外一覧のキャッシュは使用しない。

`server_complete_through`／`ga4_complete_through`は収集完了を確認できた場合だけ指定する。
既定NULLのままなら、成熟が必要な継続率・転換率はN/Aを維持する。
queryが成功したこと、最新イベントが到着したこと、全件の取り込み完了は別の状態。
`MAX(event_at)`や最新のquery時刻でwatermarkを補わない。

一度だけ接続を確認し、集計結果／接続状態を新しい非公開ファイルへ保存する場合:

```sh
node tools/analytics/serve.cjs --config /private/path/journey-live.json --cache-dir /private/path/journey-cache --once /private/path/new-connection-result.json
node --test tools/analytics/serve.test.cjs
```

この経路はBQのschema変更、Functions deploy、Firestore／Stripe／Schedulerへの
書き込みを実行しない。本番接続可否は実行結果で確認し、サンプルの0人と混同しない。

## Cloud Runの管理者専用接続

`cloud-run.cjs`は同じHTML・共有SQL・接続状態Modelを使用するCloud Run入口。
ローカル`serve.cjs`の公開設定は変更しない。Google管理のIAPをCloud Runへ直接設定し、
IAPのservice単位viewer権限を承認済み管理者だけへ付与する。未認証のRun invoker、
ロードバランサ、独自ドメイン、公開API、常駐集計jobは追加しない。

アプリ側もIAP署名JWTを検証する。ES256／Google公開鍵／issuer／正確なaudience／
発行・失効時刻を検証した後、署名内emailを明示allowlistと照合する。
未署名のemailヘッダーだけでは許可しない。HTML・API・404を含めて同じ検証を通す。

必要なCloud Run環境変数（実値はGit外のリリース設定で管理）:

| 変数 | 内容 |
| --- | --- |
| `PORT` | Cloud Runが指定するport。`0.0.0.0`へbind。 |
| `PUBLIC_ORIGIN` | 確認済みのサービスHTTPS origin。末尾slashなし。 |
| `IAP_AUDIENCE` | `/projects/PROJECT_NUMBER/locations/REGION/services/SERVICE_NAME`。OAuth client IDやURLを代入しない。 |
| `ADMIN_EMAILS` | ユーザーが承認したGoogleアカウントのcomma区切り。推測追加しない。 |
| `ANALYTICS_CONFIG_JSON` | 既存の非公開live config。明示test UID除外とNULL watermarkを維持する。 |

BigQuery認証はCloud Runの専用実行サービスアカウントを使用する。
metadata serverの短期tokenをメモリ内で参照し、既存SQLをREST query jobへ渡す。
Macの個人認証、ADCファイル、サービスアカウント秘密鍵、Cloud SDKはコンテナへ入れない。
権限はquery job実行と必要な2 datasetの参照に限定し、BigQuery Adminは付与しない。

初回の認証済みブラウザAPIアクセス時に集計し、以降は15分のキャッシュを共有する。
閲覧中の既存15秒state取得により、期限を過ぎた時だけ次の集計が動く。
「再集計」も同じ15分上限を使用する。失敗時も連続queryを抑制し、前回成功日時と失敗を残す。
起動時query／背景timerはない。誰もアクセスしない間はqueryしない。
最小instance0・最大instance1を基本とし、同時queryは1件へまとめる。
キャッシュはinstance内の一時領域で、scale-to-zero／再デプロイ後は消える。
その場合も0人へ補完せず、次のqueryが成功するまで未接続とする。

```sh
# リポジトリroot相当の、検証済みallowlistだけを含む隔離contextで実行
docker build -f tools/analytics/Dockerfile -t REGION-docker.pkg.dev/PROJECT/REPOSITORY/IMAGE:VERSION .
node --test tools/analytics/cloud-run.test.cjs
```

`Dockerfile.dockerignore`とCOPY一覧は実行7file＋既存SQL＋完全架空の表示fixtureだけを許可する。
test UID一覧、private config、入力rawデータ、認証情報、APK、既存Functionsをimageへ含めない。
再デプロイはimmutable image digestと同じ実行設定・IAP・IAMを記録して実施する。
rollbackは保存した旧image／revisionへtrafficを戻し、IAPや管理者限定IAMを外さない。
初回releaseで戻すrevisionがなければtraffic停止またはservice停止とし、公開設定で代用しない。
データ取得のquery成功、GA4 export完了、研究利用許可は引き続き別判定。

### 管理者の利用・反映・復元

サービスは`hamster-breeding-app`／`asia-northeast1`の`hamcare-analytics-admin`。
管理者向けの正規URLは
<https://hamcare-analytics-admin-797691641198.asia-northeast1.run.app>。
承認済みGoogleアカウントでログインする。閲覧許可はIAPのservice単位IAMと
アプリの`ADMIN_EMAILS`両方で確認する。Runの自動生成URIが別にあっても、
アプリの`PUBLIC_ORIGIN`と異なるHostは許可しない。

最小instance0／最大instance1、1 vCPU／512MiB、request-based billingを基本設定とする。
実行SAは`hamcare-analytics-admin@hamster-breeding-app.iam.gserviceaccount.com`。
BigQuery job実行権限、`server_events_raw`のtable参照、GA4 dataset参照だけを使う。
一般0人、N/A、unknown watermark、更新日時／失敗／古さは既存表示を維持する。
閲覧中だけ15分TTLで再集計し、Scheduler・ロードバランサ・独自ドメインは追加しない。

初回IAP OAuth設定は、organizationに属さないprojectではCloud Console操作が必要になる場合がある。
その場合はIAPの当該serviceから認証設定を完了してから、許可アカウントの画面E2Eを行う。
`iapEnabled=true`／revision稼働だけを、ログイン成功・BigQuery成功・画面PASSとは記録しない。
設定未完了でもIAPを解除したり、`allUsers`を付与したりして迂回しない。

再反映は、通常dirty treeからの全コピーを避け、配送allowlistとhashが一致した隔離contextでbuildする。
`tools/analytics/Dockerfile`を使用し、Artifact Registryのimmutable image digestを記録する。
当該serviceのimageだけを更新し、専用SA、環境変数、min/max、IAP、既存IAMを保持する。
反映前後で実revision・traffic・image digest・`iapEnabled=true`・invoker IAM有効を確認する。
承認済み管理者以外のIAP viewerと、公開Run invokerが増えていないことも確認する。
環境変数の非公開test UID一覧やGoogle tokenを、image・Git・公開ログへコピーしない。

初回releaseには旧revisionがない。安全な復元先がない場合はIAPを維持したまま
当該serviceの閲覧許可を停止し、未承認の公開設定や既存HamCareサービスで代用しない。
以降は保存済みの正常revisionへtrafficを戻し、IAPと管理者限定IAMを維持する。
いずれもBigQueryのtable／event／既存snapshotを削除・巻き戻ししない。
private config、image digest、revision／IAMの反映前後、検証結果はリリース記録へ保存する。

管理者2人程度の軽い利用（例：1日5〜20回の閲覧、同時閲覧は同一15分cache）では、
Cloud Run／BigQuery／Artifact Registry等の合計は概ね**月US$0〜3程度**を目安とする。
請求額の保証や新しい予算上限ではない。既存projectでの無料枠利用、query実bytes、
query中のrequest時間、image保存量、再build回数、ログ量・転送量で変わる。
queryは既存100MB上限と15分TTLを使い、夜間の無人定期queryを発生させない。
主な課金対象はRunのrequest時CPU／memory・request、BigQuery読取り、
Artifact Registry image保存、再デプロイ時のCloud Build、必要に応じたlogging／egress。
定額の追加監視基盤は作らない。
料金・無料枠の正本は[Cloud Run](https://cloud.google.com/run/pricing)、
[BigQuery](https://cloud.google.com/bigquery/pricing)、
[Artifact Registry](https://cloud.google.com/artifact-registry/pricing)、
[Cloud Build](https://cloud.google.com/build/pricing)を反映時点で確認する。

### 2026-10-18 初回Cloud Run反映の確認結果

- 稼働revision：`hamcare-analytics-admin-00001-nqv`、traffic100%、直接IAP有効。
  初回OAuth設定はユーザーのConsole操作後に保存を確認済み。許可する管理者は承認済み2アカウントのみ。
- 許可アカウントでのログイン後、専用実行SAによる既存BigQuery SCRIPTがDONE／errorなし。
  処理量113,440 bytes、上限100,000,000 bytes、query cache有効を確認。
  既存HTMLでファネル・継続率・有料転換・A3比較、一般0人／N/A、更新日時を実画面確認。
  watermarkはNULLを維持し、query成功を収集完了へ置き換えていない。
- Bを含む既存18テストアカウントの除外を維持。UID一覧・raw行はHTMLへ返さず、
  BigQuery table／記録／レポート／課金状態は変更していない。
- 未認証GETはGoogleログインへの302、POSTは401で、HTML・API・集計値を返さないことを
  正規URLとRun自動生成URLで確認。アプリ側の署名済み未許可email拒否はローカルテストPASS。
  2026-10-18、ユーザー提供の実ブラウザ画像で、許可外GoogleアカウントのIAPアクセス拒否と、
  許可アカウントの接続済み画面を確認。Cloud Run移行の最終E2EはPASS、当該工程の残件なし。
  生の画像は非公開のリリース記録に置き、表示された個人メールをGitや分析イベントへ転記しない。
  収集完了やwatermarkの成熟を、この認証・表示成功から推定しない。
- 証跡：リリース記録の`audit/oauth-configuration-check.json`、
  `audit/runtime-query-after-login.json`、`audit/screenshots/cloud-dashboard-*.png`。
  この確認に伴う追加デプロイ、計測イベント・実AI・Stripe決済の発生は行わない。
