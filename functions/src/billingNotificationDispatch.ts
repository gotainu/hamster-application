/** Live mail always needs an explicit scope. The owner check has its own
 * finite window and exact outbox selection; it never consumes the later
 * general launch cutoff or turns into general dispatch after expiry. */
export interface LimitedBillingNotificationSelection {
  scope:'limited';
  notBeforeMillis:number;
  expiresAtMillis:number;
  subjectHash:string;
  recipientHash:string;
  notificationId:string;
}
export type LiveBillingNotificationDispatchPolicy = LimitedBillingNotificationSelection |
  {scope:'general';notBeforeMillis:number};
const hash=(value:unknown):value is string=>typeof value==='string' && /^[a-f0-9]{64}$/.test(value);
const millis=(value:unknown):value is number=>Number.isSafeInteger(value) && Number(value)>0 && Number(value)%1000===0;
const object=(v:unknown):v is Record<string,unknown>=>!!v && typeof v==='object' && !Array.isArray(v);
export function validLimitedBillingNotificationSelection(v:unknown):v is LimitedBillingNotificationSelection {
  return object(v) && Object.keys(v).sort().join(',')===
    'expiresAtMillis,notBeforeMillis,notificationId,recipientHash,scope,subjectHash' &&
    v.scope==='limited' && millis(v.notBeforeMillis) && millis(v.expiresAtMillis) &&
    v.expiresAtMillis>v.notBeforeMillis && v.expiresAtMillis-v.notBeforeMillis<=6*60*60*1000 &&
    hash(v.subjectHash) && hash(v.recipientHash) && hash(v.notificationId);
}
export function limitedBillingNotificationWindowOpen(v:LimitedBillingNotificationSelection, now:number):boolean {
  return validLimitedBillingNotificationSelection(v) && Number.isSafeInteger(now) && now>=v.notBeforeMillis && now<v.expiresAtMillis;
}
function parseMillis(value:unknown):number {
  if(typeof value!=='string' || !/^[1-9]\d{0,15}$/.test(value) || !millis(Number(value))) throw new Error('Billing notification dispatch configuration unavailable.');
  return Number(value);
}
/** Getters are intentional: disabled/closed does not read either scope's
 * configuration, and limited never reads the general launch cutoff. */
export async function dispatchLiveBillingNotifications<T>(input:{
  enabled:unknown;
  scope?:unknown;
  notBeforeMillis():unknown;
  limited():unknown;
  nowMillis:number;
  run(policy:LiveBillingNotificationDispatchPolicy):Promise<T>;
}):Promise<{state:'disabled'}|{state:'processed';summary:T}> {
  if(input.enabled===undefined || input.enabled==='' || input.enabled==='false')return {state:'disabled'};
  if(input.enabled!=='true')throw new Error('Billing notification dispatch configuration unavailable.');
  const scope=input.scope===undefined || input.scope===''?'closed':input.scope;
  if(scope==='closed')return {state:'disabled'};
  if(scope!=='limited' && scope!=='general')throw new Error('Billing notification dispatch configuration unavailable.');
  if(!Number.isSafeInteger(input.nowMillis) || input.nowMillis<=0)throw new Error('Billing notification dispatch configuration unavailable.');
  if(scope==='limited') {
    const raw=input.limited();
    if(!object(raw) || Object.keys(raw).sort().join(',')!=='expiresAtMillis,notBeforeMillis,notificationId,recipientHash,subjectHash')throw new Error('Billing notification dispatch configuration unavailable.');
    const policy={scope:'limited' as const,notBeforeMillis:parseMillis(raw.notBeforeMillis),expiresAtMillis:parseMillis(raw.expiresAtMillis),
      subjectHash:raw.subjectHash,recipientHash:raw.recipientHash,notificationId:raw.notificationId};
    if(!validLimitedBillingNotificationSelection(policy) || !limitedBillingNotificationWindowOpen(policy,input.nowMillis))throw new Error('Billing notification dispatch configuration unavailable.');
    return {state:'processed',summary:await input.run(Object.freeze(policy))};
  }
  const limited=input.limited();
  if(!object(limited) || Object.values(limited).some(v=>v!==undefined && v!==''))throw new Error('Billing notification dispatch configuration unavailable.');
  const start=parseMillis(input.notBeforeMillis());
  if(start>input.nowMillis)throw new Error('Billing notification dispatch configuration unavailable.');
  return {state:'processed',summary:await input.run(Object.freeze({scope:'general',notBeforeMillis:start}))};
}
