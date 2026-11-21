import { isVerifiedAccountIdentity } from './account-identity.mjs';
import { createCheckoutController, clearPreviewBilling, renderPreviewBilling } from './checkout-view.mjs';
import { projectPreviewBilling, projectPreviewPortalSession, portalErrorMessage } from './checkout-model.mjs';
import { PREMIUM_MONTHLY, projectPlanReview } from './plan-model.mjs';
import { projectBillingContact, billingContactError } from './billing-contact-model.mjs';

/** Presentation only. Firebase identifiers and credentials stay inside the service. */
export async function mountAccountPage(service, { checkoutService = null, contactService = null, resumeCheckout = false } = {}) {
  const element = (id) => document.getElementById(id);
  const panels = ['loading-panel', 'login-panel', 'verification-panel', 'account-panel', 'plan-panel', 'checkout-panel'];
  const personalFields = ['verification-email', 'account-nickname', 'account-email', 'account-method', 'account-billing', 'account-trial', 'unavailable-fields', 'plan-nickname', 'plan-email', 'plan-method', 'plan-billing', 'plan-trial', 'plan-customer-check', 'plan-checkout-check', 'plan-route-title', 'plan-route-detail'];
  const form = element('email-form');
  const email = element('email');
  const password = element('password');
  const appleConsent = element('apple-linking-consent');
  const error = element('auth-error');
  const status = element('auth-status');
  let epoch = 0;
  let currentUser = null;
  let currentSummary = null;
  let busy = true;
  let loggingOut = false;
  let signInPending = false;
  let signInAttempt = null;
  let errorGeneration = 0;
  let unsubscribe = () => {};
  let destroyed = false;
  let checkout = null;
  let portalReturnPending = window.location?.pathname === '/account/' && new URLSearchParams(window.location?.search || '').get('portal') === 'return';
  if (portalReturnPending) window.history?.replaceState(null, '', '/account/');
  let resumePending = resumeCheckout && !portalReturnPending;
  let previewRead = 0;
  let previewModel = null;
  let previewReading = false;
  let portalOpening = false;
  let contactRead = 0;
  let contactChecking = false;
  const portalFields = { plan: 'planLabel', amount: 'amountLabel', state: 'statusLabel', 'next-charge': 'nextChargeLabel', cancel: 'cancelLabel', 'period-end': 'periodEndLabel', access: 'accessLabel', 'synced-at': 'syncedAtLabel' };
  const previewPrefixes = ['account-preview', 'plan-preview'];

  function setPanel(id, heading) {
    for (const panel of panels) element(panel).hidden = panel !== id;
    element('main').setAttribute('data-page', ['plan-panel','checkout-panel'].includes(id) ? 'plan' : 'account');
    if (heading) element(heading).focus();
  }

  function clearPersonal() {
    currentSummary = null;
    resetAppleConsent();
    previewRead++;
    portalOpening = false;
    previewReading = false;
    clearPortal();
    element('account-portal-return-status').textContent = '';
    element('account-portal-return-status').hidden = true;
    for (const prefix of previewPrefixes) { clearPreviewBilling(prefix); element(prefix + '-refresh').disabled = true; }
    checkout?.clear();
    checkoutService?.clear();
    contactRead++;
    contactChecking = false;
    contactService?.clear();
    element('account-contact-panel').hidden = true;
    element('account-contact-status').textContent = '';
    element('account-contact-email').textContent = '';
    element('account-contact-link').textContent = '連絡用メールを確認する';
    element('plan-checkout').disabled = true;
    for (const id of personalFields) element(id).textContent = '';
    element('premium-monthly').checked = false;
    element('plan-fields').disabled = true;
    element('plan-management').hidden = true;
    element('plan-selected-name').textContent = '未選択';
    element('plan-selected-amount').textContent = 'プランを選ぶと表示します';
    element('plan-selection-status').textContent = 'プランはまだ選択していません。';
    element('unavailable-fields').hidden = true;
    element('new-google-note').hidden = true;
    element('account-registration-note').hidden = true;
    element('account-registration-note').textContent = '';
  }

  function clearError() {
    errorGeneration++;
    error.textContent = '';
    error.hidden = true;
    email.removeAttribute('aria-invalid');
    password.removeAttribute('aria-invalid');
  }

  function showError(message) {
    errorGeneration++;
    error.textContent = message;
    error.hidden = false;
    error.focus();
  }

  function setBusy(value, message = '') {
    busy = value;
    element('email-fields').disabled = value;
    for (const id of ['google-signin', 'refresh-account', 'check-verification']) element(id).disabled = value;
    updateAppleControl();
    element('review-plan').disabled = value || contactChecking || Boolean(currentUser?.isNewUser) || currentSummary?.appAccountExists !== true;
    form.setAttribute('aria-busy', String(value));
    status.textContent = message;
  }

  function updateAppleControl() {
    const unavailable = busy || loggingOut || signInPending || service.appleSignInEnabled !== true;
    appleConsent.disabled = unavailable;
    element('apple-signin').disabled = unavailable || appleConsent.checked !== true;
  }
  function resetAppleConsent() {
    appleConsent.checked = false;
    appleConsent.removeAttribute('aria-invalid');
    updateAppleControl();
  }

  function resetPassword() {
    password.value = '';
    password.type = 'password';
    element('toggle-password').textContent = '表示';
    element('toggle-password').setAttribute('aria-pressed', 'false');
  }

  function renderPlan(summary) {
    const review = summary.planReview || projectPlanReview(null);
    element('plan-nickname').textContent = summary.nickname || '未設定';
    element('plan-email').textContent = summary.maskedEmail || currentUser.maskedEmail || '確認できませんでした';
    element('plan-method').textContent = (summary.methods || currentUser.methods || []).join('・') || '確認できませんでした';
    element('plan-billing').textContent = summary.billingLabel || '確認できませんでした';
    element('plan-trial').textContent = summary.trialLabel || '確認できませんでした';
    element('plan-customer-check').textContent = review.customerRecord;
    element('plan-checkout-check').textContent = review.checkoutCheck;
    element('plan-route-title').textContent = review.title;
    element('plan-route-detail').textContent = review.detail;
    element('plan-fields').disabled = !review.canSelectPlan;
    element('plan-management').hidden = review.route === 'review';
    if (!review.canSelectPlan) {
      element('plan-selected-name').textContent = '現在の契約の確認を優先します';
      element('plan-selected-amount').textContent = '上記は新規プランの参考価格です';
      element('plan-selection-status').textContent = 'プラン選択はできません。Webの契約管理の案内またはサポートで現在の契約を確認してください。';
    }
  }

  function clearPortal() {
    previewModel = null;
    element('account-portal-panel').hidden = true;
    element('account-portal-open').hidden = true;
    element('account-portal-open').disabled = true;
    element('account-portal-status').textContent = '';
    for (const suffix of Object.keys(portalFields)) element('account-portal-' + suffix).textContent = '';
  }
  function renderContact(model) {
    element('account-contact-panel').hidden = false;
    element('account-contact-email').textContent = model.maskedEmail || model.pendingMaskedEmail || '未設定';
    element('account-contact-status').textContent = model.canCheckout
      ? model.pendingMaskedEmail ? '確認済みの連絡先を維持しています。変更先のメールは確認待ちです。' : '確認済みの連絡先を利用できます。追加の実メール登録は必要ありません。'
      : model.state === 'pending'
        ? model.deliveryState === 'sent' ? '確認メールのリンクから確認を完了してください。'
          : model.deliveryState === 'failed' ? '確認メールを送信できませんでした。送信設定と再送可能な時刻を確認してください。' : '確認メールの送信結果を確認しています。'
        : '新規の有料申込前に、確認済みの連絡用メールが必要です。';
    element('account-contact-link').textContent = model.canCheckout ? model.source === 'user_supplied' ? '連絡用メールを確認・変更する' : '連絡先の確認状態を見る' : '連絡用メールを登録・確認する';
  }
  async function refreshContactStatus() {
    if (!contactService || !isVerifiedAccountIdentity(currentUser) || currentUser.isNewUser || currentSummary?.appAccountExists !== true || destroyed) return;
    const request = ++contactRead, generation = epoch, user = currentUser;
    element('account-contact-panel').hidden = false;
    element('account-contact-status').textContent = '連絡用メールの状態を確認しています。';
    try {
      const model = projectBillingContact(await contactService.getStatus());
      if (destroyed || generation !== epoch || request !== contactRead || user !== currentUser) return;
      renderContact(model);
    } catch {
      if (destroyed || generation !== epoch || request !== contactRead || user !== currentUser) return;
      element('account-contact-email').textContent = '';
      element('account-contact-status').textContent = '連絡用メールの状態を確認できません。新規申込前に再確認してください。既存契約の管理は引き続き利用できます。';
    }
  }
  async function checkContactBeforePurchase() {
    if (!contactService) return true;
    if (contactChecking) return false;
    const request = ++contactRead, generation = epoch, user = currentUser;
    contactChecking = true;
    element('review-plan').disabled = true;
    element('plan-checkout').disabled = true;
    try {
      const model = projectBillingContact(await contactService.getStatus());
      if (destroyed || generation !== epoch || request !== contactRead || user !== currentUser || !isVerifiedAccountIdentity(currentUser)) return false;
      renderContact(model);
      if (!model.canCheckout) { window.location.assign('/account/contact/'); return false; }
      return true;
    } catch (cause) {
      if (destroyed || generation !== epoch || request !== contactRead || user !== currentUser) return false;
      element('account-contact-panel').hidden = false;
      element('account-contact-status').textContent = '連絡用メールを確認できないため、新規申込を停止しています。既存契約の管理は利用できます。';
      showError(billingContactError(cause));
      return false;
    } finally {
      if (!destroyed && generation === epoch && request === contactRead && user === currentUser) {
        contactChecking = false;
        element('review-plan').disabled = busy || Boolean(currentUser?.isNewUser) || currentSummary?.appAccountExists !== true;
        element('plan-checkout').disabled = !checkout || busy || !element('premium-monthly').checked || previewReading || Boolean(previewModel?.portalManageable) || !currentSummary?.planReview?.canSelectPlan;
      }
    }
  }
  function renderPortal(model) {
    previewModel = model;
    element('account-portal-panel').hidden = !model.managementCardVisible;
    element('account-portal-open').hidden = !model.portalManageable;
    element('account-portal-open').disabled = !model.portalManageable || portalOpening;
    for (const [suffix, key] of Object.entries(portalFields)) element('account-portal-' + suffix).textContent = model.managementCardVisible ? model[key] : '';
    if (model.portalManageable) {
      // Existing Preview contracts are managed through Stripe, never a second Checkout.
      element('plan-fields').disabled = true;
      element('premium-monthly').checked = false;
      element('plan-checkout').disabled = true;
      if (!element('plan-panel').hidden) {
        element('plan-route-title').textContent = '登録済みのPreview契約を管理してください';
        element('plan-route-detail').textContent = '新しい申し込みは行いません。アカウント確認へ戻り、支払方法・請求・解約を管理してください。';
      }
    } else if (currentSummary && !element('plan-panel').hidden) {
      renderPlan(currentSummary);
    }
  }
  async function refreshPreviewBilling({ fromPortal = false } = {}) {
    if (!checkoutService?.getPreviewBilling || !isVerifiedAccountIdentity(currentUser) || currentUser.isNewUser || currentSummary?.appAccountExists !== true || destroyed) return;
    const request = ++previewRead;
    const generation = epoch;
    previewReading = true;
    clearPortal();
    const returnStatus = element('account-portal-return-status');
    if (fromPortal) { returnStatus.hidden = false; returnStatus.textContent = 'Stripeの契約管理画面から戻りました。契約状態を再確認しています。'; }
    for (const prefix of previewPrefixes) { clearPreviewBilling(prefix, 'Preview契約状態を確認しています。'); element(prefix + '-refresh').disabled = true; }
    try {
      const raw = await checkoutService.getPreviewBilling();
      if (destroyed || generation !== epoch || request !== previewRead || !isVerifiedAccountIdentity(currentUser)) return;
      const model = projectPreviewBilling(raw);
      for (const prefix of previewPrefixes) renderPreviewBilling(prefix, model);
      renderPortal(model);
      if (fromPortal) returnStatus.textContent = 'Stripeの契約管理画面から戻りました。最新の契約状態を読み直しました。反映待ちの場合は、時間をおいて再確認してください。';
    } catch {
      if (destroyed || generation !== epoch || request !== previewRead) return;
      for (const prefix of previewPrefixes) clearPreviewBilling(prefix, 'Preview契約状態を確認できません。時間をおいて再確認するか、サポートへお問い合わせください。');
      if (fromPortal) returnStatus.textContent = 'Stripeの契約管理画面から戻りましたが、契約状態を確認できませんでした。時間をおいて再確認してください。';
    } finally {
      if (!destroyed && generation === epoch && request === previewRead) {
        previewReading = false;
        for (const prefix of previewPrefixes) element(prefix + '-refresh').disabled = false;
        if (fromPortal) { portalReturnPending = false; returnStatus.focus(); }
      }
    }
  }
  function acceptPreviewBilling(model) {
    previewRead++;
    previewReading = false;
    for (const prefix of previewPrefixes) { renderPreviewBilling(prefix, model); element(prefix + '-refresh').disabled = false; }
    renderPortal(model);
  }
  async function openPortal() {
    if (busy || portalOpening || !checkoutService?.createPreviewPortalSession || !isVerifiedAccountIdentity(currentUser) || currentUser.isNewUser || currentSummary?.appAccountExists !== true || !previewModel?.portalManageable || destroyed) return;
    const generation = epoch;
    const currentBillingRead = previewRead;
    portalOpening = true;
    let navigating = false;
    element('account-portal-open').disabled = true;
    element('account-portal-status').textContent = 'Stripeの安全な契約管理画面を準備しています。';
    try {
      const response = await checkoutService.createPreviewPortalSession();
      if (destroyed || generation !== epoch || currentBillingRead !== previewRead || !isVerifiedAccountIdentity(currentUser) || !previewModel?.portalManageable) return;
      const url = projectPreviewPortalSession(response);
      // Never put this short-lived destination in DOM, browser storage or logs.
      window.location.assign(url);
      navigating = true;
    } catch (cause) {
      if (destroyed || generation !== epoch || currentBillingRead !== previewRead) return;
      element('account-portal-status').textContent = portalErrorMessage(cause);
      element('account-portal-status').focus();
    } finally {
      if (!destroyed && generation === epoch && !navigating) { portalOpening = false; element('account-portal-open').disabled = !previewModel?.portalManageable; }
    }
  }

  async function renderUser(user, { focus = false, plan = false } = {}) {
    const request = ++epoch;
    let attempt = signInAttempt;
    if (attempt?.candidateUser && attempt.candidateUser !== user) {
      signInAttempt = null;
      signInPending = false;
      attempt = null;
    }
    if (attempt && isVerifiedAccountIdentity(user)) attempt.candidateUser = user;
    currentUser = user;
    clearPersonal();
    clearError();
    resetPassword();
    email.value = '';
    element('session-controls').hidden = !user;
    if (!user) {
      setBusy(signInPending, signInPending ? 'ログインしています。' : '');
      setPanel('login-panel', focus && !signInPending ? 'login-title' : null);
      return;
    }
    if (!isVerifiedAccountIdentity(user)) {
      if (user.identityCheckFailed === true || user.maskedEmail === '未設定') {
        setBusy(false);
        setPanel('login-panel', focus ? 'login-title' : null);
        showError(service.safeError({code: 'account/identity-unverified'}));
        return;
      }
      element('verification-email').textContent = user.maskedEmail || 'メールアドレスを確認してください';
      setBusy(false);
      setPanel('verification-panel', focus ? 'verification-title' : null);
      return;
    }
    setBusy(true, 'アカウント情報を確認しています。');
    element('loading-title').textContent = 'アカウントを確認しています';
    element('loading-copy').textContent = '本人のプロフィール・契約・体験状態を読み取っています。';
    setPanel('loading-panel');
    try {
      const summary = await service.readAccountSummary();
      if (destroyed || request !== epoch || !currentUser || !isVerifiedAccountIdentity(currentUser)) return;
      currentSummary = summary;
      // A late Popup rejection must not overwrite this attempt's freshly
      // verified identity and successful current-account read. No names or
      // masked emails are used as identity evidence.
      if (attempt?.kind === 'apple' && signInAttempt === attempt && currentUser === user &&
          user.authenticationBasis === 'apple_provider' && !user.isNewUser && summary.appAccountExists === true &&
          Array.isArray(summary.unavailableFields) && summary.unavailableFields.length === 0) {
        attempt.confirmedUser = user;
        attempt.confirmedEpoch = request;
        if (attempt.popupErrorGeneration === errorGeneration) clearError();
      }
      element('account-nickname').textContent = summary.nickname || '未設定';
      element('account-email').textContent = summary.maskedEmail || user.maskedEmail || '確認できませんでした';
      element('account-method').textContent = (summary.methods || user.methods || []).join('・') || '確認できませんでした';
      element('account-billing').textContent = summary.billingLabel || '確認できませんでした';
      element('account-trial').textContent = summary.trialLabel || '確認できませんでした';
      const unavailable = Array.isArray(summary.unavailableFields) ? summary.unavailableFields : [];
      element('unavailable-fields').textContent = unavailable.length ? `${unavailable.join('・')}を読み取れませんでした。利用可能・未契約とは判定していません。` : '';
      element('unavailable-fields').hidden = unavailable.length === 0;
      element('new-google-note').hidden = !user.isNewUser;
      const registration = element('account-registration-note');
      registration.hidden = summary.appAccountExists === true;
      registration.textContent = summary.appAccountExists === true ? '' : summary.appAccountExists === false
        ? 'このログイン情報に対応するHamCareアプリのペット登録を確認できませんでした。アプリで普段使用しているアカウントか確認してください。ここでは登録・契約・体験を開始しません。'
        : 'HamCareアカウントの登録状態を読み取れないため、プラン確認と契約管理を停止しています。時間をおいて表示内容を再確認してください。';
      setBusy(false);
      if (plan && !user.isNewUser && summary.appAccountExists === true) {
        renderPlan(summary);
        setPanel('plan-panel', 'plan-title');
        void refreshPreviewBilling();
      } else {
        setPanel('account-panel', focus ? 'confirm-title' : null);
        if (!user.isNewUser && summary.appAccountExists === true) void refreshContactStatus();
        if (resumePending && checkout && !user.isNewUser && summary.appAccountExists === true) { resumePending = false; void checkout.resume(); }
        else if (!user.isNewUser && summary.appAccountExists === true) void refreshPreviewBilling({ fromPortal: portalReturnPending });
      }
    } catch (cause) {
      if (destroyed || request !== epoch) return;
      setBusy(false);
      element('loading-title').textContent = 'アカウント情報を確認できませんでした';
      element('loading-copy').textContent = '安全のため、アカウント情報を表示していません。再読込するか、ログアウトしてからやり直してください。';
      setPanel('loading-panel');
      showError(service.safeError(cause));
      if (attempt && signInAttempt === attempt && currentUser === user) attempt.readErrorGeneration = errorGeneration;
    }
  }

  async function signIn(action, kind = 'other') {
    if (busy || loggingOut || signInPending) return;
    const attempt = {kind, candidateUser: null, confirmedUser: null, confirmedEpoch: null, popupErrorGeneration: null, readErrorGeneration: null};
    signInAttempt = attempt;
    signInPending = true;
    clearError();
    setBusy(true, 'ログインしています。');
    try {
      await action();
    } catch (cause) {
      if (destroyed || loggingOut || signInAttempt !== attempt) return;
      const confirmedCurrent = attempt.kind === 'apple' && attempt.confirmedUser === currentUser &&
        attempt.confirmedEpoch === epoch && isVerifiedAccountIdentity(currentUser);
      const currentReadError = attempt.kind === 'apple' && attempt.readErrorGeneration === errorGeneration;
      if (cause?.code !== 'auth/popup-blocked' || (!confirmedCurrent && !currentReadError)) {
        showError(service.safeError(cause));
        if (cause?.code === 'auth/popup-blocked') attempt.popupErrorGeneration = errorGeneration;
      }
    } finally {
      if (signInAttempt === attempt) {
        signInPending = false;
        resetPassword();
        if (!destroyed && !currentUser) setBusy(false);
      }
    }
  }

  const onSubmit = (event) => {
    event.preventDefault();
    if (busy || loggingOut || signInPending) return;
    const address = email.value.trim();
    if (!address || !email.validity.valid || !password.value) {
      if (!address || !email.validity.valid) email.setAttribute('aria-invalid', 'true');
      if (!password.value) password.setAttribute('aria-invalid', 'true');
      showError('メールアドレスとパスワードを入力してください。');
      return;
    }
    const secret = password.value;
    void signIn(() => service.signInEmail(address, secret));
  };
  form.addEventListener('submit', onSubmit);

  const onGoogle = () => { void signIn(() => service.signInGoogle()); };
  element('google-signin').addEventListener('click', onGoogle);
  const onAppleConsent = () => { appleConsent.removeAttribute('aria-invalid'); updateAppleControl(); };
  appleConsent.addEventListener('change', onAppleConsent);
  const onApple = () => {
    if (busy || loggingOut || signInPending || service.appleSignInEnabled !== true) return;
    if (appleConsent.checked !== true) {
      appleConsent.setAttribute('aria-invalid', 'true');
      showError('Appleログインの関連付けについて確認し、同意してください。');
      appleConsent.focus();
      return;
    }
    // A fresh explicit choice is required for every attempt. Never persist it or
    // place it in an OAuth URL; the service also requires this strict boolean.
    void signIn(async () => {
      try { await service.signInApple({linkingConsent: true}); }
      finally { resetAppleConsent(); }
    }, 'apple');
  };
  element('apple-signin').addEventListener('click', onApple);
  if (service.appleSignInEnabled === true) element('apple-signin-note').textContent = 'HamCareアプリで使用したAppleアカウントを選んでください。別のAppleアカウントでは新しいログイン情報が作成される場合がありますが、体験・契約は自動で開始しません。';
  const onToggle = () => {
    const visible = password.type === 'password';
    password.type = visible ? 'text' : 'password';
    element('toggle-password').textContent = visible ? '非表示' : '表示';
    element('toggle-password').setAttribute('aria-pressed', String(visible));
  };
  element('toggle-password').addEventListener('click', onToggle);

  const onLogout = async () => {
    if (loggingOut) return;
    loggingOut = true;
    signInAttempt = null;
    signInPending = false;
    ++epoch;
    currentUser = null;
    clearPersonal();
    clearError();
    resetPassword();
    email.value = '';
    setBusy(true, 'ログアウトしています。');
    element('loading-title').textContent = 'ログアウトしています';
    element('loading-copy').textContent = 'アカウント情報を非表示にしました。';
    setPanel('loading-panel');
    element('logout').disabled = true;
    try {
      await service.signOut();
    } catch (cause) {
      element('loading-title').textContent = 'ログアウトを確認できませんでした';
      element('loading-copy').textContent = '安全のため情報を非表示にしています。もう一度ログアウトするか、このタブを閉じてください。';
      element('session-controls').hidden = false;
      showError(service.safeError(cause));
    } finally {
      loggingOut = false;
      element('logout').disabled = false;
    }
  };
  element('logout').addEventListener('click', onLogout);

  const onRefresh = () => { if (!busy && currentUser) void renderUser(currentUser, { focus: true }); };
  element('refresh-account').addEventListener('click', onRefresh);
  const onVerify = async () => {
    if (busy || !currentUser) return;
    clearError();
    setBusy(true, 'メール確認の状態を再確認しています。');
    try {
      await service.reloadUser();
    } catch (cause) {
      showError(service.safeError(cause));
    } finally {
      if (!destroyed) setBusy(false);
    }
  };
  element('check-verification').addEventListener('click', onVerify);

  const onPlan = async () => {
    if (busy || contactChecking || !isVerifiedAccountIdentity(currentUser) || currentUser.isNewUser || currentSummary?.appAccountExists !== true) return;
    if (contactService && previewReading) { status.textContent = '契約状態の確認が終わってからお進みください。'; return; }
    const generation = epoch, user = currentUser;
    // Existing Preview contracts remain manageable without a new contact gate.
    if (contactService && !previewModel?.portalManageable && !(await checkContactBeforePurchase())) return;
    if (destroyed || generation !== epoch || currentUser !== user) return;
    // Re-read the same UID-scoped documents; do not rely on stale account text.
    await renderUser(currentUser, { focus: true, plan: true });
  };
  element('review-plan').addEventListener('click', onPlan);
  const onBack = () => {
    if (!isVerifiedAccountIdentity(currentUser) || currentUser.isNewUser) return;
    setPanel('account-panel', 'confirm-title');
  };
  element('back-to-account').addEventListener('click', onBack);
  const onPlanChoice = () => {
    const option = element('premium-monthly');
    if (busy || contactChecking || !isVerifiedAccountIdentity(currentUser) || currentUser.isNewUser || currentSummary?.appAccountExists !== true || previewReading || previewModel?.portalManageable || !currentSummary?.planReview?.canSelectPlan || option.value !== PREMIUM_MONTHLY.key) {
      option.checked = false;
      return;
    }
    if (!option.checked) return;
    element('plan-selected-name').textContent = PREMIUM_MONTHLY.name;
    element('plan-selected-amount').textContent = `月額${PREMIUM_MONTHLY.taxInclusiveYen}円`;
    element('plan-selection-status').textContent = '月額プランを選択しました。内容の確認のみで、申し込みは行われていません。';
    element('plan-checkout').disabled = !checkout;
    // Choosing a plan itself sends no request. Checkout requires a fresh review.
  };
  element('premium-monthly').addEventListener('change', onPlanChoice);

  if (checkoutService) checkout = createCheckoutController({service: checkoutService, onShow: () => setPanel('checkout-panel', 'checkout-title'), onBack: () => { if (isVerifiedAccountIdentity(currentUser)) { setPanel('plan-panel', 'plan-title'); void refreshPreviewBilling(); } }, onBillingUpdate: acceptPreviewBilling});
  const onCheckout = async () => {
    if (busy || contactChecking || !isVerifiedAccountIdentity(currentUser) || currentUser.isNewUser || currentSummary?.appAccountExists !== true || previewReading || previewModel?.portalManageable || !currentSummary?.planReview?.canSelectPlan || !element('premium-monthly').checked) return;
    const generation = epoch, user = currentUser;
    if (contactService && !(await checkContactBeforePurchase())) return;
    if (destroyed || generation !== epoch || currentUser !== user || busy || previewReading || previewModel?.portalManageable || !element('premium-monthly').checked) return;
    void checkout?.open();
  };
  element('plan-checkout').addEventListener('click', onCheckout);
  const onPortal = () => { void openPortal(); };
  element('account-portal-open').addEventListener('click', onPortal);
  const onPreviewRefresh = () => { if (!busy && isVerifiedAccountIdentity(currentUser) && !currentUser.isNewUser) void refreshPreviewBilling(); };
  for (const prefix of previewPrefixes) element(prefix + '-refresh').addEventListener('click', onPreviewRefresh);
  const onPopState = () => { if (!element('checkout-panel').hidden && isVerifiedAccountIdentity(currentUser)) void checkout?.resume(); };
  window.addEventListener('popstate', onPopState);

  const onPageHide = () => {
    signInAttempt = null;
    signInPending = false;
    ++epoch;
    clearPersonal();
    resetPassword();
    email.value = '';
    setBusy(true, 'ログイン状態を再確認します。');
    element('loading-title').textContent = 'ログイン状態を再確認しています';
    element('loading-copy').textContent = '安全のため、アカウント情報を一時的に非表示にしました。';
    setPanel('loading-panel');
  };
  const onPageShow = async (event) => {
    if (!event.persisted || destroyed) return;
    // A restored page must not retain a disabled Portal action or its old result,
    // even when pagehide was not observed. Auth reload emits the current user;
    // renderUser then re-reads billing with the same guards as a Portal return.
    portalReturnPending = true;
    resumePending = false;
    onPageHide();
    const request = epoch;
    try {
      await service.reloadUser();
    } catch (cause) {
      if (!destroyed && request === epoch) showError(service.safeError(cause));
    }
  };
  window.addEventListener('pagehide', onPageHide);
  window.addEventListener('pageshow', onPageShow);

  try {
    await service.ready();
    if (!destroyed) unsubscribe = service.onAuthChanged((user) => { void renderUser(user, { focus: true }); });
  } catch (cause) {
    element('loading-title').textContent = '現在ログインできません';
    element('loading-copy').textContent = '通信を確認して、ページを再読込してください。';
    showError(service.safeError(cause));
  }

  return () => {
    destroyed = true;
    signInAttempt = null;
    signInPending = false;
    checkout?.destroy();
    checkoutService?.clear();
    element('plan-checkout').removeEventListener('click', onCheckout);
    element('account-portal-open').removeEventListener('click', onPortal);
    for (const prefix of previewPrefixes) element(prefix + '-refresh').removeEventListener('click', onPreviewRefresh);
    window.removeEventListener('popstate', onPopState);
    ++epoch;
    clearPersonal();
    resetPassword();
    email.value = '';
    unsubscribe();
    form.removeEventListener('submit', onSubmit);
    element('google-signin').removeEventListener('click', onGoogle);
    element('apple-signin').removeEventListener('click', onApple);
    appleConsent.removeEventListener('change', onAppleConsent);
    element('toggle-password').removeEventListener('click', onToggle);
    element('logout').removeEventListener('click', onLogout);
    element('refresh-account').removeEventListener('click', onRefresh);
    element('check-verification').removeEventListener('click', onVerify);
    element('review-plan').removeEventListener('click', onPlan);
    element('back-to-account').removeEventListener('click', onBack);
    element('premium-monthly').removeEventListener('change', onPlanChoice);
    window.removeEventListener('pagehide', onPageHide);
    window.removeEventListener('pageshow', onPageShow);
  };
}
