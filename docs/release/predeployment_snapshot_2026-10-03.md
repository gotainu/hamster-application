# 2026-10-03 接続検証反映前スナップショット

対象はローンチ前の限定接続検証。一般公開・GitHub push・ストア配布は含まない。
Firebase project は `hamster-breeding-app`（797691641198）、Cloud Run と BigQuery の
リージョンは `asia-northeast1`。Firebase/GA4 の BigQuery リンクはユーザーが Console で
完了したと報告済み。リンクの再作成はしない。

## Cloud Run（反映前）

- Service: `hamster-rag-api`
- URL: `https://hamster-rag-api-laroc33gtq-an.a.run.app`（GET `/` が HTTP 200）
- 100% traffic: revision `hamster-rag-api-00015-xwj`
- Image: `asia-northeast1-docker.pkg.dev/hamster-breeding-app/cloud-run-source-deploy/hamster-rag-api:f621356`
- Runtime service account: `hamster-rag-runner@hamster-breeding-app.iam.gserviceaccount.com`
- `APP_CHECK_ENFORCE=false` は維持。`/chat` は Firebase ID token 検証必須。現在のコードで
  `/chat` のモデル前にサーバー利用枠を確保し、limited-validation allowlist を必須化する。
- 以前の revision は保持するが、旧 RAG は新しい予約・認証上限を持たないため、AI有効状態で
  そこへ戻さない。緊急停止は後述の `AI_CHAT_ENABLED=0` で fail-closed にする。

## Firestore rules（反映前）

- Release: `projects/hamster-breeding-app/releases/cloud.firestore`
- Ruleset: `220f7563-1b97-4d7f-8131-2f47d217d018`
- Local source SHA-256: `56bcabd0c539221d5bec2f2010a678d0290bf431fa5a22e8577821a6abe4218e`
- 旧 ruleset は実記録 write gate と server-owned trial/readiness/report/event の deny を含まない。
  切り戻しで旧 rules に戻すことは禁止し、権限確認を常に維持する。

## 既存 Functions（反映前）

| Function | Revision | Source object generation | Build |
| --- | --- | ---: | --- |
| `healthWeightRecordWritten` | `healthweightrecordwritten-00009-keg` | 1790992379645313 | `029ba79e-c806-4331-82ad-28ae96bdd44d` |
| `healthDistanceRecordWritten` | `healthdistancerecordwritten-00009-pig` | 1790992419123526 | `029ba79e-c806-4331-82ad-28ae96bdd44d` |
| `healthDailyCheckinWritten` | `healthdailycheckinwritten-00009-kam` | 1790992379821317 | `f8466386-be57-4ad5-91f3-1c27982fb2ee` |
| `healthEnvironmentLatestWritten` | `healthenvironmentlatestwritten-00009-hiv` | 1790992439831171 | `f8466386-be57-4ad5-91f3-1c27982fb2ee` |
| `healthEnvironmentHistoryWritten` | `healthenvironmenthistorywritten-00009-gab` | 1790992439763128 | `f8466386-be57-4ad5-91f3-1c27982fb2ee` |
| `pollMySwitchbotNow` | `pollmyswitchbotnow-00041-lin` | 1790992429539209 | `d6202fac-b86d-4ed4-aaa6-55dca385c4b0` |
| `switchbotPoller` | `switchbotpoller-00026-kec` | 1790992428798739 | `d6202fac-b86d-4ed4-aaa6-55dca385c4b0` |

Source archives are in `gs://gcf-v2-sources-797691641198-asia-northeast1/<function>/function-source.zip`
at the listed generations; existing Cloud Run revisions and function source objects are retained.
SwitchBot acquisition checks paid or unexpired trial server-side; trial AI count is separate from
recording, SwitchBot acquisition and analysis access.

## BigQuery (反映前)

- `bigquery.googleapis.com` is enabled. Dataset listing returned empty.
- Expected GA4 property: `549839505`; expected daily-export dataset name is
  `analytics_549839505`. Console still reported “dataset not created”; no events have been confirmed.
- Analytics Admin API link read was unavailable under the current OAuth scope. No link change was made.
- Authorized server metadata destination: `hamcare_trial_analytics` in `asia-northeast1`; it must not
  be confused with, or replace, the Firebase-created daily export dataset.
- The scoped ingestion service account did not exist at snapshot time. It will receive only dataset
  write access after the dataset is created.

## テスト UID とデータ保護

- Test UID A: `uRgVakjkaqOxY6uiv0fH9B0d1wS2`
- Test UID B: `4sD1MUmi9OTM5SaRq66qGWW8q2p2`
- Read-only checks found no documents under their inspected record/history/profile/trial paths.
- The data-bearing owner UID `suMUKXnF9xWd5sfxlOGyPnL0yGv2` is excluded from all destructive tests.
- Server-side AI validation budget: 4 consultations total across A+B, $0.20 reserved total,
  $0.05 reserved per consultation; duplicate `request_id` does not consume a second slot.

## Safe response / rollback

1. Stop new AI generation by deploying a revision with `AI_CHAT_ENABLED=0`; never remove auth,
   per-user quota or validation allowlist checks.
2. Keep Firestore rules fail-closed for record writes and server-owned data. Do not restore the
   prior ruleset, which lacks trial enforcement.
3. If a Cloud Run code defect must be isolated, leave AI disabled until a reviewed hardened image
   is available. Do not send traffic to the pre-hardening revision while AI is enabled.
4. Keep Functions on the new entitlement/metadata path. If an event consumer fails, disable that
   consumer only after confirming no permission bypass is introduced; preserve all stored records.

No user data, subscription, fixture, trial expiry, existing GA link or BigQuery export setting was
modified while making this snapshot.
