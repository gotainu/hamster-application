# `trial_journey` input and first dashboard specification

The table has one row per `(user_id, trial_id)`. `user_id` is the Firebase
Authentication UID: in Analytics it comes only from GA4's standard `user_id`,
and on the server it comes from an authenticated path or verified token. GA4
`user_pseudo_id` is not a join key.

## Server normalization input

The future Firestore-to-BigQuery normalizer emits `server_events_normalized`.
It reads event metadata only, never memo text, chat text, names, emails, or
city fields.

| Source | Normalized event | Timestamp | Notes |
| --- | --- | --- | --- |
| `journey_events/initial_trial_started` | `initial_trial_started` | `startedAt` | Carries trial ID, policy version, fixed end time. |
| `feature_access/initial_trial_v2/ai_usage/*` | `ai_answer_succeeded` | `succeededAt` | Only `succeeded`; request ID is idempotency key. |
| `analysis_events/first_accepted_*` | `first_accepted_data_saved` | `serverReceivedAt` | `observationAt` remains separate; kind identifies weight/activity/check-in/SwitchBot. |
| `analysis_events/readiness_*` | `analysis_readiness_changed` | `occurredAt` | Ready and not-ready transitions both remain. |
| `analysis_events/first_report_*` | `first_personalized_report_generated` | `occurredAt` | Report ID, pet ID, revision, and spec version. |

`observed` means suitable instrumentation saw an event. `not_observed` means
no event in an instrumented observation range; `not_instrumented` means the
trial predates that event stream; `unknown` means ingestion cannot establish
either; `not_applicable` is reserved for a metric explicitly excluded by the
product. A NULL timestamp alone does not choose a status.

## Analytics input

GA4 export supplies `user_id`, `event_name`, `event_timestamp`, and event
parameters. Required metadata is limited to report/pet/revision/presentation
and monitoring-offer fields. It contains no free-text user input.
`personalized_report_viewed` is emitted only after a generated report is
fetched and painted; a button press is not a view.

## First dashboard page

For a trial-start cohort and policy/app version, show:

1. Trial starts (server source of truth), first accepted record, body-ready,
   activity-ready, first report generated, and first report displayed.
2. At each stage: observed, not-instrumented, unknown, and completed-window
   denominator separately.
3. Median and p90 elapsed time from start to every observed stage.
4. First-record method (`manual`/`sensor`) and record-kind breakdown.
5. Policy and app/flow version filters, event range, and last ETL update time.

The dashboard must not display a UID list. A report generated or read after a
trial ends remains `after_trial`; it is retained but not claimed as in-trial
conversion.

## Current connection state and next execution path

1. Firebase Console link is complete per owner: all four apps, daily export on,
   streaming off, ad ID export off, location `asia-northeast1`. Do not recreate
   the link. The Firebase-owned `analytics_549839505` dataset and `events_*`
   tables are not yet visible in BigQuery as of 2026-10-04.
2. Restricted server metadata dataset `hamcare_trial_analytics` exists in the
   same `asia-northeast1` location. Its raw table, normalized/server views, and
   preview dashboard exist; ingest Functions are deployed. ACL is limited to
   the owner and ingest service account.
3. Firestore-to-BigQuery path was smoke-tested with three synthetic
   `test_only` events and three distinct source IDs. They are not trials or
   real user outcomes. No general trial_journey row exists yet.
4. After GA4 daily tables arrive, run `trial_journey.sql` manually with a
   restricted date range and maximum bytes billed. Only then consider a
   scheduled refresh; review freshness, late-arrival, and access first.
5. Record the normalizer/application schema version with every output refresh.

The preview dashboard is a server-only status surface while the GA4 export is
awaiting arrival; it must not be presented as an end-to-end connected dashboard.
