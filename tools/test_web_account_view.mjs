import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { mountAccountPage } from '../public/assets/account-view.mjs';
import { safeAuthError } from '../public/assets/account-model.mjs';
import { projectPlanReview } from '../public/assets/plan-model.mjs';
const html = await readFile(new URL('../public/account/index.html', import.meta.url), 'utf8');
class Element {
  constructor(id) { this.id=id;this.hidden=false;this.disabled=false;this.value='';this.type=id==='password'?'password':'text';this.textContent='';this.attrs={};this.listeners=new Map();this.validity={valid:true}; }
  addEventListener(name,fn){this.listeners.set(name,fn);}
  removeEventListener(name){this.listeners.delete(name);}
  setAttribute(key,val){this.attrs[key]=val;}
  removeAttribute(key){delete this.attrs[key];}
  focus(){globalThis.focused=this.id;}
  replaceChildren(){this.textContent='';}
  dispatch(name,event={}){return this.listeners.get(name)?.(event);}
}
function deferred(){let resolve,reject;const promise=new Promise((yes,no)=>{resolve=yes;reject=no;});return{promise,resolve,reject};}
const flush=()=>new Promise(resolve=>setImmediate(resolve));
async function setup({checkoutService=null,contactService=null,search='',pathname='/account/',appleSignInEnabled=false}={}) {
  const nodes = new Map([...html.matchAll(/id="([^"]+)"/g)].map(x=>[x[1],new Element(x[1])]));
  nodes.get('premium-monthly').value='premium_monthly';
  nodes.get('premium-monthly').checked=false;
  nodes.get('plan-checkout').disabled=true;
  const windowListeners=new Map();
  globalThis.document={getElementById:id=>nodes.get(id)};
  const navigation=[],replaced=[];
  globalThis.window={location:{pathname,search,assign:url=>navigation.push(url)},history:{replaceState:(...args)=>replaced.push(args)},addEventListener:(name,fn)=>windowListeners.set(name,fn),removeEventListener:name=>windowListeners.delete(name)};
  let callback;
  const calls={reads:0,email:0,google:0,apple:0,signOut:0,reload:0};
  const user={emailVerified:true,identityVerified:true,authenticationBasis:'verified_email',maskedEmail:'sa***@example.invalid',methods:['メール/パスワード'],isNewUser:false};
  const summary={appAccountExists:true,nickname:'本人ニックネーム',maskedEmail:user.maskedEmail,methods:user.methods,billingLabel:'未契約',trialLabel:'サーバー保存状態：active',unavailableFields:[],planReview:projectPlanReview({kind:'missing'})};
  const service={appleSignInEnabled,signInApple:async options=>{assert.deepEqual(options,{linkingConsent:true});calls.apple++;callback({...user,methods:['Apple']});},ready:async()=>{},onAuthChanged:cb=>{callback=cb;cb(null);return()=>{};},readAccountSummary:async()=>{calls.reads++;return summary;},signInEmail:async()=>{calls.email++;callback(user);},signInGoogle:async()=>{calls.google++;callback(user);},signOut:async()=>{calls.signOut++;callback(null);},reloadUser:async()=>{calls.reload++;callback(user);},safeError:()=> '通信に失敗しました。'};
  const cleanup=await mountAccountPage(service,{checkoutService,contactService});
  return {el:id=>nodes.get(id),service,calls,user,summary,emit:u=>callback(u),cleanup,windowListeners,navigation,replaced,nodes};
}
test('initial login and empty form guard',async()=>{
 const h=await setup();assert.equal(h.el('login-panel').hidden,false);let stopped=false;
 h.el('email-form').dispatch('submit',{preventDefault:()=>{stopped=true;}});assert.equal(stopped,true);assert.equal(h.calls.email,0);assert.equal(h.el('auth-error').hidden,false);h.cleanup();
});
test('email signin trims address, blocks duplicate and clears password on error',async()=>{
 const h=await setup();const d=deferred();let address;h.service.signInEmail=(email)=>{address=email;h.calls.email++;return d.promise;};
 h.el('email').value=' sample@example.invalid ';h.el('password').value='not-a-real-password';
 h.el('email-form').dispatch('submit',{preventDefault(){}});h.emit(null);h.el('email-form').dispatch('submit',{preventDefault(){}});
 assert.equal(h.calls.email,1);assert.equal(address,'sample@example.invalid');d.reject(new Error('internal-sensitive-error'));await flush();assert.equal(h.el('password').value,'');assert.equal(h.el('auth-error').textContent,'通信に失敗しました。');h.cleanup();
});
test('password visibility is labelled and cleared after signin',async()=>{
 const h=await setup();h.el('password').value='example';h.el('toggle-password').dispatch('click');assert.equal(h.el('password').type,'text');assert.equal(h.el('toggle-password').attrs['aria-pressed'],'true');h.emit(null);await flush();assert.equal(h.el('password').value,'');assert.equal(h.el('password').type,'password');h.cleanup();
});
test('unverified user cannot read account or enter plan state',async()=>{
 const h=await setup();h.emit({...h.user,emailVerified:false,identityVerified:false,authenticationBasis:null});await flush();assert.equal(h.calls.reads,0);assert.equal(h.el('verification-panel').hidden,false);h.el('review-plan').dispatch('click');assert.equal(h.el('plan-panel').hidden,true);h.cleanup();
});
test('verified owner summary and read-only plan confirmation',async()=>{
 const h=await setup();h.emit(h.user);await flush();assert.equal(h.el('account-panel').hidden,false);assert.equal(h.el('account-nickname').textContent,'本人ニックネーム');assert.equal(h.el('account-email').textContent,h.user.maskedEmail);h.el('review-plan').dispatch('click');await flush();assert.equal(h.el('plan-panel').hidden,false);h.el('back-to-account').dispatch('click');assert.equal(h.el('account-panel').hidden,false);h.cleanup();
});
test('missing nickname and denied fields are explicit, not entitlement inference',async()=>{
 const h=await setup();h.summary.nickname='';h.summary.billingLabel='';h.summary.unavailableFields=['契約状態'];h.emit(h.user);await flush();assert.equal(h.el('account-nickname').textContent,'未設定');assert.equal(h.el('account-billing').textContent,'確認できませんでした');assert.match(h.el('unavailable-fields').textContent,/利用可能・未契約とは判定していません/);h.cleanup();
});
test('new Google account warning and plan button are guarded',async()=>{
 const h=await setup();h.emit({...h.user,isNewUser:true});await flush();assert.equal(h.el('new-google-note').hidden,false);assert.equal(h.el('review-plan').disabled,true);h.el('review-plan').dispatch('click');assert.equal(h.el('plan-panel').hidden,true);h.cleanup();
});
test('A response cannot replace B response after auth switch',async()=>{
 const h=await setup();const a=deferred(),b=deferred();let i=0;h.service.readAccountSummary=()=>++i===1?a.promise:b.promise;h.emit({...h.user,maskedEmail:'a***@example.invalid'});h.emit({...h.user,maskedEmail:'b***@example.invalid'});a.resolve({...h.summary,nickname:'A'});await flush();assert.equal(h.el('account-nickname').textContent,'');b.resolve({...h.summary,nickname:'B'});await flush();assert.equal(h.el('account-nickname').textContent,'B');h.cleanup();
});
test('logout immediately hides personal data and rejects stale read',async()=>{
 const h=await setup();const d=deferred();h.service.readAccountSummary=()=>d.promise;h.emit(h.user);await h.el('logout').dispatch('click');d.resolve(h.summary);await flush();assert.equal(h.calls.signOut,1);assert.equal(h.el('account-nickname').textContent,'');assert.equal(h.el('account-email').textContent,'');assert.equal(h.el('login-panel').hidden,false);h.cleanup();
});
test('bfcache hides personal data and reloads authentication',async()=>{
 const h=await setup();h.emit(h.user);await flush();h.windowListeners.get('pagehide')();assert.equal(h.el('account-nickname').textContent,'');assert.equal(h.el('account-panel').hidden,true);await h.windowListeners.get('pageshow')({persisted:true});await flush();assert.equal(h.calls.reload,1);assert.equal(h.el('account-panel').hidden,false);h.cleanup();
});
test('verification refresh requests actual service state',async()=>{
 const h=await setup();h.emit({...h.user,emailVerified:false,identityVerified:false,authenticationBasis:null});await flush();await h.el('check-verification').dispatch('click');await flush();assert.equal(h.calls.reload,1);assert.equal(h.el('account-panel').hidden,false);h.cleanup();
});
test('UI contract avoids credential-bearing native navigation',()=>{
 assert.match(html,/<form[^>]+method="post"/);assert.doesNotMatch(html,/<input[^>]+name=/);assert.match(html,/<fieldset id="email-fields" disabled>/);assert.doesNotMatch(html,/type="(?:number|tel)"|card-number|createUserWithEmailAndPassword|console\./i);
});

test('plan entry re-reads same account, selection changes only local summary',async()=>{
 const h=await setup();h.emit(h.user);await flush();assert.equal(h.calls.reads,1);
 h.el('review-plan').dispatch('click');await flush();assert.equal(h.calls.reads,2);assert.equal(h.el('main').attrs['data-page'],'plan');assert.equal(h.el('plan-nickname').textContent,h.summary.nickname);assert.equal(h.el('plan-email').textContent,h.user.maskedEmail);assert.equal(h.el('plan-fields').disabled,false);assert.equal(h.el('premium-monthly').checked,false);
 h.el('premium-monthly').checked=true;h.el('premium-monthly').dispatch('change');assert.equal(h.el('plan-selected-name').textContent,'HamCare プレミアム');assert.match(h.el('plan-selected-amount').textContent,/550円.*500円/);assert.equal(h.el('plan-checkout').disabled,true);assert.equal(h.calls.reads,2);assert.match(h.el('plan-selection-status').textContent,/申し込みは行われていません/);h.cleanup();
});
test('active and cancellation-scheduled contracts direct to management without selection',async()=>{
 for (const cancelAtPeriodEnd of [false,true]) {
  const h=await setup();h.summary.planReview=projectPlanReview({kind:'found',data:{plan:'paid',status:'active',cancelAtPeriodEnd}});h.emit(h.user);await flush();h.el('review-plan').dispatch('click');await flush();assert.equal(h.el('plan-fields').disabled,true);assert.equal(h.el('plan-management').hidden,false);h.el('premium-monthly').checked=true;h.el('premium-monthly').dispatch('change');assert.equal(h.el('premium-monthly').checked,false);assert.doesNotMatch(h.el('plan-selected-amount').textContent,/550/);assert.equal(h.el('plan-checkout').disabled,true);h.cleanup();
 }
});
test('unknown or unreadable billing blocks local plan selection without assuming no subscription',async()=>{
 for (const item of [{kind:'denied'},{kind:'unavailable'},{kind:'found',data:{status:'past_due',plan:'none'}},undefined]) {
  const h=await setup();h.summary.planReview=item?projectPlanReview(item):undefined;h.emit(h.user);await flush();h.el('review-plan').dispatch('click');await flush();assert.equal(h.el('plan-panel').hidden,false);assert.equal(h.el('plan-fields').disabled,true);assert.match(h.el('plan-route-detail').textContent,/確認/);assert.equal(h.el('plan-checkout').disabled,true);h.cleanup();
 }
});
test('plan entry double click performs only one fresh read',async()=>{
 const h=await setup();h.emit(h.user);await flush();const d=deferred();h.service.readAccountSummary=()=>{h.calls.reads++;return d.promise;};h.el('review-plan').dispatch('click');h.el('review-plan').dispatch('click');assert.equal(h.calls.reads,2);assert.equal(h.el('plan-panel').hidden,true);d.resolve(h.summary);await flush();assert.equal(h.el('plan-panel').hidden,false);h.cleanup();
});
test('failed fresh read never reveals a stale plan confirmation',async()=>{
 const h=await setup();h.emit(h.user);await flush();h.service.readAccountSummary=async()=>{throw new Error('private details');};h.el('review-plan').dispatch('click');await flush();assert.equal(h.el('plan-panel').hidden,true);assert.equal(h.el('plan-email').textContent,'');assert.equal(h.el('loading-panel').hidden,false);assert.equal(h.el('auth-error').textContent,'通信に失敗しました。');h.cleanup();
});
test('logout clears plan identity, billing and selected plan immediately',async()=>{
 const h=await setup();h.emit(h.user);await flush();h.el('review-plan').dispatch('click');await flush();h.el('premium-monthly').checked=true;h.el('premium-monthly').dispatch('change');await h.el('logout').dispatch('click');assert.equal(h.el('plan-panel').hidden,true);assert.equal(h.el('plan-email').textContent,'');assert.equal(h.el('plan-billing').textContent,'');assert.equal(h.el('plan-customer-check').textContent,'');assert.equal(h.el('premium-monthly').checked,false);assert.equal(h.el('plan-checkout').disabled,true);h.cleanup();
});
test('stale plan read from A cannot reveal A after switching to B',async()=>{
 const h=await setup();h.emit(h.user);await flush();const d=deferred();h.service.readAccountSummary=()=>d.promise;h.el('review-plan').dispatch('click');h.service.readAccountSummary=async()=>({...h.summary,nickname:'Bさん',maskedEmail:'b***@example.invalid'});h.emit({...h.user,maskedEmail:'b***@example.invalid'});await flush();d.resolve({...h.summary,nickname:'Aさん'});await flush();assert.equal(h.el('plan-panel').hidden,true);assert.equal(h.el('plan-nickname').textContent,'');assert.equal(h.el('account-nickname').textContent,'Bさん');h.cleanup();
});
test('page hide clears selected plan and personal content; page restore returns to authenticated account',async()=>{
 const h=await setup();h.emit(h.user);await flush();h.el('review-plan').dispatch('click');await flush();h.el('premium-monthly').checked=true;h.el('premium-monthly').dispatch('change');h.windowListeners.get('pagehide')();assert.equal(h.el('plan-panel').hidden,true);assert.equal(h.el('plan-email').textContent,'');assert.equal(h.el('premium-monthly').checked,false);await h.windowListeners.get('pageshow')({persisted:true});await flush();assert.equal(h.el('account-panel').hidden,false);h.cleanup();
});
test('arbitrary client plan keys are never accepted or sent',async()=>{
 const h=await setup();h.emit(h.user);await flush();h.el('review-plan').dispatch('click');await flush();h.el('premium-monthly').value='price_client_override';h.el('premium-monthly').checked=true;h.el('premium-monthly').dispatch('change');assert.equal(h.el('premium-monthly').checked,false);assert.equal(h.el('plan-selected-name').textContent,'未選択');assert.equal(h.el('plan-checkout').disabled,true);h.cleanup();
});
test('plan HTML includes account, all contract terms, legal links and no purchase form',()=>{
 for (const text of ['請求周期','自動更新','サービス開始時期','次回請求','解約方法','解約期限','返金','税抜500円','550','特定商取引法に基づく表記','本番公開前','月額500円（税込）']) assert.ok(html.includes(text),text);
 assert.match(html,/<button[^>]+id="plan-checkout"[^>]+disabled>/);assert.match(html,/<input[^>]+id="premium-monthly"[^>]+value="premium_monthly"/);assert.equal([...html.matchAll(/<form\b/g)].length,1);assert.doesNotMatch(html,/<iframe|card-number|price_[A-Za-z0-9]+/);
});


function previewBilling(status='active') {
  return {testMode:true,syncState:'synced',billing:{planKey:'premium_monthly',amount:550,currency:'jpy',interval:'month',status,currentPeriodStart:'2026-11-14T09:00:00.000Z',currentPeriodEnd:'2026-12-14T09:00:00.000Z',trialEnd:null,firstChargeAt:'2026-11-14T09:00:00.000Z',nextChargeAt:'2026-12-14T09:00:00.000Z',cancelAtPeriodEnd:false,syncedAt:'2026-11-14T09:01:00.000Z',entitlementMirror:status==='active'}};
}
function previewService(read) {
  return {getPreviewBilling:read,clear(){}};
}
test('Preview billing appears separately in account and plan while production billing stays unchanged',async()=>{
 let reads=0;const h=await setup({checkoutService:previewService(async()=>{reads++;return previewBilling();})});
 h.emit(h.user);await flush();assert.equal(reads,1);assert.equal(h.el('account-billing').textContent,'未契約');assert.equal(h.el('account-preview-details').hidden,false);assert.equal(h.el('account-preview-state').textContent,'有料会員');assert.match(h.el('account-preview-status').textContent,/本番利用権限には反映されません/);
 h.el('review-plan').dispatch('click');await flush();assert.equal(reads,2);assert.equal(h.el('plan-billing').textContent,'未契約');assert.equal(h.el('plan-preview-state').textContent,'有料会員');assert.equal(h.el('plan-preview-details').hidden,false);h.cleanup();
});
test('Preview billing manual refresh changes only its read-only mirror',async()=>{
 let reads=0;const h=await setup({checkoutService:previewService(async()=>previewBilling(++reads===1?'active':'past_due'))});
 h.emit(h.user);await flush();h.el('account-preview-refresh').dispatch('click');await flush();assert.equal(reads,2);assert.equal(h.el('account-preview-state').textContent,'お支払いの確認が必要です');assert.equal(h.el('plan-preview-state').textContent,'お支払いの確認が必要です');assert.equal(h.el('account-billing').textContent,'未契約');assert.equal(h.calls.email,0);assert.equal(h.calls.google,0);assert.equal(h.calls.signOut,0);h.cleanup();
});
test('unverified and newly created accounts cannot read Preview billing',async()=>{
 let reads=0;const h=await setup({checkoutService:previewService(async()=>{reads++;return previewBilling();})});
 h.emit({...h.user,emailVerified:false,identityVerified:false,authenticationBasis:null});await flush();h.el('account-preview-refresh').dispatch('click');assert.equal(reads,0);
 h.emit({...h.user,isNewUser:true});await flush();h.el('plan-preview-refresh').dispatch('click');assert.equal(reads,0);assert.equal(h.el('account-preview-details').hidden,true);h.cleanup();
});
test('old account Preview billing cannot replace the current account after auth switch',async()=>{
 const a=deferred(),b=deferred();let reads=0;const h=await setup({checkoutService:previewService(()=>++reads===1?a.promise:b.promise)});
 h.emit({...h.user,maskedEmail:'a***@example.invalid'});await flush();assert.equal(reads,1);
 h.emit({...h.user,maskedEmail:'b***@example.invalid'});await flush();assert.equal(reads,2);b.resolve(previewBilling('past_due'));await flush();assert.equal(h.el('account-preview-state').textContent,'お支払いの確認が必要です');
 a.resolve(previewBilling('active'));await flush();assert.equal(h.el('account-preview-state').textContent,'お支払いの確認が必要です');assert.equal(h.el('account-email').textContent,h.summary.maskedEmail);h.cleanup();
});
test('logout clears Preview billing and ignores an in-flight read',async()=>{
 const d=deferred();const h=await setup({checkoutService:previewService(()=>d.promise)});h.emit(h.user);await flush();await h.el('logout').dispatch('click');d.resolve(previewBilling());await flush();
 assert.equal(h.el('account-preview-details').hidden,true);assert.equal(h.el('account-preview-state').textContent,'');assert.equal(h.el('plan-preview-state').textContent,'');assert.equal(h.el('account-preview-refresh').disabled,true);assert.equal(h.el('login-panel').hidden,false);h.cleanup();
});
test('Preview read failure is unavailable rather than no-contract or paid success',async()=>{
 const h=await setup({checkoutService:previewService(async()=>{throw new Error('private server response');})});h.emit(h.user);await flush();
 assert.equal(h.el('account-preview-details').hidden,true);assert.match(h.el('account-preview-status').textContent,/確認できません/);assert.doesNotMatch(h.el('account-preview-status').textContent,/private|未契約|登録が完了/);assert.equal(h.el('account-preview-refresh').disabled,false);assert.equal(h.el('account-billing').textContent,'未契約');h.cleanup();
});


function manageableBilling(status='active') {const raw=previewBilling(status);raw.billing.portalManageable=true;return raw;}
function agreeApple(h) {h.el('apple-linking-consent').checked=true;h.el('apple-linking-consent').dispatch('change');}
function portalService(read=async()=>manageableBilling()) {return {getPreviewBilling:read,createPreviewPortalSession:async()=>({testMode:true,url:'https://billing.stripe.com/p/session/test_syntheticFresh'}),clear(){}};}
test('contract management card shows required server fields and only manageable contracts receive a button',async()=>{
 for(const status of ['trialing','active','past_due','unpaid','paused','incomplete']){const h=await setup({checkoutService:portalService(async()=>manageableBilling(status))});h.emit(h.user);await flush();assert.equal(h.el('account-portal-panel').hidden,false);assert.equal(h.el('account-portal-open').hidden,false);assert.equal(h.el('account-portal-open').disabled,false);assert.match(h.el('account-portal-amount').textContent,/550円/);assert.match(h.el('account-portal-period-end').textContent,/日本時間/);assert.match(h.el('account-portal-synced-at').textContent,/日本時間/);if(status==='past_due')assert.match(h.el('account-portal-access').textContent,/お支払い方法の確認が必要/);h.cleanup();}
 for(const status of ['canceled','incomplete_expired','unknown']){const h=await setup({checkoutService:portalService(async()=>manageableBilling(status))});h.emit(h.user);await flush();assert.equal(h.el('account-portal-open').hidden,true);assert.equal(h.el('account-portal-open').disabled,true);h.cleanup();}
});
test('Portal open is explicit, duplicate-click safe and never persists its opaque destination in DOM',async()=>{
 const wait=deferred();let portals=0;const service=portalService();service.createPreviewPortalSession=()=>{portals++;return wait.promise;};const h=await setup({checkoutService:service});h.emit(h.user);await flush();h.el('account-portal-open').dispatch('click');h.el('account-portal-open').dispatch('click');assert.equal(portals,1);assert.equal(h.el('account-portal-open').disabled,true);assert.match(h.el('account-portal-status').textContent,/準備しています/);wait.resolve({testMode:true,url:'https://billing.stripe.com/p/session/test_syntheticFresh'});await flush();assert.deepEqual(h.navigation,['https://billing.stripe.com/p/session/test_syntheticFresh']);assert.equal(h.el('account-portal-open').disabled,true);h.el('account-portal-open').dispatch('click');assert.equal(portals,1);assert.doesNotMatch(JSON.stringify([...h.nodes.values()].map(n=>[n.textContent,n.value,n.attrs])),/test_syntheticFresh|billing\.stripe\.com/);assert.equal(h.calls.email,0);assert.equal(h.calls.google,0);h.cleanup();
});
test('Portal rejects untrusted destination and displays safe recoverable error',async()=>{
 const service=portalService();service.createPreviewPortalSession=async()=>({testMode:true,url:'https://evil.invalid/private_destination'});const h=await setup({checkoutService:service});h.emit(h.user);await flush();h.el('account-portal-open').dispatch('click');await flush();assert.equal(h.navigation.length,0);assert.match(h.el('account-portal-status').textContent,/安全に契約管理画面を開けません/);assert.doesNotMatch(h.el('account-portal-status').textContent,/private_destination|evil/);assert.equal(h.el('account-portal-open').disabled,false);assert.equal(globalThis.focused,'account-portal-status');h.cleanup();
});
test('Portal creation result is ignored after logout, UID change and pagehide',async()=>{
 for(const change of ['logout','uid','pagehide']){const wait=deferred();const service=portalService();service.createPreviewPortalSession=()=>wait.promise;const h=await setup({checkoutService:service});h.emit(h.user);await flush();h.el('account-portal-open').dispatch('click');if(change==='logout')await h.el('logout').dispatch('click');if(change==='uid'){h.emit({...h.user,maskedEmail:'b***@example.invalid'});await flush();}if(change==='pagehide')h.windowListeners.get('pagehide')();wait.resolve({testMode:true,url:'https://billing.stripe.com/p/session/test_neverUsed'});await flush();assert.equal(h.navigation.length,0);assert.doesNotMatch(h.el('account-portal-status').textContent,/test_neverUsed/);if(change!=='uid'){assert.equal(h.el('account-portal-panel').hidden,true);assert.equal(h.el('account-portal-plan').textContent,'');}h.cleanup();}
});
test('refresh during Portal creation invalidates the old navigation result',async()=>{
 const wait=deferred();const service=portalService();service.createPreviewPortalSession=()=>wait.promise;const h=await setup({checkoutService:service});h.emit(h.user);await flush();h.el('account-portal-open').dispatch('click');h.el('account-preview-refresh').dispatch('click');await flush();wait.resolve({testMode:true,url:'https://billing.stripe.com/p/session/test_neverUsed'});await flush();assert.equal(h.navigation.length,0);assert.equal(h.el('account-portal-open').disabled,false);h.cleanup();
});
test('Portal return strips the query and refreshes current UID billing without creating any session',async()=>{
 let reads=0,portals=0;const service=portalService(async()=>{reads++;const raw=manageableBilling();raw.billing.cancelAtPeriodEnd=true;raw.billing.nextChargeAt=null;return raw;});service.createPreviewPortalSession=async()=>{portals++;throw new Error('not expected');};const h=await setup({checkoutService:service,search:'?portal=return&unexpected=discarded'});assert.deepEqual(h.replaced,[[null,'','/account/']]);h.emit(h.user);await flush();assert.equal(reads,1);assert.equal(portals,0);assert.equal(h.navigation.length,0);assert.equal(h.el('account-portal-return-status').hidden,false);assert.match(h.el('account-portal-return-status').textContent,/最新の契約状態を読み直しました/);assert.equal(globalThis.focused,'account-portal-return-status');assert.equal(h.el('account-portal-cancel').textContent,'期間末に解約予定');assert.equal(h.el('account-portal-open').hidden,false);h.cleanup();
});
test('Portal return failure and canceled state never infer success or enable management',async()=>{
 const h=await setup({checkoutService:portalService(async()=>{throw new Error('sensitive');}),search:'?portal=return'});h.emit(h.user);await flush();assert.match(h.el('account-portal-return-status').textContent,/確認できませんでした/);assert.equal(h.el('account-portal-open').hidden,true);assert.equal(h.navigation.length,0);h.cleanup();
 const canceled=await setup({checkoutService:portalService(async()=>manageableBilling('canceled')),search:'?portal=return'});canceled.emit(canceled.user);await flush();assert.equal(canceled.el('account-portal-state').textContent,'解約済み');assert.equal(canceled.el('account-portal-open').hidden,true);canceled.cleanup();
});
test('unverified, new and missing Preview accounts cannot issue Portal sessions',async()=>{
 let portals=0;const service=portalService(async()=>({testMode:true,syncState:'none',billing:null}));service.createPreviewPortalSession=async()=>{portals++;};const h=await setup({checkoutService:service});for(const user of [{...h.user,emailVerified:false,identityVerified:false,authenticationBasis:null},{...h.user,isNewUser:true},h.user]){h.emit(user);await flush();h.el('account-portal-open').dispatch('click');await flush();}assert.equal(portals,0);assert.equal(h.navigation.length,0);h.cleanup();
});
test('past_due Preview contract cannot create a duplicate Checkout through plan selection',async()=>{
 let checkouts=0;const service=portalService(async()=>manageableBilling('past_due'));service.reviewPreviewCheckout=async()=>{checkouts++;};const h=await setup({checkoutService:service});h.emit(h.user);await flush();h.el('review-plan').dispatch('click');await flush();assert.equal(h.el('plan-fields').disabled,true);h.el('premium-monthly').checked=true;h.el('premium-monthly').dispatch('change');h.el('plan-checkout').dispatch('click');await flush();assert.equal(h.el('premium-monthly').checked,false);assert.equal(h.el('plan-checkout').disabled,true);assert.equal(checkouts,0);assert.match(h.el('plan-route-detail').textContent,/新しい申し込みは行いません/);h.cleanup();
});

test('plan choice stays disabled while its Preview contract read is pending',async()=>{
 const wait=deferred();let reads=0,checkouts=0;const service=portalService(async()=>++reads===1?manageableBilling('past_due'):wait.promise);service.reviewPreviewCheckout=async()=>{checkouts++;};const h=await setup({checkoutService:service});h.emit(h.user);await flush();h.el('review-plan').dispatch('click');await flush();h.el('premium-monthly').checked=true;h.el('premium-monthly').dispatch('change');h.el('plan-checkout').dispatch('click');assert.equal(h.el('premium-monthly').checked,false);assert.equal(checkouts,0);wait.resolve(manageableBilling('past_due'));await flush();assert.equal(h.el('plan-fields').disabled,true);h.cleanup();
});

test('persisted Portal return clears stale opening state, refreshes billing and issues only a fresh Session',async()=>{
 let reads=0,portals=0;const service=portalService(async()=>{reads++;const raw=manageableBilling();raw.billing.cancelAtPeriodEnd=reads>1;return raw;});service.createPreviewPortalSession=async()=>({testMode:true,url:'https://billing.stripe.com/p/session/test_syntheticFresh'+(++portals)});const h=await setup({checkoutService:service});h.emit(h.user);await flush();h.el('account-portal-open').dispatch('click');await flush();assert.equal(portals,1);assert.equal(h.el('account-portal-open').disabled,true);assert.equal(reads,1);
 // Simulate a cached document returning without relying on a prior pagehide.
 await h.windowListeners.get('pageshow')({persisted:true});await flush();assert.equal(h.calls.reload,1);assert.equal(reads,2);assert.equal(h.el('account-portal-open').disabled,false);assert.equal(h.el('account-portal-cancel').textContent,'期間末に解約予定');assert.match(h.el('account-portal-return-status').textContent,/最新の契約状態を読み直しました/);assert.equal(globalThis.focused,'account-portal-return-status');assert.equal(h.navigation.length,1);
 h.el('account-portal-open').dispatch('click');await flush();assert.equal(portals,2);assert.deepEqual(h.navigation,['https://billing.stripe.com/p/session/test_syntheticFresh1','https://billing.stripe.com/p/session/test_syntheticFresh2']);assert.doesNotMatch(JSON.stringify([...h.nodes.values()].map(n=>[n.textContent,n.value,n.attrs])),/test_syntheticFresh/);h.cleanup();assert.equal(h.windowListeners.has('pageshow'),false);
});

test('Apple is visibly gated off until explicit capability is enabled',async()=>{
 const h=await setup();assert.equal(h.el('apple-signin').disabled,true);h.el('apple-signin').dispatch('click');await flush();assert.equal(h.calls.apple,0);assert.equal(h.calls.reads,0);assert.match(html,/Appleログインは設定確認中/);assert.match(html,/alt="Appleでサインイン"/);h.el('google-signin').dispatch('click');await flush();assert.equal(h.calls.google,1);h.cleanup();
});
test('enabled Apple capability uses existing account view and preserves its registered profile',async()=>{
 const h=await setup({appleSignInEnabled:true});h.summary.methods=['Apple'];assert.equal(h.el('apple-signin').disabled,true);agreeApple(h);assert.equal(h.el('apple-signin').disabled,false);h.el('apple-signin').dispatch('click');await flush();assert.equal(h.calls.apple,1);assert.equal(h.el('account-panel').hidden,false);assert.equal(h.el('account-method').textContent,'Apple');assert.equal(h.el('account-nickname').textContent,h.summary.nickname);assert.equal(h.el('review-plan').disabled,false);h.cleanup();
});
test('verified Apple identity without email can read account and select a plan without email confirmation',async()=>{
 let billingReads=0;
 const h=await setup({checkoutService:previewService(async()=>{billingReads++;return {testMode:true,syncState:'none',billing:null};})});
 const apple={...h.user,emailVerified:false,identityVerified:true,authenticationBasis:'apple_provider',maskedEmail:'未設定',methods:['Apple']};
 Object.assign(h.summary,{maskedEmail:apple.maskedEmail,methods:apple.methods});
 h.emit(apple);await flush();
 assert.equal(apple.emailVerified,false);
 assert.equal(h.el('verification-panel').hidden,true);
 assert.equal(h.el('account-panel').hidden,false);
 assert.equal(h.el('account-email').textContent,'未設定');
 assert.equal(h.el('account-method').textContent,'Apple');
 assert.equal(h.el('review-plan').disabled,false);
 assert.equal(billingReads,1);
 h.el('review-plan').dispatch('click');await flush();
 assert.equal(h.calls.reads,2);
 assert.equal(billingReads,2);
 assert.equal(h.el('plan-panel').hidden,false);
 assert.equal(h.el('verification-panel').hidden,true);
 assert.equal(h.el('plan-email').textContent,'未設定');
 assert.equal(h.el('plan-method').textContent,'Apple');
 assert.equal(h.el('plan-fields').disabled,false);
 h.el('premium-monthly').checked=true;h.el('premium-monthly').dispatch('change');
 assert.equal(h.el('premium-monthly').checked,true);
 assert.match(h.el('plan-selected-amount').textContent,/550円/);
 assert.equal(h.calls.reload,0);
 h.cleanup();
});
test('verified Apple identity without email can refresh Preview billing and open its management Portal',async()=>{
 let billingReads=0,portals=0;
 const service=portalService(async()=>{billingReads++;return manageableBilling();});
 service.createPreviewPortalSession=async()=>{portals++;return {testMode:true,url:'https://billing.stripe.com/p/session/test_appleSynthetic'};};
 const h=await setup({checkoutService:service});
 const apple={...h.user,emailVerified:false,identityVerified:true,authenticationBasis:'apple_provider',maskedEmail:'未設定',methods:['Apple']};
 Object.assign(h.summary,{maskedEmail:apple.maskedEmail,methods:apple.methods});
 h.emit(apple);await flush();
 assert.equal(h.el('account-preview-details').hidden,false);
 assert.equal(h.el('account-portal-open').disabled,false);
 h.el('account-preview-refresh').dispatch('click');await flush();
 assert.equal(billingReads,2);
 assert.equal(h.el('verification-panel').hidden,true);
 h.el('account-portal-open').dispatch('click');await flush();
 assert.equal(portals,1);
 assert.deepEqual(h.navigation,['https://billing.stripe.com/p/session/test_appleSynthetic']);
 assert.equal(apple.emailVerified,false);
 assert.equal(h.calls.reload,0);
 h.cleanup();
});
test('unverified email and Google identities remain blocked even with a linked Apple provider',async()=>{
 for(const methods of [['メール/パスワード'],['Google'],['Google','Apple']]){
  let billingReads=0,portals=0;
  const service=portalService(async()=>{billingReads++;return manageableBilling();});
  service.createPreviewPortalSession=async()=>{portals++;};
  const h=await setup({checkoutService:service});
  h.emit({...h.user,emailVerified:false,identityVerified:false,authenticationBasis:null,methods});await flush();
  assert.equal(h.el('verification-panel').hidden,false);
  assert.equal(h.el('account-panel').hidden,true);
  assert.equal(h.calls.reads,0);
  h.el('review-plan').dispatch('click');h.el('account-preview-refresh').dispatch('click');h.el('account-portal-open').dispatch('click');await flush();
  assert.equal(h.el('plan-panel').hidden,true);
  assert.equal(billingReads,0);
  assert.equal(portals,0);
  assert.equal(h.navigation.length,0);
  h.cleanup();
 }
});
test('failed identity verification returns safely to login instead of requesting nonexistent email confirmation',async()=>{
 for(const emailVerified of [false,true]){
  let billingReads=0;
  const h=await setup({checkoutService:previewService(async()=>{billingReads++;return previewBilling();})});
  h.service.safeError=safeAuthError;
  h.emit({...h.user,emailVerified,identityVerified:false,authenticationBasis:null,identityCheckFailed:true,maskedEmail:emailVerified?h.user.maskedEmail:'未設定',methods:['Apple']});await flush();
  assert.equal(h.el('login-panel').hidden,false);
  assert.equal(h.el('verification-panel').hidden,true);
  assert.equal(h.el('account-panel').hidden,true);
  assert.equal(h.el('verification-email').textContent,'');
  assert.equal(h.el('auth-error').hidden,false);
  assert.match(h.el('auth-error').textContent,/本人確認.*もう一度ログイン/);
  assert.doesNotMatch(h.el('auth-error').textContent,/メール.*確認|token|subject/);
  assert.equal(h.calls.reads,0);
  assert.equal(billingReads,0);
  h.cleanup();
 }
});
test('Apple identity rejection clears an in-flight Preview read without restoring prior account data',async()=>{
 const pending=deferred();
 const h=await setup({checkoutService:previewService(()=>pending.promise)});
 h.service.safeError=safeAuthError;
 const apple={...h.user,emailVerified:false,identityVerified:true,authenticationBasis:'apple_provider',maskedEmail:'未設定',methods:['Apple']};
 Object.assign(h.summary,{maskedEmail:apple.maskedEmail,methods:apple.methods});
 h.emit(apple);await flush();
 assert.equal(h.el('account-panel').hidden,false);
 h.emit({...apple,identityVerified:false,authenticationBasis:null,identityCheckFailed:true});await flush();
 pending.resolve(previewBilling());await flush();
 assert.equal(h.el('login-panel').hidden,false);
 assert.equal(h.el('verification-panel').hidden,true);
 assert.equal(h.el('account-email').textContent,'');
 assert.equal(h.el('account-nickname').textContent,'');
 assert.equal(h.el('account-preview-details').hidden,true);
 assert.equal(h.el('account-preview-state').textContent,'');
 assert.equal(h.el('account-portal-open').disabled,true);
 h.cleanup();
});
test('pending Apple sign-in blocks duplicate Apple, Google and email actions',async()=>{
 const wait=deferred();const h=await setup({appleSignInEnabled:true});h.service.signInApple=()=>{h.calls.apple++;return wait.promise;};agreeApple(h);h.el('apple-signin').dispatch('click');h.el('apple-signin').dispatch('click');h.el('google-signin').dispatch('click');h.el('email').value='synthetic@example.invalid';h.el('password').value='synthetic-only';h.el('email-form').dispatch('submit',{preventDefault(){}});assert.equal(h.calls.apple,1);assert.equal(h.calls.google,0);assert.equal(h.calls.email,0);assert.equal(h.el('apple-signin').disabled,true);wait.resolve();await flush();assert.equal(h.el('apple-linking-consent').checked,false);assert.equal(h.el('apple-signin').disabled,true);h.cleanup();
});
test('Apple cancellation, failure and provider conflict remain safe recoverable login errors',async()=>{
 for(const code of ['auth/popup-closed-by-user','auth/network-request-failed','auth/account-exists-with-different-credential']){const h=await setup({appleSignInEnabled:true});h.service.safeError=safeAuthError;h.service.signInApple=async()=>{h.calls.apple++;throw {code,message:'private_subject_code_token'};};agreeApple(h);h.el('apple-signin').dispatch('click');await flush();assert.equal(h.el('account-panel').hidden,true);assert.equal(h.calls.reads,0);assert.equal(h.el('auth-error').hidden,false);assert.doesNotMatch(h.el('auth-error').textContent,/private_subject_code_token|auth\//);if(code.includes('different-credential'))assert.match(h.el('auth-error').textContent,/ログイン方法/);assert.equal(h.el('apple-linking-consent').checked,false);assert.equal(h.el('apple-signin').disabled,true);h.cleanup();}
});
test('logout while Apple sign-in is pending clears UI and does not restore a late completed action',async()=>{
 const wait=deferred();const h=await setup({appleSignInEnabled:true});h.service.signInApple=()=>{h.calls.apple++;return wait.promise;};agreeApple(h);h.el('apple-signin').dispatch('click');await h.el('logout').dispatch('click');wait.resolve();await flush();assert.equal(h.el('login-panel').hidden,false);assert.equal(h.el('account-email').textContent,'');assert.equal(h.calls.reads,0);assert.equal(h.calls.signOut,1);h.cleanup();assert.equal(h.el('apple-signin').listeners.has('click'),false);
});
test('new Apple or empty/unreadable app account cannot enter plan, Checkout, Preview billing or Portal',async()=>{
 for(const appAccountExists of [false,null]){let billingReads=0,portals=0,checkouts=0;const service=portalService(async()=>{billingReads++;return manageableBilling();});service.createPreviewPortalSession=async()=>{portals++;};service.reviewPreviewCheckout=async()=>{checkouts++;};const h=await setup({checkoutService:service,appleSignInEnabled:true});h.summary.appAccountExists=appAccountExists;h.summary.methods=['Apple'];h.emit({...h.user,emailVerified:false,identityVerified:true,authenticationBasis:'apple_provider',maskedEmail:'未設定',methods:['Apple'],isNewUser:appAccountExists===false});await flush();assert.equal(h.el('review-plan').disabled,true);h.el('review-plan').dispatch('click');h.el('account-preview-refresh').dispatch('click');h.el('account-portal-open').dispatch('click');h.el('premium-monthly').checked=true;h.el('premium-monthly').dispatch('change');h.el('plan-checkout').dispatch('click');await flush();assert.equal(h.el('plan-panel').hidden,true);assert.equal(billingReads,0);assert.equal(portals,0);assert.equal(checkouts,0);assert.equal(h.el('account-registration-note').hidden,false);assert.match(h.el('account-registration-note').textContent,/確認|停止/);h.cleanup();}
});

test('Apple association requires an unchecked explicit choice before any authentication starts',async()=>{
 const h=await setup({appleSignInEnabled:true});assert.equal(h.el('apple-linking-consent').checked,false);assert.equal(h.el('apple-signin').disabled,true);h.el('apple-signin').dispatch('click');await flush();assert.equal(h.calls.apple,0);assert.equal(h.calls.reads,0);assert.match(h.el('auth-error').textContent,/関連付け.*同意/);assert.equal(globalThis.focused,'apple-linking-consent');assert.match(html,/Appleログイン方法が追加される場合があります/);assert.match(html,/別アカウントのデータを自動で統合・コピーすることはありません/);assert.match(html,/Appleが発行する中継メールアドレス/);h.cleanup();
});
test('checking and unchecking Apple consent controls the button and API receives literal consent only',async()=>{
 const h=await setup({appleSignInEnabled:true});let options;h.service.signInApple=async value=>{h.calls.apple++;options=value;};agreeApple(h);assert.equal(h.el('apple-signin').disabled,false);h.el('apple-linking-consent').checked=false;h.el('apple-linking-consent').dispatch('change');assert.equal(h.el('apple-signin').disabled,true);h.el('apple-signin').dispatch('click');await flush();assert.equal(h.calls.apple,0);agreeApple(h);h.el('apple-signin').dispatch('click');await flush();assert.deepEqual(options,{linkingConsent:true});assert.equal(h.calls.apple,1);assert.equal(h.el('apple-linking-consent').checked,false);assert.equal(h.el('apple-signin').disabled,true);h.cleanup();
});
test('Apple cancellation or failure consumes the choice so another attempt needs fresh consent',async()=>{
 for(const code of ['auth/popup-closed-by-user','auth/network-request-failed']){const h=await setup({appleSignInEnabled:true});h.service.signInApple=async options=>{assert.deepEqual(options,{linkingConsent:true});h.calls.apple++;throw {code};};agreeApple(h);h.el('apple-signin').dispatch('click');await flush();assert.equal(h.calls.apple,1);assert.equal(h.el('apple-linking-consent').checked,false);assert.equal(h.el('apple-signin').disabled,true);h.el('apple-signin').dispatch('click');await flush();assert.equal(h.calls.apple,1);h.cleanup();}
});
test('Apple consent is cleared on logout and pagehide without changing email or Google login',async()=>{
 const h=await setup({appleSignInEnabled:true});agreeApple(h);await h.el('logout').dispatch('click');assert.equal(h.el('apple-linking-consent').checked,false);agreeApple(h);h.windowListeners.get('pagehide')();assert.equal(h.el('apple-linking-consent').checked,false);await h.windowListeners.get('pageshow')({persisted:true});await flush();assert.equal(h.el('apple-linking-consent').checked,false);assert.equal(h.calls.apple,0);h.cleanup();assert.equal(h.el('apple-linking-consent').listeners.has('change'),false);
 const google=await setup({appleSignInEnabled:true});agreeApple(google);google.el('google-signin').dispatch('click');await flush();assert.equal(google.calls.google,1);assert.equal(google.calls.apple,0);assert.equal(google.el('apple-linking-consent').checked,false);google.cleanup();
});
test('Apple consent checkbox is required, outside the unchanged email form and disabled by the setup gate',async()=>{
 const h=await setup();assert.equal(h.el('apple-linking-consent').disabled,true);assert.match(html,/<input id="apple-linking-consent"[^>]+type="checkbox"[^>]+required disabled/);const form=html.match(/<form[^>]+id="email-form"[^>]*>[\s\S]*?<\/form>/)[0];assert.doesNotMatch(form,/apple-linking-consent/);h.cleanup();
});

// UI-only race regressions. These never change Popup/Redirect routing or make a
// real authentication request; fresh identity evidence is a synthetic service event.
const verifiedApple = h => ({...h.user,emailVerified:false,identityVerified:true,authenticationBasis:'apple_provider',maskedEmail:'未設定',methods:['Apple']});
function pendingApple(h, pending) {
 h.service.safeError=safeAuthError;
 h.service.signInApple=async options=>{assert.deepEqual(options,{linkingConsent:true});h.calls.apple++;return pending.promise;};
 agreeApple(h);h.el('apple-signin').dispatch('click');
}
test('current verified Apple account read wins over a late Popup-blocked notification from that attempt',async()=>{
 const h=await setup({appleSignInEnabled:true}),pending=deferred();pendingApple(h,pending);
 h.summary.maskedEmail='未設定';h.summary.nickname='今回のアカウント';h.emit(verifiedApple(h));await flush();
 assert.equal(h.el('account-panel').hidden,false);assert.equal(h.el('account-nickname').textContent,'今回のアカウント');assert.equal(h.el('account-email').textContent,'未設定');
 // The fresh account is visible before the original operation settles; another
 // click still cannot start a concurrent authentication operation.
 h.el('google-signin').dispatch('click');assert.equal(h.calls.google,0);
 pending.reject({code:'auth/popup-blocked'});await flush();
 assert.equal(h.el('auth-error').hidden,true);assert.equal(h.el('account-panel').hidden,false);assert.equal(h.calls.reads,1);h.cleanup();
});
test('a Popup error shown first clears only after the same current Apple account read succeeds',async()=>{
 const h=await setup({appleSignInEnabled:true}),pending=deferred(),read=deferred();h.service.readAccountSummary=()=>{h.calls.reads++;return read.promise;};pendingApple(h,pending);
 h.emit(verifiedApple(h));pending.reject({code:'auth/popup-blocked'});await flush();
 assert.equal(h.el('auth-error').hidden,false);assert.match(h.el('auth-error').textContent,/ログイン画面を開けません/);assert.equal(h.el('account-panel').hidden,true);
 read.resolve({...h.summary,maskedEmail:'未設定',nickname:'再確認したアカウント'});await flush();
 assert.equal(h.el('account-panel').hidden,false);assert.equal(h.el('account-nickname').textContent,'再確認したアカウント');assert.equal(h.el('auth-error').hidden,true);h.cleanup();
});
test('real Popup blocking with no confirmed identity remains a recoverable error',async()=>{
 const h=await setup({appleSignInEnabled:true}),pending=deferred();pendingApple(h,pending);pending.reject({code:'auth/popup-blocked'});await flush();
 assert.equal(h.el('login-panel').hidden,false);assert.equal(h.calls.reads,0);assert.equal(h.el('auth-error').hidden,false);assert.match(h.el('auth-error').textContent,/ログイン画面を開けません/);h.cleanup();
});
test('failed current-account read cannot turn a Popup rejection into authentication success',async()=>{
 const h=await setup({appleSignInEnabled:true}),pending=deferred(),read=deferred();h.service.readAccountSummary=()=>read.promise;pendingApple(h,pending);
 h.service.safeError=cause=>cause?.code==='synthetic/read-failed'?'アカウントの読取を完了できませんでした。':safeAuthError(cause);
 h.emit(verifiedApple(h));pending.reject({code:'auth/popup-blocked'});await flush();read.reject({code:'synthetic/read-failed'});await flush();
 assert.equal(h.el('account-panel').hidden,true);assert.equal(h.el('loading-panel').hidden,false);assert.equal(h.el('auth-error').hidden,false);assert.equal(h.el('auth-error').textContent,'アカウントの読取を完了できませんでした。');h.cleanup();
});
test('partial, unknown, missing or newly registered app-account results cannot suppress Popup blocking',async()=>{
 for(const condition of ['partial','unknown','missing','new-user']){
  const h=await setup({appleSignInEnabled:true}),pending=deferred();pendingApple(h,pending);
  if(condition==='partial')h.summary.unavailableFields=['プロフィール'];
  if(condition==='unknown')h.summary.appAccountExists=null;
  if(condition==='missing')h.summary.appAccountExists=false;
  h.emit({...verifiedApple(h),isNewUser:condition==='new-user'});await flush();pending.reject({code:'auth/popup-blocked'});await flush();
  assert.equal(h.el('auth-error').hidden,false);assert.match(h.el('auth-error').textContent,/ログイン画面を開けません/);h.cleanup();
 }
});
test('current Apple account success does not suppress cancellation, network or provider-conflict errors',async()=>{
 for(const code of ['auth/popup-closed-by-user','auth/cancelled-popup-request','auth/network-request-failed','auth/account-exists-with-different-credential']){
  const h=await setup({appleSignInEnabled:true}),pending=deferred();pendingApple(h,pending);h.emit(verifiedApple(h));await flush();pending.reject({code});await flush();
  assert.equal(h.el('auth-error').hidden,false);assert.equal(h.el('auth-error').textContent,safeAuthError({code}));h.cleanup();
 }
});
test('non-Popup errors shown before the current Apple read are not cleared by that read',async()=>{
 const h=await setup({appleSignInEnabled:true}),pending=deferred(),read=deferred();h.service.readAccountSummary=()=>read.promise;pendingApple(h,pending);h.emit(verifiedApple(h));
 pending.reject({code:'auth/network-request-failed'});await flush();read.resolve(h.summary);await flush();
 assert.equal(h.el('account-panel').hidden,false);assert.equal(h.el('auth-error').hidden,false);assert.match(h.el('auth-error').textContent,/通信に失敗/);h.cleanup();
});
test('an unverified Apple-labelled event cannot suppress a real Popup-blocked error',async()=>{
 const h=await setup({appleSignInEnabled:true}),pending=deferred();pendingApple(h,pending);h.emit({...verifiedApple(h),identityVerified:false,authenticationBasis:null});await flush();
 pending.reject({code:'auth/popup-blocked'});await flush();assert.equal(h.calls.reads,0);assert.equal(h.el('account-panel').hidden,true);assert.match(h.el('auth-error').textContent,/ログイン画面を開けません/);h.cleanup();
});
test('a replacement authenticated user with identical display fields invalidates the prior Popup attempt',async()=>{
 const h=await setup({appleSignInEnabled:true}),pending=deferred();pendingApple(h,pending);const first=verifiedApple(h);h.emit(first);await flush();
 // Reference identity, not nickname or masked-email equality, controls this boundary.
 h.summary.nickname='次のアカウント';h.emit({...first});await flush();pending.reject({code:'auth/popup-blocked'});await flush();
 assert.equal(h.calls.reads,2);assert.equal(h.el('account-nickname').textContent,'次のアカウント');assert.equal(h.el('auth-error').hidden,true);h.cleanup();
});
test('logout or destruction prevents a late Popup failure from writing an obsolete auth error',async()=>{
 for(const finish of ['logout','destroy']){
  const h=await setup({appleSignInEnabled:true}),pending=deferred();pendingApple(h,pending);
  if(finish==='logout')await h.el('logout').dispatch('click');else h.cleanup();
  const before=h.el('auth-error').textContent;pending.reject({code:'auth/popup-blocked'});await flush();assert.equal(h.el('auth-error').textContent,before);assert.equal(h.el('auth-error').hidden,true);
  if(finish==='logout')h.cleanup();
 }
});
test('a subsequent explicit attempt keeps its own real error when an older attempt rejects later',async()=>{
 const h=await setup({appleSignInEnabled:true}),old=deferred();pendingApple(h,old);await h.el('logout').dispatch('click');
 const next=deferred();pendingApple(h,next);next.reject({code:'auth/network-request-failed'});await flush();assert.match(h.el('auth-error').textContent,/通信に失敗/);
 old.reject({code:'auth/popup-blocked'});await flush();assert.match(h.el('auth-error').textContent,/通信に失敗/);h.cleanup();
});
test('pagehide invalidates a Popup attempt before a restored page rechecks authentication',async()=>{
 const h=await setup({appleSignInEnabled:true}),pending=deferred();pendingApple(h,pending);h.emit(verifiedApple(h));await flush();h.windowListeners.get('pagehide')();
 await h.windowListeners.get('pageshow')({persisted:true});await flush();pending.reject({code:'auth/popup-blocked'});await flush();
 assert.equal(h.calls.reload,1);assert.equal(h.el('account-panel').hidden,false);assert.equal(h.el('auth-error').hidden,true);h.cleanup();
});

test("a late Popup rejection cannot overwrite this current attempt's earlier account-read error",async()=>{
 const h=await setup({appleSignInEnabled:true}),pending=deferred();pendingApple(h,pending);
 h.service.safeError=cause=>cause?.code==='synthetic/read-failed'?'アカウントの読取を完了できませんでした。':safeAuthError(cause);
 h.service.readAccountSummary=async()=>{throw {code:'synthetic/read-failed'};};h.emit(verifiedApple(h));await flush();
 assert.equal(h.el('auth-error').textContent,'アカウントの読取を完了できませんでした。');pending.reject({code:'auth/popup-blocked'});await flush();
 assert.equal(h.el('account-panel').hidden,true);assert.equal(h.el('loading-panel').hidden,false);assert.equal(h.el('auth-error').hidden,false);assert.equal(h.el('auth-error').textContent,'アカウントの読取を完了できませんでした。');h.cleanup();
});

test('Google Popup blocking is not reclassified by the Apple-only notification rule',async()=>{
 const h=await setup(),pending=deferred();h.service.safeError=safeAuthError;h.service.signInGoogle=()=>pending.promise;h.el('google-signin').dispatch('click');h.emit({...h.user,methods:['Google']});await flush();
 pending.reject({code:'auth/popup-blocked'});await flush();assert.equal(h.el('auth-error').hidden,false);assert.match(h.el('auth-error').textContent,/ログイン画面を開けません/);h.cleanup();
});

function contactState({category='missing',source=null,verified=false,maskedEmail=null,pendingMaskedEmail=null,deliveryState=null}={}) {
 return {testMode:true,state:verified?'verified':pendingMaskedEmail?'pending':'missing',category,source,maskedEmail,pendingMaskedEmail,canCheckout:verified,resendAfter:null,expiresAt:null,deliveryState};
}
function contactHarness(initial=contactState()) {
 let value=initial;const calls={status:0,clear:0};
 const service={getStatus:async()=>{calls.status++;return value;},clear:()=>calls.clear++};
 return {service,calls,set:next=>value=next};
}
function syntheticCheckoutReview() {
 return {testMode:true,planKey:'premium_monthly',amount:550,currency:'jpy',interval:'month',reviewToken:'synthetic_review_contact_12345',account:{nickname:'Synthetic',maskedEmail:'co***@example.test'},billing:{kind:'immediate',cardRegistrationAt:'2026-11-19T09:00:00Z',firstChargeAt:'2026-11-19T09:00:00Z',firstChargeAmount:550,trialEndsAt:null}};
}
test('contact card is separate from Auth email and does not redirect merely on login',async()=>{
 const contact=contactHarness(contactState({verified:true,source:'user_supplied',maskedEmail:'co***@example.test'}));
 const h=await setup({contactService:contact.service});h.emit(h.user);await flush();
 assert.equal(h.el('account-panel').hidden,false);assert.equal(h.el('account-contact-panel').hidden,false);
 assert.equal(h.el('account-email').textContent,h.summary.maskedEmail);assert.equal(h.el('account-contact-email').textContent,'co***@example.test');
 assert.deepEqual(h.navigation,[]);assert.equal(contact.calls.status,1);h.cleanup();
});
for(const item of [contactState({category:'normal',source:'auth_verified',verified:true,maskedEmail:'no***@example.test'}),contactState({category:'apple_relay',source:'apple_provider',verified:true,maskedEmail:'re***@privaterelay.appleid.com'}),contactState({category:'apple_relay',source:'apple_provider',verified:true,maskedEmail:'re***@private.icloud.com'})])test('verified '+item.maskedEmail+' proceeds to plan without extra email input',async()=>{
 const contact=contactHarness(item);const h=await setup({contactService:contact.service});h.emit(h.user);await flush();
 await h.el('review-plan').dispatch('click');await flush();assert.equal(h.el('plan-panel').hidden,false);assert.deepEqual(h.navigation,[]);assert.equal(contact.calls.status,2);assert.equal(h.calls.reads,2);h.cleanup();
});
test('missing contact redirects only when new plan is requested and before checkout',async()=>{
 const contact=contactHarness();let reviews=0;const checkout=portalService(async()=>({testMode:true,syncState:'none',billing:null}));checkout.reviewPreviewCheckout=async()=>{reviews++;return syntheticCheckoutReview();};
 const h=await setup({contactService:contact.service,checkoutService:checkout});h.summary.maskedEmail='未設定';h.emit({...h.user,emailVerified:false,authenticationBasis:'apple_provider',maskedEmail:'未設定'});await flush();
 assert.equal(h.el('account-panel').hidden,false);assert.deepEqual(h.navigation,[]);await h.el('review-plan').dispatch('click');await flush();
 assert.deepEqual(h.navigation,['/account/contact/']);assert.equal(h.el('plan-panel').hidden,true);assert.equal(reviews,0);assert.equal(h.calls.reads,1);h.cleanup();
});
test('contact API failure leaves account and existing Portal usable while denying new purchase',async()=>{
 const contact=contactHarness();contact.service.getStatus=async()=>{contact.calls.status++;throw {code:'contact_mail_unavailable',details:'private-uid'};};let portals=0;
 const checkout=portalService();checkout.createPreviewPortalSession=async()=>{portals++;return{testMode:true,url:'https://billing.stripe.com/p/session/test_syntheticContactFailure'};};
 const h=await setup({contactService:contact.service,checkoutService:checkout});h.emit(h.user);await flush();
 assert.equal(h.el('account-panel').hidden,false);assert.match(h.el('account-contact-status').textContent,/既存契約の管理/);assert.equal(h.el('account-portal-open').disabled,false);
 await h.el('account-portal-open').dispatch('click');await flush();assert.equal(portals,1);assert.equal(h.navigation[0],'https://billing.stripe.com/p/session/test_syntheticContactFailure');h.cleanup();
});
test('contact API failure prevents plan transition but does not replace account by error screen',async()=>{
 const contact=contactHarness();contact.service.getStatus=async()=>{throw{code:'service_unavailable'};};const h=await setup({contactService:contact.service});h.emit(h.user);await flush();await h.el('review-plan').dispatch('click');await flush();
 assert.equal(h.el('account-panel').hidden,false);assert.equal(h.el('plan-panel').hidden,true);assert.equal(h.navigation.length,0);assert.equal(h.el('auth-error').hidden,false);h.cleanup();
});
test('fresh contact status is checked again before opening checkout review',async()=>{
 const contact=contactHarness(contactState({verified:true,source:'user_supplied',maskedEmail:'co***@example.test'}));let reviews=0;
 const checkout=portalService(async()=>({testMode:true,syncState:'none',billing:null}));checkout.reviewPreviewCheckout=async()=>{reviews++;return syntheticCheckoutReview();};
 const h=await setup({contactService:contact.service,checkoutService:checkout});h.emit(h.user);await flush();await h.el('review-plan').dispatch('click');await flush();
 h.el('premium-monthly').checked=true;h.el('premium-monthly').dispatch('change');contact.set(contactState());await h.el('plan-checkout').dispatch('click');await flush();
 assert.equal(reviews,0);assert.deepEqual(h.navigation,['/account/contact/']);assert.equal(contact.calls.status,3);h.cleanup();
});
test('verified supplied contact can open checkout review and never overwrites Auth display',async()=>{
 const contact=contactHarness(contactState({verified:true,source:'user_supplied',maskedEmail:'co***@example.test'}));let reviews=0;
 const checkout=portalService(async()=>({testMode:true,syncState:'none',billing:null}));checkout.reviewPreviewCheckout=async()=>{reviews++;return syntheticCheckoutReview();};
 const h=await setup({contactService:contact.service,checkoutService:checkout});h.emit(h.user);await flush();await h.el('review-plan').dispatch('click');await flush();
 h.el('premium-monthly').checked=true;h.el('premium-monthly').dispatch('change');await h.el('plan-checkout').dispatch('click');await flush();
 assert.equal(reviews,1);assert.equal(h.el('checkout-panel').hidden,false);assert.equal(h.el('plan-email').textContent,h.summary.maskedEmail);assert.equal(h.el('checkout-account-email').textContent,'co***@example.test');h.cleanup();
});
test('contact state changing during account switch cannot navigate or reveal old address',async()=>{
 const contact=contactHarness(contactState({verified:true,source:'user_supplied',maskedEmail:'aa***@example.test'}));const h=await setup({contactService:contact.service});h.emit(h.user);await flush();
 const old=deferred();contact.service.getStatus=()=>old.promise;const plan=h.el('review-plan').dispatch('click');
 contact.service.getStatus=async()=>contactState({verified:true,source:'user_supplied',maskedEmail:'bb***@example.test'});h.emit({...h.user,maskedEmail:'other***@example.test'});await flush();old.resolve(contactState());await plan;await flush();
 assert.equal(h.navigation.length,0);assert.equal(h.el('account-contact-email').textContent,'bb***@example.test');assert.equal(h.el('plan-panel').hidden,true);h.cleanup();
});
test('contact checks are double click safe and revoked by logout/pagehide',async()=>{
 for(const change of ['logout','pagehide']){
  const contact=contactHarness(contactState({verified:true,source:'user_supplied',maskedEmail:'co***@example.test'}));const h=await setup({contactService:contact.service});h.emit(h.user);await flush();
  const old=deferred();contact.service.getStatus=()=>{contact.calls.status++;return old.promise;};const first=h.el('review-plan').dispatch('click');h.el('review-plan').dispatch('click');assert.equal(contact.calls.status,2);
  if(change==='logout')await h.el('logout').dispatch('click');else h.windowListeners.get('pagehide')();old.resolve(contactState());await first;await flush();assert.equal(h.navigation.length,0);assert.equal(h.el('account-contact-email').textContent,'');assert.ok(contact.calls.clear>0);h.cleanup();
 }
});
test('pending contact with uncertain delivery is not shown as sent on account card',async()=>{
 const contact=contactHarness(contactState({pendingMaskedEmail:'pe***@example.test',deliveryState:'uncertain'}));const h=await setup({contactService:contact.service});h.emit(h.user);await flush();assert.match(h.el('account-contact-status').textContent,/送信結果を確認/);assert.doesNotMatch(h.el('account-contact-status').textContent,/リンクから確認/);h.cleanup();
});
