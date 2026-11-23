import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {billingContactEnvironment,resolveBillingContactEnvironment,BILLING_CONTACT_LIVE_ORIGIN,
  BILLING_CONTACT_PREVIEW_ORIGIN,BILLING_CONTACT_LIVE_ENDPOINT,BILLING_CONTACT_ENDPOINT,
  BILLING_CONTACT_PLAN_RETURN} from '../public/assets/billing-contact-environment.mjs';
import {createBillingContactService} from '../public/assets/billing-contact-service.mjs';
import {projectBillingContact} from '../public/assets/billing-contact-model.mjs';
const state=()=>({testMode:false,state:'missing',category:'missing',maskedEmail:null,pendingMaskedEmail:null,
  canCheckout:false,source:null,resendAfter:null,expiresAt:null,deliveryState:null});
function fixture(fetcher=async()=>({ok:true,status:200,json:async()=>state()})) {
  const uid='synthetic-live',subject='synthetic-apple',calls=[];
  const user={uid,email:null,emailVerified:false,providerData:[{providerId:'apple.com',uid:subject}],
    async getIdTokenResult(){return {token:'synthetic-token',signInProvider:'apple.com',claims:{aud:'synthetic',iss:'https://securetoken.google.com/synthetic',sub:uid,user_id:uid,email_verified:false,firebase:{sign_in_provider:'apple.com',identities:{'apple.com':[subject]}}}};}};
  const auth={currentUser:user,app:{options:{projectId:'synthetic'}}};
  const service=createBillingContactService({auth,environment:'live',origin:BILLING_CONTACT_LIVE_ORIGIN,
    fetchRequest:async(url,options)=>{calls.push({url,options});return fetcher(url,options);}});
  return {auth,service,calls};
}
test('each deployment resolves only its exact origin and fixed endpoint',()=>{
  assert.equal(resolveBillingContactEnvironment(BILLING_CONTACT_LIVE_ORIGIN).endpoint,BILLING_CONTACT_LIVE_ENDPOINT);
  assert.equal(resolveBillingContactEnvironment(BILLING_CONTACT_PREVIEW_ORIGIN).endpoint,BILLING_CONTACT_ENDPOINT);
  assert.equal(resolveBillingContactEnvironment(BILLING_CONTACT_LIVE_ORIGIN).appName,'hamcare-web-live');
  assert.ok(Object.isFrozen(billingContactEnvironment('live')));
  for(const value of ['http://hamster-breeding-app.web.app',BILLING_CONTACT_LIVE_ORIGIN+'/',BILLING_CONTACT_LIVE_ORIGIN+'.evil.test','http://localhost:18731',undefined])assert.throws(()=>resolveBillingContactEnvironment(value));
});
test('live service posts only to live endpoint and expects live projection',async()=>{
  const h=fixture();assert.deepEqual(await h.service.getStatus(),state());
  assert.equal(h.service.environment,'live');assert.equal(h.calls[0].url,BILLING_CONTACT_LIVE_ENDPOINT+'/status');
  assert.equal(h.calls[0].options.credentials,'omit');assert.equal(h.calls[0].options.referrerPolicy,'no-referrer');
  assert.deepEqual(JSON.parse(h.calls[0].options.body),{});
  assert.throws(()=>createBillingContactService({auth:h.auth,environment:'live',endpoint:BILLING_CONTACT_ENDPOINT}));
  assert.throws(()=>createBillingContactService({auth:h.auth,environment:'preview',origin:BILLING_CONTACT_LIVE_ORIGIN}));
});
test('cross-environment response cannot become a verified production contact',async()=>{
  const raw={...state(),testMode:true,state:'verified',category:'missing',maskedEmail:'sy***@example.test',canCheckout:true,source:'user_supplied'};
  assert.throws(()=>projectBillingContact(raw,{environment:'live'}));
  const h=fixture(async()=>({ok:true,status:200,json:async()=>raw}));
  await assert.rejects(h.service.getStatus(),e=>e.code==='contact_invalid_response');
  assert.equal(h.calls.length,1);
});
test('missing Live configuration never falls back or retries against Preview',async()=>{
  const h=fixture(async()=>({ok:false,status:503,json:async()=>({code:'contact_service_unavailable'})}));
  await assert.rejects(h.service.getStatus(),e=>e.code==='contact_service_unavailable');
  assert.equal(h.calls.length,1);assert.ok(h.calls.every(c=>c.url.startsWith(BILLING_CONTACT_LIVE_ENDPOINT)));
});
test('live request and confirmation send only email or proof in POST body',async()=>{
  const h=fixture();await h.service.requestVerification('Synthetic@PRIVATE.ICLOUD.COM');await h.service.confirmVerification('a'.repeat(43));
  assert.deepEqual(JSON.parse(h.calls[0].options.body),{email:'Synthetic@private.icloud.com'});
  assert.deepEqual(JSON.parse(h.calls[1].options.body),{token:'a'.repeat(43)});
  for(const call of h.calls)assert.doesNotMatch(call.url,/Synthetic|synthetic-live|aaaaa/);
});
test('allowed return is fixed to HamCare plan view, without query-selected destinations',async()=>{
  assert.equal(BILLING_CONTACT_PLAN_RETURN,'/account/?contact=verified&view=plan');
  const [entry,view,account]=await Promise.all(['billing-contact.mjs','billing-contact-view.mjs','account.mjs'].map(name=>readFile(new URL('../public/assets/'+name,import.meta.url),'utf8')));
  assert.ok(entry.indexOf('consumeVerificationFragment(location, history)')<entry.indexOf("import('https://"));
  assert.match(view,/setAttribute\('href',BILLING_CONTACT_PLAN_RETURN\)/);
  assert.doesNotMatch(entry+view,/get\(['"](?:return|redirect|continue|next)['"]\)|localStorage|sessionStorage|console\./);
  assert.match(account,/deployment\.testMode \? createPreviewCheckoutService/);
  assert.match(account,/\}\}\) : createLiveCheckoutService/);
  assert.doesNotMatch(account,/resumeCheckout:deployment\.testMode/);
});
