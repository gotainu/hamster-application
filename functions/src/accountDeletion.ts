import {createHash, randomUUID} from 'node:crypto';
import {validWebBillingUid} from './webBillingShared';
import {DeletionStop, DeletionStripe, stopAccountBilling} from './accountDeletionBilling';

export const ACCOUNT_DELETION_COLLECTION = 'account_deletion_requests';
const LEASE_MS = 11 * 60_000; // Longer than the 540-second function execution limit.
const MAX_ATTEMPTS = 12;
const digest = (uid: string) => createHash('sha256').update(uid).digest('hex');
function canonical(value:unknown):string {
  if (value===undefined) return 'null';
  if (Array.isArray(value)) return '['+value.map(canonical).join(',')+']';
  if (value && typeof value==='object') return '{'+Object.entries(value).sort(([a],[b])=>a.localeCompare(b))
    .map(([k,v])=>JSON.stringify(k)+':'+canonical(v)).join(',')+'}';
  return JSON.stringify(value);
}
/** A private operator's fresh review binds the whole existing fence, not a UID
 * supplied by a caller. No mutation or external request is made by this helper. */
export const accountDeletionFenceDigest=(value:unknown)=>digest(canonical(value));
export function canResumeAccountDeletion(value:unknown,uid:string):boolean {
  const v=value as Record<string,any>|undefined;
  return !!v && validWebBillingUid(uid) && v.uid===uid && v.version===1 && v.status==='manual_review' &&
    v.lease===null && v.dueAt===null && Number.isSafeInteger(v.attempt) && v.attempt>=1 && v.attempt<=MAX_ATTEMPTS &&
    Number.isSafeInteger(v.updatedAt) && v.updatedAt>0 && typeof v.billingStopped==='boolean' &&
    Number.isSafeInteger(v.requestedAt) && v.requestedAt>0 && v.requestedAt<=v.updatedAt &&
    ['billing_unresolved','invoice_review','manual_review','retryable','checkout_pending'].includes(v.reason) &&
    typeof v.paidConfirmed==='boolean' && (v.operatorResumeCount===undefined || v.operatorResumeCount===0);
}
export function accountDeletionRef(db: FirebaseFirestore.Firestore, uid: string) {
  if (!validWebBillingUid(uid)) throw new DeletionStop('billing_unresolved');
  return db.doc(ACCOUNT_DELETION_COLLECTION + '/' + digest(uid));
}

type Dependencies = {
  db: FirebaseFirestore.Firestore;
  stripe: () => DeletionStripe;
  deleteData: (uid: string) => Promise<void>;
  now?: () => number;
  livemode?: boolean;
};
type Outcome = {ok: true} | {ok:false; reason:'processing' | 'manual_review'};
/** A callable starts the durable request. A worker may only resume an already-confirmed
 * request. A completed request is reduced to a permanent billing fence keyed by a UID hash. */
export async function runAccountDeletion(d: Dependencies, uid: string,
  input: {kind:'request'; stopBillingConfirmed:boolean} | {kind:'retry'} |
    {kind:'operator_resume';stopBillingConfirmed:true;requestId:string;fenceDigest:string}): Promise<Outcome> {
  const ref = accountDeletionRef(d.db, uid);
  const token = randomUUID();
  const clock = d.now ?? Date.now;
  const claim = await d.db.runTransaction(async tx => {
    const snap = await tx.get(ref);
    const old = snap.data();
    if (old?.status === 'completed') {
      if (input.kind==='operator_resume') throw new DeletionStop('manual_review');
      return {action:'done'} as const;
    }
    if (!old && input.kind === 'retry') return {action:'missing'} as const;
    if (old && (old.uid !== uid || old.version !== 1)) throw new DeletionStop('manual_review');
    const now = clock();
    const operatorResume=input.kind==='operator_resume';
    if (operatorResume && (!/^[a-f0-9]{48}$/.test(input.requestId) || !/^[a-f0-9]{64}$/.test(input.fenceDigest) ||
        input.stopBillingConfirmed!==true || !canResumeAccountDeletion(old,uid) ||
        accountDeletionFenceDigest(old)!==input.fenceDigest)) throw new DeletionStop('manual_review');
    if (old?.status === 'manual_review' && !operatorResume) return {action:'manual'} as const;
    if (old && old.dueAt > now) return {action:'busy'} as const;
    // An interrupted explicitly resumed attempt must not acquire a fresh retry
    // budget through a worker or the ordinary application delete button.
    if (!operatorResume && old?.operatorResumeCount===1) {
      tx.set(ref,{...old,status:'manual_review',dueAt:null,lease:null,updatedAt:now,
        reason:'manual_review',operatorResumeInterrupted:true});
      return {action:'manual'} as const;
    }
    const attempt = (old?.attempt ?? 0) + 1;
    if (attempt > MAX_ATTEMPTS && !operatorResume) {
      tx.set(ref,{...old, status:'manual_review', dueAt:null, lease:null, updatedAt:now});
      return {action:'manual'} as const;
    }
    const paid = old?.paidConfirmed === true ||
      ((input.kind === 'request' || input.kind==='operator_resume') && input.stopBillingConfirmed);
    const cleared = old?.billingStopped === true;
    tx.set(ref,{...(operatorResume?old:{}),version:1,uid,status:'running',lease:token,attempt,paidConfirmed:paid,
      ...(operatorResume?{operatorResumeCount:1,operatorResumeAt:now,operatorResumeRequestHash:digest(input.requestId),
        operatorResumePreviousReason:typeof old?.reason==='string'?old.reason:'manual_review'}:{}),
      billingStopped:cleared,requestedAt:old?.requestedAt ?? now,updatedAt:now,dueAt:now+LEASE_MS});
    return {action:'run',paid,cleared,attempt} as const;
  });
  if (claim.action === 'done') return {ok:true};
  if (claim.action === 'missing' || claim.action === 'manual') return {ok:false,reason:'manual_review'};
  if (claim.action === 'busy') return {ok:false,reason:'processing'};

  const owned = (next: (tx:FirebaseFirestore.Transaction) => void) => d.db.runTransaction(async tx => {
    const current = await tx.get(ref);
    if (current.get('lease') !== token || current.get('dueAt') <= clock()) throw new DeletionStop('in_progress');
    next(tx);
  });
  try {
    if (!claim.cleared) {
      const hash = digest(uid);
      const [billing,customer,checkout] = await d.db.getAll(d.db.doc('users/'+uid+'/billing/subscription'),
        d.db.doc('billing_customers/'+hash),d.db.doc('billing_checkout_sessions/'+hash));
      await stopAccountBilling(uid, {billing:billing.data() ?? {},customer:customer.data() ?? {},
        checkout:checkout.data() ?? {}},claim.paid,d.stripe,clock(),d.livemode ?? true);
      // Persist this proof before the recursive cleanup removes the billing references.
      await owned(tx => tx.update(ref,{billingStopped:true,updatedAt:clock()}));
    }
    // Reuse existing cleanup, including idempotent Auth deletion. A retry after Auth
    // removal is possible even if the user cannot log in again.
    await d.deleteData(uid);
    await owned(tx => tx.set(ref,{version:1,status:'completed',completedAt:clock()}));
    return {ok:true};
  } catch (err) {
    const reason = err instanceof DeletionStop ? err.reason : 'retryable';
    if (reason === 'in_progress') return {ok:false,reason:'processing'};
    if (reason === 'paid_confirmation_required') {
      // No mutation occurred without consent. The next request must explicitly
      // confirm immediate cancellation. Do not leave the account locked meanwhile.
      await owned(tx => tx.delete(ref));
      throw err;
    }
    const manual = input.kind==='operator_resume' ||
      ['billing_unresolved','invoice_review','manual_review'].includes(reason) || claim.attempt >= MAX_ATTEMPTS;
    const delay = Math.min(60 * 60_000, 60_000 * 2 ** (claim.attempt-1));
    await owned(tx => tx.update(ref,{lease:null,status:manual?'manual_review':'retryable',
      dueAt:manual?null:clock()+delay,updatedAt:clock(),reason}));
    return {ok:false,reason:manual?'manual_review':'processing'};
  }
}

/** Single due-time query covers both failed requests and a worker that stopped
 * before releasing its lease. A missing completed request cannot be recreated. */
export async function retryDueAccountDeletions(d: Dependencies) {
  const due = await d.db.collection(ACCOUNT_DELETION_COLLECTION)
    .where('dueAt','>',0).where('dueAt','<=',(d.now ?? Date.now)()).orderBy('dueAt').limit(4).get();
  let manual = 0;
  await Promise.all(due.docs.map(async doc => {
    const uid = doc.get('uid');
    if (typeof uid !== 'string' || doc.id !== digest(uid)) {manual++;return;}
    const result = await runAccountDeletion(d,uid,{kind:'retry'});
    if (!result.ok && result.reason === 'manual_review') manual++;
  }));
  return {checked:due.size,manual};
}
