import {projectAccountIdentity, isVerifiedAccountIdentity} from './account-identity.mjs';

export const LIVE_CHECKOUT_ENDPOINT = 'https://asia-northeast1-hamster-breeding-app.cloudfunctions.net/createStripeCheckoutSession';
export const LIVE_PORTAL_ENDPOINT = 'https://asia-northeast1-hamster-breeding-app.cloudfunctions.net/createStripeCustomerPortalSession';
export const LIVE_ORIGIN = 'https://hamster-breeding-app.web.app';
// Opening intake requires a separate approved change, as well as server/IAM gates.
export const LIVE_PURCHASE_ENABLED = false;
const verifiers = new WeakSet();
export function confirmsLiveResponse(raw, verify) {
  return typeof verify === 'function' && verifiers.has(verify) && verify(raw) === true;
}

/** Exact production callable protocol. Never accepts caller-selected endpoints,
 * UIDs, Customers, prices, return destinations or Preview credentials. */
export function createLiveCheckoutService({auth, readOwnProfiles, readOwnBilling,
  origin = globalThis.location?.origin, fetchRequest = globalThis.fetch}) {
  if (origin !== LIVE_ORIGIN || typeof readOwnBilling !== 'function') throw {code:'live/server_config'};
  let generation = 0;
  let proofs = new WeakMap();
  let reviewTerms = new WeakMap();
  const pending = new Set();
  async function withIdentity(action) {
    const user = auth.currentUser, started = generation, uid = user?.uid;
    if (typeof uid !== 'string' || !uid || typeof user.getIdTokenResult !== 'function') throw {code:'unauthenticated'};
    const current = () => generation === started && auth.currentUser === user && auth.currentUser?.uid === uid;
    const requireCurrent = () => {if (!current()) throw {code:'session_changed'};};
    let token;
    const identity = async () => {
      const result = await user.getIdTokenResult(true); requireCurrent();
      const value = projectAccountIdentity(user,result,auth.app?.options?.projectId);
      if (!isVerifiedAccountIdentity(value) || typeof result.token !== 'string' || !result.token || result.token.length > 8192 || /[\s\u0000-\u001f\u007f]/u.test(result.token)) throw {code:'unauthenticated'};
      token = result.token; return value;
    };
    const verified = await identity();
    try {
      const result = await action({uid,user,token,verified,identity,requireCurrent});
      requireCurrent(); return result;
    } catch (cause) {
      requireCurrent();
      if (cause?.name === 'AbortError') throw {code:'session_changed'};
      if (cause instanceof TypeError) throw {code:'network_error'};
      if (typeof cause?.code === 'string' && cause.code.startsWith('auth/')) throw {code:'unauthenticated'};
      throw {code:typeof cause?.code === 'string' ? cause.code : 'live/unavailable'};
    }
  }
  async function request(action, extra = {}, portal = false) {
    if (!portal && ['review','create'].includes(action) && !LIVE_PURCHASE_ENABLED) throw {code:'live/purchase_closed'};
    return withIdentity(async context => {
      const controller = new AbortController(); pending.add(controller);
      try {
        // No automatic retries of mutations or uncertain responses.
        const response = await fetchRequest(portal ? LIVE_PORTAL_ENDPOINT : LIVE_CHECKOUT_ENDPOINT, {
          method:'POST',mode:'cors',credentials:'omit',cache:'no-store',referrerPolicy:'no-referrer',signal:controller.signal,
          headers:{'Content-Type':'application/json','Authorization':'Bearer '+context.token},
          body:JSON.stringify({data:portal ? {} : {flow:'web',action,...extra}}),
        });
        context.requireCurrent();
        let envelope;
        try {envelope = await response.json();} catch {throw {code:'live/unavailable'};}
        context.requireCurrent();
        if (!response.ok || envelope?.error) {
          if (envelope?.error?.status === 'UNAUTHENTICATED') throw {code:'unauthenticated'};
          if (!portal && !LIVE_PURCHASE_ENABLED) throw {code:'live/purchase_closed'};
          throw {code:'live/unavailable'};
        }
        const value = envelope?.result;
        if (!value || typeof value !== 'object' || Array.isArray(value) || value.ok !== true || 'testMode' in value) throw {code:'live/invalid_response'};
        if (action === 'review' && value.maskedEmail === '未設定') {
          if (context.verified.authenticationBasis !== 'apple_provider' || typeof readOwnProfiles !== 'function') throw {code:'live/invalid_response'};
          const profiles = await readOwnProfiles(context.uid); context.requireCurrent();
          if (profiles?.ownerExists !== true || profiles?.petExists !== true) throw {code:'app_account_required'};
        }
        proofs.set(value,{user:context.user,uid:context.uid,generation});
        if (action === 'review') reviewTerms.set(value,{token:value.reviewToken,version:value.termsVersion});
        return value;
      } finally {pending.delete(controller);}
    });
  }
  let lastReview = null;
  const service = {
    testMode:false,purchaseEnabled:LIVE_PURCHASE_ENABLED,
    async reviewPreviewCheckout() {lastReview=await request('review',{planKey:'premium_monthly'});return lastReview;},
    createPreviewCheckout({reviewToken,termsAccepted}) {
      const proof=lastReview && reviewTerms.get(lastReview);
      if (!proof || proof.token !== reviewToken || termsAccepted !== true || !service.isVerifiedResponse(lastReview)) throw {code:'live/review_mismatch'};
      return request('create',{planKey:'premium_monthly',reviewToken,termsAccepted:true,termsVersion:proof.version});
    },
    getPreviewCheckoutStatus:()=>request('status'),
    cancelPreviewCheckout:()=>request('cancel'),
    createPreviewPortalSession:()=>request(null,{},true),
    getPreviewBilling:()=>withIdentity(async context=>{
      const item = await readOwnBilling(context.uid); context.requireCurrent();
      if (item?.kind === 'missing') return {live:true,syncState:'none'};
      if (item?.kind !== 'found' || !item.data || typeof item.data !== 'object') throw {code:'live/invalid_response'};
      const b=item.data;
      if (b.testMode !== undefined || b.previewFirebaseUid !== undefined || b.stripeLivemode === false || (b.firebaseUid !== undefined && b.firebaseUid !== context.uid)) throw {code:'live/invalid_response'};
      const bound = b.stripeLivemode === true && b.firebaseUid === context.uid && b.provider === 'stripe' && b.billingSyncVersion === 1;
      // Strip all account/resource identifiers before handing data to presentation.
      const fields=['plan','status','amount','currency','interval','cancelAtPeriodEnd','currentPeriodStart','currentPeriodEnd','trialEnd','firstChargeAt','nextChargeAt','syncedAtMillis','updatedAt','latestInvoiceTotal','latestInvoiceAmountPaid'];
      return {live:true,syncState:'synced',billing:Object.fromEntries(fields.map(key=>[key,b[key]])),verifiedBinding:bound,
        portalManageable:typeof b.stripeCustomerId === 'string' && /^cus_[A-Za-z0-9_]+$/.test(b.stripeCustomerId) &&
          typeof b.stripeSubscriptionId === 'string' && /^sub_[A-Za-z0-9_]+$/.test(b.stripeSubscriptionId)};
    }),
    isVerifiedResponse(raw) {const p=proofs.get(raw);return !!p && p.generation===generation && p.user===auth.currentUser && p.uid===auth.currentUser?.uid;},
    clear(){generation++;lastReview=null;proofs=new WeakMap();reviewTerms=new WeakMap();for(const c of pending)c.abort();pending.clear();},
  };
  verifiers.add(service.isVerifiedResponse);
  return Object.freeze(service);
}
