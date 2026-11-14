import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { mountAccountPage } from '../public/assets/account-view.mjs';
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
async function setup({checkoutService=null}={}) {
  const nodes = new Map([...html.matchAll(/id="([^"]+)"/g)].map(x=>[x[1],new Element(x[1])]));
  nodes.get('premium-monthly').value='premium_monthly';
  nodes.get('premium-monthly').checked=false;
  nodes.get('plan-checkout').disabled=true;
  const windowListeners=new Map();
  globalThis.document={getElementById:id=>nodes.get(id)};
  globalThis.window={addEventListener:(name,fn)=>windowListeners.set(name,fn),removeEventListener:name=>windowListeners.delete(name)};
  let callback;
  const calls={reads:0,email:0,google:0,signOut:0,reload:0};
  const user={emailVerified:true,maskedEmail:'sa***@example.invalid',methods:['メール/パスワード'],isNewUser:false};
  const summary={nickname:'本人ニックネーム',maskedEmail:user.maskedEmail,methods:user.methods,billingLabel:'未契約',trialLabel:'サーバー保存状態：active',unavailableFields:[],planReview:projectPlanReview({kind:'missing'})};
  const service={ready:async()=>{},onAuthChanged:cb=>{callback=cb;cb(null);return()=>{};},readAccountSummary:async()=>{calls.reads++;return summary;},signInEmail:async()=>{calls.email++;callback(user);},signInGoogle:async()=>{calls.google++;callback(user);},signOut:async()=>{calls.signOut++;callback(null);},reloadUser:async()=>{calls.reload++;callback(user);},safeError:()=> '通信に失敗しました。'};
  const cleanup=await mountAccountPage(service,{checkoutService});
  return {el:id=>nodes.get(id),service,calls,user,summary,emit:u=>callback(u),cleanup,windowListeners};
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
 const h=await setup();h.emit({...h.user,emailVerified:false});await flush();assert.equal(h.calls.reads,0);assert.equal(h.el('verification-panel').hidden,false);h.el('review-plan').dispatch('click');assert.equal(h.el('plan-panel').hidden,true);h.cleanup();
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
 const h=await setup();h.emit({...h.user,emailVerified:false});await flush();await h.el('check-verification').dispatch('click');await flush();assert.equal(h.calls.reload,1);assert.equal(h.el('account-panel').hidden,false);h.cleanup();
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
 h.emit({...h.user,emailVerified:false});await flush();h.el('account-preview-refresh').dispatch('click');assert.equal(reads,0);
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
