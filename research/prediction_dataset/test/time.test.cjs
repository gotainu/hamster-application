"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {load, anchor, at, T0, T1} = require("./helpers.cjs");
const {epochNanos, normalizeInstant, predictionPoint, timingInWindow} = load("time");

test("JST 09:00 windows are explicit offset, open-start and closed-end", () => {
  const first = predictionPoint(anchor());
  const next = predictionPoint(anchor({referenceDateKey: "2030-04-02"}));
  assert.equal(first.t0, T0);
  assert.equal(first.t1, T1);
  assert.equal(next.t0, T1);
  assert.equal(timingInWindow(at(T0), first.t0, first.t1), false);
  assert.equal(timingInWindow(at(T1), first.t0, first.t1), true);
  assert.equal(timingInWindow(at(T1), next.t0, next.t1), false);
});
test("nanosecond precision and explicit timezone conversion are retained", () => {
  assert.equal(epochNanos("2030-04-01T00:00:00.000000001Z") - epochNanos(T0), 1n);
  assert.equal(normalizeInstant("2030-04-01T09:00:00.123456789+09:00"), "2030-04-01T00:00:00.123456789Z");
  assert.equal(timingInWindow(at("2030-04-01T00:00:00.000000001Z"), T0, T1), true);
});
test("ambiguous dates never acquire invented midnight observation times", () => {
  assert.equal(timingInWindow({precision: "date_only", dateKey: "2030-04-01", timeZone: "Asia/Tokyo"}, T0, T1), false);
  assert.equal(timingInWindow({precision: "unknown"}, T0, T1), false);
  assert.equal(timingInWindow({precision: "interval", start: "2030-04-01T00:00:00.000000001Z", end: T1, clock: "user_reported"}, T0, T1), true);
});
test("timestamps without timezone or with invalid calendar dates are rejected", () => {
  assert.throws(() => epochNanos("2030-04-01T09:00:00"), /invalid_explicit_timestamp/);
  assert.throws(() => epochNanos("2030-02-30T00:00:00Z"), /invalid_explicit_timestamp/);
  assert.throws(() => predictionPoint(anchor({referenceDateKey: "2030-02-30"})), /invalid_reference_day/);
});
