"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");
const {spawnSync} = require("node:child_process");
const probe = tz => spawnSync(process.execPath, [path.join(__dirname, "offline_child.cjs"), path.join(__dirname, "offline_probe.cjs")], {
  // No inherited auth tokens, credential paths, cloud project, or DB environment.
  env: {TZ: tz, LANG: "C", PATH: path.dirname(process.execPath)}, encoding: "utf8", timeout: 15000,
});
test("imports and generation work with SDK loading and all network transports denied", () => {
  const result = probe("Pacific/Honolulu");
  assert.equal(result.status, 0, result.stderr);
  const parsed = JSON.parse(result.stdout);
  assert.match(parsed.hash, /^[a-f0-9]{64}$/);
  assert.equal(parsed.rows.length, 7);
});
test("different process-local timezones give the same semantic rows and content hash", () => {
  const utc = probe("UTC"); const tokyo = probe("Asia/Tokyo"); const hawaii = probe("Pacific/Honolulu");
  for (const result of [utc, tokyo, hawaii]) assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(utc.stdout), JSON.parse(tokyo.stdout));
  assert.deepEqual(JSON.parse(utc.stdout), JSON.parse(hawaii.stdout));
});
