-- Release-only additive migration. Not executed by local tests or this task.
-- Must precede the updated ingest writer (ignoreUnknownValues=false).
ALTER TABLE `hamster-breeding-app.hamcare_trial_analytics.server_events_raw`
 ADD COLUMN IF NOT EXISTS environment STRING;
ALTER TABLE `hamster-breeding-app.hamcare_trial_analytics.server_events_raw`
 ADD COLUMN IF NOT EXISTS account_classification STRING;
ALTER TABLE `hamster-breeding-app.hamcare_trial_analytics.server_events_raw`
 ADD COLUMN IF NOT EXISTS billing_livemode BOOL;
-- Historical rows remain NULL/unknown. No backfill, no inferred general users.
-- Existing test-only preview views remain separate until a deliberate release.
