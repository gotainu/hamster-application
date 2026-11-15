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
    if (!user || !user.uid || !user.emailVerified) throw {code:'unauthenticated'};
    const uid = user.uid;
    const token = await user.getIdToken();
    if (started !== generation || auth.currentUser?.uid !== uid || !auth.currentUser?.emailVerified) throw {code:'session_changed'};
    const controller = new AbortController(); pending.add(controller);
    try {
      const response = await fetchRequest(portal ? PREVIEW_PORTAL_ENDPOINT : endpoint+'/'+operation, {method:'POST',mode:'cors',credentials:'omit',cache:'no-store',referrerPolicy:'no-referrer',signal:controller.signal,headers:{'Content-Type':'application/json','Authorization':'Bearer '+token},body:JSON.stringify(portal ? {} : {planKey:'premium_monthly',...extra})});
      if (started !== generation || auth.currentUser?.uid !== uid || !auth.currentUser?.emailVerified) throw {code:'session_changed'};
      const value = await response.json();
      if (started !== generation || auth.currentUser?.uid !== uid || !auth.currentUser?.emailVerified) throw {code:'session_changed'};
      if (!response.ok) throw {code:typeof value?.code==='string'?value.code:'service_unavailable'};
      return value;
    } catch (cause) {
      if (started !== generation || cause?.name === 'AbortError') throw {code:'session_changed'};
      if (cause instanceof TypeError) throw {code:'network_error'};
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
