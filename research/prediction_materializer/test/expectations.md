# Synthetic materializer expectations — defined before implementation

All cases below are invented. IDs use `synthetic_`; event dates are in 2030.
No production snapshot, tester UID, Library record, credential, or account data
is a fixture input. This utility does not train a model or assess Prediction Ready.

The baseline local policy uses `(T0, T1]`, 09:00 JST through next 09:00 JST.
L and data completion are explicit fixture configuration. Dataset generation
must retain rows for the subject × prediction-time schedule, including rows
that cannot become learning candidates.

| Source / case | Independent expected result |
|---|---|
| Multiple subjects and anchors | At least five audit rows, keyed by subject and configured T0, including unlabelled rows. No same-owner identity inference. |
| Initial normal, then corrected slightlyConcerned by L | Select the same original observation for both label policies; initial normal and corrected slightlyConcerned. One observation, not two training rows. |
| Selected observation cancelled by L, later response present | Missing label with cancellation reason. Do not silently substitute the later response. |
| No eligible label | Retain audit row as label_missing; do not fill normal. |
| Data not complete through L | Hold rather than label_missing. |
| Measurement accepted after feature cutoff | Exclude from T0 features even if its measurement date is earlier. |
| Future correction to an earlier measurement | Before correction receipt use earlier revision; do not leak future revision existence into a feature or overwrite the historical value. |
| History introduced after T0 | Do not reconstruct unknown earlier facts from latest current value. Return explicit unknown/exclusion. |
| Real activity 0 | Preserve 0 m as an actual measurement, distinct from no record. |
| Explicit non-action / zero walk | Preserve false / 0 only with explicit source and completed period; never infer a whole-day non-action from a morning partial statement. |
| Partial sensor with one observed valid reading | May retain a point with PARTIAL/observed evidence if policy allows; whole-period counts/ratio remain null. No average/coverage claim. |
| Unknown device or subject mapping | Sensor feature excluded; other valid subject features survive. |
| Environment revisions before and after change | Apply only environment state effective and known at T0. Do not carry the later setting back into earlier prediction inputs. |
| Date-only or unknown observation time | Not a label candidate when window inclusion cannot be proved. This does not invalidate routine care recording. |
| Boundary observation | Exact T0 excluded; exact T1 included only in preceding window. |
| Input order permutations | Identical canonical rows, state/reason counts, and reproducible content hash. |
| Separate audit execution times | Content hash unchanged, audit metadata may differ. |
| JSONL / CSV | Same row IDs, subject/T0, label state and scalar values. Missing is not encoded as a numeric zero or normal. JSON remains the typed authority. |
| CSV escaping | Quoted text/comma/newline/Unicode round-trip without row/column corruption. |
| Manifest | Identifies synthetic input/config/code/policy/source hashes, versions, exact T0/T1/L, row and state counts. No secret or production identifier. |
| Offline child process | No SDK initialization, database, network transport, credentials, or non-JST machine timezone assumptions. |
| Input immutability | Original source fixture bytes and configuration bytes are unchanged after materialization/output. |

Tests assert selected observation IDs, exact feature values and root revisions,
policy/version metadata, per-row status/reason codes, and output parity. Merely
finishing without an exception is not a success criterion.
