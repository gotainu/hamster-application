'use strict';
// Operator-only smoke runner. Fixed owner/5 fixture types, no arbitrary address,
// message or client endpoint. OAuth secrets remain in process memory only.
const {spawnSync}=require('node:child_process');
const {createHash}=require('node:crypto');
const {initializeApp}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');
const {getAuth}=require('firebase-admin/auth');
const {parseBillingNotificationMailConfig}=require('../lib/billingNotificationGmail');
const {resolveBillingNotificationRecipient}=require('../lib/billingNotificationRecipient');
const {billingNotificationsFromHooks}=require('../lib/billingNotificationEvents');
const PROJECT='hamster-breeding-app',RUN='hamcare-billing-mail-preview-20261121-v1';
const hash=v=>createHash('sha256').update(v).digest('hex');
async function main(){
  if(process.argv.length!==3 || !['--inspect','--send-owner-preview'].includes(process.argv[2]))throw Error();
  const secret=spawnSync('/opt/homebrew/bin/gcloud',['secrets','versions','access','latest',
    '--secret=HAMCARE_PREVIEW_CONTACT_MAIL_CONFIG','--project='+PROJECT],{encoding:'utf8',timeout:30000,maxBuffer:100000});
  if(secret.status!==0)throw Error();
  const config=parseBillingNotificationMailConfig(secret.stdout,'preview');
  if(config.allowedSubjectHashes.length!==1 || config.allowedRecipientHashes.length!==1 ||
      config.allowedRecipientHashes[0]!==hash(config.from))throw Error();
  initializeApp({projectId:PROJECT});const db=getFirestore(),auth=getAuth();
  const account=(await db.doc('preview_checkout_task4/'+config.allowedSubjectHashes[0]).get()).data();
  const uid=account?.previewFirebaseUid;
  if(typeof uid!=='string'||hash(uid)!==config.allowedSubjectHashes[0])throw Error();
  const [user,contact,owner,pet]=await Promise.all([auth.getUser(uid),db.doc('preview_billing_contacts/'+uid).get(),
    db.doc('users/'+uid+'/owner_profiles/main').get(),db.doc('users/'+uid+'/pet_profiles/main_pet').get()]);
  const recipient=resolveBillingNotificationRecipient({uid,authUser:user,mode:'preview',nowMillis:Date.now(),supplementalContact:{uid,state:contact.data()}});
  if(recipient.kind!=='resolved'||recipient.email!==config.from||!owner.exists||!pet.exists)throw Error();
  if(process.argv[2]==='--inspect'){process.stdout.write(JSON.stringify({ready:true,ownerBound:true,recipientAllowlisted:true,fixtureCount:5})+'\n');return;}
  // Freeze this smoke run's event clock. Re-executing the runner must not turn
  // a later wall clock into another synthetic cancellation notification.
  const existing=await db.collection('preview_billing_notification_outbox').where('fixtureRunId','==',RUN).limit(10).get();
  if(existing.size>6||existing.docs.some(s=>s.get('firebaseUid')!==uid||s.get('environment')!=='preview'||s.get('trustedSource')!=='preview_fixture'))throw Error();
  const priorRegistration=existing.docs.find(s=>s.get('type')==='contract_registered');
  const manifest=db.doc('preview_billing_notification_delivery_limits/_run_'+RUN);
  const now=await db.runTransaction(async tx=>{
    const saved=await tx.get(manifest);
    if(saved.exists){
      if(saved.get('environment')!=='preview'||saved.get('ownerHash')!==hash(uid)||saved.get('runId')!==RUN||
        !Number.isSafeInteger(saved.get('createdAtMillis')))throw Error();
      return saved.get('createdAtMillis');
    }
    const createdAtMillis=priorRegistration?.get('createdAtMillis')??Date.now();
    if(!Number.isSafeInteger(createdAtMillis)||createdAtMillis<=0)throw Error();
    tx.create(manifest,{environment:'preview',ownerHash:hash(uid),runId:RUN,createdAtMillis});return createdAtMillis;
  });
  const start=Math.floor(now/1000),endDate=new Date(now);
  endDate.setUTCMonth(endDate.getUTCMonth()+1);const end=Math.floor(endDate.getTime()/1000);
  const sub='sub_HamcareMailPreview20261121',invoice='in_HamcareMailPreview20261121';
  const base={firebaseUid:uid,stripeSubscriptionId:sub,stripeCustomerId:'cus_HamcareMailPreview20261121',
    legacyPrice:false,amount:550,currency:'jpy',interval:'month',status:'active',
    trialEndSeconds:null,currentPeriodStartSeconds:start,currentPeriodEndSeconds:end,nextChargeAtSeconds:end,
    latestInvoicePaymentStatus:'paid',latestInvoiceAmountPaid:550,latestInvoiceTotal:550,canceledAtSeconds:null,cancelAtPeriodEnd:false};
  const fixtures=[['contract_started',{...base,status:'trialing',trialEndSeconds:start+21*86400,nextChargeAtSeconds:start+21*86400,
    latestInvoicePaymentStatus:'no_payment_required',latestInvoiceAmountPaid:0,latestInvoiceTotal:0}],
    ['first_charge',base],['payment_failed',{...base,status:'past_due',latestInvoicePaymentStatus:'unpaid',latestInvoiceAmountPaid:0}],
    ['cancel_reserved',{...base,cancelAtPeriodEnd:true,nextChargeAtSeconds:null}],
    ['canceled',{...base,status:'canceled',nextChargeAtSeconds:null,canceledAtSeconds:start}]];
  const notifications=fixtures.flatMap(([type,billing])=>billingNotificationsFromHooks({billing,environment:'preview',trustedSource:'preview_fixture',
    hooks:[{id:hash(RUN+':'+type),type,firebaseUid:uid,subscriptionId:sub,invoiceId:invoice,
      transitionKey:RUN+':'+type,eventHash:hash(RUN+':'+type),status:'pending',createdAtMillis:now}]}));
  if(notifications.length!==5)throw Error();
  const refs=notifications.map(n=>db.doc('preview_billing_notification_outbox/'+n.id));
  const expectedIds=new Set(notifications.map(n=>n.id));
  const extra=existing.docs.filter(s=>!expectedIds.has(s.id));
  let discardedUnsentFixtures=0;
  await db.runTransaction(async tx=>{
    const all=await Promise.all([...refs,...extra.map(s=>s.ref)].map(ref=>tx.get(ref))),old=all.slice(0,refs.length);
    for(const s of all.slice(refs.length)){
      // Cleanup is restricted to this runner's own never-dispatched fixtures.
      // A sent, in-flight or uncertain record is never removed or reset.
      if(!s.exists)continue;
      if(s.get('firebaseUid')!==uid||s.get('fixtureRunId')!==RUN||s.get('trustedSource')!=='preview_fixture'||
        !['pending','failed_retryable','blocked_invalid_notification'].includes(s.get('status'))||s.get('sendStartedAtMillis')||s.get('messageIdHash'))throw Error();
      tx.delete(s.ref);discardedUnsentFixtures++;
    }
    for(let i=0;i<notifications.length;i++)if(!old[i].exists)tx.create(refs[i],{...notifications[i],fixtureRunId:RUN});
  });
  // A local runner may dispatch only this run's five known fixture IDs. It
  // cannot process other queued Preview notifications belonging to another run.
  const {createBillingNotificationWorker}=require('../lib/billingNotificationWorker');
  const {createBillingNotificationStore}=require('../lib/billingNotificationStore');
  const {createBillingNotificationBudget}=require('../lib/billingNotificationBudget');
  const {createBillingNotificationGmailSender}=require('../lib/billingNotificationGmail');
  const {renderBillingNotification}=require('../lib/billingNotificationTemplates');
  const {BILLING_NOTIFICATION_RETRY_POLICY}=require('../lib/billingNotificationRuntime');
  const store=createBillingNotificationStore(db,'preview'),sender=createBillingNotificationGmailSender(config);
  const scoped={...store,listDue:async()=>{
    const snapshots=await Promise.all(refs.map(ref=>ref.get()));
    return snapshots.filter(s=>s.get('fixtureRunId')===RUN&&Number.isSafeInteger(s.get('dispatchAtMillis'))&&s.get('dispatchAtMillis')<=Date.now()).map(s=>s.id);
  }};
  let providerSendCalls=0;
  const summary=await createBillingNotificationWorker({store:scoped,config:{environment:'preview',...BILLING_NOTIFICATION_RETRY_POLICY},now:Date.now,
    allowedRecipient:(subject,email)=>subject===uid&&email===config.from,
    resolveRecipient:async subject=>{
      if(subject!==uid)return null;
      const [currentUser,c]=await Promise.all([auth.getUser(uid),db.doc('preview_billing_contacts/'+uid).get()]);
      const result=resolveBillingNotificationRecipient({uid,authUser:currentUser,mode:'preview',nowMillis:Date.now(),supplementalContact:{uid,state:c.data()}});
      return result.kind==='resolved'?{email:result.email,source:result.source}:null;
    },render:n=>renderBillingNotification({type:n.type,mode:'preview',snapshot:n.snapshot,templateVersion:n.templateVersion}),
    send:m=>{providerSendCalls++;return sender.send(m);},reserveDelivery:createBillingNotificationBudget(db,'preview',10)}).runOnce();
  const final=await Promise.all(refs.map(ref=>ref.get()));
  process.stdout.write(JSON.stringify({run:RUN,summary,providerSendCalls,discardedUnsentFixtures,results:final.map(s=>({type:s.get('type'),status:s.get('status'),attempts:s.get('attempts'),
    category:s.get('lastErrorCategory')??null})),productionWrites:0,stripeCalls:0})+'\n');
}
const completion=main().catch(()=>{process.stderr.write('Preview mail smoke check unavailable; no secret or recipient details logged.\n');process.exitCode=1;});
module.exports={completion};
