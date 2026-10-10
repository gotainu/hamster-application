-- HamCare metadata-only server event views.
-- Executed in hamster-breeding-app / asia-northeast1.
-- The fixed 180-day partition predicate satisfies requirePartitionFilter and
-- bounds scans. This dataset is currently test-only; production data is not
-- admitted by the Functions triggers.

CREATE OR REPLACE VIEW
  `hamster-breeding-app.hamcare_trial_analytics.server_events_normalized`
AS
SELECT * EXCEPT(row_rank)
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY source_event_id
      ORDER BY ingested_at DESC
    ) AS row_rank
  FROM `hamster-breeding-app.hamcare_trial_analytics.server_events_raw`
  WHERE ingested_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 180 DAY)
    AND test_only = TRUE
)
WHERE row_rank = 1;

CREATE OR REPLACE VIEW
  `hamster-breeding-app.hamcare_trial_analytics.trial_journey_server`
AS
WITH events AS (
  SELECT * FROM `hamster-breeding-app.hamcare_trial_analytics.server_events_normalized`
),
trials AS (
  SELECT
    user_id,
    trial_id,
    ARRAY_AGG(policy_version IGNORE NULLS ORDER BY event_at LIMIT 1)[SAFE_OFFSET(0)] AS policy_version,
    MIN(event_at) AS trial_started_at,
    ARRAY_AGG(trial_ends_at IGNORE NULLS ORDER BY event_at LIMIT 1)[SAFE_OFFSET(0)] AS trial_ends_at,
    MIN(ingested_at) AS first_event_ingested_at
  FROM events
  WHERE event_name = 'initial_trial_started'
  GROUP BY user_id, trial_id
),
milestones AS (
  SELECT
    t.user_id,
    t.trial_id,
    MIN(IF(e.event_name = 'ai_answer_succeeded', e.event_at, NULL)) AS first_ai_answer_at,
    MIN(IF(e.event_name = 'first_accepted_data_saved', e.event_at, NULL)) AS first_record_at,
    ARRAY_AGG(IF(e.event_name = 'first_accepted_data_saved', e.record_type, NULL)
      IGNORE NULLS ORDER BY e.event_at LIMIT 1)[SAFE_OFFSET(0)] AS first_record_type,
    MIN(IF(e.event_name = 'analysis_readiness_changed' AND e.metric = 'body'
      AND e.current_status = 'ready', e.event_at, NULL)) AS body_first_ready_at,
    MIN(IF(e.event_name = 'analysis_readiness_changed' AND e.metric = 'activity'
      AND e.current_status = 'ready', e.event_at, NULL)) AS activity_first_ready_at,
    MIN(IF(e.event_name IN ('first_personalized_report_generated', 'personality_report_generated'), e.event_at, NULL)) AS first_report_generated_at,
    ARRAY_AGG(IF(e.event_name IN ('first_personalized_report_generated', 'personality_report_generated'), e.pet_id, NULL)
      IGNORE NULLS ORDER BY e.event_at LIMIT 1)[SAFE_OFFSET(0)] AS first_report_pet_id,
    ARRAY_AGG(IF(e.event_name IN ('first_personalized_report_generated', 'personality_report_generated'), e.report_id, NULL)
      IGNORE NULLS ORDER BY e.event_at LIMIT 1)[SAFE_OFFSET(0)] AS first_report_id,
    ARRAY_AGG(IF(e.event_name IN ('first_personalized_report_generated', 'personality_report_generated'), e.report_revision, NULL)
      IGNORE NULLS ORDER BY e.event_at LIMIT 1)[SAFE_OFFSET(0)] AS first_report_revision,
    COUNTIF(e.source_collection = 'ai_provider_calls' AND e.status = 'unknown') AS unknown_provider_call_count,
    MAX(e.ingested_at) AS last_server_event_ingested_at
  FROM trials t
  LEFT JOIN events e
    ON e.user_id = t.user_id
    AND (e.trial_id = t.trial_id OR e.source_collection = 'ai_provider_calls')
    AND e.event_at >= t.trial_started_at
  GROUP BY t.user_id, t.trial_id
)
SELECT
  t.user_id,
  t.trial_id,
  t.policy_version,
  t.trial_started_at,
  t.trial_ends_at,
  m.first_ai_answer_at,
  m.first_record_at,
  m.first_record_type,
  m.body_first_ready_at,
  m.activity_first_ready_at,
  m.first_report_generated_at,
  m.first_report_pet_id,
  m.first_report_id,
  m.first_report_revision,
  CAST(NULL AS TIMESTAMP) AS first_report_viewed_at,
  CAST(NULL AS STRING) AS first_report_viewed_pet_id,
  CAST(NULL AS STRING) AS first_report_viewed_id,
  CAST(NULL AS INT64) AS first_report_viewed_revision,
  'awaiting_ga4_daily_export' AS report_view_measurement_status,
  CAST(NULL AS TIMESTAMP) AS first_paywall_viewed_at,
  CAST(NULL AS INT64) AS paywall_display_count,
  'awaiting_ga4_daily_export' AS paywall_measurement_status,
  m.unknown_provider_call_count,
  1 + m.unknown_provider_call_count AS measurement_unknown_count,
  TIMESTAMP_DIFF(m.first_ai_answer_at, t.trial_started_at, MINUTE) AS minutes_to_first_ai_answer,
  TIMESTAMP_DIFF(m.first_record_at, t.trial_started_at, MINUTE) AS minutes_to_first_record,
  TIMESTAMP_DIFF(m.body_first_ready_at, t.trial_started_at, MINUTE) AS minutes_to_body_ready,
  TIMESTAMP_DIFF(m.activity_first_ready_at, t.trial_started_at, MINUTE) AS minutes_to_activity_ready,
  TIMESTAMP_DIFF(m.first_report_generated_at, t.trial_started_at, MINUTE) AS minutes_to_first_report_generated,
  CAST(NULL AS INT64) AS minutes_to_first_report_viewed,
  t.first_event_ingested_at,
  m.last_server_event_ingested_at
FROM trials t
JOIN milestones m USING (user_id, trial_id);

-- One-row private preview page. Report display stays NULL/unknown until the
-- Firebase-created GA4 dataset analytics_549839505 exists and is joined by
-- standard user_id plus pet_id/report_id/revision.
CREATE OR REPLACE VIEW
  `hamster-breeding-app.hamcare_trial_analytics.trial_journey_preview_dashboard`
AS
SELECT
  COUNT(*) AS trial_starts,
  COUNTIF(first_ai_answer_at IS NOT NULL) AS trials_with_first_ai_answer,
  COUNTIF(first_record_at IS NOT NULL) AS trials_with_first_record,
  COUNTIF(body_first_ready_at IS NOT NULL) AS trials_body_ready,
  COUNTIF(activity_first_ready_at IS NOT NULL) AS trials_activity_ready,
  COUNTIF(first_report_generated_at IS NOT NULL) AS trials_with_report_generated,
  CAST(NULL AS INT64) AS trials_with_report_viewed,
  COUNT(*) AS report_view_measurement_unknown_count,
  COUNT(*) AS paywall_measurement_unknown_count,
  CAST(NULL AS INT64) AS trials_with_paywall_presented,
  COUNTIF(unknown_provider_call_count > 0) AS trials_with_unknown_provider_calls,
  APPROX_QUANTILES(minutes_to_first_ai_answer, 100)[SAFE_OFFSET(50)] AS median_minutes_to_ai,
  APPROX_QUANTILES(minutes_to_first_record, 100)[SAFE_OFFSET(50)] AS median_minutes_to_record,
  APPROX_QUANTILES(minutes_to_body_ready, 100)[SAFE_OFFSET(50)] AS median_minutes_to_body_ready,
  APPROX_QUANTILES(minutes_to_activity_ready, 100)[SAFE_OFFSET(50)] AS median_minutes_to_activity_ready,
  APPROX_QUANTILES(minutes_to_first_report_generated, 100)[SAFE_OFFSET(50)] AS median_minutes_to_report_generated,
  CAST(NULL AS INT64) AS median_minutes_to_report_viewed,
  CAST(NULL AS INT64) AS median_minutes_to_paywall_presented,
  MAX(last_server_event_ingested_at) AS last_updated_at,
  'awaiting_ga4_daily_export' AS report_view_data_status
FROM `hamster-breeding-app.hamcare_trial_analytics.trial_journey_server`;
