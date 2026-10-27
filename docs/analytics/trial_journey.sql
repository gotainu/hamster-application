-- BigQuery Standard SQL; bounded, parameterized, metadata-only extraction.
-- No permanent tables/views are changed. Append dashboard_queries.sql to consume
-- journey_users in the same job, or export these private facts to a restricted
-- analyst dataset only after release approval. Do not expose UID facts in Looker.
-- Required parameters:
-- @as_of TIMESTAMP, @server_complete_through TIMESTAMP (nullable),
-- @ga4_complete_through TIMESTAMP (nullable), @cohort_start DATE, @cohort_end DATE,
-- @conversion_horizon_days INT64=28, @landmark_days INT64=14,
-- @landmark_followup_day INT64=21, @excluded_user_ids ARRAY<STRING>. These analytics horizons are configurable;
-- they neither change entitlement/trial duration nor research label policies.
-- General users only: explicit live + general classification. Unknown historical
-- rows are not silently promoted. Apply server_event_schema_migration.sql first.
ASSERT @as_of IS NOT NULL AS 'as_of is required';
ASSERT @cohort_start <= @cohort_end AND DATE_DIFF(DATE(@as_of), @cohort_start, DAY) <= 180
  AS 'Use a cohort within a bounded 180-day extraction window';
ASSERT @conversion_horizon_days > @landmark_days AND @landmark_days > 0
  AND @landmark_followup_day >= @landmark_days AS 'Invalid evaluation horizons';
ASSERT (@server_complete_through IS NULL OR @server_complete_through <= @as_of)
  AND (@ga4_complete_through IS NULL OR @ga4_complete_through <= @as_of)
  AS 'Source completeness cannot exceed as_of';

CREATE TEMP TABLE journey_users AS
WITH server_dedup AS (
 SELECT * EXCEPT(rn) FROM (
  SELECT *,ROW_NUMBER() OVER(PARTITION BY user_id,source_event_id ORDER BY ingested_at DESC,TO_JSON_STRING(r) DESC) rn
  FROM `hamster-breeding-app.hamcare_trial_analytics.server_events_raw` r
  WHERE ingested_at >= TIMESTAMP_SUB(@as_of,INTERVAL 180 DAY) AND ingested_at <= @as_of
    AND event_at <= @as_of AND user_id IS NOT NULL AND source_event_id IS NOT NULL
 ) WHERE rn=1
), events AS (
 SELECT * FROM server_dedup WHERE environment='live' AND account_classification='general' AND test_only=FALSE
  AND user_id NOT IN UNNEST(@excluded_user_ids)
), registrations AS (
 SELECT user_id,MIN(event_at) registered_at FROM events WHERE event_name='account_registered' GROUP BY user_id
), roster AS (
 SELECT * FROM registrations WHERE DATE(registered_at,'Asia/Tokyo') BETWEEN @cohort_start AND @cohort_end
), trials AS (
 SELECT r.*,ARRAY_AGG(IF(e.event_name='initial_trial_started',STRUCT(e.event_at AS trial_at,e.trial_id AS trial_id),NULL)
   IGNORE NULLS ORDER BY e.event_at,e.trial_id LIMIT 1)[SAFE_OFFSET(0)] trial
 FROM roster r LEFT JOIN events e ON e.user_id=r.user_id AND e.event_at>=r.registered_at GROUP BY r.user_id,r.registered_at
), scoped AS (
 SELECT t.user_id,e.* EXCEPT(user_id) FROM trials t JOIN events e ON e.user_id=t.user_id AND e.event_at>=t.trial.trial_at
  AND (e.trial_id=t.trial.trial_id OR e.trial_id IS NULL)
), generations AS (
 SELECT user_id,pet_id,report_id,report_revision,MIN(event_at) generated_at FROM scoped
 WHERE event_name IN ('first_personalized_report_generated','personality_report_generated')
  AND pet_id IS NOT NULL AND report_id IS NOT NULL AND report_revision IS NOT NULL
 GROUP BY user_id,pet_id,report_id,report_revision
), ga4_raw AS (
 SELECT user_id,event_name,TIMESTAMP_MICROS(event_timestamp) event_at,
  (SELECT MAX(value.string_value) FROM UNNEST(event_params) WHERE key='pet_id') pet_id,
  (SELECT MAX(value.string_value) FROM UNNEST(event_params) WHERE key='report_id') report_id,
  (SELECT MAX(value.int_value) FROM UNNEST(event_params) WHERE key='analysis_revision') report_revision,
  (SELECT MAX(value.string_value) FROM UNNEST(event_params) WHERE key='event_id') event_id,
  (SELECT MAX(value.string_value) FROM UNNEST(event_params) WHERE key='presentation_id') presentation_id,
  (SELECT MAX(value.string_value) FROM UNNEST(event_params) WHERE key='analytics_identity_version') identity_version,
  (SELECT MAX(value.string_value) FROM UNNEST(event_params) WHERE key='analytics_environment') environment,
  (SELECT MAX(value.int_value) FROM UNNEST(event_params) WHERE key='test_only') test_only
 FROM `hamster-breeding-app.analytics_549839505.events_*`
 WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d',DATE(@cohort_start)) AND FORMAT_DATE('%Y%m%d',DATE(@as_of))
  AND event_name IN ('personalized_report_viewed','paywall_presented','checkout_started')
  AND TIMESTAMP_MICROS(event_timestamp)<=@as_of AND user_id IS NOT NULL
), ga4 AS (
 SELECT * EXCEPT(rn) FROM (
  SELECT g.*,ROW_NUMBER() OVER(PARTITION BY g.user_id,g.event_name,COALESCE(g.event_id,g.presentation_id)
    ORDER BY g.event_at,TO_JSON_STRING(g)) rn FROM ga4_raw g JOIN roster r USING(user_id)
  WHERE g.identity_version='firebase_uid_v1' AND g.environment='live' AND g.test_only=0
   AND COALESCE(g.event_id,g.presentation_id) IS NOT NULL
 ) WHERE rn=1
), views AS (
 SELECT v.user_id,v.event_at,v.pet_id,v.report_id,v.report_revision,COALESCE(v.event_id,v.presentation_id) view_id
 FROM ga4 v JOIN generations g USING(user_id,pet_id,report_id,report_revision)
 WHERE v.event_name='personalized_report_viewed' AND v.event_at>=g.generated_at
), manual_records AS (
 SELECT * FROM events WHERE event_name IN ('first_accepted_data_saved','valid_record_saved')
  AND actor='user_client' AND record_source='manual' AND record_type!='switchbot_reading'
), active_days AS (
 SELECT DISTINCT user_id,DATE(event_at,'Asia/Tokyo') active_day FROM (
  SELECT user_id,event_at FROM manual_records WHERE event_name='valid_record_saved'
  UNION ALL SELECT user_id,event_at FROM events WHERE event_name='ai_answer_succeeded'
  UNION ALL SELECT user_id,event_at FROM views
 )
), reach AS (
 SELECT t.*,
  (SELECT MIN(event_at) FROM scoped e WHERE e.user_id=t.user_id AND event_name='ai_answer_succeeded') ai_at,
  (SELECT MIN(event_at) FROM manual_records e WHERE e.user_id=t.user_id AND e.event_at>=t.trial.trial_at AND record_type IN ('weight','activity','distance')) record_at,
  (SELECT MIN(event_at) FROM scoped e WHERE e.user_id=t.user_id AND event_name='analysis_readiness_changed' AND current_status='ready' AND metric IN ('body','activity')) ready_at,
  (SELECT MIN(event_at) FROM scoped e WHERE e.user_id=t.user_id AND event_name='analysis_readiness_changed' AND current_status='ready' AND metric='body') body_at,
  (SELECT MIN(event_at) FROM scoped e WHERE e.user_id=t.user_id AND event_name='analysis_readiness_changed' AND current_status='ready' AND metric='activity') activity_at,
  (SELECT MIN(generated_at) FROM generations g WHERE g.user_id=t.user_id) generated_at,
  (SELECT MIN(event_at) FROM views v WHERE v.user_id=t.user_id) viewed_at,
  (SELECT MIN(event_at) FROM scoped e WHERE e.user_id=t.user_id AND event_name='subscription_activated' AND billing_livemode=TRUE) paid_at,
  EXISTS(SELECT 1 FROM ga4 g WHERE g.user_id=t.user_id AND g.event_at>=t.trial.trial_at AND g.event_name='paywall_presented') has_paywall,
  EXISTS(SELECT 1 FROM ga4 g WHERE g.user_id=t.user_id AND g.event_at>=t.trial.trial_at AND g.event_name='checkout_started') has_checkout,
  EXISTS(SELECT 1 FROM scoped e WHERE e.user_id=t.user_id AND event_name='subscription_cancel_scheduled') has_cancel,
  EXISTS(SELECT 1 FROM scoped e WHERE e.user_id=t.user_id AND event_name='subscription_ended') has_end
 FROM trials t
), sequence_record AS (
 SELECT r.*,(SELECT MIN(event_at) FROM manual_records e WHERE e.user_id=r.user_id
  AND e.event_at>=r.ai_at AND record_type IN ('weight','activity','distance')) ordered_record_at FROM reach r
), sequence_ready AS (
 SELECT r.*,(SELECT MIN(event_at) FROM scoped e WHERE e.user_id=r.user_id AND e.event_at>=r.ordered_record_at
  AND event_name='analysis_readiness_changed' AND current_status='ready' AND metric IN ('body','activity')) ordered_ready_at FROM sequence_record r
), sequence_generated AS (
 SELECT r.*,(SELECT MIN(generated_at) FROM generations g WHERE g.user_id=r.user_id AND generated_at>=r.ordered_ready_at) ordered_generated_at FROM sequence_ready r
), sequence_viewed AS (
 SELECT r.*,(SELECT MIN(event_at) FROM views v WHERE v.user_id=r.user_id AND event_at>=r.ordered_generated_at) ordered_viewed_at FROM sequence_generated r
), sequence_paid AS (
 SELECT r.*,(SELECT MIN(event_at) FROM scoped e WHERE e.user_id=r.user_id AND event_at>=r.ordered_viewed_at
  AND event_name='subscription_activated' AND billing_livemode=TRUE) ordered_paid_at FROM sequence_viewed r
), scored AS (
 SELECT r.*,
  LEAST(@server_complete_through,@ga4_complete_through) complete_through,
  TIMESTAMP_ADD(trial.trial_at,INTERVAL @conversion_horizon_days DAY) conversion_end,
  TIMESTAMP_ADD(trial.trial_at,INTERVAL @landmark_days DAY) landmark_at,
  DATE_ADD(DATE(trial.trial_at,'Asia/Tokyo'),INTERVAL @landmark_followup_day DAY) followup_day
 FROM sequence_paid r
)
SELECT user_id,1 AS registered,CAST(trial.trial_at IS NOT NULL AS INT64) trial_started,
 CAST(ai_at IS NOT NULL AS INT64) a1,CAST(record_at IS NOT NULL AS INT64) a2,
 CAST(ready_at IS NOT NULL AS INT64) ready,CAST(body_at IS NOT NULL AS INT64) body_ready,CAST(activity_at IS NOT NULL AS INT64) activity_ready,
 CAST(generated_at IS NOT NULL AS INT64) generated,CAST(viewed_at IS NOT NULL AS INT64) viewed,CAST(paid_at IS NOT NULL AS INT64) paid,
 CAST(has_paywall AS INT64) paywall,CAST(has_checkout AS INT64) checkout,CAST(has_cancel AS INT64) cancel_scheduled,CAST(has_end AS INT64) ended,
 CASE WHEN ordered_paid_at IS NOT NULL THEN 8 WHEN ordered_viewed_at IS NOT NULL THEN 7 WHEN ordered_generated_at IS NOT NULL THEN 6
  WHEN ordered_ready_at IS NOT NULL THEN 5 WHEN ordered_record_at IS NOT NULL THEN 4 WHEN ai_at IS NOT NULL THEN 3 WHEN trial.trial_at IS NOT NULL THEN 2 ELSE 1 END funnel_depth,
 FORMAT_DATE('%Y-%m',DATE(trial.trial_at,'Asia/Tokyo')) cohort_month,CAST(registered_at AS STRING) registered_at,
 CAST(trial.trial_at AS STRING) trial_started_at,CAST(viewed_at AS STRING) first_report_viewed_at,
 IF(complete_through>=TIMESTAMP(DATE_ADD(DATE(registered_at,'Asia/Tokyo'),INTERVAL 2 DAY),'Asia/Tokyo'),1,0) d1_eligible,
 CAST(EXISTS(SELECT 1 FROM active_days a WHERE a.user_id=r.user_id AND a.active_day=DATE_ADD(DATE(r.registered_at,'Asia/Tokyo'),INTERVAL 1 DAY)) AS INT64) d1_retained,
 IF(complete_through>=TIMESTAMP(DATE_ADD(DATE(registered_at,'Asia/Tokyo'),INTERVAL 8 DAY),'Asia/Tokyo'),1,0) d7_eligible,
 CAST(EXISTS(SELECT 1 FROM active_days a WHERE a.user_id=r.user_id AND a.active_day=DATE_ADD(DATE(r.registered_at,'Asia/Tokyo'),INTERVAL 7 DAY)) AS INT64) d7_retained,
 IF(complete_through>=TIMESTAMP(DATE_ADD(DATE(registered_at,'Asia/Tokyo'),INTERVAL 15 DAY),'Asia/Tokyo'),1,0) d14_eligible,
 CAST(EXISTS(SELECT 1 FROM active_days a WHERE a.user_id=r.user_id AND a.active_day=DATE_ADD(DATE(r.registered_at,'Asia/Tokyo'),INTERVAL 14 DAY)) AS INT64) d14_retained,
 IF(complete_through>=TIMESTAMP(DATE_ADD(DATE(registered_at,'Asia/Tokyo'),INTERVAL 22 DAY),'Asia/Tokyo'),1,0) d21_eligible,
 CAST(EXISTS(SELECT 1 FROM active_days a WHERE a.user_id=r.user_id AND a.active_day=DATE_ADD(DATE(r.registered_at,'Asia/Tokyo'),INTERVAL 21 DAY)) AS INT64) d21_retained,
 IF(trial.trial_at IS NOT NULL AND @server_complete_through>=conversion_end,1,0) conversion_eligible,
 IF(paid_at<=conversion_end,1,0) converted,
 IF(trial.trial_at IS NOT NULL AND complete_through>=GREATEST(conversion_end,TIMESTAMP(DATE_ADD(followup_day,INTERVAL 1 DAY),'Asia/Tokyo')),1,0) landmark_eligible,
 IF(viewed_at<=landmark_at,'viewed_by_day14','not_viewed_by_day14') landmark_segment,
 CAST(EXISTS(SELECT 1 FROM active_days a WHERE a.user_id=r.user_id AND a.active_day=r.followup_day) AS INT64) landmark_retained,
 IF(paid_at IS NULL OR paid_at>landmark_at,1,0) landmark_conversion_eligible,
 IF(paid_at>landmark_at AND paid_at<=conversion_end,1,0) landmark_converted
FROM scored r;

-- Append tools/analytics/dashboard_queries.sql here for aggregate-only outputs.
-- GA4 daily exports are mutable for late arrivals and do not contain a trustworthy
-- BigQuery ingestion timestamp per event. as_of bounds event time; historical
-- exact replay additionally requires a frozen export/source snapshot + hash.
-- Source-completeness watermarks are operator-confirmed inputs, never MAX(event_at).
-- If export completeness is unconfirmed, pass NULL and preserve N/A denominators.
