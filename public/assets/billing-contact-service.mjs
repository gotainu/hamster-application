import {projectAccountIdentity, isVerifiedAccountIdentity} from './account-identity.mjs';
import {normalizeBillingEmail, projectBillingContact} from './billing-contact-model.mjs';

export const BILLING_CONTACT_ENDPOINT = 'https://us-central1-hamster-breeding-app.cloudfunctions.net/previewBillingContactEmail';

/** No cookies, token persistence, arbitrary endpoints, or automatic mutation retry. */
export function createBillingContactService({auth, fetchRequest = globalThis.fetch, endpoint = BILLING_CONTACT_ENDPOINT}) {
  if (endpoint !== BILLING_CONTACT_ENDPOINT) throw new Error('test_configuration_invalid');
  let generation = 0;
  let mutationPending = null;
  const controllers = new Set();
  async function request(operation, body = {}) {
    if (!['status','request','confirm'].includes(operation)) throw {code:'contact_invalid_response'};
    const user = auth?.currentUser;
    if (!user || typeof user.uid !== 'string' || !user.uid || typeof user.getIdTokenResult !== 'function') throw {code:'unauthenticated'};
    const started = generation, uid = user.uid;
    const current = () => started === generation && auth.currentUser === user && auth.currentUser?.uid === uid;
    const ensureCurrent = () => { if (!current()) throw {code:'session_changed'}; };
    const controller = new AbortController(); controllers.add(controller);
    try {
      for (let attempt=0; attempt<2; attempt++) {
        const tokenResult = await user.getIdTokenResult(true); ensureCurrent();
        if (!isVerifiedAccountIdentity(projectAccountIdentity(user, tokenResult, auth.app?.options?.projectId)) ||
            typeof tokenResult?.token !== 'string' || !tokenResult.token || tokenResult.token.length > 16384 || /[\s\u0000-\u001f\u007f]/u.test(tokenResult.token)) throw {code:'unauthenticated'};
        const response = await fetchRequest(endpoint+'/'+operation, {method:'POST',mode:'cors',credentials:'omit',cache:'no-store',referrerPolicy:'no-referrer',
          signal:controller.signal,headers:{'Content-Type':'application/json',Authorization:'Bearer '+tokenResult.token},body:JSON.stringify(body)});
        ensureCurrent();
        const freshIdentity = projectAccountIdentity(user, tokenResult, auth.app?.options?.projectId);
        if (!isVerifiedAccountIdentity(freshIdentity)) throw {code:'session_changed'};
        // An HTTP authentication rejection guarantees that the operation was denied.
        if (response.status === 401 && attempt === 0) continue;
        const value = await response.json(); ensureCurrent();
        if (!response.ok) throw {code:typeof value?.code === 'string' ? value.code : 'service_unavailable'};
        return projectBillingContact(value);
      }
    } catch (error) {
      if (!current() || error?.name === 'AbortError') throw {code:'session_changed'};
      if (error instanceof TypeError || error instanceof SyntaxError) throw {code:'network_error'};
      if (typeof error?.code === 'string' && error.code.startsWith('auth/')) throw {code:'unauthenticated'};
      throw {code:typeof error?.code === 'string' ? error.code : 'service_unavailable'};
    } finally {controllers.delete(controller);}
  }
  async function mutate(operation, body) {
    const started = generation;
    if (mutationPending === started) throw {code:'contact_sending'};
    mutationPending = started;
    try {return await request(operation, body);} finally {if(mutationPending === started)mutationPending = null;}
  }
  return Object.freeze({
    getStatus: () => request('status'),
    requestVerification(value) {
      const email = normalizeBillingEmail(value);
      if (!email) return Promise.reject({code:'contact_invalid_email'});
      return mutate('request', {email});
    },
    confirmVerification(token) {
      if (typeof token !== 'string' || !/^[A-Za-z0-9_-]{43,128}$/u.test(token)) return Promise.reject({code:'contact_invalid_token'});
      return mutate('confirm', {token});
    },
    clear() {generation++;mutationPending=null;for (const controller of controllers) controller.abort();controllers.clear();},
  });
}
