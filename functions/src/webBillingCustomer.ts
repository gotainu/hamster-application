import {createHash, randomUUID} from 'crypto';
import {assertLiveObject, BillingConfigurationError} from './webBillingConfig';
import {normalizeBillingEmail, validWebBillingUid} from './webBillingShared';

export const WEB_BILLING_CUSTOMER_LEASE_MS = 90 * 1000;
// Stripe can remove idempotency keys after 24 hours. Never start another create
// once the original operation reaches that boundary, even with the same key.
export const WEB_BILLING_CUSTOMER_OPERATION_MAX_MS = 24 * 60 * 60 * 1000;
type Data = Record<string, any>;
export interface WebBillingCustomerStore {
  read(uid: string): Promise<Data>;
  mutate<T>(uid: string, update: (state: Data) => {state: Data; result: T}): Promise<T>;
}
export interface WebBillingCustomerDependencies {
  stripe: {customers: {
    retrieve(id: string): Promise<unknown>;
    search(input: {query: string; limit: number}): Promise<unknown>;
    create(input: {email: string; metadata: {firebaseUid: string}}, options: {idempotencyKey: string}): Promise<unknown>;
  }};
  /** Coordination only: billing_customers/{sha256(uid)}, never users billing. */
  store: WebBillingCustomerStore;
  readBilling(uid: string): Promise<{kind: string; data?: unknown}>;
  now(): Date;
  randomLeaseToken?(): string;
}
export interface WebBillingCustomerInput {
  uid: string;
  mode: 'create-if-missing' | 'require-existing';
  /** Server-verified billing contact only. Existing Customers are never updated. */
  email?: string;
}
export class WebBillingCustomerError extends Error {
  readonly code = 'customer_unresolved';
  constructor() {
    super('現在の契約情報を確認できません。時間をおいて再度お試しください。');
    this.name = 'WebBillingCustomerError';
  }
}
function fail(): never {throw new WebBillingCustomerError();}
function record(value: unknown): value is Data {return !!value && typeof value === 'object' && !Array.isArray(value);}
const millis = (value: unknown): value is number => Number.isSafeInteger(value) && Number(value) > 0;
const customerId = (value: unknown): value is string => typeof value === 'string' && /^cus_[A-Za-z0-9_]{1,240}$/.test(value);
export const webBillingCustomerSubject = (uid: string): string => createHash('sha256').update(uid).digest('hex');
export const webBillingCustomerIdempotencyKey = (uid: string): string => 'hamcare-web-customer-v1:' + webBillingCustomerSubject(uid);

/** Configuration must already have been validated by the HTTP operation before
 * constructing/calling this resolver. No email search, entitlement write or
 * mutation of an existing Stripe Customer is available through this interface. */
export function createWebBillingCustomerResolver(d: WebBillingCustomerDependencies) {
  function now(): number {
    const date = d.now();
    if (!(date instanceof Date) || !millis(date.getTime())) fail();
    return date.getTime();
  }
  function state(value: unknown, uid: string): Data {
    if (!record(value) || (value.firebaseUid !== undefined && value.firebaseUid !== uid) ||
        value.stripeLivemode === false || value.testMode === true || Object.keys(value).some(key=>/^preview/i.test(key))) fail();
    if (value.customerId !== undefined && (!customerId(value.customerId) || value.firebaseUid !== uid)) fail();
    if (value.customerOperation !== undefined) {
      const op = value.customerOperation;
      if (value.firebaseUid !== uid || !record(op) || op.id !== webBillingCustomerIdempotencyKey(uid) ||
          !millis(op.startedAt) || !['creating', 'uncertain'].includes(op.state)) fail();
    }
    if (value.customerLease !== undefined) {
      const lease = value.customerLease;
      if (!value.customerOperation || !record(lease) || typeof lease.token !== 'string' ||
          !/^[A-Za-z0-9_-]{1,128}$/.test(lease.token) || !millis(lease.until)) fail();
    }
    return value;
  }
  function ownCustomer(value: unknown, uid: string, expected?: string): string {
    assertLiveObject(value);
    if (value.deleted || !customerId(value.id) || (expected !== undefined && value.id !== expected) ||
        !record(value.metadata) || value.metadata.firebaseUid !== uid || Object.keys(value.metadata).some(key=>/^preview/i.test(key))) fail();
    return value.id;
  }
  async function billingCustomer(uid: string): Promise<string | null> {
    const source = await d.readBilling(uid);
    if (!record(source)) fail();
    if (source.kind === 'missing') return null;
    if (source.kind !== 'found' || !record(source.data)) fail();
    if (source.data.stripeCustomerId !== undefined && source.data.stripeCustomerId !== null) {
      if (!customerId(source.data.stripeCustomerId)) fail();
      return source.data.stripeCustomerId;
    }
    // Paid or unresolved application billing must never be replaced with a new
    // Stripe Customer merely because its stored reference is missing.
    if (source.data.plan !== 'none' || !['none', 'canceled'].includes(source.data.status)) fail();
    return null;
  }
  async function findByUid(uid: string): Promise<string | null> {
    // UIDs can contain quotes. Escape Stripe's search grammar rather than
    // interpolating the UID as an unescaped expression or searching by email.
    const escaped = uid.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
    const found = await d.stripe.customers.search({query:"metadata['firebaseUid']:'" + escaped + "'", limit:2});
    if (!record(found) || found.has_more !== false || !Array.isArray(found.data) || found.data.length > 1) fail();
    return found.data.length === 1 ? ownCustomer(found.data[0], uid) : null;
  }
  async function bindExisting(uid: string, id: string): Promise<void> {
    const time = now();
    await d.store.mutate(uid, current => {
      const saved = state(current, uid);
      if (saved.customerId && saved.customerId !== id) fail();
      // A concurrent creator still owns its lease. The UID-bound object is safe
      // to return, but this caller cannot replace that in-flight coordination.
      if (saved.customerLease?.until > time) return {state:saved, result:null};
      const next: Data = {...saved, firebaseUid:uid, customerId:id};
      delete next.customerOperation; delete next.customerLease;
      return {state:next, result:null};
    });
  }
  async function commitCreated(uid: string, id: string, token: string): Promise<void> {
    await d.store.mutate(uid, current => {
      const saved = state(current, uid);
      if (saved.customerId) {
        if (saved.customerId !== id) fail();
        return {state:saved, result:null};
      }
      if (saved.customerLease?.token !== token || saved.customerOperation?.id !== webBillingCustomerIdempotencyKey(uid)) fail();
      const next: Data = {...saved, firebaseUid:uid, customerId:id};
      delete next.customerOperation; delete next.customerLease;
      return {state:next, result:null};
    });
  }
  async function uncertain(uid: string, token: string): Promise<void> {
    await d.store.mutate(uid, current => {
      const saved = state(current, uid);
      if (saved.customerId || saved.customerLease?.token !== token) return {state:saved, result:null};
      // Preserve both the original start time and lease. Unknown outcomes never
      // reset the operation or permit a fresh idempotency key after expiration.
      return {state:{...saved, customerOperation:{...saved.customerOperation, state:'uncertain'}}, result:null};
    });
  }
  async function resolveCustomer(input: WebBillingCustomerInput): Promise<{customerId: string}> {
    if (!record(input) || !validWebBillingUid(input.uid) ||
        !['create-if-missing', 'require-existing'].includes(input.mode)) fail();
    const uid = input.uid, time = now();
    const saved = state(await d.store.read(uid), uid), billingId = await billingCustomer(uid);
    if (saved.customerId && billingId && saved.customerId !== billingId) fail();
    const known = saved.customerId || billingId;
    if (known) {
      const id = ownCustomer(await d.stripe.customers.retrieve(known), uid, known);
      if (!saved.customerId && input.mode === 'create-if-missing') await bindExisting(uid, id);
      return {customerId:id};
    }
    const found = await findByUid(uid);
    if (found) {
      if (input.mode === 'create-if-missing') await bindExisting(uid, found);
      return {customerId:found};
    }
    if (input.mode !== 'create-if-missing') fail();
    const email = normalizeBillingEmail(input.email);
    if (!email) fail();
    const token = d.randomLeaseToken ? d.randomLeaseToken() : randomUUID();
    if (!/^[A-Za-z0-9_-]{1,128}$/.test(token)) fail();
    const reservation = await d.store.mutate<{kind:'known'; id:string} | {kind:'reserved'}>(uid, current => {
      const latest = state(current, uid);
      if (latest.customerId) return {state:latest, result:{kind:'known' as const, id:latest.customerId as string}};
      if (latest.customerLease?.until > time) fail();
      const startedAt = latest.customerOperation?.startedAt ?? time;
      if (startedAt > time || time - startedAt >= WEB_BILLING_CUSTOMER_OPERATION_MAX_MS) fail();
      return {state:{...latest, firebaseUid:uid,
        customerOperation:{id:webBillingCustomerIdempotencyKey(uid), startedAt, state:'creating'},
        customerLease:{token, until:time + WEB_BILLING_CUSTOMER_LEASE_MS}}, result:{kind:'reserved' as const}};
    });
    if (reservation.kind === 'known') {
      return {customerId:ownCustomer(await d.stripe.customers.retrieve(reservation.id), uid, reservation.id)};
    }
    try {
      // Recheck after winning a lease, including takeovers, so an already
      // completed but locally uncommitted Customer is recovered before create.
      const recovered = await findByUid(uid);
      if (recovered) {await commitCreated(uid, recovered, token); return {customerId:recovered};}
      const latestBilling = await billingCustomer(uid);
      if (latestBilling) {
        const id = ownCustomer(await d.stripe.customers.retrieve(latestBilling), uid, latestBilling);
        await commitCreated(uid, id, token); return {customerId:id};
      }
      // The lease and idempotency horizon are checked again immediately before
      // the external mutation. A stalled owner cannot create after a takeover.
      const current = state(await d.store.read(uid), uid), createTime = now();
      if (current.customerId) return {customerId:ownCustomer(await d.stripe.customers.retrieve(current.customerId), uid, current.customerId)};
      if (current.customerLease?.token !== token || current.customerLease.until <= createTime ||
          current.customerOperation?.startedAt > createTime ||
          createTime - current.customerOperation?.startedAt >= WEB_BILLING_CUSTOMER_OPERATION_MAX_MS) fail();
      const created = await d.stripe.customers.create({email, metadata:{firebaseUid:uid}}, {idempotencyKey:webBillingCustomerIdempotencyKey(uid)});
      const id = ownCustomer(created, uid);
      await commitCreated(uid, id, token);
      return {customerId:id};
    } catch (cause) {
      // A timeout, transport failure or invalid response is ambiguous. Do not
      // expose SDK errors, drop the operation, or issue another creation key.
      await uncertain(uid, token);
      fail();
    }
  }
  return {async resolveCustomer(input: WebBillingCustomerInput): Promise<{customerId:string}> {
    try {return await resolveCustomer(input);}
    catch (cause) {
      if (cause instanceof WebBillingCustomerError || cause instanceof BillingConfigurationError) throw cause;
      fail();
    }
  }};
}
