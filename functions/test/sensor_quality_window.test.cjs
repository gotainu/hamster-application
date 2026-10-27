'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),ts=require('typescript');
const filename=process.env.SENSOR_QUALITY_SOURCE??path.resolve(__dirname,'../src/sensorQuality/quality.ts');
function loadSource(filename){const mod={exports:{}};const localRequire=id=>id.startsWith('.')?loadSource(path.resolve(path.dirname(filename),id+'.ts')):require(id);vm.runInThisContext(`(function(exports,require,module){${ts.transpileModule(fs.readFileSync(filename,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS,esModuleInterop:true}}).outputText}\n})`,{filename})(mod.exports,localRequire,mod);return mod.exports;}
const {aggregateSensorQuality,jstSensorQualityWindow}=loadSource(filename);
const window=jstSensorQualityWindow('2026-10-16'),cutoff='2026-10-16T03:20:15.594Z';
const row=(id,data)=>({id,data});
const base=(extra={})=>({...window,knowledgeCutoff:cutoff,attempts:[],readings:[],states:[],...extra});
const reading=(id,t,extra={})=>row(id,{ts:t,createdAt:t,temperature:24,humidity:50,acquisitionId:'a',acquisitionVerification:'verified',...extra});
const partial=(reasons=['readings_limit_reached'])=>({attempts:'complete',readings:'partial',states:'complete',reasons});

test('window: complete empty period is actual zero rather than an unknown total',()=>{
 const q=aggregateSensorQuality(base());
 assert.equal(q.readings.count,0);
 assert.deepEqual(q.readings.validValueCount,{temperature:0,humidity:0});
 assert.equal(q.distribution.collectionClock.count,0);
 assert.equal(q.distribution.collectionClock.maxGapSeconds,44415.594);
 assert.equal(q.evaluatedThrough,'2026-10-16T03:20:15.594000000Z');
});

test('window: partial empty scan reports unknown total and observed zero separately',()=>{
 const q=aggregateSensorQuality(base({completeness:partial()}));
 assert.equal(q.readings.count,null);
 assert.equal(q.readings.validValueCount.temperature,null);
 assert.equal(q.readings.observed.count,0);
 assert.equal(q.readings.observed.validValueCount.temperature,0);
 assert.equal(q.distribution.collectionClock.count,null);
 assert.equal(q.distribution.collectionClock.maxGapSeconds,null);
 assert.ok(q.completeness.reasons.includes('readings_limit_reached'));
 assert.equal(q.ratios.both.value,null);
});

test('window: partial scan retains known valid lower bound without claiming the entire-period time distribution',()=>{
 const q=aggregateSensorQuality(base({readings:[reading('one','2026-10-16T02:00:00Z')],completeness:partial()}));
 assert.equal(q.readings.count,null);
 assert.equal(q.readings.observed.count,1);
 assert.deepEqual(q.readings.observed.validValueCount,{temperature:1,humidity:1});
 assert.equal(q.distribution.collectionClock.maxGapSeconds,null);
 assert.equal(q.distribution.collectionClock.endGapSeconds,null);
});

test('window: missing time cannot silently disappear into a complete zero',()=>{
 const q=aggregateSensorQuality(base({readings:[row('missing-time',{createdAt:'2026-10-16T02:00:00Z',temperature:24,humidity:50})]}));
 assert.equal(q.completeness.unknownWindowMembership,true);
 assert.ok(q.completeness.reasons.includes('reading_window_membership_unknown'));
 assert.equal(q.readings.count,null);
 assert.equal(q.readings.observed.count,0);
 assert.equal(q.distribution.collectionClock.maxGapSeconds,null);
});

test('window: legacy in-range value without receipt stays unknown for knowledge-cutoff reconstruction',()=>{
 const q=aggregateSensorQuality(base({readings:[row('legacy',{ts:'2026-10-16T02:00:00Z',temperature:0,humidity:0})]}));
 assert.equal(q.readings.count,null);
 assert.equal(q.readings.knowledgeReceiptUnknownCount,1);
 assert.ok(q.completeness.reasons.includes('reading_knowledge_receipt_unknown'));
 assert.equal(q.legacyTimestampDistribution.count,null);assert.equal(q.legacyTimestampDistribution.status,'unknown');assert.equal(q.legacyTimestampDistribution.observed.count,1);
 assert.equal(q.freshness.measuredAt,null);
});

test('window: unknown device membership prevents a false confirmed zero for a device-specific period',()=>{
 const q=aggregateSensorQuality(base({deviceId:'meter',readings:[reading('unmatched','2026-10-16T02:00:00Z')]}));
 assert.equal(q.readings.count,null);
 assert.ok(q.completeness.reasons.includes('device_membership_unknown'));
 assert.equal(q.readings.observed.count,0);
});

test('window: knowledge cutoff never counts late receipt or future collection as a missing future period',()=>{
 const q=aggregateSensorQuality(base({readings:[reading('late','2026-10-16T02:00:00Z',{createdAt:'2026-10-16T03:20:15.595Z'}),reading('future','2026-10-16T04:00:00Z')]}));
 assert.equal(q.readings.count,0);
 assert.equal(q.distribution.collectionClock.endGapSeconds,44415.594);
 assert.equal(q.evaluatedThrough,'2026-10-16T03:20:15.594000000Z');
});
