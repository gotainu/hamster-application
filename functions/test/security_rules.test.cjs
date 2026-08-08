'use strict';

const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc } = require('firebase/firestore');
const { ref, uploadBytes, getMetadata, deleteObject } = require('firebase/storage');

const ROOT = path.resolve(__dirname, '../..');
const PROJECT_ID = 'hamster-rules-test';
let passed = 0;
let failed = 0;

async function check(name, fn) {
  try {
    await fn();
    passed += 1;
    console.log(`✅ ${name}`);
  } catch (error) {
    failed += 1;
    console.error(`❌ ${name}`);
    console.error(error);
  }
}

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: fs.readFileSync(path.join(ROOT, 'firestore.rules'), 'utf8') },
    storage: { rules: fs.readFileSync(path.join(ROOT, 'storage.rules'), 'utf8') },
  });

  try {
    await testEnv.clearFirestore();
    await testEnv.clearStorage();

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/alice'), { has_subcollections: true });
      await setDoc(doc(db, 'users/bob'), { has_subcollections: true });
      await setDoc(doc(db, 'users/alice/billing/subscription'), { plan: 'paid', status: 'active' });
      await setDoc(doc(db, 'users/alice/daily_health_features/2026-08-08'), { dateKey: '2026-08-08', source: 'health_pipeline_v4' });
      await setDoc(doc(db, 'users/alice/health_assessments/latest'), { dateKey: '2026-08-08', source: 'health_pipeline_v4' });
      await setDoc(doc(db, 'users/alice/environment_assessments/latest'), { status: 'ok', level: '良好' });
      await setDoc(doc(db, 'users/alice/anomaly_notification_logs/test-log'), { sentAt: null, lastDecisionReason: 'seed' });
      await setDoc(doc(db, 'users/alice/integrations/switchbot'), {
        enabled: true,
        hasSecrets: true,
        authVersion: 'v2_encrypted',
        meterDeviceId: 'meter-1',
        meterDeviceName: 'My Meter',
        meterDeviceType: 'MeterPlus',
      });
      await setDoc(doc(db, 'users/alice/integrations/switchbot_secrets'), {
        v2_encrypted: { token: 'encrypted', secret: 'encrypted' },
      });
      await setDoc(doc(db, 'users/alice/switchbot_readings/r1'), {
        ts: '2026-08-08T00:00:00.000Z', temperature: 24.0,
      });
      await setDoc(doc(db, 'switchbot_users/alice'), { hasSwitchbot: true });
    });

    const alice = testEnv.authenticatedContext('alice');
    const bob = testEnv.authenticatedContext('bob');
    const guest = testEnv.unauthenticatedContext();
    const adb = alice.firestore();
    const bdb = bob.firestore();
    const gdb = guest.firestore();

    await check('未認証はpet profileを読めない', () =>
      assertFails(getDoc(doc(gdb, 'users/alice/pet_profiles/main_pet'))));
    await check('別ユーザーはpet profileを読めない', () =>
      assertFails(getDoc(doc(bdb, 'users/alice/pet_profiles/main_pet'))));
    await check('本人はpet profileを書ける', () =>
      assertSucceeds(setDoc(doc(adb, 'users/alice/pet_profiles/main_pet'), { name: 'Ibuki' }, { merge: true })));
    await check('本人はusers root markerを更新できる', () =>
      assertSucceeds(updateDoc(doc(adb, 'users/alice'), { has_subcollections: true })));
    await check('本人はdaily_checkinsを書ける', () =>
      assertSucceeds(setDoc(doc(adb, 'users/alice/daily_checkins/2026-08-08'), { dayKey: '2026-08-08', condition: 'normal' })));
    await check('本人はAI chatを書ける', () =>
      assertSucceeds(setDoc(doc(adb, 'users/alice/ai_chat_threads/main/messages/m1'), { role: 'user', content: 'test' })));

    await check('本人はbillingを読める', () =>
      assertSucceeds(getDoc(doc(adb, 'users/alice/billing/subscription'))));
    await check('本人でもbillingを改ざんできない', () =>
      assertFails(setDoc(doc(adb, 'users/alice/billing/subscription'), { plan: 'paid', status: 'active' }, { merge: true })));
    await check('本人はSilverを読める', () =>
      assertSucceeds(getDoc(doc(adb, 'users/alice/daily_health_features/2026-08-08'))));
    await check('本人でもSilverを書けない', () =>
      assertFails(setDoc(doc(adb, 'users/alice/daily_health_features/2026-08-08'), { source: 'tampered' }, { merge: true })));
    await check('本人はGoldを読める', () =>
      assertSucceeds(getDoc(doc(adb, 'users/alice/health_assessments/latest'))));
    await check('本人でもGoldを書けない', () =>
      assertFails(setDoc(doc(adb, 'users/alice/health_assessments/latest'), { score: 100 }, { merge: true })));
    await check('本人は環境評価を読める', () =>
      assertSucceeds(getDoc(doc(adb, 'users/alice/environment_assessments/latest'))));
    await check('本人でも環境評価を書けない', () =>
      assertFails(setDoc(doc(adb, 'users/alice/environment_assessments/latest'), { level: 'tampered' }, { merge: true })));
    await check('本人は通知ログを読める', () =>
      assertSucceeds(getDoc(doc(adb, 'users/alice/anomaly_notification_logs/test-log'))));
    await check('本人でも通知ログを書けない', () =>
      assertFails(setDoc(doc(adb, 'users/alice/anomaly_notification_logs/test-log'), { sentAt: new Date() }, { merge: true })));

    await check('本人でもSwitchBot secretsを読めない', () =>
      assertFails(getDoc(doc(adb, 'users/alice/integrations/switchbot_secrets'))));
    await check('本人でもSwitchBot secretsを書けない', () =>
      assertFails(setDoc(doc(adb, 'users/alice/integrations/switchbot_secrets'), { v1_plain: { token: 'x', secret: 'y' } }, { merge: true })));
    await check('本人はSwitchBot表示設定を読める', () =>
      assertSucceeds(getDoc(doc(adb, 'users/alice/integrations/switchbot'))));
    await check('本人は温湿度計メタデータだけ更新できる', () =>
      assertSucceeds(updateDoc(doc(adb, 'users/alice/integrations/switchbot'), {
        meterDeviceId: 'meter-2', meterDeviceName: 'Bedroom', meterDeviceType: 'MeterPlus'
      })));
    await check('本人でもhasSecretsを改ざんできない', () =>
      assertFails(updateDoc(doc(adb, 'users/alice/integrations/switchbot'), { hasSecrets: false })));
    await check('本人はSwitchBot readingsを読める', () =>
      assertSucceeds(getDoc(doc(adb, 'users/alice/switchbot_readings/r1'))));
    await check('本人でもSwitchBot readingsを書けない', () =>
      assertFails(setDoc(doc(adb, 'users/alice/switchbot_readings/r2'), { ts: 'tampered', temperature: 99 })));
    await check('switchbot_usersはClientから読めない', () =>
      assertFails(getDoc(doc(adb, 'switchbot_users/alice'))));
    await check('未定義collectionは本人でも書けない', () =>
      assertFails(setDoc(doc(adb, 'users/alice/unknown_collection/x'), { value: true })));

    const aliceStorage = alice.storage();
    const bobStorage = bob.storage();
    const guestStorage = guest.storage();
    const aliceImage = ref(aliceStorage, 'hamster_images/alice-main_pet.jpg');
    const bobAliceImage = ref(bobStorage, 'hamster_images/alice-main_pet.jpg');
    const guestAliceImage = ref(guestStorage, 'hamster_images/alice-main_pet.jpg');

    await check('本人は自分の画像をuploadできる', () =>
      assertSucceeds(uploadBytes(aliceImage, new Uint8Array([0xff, 0xd8, 0xff, 0xd9]), { contentType: 'image/jpeg' })));
    await check('本人は自分の画像を読める', () => assertSucceeds(getMetadata(aliceImage)));
    await check('別ユーザーは他人の画像を読めない', () => assertFails(getMetadata(bobAliceImage)));
    await check('別ユーザーは他人の画像を上書きできない', () =>
      assertFails(uploadBytes(bobAliceImage, new Uint8Array([1, 2, 3]))));
    await check('未認証は画像を読めない', () => assertFails(getMetadata(guestAliceImage)));
    await check('本人でも許可外Storage pathへ書けない', () =>
      assertFails(uploadBytes(ref(aliceStorage, 'other/alice.txt'), new Uint8Array([1]))));
    await check('本人は自分の画像を削除できる', () => assertSucceeds(deleteObject(aliceImage)));

    console.log(`\nResult: ${passed} passed / ${failed} failed`);
    if (failed > 0) process.exitCode = 1;
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
