import {isVerifiedAccountIdentity} from './account-identity.mjs';
import {billingContactError, normalizeBillingEmail, projectBillingContact} from './billing-contact-model.mjs';

/** A confirmation link is consumed only by an explicit, authenticated POST. */
export async function mountBillingContactPage(contactService, {
  accountService, initialToken = null, initialError = null, document = globalThis.document,
  window = globalThis.window, now = () => Date.now(), setIntervalFn = globalThis.setInterval,
  clearIntervalFn = globalThis.clearInterval,
} = {}) {
  const el = id => document.getElementById(id);
  const panels = ['contact-loading-panel','contact-login-panel','contact-unverified-panel','contact-editor-panel','contact-confirm-panel','contact-complete-panel','contact-blocked-panel'];
  const events = [];
  let token = initialToken, model = null, currentUser = null, epoch = 0, busy = true,
    destroyed = false, editing = false, lastRequestEmail = null, timer = null, unsubscribe = () => {};
  const listen = (id, name, handler) => {el(id).addEventListener(name,handler);events.push([el(id),name,handler]);};
  const setPanel = (id, title = null) => {for(const panel of panels) el(panel).hidden = panel !== id;if(title)el(title).focus();};
  const clearError = () => {el('contact-error').textContent='';el('contact-error').hidden=true;el('billing-contact-email').removeAttribute('aria-invalid');};
  const error = cause => {el('contact-error').textContent=billingContactError(cause);el('contact-error').hidden=false;el('contact-error').focus();};
  const current = (generation, user) => !destroyed && generation === epoch && user === currentUser;
  const editingAllowed = () => currentUser && model?.category === 'missing' && (!model.canCheckout || editing || model.pendingMaskedEmail);

  function cooldown() {
    const remaining = model?.resendAfter ? Math.max(0,Math.ceil((Date.parse(model.resendAfter)-now())/1000)) : 0;
    el('contact-resend').disabled = busy || !lastRequestEmail || !model?.pendingMaskedEmail || remaining > 0;
    el('contact-resend-note').textContent = model?.pendingMaskedEmail
      ? remaining > 0 ? `${remaining}秒後に再送できます。` : lastRequestEmail ? '同じアドレスへ確認メールを再送できます。' : '再送する場合は、同じメールアドレスをもう一度入力してください。'
      : '';
  }
  function controls() {
    el('contact-login-fields').disabled = busy;
    el('contact-google').disabled = busy;
    el('contact-apple-consent').disabled = busy || accountService?.appleSignInEnabled !== true;
    el('contact-apple').disabled = busy || accountService?.appleSignInEnabled !== true || !el('contact-apple-consent').checked;
    el('billing-contact-fields').disabled = busy || !editingAllowed();
    for(const id of ['contact-refresh','contact-blocked-refresh','contact-reload-auth','contact-logout','contact-change'])el(id).disabled=busy;
    el('contact-confirm').disabled = busy || !token;
    cooldown();
  }
  function clearPersonal() {
    model=null;editing=false;lastRequestEmail=null;
    for(const id of ['contact-active-note','contact-pending-note','contact-complete-email','contact-confirm-account','contact-status'])el(id).textContent='';
    el('billing-contact-email').value='';el('contact-login-email').value='';el('contact-login-password').value='';
    el('contact-apple-consent').checked=false;
    el('contact-session').hidden=true;
    if(timer!==null){clearIntervalFn(timer);timer=null;}
    contactService.clear();
  }
  function render(focus=false) {
    if(!model)return;
    el('contact-session').hidden=false;
    if(token){
      el('contact-confirm-account').textContent = '現在ログインしているHamCareアカウントで確認します。別のアカウントでは確認できません。';
      setPanel('contact-confirm-panel',focus?'contact-confirm-title':null);
    } else if(['invalid','unverified'].includes(model.state) || ['invalid','unverified'].includes(model.category)) {
      el('contact-blocked-copy').textContent = 'ログイン情報のメール状態を安全に確認できません。アプリで使用しているログイン方法とメール確認の状態を確認してください。';
      setPanel('contact-blocked-panel',focus?'contact-blocked-title':null);
    } else if(model.canCheckout && !editing && !model.pendingMaskedEmail) {
      el('contact-complete-email').textContent=model.maskedEmail;
      el('contact-complete-copy').textContent=model.source==='user_supplied'
        ? '確認した連絡先でプラン確認へ進めます。メールを変更しても契約の所有者は変わりません。この画面では契約は成立しません。'
        : 'すでに確認済みのメールを利用できます。追加のメール登録や個人の実メールの入力は必要ありません。この画面では契約は成立しません。';
      el('contact-change').hidden=model.source!=='user_supplied';
      setPanel('contact-complete-panel',focus?'contact-complete-title':null);
    } else {
      const expired=model.pendingMaskedEmail && model.expiresAt && Date.parse(model.expiresAt)<=now();
      const deliverySent=model.deliveryState==='sent';
      el('contact-title').textContent=expired?'確認リンクの期限が切れました':model.pendingMaskedEmail
        ? deliverySent?'確認メールをお送りしました':model.deliveryState==='failed'?'確認メールを送信できませんでした':'送信結果を確認しています'
        :model.canCheckout?'連絡用メールを変更':'連絡用メールを登録';
      el('contact-intro').textContent=model.pendingMaskedEmail
        ? expired ? '受信した確認リンクの有効期限が切れています。同じメールアドレスへ新しい確認メールを送ってください。'
        : !deliverySent ? model.deliveryState==='failed'?'確認メールは送信できませんでした。送信設定と再送可能な時刻を確認してから、あらためて送信してください。'
        : '送信結果が確定していません。メールの受信状況を確認し、すぐに再送せず、状態を再確認してください。'
        : '受信したメールの確認リンクを開いてください。リンクを開いた後、同じHamCareアカウントで確認を完了するとプラン確認へ進めます。'
        : model.canCheckout ? '新しいメールの確認が終わるまで、現在の確認済み連絡先を維持します。'
        : 'このアカウントには、確認済みの連絡用メールがありません。有料申込の前に、受信できるメールを確認します。';
      el('contact-active-note').hidden=!model.canCheckout;
      el('contact-active-note').textContent=model.canCheckout?'現在の確認済み連絡先：'+model.maskedEmail+'。新しいメールが未確認の間も、この連絡先を維持します。':'';
      el('contact-pending-note').hidden=!model.pendingMaskedEmail;
      el('contact-pending-note').textContent=model.pendingMaskedEmail?'確認する連絡先：'+model.pendingMaskedEmail+'。新しい確認メールを送ると、以前の確認リンクは無効になります。':'';
      setPanel('contact-editor-panel',focus?'contact-title':null);
    }
    if(timer!==null){clearIntervalFn(timer);timer=null;}
    if(model.pendingMaskedEmail) timer=setIntervalFn(cooldown,1000);
    controls();
  }
  async function loadStatus(focus=true) {
    if(busy || !currentUser || !isVerifiedAccountIdentity(currentUser))return;
    const generation=epoch,user=currentUser;busy=true;controls();
    try {
      const summary=await accountService.readAccountSummary();
      if(!current(generation,user))return;
      if(summary?.appAccountExists!==true)throw {code:'app_account_required'};
      const next=projectBillingContact(await contactService.getStatus());
      if(!current(generation,user))return;
      model=next;render(focus);
    } catch(cause) {
      if(!current(generation,user))return;
      el('contact-blocked-copy').textContent=billingContactError(cause);
      setPanel('contact-blocked-panel','contact-blocked-title');error(cause);
    } finally {if(current(generation,user)){busy=false;controls();}}
  }
  async function send(address) {
    if(busy || !editingAllowed())return;
    const email=normalizeBillingEmail(address);
    if(!email){el('billing-contact-email').setAttribute('aria-invalid','true');error({code:'contact_invalid_email'});el('billing-contact-email').focus();return;}
    const generation=epoch,user=currentUser;busy=true;clearError();controls();
    el('contact-status').textContent='';
    // A replacement attempt may invalidate the previous link before delivery.
    // Do not retain its old success claim while the new outcome is unknown.
    if(model?.pendingMaskedEmail){model=Object.freeze({...model,deliveryState:null});render();}
    try {
      const next=projectBillingContact(await contactService.requestVerification(email));
      if(!current(generation,user))return;
      if(next.state==='verified' && next.category==='missing' && next.canCheckout && next.source==='user_supplied' &&
          next.pendingMaskedEmail===null && next.resendAfter===null && next.expiresAt===null && next.deliveryState===null){
        model=next;editing=false;lastRequestEmail=null;el('billing-contact-email').value='';
        el('contact-status').textContent='この連絡用メールはすでに確認済みです。確認メールの送信は行っていません。';render(true);return;
      }
      if(!next.pendingMaskedEmail || !next.expiresAt || next.deliveryState!=='sent')throw {code:next.deliveryState==='uncertain'?'contact_delivery_unknown':'contact_invalid_response'};
      model=next;lastRequestEmail=email;el('billing-contact-email').value='';
      el('contact-status').textContent='確認メールを送信しました。メール内のリンクから確認してください。';render(true);
    } catch(cause){
      if(!current(generation,user))return;
      // Reconcile delivery without retrying the send. If this read also fails,
      // the old pending link remains visibly uncertain rather than "sent".
      try{
        const next=projectBillingContact(await contactService.getStatus());
        if(!current(generation,user))return;
        model=next;render();
      }catch{if(!current(generation,user))return;}
      error(cause);
    }
    finally {if(current(generation,user)){busy=false;controls();}}
  }
  async function signIn(action) {
    if(busy)return;
    busy=true;clearError();controls();
    try {await action();}
    catch(cause){if(!destroyed){el('contact-error').textContent=accountService.safeError?.(cause)||billingContactError(cause);el('contact-error').hidden=false;el('contact-error').focus();}}
    finally {el('contact-login-password').value='';el('contact-apple-consent').checked=false;if(!destroyed){busy=false;controls();}}
  }
  listen('billing-contact-form','submit',event=>{event.preventDefault();void send(el('billing-contact-email').value);});
  listen('contact-resend','click',()=>{if(!el('contact-resend').disabled && lastRequestEmail)void send(lastRequestEmail);});
  for(const id of ['contact-refresh','contact-blocked-refresh'])listen(id,'click',()=>{if(!busy){clearError();void loadStatus();}});
  listen('contact-change','click',()=>{if(!busy && model?.source==='user_supplied'){editing=true;render(true);el('billing-contact-email').focus();}});
  listen('contact-confirm','click',async()=>{
    if(busy || !token || !currentUser)return;
    const generation=epoch,user=currentUser,confirmationToken=token;
    busy=true;clearError();controls();
    try {
      const next=projectBillingContact(await contactService.confirmVerification(confirmationToken));
      if(!current(generation,user))return;
      token=null;model=next;editing=false;lastRequestEmail=null;
      el('contact-status').textContent='連絡用メールの確認が完了しました。';render(true);
    } catch(cause) {
      if(!current(generation,user))return;
      token=null;el('contact-blocked-copy').textContent=billingContactError(cause);setPanel('contact-blocked-panel','contact-blocked-title');error(cause);
    } finally {if(current(generation,user)){busy=false;controls();}}
  });
  listen('contact-login-form','submit',event=>{
    event.preventDefault();
    const email=normalizeBillingEmail(el('contact-login-email').value),password=el('contact-login-password').value;
    if(!email || !password){error({code:'contact_invalid_email'});return;}
    void signIn(()=>accountService.signInEmail(email,password));
  });
  listen('contact-google','click',()=>void signIn(()=>accountService.signInGoogle()));
  listen('contact-apple-consent','change',controls);
  listen('contact-apple','click',()=>{if(el('contact-apple-consent').checked && !el('contact-apple').disabled)void signIn(()=>accountService.signInApple({linkingConsent:true}));});
  listen('contact-reload-auth','click',async()=>{if(!busy){busy=true;controls();try{await accountService.reloadUser();}catch(cause){error(cause);}finally{if(!destroyed){busy=false;controls();}}}});
  listen('contact-logout','click',async()=>{
    if(busy)return;
    epoch++;token=null;currentUser=null;clearPersonal();clearError();busy=true;setPanel('contact-login-panel','contact-login-title');controls();
    try{await accountService.signOut();}catch(cause){error(cause);}finally{if(!destroyed){busy=false;controls();}}
  });
  const hide=()=>{epoch++;token=null;currentUser=null;busy=true;clearPersonal();setPanel('contact-loading-panel');controls();};
  const show=async event=>{if(event.persisted && !destroyed){try{await accountService.reloadUser();}catch(cause){error(cause);}}};
  window?.addEventListener('pagehide',hide);window?.addEventListener('pageshow',show);
  try {
    await accountService.ready();
    if(!destroyed) unsubscribe=accountService.onAuthChanged(user=>{
      // The safe Auth projection deliberately exposes no UID. After a session
      // was established, any new Auth publication must drop the link proof;
      // the user can reopen the mail link after the current account is stable.
      if(currentUser)token=null;
      epoch++;clearPersonal();currentUser=user;
      busy=false;clearError();el('contact-session').hidden=!user;
      if(!user){setPanel('contact-login-panel');controls();return;}
      if(!isVerifiedAccountIdentity(user)){setPanel('contact-unverified-panel','contact-unverified-title');controls();return;}
      setPanel('contact-loading-panel');controls();void loadStatus();
    });
  } catch(cause){busy=false;el('contact-blocked-copy').textContent=billingContactError(cause);setPanel('contact-blocked-panel');error(cause);}
  if(initialError)error({code:initialError});
  return () => {
    destroyed=true;epoch++;token=null;currentUser=null;unsubscribe();clearPersonal();
    for(const [node,name,handler]of events)node.removeEventListener(name,handler);
    window?.removeEventListener('pagehide',hide);window?.removeEventListener('pageshow',show);
  };
}
