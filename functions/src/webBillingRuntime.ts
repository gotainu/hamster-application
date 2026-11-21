import type * as admin from 'firebase-admin';
import Stripe from 'stripe';
import {createHash} from 'crypto';
import {BillingConfigurationError, parseWebBillingConfig} from './webBillingConfig';
import {authorizeWebBillingIdentity, authorizeWebBillingManagementIdentity, BillingAuthenticationError, classifyBillingEmail,
  normalizeBillingEmail, validWebBillingUid, WebBillingIdentity} from './webBillingShared';
import {createWebBillingCheckout, WebBillingCheckoutStore, WEB_BILLING_CONTACT_PURPOSE} from './webBillingCheckout';
import {createWebBillingCustomerResolver} from './webBillingCustomer';
import {createWebBillingPortalEngine} from './webBillingPortal';
import {createWebBillingWebhook, verifyWebBillingEvent} from './webBillingWebhook';
import {createWebBillingWebhookStore} from './webBillingWebhookStore';
import {accountDeletionRef} from './accountDeletion';

type Data = Record<string, any>;
const object = (v: unknown): v is Data => !!v && typeof v === 'object' && !Array.isArray(v);
export const WEB_BILLING_UNAVAILABLE = '現在お申し込みを受け付けていません。';
export interface WebBillingRequest {
  data: unknown;
  auth?: {uid: string};
  rawRequest: {headers: Record<string, unknown>};
}
export interface WebBillingRuntimeDependencies {
  db: FirebaseFirestore.Firestore;
  auth: Pick<admin.auth.Auth, 'verifyIdToken' | 'getUser'>;
  /** Dedicated production JSON only; never old STRIPE_* or Preview values. */
  rawConfig(): unknown;
  stripeFactory?(key: string): Stripe;
  now?(): Date;
}
export function readWebBillingConfig(raw: unknown) {
  try {
    const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;
    return parseWebBillingConfig(parsed as Record<string, unknown>);
  } catch {throw new BillingConfigurationError();}
}
/** The allowlist deliberately exposes no raw SDK errors, identifiers, request
 * bodies, configuration names or credential values to clients or loggers. */
export function safeWebBillingError(error: unknown): {code:'unauthenticated'|'unavailable'; message:string} {
  return error instanceof BillingAuthenticationError && error.code==='unauthenticated'
    ? {code:'unauthenticated',message:'HamCareアカウントへログインしてください。'}
    : {code:'unavailable',message:WEB_BILLING_UNAVAILABLE};
}
export function createWebBillingCoordinationStore(db: FirebaseFirestore.Firestore, collection: 'billing_customers'|'billing_checkout_sessions'): WebBillingCheckoutStore {
  function ref(uid: string) {
    if (!validWebBillingUid(uid)) throw new BillingAuthenticationError('unauthenticated');
    return db.doc(collection+'/'+createHash('sha256').update(uid).digest('hex'));
  }
  return {
    async read(uid) {
      const [deletion, snapshot] = await Promise.all([accountDeletionRef(db,uid).get(),ref(uid).get()]);
      if (deletion.exists) throw new BillingConfigurationError();
      return snapshot.data() ?? {};
    },
    async mutate(uid,update) {
      return db.runTransaction(async tx=>{
        const target=ref(uid);
        const [deletion,snap]=await Promise.all([tx.get(accountDeletionRef(db,uid)),tx.get(target)]);
        if (deletion.exists) throw new BillingConfigurationError();
        const next=update(snap.data() ?? {});
        tx.set(target,next.state); return next.result;
      });
    },
  };
}

/** Import/registration is inert. Configuration is validated before constructing
 * Stripe, reading Auth/Firestore, or performing any mutation on each request. */
export function createProductionWebBillingRuntime(d: WebBillingRuntimeDependencies) {
  const now=d.now ?? (()=>new Date());
  const configured=()=>readWebBillingConfig(d.rawConfig());
  const stripe=(key:string)=>(d.stripeFactory ?? (secret=>new Stripe(secret,{
    apiVersion:'2025-02-24.acacia',maxNetworkRetries:1,timeout:20000,telemetry:false,
  })))(key);
  async function verify(req: WebBillingRequest) {
    const bearer=req.rawRequest?.headers.authorization;
    if (typeof bearer!=='string' || bearer.length>8192 || !/^Bearer [^\s]+$/.test(bearer)) throw new BillingAuthenticationError('unauthenticated');
    let decoded: admin.auth.DecodedIdToken, user: admin.auth.UserRecord;
    try {
      decoded=await d.auth.verifyIdToken(bearer.slice(7),true);
      if (!validWebBillingUid(decoded.uid) || req.auth?.uid!==decoded.uid) throw new Error();
      user=await d.auth.getUser(decoded.uid);
    } catch {throw new BillingAuthenticationError('unauthenticated');}
    return {decoded,user};
  }
  async function authorize(req: WebBillingRequest) {
    const {decoded,user}=await verify(req);
    return {identity:authorizeWebBillingIdentity(decoded,user),user};
  }
  async function source(uid:string,path:string) {
    if (!validWebBillingUid(uid)) throw new BillingAuthenticationError('unauthenticated');
    const snap=await d.db.doc(`users/${uid}/${path}`).get();
    return snap.exists ? {kind:'found' as const,data:snap.data()!} : {kind:'missing' as const};
  }
  const readBilling=(uid:string)=>source(uid,'billing/subscription');
  async function readFacts(uid:string) {
    const [owner,pet,billing,trial]=await Promise.all([
      source(uid,'owner_profiles/main'),source(uid,'pet_profiles/main_pet'),readBilling(uid),source(uid,'feature_access/initial_trial_v2'),
    ]);
    // Nickname is display data only. Firebase UID remains the sole principal.
    const name=owner.kind==='found' ? owner.data?.displayName : '';
    return {appAccountExists:owner.kind==='found' && pet.kind==='found',billing,trial,
      nickname:typeof name==='string' && name.trim() ? name.trim().slice(0,80) : '未設定'};
  }
  async function contact(identity:WebBillingIdentity,user:admin.auth.UserRecord) {
    const classification=classifyBillingEmail(identity,user);
    if (classification.kind==='A' || classification.kind==='B') return classification.email ?? null;
    if (classification.kind!=='C') return null;
    // No Preview contact fallback. A future production confirmation flow must
    // write this schema only after the same UID consumes its email challenge.
    const snap=await d.db.doc(`billing_contacts/${identity.uid}`).get(), c=snap.data();
    if (!snap.exists || !c || c.firebaseUid!==identity.uid || c.purpose!==WEB_BILLING_CONTACT_PURPOSE ||
      c.schemaVersion!==1 || c.verified!==true || c.verificationStatus!=='verified' || c.source!=='user_supplied' ||
      !Number.isSafeInteger(c.verifiedAt) || c.verifiedAt<=0 || c.verifiedAt>now().getTime()) return null;
    return normalizeBillingEmail(c.email);
  }
  function customers(client:Stripe) {
    return createWebBillingCustomerResolver({stripe:client,store:createWebBillingCoordinationStore(d.db,'billing_customers'),readBilling,now});
  }
  return {
    async checkout(req:WebBillingRequest) {
      const config=configured();
      if (req.rawRequest?.headers.origin!==config.origin || !object(req.data) || req.data.flow!=='web') throw new BillingConfigurationError();
      const {flow,action,...input}=req.data;
      if (!['review','create','status','cancel'].includes(action) ||
        (['status','cancel'].includes(action) && Object.keys(input).length)) throw new BillingConfigurationError();
      const {identity}=await authorize(req);
      if ((await accountDeletionRef(d.db,identity.uid).get()).exists) throw new BillingConfigurationError();
      const client=stripe(config.secretKey);
      const resolver=customers(client);
      const engine=createWebBillingCheckout({config,stripe:client,store:createWebBillingCoordinationStore(d.db,'billing_checkout_sessions'),
        readFacts,readContact:async target=>{
          if (target.uid!==identity.uid) return null;
          // Revalidate revocation/disabled/provider/email evidence after slow
          // Stripe recovery work, rather than reusing a stale Auth snapshot.
          const fresh=await authorize(req);
          return fresh.identity.uid===identity.uid ? contact(fresh.identity,fresh.user) : null;
        },
        resolveCustomer:input=>resolver.resolveCustomer(input),now});
      if (action==='review') return {ok:true,...await engine.review(identity,input as any)};
      if (action==='create') return {ok:true,...await engine.create(identity,input as any)};
      return {ok:true,...await (action==='status'?engine.status(identity):engine.cancel(identity))};
    },
    async portal(req:WebBillingRequest) {
      const config=configured();
      const origin=req.rawRequest?.headers.origin;
      if ((origin!==undefined && origin!==config.origin) || (req.data!=null && (!object(req.data) || Object.keys(req.data).length))) throw new BillingConfigurationError();
      const {decoded,user}=await verify(req);
      const identity=authorizeWebBillingManagementIdentity(decoded,user);
      const client=stripe(config.secretKey), resolver=customers(client);
      const engine=createWebBillingPortalEngine({stripe:client,config,readBilling,resolveCustomer:input=>resolver.resolveCustomer(input)});
      const result=await engine.create(identity);
      return {ok:true,portalUrl:result.url}; // Preserve the existing callable DTO.
    },
    async webhook(raw:Buffer,signature:unknown) {
      const config=configured(), client=stripe(config.secretKey);
      const event=verifyWebBillingEvent(client,raw,signature,config.webhookSecret,now);
      return createWebBillingWebhook({config,stripe:client,store:createWebBillingWebhookStore(d.db,()=>now().getTime()),readFacts,now}).process(event);
    },
  };
}
