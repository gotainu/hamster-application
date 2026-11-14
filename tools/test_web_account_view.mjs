import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { mountAccountPage } from '../public/assets/account-view.mjs';
const html = await readFile(new URL('../public/account/index.html', import.meta.url), 'utf8');
class Element {
  constructor(id) { this.id=id;this.hidden=false;this.disabled=false;this.value='';this.type=id==='password'?'password':'text';this.textContent='';this.attrs={};this.listeners=new Map();this.validity={valid:true}; }
  addEventListener(name,fn){this.listeners.set(name,fn);}
  removeEventListener(name){this.listeners.delete(name);}
  setAttribute(key,val){this.attrs[key]=val;}
  removeAttribute(key){delete this.attrs[key];}
  focus(){globalThis.focused=this.id;}
  dispatch(name,event={}){return this.listeners.get(name)?.(event);}
}
function deferred(){let resolve,reject;const promise=new Promise((yes,no)=>{resolve=yes;reject=no;});return{promise,resolve,reject};}
const flush=()=>new Promise(resolve=>setImmediate(resolve));
async function setup() {
  const nodes = new Map([...html.matchAll(/id="([^"]+)"/g)].map(x=>[x[1],new Element(x[1])]));
  const windowListeners=new Map();
  globalThis.document={getElementById:id=>nodes.get(id)};
  globalThis.window={addEventListener:(name,fn)=>windowListeners.set(name,fn),removeEventListener:name=>windowListeners.delete(name)};
  let callback;
  const calls={reads:0,email:0,google:0,signOut:0,reload:0};
  const user={emailVerified:true,maskedEmail:'sa***@example.invalid',methods:['メール/パスワード'],isNewUser:false};
  const summary={nickname:'本人ニックネーム',maskedEmail:user.maskedEmail,methods:user.methods,billingLabel:'未契約',trialLabel:'サーバー保存状態：active',unavailableFields:[]};
  const service={ready:async()=>{},onAuthChanged:cb=>{callback=cb;cb(null);return()=>{};},readAccountSummary:async()=>{calls.reads++;return summary;},signInEmail:async()=>{calls.email++;callback(user);},signInGoogle:async()=>{calls.google++;callback(user);},signOut:async()=>{calls.signOut++;callback(null);},reloadUser:async()=>{calls.reload++;callback(user);},safeError:()=> '通信に失敗しました。'};
  const cleanup=await mountAccountPage(service);
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
 const h=await setup();h.emit({...h.user,emailVerified:false});await flush();assert.equal(h.calls.reads,0);assert.equal(h.el('verification-panel').hidden,false);h.el('review-plan').dispatch('click');assert.equal(h.el('pending-panel').hidden,true);h.cleanup();
});
test('verified owner summary and pending-only plan screen',async()=>{
 const h=await setup();h.emit(h.user);await flush();assert.equal(h.el('account-panel').hidden,false);assert.equal(h.el('account-nickname').textContent,'本人ニックネーム');assert.equal(h.el('account-email').textContent,h.user.maskedEmail);h.el('review-plan').dispatch('click');assert.equal(h.el('pending-panel').hidden,false);h.el('back-to-account').dispatch('click');assert.equal(h.el('account-panel').hidden,false);h.cleanup();
});
test('missing nickname and denied fields are explicit, not entitlement inference',async()=>{
 const h=await setup();h.summary.nickname='';h.summary.billingLabel='';h.summary.unavailableFields=['契約状態'];h.emit(h.user);await flush();assert.equal(h.el('account-nickname').textContent,'未設定');assert.equal(h.el('account-billing').textContent,'確認できませんでした');assert.match(h.el('unavailable-fields').textContent,/利用可能・未契約とは判定していません/);h.cleanup();
});
test('new Google account warning and plan button are guarded',async()=>{
 const h=await setup();h.emit({...h.user,isNewUser:true});await flush();assert.equal(h.el('new-google-note').hidden,false);assert.equal(h.el('review-plan').disabled,true);h.el('review-plan').dispatch('click');assert.equal(h.el('pending-panel').hidden,true);h.cleanup();
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
 assert.match(html,/<form[^>]+method="post"/);assert.doesNotMatch(html,/<input[^>]+name=/);assert.match(html,/<fieldset id="email-fields" disabled>/);assert.doesNotMatch(html,/type="(?:number|tel)"|stripe|createUserWithEmailAndPassword|console\./i);
});
