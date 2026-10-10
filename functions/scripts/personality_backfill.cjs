#!/usr/bin/env node
'use strict';
// Local emulator only. Missing current Silver uses the existing source reader
// and feature builder, without legacy report/health notification side effects.
// No deploy or ADC production fallback. Default is a read-only preview.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {validateWriteTarget} = require('./seed_reference_cohorts.cjs');
function parseOptions(argv) {
  const options={dryRun:true}; let write=false; let dry=false;
  for(const arg of argv){
    if(arg==='--write')write=true;
    else if(arg==='--dry-run')dry=true;
    else if(arg.startsWith('--project=')&&!options.projectId)options.projectId=arg.slice(10);
    else if(arg.startsWith('--uids=')&&!options.uids)options.uids=arg.slice(7).split(',');
    else if(arg.startsWith('--evaluation-date=')&&!options.evaluationDateKey)options.evaluationDateKey=arg.slice(18);
    else throw new Error('Unknown or repeated argument');
  }
  if(write&&dry)throw new Error('Choose --write or --dry-run');
  if(!options.uids?.length||options.uids.some(uid=>!/^[-a-zA-Z0-9_]{1,128}$/.test(uid)))throw new Error('Explicit safe UIDs are required');
  options.dryRun=!write;
  return options;
}
function loadReportSource(){
  const ts=require('typescript'); const cache=new Map();
  function load(filename){
    if(cache.has(filename))return cache.get(filename).exports;
    const output=ts.transpileModule(fs.readFileSync(filename,'utf8'),{fileName:filename,compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS,esModuleInterop:true}}).outputText;
    const mod={exports:{}};cache.set(filename,mod);
    const localRequire=name=>name.startsWith('.')?load(path.resolve(path.dirname(filename),name+'.ts')):require(name);
    vm.runInThisContext('(function(exports,require,module){'+output+'\n})',{filename})(mod.exports,localRequire,mod);
    return mod.exports;
  }
  return load(path.resolve(__dirname,'../src/health/personalityBackfill.ts')).backfillPersonalityReport;
}
async function backfillUsers({db,target,uids,evaluationDateKey,now,dryRun=true,sync}){
  validateWriteTarget(target);
  if(db.projectId!==target.projectId)throw new Error('Firestore project does not match the guarded demo project');
  const publish=sync||loadReportSource(); const results=[];
  // Missing current-day Silver is freshly built from Bronze first. Publication
  // then uses the same transaction/idempotency path as the current-day trigger.
  for(const uid of new Set(uids)){
    if(!/^[-a-zA-Z0-9_]{1,128}$/.test(uid))throw new Error('Invalid UID');
    results.push({uid,...await publish({db,uid,evaluationDateKey,now,dryRun})});
  }
  return results;
}
async function main(){
  const options=parseOptions(process.argv.slice(2));
  const target={projectId:options.projectId,emulatorHost:process.env.FIRESTORE_EMULATOR_HOST};
  validateWriteTarget(target); // Before loading/initializing Firebase.
  const now=new Date();
  const today=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Tokyo',year:'numeric',month:'2-digit',day:'2-digit'}).format(now);
  const admin=require('firebase-admin');
  const app=admin.initializeApp({projectId:options.projectId},'personality-local-backfill');
  try{
    const results=await backfillUsers({db:app.firestore(),target,uids:options.uids,evaluationDateKey:options.evaluationDateKey||today,now,dryRun:options.dryRun});
    process.stdout.write(JSON.stringify({mode:options.dryRun?'dry_run':'emulator_write',results},null,2)+'\n');
  }finally{await app.delete();}
}
module.exports={parseOptions,backfillUsers};
if(require.main===module)main().catch(error=>{process.stderr.write(error.message+'\n');process.exitCode=1;});
