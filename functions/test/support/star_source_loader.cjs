'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),ts=require('typescript');
const ROOT=path.resolve(__dirname,'../../src');
function loadStarSource({admin,now=()=>new Date()}={}){
 const cache=new Map(); const RealDate=Date;
 class ClockDate extends RealDate{constructor(...args){super(...(args.length?args:[now().getTime()]));}static now(){return now().getTime();}static [Symbol.hasInstance](x){return x instanceof RealDate;}}
 function load(file){if(cache.has(file))return cache.get(file).exports;const mod={exports:{}};cache.set(file,mod);
  const code=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS,esModuleInterop:true}}).outputText;
  const req=name=>name==='firebase-admin'?admin:name==='firebase-functions/v2/https'?{onCall:(_o,fn)=>fn,HttpsError:class extends Error{constructor(code,msg){super(msg);this.code=code;}}}:name==='firebase-functions/v2/firestore'?{onDocumentWritten:(o,fn)=>Object.assign(fn,{__triggerOptions:o})}:name==='firebase-functions/logger'?{info(){},error(){}}:name.startsWith('.')?load(path.resolve(path.dirname(file),name+'.ts')):require(name);
  vm.runInThisContext(`(function(exports,require,module,Date){${code}\n})`,{filename:file})(mod.exports,req,mod,ClockDate);return mod.exports;
 }
 return name=>load(path.join(ROOT,name+'.ts'));
}
class Stamp{constructor(date){this.date=new Date(date);}toDate(){return new Date(this.date);}toMillis(){return this.date.getTime();}}
function fakeFirestore({clock=()=>new Date('2026-10-12T01:00:00Z')}={}){
 const docs=new Map(),writes=[];let tail=Promise.resolve();
 const clone=x=>x instanceof Stamp?new Stamp(x.toDate()):x instanceof Date?new Date(x):Array.isArray(x)?x.map(clone):x&&typeof x==='object'?Object.fromEntries(Object.entries(x).map(([k,v])=>[k,clone(v)])):x;
 const val=(x,k)=>k.split('.').reduce((a,p)=>a?.[p],x);
 const snap=ref=>({ref,id:ref.id,exists:docs.has(ref.path),data:()=>clone(docs.get(ref.path)),get:k=>clone(val(docs.get(ref.path),k)),updateTime:new Stamp(docs.get(ref.path)?.__acceptedAt??clock())});
 function ref(p){return {path:p,id:p.split('/').at(-1),collection:n=>ref(p+'/'+n),doc:n=>ref(p+'/'+n),get:async()=>snap(ref(p)),async delete(){docs.delete(p);writes.push(['delete',p]);},orderBy(){return query(p);},limit(n){return query(p,n);}};}
 function query(p,limit=100){return{queryPath:p,get queryLimit(){return limit;},orderBy(){return this;},limit(n){limit=n;return this;},async get(){const matching=[...docs.keys()].filter(k=>k.startsWith(p+'/')&&!k.slice(p.length+1).includes('/')).sort((a,b)=>(docs.get(a).acceptedAt?.toMillis?.()??0)-(docs.get(b).acceptedAt?.toMillis?.()??0)).slice(0,limit);return{docs:matching.map(k=>snap(ref(k))),size:matching.length,empty:!matching.length};}};}
 const db={documents:docs,writes,doc:ref,collection:ref,async runTransaction(fn){const run=tail.then(async()=>{const pending=[];const result=await fn({get:async r=>{if(pending.length)throw Error('Read after write');return r.queryPath ? query(r.queryPath,r.queryLimit).get() : snap(r);},create:(r,v)=>pending.push(['create',r.path,clone(v)]),set:(r,v,opt)=>pending.push(['set',r.path,clone(v),opt]),delete:r=>pending.push(['delete',r.path])});for(const[m,p,v,opt]of pending){if(m==='create'&&docs.has(p))throw Error('Duplicate create');if(m==='delete')docs.delete(p);else docs.set(p,opt?.merge?{...docs.get(p),...v}:v);writes.push([m,p]);}return result;});tail=run.catch(()=>{});return run;}};
 const firestore=()=>db;firestore.FieldValue={serverTimestamp:()=>new Stamp(clock())};firestore.Timestamp={fromDate:d=>new Stamp(d)};
 return {db,admin:{firestore},Stamp};
}
module.exports={loadStarSource,fakeFirestore,Stamp};
