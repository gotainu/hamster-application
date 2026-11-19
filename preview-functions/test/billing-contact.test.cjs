'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {createHash} = require('node:crypto');
const {createBillingContactEngine, classifyBillingEmail, normalizeBillingEmail, BILLING_CONTACT_FROM, BILLING_CONTACT_NAMESPACE, BILLING_CONTACT_TTL_MS} = require('../lib/preview-functions/src/billing-contact');
const PROJECT_UID = 'synthetic-contact-owner';
const clone = value => structuredClone(value);
function owner(email, verified = false, provider = 'apple.com', uid = PROJECT_UID) {
  return {
    identity:{uid,emailVerified:verified,authBasis:provider === 'apple.com' ? 'apple_provider' : 'verified_email',...(verified && email ? {email} : {})},
    adminUser:{uid,disabled:false,emailVerified:verified,providerData:[{providerId:provider,uid:'synthetic-provider'}],...(email !== undefined ? {email} : {})},
    appAccountExists:true,
  };
}
function fixture(options = {}) {
  const state = new Map(); let clock = Date.parse('2026-11-19T03:00:00Z'), n = 0, writes = 0;
  const sent = []; let queue = Promise.resolve();
  const store = {
    async read(uid) {return clone(state.get(uid) || {});},
    async mutate(uid, fn) {
      let unlock; const current = queue; queue = new Promise(resolve => {unlock=resolve;});
      await current;
      try {const value=fn(clone(state.get(uid)||{}));state.set(uid,clone(value.state));writes++;return value.result;}
      finally {unlock();}
    },
  };
  const sendMail = options.sendMail || (async message => {sent.push(message);});
  const engine = createBillingContactEngine({store,sendMail:options.unconfigured ? undefined : sendMail,now:()=>new Date(clock),randomToken:()=>Buffer.alloc(32,++n).toString('base64url')});
  return {engine,state,sent,store,now:()=>clock,advance:ms=>{clock+=ms;},writes:()=>writes};
}
const token = message => new URLSearchParams(new URL(message.verificationUrl).hash.slice(1)).get('token');
const rejects = (promise, code) => assert.rejects(promise, e => e.code === code && e.message === code);

test('normal verified Auth addresses are category A without contact writes', async () => {
  for (const provider of ['password','google.com','apple.com']) {
    const f=fixture(), c=owner('synthetic@example.test',true,provider);
    assert.equal(classifyBillingEmail(c.identity,c.adminUser).kind,'A');
    const status=await f.engine.status(c);assert.equal(status.verified,true);assert.equal(status.canCheckout,true);assert.equal(status.maskedEmail,'sy***@example.test');
    assert.deepEqual(await f.engine.requireVerified(c),{email:'synthetic@example.test',source:'auth_verified'});
    await rejects(f.engine.request(c,'different@example.test'),'contact_not_required');assert.equal(f.writes(),0);assert.equal(f.sent.length,0);
  }
});
for (const domain of ['privaterelay.appleid.com','private.icloud.com']) test('verified current Apple '+domain+' is B but syntax alone is not proof', async () => {
  const f=fixture(), verified=owner('synthetic@'+domain,true), unverified=owner('synthetic@'+domain,false);
  assert.equal(classifyBillingEmail(verified.identity,verified.adminUser).kind,'B');assert.equal((await f.engine.status(verified)).verified,true);
  assert.equal(classifyBillingEmail(unverified.identity,unverified.adminUser).kind,'unverified');assert.equal((await f.engine.status(unverified)).canCheckout,false);
  await rejects(f.engine.requireVerified(unverified),'contact_auth_email_unverified');assert.equal(f.writes(),0);
});
test('truly absent current Apple email is C; provider-only existing email is unverified', async () => {
  const c=owner(undefined);assert.equal(classifyBillingEmail(c.identity,c.adminUser).kind,'C');
  const f=fixture();const s=await f.engine.status(c);assert.equal(s.verificationStatus,'missing');assert.equal(s.maskedEmail,null);assert.equal(s.canCheckout,false);assert.equal(f.writes(),0);
  c.adminUser.providerData[0].email='synthetic@private.icloud.com';assert.equal(classifyBillingEmail(c.identity,c.adminUser).kind,'unverified');
  await rejects(f.engine.request(c,'synthetic@example.test'),'contact_auth_email_unverified');
});
test('malformed or unverified Auth emails do not become C', () => {
  for(const email of [' ','broken','synthetic@','synthetic@x','x\r\n@example.test',123]) {const c=owner(email);assert.equal(classifyBillingEmail(c.identity,c.adminUser).kind,'invalid');}
  const c=owner('synthetic@example.test');assert.equal(classifyBillingEmail(c.identity,c.adminUser).kind,'unverified');
});
test('email syntax trims outer whitespace, preserves local case and accepts both relay domains', () => {
  for(const email of ['synthetic@example.test','synthetic@privaterelay.appleid.com','synthetic@private.icloud.com']) assert.equal(normalizeBillingEmail(' '+email+' '),email);
  assert.equal(normalizeBillingEmail('Owner@Example.TEST'),'Owner@example.test');
  for(const v of ['',null,[],{},'a..b@example.test','.x@example.test','x.@example.test','x@-bad.test','x@example..test','x@example.test\r\nBcc:other@example.test','x y@example.test'])assert.equal(normalizeBillingEmail(v),null);
});
test('wrong, disabled, empty and malformed identities fail before reads, writes or mail', async () => {
  const mutations=[c=>{c.identity.uid='';},c=>{c.adminUser.uid='another-owner';},c=>{c.adminUser.disabled=true;},c=>{c.adminUser.providerData=[];},c=>{c.identity.authBasis='client_claim';},c=>{c.appAccountExists=false;}];
  for(const mutate of mutations){const f=fixture(),c=owner(undefined);mutate(c);await assert.rejects(f.engine.request(c,'synthetic@example.test'));assert.equal(f.writes(),0);assert.equal(f.sent.length,0);}
});
test('server-only Preview namespace and sender are exact',()=>{assert.equal(BILLING_CONTACT_NAMESPACE,'preview_billing_contacts');assert.equal(BILLING_CONTACT_FROM,'gotainu@gmail.com');});
test('unconfigured sender fails closed before state or mail',async()=>{const f=fixture({unconfigured:true});await rejects(f.engine.request(owner(undefined),'synthetic@example.test'),'mail_unavailable');assert.equal(f.writes(),0);});
test('send success returns masked pending only and saves hash bound to UID and email', async () => {
  const f=fixture(),c=owner(undefined),before=clone(c);const view=await f.engine.request(c,' synthetic@example.test ');
  assert.equal(view.verified,false);assert.equal(view.canCheckout,false);assert.equal(view.verificationStatus,'pending');assert.equal(view.pendingMaskedEmail,'sy***@example.test');
  assert.equal(view.verificationSentAt,f.now());assert.equal(view.resendAfter,new Date(f.now()+60000).toISOString());assert.equal(f.sent.length,1);
  const m=f.sent[0],t=token(m);assert.equal(t.length,43);assert.equal(m.from,BILLING_CONTACT_FROM);assert.equal(m.to,'synthetic@example.test');
  const link=new URL(m.verificationUrl);assert.equal(link.pathname,'/account/contact/');assert.equal(link.search,'');assert.doesNotMatch(m.verificationUrl,/@|synthetic-contact-owner|uid=|email=/);
  const saved=f.state.get(PROJECT_UID);assert.equal(saved.pending.tokenHash,createHash('sha256').update(PROJECT_UID+'\0synthetic@example.test\0'+t).digest('hex'));
  assert.doesNotMatch(JSON.stringify(saved),new RegExp(t));assert.equal(saved.purpose,'billing_contact_preview');assert.equal(saved.pending.sentAt,f.now());assert.equal(saved.pending.expiresAt,f.now()+BILLING_CONTACT_TTL_MS);assert.deepEqual(c,before);
  assert.doesNotMatch(JSON.stringify(view),/synthetic@example|synthetic-contact-owner|tokenHash|provider/);
  await rejects(f.engine.requireVerified(c),'contact_verification_required');
});
test('valid confirmation verifies only current own document and unlocks checkout', async () => {
  const f=fixture(),c=owner(undefined);await f.engine.request(c,'synthetic@example.test');const t=token(f.sent[0]);f.advance(1000);
  const result=await f.engine.confirm(c,t);assert.equal(result.verificationStatus,'verified');assert.equal(result.canCheckout,true);assert.equal(result.pendingMaskedEmail,null);
  assert.deepEqual(await f.engine.requireVerified(c),{email:'synthetic@example.test',source:'user_supplied'});assert.equal(f.state.size,1);assert.equal(f.state.get(PROJECT_UID).verifiedAt,f.now());assert.equal(f.state.get(PROJECT_UID).pending,undefined);
});
test('used token is rejected without advancing verification or writes', async () => {
  const f=fixture(),c=owner(undefined);await f.engine.request(c,'synthetic@example.test');const t=token(f.sent[0]);await f.engine.confirm(c,t);const count=f.writes(),snapshot=clone(f.state.get(PROJECT_UID));
  await rejects(f.engine.confirm(c,t),'contact_token_used');assert.equal(f.writes(),count);assert.deepEqual(f.state.get(PROJECT_UID),snapshot);
});
test('expired tokens fail without verifying', async () => {
  const f=fixture(),c=owner(undefined);await f.engine.request(c,'synthetic@example.test');f.advance(BILLING_CONTACT_TTL_MS);
  await rejects(f.engine.confirm(c,token(f.sent[0])),'contact_token_expired');assert.equal((await f.engine.status(c)).verificationStatus,'expired');assert.equal(f.state.get(PROJECT_UID).verified,false);
});
test('tampering, arbitrary malformed token, wrong UID and changed pending email cannot confirm', async () => {
  const f=fixture(),c=owner(undefined);await f.engine.request(c,'synthetic@example.test');const t=token(f.sent[0]);
  for(const altered of ['',null,123,t.slice(0,42),t.slice(0,42)+(t.endsWith('A')?'B':'A')])await rejects(f.engine.confirm(c,altered),'contact_token_invalid');
  const other=owner(undefined,false,'apple.com','synthetic-other-owner');await rejects(f.engine.confirm(other,t),'contact_token_invalid');assert.equal(f.state.has(other.identity.uid),false);
  f.state.get(PROJECT_UID).pending.email='different@example.test';await rejects(f.engine.confirm(c,t),'contact_token_invalid');assert.equal((await f.engine.status(c)).verified,false);
});
test('simultaneous send clicks result in one delivery and one rate rejection', async () => {
  const f=fixture(),c=owner(undefined);const results=await Promise.allSettled([f.engine.request(c,'synthetic@example.test'),f.engine.request(c,'synthetic@example.test')]);
  assert.equal(results.filter(x=>x.status==='fulfilled').length,1);assert.equal(f.sent.length,1);assert.equal(f.state.get(PROJECT_UID).requestedAt.length,1);assert.equal(results.find(x=>x.status==='rejected').reason.code,'contact_rate_limited');
});
test('resend invalidates old token and observes 60 second cooldown', async () => {
  const f=fixture(),c=owner(undefined);await f.engine.request(c,'synthetic@example.test');const old=token(f.sent[0]);
  f.advance(59999);await rejects(f.engine.request(c,'synthetic@example.test'),'contact_rate_limited');f.advance(1);await f.engine.request(c,'synthetic@example.test');
  assert.equal(f.sent.length,2);await rejects(f.engine.confirm(c,old),'contact_token_invalid');await f.engine.confirm(c,token(f.sent[1]));assert.equal((await f.engine.status(c)).verified,true);
});
test('hour and day limits count attempts independently from confirmation', async () => {
  const f=fixture(),c=owner(undefined);for(let i=0;i<3;i++){await f.engine.request(c,'synthetic@example.test');f.advance(60000);}await rejects(f.engine.request(c,'synthetic@example.test'),'contact_rate_limited');
  f.advance(3600001);for(let i=0;i<2;i++){await f.engine.request(c,'synthetic@example.test');f.advance(60000);}await rejects(f.engine.request(c,'synthetic@example.test'),'contact_rate_limited');assert.equal(f.sent.length,5);
  f.advance(86400001);await f.engine.request(c,'synthetic@example.test');assert.equal(f.sent.length,6);
});
test('definite sender failure is not recorded sent and can be retried only after cooldown', async () => {
  let attempt=0;const f=fixture({sendMail:async()=>{attempt++;throw {delivery:'not_sent'};}}),c=owner(undefined);
  await rejects(f.engine.request(c,'synthetic@example.test'),'contact_delivery_failed');const s=await f.engine.status(c);assert.equal(s.verificationStatus,'delivery_failed');assert.equal(s.verificationSentAt,null);assert.equal(s.verified,false);
  await rejects(f.engine.request(c,'synthetic@example.test'),'contact_rate_limited');f.advance(60000);await rejects(f.engine.request(c,'synthetic@example.test'),'contact_delivery_failed');assert.equal(attempt,2);
});
test('unknown send outcome holds token until expiry and never automatically redelivers', async () => {
  let attempted;const f=fixture({sendMail:async m=>{attempted=m;throw new Error('synthetic mail SDK payload must not leak');}}),c=owner(undefined);
  await rejects(f.engine.request(c,'synthetic@example.test'),'contact_delivery_uncertain');assert.equal((await f.engine.status(c)).verificationStatus,'delivery_uncertain');
  f.advance(60000);await rejects(f.engine.request(c,'synthetic@example.test'),'contact_delivery_pending');assert.equal(f.state.get(PROJECT_UID).requestedAt.length,1);
  // If it actually arrived, possession of the correct own token may complete verification.
  await f.engine.confirm(c,token(attempted));assert.equal((await f.engine.status(c)).verified,true);
});
for(const domain of ['privaterelay.appleid.com','private.icloud.com'])test('entered '+domain+' still needs link verification',async()=>{
  const f=fixture(),c=owner(undefined);await f.engine.request(c,'synthetic@'+domain);assert.equal((await f.engine.status(c)).canCheckout,false);await f.engine.confirm(c,token(f.sent[0]));assert.equal((await f.engine.status(c)).canCheckout,true);
});
test('pending change preserves old verified contact until the new own link is confirmed', async () => {
  const f=fixture(),c=owner(undefined);await f.engine.request(c,'old@example.test');await f.engine.confirm(c,token(f.sent[0]));const oldVerified=f.state.get(PROJECT_UID).verifiedAt;f.advance(60000);
  const pending=await f.engine.request(c,'new@example.test');assert.equal(pending.canCheckout,true);assert.equal(pending.maskedEmail,'ol***@example.test');assert.equal(pending.pendingMaskedEmail,'ne***@example.test');
  assert.deepEqual(await f.engine.requireVerified(c),{email:'old@example.test',source:'user_supplied'});assert.equal(f.state.get(PROJECT_UID).verifiedAt,oldVerified);
  await f.engine.confirm(c,token(f.sent[1]));assert.deepEqual(await f.engine.requireVerified(c),{email:'new@example.test',source:'user_supplied'});assert.equal(c.identity.email,undefined);assert.equal(c.adminUser.email,undefined);
});
test('failed new email delivery does not discard an existing verified contact',async()=>{
  let fail=false;const sent=[];const f=fixture({sendMail:async m=>{sent.push(m);if(fail)throw {delivery:'not_sent'};}}),c=owner(undefined);
  await f.engine.request(c,'old@example.test');await f.engine.confirm(c,token(sent[0]));fail=true;f.advance(60000);
  await rejects(f.engine.request(c,'new@example.test'),'contact_delivery_failed');assert.equal((await f.engine.status(c)).canCheckout,true);assert.equal((await f.engine.requireVerified(c)).email,'old@example.test');
});
test('same verified contact is idempotent without another mail or changed ownership',async()=>{
  const f=fixture(),c=owner(undefined);await f.engine.request(c,'synthetic@example.test');await f.engine.confirm(c,token(f.sent[0]));const snapshot=clone(c);await f.engine.request(c,'synthetic@example.test');assert.equal(f.sent.length,1);assert.deepEqual(c,snapshot);
});
test('contact records cannot supply identity or substitute a different owner',async()=>{
  const f=fixture(),c=owner(undefined);await f.engine.request(c,'synthetic@example.test');await f.engine.confirm(c,token(f.sent[0]));
  const other=owner(undefined,false,'apple.com','synthetic-other-owner');await rejects(f.engine.requireVerified(other),'contact_verification_required');assert.equal(f.state.size,1);
});
test('client-corrupt persisted state fails closed and does not send',async()=>{
  const f=fixture(),c=owner(undefined);f.state.set(PROJECT_UID,{verified:true,email:'synthetic@example.test',verifiedAt:1,source:'client_claim'});
  await rejects(f.engine.status(c),'contact_state_invalid');await rejects(f.engine.request(c,'new@example.test'),'contact_state_invalid');assert.equal(f.sent.length,0);
});
