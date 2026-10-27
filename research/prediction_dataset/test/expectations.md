# Synthetic dataset expectations (defined before implementation)

All examples are fabricated and use `synthetic_` identifiers and dates in 2030.
They are not predictions, research consent, Prediction Ready, or real disease labels.

The default boundary fixture uses T0 `2030-04-01T00:00:00.000000000Z`
(09:00 JST), T1 `2030-04-02T00:00:00.000000000Z`, L=T1, and explicit
completion knowledge at/after L. The target window is `(T0, T1]`.

| Case | Expected outcome / independently chosen evidence |
|---|---|
| Observation exactly T0 | Not a candidate, even when received after T0. |
| Observation and original receipt exactly T1 | Candidate in the first window; excluded from the adjacent window that starts at T1. |
| One nanosecond after T0 | Candidate when both clocks are inside the window; precision must not be rounded to T0. |
| Observed before T0, submitted in window | Excluded as a label; receipt alone proves no post-T0 observation. |
| Observed in window, originally received after T1 | Excluded even if L allows 24 more hours. |
| Earlier receipt vs earlier observation | Earliest original receipt is selected, rather than earliest observation or highest concern. |
| Same receipt and reliable sequence | Lowest trusted receipt sequence breaks tie. |
| Same receipt without reliable sequence | Stable observation ID breaks tie; ambiguity flag says this does not establish real chronological order. |
| Initial normal then correction slightlyConcerned before L | Same chosen observation ID in both policies; original=normal, corrected=slightlyConcerned; correction recorded. |
| Correction after L | Original and corrected labels unchanged; future revision excluded from dataset. |
| Cancellation by L | Missing label with explicit cancellation reason; do not substitute later valid observation. |
| Cancellation after L | No effect on frozen selection/labels. |
| Correction changes observation time/subject eligibility | Do not blindly adopt label; return explicit reason and mark row ineligible. |
| Date-only / unknown observation time | Exclude if inclusion in window cannot be proved; routine recording validity remains separate. |
| Missing subject / a different subject | Never infer identity from account; no label/feature mixing. |
| No eligible observations and completion>=L | Label missing, not normal. |
| Completion<L | Pending, not label missing; model sample count zero. |
| L<T1 | Reject invalid configuration before any rows are produced. |
| Corrected weight after T0 | Use earlier accepted revision known at T0; never latest current revision. |
| Observation/receipt/API acceptance after T0 as feature | Exclude; label values must not be recycled into features. |
| Actual activity zero | Preserve numeric zero with measured quality; absence stays null/unknown. |
| PARTIAL sensor with one observed valid reading | Keep as observed point evidence only; no daily mean, full counts/ratio or Prediction Ready. Other valid features may remain usable. |
| Sensor device association unknown | Sensor feature not eligible; valid weight/care evidence still survives. |
| Future correction / late sensor reading | No effect before T0 even if retrospectively associated with an older date. |
| Root grid has day without answer | Produce an audit row for that day, not only answered days. |
| Input permutations | Same semantic rows, selected evidence, content hash and state/reason counts. |
| Caller input frozen/deep cloned | Input remains unchanged after generator runs. |
| Audit run metadata differs | Reproducibility content hash remains the same. |
| L / policy / fixture content differs | Manifest identity changes, without overwriting older generated output. |
| Isolated child execution | Succeeds with no Firebase/DB/API/auth setup, network disabled, unset cloud credentials and non-JST process TZ. |

Tests assert chosen IDs, labels, evidence revision IDs, state, and reason codes,
not merely that calls finish successfully. L=T1 or L=T1+24h are test inputs only;
they do not establish an approved research correction grace period.
