# 初回公開の通知とFlutter購入導線の範囲

更新日: 2026-11-21。今回はローカルの実装・既存検証記録を読んで範囲を整理した文書更新であり、メール機能の追加、Flutter変更、配備、送信、外部設定変更は行わない。個人のUID、宛先、確認リンク、トークン、秘密値は本書に記載しない。

## 1. 今回確定する方針

- 正式価格はHamCare プレミアム「月額550円」。過去の500円表示や税抜補助表示は、新規申込みの現行仕様として採用しない。旧Live Priceと既存契約は維持する。
- Firebase UIDを契約主体・Customer紐付け・権限確認の正本とする。確認済み通常メールとAppleの非公開リレーを連絡用メールとして認め、個人の実メールは必須にしない。Auth/providerともにメールがない場合だけ独立連絡先を補完し、確認済みになってから新規契約へ進む。
- Gmailによる本番の契約開始・請求・解約・重要通知の自動送信は未実装。今回は新しいメール機能を作らず、既存機能と不足を分けて記録する。Previewで1通届いた事実を本番通知の実装・運用確認へ読み替えない。
- **Relay実配送は初回公開の非ブロッキングとする。** 実配送未確認を理由に、新たな本人Relay宛先の取得、別アカウント作成、個人の実メール必須化を行わない。旧日付記録の「Relay配送確認を本番公開の条件とする」という判断は、この本人方針に置き換える。配送済み・返信可能・バウンスなしとは記録せず、本人所有の宛先が得られた際の改善・確認課題として残す。この変更は、一般向け本番送信基盤が実装済みであることを意味しない。
- **Flutterから新規購入・プラン追加へ通じる導線を削除する。** 現在の画面にある既存契約の解約・支払方法変更・請求履歴などの管理まで一括削除しない。Portal入口を残す場合も、既存契約管理に限定し、新規購入・プラン追加・再申込みへ通じる経路を残さない。

## 2. 通知の現状と不足

| 通知・連絡 | 現在の実装・証拠 | 不足・未確認 | 今回の扱い |
| --- | --- | --- | --- |
| Firebase Authメール確認 | `AuthScreen._sendVerificationIfNeeded` が新規ユーザーのメールあり・未確認時にFirebase標準確認メールを要求する。`lib/screens/auth.dart:106–115` | Relayへの実配送、Firebase側の現行テンプレート・送信設定は今回確認していない | 既存機能を保持。独立連絡先確認や契約成立通知へ転用したとは扱わない |
| Firebase Authパスワード再設定 | `sendPasswordResetEmail` を呼ぶ。`lib/screens/auth.dart:221–230` | Relay実配送、再設定メールの今回の実送信は未確認 | 既存機能を保持 |
| 独立連絡用メールの確認 | Preview専用Gmail APIで送信・確認する。既存記録では本人のメールなしAppleアカウントで1通受信し、同じUIDの確認完了を照合 | 一般ユーザー向け本番基盤、一般宛先への配送、Relay実配送は未実装・未確認 | Preview制限を維持。確認成功を契約成立や本番権限付与と混同しない |
| 契約開始・初回請求予定のHamCareメール | Web reviewに契約・請求予定を表示し、Webhookが課金状態を同期する。HamCareの自動メール送信処理は確認できない | 本番の送信元・対象イベント・宛先取得・重複防止・失敗時運用・本文が未実装 | 不足として残す。今回は新規実装しない |
| 継続請求・支払い失敗のHamCareメール | `functions/src/index.ts:783–792` は請求イベントから状態を更新。Previewは `subscription-sync.ts` が `invoice.paid` / `invoice.payment_failed` を同期 | HamCare自動送信処理は未実装。Stripe自身のメール有効化・宛先・到達は今回確認していない | Stripe請求イベントの同期と、通知メールの送信・到達を分ける |
| 解約予約・契約終了のHamCareメール | Portalによる既存管理、`customer.subscription.updated/deleted` の状態同期はある。`functions/src/index.ts:755–780` | 解約通知の自動送信、予約日時・利用終了日時を通知する本番運用は未実装 | Portalの管理結果とサーバー状態を正本にする。メール配送済みとはしない |
| 重要なお知らせ・サポート | 設定画面にサポート用mailtoがある。`lib/screens/settings.dart:516` | 自動重要通知基盤、Relay宛返信・到達・バウンス確認はない | サポート窓口と自動契約通知を区別。今回は自動化しない |
| Stripe領収書等 | 新規Preview Customer作成時は確認済み連絡先をemailに設定する。`preview-functions/src/engine.ts:66–79` | Stripeの送信設定・実配送は未確認。既存Customerのemailは独立連絡先の変更だけでは自動更新されない | 宛先同期設計がないまま、既存Customerにも新連絡先で届くと記載しない |

実装根拠: [Flutter Auth](../../lib/screens/auth.dart)、[本番課金Functions](../../functions/src/index.ts)、[Preview契約同期](../../preview-functions/src/subscription-sync.ts)、[Previewメール送信](../../preview-functions/src/billing-contact-mail.ts)。本番・PreviewのWebhookにあるのは状態同期であり、通知送信完了の記録ではない。

### 実際のPreview送信制限

`billing-contact-mail.ts:4–32` はPreview環境、固定送信元・Gmail mailbox、固定Preview確認URLに制限される。送信対象UIDと宛先は専用設定のハッシュ許可リストで照合し、既存検証では各1件だけを許可した。設定解析上の最大件数と、実際に許可した件数を混同しない。OAuthは送信権限だけを使用し、既存Googleログインの設定変更や代替送信元への切替を行わない。

アプリ側で60秒間隔、3回/時、5回/直近24時間/UID、全体10回/UTC日の送信予約を行う。UID側の実装はrolling windowであり、全体の日付単位の枠と区別する。配送が不明な場合に予約を戻さず、自動再送しない。`billing-contact.ts:152–159`、`billing-contact-http.ts:29–35`、`billing-contact-mail.ts:33–50`。これらはPreview用制限であり、一般向け本番通知の再送・監視・運用が用意されたことを意味しない。

## 3. 連絡先とUID一致の根拠

| 境界 | コードまたは既存証拠 | 保持する意味 |
| --- | --- | --- |
| Firebase認証とAdmin User | `authorizePreviewIdentity` は署名検証済みtoken UID＝Admin User UID、disabled、現在Apple provider subjectを照合。`preview-functions/src/auth-policy.ts:15–38` | メール文字列で本人や契約を特定しない |
| 連絡先保存先 | `createFirestoreBillingContactStore` はサーバーのidentity UIDをキーに `preview_billing_contacts/{uid}` を読み書き。`billing-contact-store.ts:5–19` | リクエスト本文のUIDや宛先で他人の保存先を選ばせない |
| 確認リンクの消費 | token hashはUID＋宛先＋tokenにbindingし、現在UIDの文書で確認。一度限り・15分。`billing-contact.ts:148,183–197` | 別UID、変更された宛先、再使用、期限切れでは確認できない |
| フロントでのアカウント変更 | `createBillingContactService` は開始時UID・user object・generationを応答時にも照合。`public/assets/billing-contact-service.mjs:14–34,60` | ログイン切替後に前アカウントの応答を採用しない |
| 新規契約との接続 | reviewとSession作成の両方で `verifiedContact` を呼び直す。CustomerはUIDハッシュmetadataで解決。`engine.ts:66–79,136–165` | 古い画面の確認済み表示だけで契約へ進めない。同じメールでも契約を統合しない |
| 合成・永続化テスト | `billing-contact.test.cjs:81–98,129–145`、`billing-contact-store.emulator.cjs:134–145` に別UID拒否、旧連絡先保持、同メール別UID非統合の検査がある | テストコードの存在と今回の再実行を分ける |
| 2026-11-19の本人実証 | リリース記録の「実Gmail配送・本人確認PASS」で、認証中の対象UIDと保存先UID一致、verified/source/verifiedAt、許可宛先一致、pending削除、使用済みhash1件、送信予約1件を照合。Auth/provider/UIDおよび本番4文書は不変 | 既存の1件限定の実配送・同一UID確認証拠として再利用。新たな実送信、Relay配送、本番契約への拡大はしない |

本人実証の正本: [戦略Cリリース記録](japan_store_payment_and_ios_readiness_20261018.md) の「2026-11-19 独立した確認済み連絡用メール（Preview限定）」節。本書には実UID・宛先・token/hash値を転載しない。

### 保存と削除の別残件

15分は確認リンクの使用期限であり、データの削除期限ではない。確認成功時にpendingを除去し、使用済みtoken hashを最大10件保持する。期限切れpendingの自動削除、独立連絡先・送信記録の保存期間、退会時の独立namespace削除、Gmail側の送信済みメール等の扱いは別途整合が必要である。現行退会処理はusers配下・switchbot_users・Authを削除するが、独立Preview連絡先を削除しない。`billing-contact.ts:194–197`、`functions/src/index.ts:2291–2304`。実装済みの削除連携とは記載しない。既存[Privacy改定案](../../public/privacy/index.html)もこの差を明記している。

## 4. Flutterで削除・保持する範囲（後続実装）

新規購入・プラン追加の削除は本人要望である。本書は対象を具体化するもので、Flutterコードは変更しない。購入先URLを別ページへ差し替えるだけでは完了とせず、アプリから新規申込みへ通じる導線を除く。既存契約の管理を選ぶ場合は、その目的だけに限定した入口・表示にする。

| ファイル・関数/Widget | 削除・変更する対象 | 保持する対象・境界 |
| --- | --- | --- |
| `lib/screens/subscription_plan_screen.dart` `_startCheckout`（93–145）、`_BillingStatusHeroCard.build` の未契約分岐（464–547） | `createStripeCheckoutSession` 呼出し、Checkout起動、登録ボタン、価格・自動更新説明を伴う新規購入案内とそれに専用の状態/配線 | `watchBillingStatus`、UID照合、読取り中・エラー表示を維持。既存契約状態の表示は購入案内と分ける |
| 同 `_openCustomerPortal`（147–194）、既存管理分岐（438–463） | 新規契約・プラン追加・再申込みに通じる機能があればその経路だけ除く | 既存契約の解約、支払方法変更、請求履歴確認の入口を一括削除しない。返却先とPortal機能が既存管理に限定されることを後続で確認 |
| `lib/screens/settings.dart` `_openPaidPlanPage`（608–613）、設定「利用プラン」（1017–1026） | 未契約者を購入画面へ送る共通入口・新規プラン勧誘の文言 | 必要な既存契約管理・利用状態確認へ再構成。未契約者向けのWeb購入リンクへ置換しない |
| 同 `_openPaidFeatureOrPlan`（541–588） | 「利用プランを見る」から新規購入へ送る分岐 | 権限確認、有料機能の利用不可説明、閉じる操作。支払問題がある既存契約者の管理は残せる |
| 同 アカウント削除前の管理案内（89–135） | 同じ購入画面へ到達する現状のルートを既存管理専用へ変更 | アカウント削除と契約解約が別である説明、既存契約の解約への到達性 |
| 同 アプリ内利用規約の有料プラン節（1461–1465） | 旧500円、新規Stripe申込みへの誘導を現行方針に整合 | 既存契約の自動更新・解約・利用終了等、利用者に必要な説明。今回の文書監査だけでアプリ表示反映済みとはしない |
| `lib/widgets/paid_feature_gate.dart` `_PaidFeatureLockedView._openPlanPage`（574–579）、既定primary action（621–624） | 新規購入画面へ送る既定ボタンと購入勧誘文言 | `PaidFeatureGate`の権限確認、読取り中/通信エラー/再試行、体験の開始・期限判定、対象機能の保護。無料体験開始ボタンまで一括削除しない |
| `lib/widgets/report_continuation_link.dart` `ReportContinuationLink`（5–16） | 「記録・分析を続けるプランを見る」と新規購入画面への遷移 | 生成済みレポートの閲覧・履歴。使用箇所は `legacy_first_report_body.dart:195` と `personality_report_screen.dart:436` |
| `lib/services/paid_feature_guard_service.dart` `ensureCanUsePaidFeature` / `_PaidFeatureDialog`（14–89） | 購入画面へのpushと「利用プランを見る」 | 権限判定、未利用状態・支払い要確認の案内、閉じる操作。既存管理を残す場合は別の管理目的へ限定 |
| `lib/screens/tabs.dart`、`search_function.dart`、`switchbot_setup.dart`、`lib/widgets/quick_record_sheet.dart` の `PaidFeatureGate` 呼出し | 共通Widget変更後も残る個別の購入勧誘文言・遷移があれば除く | 記録・変化・AI・SwitchBot・クイック記録自体、無料体験、既存の有料権限による利用 |

Portalについて、Flutter入口を残すことだけで「新規購入経路なし」と判断しない。既存ユーザーの管理先にプラン追加・再購入・変更による新規申込みの経路があれば、その範囲だけを閉じる設計とする。既存契約や本番Portal設定の実変更は、本書作成では行わない。

## 5. 起動・復帰と利用権限を維持する条件

購入UIの撤去と利用権限の同期は別である。Webでの契約状態をFirebase UIDで受け取り、購入ボタンを持たないFlutterでも起動・復帰後に正しい利用状態を表示できることを後続の受入条件とする。メール受信・メール文字列・ブラウザから戻った事実だけで有料権限を付与しない。

| 維持・確認する事項 | 現行の参照 | 後続での確認条件 |
| --- | --- | --- |
| 起動時の認証分岐 | `lib/main.dart:463–480` `_AuthGate` | 現在の認証UIDの状態へ進み、前ユーザーの権限を流用しない |
| UID別billingとサーバー確認 | `BillingStatusRepo._subscriptionDoc` / `watchBillingStatus` / `_watchServerDocument`（`lib/services/billing_status_repo.dart:26–38,62–75`） | キャッシュだけ・未確定ローカル書込みを権限確定に使わない。未確認を「未契約」に丸めない |
| UID切替時の再購読 | `PaidFeatureGate._bindRepo`（70–81）、`SubscriptionPlanScreen._bindRepo`（48–59） | ログアウト・別UIDログイン・遅れて届く旧UID応答で前ユーザーの権限を表示しない |
| 期間末と体験終了の境界 | `BillingStatus.canUsePaidFeaturesAt` / `isExpiredAt`（`lib/models/billing_status.dart:53,76–80`）、`_EntitlementExpiryTimer`（`paid_feature_gate.dart:342–359`） | 期限と同時に利用不可へ切替。元の体験終了日時・残回数を延長、再開始、リセットしない |
| 既存契約管理と機能利用の区別 | `BillingStatus.canManageSubscription`（46–47）、`test/billing_subscription_access_test.dart` | 支払問題・期間終了でも必要な管理を保ち、管理可能だからといって有料機能を開放しない |
| アプリ復帰・Web管理から戻った後 | 現行課金画面・共通ゲートのstream購読と再試行はある。一方、明示的な課金再取得を行う `AppLifecycleState.resumed` 処理は今回の読み取りで確認できない | 後続実装でサーバー状態の再確認・期限再評価を確認する。`tabs.dart:152–155` のresumedは日次記録更新であり、課金復帰確認済みの根拠にしない |

既存の回帰対象は [entitlement_race_test.dart](../../test/entitlement_race_test.dart) のキャッシュ・pending writes・読取りエラー・期限・UID切替・ログアウト、および [billing_subscription_access_test.dart](../../test/billing_subscription_access_test.dart) の既存管理と利用権限の区別である。今回これらは再実行しておらず、Flutter変更後の回帰PASS、購入導線撤去完了、起動・復帰の実機PASSは未取得とする。

## 6. 今回の変更境界

本書だけを作成する。実装・検証状態の正本への反映は親作業の `PROJECT_STATUS.md` 更新で管理する。Preview Gmailの一般化、新本番通知、連絡先保持削除の実装、Flutter購入導線撤去、Stripe/Firestore/Apple/Gmail/Hosting/Functions/ストア操作、送信、stage/commit/pushは本書作成では行わない。現状監査と後続実装範囲を区別し、過去のPASSを今回の新規検証として加算しない。
