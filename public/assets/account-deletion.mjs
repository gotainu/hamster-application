export const SUPPORT_EMAIL = 'gotainu@gmail.com';

/** Clipboard is optional: the visible address and mail link work without JS. */
export async function copySupportEmail(clipboard, status) {
  try {
    if (!clipboard || typeof clipboard.writeText !== 'function') throw new Error();
    await clipboard.writeText(SUPPORT_EMAIL);
    status.textContent = 'メールアドレスをコピーしました。';
    return true;
  } catch {
    status.textContent = 'コピーできませんでした。表示されたメールアドレスを選択してコピーしてください。';
    return false;
  }
}

export function setupDeletionRequestPage(doc, clipboard) {
  const button = doc.getElementById('copy-email');
  const status = doc.getElementById('copy-status');
  if (!button || !status) return;
  button.hidden = false;
  button.addEventListener('click', async () => {
    if (button.disabled) return;
    button.disabled = true;
    try { await copySupportEmail(clipboard, status); }
    finally { button.disabled = false; }
  });
}

if (typeof document !== 'undefined') {
  setupDeletionRequestPage(document, globalThis.navigator?.clipboard);
}
