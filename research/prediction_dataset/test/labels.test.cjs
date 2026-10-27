"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {load, point, observation, amendment, at, T0, T1, LATER, BEFORE, DURING, SUBJECT} = require("./helpers.cjs");
const select = (events, l = T1, p = point()) => load("labels").selectLabels(p, events, l);
const withOriginal = (id, original) => { const result = observation(id); return {...result, original: {...result.original, ...original}}; };
const hasExclusion = (labels, id, code) => assert.ok(labels.candidateExclusions.some(x => x.observationId === id && x.reasonCodes.includes(code)), `${id}: ${code}`);

test("only observations with both observation and original receipt inside (T0,T1] qualify", () => {
  const atStart = withOriginal("synthetic_at_start", {timing: at(T0)});
  const observedBefore = withOriginal("synthetic_prior_observation", {timing: at(BEFORE)});
  const receiptStart = withOriginal("synthetic_receipt_start", {acceptedAt: T0, availableAt: T0});
  const afterEnd = withOriginal("synthetic_late_original", {acceptedAt: "2030-04-02T00:00:00.000000001Z", availableAt: "2030-04-02T00:00:00.000000001Z"});
  const valid = withOriginal("synthetic_end_inclusive", {acceptedAt: T1, availableAt: T1, timing: at(T1)});
  const r = select([atStart, observedBefore, receiptStart, afterEnd, valid], LATER);
  assert.equal(r.selectedObservationId, valid.id);
  assert.equal(r.initial, "normal");
  hasExclusion(r, atStart.id, "observation_time_not_proven_in_window");
  hasExclusion(r, observedBefore.id, "observation_time_not_proven_in_window");
  hasExclusion(r, receiptStart.id, "original_receipt_outside_window");
  hasExclusion(r, afterEnd.id, "original_receipt_outside_window");
  const adjacent = select([valid], LATER, point({referenceDateKey: "2030-04-02"}));
  assert.equal(adjacent.status, "missing");
});
test("a nanosecond after T0 qualifies without millisecond truncation", () => {
  const valid = withOriginal("synthetic_nanosecond", {acceptedAt: "2030-04-01T00:00:00.000000001Z", availableAt: "2030-04-01T00:00:00.000000001Z", timing: at("2030-04-01T00:00:00.000000001Z")});
  assert.equal(select([valid]).selectedObservationId, valid.id);
});
test("first original receipt wins, not earliest observation or most concerning value", () => {
  const first = withOriginal("synthetic_first_receipt", {condition: "normal", acceptedAt: "2030-04-01T03:00:00Z", availableAt: "2030-04-01T03:00:00Z", timing: at("2030-04-01T02:30:00Z")});
  const earlierObserved = withOriginal("synthetic_earlier_observed", {condition: "veryConcerned", acceptedAt: "2030-04-01T04:00:00Z", availableAt: "2030-04-01T04:00:00Z", timing: at("2030-04-01T01:00:00Z")});
  const r = select([earlierObserved, first]);
  assert.equal(r.selectedObservationId, first.id);
  assert.equal(r.initial, "normal");
});
test("shared trustworthy sequence breaks same-receipt ties", () => {
  const a = observation("synthetic_tie_z", {originalOrder: {scope: "synthetic_server_stream", sequence: 7}});
  const b = observation("synthetic_tie_a", {originalOrder: {scope: "synthetic_server_stream", sequence: 8}});
  const r = select([b, a]);
  assert.equal(r.selectedObservationId, a.id);
  assert.equal(r.ordering, "trusted_sequence");
});
test("otherwise stable ID makes ties reproducible without claiming observed chronology", () => {
  const a = observation("synthetic_tie_a");
  const z = observation("synthetic_tie_z");
  const r = select([z, a]);
  assert.equal(r.selectedObservationId, a.id);
  assert.equal(r.ordering, "stable_id_fallback");
  assert.ok(r.reasonCodes.includes("stable_id_fallback_not_observed_order"));
  assert.deepEqual(select([a, z]), r);
});
test("different sequence scopes do not establish a cross-stream server order", () => {
  const z = observation("synthetic_tie_z", {originalOrder: {scope: "synthetic_stream_left", sequence: 1}});
  const a = observation("synthetic_tie_a", {originalOrder: {scope: "synthetic_stream_right", sequence: 99}});
  const r = select([z, a]);
  assert.equal(r.selectedObservationId, a.id);
  assert.equal(r.ordering, "stable_id_fallback");
});
test("initial and corrected labels share one selected observation", () => {
  const e = observation("synthetic_corrected", {amendments: [amendment()]});
  const later = withOriginal("synthetic_later", {acceptedAt: "2030-04-01T06:00:00Z", availableAt: "2030-04-01T06:00:00Z", condition: "veryConcerned"});
  const r = select([later, e]);
  assert.equal(r.selectedObservationId, e.id);
  assert.equal(r.initial, "normal");
  assert.equal(r.corrected, "slightlyConcerned");
  assert.equal(r.hasCorrection, true);
  assert.equal(r.provenance.originalRevisionId, e.original.id);
  assert.equal(r.provenance.originalRevision, 1);
  assert.equal(r.provenance.originalAcceptedAt, DURING);
  assert.equal(r.provenance.originalAvailableAt, DURING);
  assert.deepEqual(r.provenance.originalTiming, e.original.timing);
  assert.deepEqual(r.provenance.appliedAmendments, [{id: "synthetic_revision_2", revision: 2, kind: "correction", acceptedAt: "2030-04-01T05:00:00.000000000Z", availableAt: "2030-04-01T05:00:00.000000000Z"}]);
});
test("L inclusive correction applies; L+1ns correction is not mixed in", () => {
  const byL = amendment({acceptedAt: T1, availableAt: T1});
  const afterL = amendment({id: "synthetic_revision_3", revision: 3, acceptedAt: "2030-04-02T00:00:00.000000001Z", availableAt: "2030-04-02T00:00:00.000000001Z", condition: "veryConcerned"});
  const e = observation("synthetic_finalize", {amendments: [afterL, byL]});
  const r = select([e]);
  assert.equal(r.initial, "normal");
  assert.equal(r.corrected, "slightlyConcerned");
  assert.deepEqual(r.provenance.appliedAmendments.map(x => x.id), [byL.id]);
  assert.equal(select([e], LATER).corrected, "veryConcerned");
});
test("accepted-but-unavailable correction is excluded at L", () => {
  const e = observation("synthetic_delayed_correction", {amendments: [amendment({acceptedAt: "2030-04-01T05:00:00Z", availableAt: "2030-04-02T01:00:00Z"})]});
  const r = select([e]);
  assert.equal(r.corrected, "normal");
  assert.equal(r.hasCorrection, false);
});
test("cancellation by L yields missing labels and never substitutes another answer", () => {
  const chosen = observation("synthetic_cancelled", {amendments: [amendment({kind: "cancel", condition: undefined})]});
  const next = withOriginal("synthetic_next_answer", {acceptedAt: "2030-04-01T06:00:00Z", availableAt: "2030-04-01T06:00:00Z", condition: "veryConcerned"});
  const r = select([next, chosen]);
  assert.equal(r.selectedObservationId, chosen.id);
  assert.equal(r.cancelled, true);
  assert.equal(r.initial, null);
  assert.equal(r.corrected, null);
  assert.ok(r.reasonCodes.includes("cancelled_by_finalization"));
});
test("cancellation after L does not alter the frozen labels", () => {
  const chosen = observation("synthetic_future_cancel", {amendments: [amendment({kind: "cancel", acceptedAt: LATER, availableAt: LATER, condition: undefined})]});
  const r = select([chosen]);
  assert.equal(r.initial, "normal");
  assert.equal(r.corrected, "normal");
  assert.equal(r.cancelled, false);
});
test("correction invalidating timing makes selected row ineligible", () => {
  const e = observation("synthetic_timing_correction", {amendments: [amendment({timing: at(BEFORE)})]});
  const r = select([e]);
  assert.equal(r.selectedObservationId, e.id);
  assert.equal(r.status, "ineligible");
  assert.ok(r.reasonCodes.includes("corrected_timing_ineligible"));
});
test("correction invalidating subject cannot be used just because owner matches", () => {
  const e = observation("synthetic_subject_correction", {amendments: [amendment({subjectId: "synthetic_other_subject"})]});
  const r = select([e]);
  assert.equal(r.status, "ineligible");
  assert.ok(r.reasonCodes.includes("corrected_subject_ineligible"));
});
test("date-only, unknown timing, unknown identity and non-explicit answers are excluded", () => {
  const unknown = observation("synthetic_unknown_subject", {subjectId: null});
  const other = observation("synthetic_other_subject", {subjectId: "synthetic_subject_other"});
  const dateOnly = withOriginal("synthetic_date_only", {timing: {precision: "date_only", dateKey: "2030-04-01", timeZone: "Asia/Tokyo"}});
  const timingUnknown = withOriginal("synthetic_timing_unknown", {timing: {precision: "unknown"}});
  const automatic = withOriginal("synthetic_automatic", {explicit: false});
  const r = select([unknown, other, dateOnly, timingUnknown, automatic]);
  assert.equal(r.selectedObservationId, null);
  assert.equal(r.initial, null);
  hasExclusion(r, unknown.id, "subject_unconfirmed");
  hasExclusion(r, other.id, "subject_mismatch");
  hasExclusion(r, dateOnly.id, "observation_time_not_proven_in_window");
  hasExclusion(r, timingUnknown.id, "observation_time_not_proven_in_window");
  hasExclusion(r, automatic.id, "not_explicit");
});
test("invalid initial value is not rescued by later correction", () => {
  const e = withOriginal("synthetic_invalid_initial", {condition: "ill"});
  e.amendments = [amendment({condition: "normal"})];
  const r = select([e]);
  assert.equal(r.selectedObservationId, null);
  assert.equal(r.initial, null);
  hasExclusion(r, e.id, "invalid_initial_condition");
});
test("conflicting same-revision content cannot silently win by input order", () => {
  const first = amendment();
  const second = amendment({condition: "veryConcerned"});
  const e = observation("synthetic_revision_conflict", {amendments: [first, second]});
  const r = select([e]);
  assert.equal(r.status, "ineligible");
  assert.ok(r.reasonCodes.includes("conflicting_revision"));
  assert.deepEqual(select([{...e, amendments: [second, first]}]), r);
});
test("original revision must be a positive safe integer", () => {
  for (const revision of [0, -1, 1.5, Number.MAX_SAFE_INTEGER + 1]) {
    const e = withOriginal("synthetic_bad_original_revision", {revision});
    const r = select([e]);
    assert.equal(r.selectedObservationId, null);
    hasExclusion(r, e.id, "invalid_original_revision");
  }
});
test("fractional amendment revisions cannot establish valid correction order", () => {
  const e = observation("synthetic_fractional_revision", {amendments: [amendment({revision: 2.5})]});
  const r = select([e]);
  assert.equal(r.status, "ineligible");
  assert.ok(r.reasonCodes.includes("conflicting_revision"));
});
test("unsafe receipt sequence uses stable-ID fallback rather than trusted order", () => {
  for (const sequence of [-1, 1.5, Number.MAX_SAFE_INTEGER + 1]) {
    const z = observation("synthetic_invalid_sequence_z", {originalOrder: {scope: "synthetic_receipt_stream", sequence}});
    const a = observation("synthetic_invalid_sequence_a", {originalOrder: {scope: "synthetic_receipt_stream", sequence: 100}});
    const r = select([z, a]);
    assert.equal(r.selectedObservationId, a.id);
    assert.equal(r.ordering, "stable_id_fallback");
    assert.ok(r.reasonCodes.includes("stable_id_fallback_not_observed_order"));
  }
});
test("revision receipt cannot precede original receipt or run backward", () => {
  const beforeOriginal = observation("synthetic_reversed_receipt", {amendments: [amendment({acceptedAt: "2030-04-01T03:00:00Z", availableAt: "2030-04-01T03:00:00Z"})]});
  const reverse = observation("synthetic_reversed_revisions", {amendments: [amendment(), amendment({id: "synthetic_revision_3", revision: 3, acceptedAt: "2030-04-01T04:30:00Z", availableAt: "2030-04-01T05:30:00Z"})]});
  for (const e of [beforeOriginal, reverse]) {
    const r = select([e]);
    assert.equal(r.status, "ineligible");
    assert.ok(r.reasonCodes.includes("conflicting_revision"));
  }
});
test("revision cannot be available before its server receipt", () => {
  const e = observation("synthetic_bad_available_clock", {amendments: [amendment({acceptedAt: "2030-04-01T06:00:00Z", availableAt: "2030-04-01T05:00:00Z"})]});
  const r = select([e]);
  assert.equal(r.status, "ineligible");
  assert.ok(r.reasonCodes.includes("conflicting_revision"));
});
test("standalone label selection requires explicit finalization clock", () => {
  assert.throws(() => load("labels").selectLabels(point(), [], undefined), /./);
  assert.throws(() => load("labels").selectLabels(point(), [], T0), /L_before_T1/);
});
test("incomplete materialization uses a separate cutoff without changing policy L", () => {
  const pendingAmendment = amendment({acceptedAt: "2030-04-01T06:00:00Z", availableAt: "2030-04-01T06:00:00Z"});
  const e = observation("synthetic_data_cutoff", {amendments: [pendingAmendment]});
  const r = load("labels").selectLabels(point(), [e], T1, "2030-04-01T05:00:00Z");
  assert.equal(r.initial, "normal");
  assert.equal(r.corrected, "normal");
  assert.equal(r.hasCorrection, false);
});
