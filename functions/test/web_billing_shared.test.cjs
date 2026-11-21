'use strict';
const assert = require('node:assert/strict');
const {test} = require('node:test');
const {loadStarSource} = require('./support/star_source_loader.cjs');
const load = loadStarSource();
const shared = load('webBillingShared');
const preview = load('../../preview-functions/src/auth-policy');
const contacts = load('../../preview-functions/src/billing-contact');
const policy = load('previewCheckoutPolicy');
const UID = 'synthetic-owner', SUBJECT = 'synthetic-apple-provider';
function owner(email, verified = true, provider = 'apple.com') {
  return {token:{uid:UID,email_verified:verified,firebase:{sign_in_provider:provider,identities:{'apple.com':[SUBJECT]}}},
    user:{uid:UID,disabled:false,emailVerified:verified,providerData:[{providerId:provider,uid:SUBJECT}], ...(email === undefined ? {} : {email})}};
}
const authorize = f => shared.authorizeWebBillingIdentity(f.token, f.user);
test('Preview public auth and email APIs are aliases of the shared pure implementation', () => {
  assert.equal(preview.PreviewAuthenticationError, shared.BillingAuthenticationError);
  assert.equal(preview.authorizePreviewIdentity, shared.authorizeWebBillingIdentity);
  assert.equal(preview.validPreviewUid, shared.validWebBillingUid);
  for (const name of ['normalizeBillingEmail', 'maskBillingEmail', 'classifyBillingEmail']) assert.equal(contacts[name], shared[name]);
  assert.equal(shared.assessWebCheckout, policy.assessPreviewCheckout);
  assert.equal(shared.isWebBillingIdentityConfirmed, policy.isPreviewIdentityConfirmed);
  assert.equal(shared.WebCheckoutPolicyError, policy.PreviewCheckoutPolicyError);
});
for (const provider of ['password','google.com','apple.com']) test('verified regular email is A for ' + provider, () => {
  const f = owner('Synthetic@Example.TEST', true, provider), before = structuredClone(f);
  const identity = authorize(f);
  assert.deepEqual(shared.classifyBillingEmail(identity, f.user), {kind:'A',email:'Synthetic@example.test',source:'auth_verified'});
  assert.equal(identity.uid, UID); assert.equal(Object.isFrozen(identity), true); assert.deepEqual(f, before);
});
for (const domain of ['privaterelay.appleid.com','private.icloud.com']) {
  test('current verified Apple ' + domain + ' is accepted as B without a real email requirement', () => {
    const f = owner('synthetic@' + domain), identity = authorize(f);
    assert.deepEqual(shared.classifyBillingEmail(identity, f.user), {kind:'B',email:f.user.email,source:'apple_relay'});
    assert.equal(shared.normalizeBillingEmail(' Synthetic@' + domain.toUpperCase() + ' '), 'Synthetic@' + domain);
    assert.equal(shared.maskBillingEmail(f.user.email), 'sy***@' + domain);
  });
  test(domain + ' syntax or unverified current Apple session cannot prove reachability', () => {
    const f = owner('synthetic@' + domain, false), identity = authorize(f);
    assert.equal(identity.emailVerified, false); assert.equal(Object.hasOwn(identity,'email'), false);
    assert.deepEqual(shared.classifyBillingEmail(identity, f.user), {kind:'unverified'});
  });
  test(domain + ' cannot bind a different UID or mismatched Apple subject', () => {
    for (const mutate of [f => {f.user.uid='synthetic-other';},f => {f.user.providerData[0].uid='synthetic-other-subject';}]) {
      const f = owner('synthetic@' + domain); mutate(f);
      assert.throws(() => authorize(f), error => error instanceof shared.BillingAuthenticationError && error.code === 'unauthenticated');
    }
  });
}
test('only current Apple with truly absent Auth and provider emails is C', () => {
  const f = owner(undefined, false), identity = authorize(f);
  assert.deepEqual(shared.classifyBillingEmail(identity,f.user), {kind:'C'});
  f.user.providerData[0].email='synthetic@private.icloud.com';
  assert.deepEqual(shared.classifyBillingEmail(identity,f.user), {kind:'unverified'});
});
for (const email of [' ', 'broken', 123, 'synthetic@example.test\r\nBcc:synthetic@example.test']) test('invalid email is never coerced into missing-email C: ' + typeof email, () => {
  const f = owner(email,false); assert.deepEqual(shared.classifyBillingEmail(authorize(f),f.user), {kind:'invalid'});
});
test('unverified regular-email sessions and linked Apple claims fail the shared auth boundary', () => {
  for (const provider of ['password','google.com']) {
    const f = owner('synthetic@example.test',false,provider); f.token.authBasis='apple_provider';
    assert.throws(() => authorize(f), error => error instanceof shared.BillingAuthenticationError && error.code === 'email_unverified');
  }
});
for (const uid of ['', 'synthetic/owner', 'synthetic owner', 'synthetic\u0000owner', 'x'.repeat(129), 123, null]) test('UID validation rejects unsafe ' + typeof uid + ' value', () => {
  assert.equal(shared.validWebBillingUid(uid),false);
  const f=owner(undefined,false); f.token.uid=uid; f.user.uid=uid;
  assert.throws(() => authorize(f), error => error.code === 'unauthenticated');
});
test('shared checkout keeps original trial end and its 48h plus one minute boundary', () => {
  const now = new Date('2026-11-21T00:00:00Z'), end = new Date(now.getTime()+shared.MIN_WEB_TRIAL_REMAINING_SECONDS*1000);
  const input={identity:{uid:UID,emailVerified:true,authBasis:'verified_email'},appAccountExists:true,billing:{kind:'missing'},
    trial:{kind:'found',data:{status:'active',startedAt:new Date(now.getTime()-86400000),endsAt:end}},planKey:'premium_monthly',now};
  const decision=shared.assessWebCheckout(input);
  assert.equal(decision.unitAmount,550); assert.equal(decision.trialEndSeconds,end.getTime()/1000);
  assert.equal(decision.hamcareTrialEndsAtMillis,end.getTime());
  input.now=new Date(now.getTime()+1);
  assert.throws(() => shared.assessWebCheckout(input),error => error.code === 'trial_too_short');
});
