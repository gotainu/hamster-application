import { PREMIUM_MONTHLY } from './plan-model.mjs';
import { projectCheckoutReview, projectCheckoutSession, projectCheckoutStatus, projectPreviewBilling, checkoutErrorMessage } from './checkout-model.mjs';

let stripeScriptPromise;
export async function loadStripeSdk(publishableKey) {
  if (!/^pk_test_[A-Za-z0-9]{8,}$/.test(publishableKey)) throw { code: 'preview/mode-mismatch' };
  if (typeof window.Stripe !== 'function') {
    stripeScriptPromise ??= new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://js.stripe.com/v3/';
      script.async = true;
      script.onload = () => typeof window.Stripe === 'function' ? resolve() : reject({ code: 'preview/stripe-load-failed' });
      script.onerror = () => reject({ code: 'preview/stripe-load-failed' });
      document.head.appendChild(script);
    }).catch(cause => { stripeScriptPromise = undefined; throw cause; });
    await stripeScriptPromise;
  }
  return window.Stripe(publishableKey, { locale: 'ja' });
}

const previewBillingFields = { state: 'statusLabel', plan: 'planLabel', amount: 'amountLabel', 'first-charge': 'firstChargeLabel', 'next-charge': 'nextChargeLabel', 'period-start': 'periodStartLabel', 'period-end': 'periodEndLabel', 'trial-end': 'trialEndLabel', cancel: 'cancelLabel', 'synced-at': 'syncedAtLabel', entitlement: 'entitlementLabel' };
export function clearPreviewBilling(prefix, message = 'Preview契約状態はまだ確認していません。') {
  document.getElementById(prefix + '-status').textContent = message;
  document.getElementById(prefix + '-details').hidden = true;
  for (const suffix of Object.keys(previewBillingFields)) document.getElementById(prefix + '-' + suffix).textContent = '';
}
export function renderPreviewBilling(prefix, model) {
  document.getElementById(prefix + '-status').textContent = model.title + ' ' + model.copy;
  document.getElementById(prefix + '-details').hidden = model.state !== 'synced';
  for (const [suffix, key] of Object.entries(previewBillingFields)) document.getElementById(prefix + '-' + suffix).textContent = model.state === 'synced' ? model[key] : '';
}

/** Tokens stay in the account service. Card fields stay exclusively in Stripe's iframe. */
export function createCheckoutController({ service, onShow, onBack, loadStripe = loadStripeSdk, onBillingUpdate = () => {}, timers = globalThis }) {
  const el = id => document.getElementById(id);
  const personal = ['checkout-account-name', 'checkout-account-email', 'checkout-plan-name', 'checkout-amount', 'checkout-card-date', 'checkout-first-charge-date', 'checkout-first-charge-amount', 'checkout-trial-note'];
  const terms = el('checkout-terms');
  let epoch = 0;
  let destroyed = false;
  let phase = 'idle';
  let review = null;
  let embedded = null;
  let sessionKnown = false;
  let completionPending = false;
  let stripeOperationComplete = false;
  let syncEpoch = 0;
  let syncRunning = false;
  let nextSyncTimer = null;
  let syncDeadlineTimer = null;
  const busy = () => ['reviewing', 'creating', 'checking', 'canceling'].includes(phase);
  const terminal = () => ['complete', 'expired', 'canceled', 'none'].includes(phase);
  const current = generation => !destroyed && epoch === generation;

  function controls() {
    el('checkout-start').disabled = phase !== 'review' || !terms.checked;
    el('checkout-start').hidden = phase !== 'review';
    terms.disabled = phase !== 'review';
    el('checkout-back').disabled = busy();
    el('checkout-cancel').disabled = busy() || !sessionKnown || terminal() || stripeOperationComplete;
    el('checkout-refresh').disabled = busy() || syncRunning || (terminal() && !stripeOperationComplete);
    el('checkout-refresh').textContent = stripeOperationComplete ? 'Preview契約状態を再確認する' : sessionKnown ? '支払い状況を再確認する' : '申込内容を再確認する';
    el('checkout-panel').setAttribute('aria-busy', String(busy()));
  }
  function setPhase(value, message = '') {
    phase = value;
    el('checkout-status').textContent = message;
    controls();
  }
  function clearError() {
    el('checkout-error').textContent = '';
    el('checkout-error').hidden = true;
  }
  function showError(cause) {
    el('checkout-error').textContent = checkoutErrorMessage(cause);
    el('checkout-error').hidden = false;
    el('checkout-error').focus();
  }
  function destroyEmbedded() {
    try { embedded?.destroy(); } catch { /* Never log SDK payloads. */ }
    embedded = null;
    el('checkout-embed').replaceChildren();
    el('checkout-payment').hidden = true;
  }
  function stopBillingSync() {
    syncEpoch++;
    syncRunning = false;
    if (nextSyncTimer !== null) timers.clearTimeout(nextSyncTimer);
    if (syncDeadlineTimer !== null) timers.clearTimeout(syncDeadlineTimer);
    nextSyncTimer = null;
    syncDeadlineTimer = null;
  }
  function clear() {
    epoch++;
    stopBillingSync();
    stripeOperationComplete = false;
    clearPreviewBilling('checkout-preview');
    el('checkout-preview-panel').hidden = true;
    destroyEmbedded();
    review = null;
    sessionKnown = false;
    completionPending = false;
    terms.checked = false;
    for (const id of personal) el(id).textContent = '';
    el('checkout-result-title').textContent = '';
    el('checkout-result-copy').textContent = '';
    el('checkout-result').hidden = true;
    el('checkout-review').hidden = false;
    clearError();
    setPhase('idle');
  }
  function renderReview(value) {
    const fields = {
      'checkout-account-name': value.nickname,
      'checkout-account-email': value.maskedEmail,
      'checkout-plan-name': value.planName,
      'checkout-amount': value.amountLabel,
      'checkout-card-date': value.cardRegistrationLabel,
      'checkout-first-charge-date': value.firstChargeLabel,
      'checkout-first-charge-amount': value.firstChargeAmountLabel,
      'checkout-trial-note': value.trialNote,
    };
    for (const [id, text] of Object.entries(fields)) el(id).textContent = text;
  }
  function startBillingSync() {
    stopBillingSync();
    syncRunning = true;
    const generation = epoch;
    const run = syncEpoch;
    let attempts = 0;
    const isCurrent = () => current(generation) && run === syncEpoch;
    el('checkout-preview-panel').hidden = false;
    const pending = projectPreviewBilling({ testMode: true, syncState: 'pending' });
    renderPreviewBilling('checkout-preview', pending);
    el('checkout-result-title').textContent = pending.title;
    el('checkout-result-copy').textContent = pending.copy;
    el('checkout-result').hidden = false;
    setPhase('syncing');
    const timeout = () => {
      if (!isCurrent()) return;
      stopBillingSync();
      el('checkout-result-title').textContent = '契約状態の確認に時間がかかっています';
      el('checkout-result-copy').textContent = '支払い処理は完了している可能性がありますが、契約状態の確認に時間がかかっています。再確認するか、サポートへお問い合わせください。Preview専用のため、HamCareアプリの本番利用権限には反映されません。';
      setPhase('sync-timeout');
    };
    syncDeadlineTimer = timers.setTimeout(timeout, 30000);
    const read = async () => {
      if (!isCurrent()) return;
      attempts++;
      try {
        const raw = await service.getPreviewBilling();
        if (!isCurrent()) return;
        const model = projectPreviewBilling(raw);
        renderPreviewBilling('checkout-preview', model);
        onBillingUpdate(model);
        if (model.state === 'synced') {
          stopBillingSync();
          el('checkout-result-title').textContent = model.title;
          el('checkout-result-copy').textContent = model.copy;
          setPhase('synced');
          el('checkout-result-title').focus();
          return;
        }
      } catch {
        if (!isCurrent()) return;
        clearPreviewBilling('checkout-preview', 'Preview契約状態を取得できません。反映を再確認しています。');
      }
      if (!isCurrent()) return;
      if (attempts >= 6) { timeout(); return; }
      nextSyncTimer = timers.setTimeout(() => { nextSyncTimer = null; void read(); }, 5000);
    };
    void read();
  }
  function presentStatus(value) {
    if (value.terminal) {
      destroyEmbedded();
      review = null;
      terms.checked = false;
      el('checkout-review').hidden = true;
    }
    if (value.state === 'complete') {
      stripeOperationComplete = true;
      startBillingSync();
      return;
    }
    if (value.state === 'open' && embedded) {
      el('checkout-result').hidden = true;
      setPhase('embedded', value.copy);
      return;
    }
    el('checkout-result-title').textContent = value.title;
    el('checkout-result-copy').textContent = value.state === 'open'
      ? 'Stripeの支払い操作はまだ完了していません。以前の画面を自動で再利用せず、キャンセルしてプラン確認からやり直してください。'
      : value.copy;
    el('checkout-result').hidden = false;
    setPhase(value.terminal ? value.state : value.state === 'processing' ? 'processing' : embedded ? 'embedded' : 'error');
    el('checkout-result-title').focus();
  }
  async function open() {
    if (destroyed || busy()) return;
    clear();
    const generation = epoch;
    onShow();
    setPhase('reviewing', 'サーバーで契約対象・体験終了日時・請求内容を確認しています。');
    try {
      const response = await service.reviewPreviewCheckout();
      if (!current(generation)) return;
      review = projectCheckoutReview(response);
      renderReview(review);
      setPhase('review', '内容と規約をご確認ください。まだテスト決済は開始していません。');
      el('checkout-title').focus();
    } catch (cause) {
      if (!current(generation)) return;
      review = null;
      setPhase('error');
      showError(cause);
    }
  }
  async function checkStatus() {
    if (destroyed || !sessionKnown) return;
    if (stripeOperationComplete) { if (!syncRunning) startBillingSync(); return; }
    if (busy()) { completionPending = true; return; }
    const generation = epoch;
    clearError();
    setPhase('checking', 'Stripe Test Modeの支払い状況を確認しています。');
    try {
      const response = await service.getPreviewCheckoutStatus();
      if (!current(generation)) return;
      presentStatus(projectCheckoutStatus(response));
    } catch (cause) {
      if (!current(generation)) return;
      setPhase('error');
      showError(cause);
    }
  }
  async function start() {
    if (destroyed || phase !== 'review' || !review || !terms.checked) return;
    const generation = epoch;
    const reviewToken = review.reviewToken;
    clearError();
    setPhase('creating', 'Stripe Test Modeの安全な支払い画面を準備しています。');
    // A lost response does not prove that the server did not create a Session.
    // From dispatch onward, status/cancel must reconcile the result before return.
    sessionKnown = true;
    try {
      const raw = await service.createPreviewCheckout({ planKey: PREMIUM_MONTHLY.key, reviewToken, termsAccepted: true });
      if (!current(generation)) return;
      const session = projectCheckoutSession(raw);
      const stripe = await loadStripe(session.publishableKey);
      if (!current(generation)) return;
      const instance = await stripe.initEmbeddedCheckout({
        clientSecret: session.clientSecret,
        onComplete: () => {
          if (!current(generation)) return;
          completionPending = true;
          if (!busy()) { completionPending = false; void checkStatus(); }
        },
      });
      if (!current(generation)) { try { instance.destroy(); } catch { /* No logging. */ } return; }
      destroyEmbedded();
      embedded = instance;
      el('checkout-payment').hidden = false;
      setPhase('embedded', 'Stripe Test Modeです。実際のカードは使わず、公式のテスト用カードだけをご利用ください。');
      embedded.mount(el('checkout-embed'));
      if (completionPending) { completionPending = false; void checkStatus(); }
    } catch (cause) {
      if (!current(generation)) return;
      terms.checked = false;
      setPhase('error');
      showError(cause);
    }
  }
  async function cancel({ back = false } = {}) {
    if (destroyed || busy()) return;
    if (!sessionKnown || terminal() || stripeOperationComplete) {
      clear();
      await onBack();
      return;
    }
    const generation = epoch;
    clearError();
    destroyEmbedded();
    setPhase('canceling', '支払い画面を閉じ、テスト決済の状況を確認しています。');
    try {
      const response = await service.cancelPreviewCheckout();
      if (!current(generation)) return;
      const value = projectCheckoutStatus(response);
      if (value.state === 'canceled' || value.state === 'expired') {
        if (back) { clear(); await onBack(); } else presentStatus(value);
      } else presentStatus(value);
    } catch (cause) {
      if (!current(generation)) return;
      setPhase('error');
      showError(cause);
    }
  }
  async function resume() {
    if (destroyed || busy()) return;
    clear();
    onShow();
    sessionKnown = true;
    el('checkout-review').hidden = true;
    await checkStatus();
  }
  const onTerms = () => { if (phase === 'review') { clearError(); controls(); } };
  const onStart = () => { void start(); };
  const onRefresh = () => { if (busy() || syncRunning) return; if (stripeOperationComplete) startBillingSync(); else if (!terminal()) void (sessionKnown ? checkStatus() : open()); };
  const onCancel = () => { void cancel(); };
  const onBackClick = () => { void cancel({ back: true }); };
  terms.addEventListener('change', onTerms);
  el('checkout-start').addEventListener('click', onStart);
  el('checkout-refresh').addEventListener('click', onRefresh);
  el('checkout-cancel').addEventListener('click', onCancel);
  el('checkout-back').addEventListener('click', onBackClick);
  clear();
  return Object.freeze({
    open, resume, clear,
    destroy() {
      clear();
      destroyed = true;
      terms.removeEventListener('change', onTerms);
      el('checkout-start').removeEventListener('click', onStart);
      el('checkout-refresh').removeEventListener('click', onRefresh);
      el('checkout-cancel').removeEventListener('click', onCancel);
      el('checkout-back').removeEventListener('click', onBackClick);
    },
  });
}
