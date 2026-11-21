# Flutter Customer Portal導線撤去（2026-11-21）

開始点は承認済み`d23820c42c4b`。同じ専用ブランチ・worktreeで実装し、本番・配信版は変更しない。

## 対象と撤去

- `feature/web-first-stripe-checkout`、既存専用worktreeで実施。開始時はclean。
- 運営者の今回の確認では**有料契約者0人、無料テスターのみ**。今回Stripe実データを照会して再確認したものではない。旧Live500円Priceの存在を契約者の存在と解釈しない。移行・互換処理を追加しない。
- `lib/screens/subscription_plan_screen.dart`：`createStripeCustomerPortalSession`、`portalUrl`、外部起動、処理中状態、契約管理ボタンを削除。画面は利用状況の読取りだけ。
- `lib/screens/settings.dart`：アカウント削除前の「プランを管理する」→利用状況→Portalと、「削除へ進む」の迂回を撤去。内蔵規約の「利用状況から管理できる」を、状態確認のみへ訂正。
- WebサイトのCustomer Portal、Functions、Webhook、課金設定は変更しない。正式公開後の契約管理は公式Webサイトへの独立アクセスで行う。

## 保持した機能とリンク

21日体験、明示的な体験開始、AI枠、有料権限モデル・Repo、UID切替監視、期限、再確認・復帰時の再読取りを維持。Web契約に基づく有料機能解放を変えない。設定・Drawer・利用状況は同じルートで到達する。iOS/Androidで共通のFlutter実装を使い、購入導線のplatform分岐は追加しない。

Flutterの外部起動は8箇所。AuthのTerms/Privacy、AI同意のPrivacy、SettingsのPrivacyとSupport mailto、利用状況のTerms/Privacy、AIのYouTube参照、研究DOI2箇所。リンク数ではなく`launchUrl`呼出箇所数である。購入・Portal・Web購入ルートは0件。法務のStripe説明、内部状態getter、未使用の計測定義、装飾のstripeは購入導線ではない。

## アカウント削除の暫定境界

既存サーバーは`functions/src/index.ts`の`deleteMyAccountAndData`で、認証UID・確認文字列を検証して`users/{uid}`配下とAuth等を削除する。Stripeでの継続請求停止を行わない。このサーバー処理と`lib/services/account_delete_service.dart`は今回変更しない。

`lib/services/account_deletion_guard.dart`を最小のアプリ側ガードとして追加。認証UIDと一致する`users/{uid}/billing/subscription`だけを`Source.server`で確認し、cache/pending write/取得失敗/UID切替では進まない。確認ダイアログの前後に再読取りする。

- 文書なし、空文書、契約なしの明示状態、Customer参照だけの状態は無料アカウントとして従来の削除へ進む。21日体験は別のfeature_accessパスなので有料契約と誤認しない。
- Subscription参照、paid plan、active/trialing/past_due/unpaid/incomplete/未知状態、解約予約等は削除を拒否する。既知Subscription参照が残るcanceledも暫定的に停止し、サーバー確認を次工程へ残す。
- 確認取消・誤入力では削除しない。Callableの`ok: true`を受け取るまで成功扱いにしない。失敗時にsignOutしない。要求中にUIDが変わった場合、新しいアカウントをsignOutしない。
- **このガードはStripe正本の不存在証明ではない。** 古いアプリ/直接Callable呼出、billing未同期、確認後の競合をサーバーで防ぐものではない。有料契約の安全な削除を完了したとは扱わない。

### 独立次タスクの最小範囲

1. `deleteMyAccountAndData`の認証UIDからCustomer/Subscriptionをサーバーで解決し、Stripe正本と所有者を照合する。メールやクライアント指定IDを正本にしない。
2. 削除要求と新規Checkout/Webhookの競合を止め、継続請求停止を確認してからAuth・データ削除へ進む。Stripe停止失敗/状態不明では削除せず、再実行を安全にする。
3. `billing_customers`、`billing_checkout_sessions`、`billing_contacts`、通知outboxとWebhookの扱い・必要な保持を、既存データ削除に接続する。解約予約だけで直ちに削除完了とせず、削除後の再作成や継続請求を防ぐ。
4. 無料削除、有効/解約予約/支払未解決、二重要求、Stripe失敗、Auth削除失敗、遅延Webhookの回帰を検証する。既存無料テスターの体験/権限は変更しない。

## 検証と保護

- 関連25ファイル**322/322件PASS**。利用状況28件・entitlement race37件、21日体験/権限/AI/記録/通知/レポート、実Home→Drawer→Settings→利用状況の明暗ナビゲーションを含む。利用状況は360px・文字2倍も確認。実機のiOS/Android新ビルド確認とは区別する。
- guard28件、Settingsの実画面＋既存Callable wrapper21件、既存境界16件を含む。無料状態の削除成功、取消・誤入力、二重押し、UID変更、確認中の契約状態変更、取得不能、サーバー失敗/`ok != true`を検証。
- 186 Dart、pubspec asset27指定・137ファイル（テキスト4）の共通スキャン5件PASS。購入/Portal/Web購入導線0件。画像全件のOCRは行っていない。
- 変更/追加9 Dartファイルのanalyzeは新規指摘0。Settingsの既存`activeColor`非推奨info6件のみ（`--no-fatal-infos`、exit0）。`git diff --check` PASS。
- 既存カレンダーGolden系列の固定font SHA不一致は前工程の環境制約として残る。期待画像・font helper・SHAを変更せず、対象導線は非Goldenナビゲーションで確認。Settingsの既知ListTile背景/ink診断だけを既存試験と同じ条件で限定捕捉し、その他の例外は検査する。

実アカウントの削除、Stripe/Firestore/Authの実API呼出、ネイティブ実機の再配信は行わない。既存の依存情報・キャッシュ済みFlutter3.47.7/Dart3.13.5を利用し、pub get/SDK更新なし。

Web/Functions/Preview/Live Stripe/本番billing/既存体験/テスター権限/Hosting/ストア/native設定/依存/SDK/バージョンは変更しない。main merge/push、新ビルド配信なし。初回の契約管理例外を記した[前工程の監査](flutter_strategy_c_cta_audit_20261121.md)は履歴として保持し、現状は本書を優先する。
