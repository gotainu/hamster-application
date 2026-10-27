'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const fixturePath = path.join(root, 'fixtures/source.json');
const configPath = path.join(root, 'fixtures/config.json');
const source = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const canonical = value => value === null || typeof value !== 'object' ? JSON.stringify(value) :
  Array.isArray(value) ? '[' + value.map(canonical).join(',') + ']' :
    '{' + Object.keys(value).sort().map(k => JSON.stringify(k) + ':' + canonical(value[k])).join(',') + '}';
const alias = (kind, value) => kind + '_' + sha(canonical({namespace:'hamcare_local_materializer_v1',kind,value}));
function findFiles(directory, filename) {
  return fs.readdirSync(directory, {withFileTypes:true}).flatMap(entry => entry.isDirectory() ? findFiles(path.join(directory, entry.name), filename) : entry.name === filename ? [path.join(directory, entry.name)] : []);
}
function jsonl(filename) {return fs.readFileSync(filename, 'utf8').trim().split('\n').filter(Boolean).map(line => JSON.parse(line));}
function parseCsv(text) {
  const records = []; let record = [], cell = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') {cell += '"'; i++;}
      else if (c === '"') quoted = false;
      else cell += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') {record.push(cell); cell = '';}
    else if (c === '\n') {record.push(cell.endsWith('\r') ? cell.slice(0, -1) : cell); records.push(record); record = []; cell = '';}
    else cell += c;
  }
  assert.equal(quoted, false, 'CSV must close quoted fields');
  if (cell.length || record.length) {record.push(cell); records.push(record);}
  const [header, ...data] = records;
  return data.map(values => {
    assert.equal(values.length, header.length, 'CSV columns must remain aligned');
    return Object.fromEntries(header.map((key, i) => [key, JSON.parse(values[i])]));
  });
}
function runSource(input = source, settings = config, options = {}) {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'hamcare-materializer-e2e-'));
  const sourceFile = path.join(temporary, 'synthetic_source.json');
  const configFile = path.join(temporary, 'synthetic_config.json');
  const output = path.join(temporary, 'output');
  fs.writeFileSync(sourceFile, JSON.stringify(input));
  fs.writeFileSync(configFile, JSON.stringify(settings));
  const before = {source:sha(fs.readFileSync(sourceFile)), config:sha(fs.readFileSync(configFile))};
  const args = [];
  if (options.offline) {
    const prelude = path.join(temporary, 'offline.cjs');
    fs.writeFileSync(prelude, `
const Module=require('node:module');const original=Module._load;
Module._load=function(request,parent,isMain){if(/firebase|google-cloud|google-auth|gaxios|axios|switchbot|bigquery/i.test(request))throw Error('external_dependency_forbidden');return original.apply(this,arguments);};
const forbidden=()=>{throw Error('external_transport_forbidden');};global.fetch=forbidden;
for(const [name,methods] of [['node:http',['request','get']],['node:https',['request','get']],['node:net',['connect','createConnection']],['node:tls',['connect']],['node:dns',['lookup','resolve']]])for(const method of methods)require(name)[method]=forbidden;
`);
    args.push('--require', prelude);
  }
  args.push(path.join(root, 'runner.cjs'), '--source', sourceFile, '--config', configFile, '--output', output, '--run-id', 'synthetic_e2e_run');
  execFileSync(process.execPath, args, {encoding:'utf8', env:options.offline ? {PATH:process.env.PATH, TZ:options.tz || 'Pacific/Honolulu'} : {...process.env, TZ:options.tz || 'UTC'}});
  assert.equal(sha(fs.readFileSync(sourceFile)), before.source);
  assert.equal(sha(fs.readFileSync(configFile)), before.config);
  const manifests = findFiles(output, 'manifest.json');
  assert.equal(manifests.length, 1);
  const directory = path.dirname(manifests[0]);
  return {directory, manifest:JSON.parse(fs.readFileSync(manifests[0], 'utf8')), rows:jsonl(path.join(directory, 'rows.jsonl')),
    candidates:jsonl(path.join(directory, 'candidate_rows.jsonl')), excluded:jsonl(path.join(directory, 'excluded_rows.jsonl')),
    audit:JSON.parse(fs.readFileSync(path.join(directory, 'audit.json'), 'utf8')), csv:parseCsv(fs.readFileSync(path.join(directory, 'rows.csv'), 'utf8'))};
}
function row(result, subject, time = '2030-04-01T00:00:00.000000000Z') {
  const id = alias('row', 'synthetic_owner_main|synthetic_subject_' + subject + '|' + time);
  const found = result.rows.find(item => item.row_id === id);
  assert.ok(found, 'configured subject and T0 must produce an audit row');
  return found;
}
let baseline;
function result() {return baseline || (baseline = runSource());}

test('end-to-end source materialization retains the subject × prediction-time grid and label evidence', () => {
  const r = result();
  assert.equal(r.rows.length, 7);
  assert.equal(new Set(r.rows.map(x => x.row_id)).size, 7);
  assert.deepEqual(r.manifest.state_counts, {candidate:4, hold:1, label_missing:2, ineligible:0});
  assert.equal(r.candidates.length, 4); assert.equal(r.excluded.length, 3);
  const first = row(r, 'alpha');
  assert.equal(first.label_initial, 'normal'); assert.equal(first.label_corrected, 'slightlyConcerned');
  assert.equal(first.selected_observation_id, alias('observation', 'synthetic_observation_alpha_1'));
  assert.equal(first.was_corrected, true);
  assert.equal(row(r, 'alpha', '2030-04-02T00:00:00.000000000Z').selected_observation_id, alias('observation', 'synthetic_observation_alpha_2'));
  const cancelled = row(r, 'beta');
  assert.equal(cancelled.row_status, 'label_missing'); assert.equal(cancelled.was_cancelled, true);
  assert.equal(cancelled.label_initial, null); assert.equal(cancelled.label_corrected, null);
  assert.equal(cancelled.selected_observation_id, alias('observation', 'synthetic_observation_beta_1'));
  assert.ok(cancelled.exclusion_reason.includes('cancelled_by_finalization'));
  assert.equal(row(r, 'gamma').row_status, 'label_missing');
  assert.equal(row(r, 'gamma').label_initial, null);
  assert.ok(row(r, 'gamma').exclusion_reason.includes('observation_time_not_proven_in_window'));
  assert.equal(row(r, 'zeta').row_status, 'hold');
});

test('historical revisions and environment states are selected at their explicit feature cutoffs', () => {
  const r = result(), before = row(r, 'alpha'), after = row(r, 'alpha', '2030-04-02T00:00:00.000000000Z');
  assert.equal(before.weight_g, 42); assert.equal(after.weight_g, 44);
  assert.equal(before.feature_metadata.weight_last_g.source_revision.revision, 1);
  assert.equal(after.feature_metadata.weight_last_g.source_revision.revision, 2);
  assert.equal(before.environment_wheel_cm, 23); assert.equal(after.environment_wheel_cm, 28);
  assert.equal(before.activity_m, 0);
  assert.equal(before.feature_metadata.activity_last_m.is_missing, false);
  assert.equal(before.walk_minutes, 0); assert.equal(before.cleaning, false);
  assert.equal(before.feature_metadata.care_walk_minutes.declaration_scope, 'up_to_acceptance');
  const legacy = row(r, 'delta');
  assert.equal(legacy.weight_g, null); assert.equal(legacy.species, null);
  assert.equal(legacy.feature_metadata.weight_last_g.is_missing, true);
  assert.ok(r.audit.rows.some(item => item.source_audit.some(a => a.reasonCodes.includes('profile_history_not_reconstructable'))));
});

test('partial sensor evidence stays partial and unmapped sensor does not discard other valid features', () => {
  const r = result(), alpha = row(r, 'alpha'), epsilon = row(r, 'epsilon');
  assert.equal(alpha.temperature_c, 22.7); assert.equal(alpha.humidity_pct, 48);
  assert.equal(alpha.feature_metadata.temperature_last_received_c.quality, 'partial');
  const quality = alpha.feature_metadata.temperature_last_received_c.sensor_quality;
  assert.equal(quality.observedCount, 1); assert.equal(quality.wholeCount, null);
  assert.equal(quality.expectedCount, null); assert.equal(quality.ratio, null); assert.equal(quality.freshness, 'unknown');
  assert.equal(alpha.sensor_period_count, null);
  assert.equal(epsilon.temperature_c, null); assert.equal(epsilon.humidity_pct, null);
  assert.equal(epsilon.weight_g, 37); assert.equal(epsilon.row_status, 'candidate');
  assert.ok(epsilon.feature_metadata.temperature_last_received_c.reason_codes.includes('sensor_device_association_unknown'));
  assert.equal(alpha.research_eligibility, 'not_assessed'); assert.equal(alpha.prediction_ready, 'not_assessed');
});

test('typed JSONL and typed CSV preserve row identity, null, zero, booleans and evidence structures', () => {
  const r = result();
  assert.deepEqual(r.csv, r.rows);
  assert.equal(r.manifest.csv_encoding, 'typed_json_cells_v1');
  assert.ok(fs.readFileSync(path.join(r.directory, 'rows.csv'), 'utf8').includes('""'));
  assert.equal(JSON.parse(fs.readFileSync(path.join(r.directory, 'config.json'), 'utf8')).schemaVersion, 'canonical_dataset_config_v1');
  assert.equal(r.manifest.synthetic_only, true); assert.equal(r.manifest.source_classification, 'synthetic');
  assert.equal(r.manifest.total_row_count, 7); assert.equal(r.manifest.candidate_row_count, 4);
  assert.equal(r.manifest.catalog_versions.observation, 'observation_catalog_v1');
  assert.match(r.manifest.source_snapshot_hash, /^[a-f0-9]{64}$/); assert.match(r.manifest.input_config_hash, /^[a-f0-9]{64}$/);
  assert.match(r.manifest.content_hash, /^[a-f0-9]{64}$/);
});

test('source/config input permutations preserve canonical rows and semantic hash', () => {
  const shuffled = structuredClone(source), changed = structuredClone(config);
  shuffled.subjects.reverse(); for (const entries of Object.values(shuffled.sources)) entries.reverse();
  changed.points.reverse(); changed.featureIds.reverse(); changed.allowPartialFeatureIds.reverse();
  const other = runSource(shuffled, changed), r = result();
  assert.deepEqual(other.rows, r.rows);
  assert.equal(other.manifest.content_hash, r.manifest.content_hash);
  assert.deepEqual(other.manifest.state_counts, r.manifest.state_counts);
  assert.deepEqual(other.manifest.reason_counts, r.manifest.reason_counts);
});

test('offline, credential-free execution with another machine timezone preserves results and separates audit clock', () => {
  const other = runSource(source, config, {offline:true, tz:'America/New_York'}), r = result();
  assert.deepEqual(other.rows, r.rows);
  assert.equal(other.manifest.content_hash, r.manifest.content_hash);
  assert.ok(!Object.hasOwn(r.manifest, 'generated_at') && !Object.hasOwn(r.manifest, 'generatedAt'));
  assert.notDeepEqual(other.audit, r.audit);
  assert.equal(sha(fs.readFileSync(fixturePath)), sha(JSON.stringify(source, null, 2) + '\n'));
  assert.equal(sha(fs.readFileSync(configPath)), sha(JSON.stringify(config, null, 2) + '\n'));
});

test('CSV typed cells round-trip comma, quote, newline and Unicode without changing meaning', () => {
  const {toCsv, fromCsv} = require('../writer.cjs');
  const fabricated = {...result().rows[0], species:'架空種, "A"\n追加行'};
  const encoded = toCsv([fabricated]);
  assert.deepEqual(parseCsv(encoded), [fabricated]);
  assert.deepEqual(fromCsv(encoded), [fabricated]);
  assert.equal(parseCsv(encoded)[0].species, '架空種, "A"\n追加行');
});
