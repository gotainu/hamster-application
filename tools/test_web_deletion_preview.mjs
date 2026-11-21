import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const original = JSON.parse(read('firebase.preview.json'));
const deletion = JSON.parse(read('firebase.account-deletion-preview.json'));

test('deletion Preview changes only the static deletion exception and its headers', () => {
  assert.deepEqual(Object.keys(deletion), ['hosting']);
  const expected = structuredClone(original);
  expected.hosting.ignore = expected.hosting.ignore.filter(path => path !== 'account-deletion/**');
  const dedicated = deletion.hosting.headers.at(-1);
  assert.equal(dedicated.source, '/account-deletion/**');
  expected.hosting.headers.push(dedicated);
  assert.deepEqual(deletion, expected);
  assert.equal(deletion.hosting.site, 'hamster-breeding-app');
  assert.equal(deletion.hosting.public, 'public');
});

test('the anonymous deletion page cannot open network APIs or frames', () => {
  const headers = Object.fromEntries(deletion.hosting.headers.at(-1).headers.map(h => [h.key,h.value]));
  const csp = Object.fromEntries(headers['Content-Security-Policy'].split(';').map(part => {
    const [key,...values] = part.trim().split(/\s+/); return [key,values];
  }));
  for (const rule of ['default-src','connect-src','form-action','frame-ancestors','base-uri','object-src']) {
    assert.deepEqual(csp[rule], ["'none'"]);
  }
  assert.deepEqual(csp['script-src'], ["'self'"]);
  assert.deepEqual(csp['style-src'], ["'self'"]);
  assert.equal(headers['Cache-Control'], 'no-store, max-age=0');
});

test('LP, Privacy and Support keep a discoverable deletion request path', () => {
  for (const page of ['public/index.html','public/privacy/index.html','public/support/index.html']) {
    assert.match(read(page), /href="\/account-deletion\/"/);
  }
  assert.match(read('public/privacy/index.html'), /申請のためのログインやアプリの再インストールは不要/);
  assert.match(read('public/support/index.html'), /メール未設定のアカウントも申し出られます/);
});
