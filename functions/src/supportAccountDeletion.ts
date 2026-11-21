import {createHash, randomBytes, timingSafeEqual} from 'node:crypto';
import {accountDeletionRef} from './accountDeletion';
import {validWebBillingUid} from './webBillingShared';

export const SUPPORT_DELETION_COLLECTION = 'support_account_deletion_requests';
export const SUPPORT_DELETION_PROOF_TTL_MS = 24 * 60 * 60_000;
export const SUPPORT_DELETION_REVIEW_TTL_MS = 5 * 60_000;
export const SUPPORT_DELETION_SCOPE = Object.freeze(['Firebase Auth', 'users subtree', 'switchbot_users subtree',
  'billing contact', 'fixed pet image', 'Stripe recurring billing stop before cleanup']);
const hash = (value:string) => createHash('sha256').update(value).digest('hex');
const validRequest = (value:unknown):value is string => typeof value === 'string' && /^[a-f0-9]{48}$/.test(value);
const validProof = (value:unknown):value is string => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
export class SupportDeletionError extends Error {
  constructor(public reason:'invalid_request'|'unauthenticated'|'wrong_account'|'expired'|'reused'|'unverified'|
    'stale_review'|'apple_action_required'|'processing'|'completion_unconfirmed') {super(reason);}
}
export type SupportDeletionUser = {uid:string;disabled:boolean;metadata:{creationTime:string};
  providerData:Array<{providerId:string;uid?:string}>};
/** Created only after Admin verifyIdToken(token,true) and current Admin user / provider validation. */
export type SupportDeletionIdentity = {uid:string;authTime:number;appleLinked:boolean};
export type SupportDeletionDependencies = {
  db:FirebaseFirestore.Firestore;
  getUser:(uid:string)=>Promise<SupportDeletionUser|null>;
  runDeletion:(uid:string)=>Promise<{ok:true}|{ok:false;reason:'processing'|'manual_review'}>;
  now?:()=>number;
};
type Request = {version:1;targetUid:string;authCreatedAt:number;intakeRef:string;createdAt:number;expiresAt:number;
  proofHash:string;status:'pending'|'verified'|'completed';verifiedAt?:number;consent?:true;paidConsent?:true;
  appleAction?:'revoked_client_reported'|'manual_acknowledged'|'not_linked';completedAt?:number;lastResult?:string};
function reject(reason:ConstructorParameters<typeof SupportDeletionError>[0]):never {throw new SupportDeletionError(reason);}
function ref(d:SupportDeletionDependencies,id:string) {
  if (!validRequest(id)) reject('invalid_request');
  return d.db.doc(SUPPORT_DELETION_COLLECTION+'/'+id);
}
function record(value:unknown):Request {
  const v=value as Request|undefined;
  if (!v || v.version!==1 || !validWebBillingUid(v.targetUid) || !Number.isFinite(v.authCreatedAt) ||
      !Number.isFinite(v.createdAt) || !Number.isFinite(v.expiresAt) || !validProof(v.proofHash) ||
      !['pending','verified','completed'].includes(v.status)) reject('invalid_request');
  return v;
}
function existing(user:SupportDeletionUser|null,uid:string,createdAt:number) {
  const creation = user ? Date.parse(user.metadata.creationTime) : NaN;
  if (!user || user.uid!==uid || user.disabled!==false || !Number.isFinite(creation) || creation>=createdAt) reject('wrong_account');
  return creation;
}
/** Private operator intake only. Mail fields / screenshots are not identity proof.
 * This does not delete anything and cannot be invoked by the public confirmation route. */
export async function createSupportDeletion(d:SupportDeletionDependencies,input:{targetUid:string;intakeRef:string}) {
  if (!validWebBillingUid(input.targetUid) || typeof input.intakeRef!=='string' ||
      !/^[A-Za-z0-9_-]{1,80}$/.test(input.intakeRef)) reject('invalid_request');
  const now=(d.now??Date.now)();
  const authCreatedAt=existing(await d.getUser(input.targetUid),input.targetUid,now);
  const requestId=randomBytes(24).toString('hex'),proof=randomBytes(32).toString('hex');
  const request:Request={version:1,targetUid:input.targetUid,authCreatedAt,intakeRef:input.intakeRef,
    createdAt:now,expiresAt:now+SUPPORT_DELETION_PROOF_TTL_MS,proofHash:hash(requestId+':'+proof),status:'pending'};
  await d.db.runTransaction(async tx=>{const r=ref(d,requestId);if((await tx.get(r)).exists)reject('invalid_request');tx.create(r,request);});
  // The caller hands this link to the requester; proof is never stored in plaintext or logged.
  return {requestId,proof,expiresAt:request.expiresAt};
}
function validateProof(value:Request, input:{requestId:string;proof:string}, identity:SupportDeletionIdentity,
  user:SupportDeletionUser|null, now:number) {
  if (!identity || !validWebBillingUid(identity.uid) || !Number.isFinite(identity.authTime)) reject('unauthenticated');
  if (value.targetUid!==identity.uid) reject('wrong_account');
  if (value.status!=='pending') reject('reused');
  if (value.expiresAt<=now) reject('expired');
  if (identity.authTime < Math.floor(value.createdAt/1000) || identity.authTime*1000>now+30_000 ||
      now-identity.authTime*1000>5*60_000) reject('unauthenticated');
  if (existing(user,identity.uid,value.createdAt)!==value.authCreatedAt) reject('wrong_account');
  if (!validProof(input.proof)) reject('invalid_request');
  const actual=hash(input.requestId+':'+input.proof);
  if (!timingSafeEqual(Buffer.from(actual,'hex'),Buffer.from(value.proofHash,'hex'))) reject('invalid_request');
  const appleLinked=user!.providerData.some(p=>p.providerId==='apple.com');
  if (identity.appleLinked!==appleLinked) reject('unauthenticated');
  return appleLinked;
}
/** Read-only preflight before a browser attempts Apple revocation. A different
 * authenticated account must be refused before any provider authorization changes. */
export async function inspectSupportDeletion(d:SupportDeletionDependencies,input:{requestId:string;proof:string},
  identity:SupportDeletionIdentity) {
  if (!identity || !validWebBillingUid(identity.uid)) reject('unauthenticated');
  const value=record((await ref(d,input.requestId).get()).data());
  const appleLinked=validateProof(value,input,identity,await d.getUser(identity.uid),(d.now??Date.now)());
  return {ok:true as const,appleLinked};
}
export async function confirmSupportDeletion(d:SupportDeletionDependencies,input:{requestId:string;proof:string;
  confirmText:string;stopBillingConfirmed:boolean;appleRevocation:string},identity:SupportDeletionIdentity) {
  if (!identity || !validWebBillingUid(identity.uid) || !Number.isFinite(identity.authTime)) reject('unauthenticated');
  if (!validProof(input.proof) || input.confirmText!=='DELETE_MY_ACCOUNT' || input.stopBillingConfirmed!==true) reject('invalid_request');
  const r=ref(d,input.requestId),now=(d.now??Date.now)();
  const user=await d.getUser(identity.uid);
  await d.db.runTransaction(async tx=>{
    const value=record((await tx.get(r)).data());
    const appleLinked=validateProof(value,input,identity,user,now);
    if (appleLinked && !['revoked_client_reported','manual_acknowledged'].includes(input.appleRevocation)) reject('apple_action_required');
    if (!appleLinked && input.appleRevocation!=='not_linked') reject('invalid_request');
    tx.set(r,{...value,status:'verified',verifiedAt:now,consent:true,paidConsent:true,
      appleAction:appleLinked?input.appleRevocation:'not_linked'});
  });
  return {status:'verified' as const};
}
function canonical(value:unknown):string {
  if (value===undefined) return 'null';
  if (Array.isArray(value)) return '['+value.map(canonical).join(',')+']';
  if (value && typeof value==='object') return '{'+Object.entries(value).sort(([a],[b])=>a.localeCompare(b))
    .map(([k,v])=>JSON.stringify(k)+':'+canonical(v)).join(',')+'}';
  return JSON.stringify(value);
}
function verified(value:Request) {
  if (!['verified','completed'].includes(value.status) || value.consent!==true || value.paidConsent!==true ||
      !Number.isFinite(value.verifiedAt)) reject('unverified');
}
async function reviewState(d:SupportDeletionDependencies,requestId:string) {
  const value=record((await ref(d,requestId).get()).data());verified(value);
  const uid=value.targetUid,key=hash(uid);
  const [billing,customer,checkout,deletion]=await d.db.getAll(d.db.doc('users/'+uid+'/billing/subscription'),
    d.db.doc('billing_customers/'+key),d.db.doc('billing_checkout_sessions/'+key),accountDeletionRef(d.db,uid));
  const user=await d.getUser(uid);
  const fence=deletion.data()??{};
  // The immutable Auth creation time rejects a deleted/re-created UID. Auth can be
  // absent only after the existing deletion state machine has confirmed billing stop.
  if (user) {
    if (existing(user,uid,value.createdAt)!==value.authCreatedAt) reject('wrong_account');
  } else if (fence.billingStopped!==true && fence.status!=='completed') reject('completion_unconfirmed');
  if (!deletion.exists && (d.now??Date.now)()-value.verifiedAt!>SUPPORT_DELETION_PROOF_TTL_MS) reject('expired');
  const state={request:value,billing:billing.data()??{},customer:customer.data()??{},checkout:checkout.data()??{},fence,
    authExists:!!user,scope:SUPPORT_DELETION_SCOPE};
  return {value,state,billing:billing.data()??{},fence,authExists:!!user};
}
function reviewHash(requestId:string,reviewedAt:number,state:unknown) {
  return hash(requestId+':'+reviewedAt+':'+canonical(state));
}
/** Private, read-only dry-run. Does not call Stripe or modify deletion fences. */
export async function reviewSupportDeletion(d:SupportDeletionDependencies,requestId:string) {
  const {value,state,billing,fence,authExists}=await reviewState(d,requestId);
  const now=(d.now??Date.now)();
  const validStates=['active','trialing','past_due','unpaid','canceled','incomplete','incomplete_expired','paused'];
  return {requestId,uidHash:hash(value.targetUid),intakeRef:value.intakeRef,scope:SUPPORT_DELETION_SCOPE,
    contract:{status:validStates.includes(billing.status)?billing.status:'none_or_unknown',
      hasCustomer:typeof billing.stripeCustomerId==='string',hasSubscription:typeof billing.stripeSubscriptionId==='string',
      cancelAtPeriodEnd:billing.cancelAtPeriodEnd===true},
    deletionState:typeof fence.status==='string'?fence.status:'not_started',billingStopped:fence.billingStopped===true||fence.status==='completed',
    authExists,completionConfirmed:fence.status==='completed'&&!authExists,
    appleAction:value.appleAction,reviewDigest:'v1.'+now+'.'+reviewHash(requestId,now,state),reviewExpiresAt:now+SUPPORT_DELETION_REVIEW_TTL_MS};
}
/** The only execution target is the immutable verified request's UID. No UID input.
 * Runtime must additionally enforce private IAM / operator allowlist and an enable switch. */
export async function executeSupportDeletion(d:SupportDeletionDependencies,input:{requestId:string;reviewDigest:string}) {
  const match=typeof input.reviewDigest==='string' && /^v1\.(\d{13})\.([a-f0-9]{64})$/.exec(input.reviewDigest);
  if (!match) reject('stale_review');
  const reviewedAt=Number(match[1]),now=(d.now??Date.now)();
  if (reviewedAt>now || now-reviewedAt>SUPPORT_DELETION_REVIEW_TTL_MS) reject('stale_review');
  const {value,state}=await reviewState(d,input.requestId);
  if (reviewHash(input.requestId,reviewedAt,state)!==match[2]) reject('stale_review');
  const result=await d.runDeletion(value.targetUid);
  const after=await reviewState(d,input.requestId);
  const completed=result.ok && after.fence.status==='completed' && !after.authExists;
  if (result.ok && !completed) reject('completion_unconfirmed');
  // The billing state machine owns the lease/retry and cleanup. This ticket is
  // only an immutable identity/intent audit and a resumable reference to that work.
  await d.db.runTransaction(async tx=>{
    const r=ref(d,input.requestId),current=record((await tx.get(r)).data());verified(current);
    if (current.targetUid!==value.targetUid || current.verifiedAt!==value.verifiedAt) reject('wrong_account');
    tx.set(r,{...current,...(completed?{status:'completed',completedAt:now}:{}),lastResult:completed?'completed':result.ok?'processing':result.reason});
  });
  return completed?{status:'completed' as const,completionConfirmed:true}:{status:result.ok?'processing':result.reason,completionConfirmed:false};
}
