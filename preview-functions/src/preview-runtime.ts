import {getFirestore, Timestamp} from 'firebase-admin/firestore';
import {hash, AppFacts, CheckoutError} from './engine';

export const PREVIEW_NAMESPACE='preview_checkout_task4';
export const FIXTURE_TAG='task5-operator-fixture-v1';
export function subjectRef(subject:string) {
  if(!/^[a-f0-9]{64}$/.test(subject))throw new CheckoutError('unauthenticated');
  return getFirestore().collection(PREVIEW_NAMESPACE).doc(subject);
}
/** Operator-written, expiring Test-only facts. Never accepted from HTTP input. */
export async function readPreviewFacts(uid:string,forSync=false):Promise<AppFacts> {
  const db=getFirestore();const root=subjectRef(hash(uid));
  const fixture=await root.collection('fixture').doc('facts').get();
  const canonicalEmulatorFixture=forSync && fixture.get('authSource')==='firebase-auth-emulator';
  if(fixture.exists && (fixture.get('enabled')!==false || canonicalEmulatorFixture)) {
    const f=fixture.data()!;const expiry=f.expiresAt instanceof Timestamp?f.expiresAt.toMillis():0;
    if(f.tag!==FIXTURE_TAG || f.previewFirebaseUid!==uid || (!canonicalEmulatorFixture && expiry<=Date.now()) || expiry<=0 || expiry>Date.now()+86400000 || f.appAccountExists!==true || !['unstarted','expired','trialing'].includes(f.scenario))throw new CheckoutError('test_configuration_invalid');
    const trial=f.scenario==='unstarted'?{kind:'missing'}:{kind:'found',data:f.trial};
    return {appAccountExists:true,billing:{kind:'missing'},trial,nickname:'Preview検証用',maskedEmail:'非公開',testDataSource:'preview_fixture'};
  }
  const user=db.collection('users').doc(uid);
  const [pet,billing,trial,owner]=await db.getAll(user.collection('pet_profiles').doc('main_pet'),user.collection('billing').doc('subscription'),user.collection('feature_access').doc('initial_trial_v2'),user.collection('owner_profiles').doc('main'));
  const item=(s:typeof billing)=>s.exists?{kind:'found',data:s.data()}:{kind:'missing'};
  const name=owner.data()?.displayName;
  return {appAccountExists:pet.exists,billing:item(billing),trial:item(trial),nickname:typeof name==='string'&&name.trim()?name.trim().slice(0,80):'未設定',maskedEmail:'非公開',testDataSource:'app'};
}
export interface PreviewWebhookConfig {endpointId:string;endpointUrl:string;signingSecret:string;}
export function parseWebhookConfig(raw:string):PreviewWebhookConfig {
  let c:any;try{c=JSON.parse(raw);}catch{throw new CheckoutError('test_configuration_invalid');}
  if(!c || !/^we_[A-Za-z0-9]+$/.test(c.endpointId) || typeof c.signingSecret!=='string' || !c.signingSecret.startsWith('whsec_') || typeof c.endpointUrl!=='string')throw new CheckoutError('test_configuration_invalid');
  let url:URL;try{url=new URL(c.endpointUrl);}catch{throw new CheckoutError('test_configuration_invalid');}
  if(url.protocol!=='https:' || url.hostname!=='us-central1-hamster-breeding-app.cloudfunctions.net' || url.pathname!=='/stripePreviewWebhook' || url.search || url.hash || url.username || url.password)throw new CheckoutError('test_configuration_invalid');
  return {endpointId:c.endpointId,endpointUrl:c.endpointUrl,signingSecret:c.signingSecret};
}
