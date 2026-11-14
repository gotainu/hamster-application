// Firebase UID remains inside Auth. This service sends only a plan key and a
// short-lived review proof; IDs, prices, trial dates and Customer IDs are not inputs.
export const PREVIEW_CHECKOUT_ENDPOINT = 'https://us-central1-hamster-breeding-app.cloudfunctions.net/createPreviewStripeCheckoutSession';
export function createPreviewCheckoutService({auth, fetchRequest = globalThis.fetch, endpoint = PREVIEW_CHECKOUT_ENDPOINT}) {
  if (endpoint !== PREVIEW_CHECKOUT_ENDPOINT) throw new Error('test_configuration_invalid');
  const pending = new Set();
  let generation = 0;
  async function request(operation, extra = {}) {
    const started = generation;
    const user = auth.currentUser;
    if (!user || !user.uid || !user.emailVerified) throw {code:'unauthenticated'};
    const uid = user.uid;
    const token = await user.getIdToken();
    if (started !== generation || auth.currentUser?.uid !== uid || !auth.currentUser?.emailVerified) throw {code:'session_changed'};
    const controller = new AbortController(); pending.add(controller);
    try {
      const response = await fetchRequest(endpoint+'/'+operation, {method:'POST',mode:'cors',credentials:'omit',cache:'no-store',referrerPolicy:'no-referrer',signal:controller.signal,headers:{'Content-Type':'application/json','Authorization':'Bearer '+token},body:JSON.stringify({planKey:'premium_monthly',...extra})});
      if (started !== generation || auth.currentUser?.uid !== uid || !auth.currentUser?.emailVerified) throw {code:'session_changed'};
      const value = await response.json();
      if (started !== generation || auth.currentUser?.uid !== uid) throw {code:'session_changed'};
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
    cancelPreviewCheckout:()=>request('cancel'),
    clear(){generation++;for(const controller of pending)controller.abort();pending.clear();},
  };
}
