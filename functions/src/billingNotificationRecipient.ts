import {normalizeBillingEmail, validWebBillingUid, readVerifiedBillingContact} from './webBillingShared';
import type {BillingNotificationEnvironment} from './billingNotificationTemplates';

export type BillingNotificationRecipientSource = 'auth_verified' | 'apple_relay' | 'user_supplied';
export type BillingNotificationRecipient = {kind:'resolved';email:string;source:BillingNotificationRecipientSource} |
  {kind:'blocked_no_verified_contact'};
type Data = Record<string, unknown>;
const object = (v: unknown): v is Data => !!v && typeof v==='object' && !Array.isArray(v);
const blocked = (): BillingNotificationRecipient => ({kind:'blocked_no_verified_contact'});
const isRelay = (email:string) => ['privaterelay.appleid.com','private.icloud.com'].includes(email.slice(email.lastIndexOf('@')+1).toLowerCase());
const providerUid = (v:unknown) => typeof v==='string' && v.length>0 && v.length<=1024 && !/[\s\u0000-\u001f\u007f]/u.test(v);

/** Call only with Admin getUser(uid) and a same-UID, mode-specific contact
 * document. This helper never queries Auth by email, writes contacts, or treats
 * a Relay-looking address as proof of an Apple identity. */
export function resolveBillingNotificationRecipient(input: {
  uid: string;
  authUser: unknown;
  supplementalContact?: {uid:string;state:unknown} | null;
  mode: BillingNotificationEnvironment;
  nowMillis: number;
}): BillingNotificationRecipient {
  if (!input || !validWebBillingUid(input.uid) || !['live','preview'].includes(input.mode) ||
    !Number.isSafeInteger(input.nowMillis) || input.nowMillis<=0 || !object(input.authUser) ||
    input.authUser.uid!==input.uid || input.authUser.disabled!==false || typeof input.authUser.emailVerified!=='boolean') return blocked();
  const user=input.authUser, authEmail=normalizeBillingEmail(user.email);
  if (authEmail && user.emailVerified===true) {
    if (!isRelay(authEmail)) return {kind:'resolved',email:authEmail,source:'auth_verified'};
    const providers=user.providerData;
    if (Array.isArray(providers) && providers.every(p=>object(p) && typeof p.providerId==='string')) {
      const apple=providers.filter(p=>object(p) && p.providerId==='apple.com') as Data[];
      if (apple.length===1 && providerUid(apple[0].uid) &&
        (apple[0].email===undefined || apple[0].email===null || apple[0].email==='' || normalizeBillingEmail(apple[0].email)===authEmail)) {
        return {kind:'resolved',email:authEmail,source:'apple_relay'};
      }
    }
  }
  const reference=input.supplementalContact;
  if (!reference || reference.uid!==input.uid || !object(reference.state)) return blocked();
  const email=readVerifiedBillingContact(reference.state,input.uid,input.mode,input.nowMillis);
  return email ? {kind:'resolved',email,source:'user_supplied'} : blocked();
}
