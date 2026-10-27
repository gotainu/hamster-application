/** Server-controlled launch measurement classification. Unknown is excluded
 * from general-user metrics; a client flag never promotes a user to general. */
import {isValidationUid} from './validationIdentity';

export type AnalyticsEnvironment = 'live' | 'test' | 'emulator' | 'unknown';
export interface AnalyticsClassification {
  environment: AnalyticsEnvironment;
  accountClassification: 'general' | 'test' | 'unknown';
  billingLivemode: boolean | null;
}
export function classifyAnalytics(uid: string, data: Record<string, unknown> = {}): AnalyticsClassification {
  const explicitTest = data.testOnly === true || isValidationUid(uid) ||
    (process.env.ANALYTICS_TEST_UIDS ?? '').split(',').map(value => value.trim()).includes(uid);
  const billingLivemode = typeof data.billingLivemode === 'boolean' ? data.billingLivemode : null;
  const configured = process.env.ANALYTICS_ENVIRONMENT;
  const emulator = process.env.FUNCTIONS_EMULATOR === 'true' || Boolean(process.env.FIRESTORE_EMULATOR_HOST);
  // A durable server stamp is historical evidence. Configuration changes or
  // delivery retries must never promote a stamped unknown/test event to live.
  // The current server test registry may still conservatively exclude a user.
  if (explicitTest || billingLivemode === false) {
    return {environment: emulator ? 'emulator' : 'test', accountClassification: 'test', billingLivemode};
  }
  if (emulator) return {environment: 'emulator', accountClassification: 'test', billingLivemode};
  if (data.environment !== undefined || data.accountClassification !== undefined) {
    if (data.environment === 'test' || data.environment === 'emulator') {
      return {environment: data.environment, accountClassification: 'test', billingLivemode};
    }
    if (data.environment === 'live' && data.accountClassification === 'general') {
      return {environment: 'live', accountClassification: 'general', billingLivemode};
    }
    return {environment: 'unknown', accountClassification: 'unknown', billingLivemode};
  }
  const environment: AnalyticsEnvironment = configured === 'test' ? 'test' :
    configured === 'live' ? 'live' : 'unknown';
  return {environment, accountClassification: environment === 'test' ? 'test' :
    environment === 'live' ? 'general' : 'unknown', billingLivemode};
}
