# 本番Web Billing API実装記録（2026-11-21・未配備）

対象は開始HEAD `4dc423f`の専用worktreeで準備したFunctions実装。料金・契約・メールの確定方針は既存の[26工程Runbook](web_billing_live_cutover_runbook_ja.md)を維持し、本書はAPIと書込み境界だけを説明する。今回はStripe Live/Test、Firestore本番データ、IAM/Secret、Functions/Hosting、ストアへ変更していない。実決済・実解約・本番配送・本番E2Eの確認結果ではない。

## モジュールと権限境界

| 実装 | 担当する処理と境界 |
| --- | --- |
| `functions/src/webBillingConfig.ts` | 完全なLive専用設定の解析。欠損・Test key・Preview/任意URLを拒否。importだけでは設定読取りや外部呼出を行わない |
| `functions/src/webBillingShared.ts` | UID/provider確認、メール分類、550円/元体験終了日時の純粋policy。Preview側も同じ純粋実装を参照し、Live依存・保存先・credentialsは共有しない |
| `functions/src/webBillingRuntime.ts` | 呼出ごとの設定→Origin/input→失効確認付きFirebase認証→同一UIDの現在Auth読取り。各engineへ検証済みidentityと必要最小限の依存を渡す |
| `functions/src/webBillingCustomer.ts` | 既存billing/専用対応表/UID metadataからLive Customerを解決。新規時だけUIDごとのleaseと固定idempotency keyで作成。email検索・既存Customerのemail/metadata更新・billing書込みは行わない |
| `functions/src/webBillingCheckout.ts` | review/create/status/cancel。対応表と申込調整文書だけを書き、billingや体験を更新しない |
| `functions/src/webBillingPortal.ts` | 同一UIDの既存Live契約管理だけ。読取りと専用Portal Session作成に限定。Customer/Subscription作成・billing同期/権限更新は行わない |
| `functions/src/webBillingWebhook.ts`・`webBillingWebhookStore.ts` | raw署名検証後にStripe正本を再取得。event/UID leaseとsnapshot versionを検査したtransactionで本番billing・処理receipt・通知待ちhookを反映。メールは送らない |
| `functions/src/index.ts` | 既存3 export名からruntimeへ委譲。callableの名称・regionを維持し、旧実装のdefault設定/旧Secretへのfallbackを外す |

## Secretの設定schema

参照するSecretはJSON 1件、`HAMCARE_LIVE_WEB_BILLING_CONFIG`。値はリポジトリ・HTML・Firestore・ログへ記録しない。`STRIPE_*`や`HAMCARE_PREVIEW_*`からの補完はない。

| JSON field | 必須 | 検証・用途 |
| --- | --- | --- |
| `secretKey` | 必須 | `sk_live_`で始まるkey。Test keyを拒否。Stripe objectのmode確認も別途必須 |
| `publishableKey` | 必須 | `pk_live_`で始まるkey。新規Checkout表示に必要な安全なDTOだけへ返す |
| `priceId` | 必須 | 新規550 JPY/month・inclusive・quantity 1専用のLive Price ID。作成済み/有効であることは実APIの検査まで未確認 |
| `legacyPriceId` | 任意 | 旧Live500円の既存契約を認識するID。`priceId`と同値不可。新規Checkoutには使用しない |
| `webhookSecret` | 必須 | `whsec_`で始まる署名検証用Secret |
| `portalConfigurationId` | 必須 | 専用Live Portal Configurationの`bpc_` ID。欠損時にdefaultへfallbackしない |
| `origin` | 必須 | 完全一致で`https://hamster-breeding-app.web.app`のみ |
| `returnUrl` | 必須 | 上記originの`/account/`又は`/account/?portal=return`のみ。Portalへの戻り先はこの設定から固定し、要求本文から受け取らない |

JSON不正・欠損を含む設定の検証は、Auth/Firestore/Stripeの呼出前に行う。1件のschemaを各操作で完全に検査するため、Portalだけ使う場合も全必須fieldが必要。Preview channel、localhost、alternate Firebase origin、任意query/fragment/資格情報入りURLは認めない。CheckoutのStripe return先は別途、上記本番originの`/billing/success/`へ固定する。現時点ではこのSecretの作成・値登録・権限設定を行っていない。

## 呼出API

既存callableは`asia-northeast1`の`createStripeCheckoutSession`と`createStripeCustomerPortalSession`を維持。以下はFirebase callable SDKへ渡す`data`の形であり、生のHTTP callable envelopeとは区別する。認証UIDは本文へ含めない。

| callable / action | data | 安全な応答（`ok:true`を付加） |
| --- | --- | --- |
| Checkout `review` | `{flow:'web',action:'review',planKey:'premium_monthly'}` | `reviewToken`, `expiresAt`, `termsVersion`, `planKey`, `unitAmount:550`, `currency:'jpy'`, `interval:'month'`, `chargeTiming`, `firstChargeAtSeconds`, `nickname`, `maskedEmail` |
| Checkout `create` | `{flow:'web',action:'create',planKey:'premium_monthly',reviewToken,termsAccepted:true,termsVersion}` | `clientSecret`, `publishableKey`。client secretはStripe SDKに渡す用途だけとし、URL・ログ・独自永続化へ保存しない |
| Checkout `status` | `{flow:'web',action:'status'}` | `checkoutStatus`, `billingState:'confirmed'`又は`'pending'` |
| Checkout `cancel` | `{flow:'web',action:'cancel'}` | `checkoutStatus:'expired'`。未完了の当該Checkoutだけをexpireし、既存Subscriptionを解約しない |
| Portal | `{}`、`null`又は未指定 | `{ok:true,portalUrl}`。既存callableの戻りfieldを維持し、Customer/Subscription/Session/Configuration IDを返さない |

Checkoutは厳密な本番Originと`flow:'web'`が必要。actionごとの余分なfield、client指定のUID/email/Customer/Price/体験期限/return URLを拒否する。Portalは同じ本番Origin又はOrigin headerのないnative callableを認め、本文は空object又は既存Flutterの引数なし呼出（null/未指定）だけを受け取る。

両callableでBearer tokenをAdmin `verifyIdToken(token,true)`に通し、callableの`req.auth.uid`と一致させ、同じUIDの現在のAuth userも取得する。新規Checkoutの通常認証はtokenとAuth双方の確認済みメールが必要。Appleは現在の署名済みprovider subjectとAdminのApple provider bindingを照合し、実際の`emailVerified:false`をtrueへ書き換えない。

Portalの既存管理は`authorizeWebBillingManagementIdentity`を使用する。非Appleの同一UID・有効Firebase sessionにはserver側だけで`authBasis:'firebase_session'`を発行し、実際のboolean `emailVerified`を保持する。これにより通常アカウントのメール未確認/メールなしでも、所有を確認した既存契約の期間末解約・管理を妨げない。現在のApple sessionはprovider bindingの確認も維持する。proofは要求本文から受け取らず、Portal engineも空/未知basis・不正UID・非booleanを拒否する。この管理用proofは新規Checkoutや連絡先分類を通過できない。Auth/provider・owner/pet・体験はこのAPIから書き換えない。

設定・状態・SDK例外は外向けに`unavailable`と「現在お申し込みを受け付けていません。」へ絞る。未認証だけ`unauthenticated`。詳細SDK error、UID、宛先、token、Stripe ID、raw要求、Secret名/値を利用者へ返したりログへ出したりしない。

## Checkoutの状態と再試行

- review/create直前に同じUIDのowner・pet・billing・元の無料体験を読み直す。新しい体験・延長・リセットは作らず、既存の48時間＋1分境界を保持する。連絡先・Customer・契約状態も作成前に確認する。
- メールA/Bは現在Authの確認済み通常メール/Apple Relayを使用。Auth/provider双方にメールがないAppleのCだけ、`billing_contacts/{uid}`の確認済み独立連絡先を読む。不正値・未確認メールはCへ丸めず拒否し、Preview連絡先へfallbackしない。
- review tokenは3分有効。保存はtoken hashとUID・料金/体験decision・連絡先hash・terms versionのbinding。create時に同意と同じ条件を再検査し、古い見積りをそのまま課金へ使わない。
- 新規550円Price、JPY/month、inclusive、単一quantity 1、promotion/automatic taxなし、Customer balance/discountなしを照合する。旧500円・既存Subscription・既存割引を更新して新価格へ移行しない。
- Customer作成はUIDごとの共通調整文書と固定idempotency keyを使用。結果不明・lease引継ぎでも同じoperationを保ち、24時間境界以降に新しいCustomer作成へ切り替えない。UID metadata検索は許可するがemailで契約主体を探さない。
- Checkoutも同一attemptのidempotency key・leaseを保持し、結果不明時はそのattemptのSessionを再確認する。31分のSession期限、元operationの期限、idempotencyの安全境界を超えた不明結果を新しい申込へ自動置換しない。
- successページへの到達やSession completedだけでは権限を付与しない。statusはWebhookにより同一UID・Customer・SubscriptionのLive billingがactive/trialingへ反映された後だけ`confirmed`を返す。作成/Portal/success URL側はbillingを書かない。

## 保存先とWebhook

| path | 書込み主体・内容 |
| --- | --- |
| `billing_customers/{sha256(uid)}` | Customer resolverの新規/回復時だけ。`firebaseUid`, `customerId`, operation/lease。Portalの`require-existing`では対応表も書かない |
| `billing_checkout_sessions/{sha256(uid)}` | Checkoutのquote hash・条件binding・operation・lease・Session参照。client secret/Portal URLは保存しない |
| `billing_contacts/{uid}` | 今回は読取りだけ。C用に`firebaseUid`, `purpose:'billing_contact_live'`, `schemaVersion:1`, `verified:true`, `verificationStatus:'verified'`, `source:'user_supplied'`, 過去の安全な整数millis `verifiedAt`, 有効な`email`を要求 |
| `billing_webhook_events/{sha256(eventId)}` | 署名済みeventのclaim/重複処理receipt。raw payloadを保存せず、許可event type・作成時刻・処理状態・lease・安全なerror code等を保存 |
| `billing_webhook_subjects/{sha256(uid)}` | UID単位の同期lease。event到着順だけでbillingを上書きしない |
| `users/{uid}/billing/subscription` | Webhookのtransactionでだけ正本同期。UID/Live/provider/Price・金額・契約状態・実期間・体験期限・解約予約/終了・請求状態を正規化し、既存Flutter用Timestamp fieldも維持 |
| `billing_notification_outbox/{transitionHash}` | 同じtransactionで通知待ちhookを作る。重複event/同じ遷移の再処理でも重複作成を抑止。メール本文・宛先・送信処理は今回の範囲外 |

Webhook export名`stripeWebhook`とregionも維持。POST・queryなし・raw body・署名headerを要求し、署名の300秒許容を過去/未来の双方へ適用、Live event以外は拒否する。対応eventは`checkout.session.completed`、`customer.subscription.created/updated/deleted`、`invoice.paid`、`invoice.payment_failed`。旧endpoint互換の`invoice.payment_succeeded`も`invoice.paid`と同じLive・UID・Price・最新Stripe状態の検証で処理し、旧500円・新550円ともinvoice単位のhook重複抑止で二重通知・二重付与を防ぐ。

payloadのIDからSession/Invoice/Subscription/Customer/Price/Productを再取得し、UID・Live・保存済み対応・許可した料金を確認する。UID lease取得後に改めて読むことで、古いeventや解除前の応答で新しい契約を巻き戻さない。既存のactive/trialing優先も保持する。commit時はevent/UID leaseと対応表/billingのsnapshot versionをtransactionで再検査し、billing・通知hook・processed receiptを一括反映する。

署名不正や不整合は反映せず、同期中・競合・一時的失敗は安全な応答で再試行可能にする。処理済みreceiptと通知hookの保持期限/TTLを今回勝手に追加していない。詳細なclient RulesとAdmin/IAM境界は[Rules監査](production_billing_rules_audit_20261121.md)を参照。clientは全調整/連絡先/通知pathへ直接アクセスできず、本番billingは本人readのみ。Admin SDKの権限をRulesだけで隔離済みとは扱わない。配備済みIAM/Rulesの実値は今回照会していない。

## 既存アプリへの影響と残件

旧アプリの空Checkout要求`{}`は、新しい550円申込へ自動変換せず安全に拒否する。旧価格を表示したまま新価格で課金させないための意図した変更であり、現行アプリの購入CTA撤去/案内とWeb側の接続計画を調整してから配備する。今回はFlutterや公開Webの購入導線を切り替えていない。

既存Portalはnativeの`{}`と`{ok:true,portalUrl}`、検証済みFirebase sessionによる既存管理を維持する。連絡先確認は新規購入の条件であり、既存管理の条件には加えない。一方で全必須設定とPII変更を無効化した専用Live Configurationが必要。準備前の配備は管理導線を停止する。旧500円はcurrent billingに保存済みの同一Subscriptionとlegacy Priceで認識し、coupon/discount/balanceを保持する。未知のCustomer履歴、別UID、100件超のpagination、欠損した旧UID metadata等は自動修復せず停止するため、切替前の読取り照合が残る。

本番の独立連絡先確認producer/検証メール送信は今回追加していない。Cは本番確認済み連絡先がなければ新規review/createを拒否し、既存Portal管理は阻害しない。Preview確認済みの宛先を本番へ暗黙移行しない。

通知outboxは配送完了を意味しない。Gmail本番worker、必要な契約通知のテンプレート/宛先決定、送信済み/失敗状態、有限再試行・指数backoff・429・配送の重複抑止・bounce、連絡先/receipt/outboxの保持削除と退会連携は後工程。[通知とFlutterの既存整理](launch_notifications_and_flutter_scope_20261121.md)を維持する。今回はメール送信0通。

新Live550円Price/専用Portal Configuration/Secret/IAM/Webhook設定の実準備、Live実データ互換照合、実決済・実解約・通知配送E2E、Functions/Rules/Hosting配備、Flutterビルド/提出は未実施。ローカル実装と合成試験の完了を公開GOと扱わない。

## 検証記録

| 検証 | この時点で確認した結果 |
| --- | --- |
| strict TypeScript | `functions/tsconfig.json`によるbuild/`--noEmit` PASS |
| Portal | `functions/test/web_billing_portal.test.cjs` 98/98 PASS。通常の未確認/欠損メールでも既存管理可、不正proof/別UIDは拒否 |
| Customer resolver | `functions/test/web_billing_customer.test.cjs` 40/40 PASS。別factory共有lease、timeout回復、24時間境界、read-only Portal、旧500円等 |
| 現行Firestore Rules | `functions/test/web_billing_rules.emulator.test.cjs` 2/2 PASS・183アクセス操作。専用demo/loopbackだけ。終了後Emulator停止・8297閉鎖確認 |
| Config/共有identity/管理proof/Checkout/runtime/Webhook | 84/24/42/53/49/73件PASS。Portal98/Customer40と合わせ新規463件。既存のpolicy/Stripe優先度/旧同期/体験118件を含む13ファイル581/581 PASS |
| Preview回帰 | strict build後、既存11ファイル514/514 PASS。Test専用設定/URL/namespace/体験/連絡先/Webhook/Portalを保持 |
| 変更整合 | `git diff --check` PASS。依存追加/更新なし、Firestore Rules/Firebase配備設定ファイル差分なし。外部環境変更・配備なし |
