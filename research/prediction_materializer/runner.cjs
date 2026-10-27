'use strict';
// Local files only. No DB/API adapter or cloud credentials are accepted.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {loadTypeScript,loadedSourceFiles,typescriptVersion}=require('../prediction_dataset/tools/load-typescript.cjs');
const root=__dirname,repo=path.resolve(root,'../..');
const sha256=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function codeIdentity() {
  const ownSources=fs.readdirSync(path.join(root,'src')).filter(name=>name.endsWith('.ts')).map(name=>path.join(root,'src',name));
  const files=[...new Set([...loadedSourceFiles(),...ownSources,__filename,path.join(root,'writer.cjs'),path.join(root,'../prediction_dataset/tools/load-typescript.cjs')])].sort();
  const sources=files.map(filename=>({path:path.relative(repo,filename).split(path.sep).join('/'),sha256:sha256(fs.readFileSync(filename))}));
  return {sha256:sha256(JSON.stringify({sources,node:process.versions.node,typescript:typescriptVersion})),sources,node:process.versions.node,typescript:typescriptVersion};
}
function argumentsFor(argv) {
  const options={};
  for(let i=0;i<argv.length;i+=2) {
    const key=argv[i];
    if(!['--source','--config','--output','--run-id'].includes(key)||!argv[i+1]||options[key])throw new Error('usage: --source FILE --config FILE --output DIRECTORY --run-id ID');
    options[key]=argv[i+1];
  }
  if(Object.keys(options).length!==4)throw new Error('source_config_output_run_id_required');
  for(const key of ['--source','--config','--output']) if(/^[a-z][a-z0-9+.-]*:\/\//i.test(options[key]))throw new Error('local_paths_only');
  return options;
}
async function run(argv=process.argv.slice(2)) {
  const options=argumentsFor(argv);
  const source=JSON.parse(fs.readFileSync(options['--source'],'utf8'));
  const config=JSON.parse(fs.readFileSync(options['--config'],'utf8'));
  const {materializeRepository}=loadTypeScript(path.join(root,'src/materialize.ts'));
  const {JsonSnapshotRepository}=loadTypeScript(path.join(root,'src/sourceTypes.ts'));
  const {writeMaterialization}=require('./writer.cjs');
  const identity=codeIdentity();
  const result=await materializeRepository(new JsonSnapshotRepository(source),config,identity.sha256);
  const written=writeMaterialization(result,{outputRoot:options['--output'],runId:options['--run-id'],generatedAt:new Date().toISOString()});
  fs.writeFileSync(path.join(written.directory,'execution.json'),JSON.stringify({code:identity,source_file_sha256:sha256(fs.readFileSync(options['--source'])),config_file_sha256:sha256(fs.readFileSync(options['--config'])),content_hash:result.manifest.content_hash},null,2)+'\n',{flag:'wx',mode:0o600});
  process.stdout.write(JSON.stringify({directory:written.directory,content_hash:result.manifest.content_hash,state_counts:result.manifest.state_counts})+'\n');
  return written;
}
if(require.main===module)run().catch(error=>{process.stderr.write((error.code==='EEXIST'?'run_id_already_exists':error.message)+'\n');process.exitCode=1;});
module.exports={run,codeIdentity,argumentsFor};
