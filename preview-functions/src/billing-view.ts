import {hash} from './engine';
import {subjectRef,readPreviewFacts} from './preview-runtime';
const iso=(v:unknown)=>typeof v==='number' && Number.isSafeInteger(v) && v>0?new Date(v*1000).toISOString():null;
const statuses=new Set(['incomplete','incomplete_expired','trialing','active','past_due','unpaid','paused','canceled']);
/** Authenticated HTTP projection only; no identifiers or direct Firestore reads in Web JS. */
export async function readPreviewBilling(uid:string) {
  const root=subjectRef(hash(uid));const [state,billing]=await root.firestore.getAll(root,root.collection('billing').doc('subscription'));
  const s=state.data()||{};const b=billing.data();
  if(!b)return {testMode:true,syncState:s.attempt?.phase==='complete'?'pending':'none',billing:null};
  if(s.previewFirebaseUid!==uid || b.previewFirebaseUid!==uid || b.stripeCustomerId!==s.customerId || b.testMode!==true || b.version!==1 || b.planKey!=='premium_monthly' || b.amount!==550 || b.currency!=='jpy' || b.interval!=='month' || !statuses.has(b.status))return {testMode:true,syncState:'unavailable',billing:null};
  if(s.attempt?.id!==b.previewAttempt)return {testMode:true,syncState:'pending',billing:null};
  const facts=await readPreviewFacts(uid);
  const paid=b.plan==='paid' && ['active','trialing'].includes(b.status) && (b.currentPeriodEndSeconds===null || (typeof b.currentPeriodEndSeconds==='number' && Date.now()<b.currentPeriodEndSeconds*1000));
  const portalManageable=['active','trialing','past_due','unpaid','paused','incomplete'].includes(b.status);
  return {testMode:true,syncState:'synced',billing:{planKey:b.planKey,amount:b.amount,currency:b.currency,interval:b.interval,status:b.status,currentPeriodStart:iso(b.currentPeriodStartSeconds),currentPeriodEnd:iso(b.currentPeriodEndSeconds),trialEnd:iso(b.trialEndSeconds),firstChargeAt:iso(b.firstChargeAtSeconds),nextChargeAt:iso(b.nextChargeAtSeconds),cancelAtPeriodEnd:b.cancelAtPeriodEnd===true,syncedAt:typeof b.syncedAtMillis==='number'?new Date(b.syncedAtMillis).toISOString():null,entitlementMirror:paid,portalManageable,testDataSource:facts.testDataSource||'app'}};
}
