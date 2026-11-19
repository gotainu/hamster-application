import {createHash, randomBytes, timingSafeEqual} from 'crypto';
import type {Identity} from './engine';

export const BILLING_CONTACT_NAMESPACE = 'preview_billing_contacts';
export const BILLING_CONTACT_FROM = 'gotainu@gmail.com';
export const BILLING_CONTACT_PREVIEW_ORIGIN = 'https://hamster-breeding-app--web-first-task1-lco08m60.web.app';
export const BILLING_CONTACT_TTL_MS = 15 * 60 * 1000;
export const BILLING_CONTACT_COOLDOWN_MS = 60 * 1000;
const PURPOSE = 'billing_contact_preview';
const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;
const object = (v: unknown): v is Record<string, any> => !!v && typeof v === 'object' && !Array.isArray(v);
const validUid = (v: unknown): v is string => typeof v === 'string' && v.length > 0 && v.length <= 128 && !/[\/\s\u0000-\u001f\u007f]/u.test(v);
const digest = (v: string) => createHash('sha256').update(v).digest('hex');
const sameHash = (a: unknown, b: string) => typeof a === 'string' && /^[a-f0-9]{64}$/.test(a) && timingSafeEqual(Buffer.from(a, 'hex'), Buffer.from(b, 'hex'));
const isMillis = (v: unknown): v is number => Number.isSafeInteger(v) && Number(v) > 0;
const iso = (v: number | null) => v === null ? null : new Date(v).toISOString();
export class BillingContactError extends Error {constructor(public code: string) {super(code);}}
const fail = (code: string): never => {throw new BillingContactError(code);};

/** Syntax is not proof of identity or deliverability. Neither relay domain is special here. */
export function normalizeBillingEmail(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const email = value.trim();
  if (email.length > 254 || /[^\x21-\x7e]/.test(email)) return null;
  const parts = email.split('@');
  if (parts.length !== 2) return null;
  const [local, domain] = parts;
  if (!local || local.length > 64 || local.startsWith('.') || local.endsWith('.') || local.includes('..') ||
      !/^[A-Za-z0-9.!#$%&'*+\-/=?^_`{|}~]+$/.test(local)) return null;
  if (!domain || domain.length > 253 || !domain.includes('.') || domain.split('.').some(label =>
      !/^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$/.test(label)) || !/[A-Za-z]{2,}$/.test(domain)) return null;
  return local + '@' + domain.toLowerCase();
}
export function maskBillingEmail(email: string): string {
  const at = email.lastIndexOf('@');
  return email.slice(0, Math.min(2, at)) + '***' + email.slice(at);
}
const relay = (email: string) => ['privaterelay.appleid.com', 'private.icloud.com'].includes(email.slice(email.lastIndexOf('@') + 1).toLowerCase());
export interface BillingEmailClassification {kind: 'A'|'B'|'C'|'unverified'|'invalid'; email?: string; source?: 'auth_verified'|'apple_relay';}

/** Identity must already come from authorizePreviewIdentity after Admin token verification. */
export function classifyBillingEmail(identity: Identity, adminUser: unknown): BillingEmailClassification {
  if (!object(adminUser) || !validUid(identity?.uid) || adminUser.uid !== identity.uid || adminUser.disabled !== false ||
      !['verified_email', 'apple_provider'].includes(identity.authBasis || '') || !Array.isArray(adminUser.providerData) ||
      adminUser.providerData.some((p: unknown) => !object(p) || typeof p.providerId !== 'string')) return {kind:'invalid'};
  const apple = adminUser.providerData.filter((p: any) => p.providerId === 'apple.com');
  if (identity.authBasis === 'apple_provider' && (apple.length !== 1 || typeof apple[0].uid !== 'string' || !apple[0].uid || /\s/.test(apple[0].uid))) return {kind:'invalid'};
  const absent = adminUser.email === undefined || adminUser.email === null || adminUser.email === '';
  if (absent) {
    // An existing provider email without verified current-session evidence is not "no email".
    if (adminUser.providerData.some((p: any) => p.email !== undefined && p.email !== null && p.email !== '')) return {kind:'unverified'};
    return identity.authBasis === 'apple_provider' && identity.email === undefined ? {kind:'C'} : {kind:'invalid'};
  }
  const email = normalizeBillingEmail(adminUser.email);
  if (!email) return {kind:'invalid'};
  if (adminUser.emailVerified !== true || identity.emailVerified !== true || normalizeBillingEmail(identity.email) !== email) return {kind:'unverified'};
  return identity.authBasis === 'apple_provider' && relay(email)
    ? {kind:'B', email, source:'apple_relay'} : {kind:'A', email, source:'auth_verified'};
}

export interface BillingContactContext {identity: Identity; adminUser: unknown; appAccountExists: boolean;}
export type BillingContactState = Record<string, any>;
export interface BillingContactStore {
  read(uid: string): Promise<BillingContactState>;
  mutate<T>(uid: string, update: (state: BillingContactState) => {state: BillingContactState; result: T}): Promise<T>;
}
export interface BillingContactMail {
  from: typeof BILLING_CONTACT_FROM; to: string; subject: string; text: string;
  verificationUrl: string; idempotencyKey: string;
}
export interface BillingContactView {
  testMode: true; emailClass: BillingEmailClassification['kind'];
  verificationStatus: 'verified'|'missing'|'pending'|'expired'|'delivery_failed'|'delivery_uncertain'|'unverified'|'invalid';
  verified: boolean; canCheckout: boolean; maskedEmail: string|null; pendingMaskedEmail: string|null;
  pendingDeliveryState: 'dispatching'|'sent'|'failed'|'uncertain'|null;
  source: 'auth_verified'|'apple_relay'|'user_supplied'|null;
  verificationSentAt: number|null; verifiedAt: number|null; resendAfter: string|null; expiresAt: string|null;
}
export interface BillingContactDependencies {
  store: BillingContactStore;
  sendMail?: (message: BillingContactMail) => Promise<void>;
  now(): Date;
  randomToken?: () => string;
}

function validateContext(context: BillingContactContext): BillingEmailClassification {
  if (!context || !validUid(context.identity?.uid)) fail('unauthenticated');
  if (context.appAccountExists !== true) fail('app_account_required');
  const category = classifyBillingEmail(context.identity, context.adminUser);
  if (category.kind === 'invalid') fail('contact_identity_invalid');
  return category;
}
function stateIsSafe(state: BillingContactState): boolean {
  if (!object(state) || (state.purpose !== undefined && state.purpose !== PURPOSE)) return false;
  if (state.verified === true && (!normalizeBillingEmail(state.email) || !isMillis(state.verifiedAt) || state.source !== 'user_supplied')) return false;
  if (state.pending !== undefined && (!object(state.pending) || !normalizeBillingEmail(state.pending.email) ||
      !/^[a-f0-9]{64}$/.test(state.pending.tokenHash) || !isMillis(state.pending.expiresAt) || !isMillis(state.pending.createdAt) ||
      !['dispatching','sent','failed','uncertain'].includes(state.pending.deliveryState))) return false;
  return true;
}
function activeContact(state: BillingContactState): {email: string; source:'user_supplied'}|null {
  return state.verified === true ? {email: state.email, source:'user_supplied'} : null;
}
function describe(category: BillingEmailClassification, state: BillingContactState, now: number): BillingContactView {
  if (!stateIsSafe(state)) fail('contact_state_invalid');
  const inherent = category.kind === 'A' || category.kind === 'B';
  const active = category.kind === 'C' ? activeContact(state) : null;
  const pending = category.kind === 'C' ? state.pending : undefined;
  const verified = inherent || !!active;
  const pendingStatus = !pending ? 'missing' : pending.expiresAt <= now ? 'expired' :
    pending.deliveryState === 'failed' ? 'delivery_failed' : pending.deliveryState === 'uncertain' || pending.deliveryState === 'dispatching' ? 'delivery_uncertain' : 'pending';
  const email = inherent ? category.email : active?.email;
  return {
    testMode:true, emailClass:category.kind,
    verificationStatus: verified ? 'verified' : category.kind === 'unverified' || category.kind === 'invalid' ? category.kind : pendingStatus,
    verified, canCheckout:verified, maskedEmail:email ? maskBillingEmail(email) : null,
    pendingMaskedEmail:pending ? maskBillingEmail(pending.email) : null,
    pendingDeliveryState:pending ? pending.deliveryState : null,
    source:inherent ? category.source! : active ? 'user_supplied' : null,
    verificationSentAt:pending && isMillis(pending.sentAt) ? pending.sentAt : null,
    verifiedAt:active ? state.verifiedAt : null,
    // A dispatch whose outcome is unknown cannot be automatically repeated until expiry.
    resendAfter:pending ? iso(['dispatching','uncertain'].includes(pending.deliveryState)
      ? Math.max(pending.expiresAt, (state.lastRequestedAt || 0) + BILLING_CONTACT_COOLDOWN_MS)
      : (state.lastRequestedAt || 0) + BILLING_CONTACT_COOLDOWN_MS) : null,
    expiresAt:pending ? iso(pending.expiresAt) : null,
  };
}

export function createBillingContactEngine(d: BillingContactDependencies) {
  const now = () => {const time = d.now().getTime(); if (!isMillis(time)) fail('server_clock_invalid'); return time;};
  const random = d.randomToken || (() => randomBytes(32).toString('base64url'));
  async function status(context: BillingContactContext): Promise<BillingContactView> {
    const category = validateContext(context);
    if (category.kind === 'A' || category.kind === 'B' || category.kind === 'unverified') return describe(category, {}, now());
    return describe(category, await d.store.read(context.identity.uid), now());
  }
  async function request(context: BillingContactContext, rawEmail: unknown): Promise<BillingContactView> {
    const category = validateContext(context);
    if (category.kind !== 'C') fail(category.kind === 'unverified' ? 'contact_auth_email_unverified' : 'contact_not_required');
    const email = normalizeBillingEmail(rawEmail);
    if (!email) throw new BillingContactError('contact_email_invalid');
    const sendMail = d.sendMail;
    if (typeof sendMail !== 'function') throw new BillingContactError('mail_unavailable');
    const time = now(), uid = context.identity.uid, token = random();
    if (!/^[A-Za-z0-9_-]{43}$/.test(token)) fail('test_configuration_invalid');
    const tokenHash = digest(uid + '\0' + email + '\0' + token);
    const result = await d.store.mutate(uid, state => {
      if (!stateIsSafe(state)) fail('contact_state_invalid');
      if (state.verified === true && state.email === email) return {state, result:'already_verified' as const};
      const requests = Array.isArray(state.requestedAt) ? state.requestedAt.filter((t: unknown) => isMillis(t) && t > time - DAY_MS) : [];
      if (requests.some((t: number) => t > time)) fail('server_clock_invalid');
      if ((state.lastRequestedAt && time - state.lastRequestedAt < BILLING_CONTACT_COOLDOWN_MS) || requests.length >= 5 || requests.filter((t: number) => t > time - HOUR_MS).length >= 3) fail('contact_rate_limited');
      if (state.pending && ['dispatching','uncertain'].includes(state.pending.deliveryState) && state.pending.expiresAt > time) fail('contact_delivery_pending');
      const next = {...state, purpose:PURPOSE, schemaVersion:1, createdAt:state.createdAt || time, updatedAt:time,
        verified:state.verified === true, source:state.verified === true ? state.source : null,
        lastRequestedAt:time, requestedAt:[...requests,time],
        pending:{email, tokenHash, createdAt:time, expiresAt:time + BILLING_CONTACT_TTL_MS, sentAt:null, deliveryState:'dispatching'}};
      return {state:next, result:'send' as const};
    });
    if (result === 'already_verified') return status(context);
    const verificationUrl = BILLING_CONTACT_PREVIEW_ORIGIN + '/account/contact/#token=' + token;
    try {
      await sendMail({from:BILLING_CONTACT_FROM,to:email,subject:'【HamCare Preview】連絡用メールアドレスの確認',verificationUrl,
        idempotencyKey:digest(PURPOSE + '\0' + uid + '\0' + tokenHash),
        text:'HamCare Previewの契約・請求・解約・重要なお知らせの連絡先を確認します。\n\n同じHamCareアカウントでログインし、次のリンクを開いて確認してください。リンクは15分間、1回だけ使用できます。\n' + verificationUrl + '\n\nこのメールに心当たりがなければ、リンクを使用せず破棄してください。個人の実メールは必須ではなく、アカウントの統合や本番契約の変更は行いません。広告配信には使用しません。'});
    } catch (cause) {
      const definite = object(cause) && cause.delivery === 'not_sent';
      await d.store.mutate(uid, state => {
        if (!state.pending || !sameHash(state.pending.tokenHash, tokenHash)) return {state,result:null};
        return {state:{...state,updatedAt:now(),pending:{...state.pending,deliveryState:definite?'failed':'uncertain'}},result:null};
      });
      fail(definite ? 'contact_delivery_failed' : 'contact_delivery_uncertain');
    }
    await d.store.mutate(uid, state => {
      if (!state.pending || !sameHash(state.pending.tokenHash, tokenHash)) return {state,result:null};
      const sentAt = now();
      return {state:{...state,updatedAt:sentAt,pending:{...state.pending,sentAt,deliveryState:'sent'}},result:null};
    });
    return status(context);
  }
  async function confirm(context: BillingContactContext, token: unknown): Promise<BillingContactView> {
    const category = validateContext(context);
    if (category.kind !== 'C') fail('contact_not_required');
    if (typeof token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(token)) fail('contact_token_invalid');
    const uid = context.identity.uid, time = now(), usedDigest = digest(uid + '\0' + token);
    await d.store.mutate(uid, state => {
      if (!stateIsSafe(state)) fail('contact_state_invalid');
      if (Array.isArray(state.usedTokenHashes) && state.usedTokenHashes.some((h: unknown) => sameHash(h, usedDigest))) fail('contact_token_used');
      const pending = state.pending;
      if (!pending || !sameHash(pending.tokenHash, digest(uid + '\0' + pending.email + '\0' + token)) || pending.deliveryState === 'failed') fail('contact_token_invalid');
      if (pending.expiresAt <= time) fail('contact_token_expired');
      const next: BillingContactState = {...state,email:pending.email,verified:true,verificationStatus:'verified',verifiedAt:time,updatedAt:time,source:'user_supplied',
        usedTokenHashes:[...(Array.isArray(state.usedTokenHashes)?state.usedTokenHashes:[]).slice(-9),usedDigest]};
      delete next.pending;
      return {state:next,result:null};
    });
    return status(context);
  }
  async function requireVerified(context: BillingContactContext): Promise<{email:string;source:'auth_verified'|'apple_relay'|'user_supplied'}> {
    const category = validateContext(context);
    if (category.kind === 'A' || category.kind === 'B') return {email:category.email!,source:category.source!};
    if (category.kind !== 'C') fail('contact_auth_email_unverified');
    const state = await d.store.read(context.identity.uid);
    if (!stateIsSafe(state)) fail('contact_state_invalid');
    const active = activeContact(state);
    if (!active) fail('contact_verification_required');
    return active!;
  }
  return {status,request,confirm,requireVerified};
}
