# 本番Web Billing・Portal・Rules/IAMのローカル監査（2026-11-21）

対象は専用worktreeのローカル実装・設定。開始HEADは`4dc423f`。Rules、IAM、Stripe、Firebaseの本番設定は変更せず、リモートの現在値も照会していない。本書は配備済み設定の再確認結果ではない。

## Client Security Rules

- `firestore.rules`の`users/{uid}/billing/subscription`は本人readだけ許可し、writeは常にfalse。別UID・未認証のread、本人を含むcreate/update/deleteは不可。
- `users/{uid}`のclient更新は既存の`has_subcollections`だけ。Stripe Customer参照、plan、statusをrootへ書いてbillingを迂回できない。
- `users`配下の未定義pathと最外の未定義pathはdeny。`preview_checkout_task4`、`preview_billing_contacts`とそのstatus投影、`preview_billing_contact_delivery_limits`をclientへ開放する本番Rulesはない。
- 本番のCustomer対応`billing_customers`、Checkout調整用`billing_checkout_sessions`、連絡先`billing_contacts`、Webhook event/subject/outbox用`billing_webhook_events`・`billing_webhook_subjects`・`billing_notification_outbox`も最外denyの対象。識別子のハッシュ化をアクセス制御の代替にはしていない。
- `firebase.json`が指定するRulesは`firestore.rules`。`firestore.contact-preview.rules`は別候補ファイルであり、この通常設定の配備対象へ自動的に切り替わらない。`firebase.checkout-preview.json`の別codebaseもIAMによるcollection分離を意味しない。

検証元は`functions/test/web_billing_rules.emulator.test.cjs`。`demo-hamcare-production-billing`、`127.0.0.1:8297`の専用Emulatorだけで本人・別UID・未認証を確認する。実Firebaseの認証情報は読み込まず、明示されたloopback以外ではテストを開始しない。

## Portalの安全境界

実装は`functions/src/webBillingPortal.ts`、合成試験は`functions/test/web_billing_portal.test.cjs`。

- `parseWebBillingConfig`を構築時と各操作の先頭で呼ぶ。専用Portal Configuration ID欠損・Test key・Preview/任意return URLを、resolver/Firestore/Stripe呼出より先に拒否する。Stripeのdefault configurationにfallbackしない。
- serverで検証した同一UIDだけを`require-existing` resolverへ渡す。Customerを再取得し、Live・未削除・UID metadata一致を確認する。旧metadataが欠損する互換分岐はcurrent billingの正確なCustomer/Subscription参照だけで限定し、明示された別UIDとPreview metadataは必ず拒否する。実resolver側がより厳密な場合はその制約も残る。
- 既存管理では失効確認済み・同一UIDのFirebase sessionをserverだけが管理用proofへ変換する。通常アカウントの未確認/欠損メールも既存契約の解約管理を妨げず、現在Apple sessionのprovider照合は維持する。proofは本文から受け取らず、新規Checkout/連絡先分類に流用しない。
- config/Customer/Subscription/Price/Product/Portal Sessionの`livemode === true`を確認。Customer全体へPortalを開くため、一覧にある履歴もすべてUID・許可Price・単一quantity=1等を検証し、ページング・未対応状態・未対応Priceは安全側で停止する。
- 新550円は設定したJPY/month・inclusive Priceだけ。旧500円は設定したlegacy Price IDかつcurrent billingに保存済みの同一Subscriptionだけを認識する。旧Priceのarchive、既存の100% coupon/discountやCustomer balanceを変更・移行しない。
- 許可操作は請求履歴、支払方法更新、`at_period_end`かつ`proration_behavior=none`の解約。Customerの氏名/メール/住所/電話更新、Subscription/Price/quantity更新、即時解約、新規購入、retention offer/割引提案、未知の有効機能を拒否する。login pageも無効必須。
- active/trialing/past_due/unpaid/paused/incompleteと期間末解約予約は既存管理可。連絡先メールの欠損・体験期限・有料期間の経過を管理停止や権限付与の理由にしない。canceled/incomplete_expired、未知状態、削除Customer、対応不明・別UIDは停止する。選択後のSubscription再取得で一覧との競合を再確認する。
- 各操作で固定の本番return URL・locale ja・専用Configurationの新しいPortal Sessionだけを作成する。返却DTOは`{url}`のみ。URLやCustomer/Subscription IDを永続化・ログ出力しない。Customer/Subscriptionの作成、Checkout、billing書込み・権限更新の依存は持たない。

## IAM/管理SDKの制約

- Security Rulesはclient SDKの境界であり、Admin SDK/service accountからの書込みを禁止する仕組みではない。Emulatorのseedも明示したRules bypassであり、IAMの実証にはならない。
- リポジトリの`.firebaserc`は通常の既定projectを指定する。今回は専用demo projectを明示したEmulator以外に接続していない。IAM policy/role binding、配備済みruntime service accountとそのSecret Accessor権限、service agentの実際の権限はリポジトリだけでは確定できない。外部照会・権限変更は0。
- 同じFirestore projectでPreview/本番をcollection名やFunctions codebaseで分けても、広いAdmin権限を持つ実行主体が相互の業務データを更新できない保証にはならない。今回のPortalは読取りだけに限定し、Checkoutの対応表書込みとWebhookの本番billing書込みはそれぞれ別の明示した実装境界で制御する。
- 将来配備時のIAM確認はRunbookの独立工程として残す。必要なruntimeとSecretへの最小権限、公開HTTP/callableの認証・署名検証、本番/PreviewのSecret参照分離、広い権限の既存bindingを照合してから切替を判断する。本書から「IAM隔離済み」「配備済みRulesを再取得済み」とは判定しない。

## 互換性・未実施事項

現在の既定Live PortalでCustomer PII変更が有効なら、新しい厳密なvalidatorはそのConfigurationを拒否する。専用の承認済みLive Configurationと本番設定を準備せず既存callableだけを配備すると、既存利用者の管理導線を停止する。今回は配備せず、旧500円契約を変更せずに事前準備と切替確認を別工程にする。

Customer全体の履歴に未知Price・別UID・壊れた期間/quantityがある場合、100件超で一覧が続く場合、古いUID metadataが本番resolverで確認できない場合も自動修復せず停止する。既存利用者の管理互換性は切替前に対象データの読取りで照合する。Portalの新規Session発行以外のStripe操作、実決済、実解約、Live Portal実機E2E、Rules/Functions/Hosting配備、IAM変更は未実施。

## ローカル検証結果

- strict TypeScript build：PASS。
- Portal合成試験：98/98 PASS。旧500円/新550円、既存割引維持、通常の未確認/欠損メールでも既存管理可・不正proof拒否、trial/active/past_due等、解約予約/終了/未知状態、別UID/削除/未対応Customer、Live/Test境界、欠損Configurationの外部呼出前拒否、PII/quantity/即時解約/retention機能拒否、固定return URL、例外の非公開化を確認。
- 現Rulesの専用Emulator：2/2 PASS、183アクセス操作（billing/root 18＋実namespace 11種×actor 3種×5操作）を確認。既存のcached Emulator/既存のlock済み依存だけを使用し、install/SDK更新なし。通常実行のloopback制限とJavaの日本語resource欠損は、許可されたローカル実行と`-Duser.language=en -Duser.country=US`で解消した。最終実行後にEmulatorを停止し、8297番の閉鎖まで確認。
