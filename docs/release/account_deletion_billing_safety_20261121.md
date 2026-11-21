# アカウント削除前のStripe継続課金停止（2026-11-21）

開始点は承認済み `6e85a3c25640`、`feature/web-first-stripe-checkout` の同じ専用worktree、開始時clean。現在の有料契約者0人・無料テスターのみという運営者確認を前提とする。今回はコード・ローカル検証だけで、配備、実アカウント削除、Live Stripeアクセスを行わない。

## 既存処理と今回の変更

- FlutterはSettingsの削除確認、確認文字列、既存Callable名 `deleteMyAccountAndData` を維持。本人UIDのserver billingを確認して文面を選ぶ。無料には課金説明なし。有効/支払未解決/未確定契約には、登録情報・飼育記録の削除、自動請求停止、残期間の利用終了、原則日割り返金なしを表示する。明確な終了済み・未契約表示でもサーバーのStripe照合を省略する根拠にはしない。
- 有料説明を確認した場合だけ `stopBillingConfirmed:true` を送る。無料確認の後で実契約が見つかった場合は、サーバーが `paid_confirmation_required` で停止し、本人が改めて確認する。自動再送で同意を代用しない。UI二重押しを防ぎ、UID変更時に別アカウントを削除・ログアウトしない。`ok:true` だけを完了扱いにする。
- サーバーはCallableのFirebase認証UIDだけを使用し、クライアントUID/Customer/Subscription指定を受け付けない。既存の確認文字列と通常の `deleteAuthUser:true` を維持し、データだけの削除要求は拒否する。
- 既存の `createDeepDeleteStats` / `deleteCollectionDeep` / `deleteDocumentDeep` とanalytics・sensor削除フェンスを再利用。Firestore削除システムを作り直さない。アプリの暫定「有料なら拒否」は、有料説明＋サーバーの安全判定へ置き換える。

## 順序・所有者照合

1. `account_deletion_requests/{sha256(uid)}` をtransactionで予約する。任意の削除要求マーカーがあるUIDは新しいLive Checkout/Customerの予約へ進めない。対象は本番向けコードだけで、Preview UIや通常のPortal設定は変更しない。
2. 本人billing、`billing_customers/{hash}`、`billing_checkout_sessions/{hash}` を照合する。Stripeへの手掛かりがない無料アカウントでは、Secretを読まずStripeを生成・呼出しせず既存データ削除へ進む。21日体験は無料状態として保持する。
3. 手掛かりがある場合だけ既存Customerを読む。Customer metadata、各SubscriptionのUID/Customer/Price/modeと、保存済み対応を照合し、別UID・不明な設定・ページの続きあり・不明なCustomer作成操作は安全停止する。Customerは新規作成しない。将来の請求を作る未完了scheduleも自動処理せず運営確認とする。
4. Checkout実行中のleaseは待つ。作成結果不明のoperationは、Session有効期限＋余裕まで待ってから再照合する。本人のopen Sessionだけをexpireし、expiredを再取得確認する。期限切れ化と競合して支払いが完了した場合は、そのまま成功扱いにせず次の再試行で契約を再照合する。
5. Subscriptionを最新一覧から照合し、非終了状態を `subscriptions.cancel(id,{invoice_now:false,prorate:false})` で即時キャンセルする。active/trialing/期間末解約予約/past_due/unpaid/incomplete等を扱い、すでにcanceled/incomplete_expiredなら再キャンセルしない。個別retrieveと再度の一覧で全対象が終了状態になったことを確認する。返金・追加請求は作らない。
6. Stripe停止確認後に `billingStopped:true` を永続化し、その後だけ既存のデータ/Auth削除を実行する。Firebase側で失敗してもこの確認を保持し、再開時に新たなキャンセル・請求を行わない。
7. 完了時はマーカーをversion/status/completedAtだけに縮小し、UIDハッシュで引く削除済みフェンスを残す。これは匿名化の保証ではなく、再購入・遅延通知による復活を防ぐ最小の運用記録である。

## 請求書・会計記録

open/draft Invoiceは停止前にCustomer/Subscriptionの所有関係と決済中PaymentIntentの有無を調べ、停止後に `auto_advance=false`、次回決済予定なし、安全なPaymentIntent状態を確認する。判定できなければ `invoice_review` とし、Authを削除しない。請求書・Customer・支払い・pending invoice itemを削除せず、collect/pay/finalize/void/refundを実行しない。Stripe通常キャンセルによる自動回収停止と照合を使い、法定保存期間をこのタスクで決めない。通常のWeb解約は引き続き期間末解約。

[Stripe即時キャンセルAPI](https://docs.stripe.com/api/subscriptions/cancel) と [未処理Invoiceの扱い](https://docs.stripe.com/billing/subscriptions/cancel#handle-invoice-items-when-canceling-subscriptions) を確認した。StripeのAPI受付だけで停止完了とは扱わない。

## 再試行・運用確認

- 要求はrunning/retryable/manual_review/completedを保持し、11分lease（Function上限540秒より長い）で同時実行を排他。通信断・Functions中断でも要求を失わず、同じUIDの要求は既存処理へ合流する。
- `retryAccountDeletions` のコードを用意。15分ごと・最大instance1・batch4、1分から1時間までの指数backoff、最大12回。停止したworkerの期限切れleaseも回収する。自動再試行対象は既存の確認済み要求のみで、未同意の有料削除を作らない。
- 状態不明、UID不一致、請求書要確認、上限到達はmanual_review。ログは一般メッセージ/件数のみで、UID・メール・Token・Stripe応答やSecretを出さない。本人には処理中/再試行、または既存のお問い合わせへの案内を表示し、失敗を削除完了としない。
- **将来の配備条件**：専用Live設定/Secret、workerのIAM/Scheduler、実行時間を確認し、`Account deletion needs operator review` とworker失敗の監視通知を設定する。現在は未配備・監視通知も未作成。
- **運営の最低確認**：公開後は毎日、管理権限でmanual_review、古いrunning、期限を過ぎたretryable、Scheduler失敗を確認する。要求を消したり `billingStopped` を手動でtrueにして通さない。Stripeの本人Customer/Session/Subscription/InvoiceとFirebaseの失敗工程を照合し、原因を直した後だけ既存要求の再処理を承認する。12回上限の再キューは有人照合後に限りattempt/dueAt/statusを調整し、同意・停止確認・削除フェンスを保持する。本人へ完了/未完了を連絡する。

## 削除対象・保持対象

削除するのは本人の `users/{uid}` 配下（プロフィール・ペット・飼育記録・体験・billing等）、既存 `switchbot_users/{uid}` 配下、補完連絡先 `billing_contacts/{uid}`、固定ペット画像 `hamster_images/{uid}-main_pet.jpg`、Firebase Auth。画像削除は今回追加し404を許容する。画像削除失敗時にAuthを先に削除しない。他UIDの文書・画像は削除しない。

Stripe Customer/Subscription/Invoice等の会計記録は保持する。トップレベルの課金対応・Session調整情報・Webhook receipt・通知outboxは一括削除しない。これらの保持期間/アクセス権・未完了メール確認challengeの削除運用は公開前の保持方針へ接続する。ここで無条件に会計・運用証跡を消さない。

Appleログインの明示的な認可トークン失効処理は現行実装に存在せず、既存の [iOS準備文書](ios_runtime_preparation_stage2_20261018.md) でも残件。今回既存処理を削除/置換しておらず、新たなApple再認証フローは追加していない。Firebase Auth削除をApple認可失効と同一視しない。これは公開前に別途解消する。

## 遅延Webhook

Checkout排他は削除要求マーカーがあれば開始する。一方、Webhookの最終transactionは `billingStopped=true` またはcompletedだけでbilling/outbox書込みを抑止し、処理済みreceiptを返す。停止確認前の要求は撤回され得るため、通常同期を保ち、未同意で削除を中止したユーザーの支払通知を捨てない。判定後に削除フェンスが追加された競合も最終transactionで検知し、`ignored` としてACK。別UIDの同期は維持する。

## 検証結果

- Node22.23.1でstrict TypeScript build PASS。既存のNode18実行ファイルはローカル共有ライブラリ不足のため使わず、既存nvmのNode22を使用した。SDK/依存の更新・インストールなし。
- Web課金関連＋Stripe停止Mock：9ファイル504/504件PASS。active/trialing/解約予約/past_due/unpaid/incomplete/paused/canceled/incomplete_expired、停止確認失敗、API障害・再実行、Session失効、将来schedule、Invoiceの安全/不明、別UID、Checkout排他、Webhook書込み競合を含む。
- Firestore Emulator：専用demo・loopback18687で新規削除6件＋既存のsensor/observation/measurement削除3件、計9/9件PASS。既存tree walkを実DBで使い、Auth/Storage/Stripeは合成adapter。別UID保持、二重要求、キャンセル後Firebase失敗、worker再開/上限、Storage失敗でAuth維持を確認。
- Rules Emulator：専用demo・loopback8297で2/2件PASS。削除要求の新namespaceについても本人/別人/未認証からの読取り・書込み等を拒否。Rules本体変更なし。両Emulatorは停止済み。
- Flutter：既存関連25ファイル334/334件＋追加の360×640/キーボード300px試験1件PASS。合計335件。21日体験、entitlement、Settings/Drawer/利用状況の回帰、無料説明・有料説明・再同意・処理中/手動確認・完了・UID切替・二重押しを確認。静的解析は新規指摘なし、Settings既存activeColor非推奨info6件のみ。
- 以上850件の合格はローカルEmulator/Mockの証拠。Stripe Test APIを実際に呼んだ検証、iPhone/Android新ビルドの実機削除、Live配備後E2Eではない。既存Goldenのfont SHA制約は維持し、期待画像等を変えない。
- 本番Firestore/Stripe/Auth/Storage API呼出・書込み0、実アカウント削除0、既存契約/体験/外部テスター変更0、Functions/Hosting配備0、ストア変更0、main merge/push0。Web購入画面・通常のPortal・有料権限モデル・21日体験仕様は不変。

## 変更ファイル

本体9件：`functions/src/index.ts`、`functions/src/accountDeletion.ts`、`functions/src/accountDeletionBilling.ts`、`functions/src/webBillingRuntime.ts`、`functions/src/webBillingWebhook.ts`、`functions/src/webBillingWebhookStore.ts`、`lib/screens/settings.dart`、`lib/services/account_delete_service.dart`、`lib/services/account_deletion_guard.dart`。

試験8件：`functions/test/account_deletion_billing.test.cjs`、`functions/test/account_deletion_emulator.test.cjs`、`functions/test/web_billing_runtime.test.cjs`、`functions/test/web_billing_webhook.test.cjs`、`functions/test/web_billing_rules.emulator.test.cjs`、`test/account_deletion_guard_test.dart`、`test/settings_account_deletion_test.dart`、`test/strategy_c_deletion_boundary_test.dart`。

文書3件：`PROJECT_STATUS.md`、本書、`docs/release/web_billing_live_cutover_runbook_ja.md`。

既存analytics/sensorの削除フェンスは維持するが、このタスクで全機能の非同期producerや端末書込みを新しい削除フェンスへ統一したわけではない。

## 検証

- Stripe/課金/Checkout/Webhook関連Mock：9ファイル504件PASS（実Stripe接続なし、Live型fixtureは合成値だけ）。
- Firestore Emulator：新規削除6件＋既存の観測/計測/センサーの削除3件＝9件PASS。専用localhost:18687・demoプロジェクト。Auth/Storageは合成adapter、既存Firestore走査は実Emulatorで確認。別UIDは保持。
- 既存Rules：専用localhost:8297・demoプロジェクトで2件PASS。削除要求マーカーのクライアント読書き・改変も拒否。
- Flutter：関連25ファイル334件PASS＋小画面/キーボード1件PASS。無料/体験/終了済み/有料の表示、同意不足、状態変化、二重押し、認証切替、通信失敗、完了表示、権限/21日体験、購入リンク0を確認。
- TypeScript strict build PASS。変更Dartのanalyzeは新規指摘0、既存Settings activeColor非推奨info6件のみ。既知のfont SHA不一致があるカレンダーGoldenは今回の検証対象外で、期待画像/SDKを変更しない。新しい実機ビルドの確認ではない。

本番Stripe・Firestore/Auth/StorageへのAPIアクセス/書込み0、実ユーザー削除0、外部テスターへの影響0。Functions/Hosting配備0、新ビルド配信0、main merge/push0。依存/SDK/native設定/通常の21日体験・権限評価・Web UI・通常Portal設定は変更しない。
