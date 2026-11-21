import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { SUPPORT_EMAIL, copySupportEmail, setupDeletionRequestPage } from '../public/assets/account-deletion.mjs';

const html = await readFile(new URL('../public/account-deletion/index.html', import.meta.url), 'utf8');
const css = await readFile(new URL('../public/assets/account-deletion.css', import.meta.url), 'utf8');
const script = await readFile(new URL('../public/assets/account-deletion.mjs', import.meta.url), 'utf8');

test('email request is available without login, JS, or reinstall', () => {
  const target = new URL(html.match(/href="(mailto:[^"]+)"/)[1]);
  assert.equal(target.pathname, SUPPORT_EMAIL);
  assert.equal(target.searchParams.get('subject'), '【HamCare】アカウント削除申請');
  assert.equal(target.searchParams.get('body'), null);
  assert.match(html, /メールで削除を申請する/);
  assert.match(html, /申請にログインやアプリの再インストールは必要ありません/);
  assert.match(html, /メールアドレスが設定されていない方も申請できます/);
  assert.match(html, /現在受信できるメールアドレスから/);
  assert.doesNotMatch(html, /登録メールアドレスから|<form\b|type="password"/);
});

test('current brand and legal links remain, with no purchase CTA or auth dependency', () => {
  assert.match(html, /<h1[^>]*>アカウント削除について<\/h1>/);
  assert.match(html, /hamcare-mark-outline\.png/);
  for (const path of ['privacy', 'support', 'terms']) assert.ok(html.includes(`href="https://hamster-breeding-app.web.app/${path}/"`));
  assert.doesNotMatch(html, /href="(?:\/account\/|https:\/\/billing\.stripe|https:\/\/checkout\.stripe)|FirebaseAuth|firebasejs|signInWith|\b(?:500|550)円|プランを選ぶ|購入する/);
  assert.doesNotMatch(script, /fetch\(|XMLHttpRequest|localStorage|sessionStorage|execCommand|console\./);
});

test('deletion copy distinguishes identity verification, completion and retention', () => {
  assert.match(html, /メールの送信だけで削除が完了することはありません/);
  assert.match(html, /本人確認後/);
  assert.match(html, /パスワード、認証コード、Firebase ID Token/);
  assert.match(html, /すべての情報が同時に完全削除されるわけではありません/);
  assert.match(html, /法令遵守、請求・会計、返金・紛争対応、不正利用防止/);
  assert.match(html, /継続請求が停止したことを確認してから/);
  assert.doesNotMatch(html, /バックアップ.*更新サイクル|すべて完全削除|sk_live_|sk_test_|AIza|BEGIN PRIVATE KEY/);
});

test('copy writes only the public support address and announces success', async () => {
  const values = [], status = {};
  assert.equal(await copySupportEmail({writeText: async v => values.push(v)}, status), true);
  assert.deepEqual(values, [SUPPORT_EMAIL]);
  assert.equal(status.textContent, 'メールアドレスをコピーしました。');
});

for (const [name, clipboard] of [['missing', null], ['denied', {writeText: async () => {throw new Error('denied');}}]]) {
  test(`copy ${name} keeps the address available for manual selection`, async () => {
    const status = {};
    assert.equal(await copySupportEmail(clipboard, status), false);
    assert.match(status.textContent, /表示されたメールアドレスを選択してコピー/);
    assert.match(html, /id="support-address">gotainu@gmail.com/);
    assert.match(css, /user-select: all/);
  });
}

test('copy control prevents concurrent writes and restores the button', async () => {
  let listener, release, calls = 0;
  const button = {hidden: true, disabled: false, addEventListener: (_type, callback) => listener = callback};
  const status = {};
  setupDeletionRequestPage({getElementById: id => id === 'copy-email' ? button : status}, {
    writeText: () => {calls++; return new Promise(resolve => release = resolve);},
  });
  assert.equal(button.hidden, false);
  const first = listener();
  await listener();
  assert.equal(calls, 1);
  assert.equal(button.disabled, true);
  release(); await first;
  assert.equal(button.disabled, false);
});

test('responsive and accessibility hooks support narrow screens and keyboard focus', () => {
  assert.match(html, /name="viewport"/);
  assert.match(html, /class="skip-link" href="#main"/);
  assert.match(html, /role="status" aria-live="polite" aria-atomic="true"/);
  assert.match(css, /@media \(max-width: 600px\)/);
  assert.match(css, /min-height: 44px/);
  assert.match(css, /backdrop-filter/);
  assert.match(css, /prefers-reduced-transparency/);
});
