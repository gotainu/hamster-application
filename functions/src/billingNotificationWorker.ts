import {createHash, randomUUID} from 'node:crypto';
import {normalizeBillingEmail, validWebBillingUid} from './webBillingShared';

export type BillingNotificationEnvironment = 'live' | 'preview';
export type BillingNotificationType = 'contract_registered' | 'payment_success' | 'payment_failed' | 'cancel_reserved' | 'resumed' | 'canceled';
export type BillingNotificationStatus = 'pending' | 'claimed' | 'sending' | 'failed_retryable' | 'sent' |
  'failed_permanent' | 'blocked_no_verified_contact' | 'blocked_recipient_not_allowed' | 'blocked_invalid_notification' | 'uncertain' | 'held_before_dispatch_start';
export interface BillingNotificationRecord {
  id: string;
  schemaVersion: 1;
  environment: BillingNotificationEnvironment;
  trustedSource: 'stripe_webhook' | 'preview_fixture';
  templateVersion: 'billing-v1';
  type: BillingNotificationType;
  firebaseUid: string;
  transitionKey: string;
  eventHash: string;
  /** Immutable, non-PII billing facts captured by the trusted producer.
   * Rendering validates its exact schema; do not substitute current billing. */
  snapshot: Record<string, unknown>;
  status: BillingNotificationStatus;
  createdAtMillis: number;
  /** Canonical Stripe event time, separate from enqueue/processing time. */
  eventCreatedAtMillis?: number;
  attempts?: number;
  nextAttemptAtMillis?: number;
  dispatchAtMillis?: number;
  [key: string]: unknown;
}
export interface BillingNotificationWorkerConfig {
  environment: BillingNotificationEnvironment;
  maxAttempts: number;
  baseDelayMillis: number;
  maxDelayMillis: number;
  leaseMillis: number;
  batchSize: number;
}
export type BillingNotificationRecipientSource = 'auth_verified' | 'apple_relay' | 'user_supplied';
export interface BillingNotificationRecipient {email: string; source: BillingNotificationRecipientSource;}
export interface BillingNotificationMessage {subject: string; text: string; html: string; templateVersion: string;}
export interface BillingNotificationClaim {
  kind: 'claimed'; notification: BillingNotificationRecord; leaseToken: string; attemptId: string;
}
export type BillingNotificationClaimResult = BillingNotificationClaim | {kind: 'skipped' | 'uncertain' | 'blocked' | 'exhausted' | 'held'};
export interface BillingNotificationOutcome {
  status: 'sent' | 'failed_retryable' | 'failed_permanent' | 'blocked_no_verified_contact' |
    'blocked_recipient_not_allowed' | 'blocked_invalid_notification' | 'uncertain';
  atMillis: number;
  lastErrorCategory?: string;
  nextAttemptAtMillis?: number;
  messageIdHash?: string;
}
export interface BillingNotificationStore {
  listDue(nowMillis: number, limit: number): Promise<string[]>;
  claim(input: {id: string; environment: BillingNotificationEnvironment; leaseToken: string; attemptId: string;
    nowMillis: number; leaseUntilMillis: number; maxAttempts: number}): Promise<BillingNotificationClaimResult>;
  beginSend(input: {id: string; leaseToken: string; attemptId: string; nowMillis: number;
    leaseUntilMillis: number; recipientSource: BillingNotificationRecipientSource; recipientReference: string}): Promise<boolean>;
  finish(input: {id: string; leaseToken: string; attemptId: string; outcome: BillingNotificationOutcome}): Promise<boolean>;
}
export interface BillingNotificationWorkerDependencies {
  config: BillingNotificationWorkerConfig;
  store: BillingNotificationStore;
  resolveRecipient(uid: string): Promise<BillingNotificationRecipient | null>;
  render(notification: BillingNotificationRecord): BillingNotificationMessage;
  send(input: {notificationId: string; uid: string; to: string; subject: string; text: string; html: string}): Promise<{messageIdHash: string}>;
  /** Transactional global/per-UID budget, environment-specific. Reservation is
   * before send intent and may conservatively consume a slot on a crash. */
  reserveDelivery(input: {uid: string; notificationId: string; attemptId: string; nowMillis: number}): Promise<{allowed: boolean; nextAttemptAtMillis?: number}>;
  allowedRecipient?(uid: string, email: string): boolean;
  now(): number;
  randomToken?(): string;
}
export class BillingNotificationWorkerError extends Error {
  constructor(readonly code: 'configuration_invalid' | 'clock_invalid' | 'state_invalid') {
    super('Billing notification processing is unavailable.'); this.name = 'BillingNotificationWorkerError';
  }
}
const TYPES = new Set(['contract_registered','payment_success','payment_failed','cancel_reserved','resumed','canceled']);
const STATUSES = new Set(['pending','claimed','sending','failed_retryable','sent','failed_permanent','blocked_no_verified_contact','blocked_recipient_not_allowed','blocked_invalid_notification','uncertain','held_before_dispatch_start']);
const SOURCES = new Set(['auth_verified','apple_relay','user_supplied']);
const ERROR_CATEGORIES = new Set(['configuration_invalid','recipient_not_allowed','invalid_recipient','request_invalid','authorization_revoked',
  'authorization_failed','oauth_temporary','rate_limited','quota_exceeded','sending_limit','gmail_temporary','delivery_uncertain','gmail_permanent']);
export const isBillingNotificationHash = (v: unknown): v is string => typeof v === 'string' && /^[a-f0-9]{64}$/.test(v);
export const isBillingNotificationMillis = (v: unknown): v is number => Number.isSafeInteger(v) && Number(v) > 0;
const object = (v: unknown): v is Record<string, any> => !!v && typeof v === 'object' && !Array.isArray(v);
export function validBillingNotificationRecord(value: unknown, id: string, environment: BillingNotificationEnvironment): value is BillingNotificationRecord {
  if (!object(value) || !isBillingNotificationHash(id) || value.id!==id || value.schemaVersion!==1 || value.environment!==environment ||
    !['live','preview'].includes(environment) || value.templateVersion!=='billing-v1' || !validWebBillingUid(value.firebaseUid) ||
    !TYPES.has(value.type) || !STATUSES.has(value.status) || !isBillingNotificationHash(value.eventHash) ||
    typeof value.transitionKey!=='string' || !value.transitionKey || value.transitionKey.length>1024 || /[\u0000-\u001f\u007f]/u.test(value.transitionKey) ||
    !isBillingNotificationMillis(value.createdAtMillis) || !object(value.snapshot) ||
    (value.attempts!==undefined && (!Number.isSafeInteger(value.attempts) || value.attempts<0)) ||
    !['stripe_webhook','preview_fixture'].includes(value.trustedSource) || (environment==='live' && value.trustedSource!=='stripe_webhook')) return false;
  return true;
}
export function validateBillingNotificationWorkerConfig(value: BillingNotificationWorkerConfig): BillingNotificationWorkerConfig {
  if (!object(value) || Object.keys(value).some(k=>!['environment','maxAttempts','baseDelayMillis','maxDelayMillis','leaseMillis','batchSize'].includes(k)) ||
    !['live','preview'].includes(value.environment) || !Number.isSafeInteger(value.maxAttempts) || value.maxAttempts<1 || value.maxAttempts>10 ||
    !Number.isSafeInteger(value.baseDelayMillis) || value.baseDelayMillis<1000 || value.baseDelayMillis>3600000 ||
    !Number.isSafeInteger(value.maxDelayMillis) || value.maxDelayMillis<value.baseDelayMillis || value.maxDelayMillis>86400000 ||
    !Number.isSafeInteger(value.leaseMillis) || value.leaseMillis<30000 || value.leaseMillis>600000 ||
    !Number.isSafeInteger(value.batchSize) || value.batchSize<1 || value.batchSize>20) throw new BillingNotificationWorkerError('configuration_invalid');
  return Object.freeze({...value});
}

/** Email delivery has no billing mutation dependency. A durable sending intent
 * precedes Gmail. Gmail send has no idempotency key: unknown outcomes and stale
 * sending leases are quarantined for reconciliation, never blindly resent. */
export function createBillingNotificationWorker(d: BillingNotificationWorkerDependencies) {
  const config=validateBillingNotificationWorkerConfig(d.config);
  if (typeof d.reserveDelivery!=='function' || (config.environment==='preview' && typeof d.allowedRecipient!=='function')) throw new BillingNotificationWorkerError('configuration_invalid');
  function now() {const n=d.now();if (!isBillingNotificationMillis(n)) throw new BillingNotificationWorkerError('clock_invalid');return n;}
  function token() {const v=(d.randomToken??randomUUID)();if (!/^[A-Za-z0-9_-]{1,128}$/.test(v)) throw new BillingNotificationWorkerError('state_invalid');return v;}
  function retry(notification:BillingNotificationRecord, at:number, category:string, retryAfter?:number): BillingNotificationOutcome {
    if ((notification.attempts??0)>=config.maxAttempts) return {status:'failed_permanent',atMillis:at,lastErrorCategory:'attempt_limit'};
    const exponent=Math.max(0,(notification.attempts??1)-1);
    const delay=Math.min(config.maxDelayMillis,config.baseDelayMillis * 2**exponent);
    const requested=Number.isSafeInteger(retryAfter) && Number(retryAfter)>0 ? Number(retryAfter) : 0;
    // Gmail daily quota is a rolling window, not a promise of UTC midnight reset.
    const quota=['quota_exceeded','sending_limit'].includes(category) ? 86400000 : 0;
    const nextAttemptAtMillis=at+Math.max(delay,requested,quota);
    if (!isBillingNotificationMillis(nextAttemptAtMillis)) return {status:'failed_permanent',atMillis:at,lastErrorCategory:'retry_schedule_invalid'};
    return {status:'failed_retryable',atMillis:at,lastErrorCategory:category,nextAttemptAtMillis};
  }
  async function process(id:string):Promise<string> {
    const time=now(), leaseToken=token(), attemptId=token();
    const claimed=await d.store.claim({id,environment:config.environment,leaseToken,attemptId,nowMillis:time,leaseUntilMillis:time+config.leaseMillis,maxAttempts:config.maxAttempts});
    if (claimed.kind!=='claimed') return claimed.kind;
    const n=claimed.notification;
    const finish=(outcome:BillingNotificationOutcome)=>d.store.finish({id,leaseToken,attemptId,outcome});
    let recipient:BillingNotificationRecipient|null;
    try {recipient=await d.resolveRecipient(n.firebaseUid);} catch {
      const outcome=retry(n,now(),'recipient_unavailable');await finish(outcome);return outcome.status;
    }
    if (!recipient) {await finish({status:'blocked_no_verified_contact',atMillis:now(),lastErrorCategory:'no_verified_contact'});return 'blocked';}
    const email=normalizeBillingEmail(recipient.email);
    if (!email || !SOURCES.has(recipient.source)) {await finish({status:'blocked_no_verified_contact',atMillis:now(),lastErrorCategory:'contact_invalid'});return 'blocked';}
    if (d.allowedRecipient && d.allowedRecipient(n.firebaseUid,email)!==true) {await finish({status:'blocked_recipient_not_allowed',atMillis:now(),lastErrorCategory:'recipient_not_allowed'});return 'blocked';}
    let message:BillingNotificationMessage;
    try {
      message=d.render(n);
      if (!message || message.templateVersion!==n.templateVersion || typeof message.subject!=='string' || !message.subject || /[\r\n]/.test(message.subject) ||
        typeof message.text!=='string' || !message.text || typeof message.html!=='string' || !message.html) throw new Error();
    } catch {await finish({status:'blocked_invalid_notification',atMillis:now(),lastErrorCategory:'template_invalid'});return 'blocked';}
    try {
      const budget=await d.reserveDelivery({uid:n.firebaseUid,notificationId:id,attemptId,nowMillis:now()});
      if (!budget || budget.allowed!==true) {
        const at=now(), next=budget?.nextAttemptAtMillis;
        const outcome=retry(n,at,'local_sending_limit',isBillingNotificationMillis(next) && next>at ? next-at : 86400000);
        await finish(outcome);return outcome.status;
      }
    } catch {const outcome=retry(n,now(),'budget_unavailable');await finish(outcome);return outcome.status;}
    const sendTime=now();
    const ready=await d.store.beginSend({id,leaseToken,attemptId,nowMillis:sendTime,leaseUntilMillis:sendTime+config.leaseMillis,
      recipientSource:recipient.source,recipientReference:createHash('sha256').update(n.firebaseUid+':'+recipient.source).digest('hex')});
    if (!ready) return 'skipped';
    try {
      const result=await d.send({notificationId:id,uid:n.firebaseUid,to:email,subject:message.subject,text:message.text,html:message.html});
      if (!isBillingNotificationHash(result?.messageIdHash)) throw new Error();
      // If this write fails, the durable sending intent remains. A successor
      // marks it uncertain, never sends again, and operations can reconcile it.
      const recorded=await finish({status:'sent',atMillis:now(),messageIdHash:result.messageIdHash});return recorded?'sent':'uncertain';
    } catch (error) {
      const value=object(error)?error:null;
      const category=value && ERROR_CATEGORIES.has(value.category)?value.category:'delivery_uncertain';
      const certain=value?.delivery==='not_sent';
      const outcome:BillingNotificationOutcome=!certain
        ? {status:'uncertain',atMillis:now(),lastErrorCategory:category}
        : value?.retryable===true ? retry(n,now(),category,value.retryAfterMillis)
          : {status:'failed_permanent',atMillis:now(),lastErrorCategory:category};
      await finish(outcome);return outcome.status;
    }
  }
  return {
    async runOnce() {
      const ids=await d.store.listDue(now(),config.batchSize);
      if (!Array.isArray(ids) || ids.length>config.batchSize || ids.some(id=>!isBillingNotificationHash(id)) || new Set(ids).size!==ids.length) throw new BillingNotificationWorkerError('state_invalid');
      const counts:Record<string,number>={};
      // A small bounded sequential batch prevents burst/retry fanout for a
      // personal Gmail account. Distinct invocations are fenced by the store.
      for (const id of ids) {const result=await process(id);counts[result]=(counts[result]??0)+1;}
      return {processed:ids.length,counts};
    },
  };
}
