export const BILLING_CONTACT_PREVIEW_ORIGIN = 'https://hamster-breeding-app--web-first-task1-lco08m60.web.app';
export const BILLING_CONTACT_LIVE_ORIGIN = 'https://hamster-breeding-app.web.app';
export const BILLING_CONTACT_ENDPOINT = 'https://us-central1-hamster-breeding-app.cloudfunctions.net/previewBillingContactEmail';
export const BILLING_CONTACT_LIVE_ENDPOINT = 'https://asia-northeast1-hamster-breeding-app.cloudfunctions.net/billingContactEmail';
export const BILLING_CONTACT_PLAN_RETURN = '/account/?contact=verified&view=plan';
const environments = Object.freeze({
  preview: Object.freeze({environment:'preview',testMode:true,origin:BILLING_CONTACT_PREVIEW_ORIGIN,
    endpoint:BILLING_CONTACT_ENDPOINT,appName:'hamcare-web-preview'}),
  live: Object.freeze({environment:'live',testMode:false,origin:BILLING_CONTACT_LIVE_ORIGIN,
    endpoint:BILLING_CONTACT_LIVE_ENDPOINT,appName:'hamcare-web-live'}),
});
export function billingContactEnvironment(environment) {
  if (environment!=='preview' && environment!=='live') throw {code:'contact_configuration_unavailable'};
  return environments[environment];
}
/** Origin chooses a fixed deployment, never a URL parameter, stored preference,
 * endpoint supplied by a caller, or a fallback after a failed Live request. */
export function resolveBillingContactEnvironment(origin) {
  if (origin===BILLING_CONTACT_PREVIEW_ORIGIN) return environments.preview;
  if (origin===BILLING_CONTACT_LIVE_ORIGIN) return environments.live;
  throw {code:'contact_configuration_unavailable'};
}
