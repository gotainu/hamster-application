import {createHash} from 'node:crypto';
import {validWebBillingUid} from './webBillingShared';

type Environment='live'|'preview';
type SenderCooldownCategory='quota_exceeded'|'sending_limit'|'rate_limited';
const namespaceFor=(environment:Environment)=>environment==='preview'?'preview_billing_notification_delivery_limits':'billing_notification_delivery_limits';
const validCategory=(value:unknown):value is SenderCooldownCategory=>typeof value==='string' && ['quota_exceeded','sending_limit','rate_limited'].includes(value);
function senderCooldown(snapshot:FirebaseFirestore.DocumentSnapshot):{untilMillis:number;category:SenderCooldownCategory}|null {
  if (!snapshot.exists) return null;
  const value=snapshot.data();
  if (!value || Object.keys(value).some(key=>!['untilMillis','category'].includes(key)) ||
    !Number.isSafeInteger(value.untilMillis) || value.untilMillis<=0 || !validCategory(value.category)) throw new Error('Mail budget unavailable.');
  return {untilMillis:value.untilMillis,category:value.category};
}

/** One account-wide, mode-specific pause prevents queued jobs from continuing
 * to call Gmail after an explicit quota/rate refusal. No account address,
 * credentials, message body or billing state is stored here. */
export async function deferBillingNotificationSender(db:FirebaseFirestore.Firestore,environment:Environment,
  input:{nowMillis:number;category:SenderCooldownCategory;delayMillis:number}):Promise<void> {
  if (!['live','preview'].includes(environment) || !input || !Number.isSafeInteger(input.nowMillis) || input.nowMillis<=0 ||
    !validCategory(input.category) || !Number.isSafeInteger(input.delayMillis) || input.delayMillis<=0 ||
    !Number.isSafeInteger(input.nowMillis+input.delayMillis)) throw new Error('Mail budget unavailable.');
  const target=db.doc(namespaceFor(environment)+'/_sender');
  await db.runTransaction(async tx=>{
    const old=senderCooldown(await tx.get(target)),untilMillis=input.nowMillis+input.delayMillis;
    if (old && old.untilMillis>=untilMillis) return;
    tx.set(target,{untilMillis,category:input.category});
  });
}

/** Preview shares the established contact-mail global reservation of 10/day.
 * Its notification per-owner cap is five, enough for the five approved smoke
 * messages. Live has no default budget: the operator must set a value <=100,
 * leaving substantial headroom below personal Gmail's published daily limit.
 * Gmail quota errors still impose a rolling 24h cooldown, not midnight reset. */
export function createBillingNotificationBudget(db:FirebaseFirestore.Firestore,environment:'live'|'preview',dailyLimit:number) {
  if (!['live','preview'].includes(environment) || !Number.isSafeInteger(dailyLimit) || dailyLimit<1 || dailyLimit>100 ||
      (environment==='preview' && dailyLimit!==10)) throw new Error('Mail budget configuration unavailable.');
  const perOwnerLimit=environment==='preview'?5:dailyLimit;
  return async(input:{uid:string;notificationId:string;attemptId:string;nowMillis:number})=>{
    if (!validWebBillingUid(input.uid) || !/^[a-f0-9]{64}$/.test(input.notificationId) ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(input.attemptId) || !Number.isSafeInteger(input.nowMillis) || input.nowMillis<=0) throw new Error('Mail budget unavailable.');
    const day=new Date(input.nowMillis).toISOString().slice(0,10),uidHash=createHash('sha256').update(input.uid).digest('hex');
    const reservation=createHash('sha256').update(input.notificationId+':'+input.attemptId).digest('hex');
    const namespace=namespaceFor(environment);
    const global=db.doc(environment==='preview'?`preview_billing_contact_delivery_limits/${day}`:`${namespace}/${day}`);
    const owner=db.doc(`${namespace}/${day}_${uidHash}`),slot=db.doc(`${namespace}/${day}_${reservation}`);
    const sender=db.doc(namespace+'/_sender');
    return db.runTransaction(async tx=>{
      const [g,u,s,c]=await Promise.all([tx.get(global),tx.get(owner),tx.get(slot),tx.get(sender)]);
      const cooldown=senderCooldown(c);
      if (cooldown && cooldown.untilMillis>input.nowMillis) return {allowed:false,nextAttemptAtMillis:cooldown.untilMillis};
      const count=(snapshot:FirebaseFirestore.DocumentSnapshot)=>{
        const value=snapshot.exists?snapshot.get('count'):0;
        if (!Number.isSafeInteger(value) || value<0) throw new Error('Mail budget unavailable.');
        return value as number;
      };
      const gc=count(g),uc=count(u);
      if (s.exists) {
        // A prior reservation is reusable only when its atomic accounting and
        // receipt are intact. Corrupt state must never reset or bypass quotas.
        const receipt=s.data(),dayStart=Date.parse(day+'T00:00:00Z');
        if (!g.exists || !u.exists || gc<1 || uc<1 || !receipt ||
          Object.keys(receipt).some(key=>!['environment','reservedAtMillis'].includes(key)) ||
          receipt.environment!==environment || !Number.isSafeInteger(receipt.reservedAtMillis) ||
          receipt.reservedAtMillis<dayStart || receipt.reservedAtMillis>=dayStart+86400000 ||
          receipt.reservedAtMillis>input.nowMillis) throw new Error('Mail budget unavailable.');
        return {allowed:true};
      }
      if (gc>=dailyLimit || uc>=perOwnerLimit) return {allowed:false,nextAttemptAtMillis:Date.parse(day+'T00:00:00Z')+86400000};
      tx.set(global,{...(g.data()??{}),count:gc+1,updatedAt:input.nowMillis});
      tx.set(owner,{count:uc+1,updatedAt:input.nowMillis});
      tx.create(slot,{environment,reservedAtMillis:input.nowMillis});
      return {allowed:true};
    });
  };
}
