-- Final UID-keyed daily-export join. Do not execute until Firebase has created
-- `hamster-breeding-app.analytics_549839505` and at least one daily events_* table.
-- No Firebase link is created or changed by this SQL.
-- Query window is bounded to 180 daily suffixes; GA4 daily exports can arrive
-- after the action, so a null view is not called a user failure.

CREATE OR REPLACE VIEW
  `hamster-breeding-app.hamcare_trial_analytics.trial_journey`
AS
WITH server AS (
  SELECT * FROM `hamster-breeding-app.hamcare_trial_analytics.trial_journey_server`
),
report_generations AS (
  SELECT
    user_id,
    trial_id,
    pet_id,
    report_id,
    report_revision,
    MIN(event_at) AS generated_at,
    ARRAY_AGG(analysis_spec_version IGNORE NULLS ORDER BY event_at LIMIT 1)[SAFE_OFFSET(0)] AS analysis_spec_version
  FROM `hamster-breeding-app.hamcare_trial_analytics.server_events_normalized`
  WHERE event_name IN ('first_personalized_report_generated', 'personality_report_generated')
    AND trial_id IS NOT NULL
    AND pet_id IS NOT NULL
    AND report_id IS NOT NULL
    AND report_revision IS NOT NULL
  GROUP BY user_id, trial_id, pet_id, report_id, report_revision
),
ga4_events AS (
  SELECT
    user_id,
    event_name,
    TIMESTAMP_MICROS(event_timestamp) AS event_at,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'report_id') AS report_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'pet_id') AS pet_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'analysis_revision') AS report_revision,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'presentation_id') AS presentation_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'feature_name') AS feature_name,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'analytics_identity_version') AS analytics_identity_version,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'test_only') AS test_only
  FROM `hamster-breeding-app.analytics_549839505.events_*`
  WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 179 DAY))
    AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
    AND event_name IN ('personalized_report_viewed', 'paywall_presented')
    AND user_id IS NOT NULL AND user_id != ''
),
test_ga4 AS (
  SELECT * FROM ga4_events
  WHERE test_only = 1
    AND analytics_identity_version = 'firebase_uid_v1'
),
matched_report_views AS (
  SELECT
    s.user_id,
    s.trial_id,
    v.event_at,
    v.presentation_id,
    g.pet_id,
    g.report_id,
    g.report_revision,
    g.analysis_spec_version
  FROM server s
  JOIN report_generations g
    ON g.user_id = s.user_id AND g.trial_id = s.trial_id
  JOIN test_ga4 v
    ON v.event_name = 'personalized_report_viewed'
    AND v.user_id = g.user_id
    AND v.pet_id = g.pet_id
    AND v.report_id = g.report_id
    AND v.report_revision = g.report_revision
    AND v.event_at >= g.generated_at
    AND v.event_at >= s.trial_started_at
),
views_by_trial AS (
  SELECT
    user_id,
    trial_id,
    MIN(event_at) AS first_report_viewed_at,
    ARRAY_AGG(pet_id IGNORE NULLS ORDER BY event_at LIMIT 1)[SAFE_OFFSET(0)] AS first_report_viewed_pet_id,
    ARRAY_AGG(report_id IGNORE NULLS ORDER BY event_at LIMIT 1)[SAFE_OFFSET(0)] AS first_report_viewed_id,
    ARRAY_AGG(report_revision IGNORE NULLS ORDER BY event_at LIMIT 1)[SAFE_OFFSET(0)] AS first_report_viewed_revision,
    ARRAY_AGG(analysis_spec_version IGNORE NULLS ORDER BY event_at LIMIT 1)[SAFE_OFFSET(0)] AS first_report_viewed_spec_version,
    COUNT(DISTINCT presentation_id) AS report_view_count
  FROM matched_report_views
  GROUP BY user_id, trial_id
),
paywall_by_trial AS (
  SELECT
    s.user_id,
    s.trial_id,
    MIN(g.event_at) AS first_paywall_viewed_at,
    COUNT(DISTINCT g.presentation_id) AS paywall_display_count
  FROM server s
  LEFT JOIN test_ga4 g
    ON g.user_id = s.user_id
    AND g.event_name = 'paywall_presented'
    AND g.event_at >= s.trial_started_at
  GROUP BY s.user_id, s.trial_id
)
SELECT
  s.* EXCEPT(first_report_viewed_at, first_report_viewed_pet_id,
    first_report_viewed_id, first_report_viewed_revision,
    minutes_to_first_report_viewed, report_view_measurement_status),
  v.first_report_viewed_at,
  v.first_report_viewed_pet_id,
  v.first_report_viewed_id,
  v.first_report_viewed_revision,
  v.first_report_viewed_spec_version,
  v.report_view_count,
  TIMESTAMP_DIFF(v.first_report_viewed_at, s.trial_started_at, MINUTE) AS minutes_to_first_report_viewed,
  IF(v.first_report_viewed_at IS NULL, 'no_matching_ga4_event_yet', 'observed') AS report_view_measurement_status,
  p.first_paywall_viewed_at,
  p.paywall_display_count,
  TIMESTAMP_DIFF(p.first_paywall_viewed_at, s.trial_started_at, MINUTE) AS minutes_to_first_paywall_viewed,
  CURRENT_TIMESTAMP() >= TIMESTAMP_ADD(s.trial_ends_at, INTERVAL 72 HOUR) AS eligible_for_21d_cohort,
  v.first_report_viewed_at IS NOT NULL
    AND v.first_report_viewed_at < s.trial_ends_at AS report_viewed_within_trial,
  CASE
    WHEN v.first_report_viewed_at IS NULL THEN NULL
    WHEN v.first_report_viewed_at < s.trial_ends_at THEN 'within_trial'
    ELSE 'after_trial'
  END AS report_view_timing
FROM server s
LEFT JOIN views_by_trial v USING (user_id, trial_id)
LEFT JOIN paywall_by_trial p USING (user_id, trial_id);

-- Private dashboard view: aggregate only, never expose UID rows on the page.
CREATE OR REPLACE VIEW
  `hamster-breeding-app.hamcare_trial_analytics.trial_journey_dashboard`
AS
SELECT
  COUNT(*) AS trial_starts,
  COUNTIF(first_ai_answer_at IS NOT NULL) AS trials_with_first_ai_answer,
  COUNTIF(first_record_at IS NOT NULL) AS trials_with_first_record,
  COUNTIF(body_first_ready_at IS NOT NULL) AS trials_body_ready,
  COUNTIF(activity_first_ready_at IS NOT NULL) AS trials_activity_ready,
  COUNTIF(first_report_generated_at IS NOT NULL) AS trials_with_report_generated,
  COUNTIF(first_report_viewed_at IS NOT NULL) AS trials_with_report_viewed,
  COUNTIF(first_paywall_viewed_at IS NOT NULL) AS trials_with_paywall_presented,
  COUNTIF(report_view_measurement_status = 'no_matching_ga4_event_yet') AS report_view_measurement_unknown_count,
  COUNTIF(unknown_provider_call_count > 0) AS trials_with_unknown_provider_calls,
  COUNTIF(eligible_for_21d_cohort) AS mature_21d_trial_count,
  APPROX_QUANTILES(minutes_to_first_ai_answer, 100)[SAFE_OFFSET(50)] AS median_minutes_to_ai,
  APPROX_QUANTILES(minutes_to_first_record, 100)[SAFE_OFFSET(50)] AS median_minutes_to_record,
  APPROX_QUANTILES(minutes_to_body_ready, 100)[SAFE_OFFSET(50)] AS median_minutes_to_body_ready,
  APPROX_QUANTILES(minutes_to_activity_ready, 100)[SAFE_OFFSET(50)] AS median_minutes_to_activity_ready,
  APPROX_QUANTILES(minutes_to_first_report_generated, 100)[SAFE_OFFSET(50)] AS median_minutes_to_report_generated,
  APPROX_QUANTILES(minutes_to_first_report_viewed, 100)[SAFE_OFFSET(50)] AS median_minutes_to_report_viewed,
  APPROX_QUANTILES(minutes_to_first_paywall_viewed, 100)[SAFE_OFFSET(50)] AS median_minutes_to_paywall_presented,
  MAX(last_server_event_ingested_at) AS latest_server_metadata_at,
  CURRENT_TIMESTAMP() AS dashboard_refreshed_at
FROM `hamster-breeding-app.hamcare_trial_analytics.trial_journey`;
