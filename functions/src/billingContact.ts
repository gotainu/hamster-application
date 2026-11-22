import {createHash, randomBytes, timingSafeEqual} from 'crypto';
import type {WebBillingIdentity as Identity} from './webBillingShared';
import {normalizeBillingEmail, maskBillingEmail, classifyBillingEmail, BillingEmailClassification, readVerifiedBillingContact} from './webBillingShared';
export {normalizeBillingEmail, maskBillingEmail, classifyBillingEmail, BillingEmailClassification, readVerifiedBillingContact} from './webBillingShared';

export const BILLING_CONTACT_NAMESPACE = 'preview_billing_contacts';
export const BILLING_CONTACT_FROM = 'gotainu@gmail.com';
export const BILLING_CONTACT_PREVIEW_ORIGIN = 'https://hamster-breeding-app--web-first-task1-lco08m60.web.app';
export const BILLING_CONTACT_TTL_MS = 15 * 60 * 1000;
export const BILLING_CONTACT_COOLDOWN_MS = 60 * 1000;
export const BILLING_CONTACT_LIVE_NAMESPACE = 'billing_contacts';
export const BILLING_CONTACT_LIVE_ORIGIN = 'https://hamster-breeding-app.web.app';
export const BILLING_CONTACT_LIVE_PURPOSE = 'billing_contact_live';
export type BillingContactEnvironment = 'preview'|'live';
const purposeFor = (environment:BillingContactEnvironment) => environment==='live'?BILLING_CONTACT_LIVE_PURPOSE:'billing_contact_preview';
const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;
const object = (v: unknown): v is Record<string, any> => !!v && typeof v === 'object' && !Array.isArray(v);
const validUid = (v: unknown): v is string => typeof v === 'string' && v.length > 0 && v.length <= 128 && !/[\/\s\u0000-\u001f\u007f]/u.test(v);
const digest = (v: string) => createHash('sha256').update(v).digest('hex');
const sameHash = (a: unknown, b: string) => typeof a === 'string' && /^[a-f0-9]{64}$/.test(a) && timingSafeEqual(Buffer.from(a, 'hex'), Buffer.from(b, 'hex'));
const isMillis = (v: unknown): v is number => Number.isSafeInteger(v) && Number(v) > 0;
const iso = (v: number | null) => v === null ? null : new Date(v).toISOString();
export class BillingContactError extends Error {constructor(public code: string) {super(code);}}
function fail(code:string):never {throw new BillingContactError(code);}

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
  testMode: boolean; emailClass: BillingEmailClassification['kind'];
  verificationStatus: 'verified'|'missing'|'pending'|'expired'|'delivery_failed'|'delivery_uncertain'|'unverified'|'invalid';
  verified: boolean; canCheckout: boolean; maskedEmail: string|null; pendingMaskedEmail: string|null;
  pendingDeliveryState: 'dispatching'|'sent'|'failed'|'uncertain'|null;
  source: 'auth_verified'|'apple_relay'|'user_supplied'|null;
  verificationSentAt: number|null; verifiedAt: number|null; resendAfter: string|null; expiresAt: string|null;
}
export interface BillingContactDependencies {
  /** Preview remains default only for the compatibility wrapper. Live callers must be explicit. */
  environment?: BillingContactEnvironment;
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
function stateIsSafe(state: BillingContactState, environment:BillingContactEnvironment, uid:string, time:number): boolean {
  const purpose=purposeFor(environment);
  if (!object(state)) return false;
  if (environment==='live' && Object.keys(state).length && (state.purpose!==purpose || state.schemaVersion!==1 || state.firebaseUid!==uid)) return false;
  if (state.purpose !== undefined && state.purpose !== purpose) return false;
  if (environment==='live' && ((state.requestedAt!==undefined && (!Array.isArray(state.requestedAt) || state.requestedAt.some((v:unknown)=>!isMillis(v)||v>time))) ||
      (state.lastRequestedAt!==undefined && (!isMillis(state.lastRequestedAt)||state.lastRequestedAt>time)))) return false;
  if (environment==='live' && state.verified===true && readVerifiedBillingContact(state,uid,'live',time)===null) return false;
  if (state.verified === true && (!normalizeBillingEmail(state.email) || !isMillis(state.verifiedAt) || state.source !== 'user_supplied')) return false;
  if (state.pending !== undefined && (!object(state.pending) || !normalizeBillingEmail(state.pending.email) ||
      !/^[a-f0-9]{64}$/.test(state.pending.tokenHash) || !isMillis(state.pending.expiresAt) || !isMillis(state.pending.createdAt) ||
      !['dispatching','sent','failed','uncertain'].includes(state.pending.deliveryState))) return false;
  return true;
}
function activeContact(state: BillingContactState): {email: string; source:'user_supplied'}|null {
  return state.verified === true ? {email: state.email, source:'user_supplied'} : null;
}
function describe(category: BillingEmailClassification, state: BillingContactState, now: number, environment:BillingContactEnvironment, uid:string): BillingContactView {
  if (!stateIsSafe(state,environment,uid,now)) fail('contact_state_invalid');
  const inherent = category.kind === 'A' || category.kind === 'B';
  const active = category.kind === 'C' ? activeContact(state) : null;
  const pending = category.kind === 'C' ? state.pending : undefined;
  const verified = inherent || !!active;
  const pendingStatus = !pending ? 'missing' : pending.expiresAt <= now ? 'expired' :
    pending.deliveryState === 'failed' ? 'delivery_failed' : pending.deliveryState === 'uncertain' || pending.deliveryState === 'dispatching' ? 'delivery_uncertain' : 'pending';
  const email = inherent ? category.email : active?.email;
  return {
    testMode:environment==='preview', emailClass:category.kind,
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
  const environment=d.environment??'preview';
  if (!['preview','live'].includes(environment)) fail('contact_configuration_invalid');
  const purpose=purposeFor(environment);
  const origin=environment==='live'?BILLING_CONTACT_LIVE_ORIGIN:BILLING_CONTACT_PREVIEW_ORIGIN;
  // Preserve in-flight Preview links. Live proofs bind the environment as well as UID/email.
  const proofHash=(uid:string,email:string,token:string)=>digest((environment==='live'?purpose+'\0':'')+uid+'\0'+email+'\0'+token);
  const usedHash=(uid:string,token:string)=>digest((environment==='live'?purpose+'\0':'')+uid+'\0'+token);
  const label=environment==='live'?'HamCare':'HamCare Preview';
  const now = () => {const time = d.now().getTime(); if (!isMillis(time)) fail('server_clock_invalid'); return time;};
  const random = d.randomToken || (() => randomBytes(32).toString('base64url'));
  async function status(context: BillingContactContext): Promise<BillingContactView> {
    const category = validateContext(context);
    if (category.kind === 'A' || category.kind === 'B' || category.kind === 'unverified') return describe(category, {}, now(),environment,context.identity.uid);
    return describe(category, await d.store.read(context.identity.uid), now(),environment,context.identity.uid);
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
    const tokenHash = proofHash(uid,email,token);
    const result = await d.store.mutate(uid, state => {
      if (!stateIsSafe(state,environment,uid,time)) fail('contact_state_invalid');
      if (state.verified === true && state.email === email) return {state, result:'already_verified' as const};
      const requests = Array.isArray(state.requestedAt) ? state.requestedAt.filter((t: unknown) => isMillis(t) && t > time - DAY_MS) : [];
      if (requests.some((t: number) => t > time)) fail('server_clock_invalid');
      if ((state.lastRequestedAt && time - state.lastRequestedAt < BILLING_CONTACT_COOLDOWN_MS) || requests.length >= 5 || requests.filter((t: number) => t > time - HOUR_MS).length >= 3) fail('contact_rate_limited');
      if (state.pending && ['dispatching','uncertain'].includes(state.pending.deliveryState) && state.pending.expiresAt > time) fail('contact_delivery_pending');
      const next = {...state, purpose, schemaVersion:1, ...(environment==='live'?{firebaseUid:uid}:{}), createdAt:state.createdAt || time, updatedAt:time,
        verified:state.verified === true, source:state.verified === true ? state.source : null,
        lastRequestedAt:time, requestedAt:[...requests,time],
        pending:{email, tokenHash, createdAt:time, expiresAt:time + BILLING_CONTACT_TTL_MS, sentAt:null, deliveryState:'dispatching'}};
      return {state:next, result:'send' as const};
    });
    if (result === 'already_verified') return status(context);
    const verificationUrl = origin + '/account/contact/#token=' + token;
    try {
      await sendMail({from:BILLING_CONTACT_FROM,to:email,subject:'【'+label+'】連絡用メールアドレスの確認',verificationUrl,
        idempotencyKey:digest(purpose + '\0' + uid + '\0' + tokenHash),
        text:label+'の契約・請求・解約・重要なお知らせの連絡先を確認します。\n\n同じHamCareアカウントでログインし、次のリンクを開いて確認してください。リンクは15分間、1回だけ使用できます。\n' + verificationUrl + '\n\nこのメールに心当たりがなければ、リンクを使用せず破棄してください。個人の実メールは必須ではありません。この連絡先をAuthへ逆同期したり、メール一致でアカウントを統合したりしません。広告配信には使用しません。'});
    } catch (cause) {
      const definite = object(cause) && cause.delivery === 'not_sent';
      await d.store.mutate(uid, state => {
        if (!state.pending || !sameHash(state.pending.tokenHash, tokenHash)) return {state,result:null};
        return {state:{...state,updatedAt:now(),pending:{...state.pending,deliveryState:definite?'failed':'uncertain'}},result:null};
      });
      if (environment==='live' && object(cause) && cause.code==='contact_rate_limited') fail('contact_rate_limited');
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
    const uid = context.identity.uid, time = now(), usedDigest = usedHash(uid,token);
    await d.store.mutate(uid, state => {
      if (!stateIsSafe(state,environment,uid,time)) fail('contact_state_invalid');
      if (Array.isArray(state.usedTokenHashes) && state.usedTokenHashes.some((h: unknown) => sameHash(h, usedDigest))) fail('contact_token_used');
      const pending = state.pending;
      if (!pending || !sameHash(pending.tokenHash, proofHash(uid,pending.email,token)) || pending.deliveryState === 'failed') fail('contact_token_invalid');
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
    const uid=context.identity.uid;
    const state = await d.store.read(uid);
    if (!stateIsSafe(state,environment,uid,now())) fail('contact_state_invalid');
    const active = activeContact(state);
    if (!active) fail('contact_verification_required');
    return active!;
  }
  return {status,request,confirm,requireVerified};
}
