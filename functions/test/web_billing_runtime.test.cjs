'use strict';
// Runtime wiring tests use a synthetic Auth service, an in-memory database and
// captured engine factories. No Admin app, network client or delivery is opened.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),ts=require('typescript');
const {loadStarSource}=require('./support/star_source_loader.cjs');
const load=loadStarSource();
const cfg=load('webBillingConfig'),identity=load('webBillingShared'),webhook=load('webBillingWebhook');
const NOW=Date.UTC(2030,0,1),UID='syntheticRuntimeOwner';
const config=extra=>({secretKey:'sk_live_synthetic',publishableKey:'pk_live_synthetic',priceId:'price_syntheticNew550',legacyPriceId:'price_syntheticOld500',
  webhookSecret:'whsec_synthetic',portalConfigurationId:'bpc_syntheticRestricted',origin:cfg.WEB_BILLING_ORIGIN,returnUrl:cfg.WEB_BILLING_RETURN_URL,...extra});
const deletion=load('accountDeletion');
const markerPath=uid=>deletion.accountDeletionRef({doc:path=>({path})},uid).path;
const clone=v=>structuredClone(v);
function fixture(options={}) {
  const calls={config:0,factory:[],verify:[],user:[],read:[],write:[],checkout:[],portal:[],webhook:[],signature:[]},captured={};
  const documents=new Map(options.documents??[]);
  const ref=p=>({path:p,async get(){calls.read.push(p);return {exists:documents.has(p),data:()=>documents.get(p)};}});
  const db={doc:ref,async runTransaction(fn){const writes=[];const result=await fn({get:r=>r.get(),set:(r,v)=>writes.push([r.path,v])});
    for(const [p,v]of writes){documents.set(p,v);calls.write.push([p,v]);}return result;}};
  const user={uid:UID,disabled:false,email:'synthetic@example.test',emailVerified:true,providerData:[],...options.user};
  const token={uid:UID,email_verified:true,firebase:{sign_in_provider:'password'},...options.token};
  const auth={async verifyIdToken(value,revoked){calls.verify.push([value,revoked]);if(options.revoked)throw Error('synthetic revoked token');return token;},
    async getUser(uid){calls.user.push(uid);return user;}};
  const client={webhooks:{constructEvent(...args){calls.signature.push(args);if(options.badSignature)throw Error('synthetic secret raw body');
    return {id:'evt_syntheticRuntime',type:'invoice.paid',livemode:true,created:NOW/1000,data:{object:{id:'in_syntheticRuntime'}},...options.event};}}};
  const imports={
    './accountDeletion':deletion,'./webBillingConfig':cfg,'./webBillingShared':identity,
    './webBillingCheckout':{WEB_BILLING_CONTACT_PURPOSE:'billing_contact_live',createWebBillingCheckout(d){captured.checkout=d;
      return Object.fromEntries(['review','create','status','cancel'].map(action=>[action,async(who,input)=>{calls.checkout.push([action,who,input]);return {action};}]));}},
    './webBillingCustomer':{createWebBillingCustomerResolver(d){captured.customer=d;return {resolveCustomer:async input=>({customerId:'cus_syntheticRuntime'})};}},
    './webBillingPortal':{createWebBillingPortalEngine(d){captured.portal=d;return {async create(who){calls.portal.push(who);return {url:'https://billing.stripe.com/p/session/live_syntheticRuntime'};}};}},
    './webBillingWebhook':{...webhook,createWebBillingWebhook(d){captured.webhook=d;return {async process(event){calls.webhook.push(event);return {result:'synced'};}};}},
    './webBillingWebhookStore':{createWebBillingWebhookStore(db,now){captured.webhookStore={db,now};return {synthetic:true};}},
  };
  const file=path.resolve(__dirname,'../src/webBillingRuntime.ts'),mod={exports:{}};
  const code=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020,esModuleInterop:true}}).outputText;
  vm.runInThisContext(`(function(exports,require,module){${code}\n})`,{filename:file})(mod.exports,name=>imports[name]??require(name),mod);
  const runtime=mod.exports.createProductionWebBillingRuntime({db,auth,now:()=>new Date(NOW),
    ...(options.omitPurchaseSwitch?{}:{purchaseEnabled:()=>Object.hasOwn(options,'purchaseEnabled')?options.purchaseEnabled:true}),
    ...(options.omitWebhookSwitch?{}:{webhookEnabled:()=>Object.hasOwn(options,'webhookEnabled')?options.webhookEnabled:true}),
    rawConfig:()=>{calls.config++;return options.rawConfig===undefined?JSON.stringify(config()):options.rawConfig;},
    stripeFactory:key=>{calls.factory.push(key);return client;}});
  const request=(data={flow:'web',action:'review',planKey:'premium_monthly'},headers={})=>({data,auth:{uid:UID},
    rawRequest:{headers:{origin:cfg.WEB_BILLING_ORIGIN,authorization:'Bearer synthetic-token',...headers}}});
  return {runtime,calls,captured,documents,db,user,token,request,api:mod.exports};
}
test('runtime registration performs no configuration read, Stripe construction, Auth or Firestore work',()=>{
  const f=fixture();assert.deepEqual(f.calls,{config:0,factory:[],verify:[],user:[],read:[],write:[],checkout:[],portal:[],webhook:[],signature:[]});
});
for(const rawConfig of ['',{},'not-json',JSON.stringify(config({secretKey:'sk_test_synthetic'})),JSON.stringify(config({priceId:undefined})),JSON.stringify(config({returnUrl:'https://outside.invalid'}))]) {
  test('invalid production configuration stops every route before Auth, Stripe or database',async()=>{
    const f=fixture({rawConfig});
    await assert.rejects(f.runtime.checkout(f.request()));await assert.rejects(f.runtime.portal(f.request({})));
    await assert.rejects(f.runtime.webhook(Buffer.from('{}'),'synthetic'));
    assert.equal(f.calls.config,3);for(const name of ['factory','verify','user','read','write','signature','checkout','portal','webhook'])assert.equal(f.calls[name].length,0,name);
  });
}
for(const [name,request]of [
  ['old native purchase',f=>f.request(null)],['missing explicit Web flow',f=>f.request({action:'review',planKey:'premium_monthly'})],
  ['unknown action',f=>f.request({flow:'web',action:'other'})],['foreign origin',f=>f.request(undefined,{origin:'https://outside.invalid'})],
  ['missing origin',f=>f.request(undefined,{origin:undefined})],['status body includes client UID',f=>f.request({flow:'web',action:'status',uid:'syntheticOther'})],
])test('purchase transport rejects '+name+' before Auth or Stripe',async()=>{
  const f=fixture();await assert.rejects(f.runtime.checkout(request(f)));assert.equal(f.calls.verify.length,0);assert.equal(f.calls.factory.length,0);assert.equal(f.calls.write.length,0);
});
test('server identity uses revocation verification and same-UID current Admin user',async()=>{
  const f=fixture();assert.deepEqual(await f.runtime.checkout(f.request()),{ok:true,action:'review'});
  assert.deepEqual(f.calls.verify,[['synthetic-token',true]]);assert.deepEqual(f.calls.user,[UID]);assert.deepEqual(f.calls.factory,['sk_live_synthetic']);
  assert.equal(f.calls.checkout[0][1].uid,UID);assert.equal(f.calls.write.length,0);
});
for(const [name,options,alter]of [
  ['revoked token',{revoked:true}],['disabled user',{user:{disabled:true}}],['token/user mismatch',{user:{uid:'syntheticOther'}}],
  ['callable/token mismatch',{},r=>{r.auth.uid='syntheticOther';}],['missing bearer',{},r=>{delete r.rawRequest.headers.authorization;}],
  ['UID path injection',{token:{uid:'synthetic/Other'}}],
])test('identity rejection stops engine and Stripe construction: '+name,async()=>{
  const f=fixture(options),r=f.request();if(alter)alter(r);await assert.rejects(f.runtime.checkout(r));
  assert.equal(f.calls.factory.length,0);assert.equal(f.calls.checkout.length,0);assert.equal(f.calls.write.length,0);
});
test('verified Apple session without email remains the same UID without fabricated verification',async()=>{
  const f=fixture({token:{email_verified:false,firebase:{sign_in_provider:'apple.com',identities:{'apple.com':['syntheticAppleSubject']}}},
    user:{email:undefined,emailVerified:false,providerData:[{providerId:'apple.com',uid:'syntheticAppleSubject'}]}});
  await f.runtime.checkout(f.request());const who=f.calls.checkout[0][1];
  assert.equal(who.uid,UID);assert.equal(who.authBasis,'apple_provider');assert.equal(who.emailVerified,false);assert.equal(who.email,undefined);
});
test('facts read existing owner/main, pet/main_pet, billing/subscription and original initial_trial_v2 paths',async()=>{
  const f=fixture({documents:[[`users/${UID}/owner_profiles/main`,{displayName:'  Synthetic owner  '}],[`users/${UID}/pet_profiles/main_pet`,{}],
    [`users/${UID}/feature_access/initial_trial_v2`,{status:'active'}]]});
  await f.runtime.checkout(f.request());const facts=await f.captured.checkout.readFacts(UID);
  assert.equal(facts.appAccountExists,true);assert.equal(facts.nickname,'Synthetic owner');assert.equal(facts.billing.kind,'missing');assert.equal(facts.trial.kind,'found');
  assert.deepEqual(new Set(f.calls.read),new Set([markerPath(UID),`users/${UID}/owner_profiles/main`,`users/${UID}/pet_profiles/main_pet`,
    `users/${UID}/billing/subscription`,`users/${UID}/feature_access/initial_trial_v2`]));
  assert.equal(f.calls.write.length,0);
});
test('new purchase facts require both owner and pet while still reading original billing',async()=>{
  const f=fixture({documents:[[`users/${UID}/pet_profiles/main_pet`,{}]]});await f.runtime.checkout(f.request());
  assert.equal((await f.captured.checkout.readFacts(UID)).appAccountExists,false);assert.equal(f.calls.write.length,0);
});
test('verified Auth contact is read from current Admin identity without contact fallback reads',async()=>{
  const f=fixture();await f.runtime.checkout(f.request());const who=f.calls.checkout[0][1];
  assert.equal(await f.captured.checkout.readContact(who),'synthetic@example.test');assert.deepEqual(f.calls.read,[markerPath(UID)]);assert.equal(f.calls.write.length,0);
});
function appleC(options={}) {
  return {token:{email_verified:false,firebase:{sign_in_provider:'apple.com',identities:{'apple.com':['syntheticAppleSubject']}}},
    user:{email:undefined,emailVerified:false,providerData:[{providerId:'apple.com',uid:'syntheticAppleSubject'}]},...options};
}
const verifiedContact=extra=>({firebaseUid:UID,purpose:'billing_contact_live',schemaVersion:1,verified:true,
  verificationStatus:'verified',source:'user_supplied',verifiedAt:NOW-1000,email:'synthetic-contact@example.test',...extra});
test('email-less Apple contact reads only strict same-UID verified production schema',async()=>{
  const f=fixture(appleC({documents:[[`billing_contacts/${UID}`,verifiedContact()],[`preview_billing_contacts/${UID}`,{email:'synthetic-preview@example.test'}]]}));
  await f.runtime.checkout(f.request());assert.equal(await f.captured.checkout.readContact(f.calls.checkout[0][1]),'synthetic-contact@example.test');
  assert.deepEqual(f.calls.read,[markerPath(UID),`billing_contacts/${UID}`]);assert.equal(f.calls.write.length,0);
});
for(const [field,value]of [['firebaseUid','syntheticOther'],['purpose','preview'],['verified',false],['verificationStatus','pending'],['source','unverified'],['verifiedAt',NOW+1],['email','bad email']])
  test('independent contact rejects '+field+' without writes or Preview fallback',async()=>{
    const f=fixture(appleC({documents:[[`billing_contacts/${UID}`,verifiedContact({[field]:value})]]}));await f.runtime.checkout(f.request());
    assert.equal(await f.captured.checkout.readContact(f.calls.checkout[0][1]),null);assert.deepEqual(f.calls.read,[markerPath(UID),`billing_contacts/${UID}`]);assert.equal(f.calls.write.length,0);
  });
test('contact reader refuses another UID supplied to the already authorized request',async()=>{
  const f=fixture();await f.runtime.checkout(f.request());assert.equal(await f.captured.checkout.readContact({uid:'syntheticOther'}),null);assert.deepEqual(f.calls.read,[markerPath(UID)]);
});
test('native Portal null payload preserves existing callable DTO and needs no contact or new account facts',async()=>{
  const f=fixture(appleC());const result=await f.runtime.portal(f.request(null,{origin:undefined}));
  assert.deepEqual(result,{ok:true,portalUrl:'https://billing.stripe.com/p/session/live_syntheticRuntime'});assert.equal(f.calls.portal[0].uid,UID);
  assert.deepEqual(f.calls.read,[]);assert.deepEqual(f.calls.write,[]);
});
test('Portal rejects foreign origins and supplied Customer identifiers before authentication',async()=>{
  for(const [data,headers]of [[{customerId:'cus_syntheticOther'},{}],[{}, {origin:'https://outside.invalid'}]]){
    const f=fixture();await assert.rejects(f.runtime.portal(f.request(data,headers)));assert.equal(f.calls.verify.length,0);assert.equal(f.calls.factory.length,0);
  }
});
test('coordination transactions write only selected hashed namespace and never production entitlement',async()=>{
  const f=fixture();for(const collection of ['billing_customers','billing_checkout_sessions']){
    const store=f.api.createWebBillingCoordinationStore(f.db,collection);
    await store.mutate(UID,s=>({state:{...s,firebaseUid:UID,synthetic:true},result:true}));assert.equal((await store.read(UID)).firebaseUid,UID);
  }
  assert.equal(f.calls.write.length,2);for(const [p]of f.calls.write)assert.match(p,/^billing_(?:customers|checkout_sessions)\/[a-f0-9]{64}$/);
});
test('signed runtime webhook forwards exact bytes and clock then delegates only verified event',async()=>{
  const f=fixture();const raw=Buffer.from('{"synthetic":true}'),signature='t='+NOW/1000+',v1=synthetic';
  assert.deepEqual(await f.runtime.webhook(raw,signature),{result:'synced'});
  assert.equal(f.calls.signature[0][0],raw);assert.equal(f.calls.signature[0][1],signature);assert.equal(f.calls.signature[0][5],NOW);
  assert.equal(f.captured.webhookStore.db,f.db);assert.equal(f.captured.webhookStore.now(),NOW);
  assert.equal(f.calls.webhook[0].livemode,true);assert.equal(f.calls.verify.length,0);assert.equal(f.calls.write.length,0);
});
test('signature failure opens no database store, performs no billing write and has no raw public error',async()=>{
  const f=fixture({badSignature:true});await assert.rejects(f.runtime.webhook(Buffer.from('{}'),'t='+NOW/1000+',v1=synthetic'),e=>e.code==='signature_invalid');
  assert.equal(f.captured.webhookStore,undefined);assert.equal(f.calls.webhook.length,0);assert.deepEqual(f.calls.read,[]);assert.deepEqual(f.calls.write,[]);
});
test('public error mapping never serializes SDK errors, keys, email or raw object details',()=>{
  const f=fixture(),raw=Object.assign(new Error('sk_live_private synthetic@example.test cus_private raw'),{code:'permission-denied',data:{uid:UID}});
  const unavailable=f.api.safeWebBillingError(raw);assert.deepEqual(unavailable,{code:'unavailable',message:f.api.WEB_BILLING_UNAVAILABLE});
  assert.deepEqual(f.api.safeWebBillingError(new identity.BillingAuthenticationError('unauthenticated')),{code:'unauthenticated',message:'HamCareアカウントへログインしてください。'});
  assert.doesNotMatch(JSON.stringify(unavailable),/sk_|cus_|synthetic|permission|uid|raw/);
});
test('contact re-read revalidates current Admin state instead of reusing initial email evidence',async()=>{
  const f=fixture();await f.runtime.checkout(f.request());const prior=f.calls.checkout[0][1];
  f.user.email='synthetic-new@example.test';
  assert.equal(await f.captured.checkout.readContact(prior),'synthetic-new@example.test');
  assert.equal(f.calls.verify.length,2);assert.equal(f.calls.user.length,2);assert.equal(f.calls.write.length,0);
});
test('contact re-read rejects disabled or newly unverified Admin state before any session or database write',async()=>{
  for(const change of [{disabled:true},{emailVerified:false}]){
    const f=fixture();await f.runtime.checkout(f.request());Object.assign(f.user,change);
    await assert.rejects(f.captured.checkout.readContact(f.calls.checkout[0][1]));assert.equal(f.calls.write.length,0);
  }
});
for(const [name,options]of [
  ['unverified normal email',{token:{email_verified:false},user:{emailVerified:false}}],
  ['missing normal email',{token:{email_verified:false},user:{email:undefined,emailVerified:false}}],
]) {
  test('existing Portal retains management with '+name+' through explicit server session proof',async()=>{
    const f=fixture(options);await f.runtime.portal(f.request(null,{origin:undefined}));
    assert.deepEqual(f.calls.portal[0],{uid:UID,emailVerified:false,authBasis:'firebase_session'});
    assert.deepEqual(f.calls.verify,[['synthetic-token',true]]);assert.deepEqual(f.calls.user,[UID]);
    assert.deepEqual(f.calls.read,[]);assert.deepEqual(f.calls.write,[]);
  });
  test('new Checkout still rejects '+name+' before Stripe or engine construction',async()=>{
    const f=fixture(options);await assert.rejects(f.runtime.checkout(f.request()));
    assert.deepEqual(f.calls.factory,[]);assert.deepEqual(f.calls.checkout,[]);assert.deepEqual(f.calls.write,[]);
  });
}
test('caller-supplied management proof cannot authorize Portal or elevate an unverified Checkout',async()=>{
  const forged={uid:UID,emailVerified:true,authBasis:'firebase_session'};
  const p=fixture();await assert.rejects(p.runtime.portal(p.request({identity:forged})));
  assert.deepEqual(p.calls.verify,[]);assert.deepEqual(p.calls.factory,[]);assert.deepEqual(p.calls.portal,[]);
  const c=fixture({token:{email_verified:false},user:{emailVerified:false}});
  await assert.rejects(c.runtime.checkout(c.request({flow:'web',action:'review',planKey:'premium_monthly',identity:forged})));
  assert.deepEqual(c.calls.factory,[]);assert.deepEqual(c.calls.checkout,[]);assert.deepEqual(c.calls.write,[]);
});
test('Portal still rejects a current Apple session whose provider subject does not match Admin',async()=>{
  const f=fixture({token:{email_verified:false,firebase:{sign_in_provider:'apple.com',identities:{'apple.com':['syntheticAppleSubject']}}},
    user:{email:undefined,emailVerified:false,providerData:[{providerId:'apple.com',uid:'syntheticDifferentSubject'}]}});
  await assert.rejects(f.runtime.portal(f.request(null,{origin:undefined})));
  assert.deepEqual(f.calls.factory,[]);assert.deepEqual(f.calls.portal,[]);assert.deepEqual(f.calls.write,[]);
});
for(const [name,options]of [['revoked',{revoked:true}],['disabled',{user:{disabled:true}}]])
  test('management-only proof never bypasses '+name+' account rejection',async()=>{
    const f=fixture(options);await assert.rejects(f.runtime.portal(f.request(null,{origin:undefined})));
    assert.deepEqual(f.calls.factory,[]);assert.deepEqual(f.calls.portal,[]);assert.deepEqual(f.calls.write,[]);
  });

test('deletion prevents a new Checkout before a Stripe client is constructed',async()=>{
  const f=fixture({documents:[[markerPath(UID),{status:'running'}]]});
  await assert.rejects(f.runtime.checkout(f.request({flow:'web',action:'create'})));
  assert.deepEqual(f.calls.factory,[]);
  assert.deepEqual(f.calls.checkout,[]);
  assert.deepEqual(f.calls.write,[]);
});
test('deletion between authentication and reservation rejects both Customer and Checkout writes',async()=>{
  const f=fixture();
  await f.runtime.checkout(f.request());
  const stores=[f.captured.customer.store,f.captured.checkout.store];
  for(const store of stores) await store.read(UID);
  f.documents.set(markerPath(UID),{status:'running'});
  for(const store of stores) {
    await assert.rejects(store.mutate(UID,()=>assert.fail('reservation after deletion')));
    await assert.rejects(store.read(UID));
  }
  assert.deepEqual(f.calls.write,[]);
});
test('another UID deletion allows normal Checkout and its own reservation',async()=>{
  const f=fixture({documents:[[markerPath('otherUser'),{status:'completed'}]]});
  await f.runtime.checkout(f.request());
  await f.captured.checkout.store.mutate(UID,()=>({state:{firebaseUid:UID},result:true}));
  assert.equal(f.calls.write.length,1);
  assert.equal(f.calls.write[0][1].firebaseUid,UID);
});

for(const [name,options]of [['missing',{omitPurchaseSwitch:true}],['false',{purchaseEnabled:false}],
  ['undefined',{purchaseEnabled:undefined}],['null',{purchaseEnabled:null}],['string true',{purchaseEnabled:'true'}],
  ['number one',{purchaseEnabled:1}]]) {
  test('closed purchase '+name+' rejects Web, legacy and empty requests before configuration/Auth/DB/Stripe',async()=>{
    const f=fixture(options);
    for(const data of [null,undefined,{}, {priceId:'price_syntheticOld500'},
      ...['review','create','status','cancel'].map(action=>({flow:'web',action,planKey:'premium_monthly'}))]) {
      const request=f.request();request.data=data;
      await assert.rejects(f.runtime.checkout(request),error=>error instanceof cfg.BillingConfigurationError);
    }
    await assert.rejects(f.runtime.checkout(undefined),error=>error instanceof cfg.BillingConfigurationError);
    assert.equal(f.calls.config,0);
    for(const name of ['factory','verify','user','read','write','checkout','portal','webhook','signature'])assert.deepEqual(f.calls[name],[],name);
  });
}
test('purchase switch closes the first request but leaves existing Portal and signed webhook wiring available',async()=>{
  const f=fixture({omitPurchaseSwitch:true});await assert.rejects(f.runtime.checkout(f.request()));assert.equal(f.calls.config,0);
  assert.deepEqual(await f.runtime.portal(f.request(null,{origin:undefined})),{ok:true,portalUrl:'https://billing.stripe.com/p/session/live_syntheticRuntime'});
  assert.deepEqual(await f.runtime.webhook(Buffer.from('{}'),'t='+NOW/1000+',v1=synthetic'),{result:'synced'});
  assert.equal(f.calls.portal.length,1);assert.equal(f.calls.webhook.length,1);assert.equal(f.calls.checkout.length,0);assert.equal(f.calls.write.length,0);
});
test('deployed purchase and webhook bindings require the exact true environment string',()=>{
  const file=path.resolve(__dirname,'../src/index.ts'),source=fs.readFileSync(file,'utf8');
  const parsed=ts.createSourceFile(file,source,ts.ScriptTarget.ES2020,true,ts.ScriptKind.TS),variables=new Map();
  for(const statement of parsed.statements)if(ts.isVariableStatement(statement))for(const d of statement.declarationList.declarations)
    if(ts.isIdentifier(d.name)&&d.initializer)variables.set(d.name.text,d.initializer.getText(parsed));
  const init=variables.get('webBilling');
  for(const value of [undefined,'false','TRUE','1',' true ','true']) {
    const env=value===undefined?{}:{HAMCARE_WEB_PURCHASE_ENABLED:value,HAMCARE_WEBHOOK_ENABLED:value},m={exports:{}};
    const compiled=ts.transpileModule('module.exports='+init+';', {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;
    vm.runInNewContext(compiled,{module:m,process:{env},db:{},admin:{auth:()=>({})},createProductionWebBillingRuntime:d=>d});
    assert.equal(m.exports.purchaseEnabled(),value==='true');assert.equal(m.exports.webhookEnabled(),value==='true');
  }
});
for(const [name,options]of [['missing',{omitWebhookSwitch:true}],['false',{webhookEnabled:false}],
  ['undefined',{webhookEnabled:undefined}],['null',{webhookEnabled:null}],['string true',{webhookEnabled:'true'}],['number one',{webhookEnabled:1}]])
  test('paused webhook '+name+' verifies signature/live but returns retryable before engine/API/DB',async()=>{
    const f=fixture(options),raw=Buffer.from('{}'),signature='t='+NOW/1000+',v1=synthetic';
    await assert.rejects(f.runtime.webhook(raw,signature),e=>e instanceof webhook.WebBillingWebhookError && e.code==='processing_paused' && e.retryable===true);
    assert.equal(f.calls.signature.length,1);assert.equal(f.calls.factory.length,1);assert.equal(f.calls.config,1);
    for(const name of ['verify','user','read','write','checkout','portal','webhook'])assert.deepEqual(f.calls[name],[],name);
    assert.equal(f.captured.webhook,undefined);assert.equal(f.captured.webhookStore,undefined);
  });
test('paused webhook rejects missing configuration, invalid signatures and Test events instead of ACKing',async()=>{
  const c=fixture({webhookEnabled:false,rawConfig:''});await assert.rejects(c.runtime.webhook(Buffer.from('{}'),'synthetic'),cfg.BillingConfigurationError);assert.deepEqual(c.calls.factory,[]);
  const f=fixture({webhookEnabled:false,badSignature:true});await assert.rejects(f.runtime.webhook(Buffer.from('{}'),'t='+NOW/1000+',v1=synthetic'),e=>e.code==='signature_invalid' && e.retryable===false);
  const t=fixture({webhookEnabled:false,event:{livemode:false}});await assert.rejects(t.runtime.webhook(Buffer.from('{}'),'t='+NOW/1000+',v1=synthetic'),e=>e.code==='live_mode_required' && e.retryable===false);
  for(const fixture of [c,f,t]) {assert.deepEqual(fixture.calls.read,[]);assert.deepEqual(fixture.calls.write,[]);assert.equal(fixture.captured.webhookStore,undefined);}
});
test('paused production HTTP handler returns503 with Retry-After; bad signatures remain400',async()=>{
  const file=path.resolve(__dirname,'../src/index.ts'),source=fs.readFileSync(file,'utf8'),parsed=ts.createSourceFile(file,source,ts.ScriptTarget.ES2020,true,ts.ScriptKind.TS);
  let init;for(const statement of parsed.statements)if(ts.isVariableStatement(statement))for(const d of statement.declarationList.declarations)
    if(ts.isIdentifier(d.name)&&d.name.text==='stripeWebhook')init=d.initializer.getText(parsed);
  assert.ok(init);
  for(const [code,retryable,status]of [['processing_paused',true,503],['signature_invalid',false,400]]) {
    const mod={exports:{}},logs=[],reply={headers:{},status(n){this.statusCode=n;return this;},set(k,v){this.headers[k]=v;return this;},json(v){this.body=v;return this;}};
    const compiled=ts.transpileModule('module.exports='+init+';', {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;
    vm.runInNewContext(compiled,{module:mod,Buffer,onRequest:(_options,handler)=>handler,LIVE_WEB_BILLING_CONFIG:{},
      webBilling:{webhook:async()=>{throw new webhook.WebBillingWebhookError(code,retryable);}},WebBillingWebhookError:webhook.WebBillingWebhookError,
      logger:{warn:(...args)=>logs.push(args)},WEB_BILLING_UNAVAILABLE:'現在お申し込みを受け付けていません。'});
    await mod.exports({method:'POST',query:{},rawBody:Buffer.from('{}'),headers:{}},reply);
    assert.equal(reply.statusCode,status);assert.equal(reply.body.ok,false);assert.equal(reply.headers['Retry-After'],code==='processing_paused'?'60':undefined);
    assert.doesNotMatch(JSON.stringify(logs),/synthetic|sk_|whsec_|cus_|uid|token/);
  }
});

test('purchase and webhook gates are independent rather than enabling each other',async()=>{
  const f=fixture({webhookEnabled:false});assert.deepEqual(await f.runtime.checkout(f.request()),{ok:true,action:'review'});
  await assert.rejects(f.runtime.webhook(Buffer.from('{}'),'t='+NOW/1000+',v1=synthetic'),e=>e.code==='processing_paused');
  assert.equal(f.calls.checkout.length,1);assert.equal(f.calls.webhook.length,0);assert.deepEqual(f.calls.write,[]);
});
