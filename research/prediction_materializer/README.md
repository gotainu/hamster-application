# Prediction dataset table materializer v1

Local, offline preparation of **synthetic** learning-table candidates. This utility
never trains a model, creates a prediction, authorizes research, reads a cloud DB,
or changes the application/server. Observation answers are not disease labels.

## Run

From the repository root with the existing Node 22 and pinned TypeScript:

```sh
node functions/node_modules/typescript/bin/tsc -p research/prediction_materializer/tsconfig.json
node research/prediction_materializer/runner.cjs \
  --source research/prediction_materializer/fixtures/source.json \
  --config research/prediction_materializer/fixtures/config.json \
  --output research/prediction_materializer/output \
  --run-id synthetic_example_01
node --test research/prediction_dataset/test/*.test.cjs research/prediction_materializer/test/*.test.cjs
```

The four CLI arguments are mandatory local paths/run identity. A repeated run ID
fails without overwriting anything; choose a new ID for another execution.
No credentials, Firebase emulator, API, database, model, or new dependency is needed.
The CLI accepts **synthetic source classification only**. `test`/`production`
are representable provenance classifications, but execution is deliberately
blocked. No test-account/live-Firestore adapter is included in v1.

## Responsibility boundaries

1. `sourceTypes.ts`: detached JSON source snapshot and read-only
   `SnapshotRepository`; `JsonSnapshotRepository` returns a copy of local input.
2. `adapters.ts`: maps saved-history fields and existing point-in-time repository
   responses to canonical `ObservationEvent`/`FeatureRevision`. No statistics or
   label/row selection lives here.
3. `materialize.ts`: validates the explicit source/config, normalizes each point,
   calls **the existing generator**, and arranges outputs/audit. Snapshot
   completeness limits the requested `dataAvailableThrough`; it never claims
   knowledge beyond the snapshot watermark.
4. `prediction_dataset/src/generate.ts`: shared `generateRows` is the sole row
   decision path for the old synthetic wrapper and new `generateCanonicalDataset`.
   Existing label/feature selectors remain the sole calculation/selection path.
5. `table.ts`: serializes generator results, aliases identifiers, and exposes
   only feature-policy-eligible values as scalar model candidates.
6. `writer.cjs`/`runner.cjs`: file I/O and execution timestamps. The existing
   allowlisted TypeScript loader admits only research source and named pure
   date/Catalog helpers. SDKs and production entrypoints are rejected.

## Source contract

See `src/sourceTypes.ts` and `fixtures/source.json`. All records are invented.
The envelope has `sourceId`, `ownerId`, explicit `availableAt`, and narrowed
saved data. Accepted timestamps support offset ISO strings or JSON
`{seconds,nanoseconds}`; no timestamp precision is inferred from save time.

| Adapter | Existing contract reused | Rule |
|---|---|---|
| subject | server-issued subject registration | identity must have been confirmed by T0; UID alone never establishes a subject |
| profile | `readMainPetProfileHistoryAt` resolved result + evidence acceptance metadata | evaluation day, exact knowledge cutoff, and every referenced revision are checked; no current-profile backfill |
| observation | append-only observation revisions | group original/corrections/cancel by event; only `explicit_submission` is explicit; auto item-normal is not an answer |
| weight/distance | logical measurement revisions | retain subject/revision/acceptance/timing and saved g/m; no wheel reconversion, day-index-as-measurement or zero fill |
| care | immutable daily-care revisions | cleaning/bedding/time stay distinct; no subject inferred from the account; an independently confirmed temporal binding is required |
| environment | existing `readEnvironmentAt` resolved response + evidence metadata | exact observedAt/T0 and cutoff, evidence revisions and temporal binding are checked; no second effective-history resolver |
| sensor | immutable quality snapshot / terminal acquisition evidence | partial observed counts and unknown totals/device/freshness remain distinct; response time is not a device measurement time |

Profile/environment inputs are **existing repository read responses**, not a new
raw-history replay algorithm. Their `availableAt` describes source knowledge,
not the later JSON export time. Resolved state timestamps mean state-as-of-T0,
not an independent observation. Current-only/legacy-unrecoverable periods remain
`not_reconstructable`; no raw current document fallback is supported.

`sourceCompleteness` declares the read completeness of each source, independently
of a sensor snapshot's internal PARTIAL quality. A producer must have completed
the relevant history/revision scan, not merely supplied one document. Missing,
partial or unreconstructable feature sources are passed as unknown quality to
the generator. Observations need complete original/correction/cancel history:
partial/unknown is held, unreconstructable is ineligible, and labels/selected ID
are cleared by the **shared generator**. A complete scan with truly no answers
is label-missing. Future real adapters must establish bounded read coverage and
watermarks before making these declarations; v1 only tests invented snapshots.

## Config and table

`fixtures/config.json` explicitly supplies each point's owner/subject,
`T0`, `T1`, `L`, completeness time and the shared feature/label policy versions.
The materializer keeps boundaries explicit. The adopted initial research policy
is T0=09:00 JST, T1=the next 09:00 JST, `(T0,T1]`, and L=T1+24 hours.
The primary label is the selected observation's initial answer; the corrected
answer is for comparison/sensitivity analysis. Cancellation by L makes the label
missing, without automatic substitution of a later observation. The 24-hour
grace is the current initial-study operating value and may change under a new
policy version after real-data evaluation. The generic configurable API and
existing fixtures are unchanged; policy adoption does not authorize real-data use.

One row is a requested subject × prediction instant. Repeated points/row IDs
fail rather than duplicate. JSONL contains all audit dispositions; only
`candidate_rows.jsonl` contains technical candidates.

- Identity/time: `row_id`, pseudonymous `subject_id`/`owner_group_id`,
  `prediction_at`, window boundaries and `label_finalized_at`.
- Compact scalar feature columns: weight g, activity m, prior condition,
  cleaning, bedding, walk minutes, wheel cm, species/birthday, temperature,
  humidity and sensor-period count. These are the existing generator's minimum
  feature set, not new aggregates. Other environment attributes are not silently
  promoted to new features.
- One `feature_metadata` column retains per-feature eligibility, missing status,
  unit, quality, acceptance age, revision/time provenance, declaration scope,
  sensor quality and reasons. Acceptance age is elapsed server-receipt age in
  seconds, **not measurement freshness**; exact original timestamps are retained.
  Metadata/adapter reasons are audit evidence, not automatically model inputs.
- Labels: initial/corrected values from the same selected observation, status,
  selected ID and corrected/cancelled flags. Row disposition, reasons and
  schema/policy versions remain explicit. No-answer/invalid/cancelled is not normal.

Null is formal. Actual 0 and explicit nonperformance false remain 0/false.
Unknown subject/device, unconfirmed answers, incomplete scans and unrecoverable
history do not become values. Optional sensor absence does not erase a valid
weight. No imputation, normalization fit or learned feature selection is done.

## Files and reproducibility

Each exclusive run directory contains:

- `rows.jsonl` and `rows.csv`: equivalent full table, including held/excluded rows.
- `candidate_rows.jsonl`, `excluded_rows.jsonl`: disjoint candidate/noncandidate views.
- `config.json`: the normalized **effective** config, including watermark limits.
- `manifest.json`: schema/policy/Catalog versions, all windows, source/config and
  canonical-input hashes, code identity, classifications/counts/reasons, and
  deterministic output artifact hashes. `input_config_hash` identifies the
  requested config; `effective_config_hash` identifies the copied effective one.
- `audit.json`: source/label evidence and reasons plus separate run ID/time.
- `execution.json`: exact source-file/config-file digest and loaded code/Node/TS
  identity. No credentials or raw source snapshot are copied into output.

CSV uses `typed_json_cells_v1`: each value is JSON, then RFC4180 quoted. Thus
`null`, 0, false, empty string and the literal string "null" stay different;
objects remain JSON in a compact cell. JSONL and manifest are authoritative.
Parquet is not added, avoiding a new dependency/runtime just for this task.

Source/config normalization ignores input-list ordering. Content hashing includes
semantic rows, source audit, effective config, source snapshot and code identity;
execution time/run ID/paths are excluded. Reordered source/config produce the
same hash. Changing L, source/config contents or code version produces a distinct
dataset identity. Existing tables are never overwritten. A failed write can leave
an incomplete reserved run directory; only a completed manifest marks success.

Table/source IDs are deterministic local aliases; this is pseudonymization,
not anonymization or permission for research. The copied config contains only
invented IDs in this synthetic-only implementation. Research identification and
real-output privacy/consent operations require separate approval before enabling
any real-data adapter.

## Completion boundary

The launch-preparation data-plumbing milestone is complete after local tests and
synthetic E2E, **not research-ready or Prediction Ready**. The window/L/primary
label policy above is adopted; consent/withdrawal/retention/deletion, actual
source coverage/identity,
authorized extraction, models, shadow operation and RCT remain undecided/not run.
See [the dataset contract](../../docs/prediction_dataset_contract_v1.md).
