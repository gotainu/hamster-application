# Synthetic prediction dataset generator

This is an offline research utility, not a production Function or a model. Its
only supported input is the checked-in, completely invented fixture. No fixture
is copied from Firestore, Library, a tester, or a production snapshot.

## Run

From the repository root, use the already installed, pinned TypeScript compiler
and Node 22 built-in test runner. No package installation or cloud credentials are
needed.

```sh
node functions/node_modules/typescript/bin/tsc -p research/prediction_dataset/tsconfig.json
node research/prediction_dataset/runner.cjs
node --test research/prediction_dataset/test/*.test.cjs
```

The runner reads only `fixtures/representative.json` and
`fixtures/policy.json`. It deliberately has no account, endpoint, credential,
Firestore, SwitchBot, or arbitrary input-path arguments. Generated typed JSON
and a manifest go under `research/prediction_dataset/output/`; this local output
must not be treated as research-approved or Prediction Ready data.

The checked-in [example dataset](examples/dataset.json) and [manifest](examples/manifest.json)
retain the original v1.6 code identity. The shared canonical entry point added
for the [materializer](../prediction_materializer/README.md) preserves their row
semantics; a new code identity intentionally gives a new dataset/content hash.
Regenerate with the runner to verify current-code output;
execution audits are separate and are not committed as dataset content.

## Boundaries

- `src/` contains pure transformations and validation. It neither initializes
  Firebase nor performs file, network, database, clock, or credential access.
- `tools/load-typescript.cjs` uses the project's installed TypeScript compiler.
  Its source dependency allowlist admits only this research directory, the
  named existing pure date/Catalog helpers, and Node's SHA-256 implementation.
  Production entrypoints and SDK modules are rejected.
- `runner.cjs` is the thin file/clock boundary. It records an actual execution
  timestamp separately from deterministic dataset content, and hashes the
  loaded source dependencies as well as the fixture and policy files. Node and
  TypeScript versions are included in the code identity.
- The fixture has `syntheticOnly: true` (the manifest uses `synthetic_only`), `synthetic_` IDs, and invented 2030
  timestamps. The runner rejects a missing synthetic declaration or unknown
  command-line arguments. This is a guard against accidental use, not consent
  or permission to load real records.
- JSON plus manifest are authoritative. No CSV conversion, imputation,
  standardization, feature selection training, prediction, probability,
  extraction, shadow operation, or model training is performed.

## Local policy under test

The primary target is an explicitly reported observation answer
`normal` / `slightlyConcerned` / `veryConcerned`, not a disease diagnosis.
Prediction windows are `(09:00 JST, next 09:00 JST]`: the start is excluded and
the end included. Features are limited to information accepted and available by
T0. Labels require both original receipt and observation time to be provably in
the window. A date-only or unknown observation time is not guessed.

The selected observation is the first eligible **original receipt**, with a
stable ID tie-break. That tie-break proves reproducibility, not actual temporal
order. Input corrections do not create another observation. Both label
policies retain the same selected observation: one uses its initial value; the
other applies corrections accepted by explicitly supplied L. Cancellation or
an eligibility-invalidating correction yields a missing/ineligible label,
without switching to a later observation or choosing the most concerned value.

L is required and must be at least T1. The separately supplied data-availability
clock controls whether a row is final or held; neither comes from `Date.now()`
inside the pure generator. The adopted initial research policy is T0=09:00 JST,
T1=the next 09:00 JST,
`(T0,T1]`, L=T1+24h, initial answer as primary and the same observation's
corrected answer for comparison/sensitivity analysis. Cancellation by L means
missing, with no automatic switch to a later observation. The 24h value is the
current initial-study operating value; future real-data evaluation may revise it
under a new policy version. L=T1 remains a boundary-test setting; the configurable
API and fixtures are unchanged. Adoption does not authorize real-data use.
Extending L never
extends the feature cutoff or admits an original answer first accepted after
T1.

Rows start from the fixture's subject × prediction-time schedule, including
rows with no answer. Audit rows retain rejection, hold and missing reasons.
Candidate rows are a separately identified subset. Feature-level exclusion
(e.g. sensor mapping unknown) does not discard other valid features or silently
become a 0, non-action, or normal answer. Each row has explicit `featureEligibility`: usable
values are eligible; partial values require `allowPartialFeatureIds` permission.
Other evidence remains in the audit without becoming a candidate model input.

## Reproducibility and manifest

The manifest includes schema/policy/Catalog versions, exact windows and L,
fixture identity and hash, code/dependency hashes, state/reason counts and
`synthetic_only`. The canonical content hash excludes execution metadata such
as the runner timestamp. Input arrays are normalized by stable identifiers and
explicit timestamps, so changing input order does not change semantic content.
Neither generator nor runner mutates the input fixture. Content artifacts are
created once under a content-hash directory; subsequent identical runs reuse
them and append a separate execution-audit JSON rather than overwrite them.

See [the dataset contract](../../docs/prediction_dataset_contract_v1.md) for
the adopted window/L/label policy and the still unresolved research choices:
consent, withdrawal, retention/deletion, model choice,
Prediction Ready, and any future shadow/display experiment.

## Pure API and representative fixture

`generateDataset(fixture, policy, codeIdentity)` returns `auditRows`,
`candidateRows`, `labelDifferences`, and `manifest`. `selectLabels`,
`selectFeatures`, and explicit-time helpers can be tested independently.

The checked-in fixture contains seven anchors, ten observations and twenty
feature revisions, all invented. Its alpha row retains weight 42 g, an actual
activity value of 0 m, explicit care non-action, and a single PARTIAL sensor
point (22.7 C / 48 %RH). It selects the same observation for initial `normal`
and corrected `slightlyConcerned`. Beta is cancelled without substitution;
gamma demonstrates pre-window observation and after-window receipt; delta has
only a date; eta is exactly on T1 and has an unrelated unmapped sensor point;
theta becomes identity-ineligible after a correction. An unknown-subject anchor
is retained for audit. Separate tests cover held rows before L.
