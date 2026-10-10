# `trial_journey` 用サーバーイベント取り込み・プライバシー整理

更新日: 2026-10-04  
状態: サーバーイベント取込先・Functions ingest は作成済み。Firebase Console のGA4リンクは所有者が完了済みと報告。GA4日次テーブルは未到着、実機イベント未確認。

## 取り込み経路

`trial_journey` は Firebase Analytics 単独では作らない。無料体験、AI 枠、記録受理、
分析準備、レポート生成の正はサーバーであり、画面タップは正にしない。

```text
Flutter device
  ├─ Firebase Analytics (GA4): standard user_id=Firebase Auth UID
  │      └─ GA4 BigQuery export → analytics_549839505.events_* (Firebase管理; 未作成/未到着)
  └─ authenticated calls / Firestore write
         └─ Functions / RAG (verified UID)
                └─ Firestore server-owned event documents
                       └─ ingestJourneyEventToBigQuery / ingestAnalysisEventToBigQuery
                          / ingestAiProviderUsageToBigQuery → server_events_raw
                              └─ validated normalizer → server_events_normalized
                                     └─ trial_journey.sql → trial_journey
```

server-event ingest は、Firestore event document の ID を `source_event_id` として
BigQuery raw table に一意保存する。少なくとも次を受ける。

| Firestore source | 正規化イベント | 一意性 |
| --- | --- | --- |
| `users/{uid}/journey_events/initial_trial_started` | `initial_trial_started` | `(uid, trial_id)` |
| `.../feature_access/initial_trial_v2/ai_usage/{requestId}` | `ai_answer_succeeded` | `(uid, requestId)`、status=succeeded のみ |
| `.../analysis_events/first_accepted_*` | `first_accepted_data_saved` | source document ID |
| `.../analysis_events/readiness_*` | `analysis_readiness_changed` | state transition event ID |
| `.../analysis_events/first_report_*` | `first_personalized_report_generated` | `(uid, pet_id, report_id, revision)` |

RAG は verified UID と request hash を照合し、request ID を別 UID へ再利用できない。
GA4 の `user_pseudo_id` はこの結合に使わず、標準 `user_id` と server `uid` を結ぶ。
`trial_id` は server の immutable trial document から供給し、GA4 の未保証 client
parameter を権限・利用枠の正にしない。

現在のserver-only previewは
`hamster-breeding-app.hamcare_trial_analytics.trial_journey_preview_dashboard`。
GA4 dataset `analytics_549839505`の`events_*`がFirebase側で作成されるまでは、
最終`trial_journey.sql`は実データ結合できず、完了扱いにしない。最終行は
`(user_id, trial_id)`に固定し、レポートは`report_id=first`だけでは不十分なので、
常に`(user_id, pet_id, report_id, revision)`を保持する。

## 現在のGCP状態（2026-10-04確認）

- Google Analytics→BigQueryリンク: 所有者がFirebase Consoleで完了を確認。対象4アプリ、東京`asia-northeast1`、daily ON、streaming OFF、広告ID export OFF。リンクを再作成しない。
- Firebase管理dataset `analytics_549839505`: BigQuery上ではまだ存在せず、日次Exportデータ未着。
- Server dataset `hamcare_trial_analytics`: asia-northeast1、ownerと取込service accountだけに限定ACL。
- `server_events_raw`: `ingested_at`日次partition、partition filter必須、clusterあり。3件の`test_only`合成接続イベントがFirestoreから到着し、3つのsource event IDが一意。これらは体験開始/初回実データではない。
- `server_events_normalized`、`trial_journey_server`、`trial_journey_preview_dashboard` viewを確認。現時点の実trial行数は0、previewのreport-view状態は`awaiting_ga4_daily_export`。
- Gen2 ingest FunctionsはACTIVE。Eventarcからの呼び出しには対象ingest serviceごとにservice-account限定`run.invoker`を設定した。

## データ最小化・アクセス

取り込むのは UID、trial/policy ID、時刻、record type/source、metric state、
report/pet/revision、request ID/hash の最小メタデータだけである。Analytics の event
parameter および server event raw/normalized のいずれにも次を保存しない。

- 質問本文、回答本文、会話履歴、メモ
- 氏名、メールアドレス、ペット名、市区町村
- Firebase ID token、SwitchBot credential、決済情報

UID と analytics イベントを対応付ける内部テーブル/BigQuery dataset は analytics
operator に限定し、一般のアプリ運用者・端末利用者には公開しない。ログアウト時は
Analytics User-ID を clear し、アカウント切替時は ID 更新完了後のイベントだけを送る。
Analytics の到達成否は権限判定や課金判定に一切使わない。

## プライバシー説明・ストア申告の変更案（未公開）

公開中のプライバシーポリシーおよびストア申告を変更する前に、法務/運用承認と実機
確認を行う。改訂候補は次のとおり。

1. Firebase Authentication UID をログイン中の Firebase Analytics 標準 User-ID として
   設定し、無料体験、分析到達、レポート表示の集計に使うことを明記する。
2. 質問本文、自由記述、氏名、メールアドレス、ペット名、市区町村、認証情報は
   Analytics に送らないことを明記する。
3. BigQuery は Firebase/Google Cloud 上の限定アクセス分析基盤であり、広告、販売、
   他社サイト横断トラッキングには用いないことを明記する。
4. Apple App Privacy と Google Play Data Safety の `Identifiers > User ID` と
   `App activity > App interactions` が、Analytics と紐付く可能性をストア管理画面の
   最新質問文で再評価する。既存の質問・会話データ申告は AI 機能提供のための別経路
   として維持する。

具体的な申告候補は `docs/release/privacy_disclosure_checklist_ja.md` にあり、上記を
承認するまでは公開ポリシー、ストア入力、一般配布を変更しない。

## 以降に必要な証跡（実機・実データ）

1. GA4 DebugView でテストUID A の `ai_consultation_completed` と
   `personalized_report_viewed` を確認する。
2. 同じ UID A の Firestore server event で `trial_id`、AI 成功、record/readiness/report
   generation を確認する。
3. raw/normalized table で source event ID の重複がないことを確認する。
4. GA4の`events_*`到着後に`trial_journey.sql`を対象期間・最大bytes指定で実行し、UID A / trial ID の 1 行に
   report generation と report view が結び付くことを確認する。
5. UID B の `report_id=first` が UID A の行に混ざらず、A の再閲覧が row count ではなく
   view count だけを増やすことを確認する。

GA4 exportが未到着の間は`awaiting_ga4_daily_export`として扱い、0件・未到達に埋め替えない。
実機Analytics受信、GA4→BigQuery到着、server側metadata取込、最後のjoinは別々に検証する。
