# 戦略C：料金・法務表示の整合監査（2026-11-19）

## 2026-11-21 初回公開方針の最終決定（この節を現在の正本とする）

価格・返金・解約・公開窓口・初回メール基盤は本人決定済み。価格は月額550円、旧Live500円/既存契約を保護し、後日承認後に新Live550円を新規申込だけへ接続する。返金候補A/B、バーチャルオフィス契約、新たなメールサービス選定を未決事項として再提起しない。申告・納税は別の事務事項で、表示分岐や公開条件にしない。

返金の正式文は「利用者都合による支払済み料金の返金は原則として行いません。ただし、重複課金、当方のシステムによる誤請求、その他法令上返金が必要となる場合は個別に対応します。」。解約はPortalで期間末、即時なし・日割り返金なし。「解約手続き後も、現在の契約期間が終了するまではHamCareプレミアムをご利用いただけます。」を返金とは別に案内する。

特商法は請求開示方式を採用し、消費者庁Q15/Q17の条件を照合した。購入判断前に十分な余裕をもつ書面/メール開示、実際に開示できる措置が必要。文面を用意した事実と実開示体制の確認を分ける。窓口は既存Gmail、差出人のブランドを維持し、本人の個人値は転記しない。[開示運用](commercial_disclosure_operations_20261121.md)を参照。

Firebaseは認証メール、Gmail APIは初回の連絡先確認と重要な契約/サポート通知に採用。Stripeメールは補助。Gmail本番通知の不足、送信状態・重複防止・429/再試行/指数バックオフ・バウンス・非公開ログの要件は[通知とFlutter範囲](launch_notifications_and_flutter_scope_20261121.md)と[Runbook](web_billing_live_cutover_runbook_ja.md)に記録し、今回メール機能を実装しない。独自ドメイン/Resend等は将来検討のみ。

Relay2送信元登録・SPF・両ドメイン対応の証拠は維持する。実Relay配送は未確認・非ブロッキング。本人の宛先確保後、本番前又は公開直後に確認する。個人実メールを必須にしない。連絡先補完はUID正本・通常/Relay確認済み・本当にメールなしだけ補完・確認前の新規契約拒否という既存Preview実装と一致する。

今回、規約/特商法/FAQ/最終確認等の未公開文面と表示文字列を整合した。公開済みサイト、Stripe、Flutter、ストア設定、通知処理は変更していない。GOは方針/既存証拠であり、本番実行は未承認・未実行。正確な19項目の状態と指定26工程は[Runbook](web_billing_live_cutover_runbook_ja.md)を正本とする。


## 2026-11-21 料金表示更新の履歴（4aeab766f90e時点）

ユーザー向け正式価格は **月額550円** に固定する。Preview／本番Web／Stripe Test／Stripe Live／利用規約／特商法で、この表示と最終請求額550円を正本とする。税抜500円の補助表示や、事業者の税務上の区分による表示分岐は採用しない。申告・納税上の扱いは別のバックオフィス事項として管理し、料金UXやリリースRunbookの判断条件にしない。

旧Live500円Priceと既存契約は保持し、直接変更・削除・一括移行しない。別途承認を得た本番切替工程で **新しい月額550円Live Priceを作成し、新規申込だけを接続する**。Test Priceは550円を維持する。今回は本番Price作成・Stripe設定変更を行わない。

この方針を [料金に関する本番切替Runbook案](web_billing_live_cutover_runbook_ja.md) に反映した。以下の11月19日監査値・分類台帳・検証記録は履歴として保持する。既存HTML／JavaScript／掲載用txtの表記反映は後続作業であり、今回は更新・配備していない。

## 結論・適用範囲

正式方針は **HamCare プレミアム／月額550円**。月額1種類で、Stripeの最終請求額550円を正本とする。11月19日は専用 `feature/web-first-stripe-checkout`、承認済み開始点 `9e2b26ce36f577c683688f20b4bb4860d4e88aae` から表示と文書を更新した。11月21日の先行コミット4aeab766f90eは料金方針の文書更新だけである。今回の最終化は正式返金・解約・開示方式等を未公開文面と表示文字列へ反映し、本番切替は行わない。

本番切替の設計・判断準備には進めるが、**本番切替・ストア提出可能とは判断しない**。返金・解約・窓口・メール採用方針は決定済み。請求開示の実体制、本番の通知/保持削除/API、最終申込表示、Flutter購入CTA撤去等の実装・確認は残る。税務上の区分確認はこの判断条件に含めない。

旧一時worktreeが存在しなかったため、承認コミットが残る同じ専用ブランチをプロジェクト内の `worktrees/hamcare-pricing-legal-20261119` に復元した。元アプリ作業ツリーと過去の記録は保護する。

## 1. 2026-11-19時点の全件検索と分類（監査履歴）

開始点の追跡1,067パスを対象に、指定語を大文字小文字の区別なく `rg --json` で検索。指定語は160ファイル・1,171行。タグで単位が分かれた価格と数値定数を補う単位なし500/550の追加97行を含め、**183ファイル・1,268行**を分類した。画像等のバイナリは本文検索対象外。1行に複数語があっても1件。

| 分類 | 行数 | 扱い |
|---|---:|---|
| A | 14 | 公開前の価格・名称・Web申込原稿を整合。履歴と混在する文書は旧本文を改変せず、最新の草案を分離して追記 |
| B | 5 | 税抜500円という補助表示・モデル値を保持 |
| C | 1,228 | Preview、旧Live、日付付き履歴、テストの拒否値、技術語、画像寸法・HTTP500等を保持。関連する現在のFAQ・説明は必要な文言だけ修正 |
| D | 21 | Flutterの旧価格・購入CTA。今回は変更せず後続作業へ |

台帳は [全件TSV](evidence/pricing-legal-20261119/price-reference-inventory.tsv)、[集計と曖昧5件](evidence/pricing-legal-20261119/price-reference-summary.json)。開始コミットに対するファイル・行番号・語・分類・理由だけを保存し、ソース本文や個人情報は転記していない。現在方針の追記後にも旧500円記録が残るのは意図したもの。

11月19日に550円へ整合した主な対象はLP/FAQ、アカウントのプラン・契約確認・Portal説明、規約、特商法、サポート、提出用草案。当時は税抜500円を補助表示として残したため、上表B分類と台帳はその監査結果を保持する。11月21日以降の正式表示は「月額550円」であり、税抜補助を残すという旧方針は採用しない。旧Live Price、テストの500円拒否ケース、過去の500円審査用契約は変更しない。

## 2. 請求・体験・更新・解約

| 現在の体験 | Test実装・表示 | 体験への影響 |
|---|---|---|
| 21日体験中 | 申込時カード登録、本日の請求0円、既存終了日時に初回550円 | 元の `endsAt` を `trial_end` に使用。延長・リセットなし |
| 終了済み | 本日の請求550円、支払成功・契約反映後に利用 | 新規体験なし |
| 未開始 | 本日の請求550円、支払成功・契約反映後に利用 | Web申込を理由とする21日付与なし |

根拠：`functions/src/previewCheckoutPolicy.ts:114–145` の既存分岐と `preview-functions/src/engine.ts:46,198`。APIへ金額を送らず許可plan keyから固定Priceを使い、Test/総額550円/月次を確認する。ロジックは変更していない。

**例外**：現在のガードは体験残り **48時間＋1分未満** を拒否する（同policy:69–71,139）。体験延長や即時課金へ勝手に切り替えず、体験終了後の申込みを案内する。基本3ケースの確認を「すべての体験中の日時で申込可能」と拡大解釈しない。規約・特商法・FAQに間近の申込みができない場合の説明を加えた。ガードを変えるかは後続設計事項。

更新は **解約しない限り1か月ごと・次回以降も550円**。初回日・体験終了を基準にStripeが算出する実際の請求周期を使い、毎月の固定日を定めない。次回請求日はWebの契約管理画面で確認する。

解約はWebアカウント画面の「支払方法・請求・解約を管理する」からCustomer Portalへ。Test設定・Live既定設定とも `subscription_cancel.mode=at_period_end`、prorationなし。期間終了前に手続きを完了して次回更新を止め、即時解約にはしない。指定の次の文へ統一：

> 解約手続き後も、現在の契約期間が終了するまではHamCareプレミアムをご利用いただけます。

Test Portalは支払方法変更・請求履歴・期間末解約のみ。顧客メール変更・プラン変更は無効。Preview billingはUID単位で、解約予約・利用期限・次回請求を表示する。支払失敗時は実際の契約状態で判定し、独自の猶予日数を文面だけで追加しない。

## 3. 2026-11-19読取り時点のLive StripeとPreviewの実差分

2026-11-19 20:59 JSTに専用Secretをメモリ内だけで読み、Stripe APIの **GETだけ** で実設定を照合した。最終スナップショットは8読取り（Price各1、Portal各1、Webhook一覧各1、Live Tax設定、直近Live Session1）。先行7件の再照合も含めGET計15回・変更0回。秘密キー・各識別子・顧客情報を報告へ転記しない。サニタイズ済み [読取り結果](evidence/pricing-legal-20261119/stripe-read-only-sanitized.json) を保存。

| 項目 | 現在のLive（変更なし） | Preview Test | 次の切替準備 |
|---|---|---|---|
| Product | Hamster Care Premium Plan、active、live | HamCare プレミアム（Previewテスト専用）、active、test | 公開名称を揃える設計。既存契約の商品は今回変更しない |
| Price | 500 JPY、month×1、active | 550 JPY、month×1、active | 別途承認後に新Live550円Priceを作成し、新規申込だけへ接続。旧500円Price/契約は変更・削除・移行しない |
| `tax_behavior` | **exclusive** | **inclusive** | 内部設定の観測差として保持。切替時は最終請求額550円を検証し、表示分岐は作らない |
| Automatic Tax | アカウントTax設定active、default exclusive。ただし直近Sessionは `enabled=false`、tax0、subtotal/total500、expired。現行作成コードもautomatic_tax未指定 | Session/Subscriptionともfalse、550円を固定、追加税0 | アカウント設定activeを全決済で自動税ONと混同しない。追加計算で請求額が550円を超えないことを技術的に確認 |
| Checkout | 既存hosted、promotion codes許可、元体験を渡す処理なし | embedded/日本語、cardsのみ、promotion無効、元trial_end | 新Webフローの本番接続は別作業。旧関数を550円フローと見なさない |
| Portal | default active。カード・請求履歴・期間末解約。**氏名・メール・住所・電話変更が有効**。プラン変更無効。default return空（Sessionで指定） | 専用active、顧客情報/プラン変更無効、カード・請求履歴・期間末解約、Preview return | 既定Portalの変更が既存契約へ及ぶ範囲を確認し、分離を含め設計 |
| Webhook | `stripeWebhook`、asia-northeast1、enabled、API `2026-05-27.dahlia` | `stripePreviewWebhook`、us-central1、enabled、API `2025-02-24.acacia` | イベント/API版/検証/同期の本番接続計画が必要。既存endpointは変更しない |
| 受信イベント | `checkout.session.completed`、`customer.subscription.updated/deleted`、`invoice.payment_failed/payment_succeeded` | `checkout.session.completed`、`customer.subscription.created/updated/deleted`、`invoice.paid/payment_failed` | `invoice.paid`と`payment_succeeded`を同一の既存設定と扱わない |
| Firestore | `users/{uid}/billing/subscription` | `preview_checkout_task4/{subjectHash}/billing/subscription`、連絡先は `preview_billing_contacts/{uid}` | 本番billing書込みは今回なし |

旧Testの `stripeWebhook` endpointはdisabledで残っている。削除・有効化はしない。直近Live Sessionは1件の観測であり、すべての既存請求や契約の税額を代表すると主張しない。Live顧客・Subscriptionの一覧は取得していない。

公開中の特商法等は旧「500円（税込）」で、Live Priceは500円 **exclusive**。この差を「現在のLiveは税込550円」と読み替えない。Test inclusive550は税を含む固定総額の検証であり、「Stripeが税50円を自動計算した」証拠ではない。

## 4. 返金・解約の最終方針

上の正式返金文を、規約・特商法・最終確認・FAQの未公開文面へ同じ意味で反映した。以前の候補A/Bと本人判断待ちは終了する。運用の例外を勝手に拡張せず、重複課金、当方システムの誤請求、法令上必要な返金を個別対応する。一般の解約予約は返金操作ではなく、期間末で終了して次回以降の請求を止める。利用者都合の日割り返金は行わない。今回、返金API・通知機能・本番設定は変更しない。

## 5. 特商法の項目別点検（個人値を転記しない）

| 項目 | 現状・今回の扱い | 未確定点 |
|---|---|---|
| 販売事業者 | 請求開示方式を正式採用し、提供方法・購入前の提供・窓口を未公開HTMLへ追記 | 個人値は非公開で管理し、遅滞ない実開示体制だけ本人確認 |
| 運営責任者 | 独立項目なし | 事業形態と必要な氏名表示を本人確認 |
| 所在地 | 上記の開示方式 | 公開/省略の要件・開示手順の確認 |
| 電話 | 上記の開示方式 | 確実に連絡できる窓口と代替表示運用の確認 |
| 問い合わせ | 既存Gmailを公開窓口として正式採用 | ブランド差出人を維持。Relay実配送未確認は非ブロッキング |
| 販売価格 | 今後の正式表示は月額550円、最終請求額550円 | HTML改定案へ反映済み。公開版・Liveは未変更 |
| 追加費用 | 通信費を利用者負担と記載 | 追加徴収の有無の本人最終確認 |
| 支払方法 | Stripe決済画面で利用できるカードを記載 | Live接続時に実際の支払手段と再照合 |
| 支払時期 | 体験3ケース・初回金額/時期・月次更新へ修正 | 残48時間＋1分未満ガードは後続判断 |
| 提供時期 | 契約通知の反映後に利用、遅延あり | 遅延時の提供期限・返金/サポート運用の具体化 |
| 自動更新 | 解約しない限り1か月ごと550円 | なし（本番設定は未切替） |
| 解約方法 | WebからPortalへ修正 | 本番Web接続前。既存管理は変更しない |
| 解約期限 | 現在期間終了前の手続完了と追記 | 実日時はPortal、独自の○日前なし |
| 返金 | 正式文を規約・特商法・最終確認・FAQで統一 | 方針GO。公開/運用実装は別工程 |
| 動作環境 | iOS/Android/ネット/アカウント、機器依存の記載あり | 公開対象アプリ/ブラウザの最小対応版を確定して追記 |

申込期間は既存の「定めなし」を保持。事業者の個人値は監査台帳、差分出力、チャットへ転記しない。氏名・住所・電話等の表示省略が直ちに適法と断定せず、請求に応じる旨の文言だけで十分とも判断しない。

## 6. 規約・Privacy・サポートの変更

- 規約はアプリ/公式Webへ適用、正式名/550円、Web申込、体験3ケース、元期限の維持、月次更新、Portal、期間末解約、返金参照、支払失敗・期間終了時の利用を整理。変更・中断・終了の既存条項は保持。
- PrivacyはFirebase UIDを契約の正本とし、Auth確認済みメール、Appleリレー、未設定時だけ独立した確認済み連絡先を扱う。実メールを必須にせず、メールで権限付与/顧客紐付け/統合をしない。独立連絡先をAuthへ逆同期しない。
- 連絡先用途は契約確認・請求・解約・重要通知・サポート。広告に利用しない。Stripe Customer/Subscription、契約/請求履歴、確認状態/トークンハッシュ/配送・送信制限情報を明記。カード番号・有効期限・CVCはStripe入力欄内だけで扱い、HamCareは受け取り・保存しない。
- Preview Gmailは本人限定。Google/Stripe等を一律に委託と断定する旧表現を改め、契約実態・国外処理・保持の確認を残す。既存AI/Analytics説明は保持。
- 15分はリンクの使用期限。確認成功でpendingを除去し使用済みhash最大10件。**期限切れpendingの自動削除、独立root連絡先の退会時削除連携、具体的保存期間は未確定**。コード上の未実装と外部TTL未照会を区別する。Privacyに15分でデータが消える等の未実証な約束を追加しない。
- サポートとアカウント削除の契約管理案内もWeb/Portalへ整合。削除で自動解約されると案内しない。メール文字列だけで契約を特定しない。

## 7. 契約確認と申込み確定段階

| 確認項目 | 今回の確認 |
|---|---|
| 名称・料金・対象アカウント | 11月19日時点の実HTML/モデルで550円と旧税抜補助を確認。正式表示「月額550円」への実装反映は後続 |
| 本日0/550・初回日/550 | 元trial終了日時と即時をモデル分岐。別項目で日時と金額を表示し、説明で本日を明示 |
| 月次更新・以後550・期限 | 文字列を統一。日時はサーバーからの実値 |
| 解約/返金/提供開始 | 指定の期間末解約文と既存返金案の例外、通知反映後の利用を表示 |
| 法務/問い合わせ | 4リンクあり。現在はLive公開文書へのリンクで旧500円条件のため差異注意を保持 |
| カード情報 | Stripeのみ処理する説明。独自カード入力欄なし |

**残件**：`firebase.preview.json` は法務5ページを配信対象から除外している。今回の法務改定案をリンク先で公開したと装わない。今回はPreviewデプロイもliveデプロイも0。リンクを相対化して壊す変更は行わない。承認後に新料金と同じ版の法務を配信・接続する工程が必要。

また独自確認画面の次には、実際の申込確定ボタンがあるStripe Embedded Checkoutがある。今回のローカル確認だけで、その**最終確定段階**まで法的表示・訂正可能性が揃ったとは判断しない。継続して見える説明/配置とStripe側最終表示を、法務文案確定後にテスト環境で再照合する。これは消費者庁資料を踏まえた実装上の推論であり、適法性を断定するものではない。

## 8. 審査文案

`store_review_notes_ja.md`、`store_listing_ja.md`、Google Play提出手順の先頭に最新草案を追加し、旧保存履歴は保持。ストア用txtの文案も更新し、metadata READMEで「未提出・現行Flutter CTA撤去待ち」を明示した。Consoleへ転記・提出はしていない。

Appleはアプリ内購入/外部購入CTAなし、Web購入はアプリ外開始、契約済みユーザーはログインして利用する将来版。21日体験、Case22954972のscope外回答、Case103009817213の「回答済み：事前承認なし。実提出後に審査判断」を正確に区別する。GoogleもYouTube/Webなどアプリ外で購入開始・契約済み権限を利用する将来版。

**現行Flutterには旧500円・外部Checkout CTAが存在する。まだ提出不可。** 後続対象は `subscription_plan_screen.dart`（`_startCheckout`/登録ボタン/価格）、`settings.dart`（設定/有料ダイアログ/内部規約）、`paid_feature_gate.dart`、`paid_feature_guard_service.dart`、`report_continuation_link.dart`。購入誘導の撤去と既存契約管理/権限ガードの維持を分けて設計する。

## 9. 決定済み方針と残る実作業

価格、返金、期間末解約、Gmail公開窓口、Firebase/Gmail API採用、請求開示方式、バーチャルオフィス不要、将来メール基盤の非ブロッキング化は決定済み。これらを再度選定待ちにしない。

残る実作業は、本番用API/署名Webhook/通常権限同期/制限されたPortal/送信基盤、保存期間・期限切れ/退会時削除連携、開示運用の実体制、最終申込段階の表示、Flutter購入CTA撤去、ビルド・実機確認・提出である。既存PreviewのTestガードを解除して本番化しない。Relay実配送未確認だけで準備を止めない。Go/No-Goと実行順はRunbookを参照する。

申告・納税・帳簿等は別の事務事項として管理し、価格やリリースの可否を変える条件にしない。

## 10. 11月19日の検証・保護（履歴）

- 今回の再実行：frontend443/443、Preview backend514/514、体験/Checkout policy91/91、**runtime計1,048件PASS**。TypeScript build PASS。LP84/account171/brand177＝静的432項目PASS。文言変更に関係する既存検査を更新し、カード入力部品を禁止する安全境界・認証フォーム/配色/素材の保護を維持。
- ローカル同一HTML/View/CSSと合成データで体験中/即時の確認を360/390/768/1280pxの8ケース、LP4幅、法務5ページ390pxの計17レイアウトで確認。横はみ出し0、モデルエラー0。表示用fixtureは外部通信/iframe/決済をCSPで禁止し、認証・見積り・Customer/Session/契約を作っていない。実Safari/Androidで今回変更を再試験したという記録にはしない。
- 関連7 HTMLのローカルリンク/素材75参照は解決し、個人事業者情報の段落は開始点と一致。既存公開法務4 URLとPreview accountはHEADで全てHTTP200。確認画像はプロジェクトの `artifacts/pricing-legal-20261119/checkout-trial-390.jpg`（合成データ、390×3182）へ保存。
- 過去のSafari Test550円決済/Webhook/Portal/期間末解約・後始末証拠、連絡先の両実機PASSを再利用。今回追加の実決済・メール送信・VoiceOver専用再検査なし。変更のないEmulator68/旧Stripe pure21を今回再実行件数へ足さない。
- **本番Stripe書込み0、本番Firestore billing書込み0、既存契約変更0、テスター権限変更0**。今回Firestore読書きAPI自体を呼ばず、StripeはGETだけ。Functions/Rules/Flutter/SDK/lock/Apple/ストア設定を変更せず、Hosting/Functions配備も行わない。既存Live Customer/Subscription/Price/Webhook Secretを保持。main merge/pushなし。

## 11. 次工程・残件

決定済み法務文面の公開準備、対応OS/ブラウザと申込確定段階の表示、本番送信・保持削除/API/Portal/イベントの実装、Flutter CTA整理を準備する。Relay実配送は本人宛先が用意できた時点の非ブロッキング残件とする。料金表示は「月額550円」、別途承認後に新Live550円Priceを作成して新規申込を接続し、旧500円Priceと既存契約は保持する。Test Priceは550円を維持する。[切替Runbook案](web_billing_live_cutover_runbook_ja.md)に沿った実行は別承認後で、今回は文書更新で停止する。

既存Preview：<https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account/>。今回の改定はローカル/コミットのみで、前回配信版を維持する。

## 公式資料（2026-11-19確認）

- [消費者庁：申込み段階の表示ガイドライン](https://www.no-trouble.caa.go.jp/what/mailorder/guidelines.html)：最終確認と訂正可能性。
- [消費者庁：通信販売広告Q&A Q15–20](https://www.no-trouble.caa.go.jp/qa/advertising.html)：氏名・住所・電話等の表示と、請求開示の実運用条件。法的適合の個別判断は別途。
- [消費者庁：通信販売広告の解説](https://www.no-trouble.caa.go.jp/what/mailorder/advertising.php)：販売条件、役務、動作環境。
- [国税庁：総額表示](https://www.nta.go.jp/taxes/shiraberu/taxanswer/shohi/6902.htm)：税込総額を主表示とする根拠。事業者自身の税務判断とは区別。
- [個人情報保護委員会：通則編](https://www.ppc.go.jp/personalinfo/legal/guidelines_tsusoku/)：利用目的、保存、安全管理、委託先等の確認。
- [Stripe：税の扱い](https://docs.stripe.com/tax/products-prices-tax-codes-tax-behavior)、[Checkout作成API](https://docs.stripe.com/api/checkout/sessions/create)、[期間末解約](https://docs.stripe.com/billing/subscriptions/cancel)：価格の税込/税別、automatic_tax、period-endの区別。
