import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {defineSecret} from 'firebase-functions/params';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import * as logger from 'firebase-functions/logger';
import {createBillingNotificationRuntime} from './billingNotificationRuntime';
import {dispatchLiveBillingNotifications} from './billingNotificationDispatch';

// Binding only; no value is read by the disabled handler. Deployment still
// needs valid Secret access for the platform's environment mount at startup.
const mailConfig=defineSecret('HAMCARE_LIVE_BILLING_MAIL_CONFIG');
export const processBillingNotificationOutbox=onSchedule({region:'asia-northeast1',schedule:'every 15 minutes',
  timeZone:'Asia/Tokyo',secrets:[mailConfig],maxInstances:1,timeoutSeconds:120,memory:'256MiB',retryCount:0},async()=>{
  try {
    const result=await dispatchLiveBillingNotifications({
      enabled:process.env.HAMCARE_BILLING_NOTIFICATIONS_ENABLED,scope:process.env.HAMCARE_BILLING_NOTIFICATIONS_SCOPE,
      notBeforeMillis:()=>process.env.HAMCARE_BILLING_NOTIFICATIONS_NOT_BEFORE_MILLIS,
      limited:()=>({notBeforeMillis:process.env.HAMCARE_BILLING_NOTIFICATIONS_LIMITED_NOT_BEFORE_MILLIS,
        expiresAtMillis:process.env.HAMCARE_BILLING_NOTIFICATIONS_LIMITED_EXPIRES_AT_MILLIS,
        subjectHash:process.env.HAMCARE_BILLING_NOTIFICATIONS_LIMITED_UID_SHA256,
        recipientHash:process.env.HAMCARE_BILLING_NOTIFICATIONS_LIMITED_RECIPIENT_SHA256,
        notificationId:process.env.HAMCARE_BILLING_NOTIFICATIONS_LIMITED_NOTIFICATION_ID}),
      nowMillis:Date.now(),run:async policy=>createBillingNotificationRuntime({
        db:getFirestore(),auth:getAuth(),environment:'live',liveDispatchScope:policy.scope,liveDispatchNotBeforeMillis:policy.notBeforeMillis,
        ...(policy.scope==='limited'?{liveLimitedSelection:policy}:{}),
        rawConfig:()=>process.env.HAMCARE_LIVE_BILLING_MAIL_CONFIG,
        dailyLimit:Number(process.env.HAMCARE_BILLING_MAIL_DAILY_LIMIT)}).runOnce()});
    logger.info('Billing notification batch finished',result);
  } catch {
    // Never log SDK errors, recipient addresses, IDs, MIME, tokens or config.
    logger.warn('Billing notification worker unavailable');
  }
});
