/** Presentation only. Firebase identifiers and credentials stay inside the service. */
export async function mountAccountPage(service) {
  const element = (id) => document.getElementById(id);
  const panels = ['loading-panel', 'login-panel', 'verification-panel', 'account-panel', 'pending-panel'];
  const personalFields = ['verification-email', 'account-nickname', 'account-email', 'account-method', 'account-billing', 'account-trial', 'unavailable-fields'];
  const form = element('email-form');
  const email = element('email');
  const password = element('password');
  const error = element('auth-error');
  const status = element('auth-status');
  let epoch = 0;
  let currentUser = null;
  let busy = true;
  let loggingOut = false;
  let signInPending = false;
  let unsubscribe = () => {};
  let destroyed = false;

  function setPanel(id, heading) {
    for (const panel of panels) element(panel).hidden = panel !== id;
    if (heading) element(heading).focus();
  }

  function clearPersonal() {
    for (const id of personalFields) element(id).textContent = '';
    element('unavailable-fields').hidden = true;
    element('new-google-note').hidden = true;
  }

  function clearError() {
    error.textContent = '';
    error.hidden = true;
    email.removeAttribute('aria-invalid');
    password.removeAttribute('aria-invalid');
  }

  function showError(message) {
    error.textContent = message;
    error.hidden = false;
    error.focus();
  }

  function setBusy(value, message = '') {
    busy = value;
    element('email-fields').disabled = value;
    for (const id of ['google-signin', 'refresh-account', 'check-verification']) element(id).disabled = value;
    element('review-plan').disabled = value || Boolean(currentUser?.isNewUser);
    form.setAttribute('aria-busy', String(value));
    status.textContent = message;
  }

  function resetPassword() {
    password.value = '';
    password.type = 'password';
    element('toggle-password').textContent = '表示';
    element('toggle-password').setAttribute('aria-pressed', 'false');
  }

  async function renderUser(user, { focus = false } = {}) {
    const request = ++epoch;
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
    if (!user.emailVerified) {
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
      if (destroyed || request !== epoch || !currentUser || !currentUser.emailVerified) return;
      element('account-nickname').textContent = summary.nickname || '未設定';
      element('account-email').textContent = summary.maskedEmail || user.maskedEmail || '確認できませんでした';
      element('account-method').textContent = (summary.methods || user.methods || []).join('・') || '確認できませんでした';
      element('account-billing').textContent = summary.billingLabel || '確認できませんでした';
      element('account-trial').textContent = summary.trialLabel || '確認できませんでした';
      const unavailable = Array.isArray(summary.unavailableFields) ? summary.unavailableFields : [];
      element('unavailable-fields').textContent = unavailable.length ? `${unavailable.join('・')}を読み取れませんでした。利用可能・未契約とは判定していません。` : '';
      element('unavailable-fields').hidden = unavailable.length === 0;
      element('new-google-note').hidden = !user.isNewUser;
      setBusy(false);
      setPanel('account-panel', focus ? 'confirm-title' : null);
    } catch (cause) {
      if (destroyed || request !== epoch) return;
      setBusy(false);
      element('loading-title').textContent = 'アカウント情報を確認できませんでした';
      element('loading-copy').textContent = '安全のため、アカウント情報を表示していません。再読込するか、ログアウトしてからやり直してください。';
      setPanel('loading-panel');
      showError(service.safeError(cause));
    }
  }

  async function signIn(action) {
    if (busy || loggingOut || signInPending) return;
    signInPending = true;
    clearError();
    setBusy(true, 'ログインしています。');
    try {
      await action();
    } catch (cause) {
      showError(service.safeError(cause));
    } finally {
      signInPending = false;
      resetPassword();
      if (!destroyed && !currentUser) setBusy(false);
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

  const onPlan = () => {
    if (busy || !currentUser?.emailVerified || currentUser.isNewUser) return;
    setPanel('pending-panel', 'pending-title');
  };
  element('review-plan').addEventListener('click', onPlan);
  const onBack = () => {
    if (!currentUser?.emailVerified || currentUser.isNewUser) return;
    setPanel('account-panel', 'confirm-title');
  };
  element('back-to-account').addEventListener('click', onBack);

  const onPageHide = () => {
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
    try {
      await service.reloadUser();
    } catch (cause) {
      if (!destroyed) showError(service.safeError(cause));
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
    ++epoch;
    clearPersonal();
    resetPassword();
    email.value = '';
    unsubscribe();
    form.removeEventListener('submit', onSubmit);
    element('google-signin').removeEventListener('click', onGoogle);
    element('toggle-password').removeEventListener('click', onToggle);
    element('logout').removeEventListener('click', onLogout);
    element('refresh-account').removeEventListener('click', onRefresh);
    element('check-verification').removeEventListener('click', onVerify);
    element('review-plan').removeEventListener('click', onPlan);
    element('back-to-account').removeEventListener('click', onBack);
    window.removeEventListener('pagehide', onPageHide);
    window.removeEventListener('pageshow', onPageShow);
  };
}
