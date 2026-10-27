# Trial and analysis event definitions

All Firebase Analytics events below use standard Analytics `user_id` set from
Firebase Auth UID after login. UID is not copied into event parameters. Server
events use a verified UID as their document owner. Neither event stream carries
question text, answers, memo text, names, email, city, tokens, or keys.

| Event | Trigger / source of truth | Actor | Repeat | Parameters or fields | Destination | Duplicate control | Local verification |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `initial_trial_started` | Server creates immutable initial-trial document | server | Once per `(user_id, trial_id)` | trial ID, policy version, start/end | Firestore `journey_events`; normalizer | transaction + fixed doc ID | Functions unit test |
| `initial_trial_start_attempt` | User asks callable to start | user client | Each attempt | flow version, success/failed | Firebase Analytics | each genuine tap; never used as start numerator | static call review |
| `ai_answer_succeeded` | RAG `ai_usage` status becomes `succeeded` | server | Once per `(uid, request_id)` | request ID, entitlement source, succeeded time | Firestore; normalizer | reservation doc + request hash | mocked RAG tests |
| `first_accepted_data_saved` | First valid create for a record kind | user client / sensor | Once per user and kind | record type, manual/sensor, observation time, server-received time, source doc ID | Firestore `analysis_events`; normalizer | transaction + fixed first-event ID | Functions compile; emulator deployment path pending |
| `analysis_readiness_changed` | Server baseline status changes, including first ready | health pipeline | State transitions; first-ready only once | metric, old/current status, spec version, first-ready time | Firestore `analysis_events`; normalizer | transition sequence / fixed first-ready ID | Functions unit test |
| `first_personalized_report_generated` | Report logical ID obtains a first/new revision | health pipeline | Once per generated revision | pet, report ID, revision, ready metrics, spec version | Firestore `analysis_events`; normalizer | fixed report/revision doc ID | Functions unit test |
| `personalized_report_viewed` | Generated report fetch succeeds and its screen paints | user client | Each separate screen presentation | pet, report ID, revision, presentation ID, auto flag | Firebase Analytics | widget state logs once per revision/presentation; opening later is another view | Flutter static analysis/test pending device |
| `monitoring_method_presented` | Method chooser paints | user client | Each screen presentation | presentation ID, offer version, option order, availability | Firebase Analytics | one post-frame event per screen state | Flutter static analysis |
| `monitoring_method_selected` | User selects an offered method | user client | Each genuine selection | same presentation ID, selected method/position, offer version/order | Firebase Analytics | linked to presentation ID | Flutter static analysis |
| `paywall_presented` | Locked trial/paid feature view paints | user client | Each distinct display opportunity | flow version, feature name | Firebase Analytics | stateful tracker, not rebuild | Flutter static analysis |

The Firestore normalizer must label unavailable historical event streams as
`not_instrumented`, ingestion uncertainty as `unknown`, and a monitored stream
with no event as `not_observed`. It must not fabricate events after record
deletion/overwrite and must keep observation time separate from acceptance time.

## ローンチ計測の追加（2026-10-17、ローカル実装・未反映）

既存のtrial／A1／A2／ready／生成／表示イベントを置き換えず、不足分のみ追加する。
A1は「初回AI相談成功」という代理指標であり、主観的な価値実感を証明しない。

| 追加・補強イベント | 確定元 | 一意性・集計上の扱い |
| --- | --- | --- |
| `account_registered` | Auth作成trigger | 本人UIDから固定イベントID。過去ユーザーの生成はしない。 |
| `valid_record_saved` | 受理済み体重／活動量／観察／ケアのimmutable revision | revisionごとの固定ID。取消・再送を新しい利用にしない。記録対象日でなく受理日が能動的利用日。 |
| `checkout_started` | 既存クライアントの開始イベントを維持 | 画面表示・契約成立と分離。共通`event_id`で再配送重複排除。 |
| `subscription_activated` | Stripe最新状態の同期が確定したサーバーの課金document | active＋paid。Stripe trialing／Checkout表示だけでは発火しない。一般課金数は`billing_livemode=TRUE`のみ。 |
| `subscription_cancel_scheduled` | 同じ確定済み課金状態の遷移 | 解約予約。期限内の利用権限を終了扱いにしない。 |
| `subscription_ended` | 同じ確定済み課金状態の遷移 | 実際の利用権限終了。予約と別集計。 |
| `subscription_payment_failed` | 同じ確定済み課金状態の遷移 | 支払失敗の運用指標。契約成立数や能動的利用数にしない。 |

server metadataへ`environment=live/test/emulator/unknown`、
`account_classification=general/test/unknown`、nullable `billing_livemode`を追加する。
クライアントは`analytics_environment`、明示的な`test_only=0/1`、`event_id`を送る。
一般集計はserver側でlive/generalと確認できた登録UIDに限定し、GA4もlive・test_only=0と
標準User-IDの一致を要求する。Unknownを一般ユーザーへ推測分類しない。
Sandboxはtest、Emulatorはemulator、debugビルドはtestとして除外する。
本番設定のテストUID一覧も併用し、クライアント自己申告だけで一般ユーザーと判定しない。

`personalized_report_viewed`の結合は
`(user_id, pet_id, report_id, report_revision)`の全一致＋生成後の表示時刻が必要。
画面遷移・GA4の匿名pseudo-IDだけでA3表示を補完しない。
同一イベントID／presentationの再配送は1件、別の表示機会は別件として残す。
健康記録の値・自由記述、AI相談内容、メール、決済内容は追加しない。
