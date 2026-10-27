'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {loadStarSource,fakeFirestore}=require('./support/star_source_loader.cjs');
function stamp(Stamp,iso){const value=new Stamp(iso);value.seconds=Math.floor(Date.parse(iso)/1000);value.nanoseconds=0;return value;}
test('configuration evidence copies only allowlisted fields and never asserts continuous eligibility',async()=>{
 const {db,admin,Stamp}=fakeFirestore();
 const api=loadStarSource({admin})('sensorQuality/configuration');db.documents.set('users/owner/integrations/switchbot',{meterDeviceId:'current'});
 const data={meterDeviceId:'meter-1',enabled:true,hasSecrets:true,token:'secret',memo:'private'};
 const input={db,uid:'owner',sourcePath:'users/owner/integrations/switchbot',sourceUpdatedAt:stamp(Stamp,'2026-10-16T01:00:00Z'),before:null,after:data};
 const first=await api.recordSensorConfiguration(input);
 const replay=await api.recordSensorConfiguration(input);
 assert.equal(first.stateId,replay.stateId);assert.equal(replay.replayed,true);assert.equal([...db.documents.keys()].filter(p=>p.includes('/sensor_polling_state/')).length,1);
 const stored=[...db.documents.entries()].find(([p])=>p.includes('/sensor_polling_state/'))[1];
 assert.equal(stored.eligibility,'unknown');assert.equal(stored.continuity,'transition_only');
 assert.equal(stored.config.deviceId,'meter-1');assert.equal(JSON.stringify(stored).includes('secret'),false);assert.equal(JSON.stringify(stored).includes('private'),false);
 assert.equal(stored.policy.slotAnchor,null);
});
test('device changes and disconnects create distinct immutable transitions; no-op does not grow history',async()=>{
 const {db,admin,Stamp}=fakeFirestore();const api=loadStarSource({admin})('sensorQuality/configuration');db.documents.set('users/owner/integrations/switchbot',{meterDeviceId:'current'});
 const base={db,uid:'owner',sourcePath:'users/owner/integrations/switchbot'};
 const a={meterDeviceId:'meter-1',enabled:true,hasSecrets:true};const b={...a,meterDeviceId:'meter-2'};
 await api.recordSensorConfiguration({...base,sourceUpdatedAt:stamp(Stamp,'2026-10-16T01:00:00Z'),before:null,after:a});
 await api.recordSensorConfiguration({...base,sourceUpdatedAt:stamp(Stamp,'2026-10-16T02:00:00Z'),before:a,after:b});
 const noop=await api.recordSensorConfiguration({...base,sourceUpdatedAt:stamp(Stamp,'2026-10-16T03:00:00Z'),before:b,after:{...b,updatedAt:'ignored'}});assert.equal(noop.changed,false);
 await api.recordSensorConfiguration({...base,sourceUpdatedAt:stamp(Stamp,'2026-10-16T04:00:00Z'),before:b,after:{enabled:false,hasSecrets:false}});
 assert.equal([...db.documents.keys()].filter(p=>p.includes('/sensor_polling_state/')).length,3);assert.deepEqual([...db.documents.entries()].filter(([p])=>p.includes('/sensor_polling_state/')).map(([,x])=>x.config.deviceId),['meter-1','meter-2',null]);
});
test('unversioned changes remain unknown; same source revision different content is refused',async()=>{
 const {db,admin,Stamp}=fakeFirestore();const api=loadStarSource({admin})('sensorQuality/configuration');db.documents.set('users/owner/integrations/switchbot',{meterDeviceId:'current'});
 const base={db,uid:'owner',sourcePath:'users/owner/integrations/switchbot',before:null,after:{meterDeviceId:'meter-1'}};
 assert.deepEqual(await api.recordSensorConfiguration({...base,sourceUpdatedAt:null}),{changed:false,reason:'source_version_unknown'});
 const input={...base,sourceUpdatedAt:stamp(Stamp,'2026-10-16T01:00:00Z')};await api.recordSensorConfiguration(input);
 await assert.rejects(api.recordSensorConfiguration({...input,after:{meterDeviceId:'meter-2'}}),/configuration_evidence_collision/);
 assert.equal([...db.documents.keys()].filter(p=>p.includes('/sensor_polling_state/')).length,1);
});
