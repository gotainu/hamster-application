'use strict';
// Private operator transport only: never uses Admin SDK or deletes data directly.
const fs=require('node:fs');
const {execFileSync}=require('node:child_process');
const ENDPOINT='https://asia-northeast1-hamster-breeding-app.cloudfunctions.net/supportAccountDeletionOperator';
const CONFIRM_ORIGIN='https://hamster-breeding-app.web.app';
const requestId=v=>typeof v==='string'&&/^[a-f0-9]{48}$/.test(v);
function privateJson(file) {
  const stat=fs.lstatSync(file);
  if (!stat.isFile() || (stat.mode&0o077)) throw new Error('private_file_required');
  return JSON.parse(fs.readFileSync(file,'utf8'));
}
function savePrivate(file,value) {
  const fd=fs.openSync(file,'wx',0o600);
  try {fs.writeFileSync(fd,JSON.stringify(value,null,2)+'\n');} finally {fs.closeSync(fd);}
}
function parse(args) {
  const flags={};
  for (const a of args) {
    const match=/^--([a-z-]+)(?:=(.*))?$/.exec(a);
    if (!match || Object.hasOwn(flags,match[1])) throw new Error('invalid_arguments');
    flags[match[1]]=match[2]??true;
  }
  if (Object.keys(flags).some(k=>!['service-account','request','create','input','output','execute','review-file','ack'].includes(k)) ||
      !/^[a-z][a-z0-9-]+@hamster-breeding-app\.iam\.gserviceaccount\.com$/.test(flags['service-account']||'')) throw new Error('invalid_arguments');
  if (flags.create===true) {
    if (!flags.input || !flags.output || flags.execute || flags.request || flags['review-file'] || flags.ack) throw new Error('invalid_arguments');
    const input=privateJson(flags.input);
    if (Object.keys(input).sort().join(',')!=='intakeRef,targetUid') throw new Error('invalid_input');
    return {flags,body:{action:'create',...input}};
  }
  if (!requestId(flags.request) || flags.input || flags.create) throw new Error('invalid_arguments');
  if (flags.execute===true) {
    if (!flags['review-file'] || flags.ack!=='EXECUTE_VERIFIED_DELETION' || flags.output) throw new Error('explicit_review_required');
    const review=privateJson(flags['review-file']);
    if (review.requestId!==flags.request || typeof review.reviewDigest!=='string') throw new Error('review_mismatch');
    return {flags,body:{action:'execute',requestId:flags.request,reviewDigest:review.reviewDigest,confirmText:flags.ack}};
  }
  if (flags.execute || flags['review-file'] || flags.ack || !flags.output) throw new Error('invalid_arguments');
  return {flags,body:{action:'review',requestId:flags.request}};
}
async function run(args,{token,send,write=savePrivate}={}) {
  const {flags,body}=parse(args);
  const credential=token?await token(flags['service-account']):execFileSync('gcloud',[
    'auth','print-identity-token','--quiet','--impersonate-service-account='+flags['service-account'],
    '--audiences='+ENDPOINT],{encoding:'utf8',stdio:['ignore','pipe','pipe']}).trim();
  const response=send?await send(body,credential):await fetch(ENDPOINT,{method:'POST',redirect:'error',
    headers:{Authorization:'Bearer '+credential,'Content-Type':'application/json'},body:JSON.stringify(body),
    signal:AbortSignal.timeout(550000)}).then(async r=>{if(!r.ok)throw new Error('request_rejected');return r.json();});
  if (body.action==='create') {
    if (!requestId(response.requestId) || !/^[a-f0-9]{64}$/.test(response.proof)) throw new Error('invalid_response');
    write(flags.output,{requestId:response.requestId,expiresAt:response.expiresAt,
      verificationLink:CONFIRM_ORIGIN+'/account-deletion/confirm/#request='+response.requestId+'&proof='+response.proof});
    return {status:'link_saved_privately'};
  }
  if (body.action==='review') {
    write(flags.output,{requestId:body.requestId,...response});
    return {status:'review_saved_privately',dryRun:true};
  }
  return {status:response.status??(response.ok?'completed':'processing'),completionConfirmed:response.completionConfirmed===true};
}
module.exports={run,parse,ENDPOINT};
if (require.main===module) run(process.argv.slice(2)).then(result=>process.stdout.write(JSON.stringify(result)+'\n'))
  .catch(()=>{process.stderr.write('削除申請の操作を完了できませんでした。権限・申請・確認ファイルとサーバーの処理状態を確認してください。\n');process.exitCode=1;});
