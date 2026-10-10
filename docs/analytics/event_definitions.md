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
