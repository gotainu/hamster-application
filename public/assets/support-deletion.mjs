import {consumeSupportDeletionLink, canUseSupportDeletion, createSupportDeletionService} from './support-deletion-service.mjs';
import {firebaseConfig} from './firebase-web-config.mjs';

export function supportDeletionError(error) {
  if (error?.code === 'manual_apple_required') return 'Apple連携の自動解除を確認できませんでした。手動解除の案内を確認し、削除を希望する場合は確認欄を選んで、もう一度記録してください。';
  if (error?.code === 'intent_required') return '削除の内容を確認し、削除を希望する場合は確認欄を選んでください。';
  if (error?.code === 'consent_required') return 'Appleログイン前の説明と確認欄をご確認ください。';
  if (['auth/popup-closed-by-user', 'auth/cancelled-popup-request'].includes(error?.code)) return 'ログインを中止しました。必要な場合は、いつものログイン方法でやり直してください。';
  return 'この申請の本人確認を完了できませんでした。リンクの期限や使用状況、ログイン方法をサポートにご確認ください。パスワードや確認用リンクは送らないでください。';
}

export async function mountSupportDeletionPage({doc, service, link}) {
  const el = id => doc.getElementById(id);
  let busy = false, verified = false;
  const controls = ['support-email-fields', 'support-google', 'support-apple', 'support-apple-consent', 'support-confirm', 'support-logout', 'support-login-logout'];
  const lock = value => {busy = value; for (const id of controls) el(id).disabled = value;};
  const error = value => {el('request-error').hidden = false; el('request-error').textContent = supportDeletionError(value);};
  async function act(work) {
    if (busy || verified) return;
    lock(true); el('request-error').hidden = true;
    try {await work();} catch (reason) {
      if (reason?.code === 'manual_apple_required') {
        el('support-manual-choice').hidden = false;
        el('support-manual-ack').disabled = false;
      }
      error(reason);
    }
    finally {lock(false);}
  }
  async function inspect() {
    const result = await service.inspect(link);
    el('verification-controls').hidden = true;
    el('deletion-intent-panel').hidden = false;
    el('support-apple-manual').hidden = !result.appleLinked;
    el('support-manual-choice').hidden = true;
    el('support-manual-ack').disabled = true;
    el('support-manual-ack').checked = false;
    el('verified-account').textContent = result.appleLinked ? 'この申請に指定された、Apple連携のあるアカウントを確認しました。メールアドレスの登録は、削除の条件ではありません。' : 'この申請に指定されたアカウントを確認しました。';
    el('request-status').textContent = '本人確認ができました。削除の内容と、この申請で削除を希望する意思を確認してください。';
  }
  if (!link) {el('request-status').textContent = '申請用リンクを確認できませんでした。運営から届いたリンクを開き直すか、申請メールへご返信ください。'; return;}
  await service.ready();
  el('verification-controls').hidden = false;
  el('request-status').textContent = '申請に指定されたアカウントへ、いつもの方法でログインしてください。既にログインしている場合も、改めて本人確認を行います。';
  lock(false);
  el('support-email-form').addEventListener('submit', event => {
    event.preventDefault();
    void act(async () => {
      const password = el('support-password').value;
      el('support-password').value = '';
      await service.signInEmail(el('support-email').value, password); await inspect();
    });
  });
  el('support-google').addEventListener('click', () => void act(async () => {await service.signInSocial('google'); await inspect();}));
  el('support-login-logout').addEventListener('click', () => void act(async () => {await service.signOut(); el('request-status').textContent = 'ログアウトしました。HamCareで使っていたアカウントで確認してください。';}));
  el('support-apple').addEventListener('click', () => void act(async () => {await service.signInSocial('apple', el('support-apple-consent').checked); await inspect();}));
  el('support-confirm').addEventListener('click', () => void act(async () => {
    await service.confirm(link, {intent: el('support-intent').checked, manualAppleAcknowledged: el('support-manual-ack').checked});
    verified = true;
    el('deletion-intent-panel').hidden = true;
    el('support-verified').hidden = false;
    el('request-status').textContent = '本人確認と削除の意思を記録しました。削除の完了は、運営から別途ご案内します。';
  }));
  el('support-logout').addEventListener('click', () => void act(async () => {
    await service.signOut();
    el('deletion-intent-panel').hidden = true;
    el('verification-controls').hidden = false;
    el('support-intent').checked = false; el('support-manual-ack').checked = false;
    el('request-status').textContent = 'ログアウトしました。再開する場合は、同じアカウントで本人確認してください。';
  }));
}

if (typeof document !== 'undefined') {
  // Do this before any authentication SDK import. Never store the proof in browser storage.
  const link = consumeSupportDeletionLink(globalThis.location, globalThis.history);
  if (!canUseSupportDeletion(globalThis.location?.origin)) {
    document.getElementById('request-status').textContent = 'この確認機能は公開前のため停止しています。Previewではログイン・Apple連携解除・申請情報の送信・削除を行いません。メールでの削除申請は、案内ページから受け付けています。';
  } else {
    try {
      const [appSDK, authSDK] = await Promise.all([
        import('https://www.gstatic.com/firebasejs/12.17.1/firebase-app.js'),
        import('https://www.gstatic.com/firebasejs/12.17.1/firebase-auth.js'),
      ]);
      appSDK.setLogLevel('silent');
      const app = appSDK.initializeApp(firebaseConfig, {name: 'hamcare-support-deletion', automaticDataCollectionEnabled: false});
      const auth = authSDK.initializeAuth(app, {persistence: authSDK.browserSessionPersistence, popupRedirectResolver: authSDK.browserPopupRedirectResolver});
      auth.languageCode = 'ja';
      await mountSupportDeletionPage({doc: document, link, service: createSupportDeletionService({auth, sdk: authSDK})});
    } catch {
      document.getElementById('request-status').textContent = '現在、本人確認画面を準備できません。申請メールへの返信でサポートにお知らせください。';
    }
  }
}
