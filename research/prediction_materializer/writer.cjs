'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {loadTypeScript}=require('../prediction_dataset/tools/load-typescript.cjs');
const {canonicalStringify}=loadTypeScript(path.join(__dirname,'../prediction_dataset/src/canonical.ts'));
const {TABLE_COLUMNS}=loadTypeScript(path.join(__dirname,'src/table.ts'));
const sha256=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const csvCell=text=>'"'+text.replace(/"/g,'""')+'"';
function toCsv(rows) {
  return TABLE_COLUMNS.map(csvCell).join(',')+'\r\n'+rows.map(row=>TABLE_COLUMNS.map(column=>csvCell(canonicalStringify(row[column]))).join(',')+'\r\n').join('');
}
/** Readback helper: every cell is JSON before RFC4180 quoting, so null/0/false/strings remain distinct. */
function fromCsv(csv) {
  const records=[],record=[];let field='',quoted=false;
  for(let i=0;i<csv.length;i++) {
    const c=csv[i];
    if(c==='"') {if(quoted&&csv[i+1]==='"'){field+='"';i++;}else quoted=!quoted;}
    else if(!quoted&&c===','){record.push(field);field='';}
    else if(!quoted&&(c==='\r'||c==='\n')) {if(c==='\r'&&csv[i+1]==='\n')i++;record.push(field);field='';records.push(record.splice(0));}
    else field+=c;
  }
  if(quoted||field||record.length)throw new Error('invalid_or_unterminated_csv');
  const header=records.shift();
  if(!header||JSON.stringify(header)!==JSON.stringify(TABLE_COLUMNS))throw new Error('csv_schema_mismatch');
  return records.map(fields=>{if(fields.length!==header.length)throw new Error('csv_column_count_mismatch');return Object.fromEntries(header.map((column,i)=>[column,JSON.parse(fields[i])]));});
}
function writeMaterialization(result,{outputRoot,runId,generatedAt}) {
  if(!/^[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}$/.test(runId))throw new Error('invalid_run_id');
  if(typeof generatedAt!=='string'||!Number.isFinite(Date.parse(generatedAt)))throw new Error('explicit_generated_at_required');
  fs.mkdirSync(outputRoot,{recursive:true,mode:0o700});
  const directory=path.resolve(outputRoot,runId);
  // Exclusive reservation: existing tables, even an incomplete run, are never overwritten.
  fs.mkdirSync(directory,{mode:0o700});
  const jsonl=rows=>rows.map(row=>canonicalStringify(row)+'\n').join('');
  const documents={
    'rows.jsonl':jsonl(result.rows),'rows.csv':toCsv(result.rows),
    'candidate_rows.jsonl':jsonl(result.rows.filter(row=>row.row_status==='candidate')),
    'excluded_rows.jsonl':jsonl(result.excludedRows),
    'config.json':canonicalStringify(result.config)+'\n',
  };
  const artifacts=Object.fromEntries(Object.entries(documents).map(([name,bytes])=>[name,{sha256:sha256(bytes),bytes:Buffer.byteLength(bytes)}]));
  for(const [name,bytes] of Object.entries(documents))fs.writeFileSync(path.join(directory,name),bytes,{flag:'wx',mode:0o600});
  const audit={run_id:runId,generated_at:generatedAt,content_hash:result.manifest.content_hash,rows:result.audit};
  fs.writeFileSync(path.join(directory,'audit.json'),JSON.stringify(audit,null,2)+'\n',{flag:'wx',mode:0o600});
  // Manifest is the completion marker. Partial writes have no successful manifest.
  const manifest={...result.manifest,artifacts};
  fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx',mode:0o600});
  return {directory,manifest};
}
module.exports={writeMaterialization,toCsv,fromCsv};
