import { projectAccountIdentity, isVerifiedAccountIdentity } from './account-identity.mjs';
// Firebase UID remains inside Auth. This service sends only a plan key and a
// short-lived review proof; Portal creation sends an empty body. Identifiers,
// prices, trial dates and arbitrary return destinations are never inputs.
export const PREVIEW_CHECKOUT_ENDPOINT = 'https://us-central1-hamster-breeding-app.cloudfunctions.net/createPreviewStripeCheckoutSession';
export const PREVIEW_PORTAL_ENDPOINT = 'https://us-central1-hamster-breeding-app.cloudfunctions.net/createPreviewStripeCustomerPortalSession';
export function createPreviewCheckoutService({auth, fetchRequest = globalThis.fetch, endpoint = PREVIEW_CHECKOUT_ENDPOINT}) {
  if (endpoint !== PREVIEW_CHECKOUT_ENDPOINT) throw new Error('test_configuration_invalid');
  const pending = new Set();
  let generation = 0;
  async function request(operation, extra = {}, portal = false) {
    const started = generation;
    const user = auth.currentUser;
    if (!user || typeof user.uid !== 'string' || !user.uid || typeof user.getIdTokenResult !== 'function') throw {code:'unauthenticated'};
    const uid = user.uid;
    const projectId = auth.app?.options?.projectId;
    let tokenResult;
    const stillCurrent = () => started === generation && auth.currentUser === user && auth.currentUser?.uid === uid;
    const requireCurrent = () => { if (!stillCurrent()) throw {code:'session_changed'}; };
    const requireIdentity = () => {
      requireCurrent();
      if (!isVerifiedAccountIdentity(projectAccountIdentity(user, tokenResult, projectId))) throw {code:'session_changed'};
    };
    const controller = new AbortController(); pending.add(controller);
    try {
      // A fresh SDK token is checked for each request. The server independently
      // verifies its signature/revocation and current Admin-side Apple binding.
      for (let attempt = 0; attempt < 2; attempt++) {
        tokenResult = await user.getIdTokenResult(true);
        requireCurrent();
        if (!isVerifiedAccountIdentity(projectAccountIdentity(user, tokenResult, projectId)) ||
            typeof tokenResult.token !== 'string' || !tokenResult.token || tokenResult.token.length > 16384 || /[\s\u0000-\u001f\u007f]/u.test(tokenResult.token)) throw {code:'unauthenticated'};
        const token = tokenResult.token;
        const response = await fetchRequest(portal ? PREVIEW_PORTAL_ENDPOINT : endpoint+'/'+operation, {method:'POST',mode:'cors',credentials:'omit',cache:'no-store',referrerPolicy:'no-referrer',signal:controller.signal,headers:{'Content-Type':'application/json','Authorization':'Bearer '+token},body:JSON.stringify(portal ? {} : {planKey:'premium_monthly',...extra})});
        requireIdentity();
        // Only an authentication rejection is retried, once, with a fresh SDK
        // result. A business error or unknown mutation outcome is never retried.
        if (response.status === 401 && attempt === 0) continue;
        const value = await response.json();
        requireIdentity();
        if (!response.ok) throw {code:typeof value?.code==='string'?value.code:'service_unavailable'};
        return value;
      }
    } catch (cause) {
      if (!stillCurrent() || cause?.name === 'AbortError') throw {code:'session_changed'};
      if (cause instanceof TypeError) throw {code:'network_error'};
      // Firebase failures must not expose SDK error payloads or credentials.
      if (typeof cause?.code === 'string' && cause.code.startsWith('auth/')) throw {code:'unauthenticated'};
      throw cause;
    } finally { pending.delete(controller); }
  }
  return {
    reviewPreviewCheckout:()=>request('review'),
    createPreviewCheckout:({reviewToken,termsAccepted})=>request('session',{reviewToken,termsAccepted}),
    getPreviewCheckoutStatus:()=>request('status'),
    getPreviewBilling:()=>request('billing'),
    createPreviewPortalSession:()=>request(null, {}, true),
    cancelPreviewCheckout:()=>request('cancel'),
    clear(){generation++;for(const controller of pending)controller.abort();pending.clear();},
  };
}
