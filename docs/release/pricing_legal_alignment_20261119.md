# 戦略C：料金・法務表示の整合監査（2026-11-19）

## 結論・適用範囲

正式方針は **HamCare プレミアム／月額550円（税込）**、補助表示は税抜500円・消費税10％。月額1種類のみ。専用 `feature/web-first-stripe-checkout`、承認済み開始点 `9e2b26ce36f577c683688f20b4bb4860d4e88aae` から表示と文書だけを更新した。本番切替や規約の最終承認を意味しない。

本番切替の設計・判断準備には進めるが、**本番切替・ストア提出可能とは判断しない**。返金方針、事業者表示、税務、保存・削除運用、実際の申込確定段階の法務表示、Flutter購入CTA撤去などが残る。

旧一時worktreeが存在しなかったため、承認コミットが残る同じ専用ブランチをプロジェクト内の `worktrees/hamcare-pricing-legal-20261119` に復元した。元アプリ作業ツリーと過去の記録は保護する。

## 1. 全件検索と分類

開始点の追跡1,067パスを対象に、指定語を大文字小文字の区別なく `rg --json` で検索。指定語は160ファイル・1,171行。タグで単位が分かれた価格と数値定数を補う単位なし500/550の追加97行を含め、**183ファイル・1,268行**を分類した。画像等のバイナリは本文検索対象外。1行に複数語があっても1件。

| 分類 | 行数 | 扱い |
|---|---:|---|
| A | 14 | 公開前の価格・名称・Web申込原稿を整合。履歴と混在する文書は旧本文を改変せず、最新の草案を分離して追記 |
| B | 5 | 税抜500円という補助表示・モデル値を保持 |
| C | 1,228 | Preview、旧Live、日付付き履歴、テストの拒否値、技術語、画像寸法・HTTP500等を保持。関連する現在のFAQ・説明は必要な文言だけ修正 |
| D | 21 | Flutterの旧価格・購入CTA。今回は変更せず後続作業へ |

台帳は [全件TSV](evidence/pricing-legal-20261119/price-reference-inventory.tsv)、[集計と曖昧5件](evidence/pricing-legal-20261119/price-reference-summary.json)。開始コミットに対するファイル・行番号・語・分類・理由だけを保存し、ソース本文や個人情報は転記していない。現在方針の追記後にも旧500円記録が残るのは意図したもの。

550円へ整合した主な対象はLP/FAQ、アカウントのプラン・契約確認・Portal説明、規約、特商法、サポート、提出用草案。税抜500円はLP、選択プラン、確認モデル、Portalモデルと法務の補助説明に残す。旧Live Price、テストの500円拒否ケース、過去の500円審査用契約は変更しない。

## 2. 請求・体験・更新・解約

| 現在の体験 | Test実装・表示 | 体験への影響 |
|---|---|---|
| 21日体験中 | 申込時カード登録、本日の請求0円、既存終了日時に初回550円 | 元の `endsAt` を `trial_end` に使用。延長・リセットなし |
| 終了済み | 本日の請求550円、支払成功・契約反映後に利用 | 新規体験なし |
| 未開始 | 本日の請求550円、支払成功・契約反映後に利用 | Web申込を理由とする21日付与なし |

根拠：`functions/src/previewCheckoutPolicy.ts:114–145` の既存分岐と `preview-functions/src/engine.ts:46,198`。APIへ金額を送らず許可plan keyから固定Priceを使い、Test/税込550/月次を確認する。今回ロジックは変更していない。

**例外**：現在のガードは体験残り **48時間＋1分未満** を拒否する（同policy:69–71,139）。体験延長や即時課金へ勝手に切り替えず、体験終了後の申込みを案内する。基本3ケースの確認を「すべての体験中の日時で申込可能」と拡大解釈しない。規約・特商法・FAQに間近の申込みができない場合の説明を加えた。ガードを変えるかは後続設計事項。

更新は **解約しない限り1か月ごと・次回以降も550円（税込）**。初回日・体験終了を基準にStripeが算出する実際の請求周期を使い、毎月の固定日を定めない。次回請求日はWebの契約管理画面で確認する。

解約はWebアカウント画面の「支払方法・請求・解約を管理する」からCustomer Portalへ。Test設定・Live既定設定とも `subscription_cancel.mode=at_period_end`、prorationなし。期間終了前に手続きを完了して次回更新を止め、即時解約にはしない。指定の次の文へ統一：

> 解約手続き後も、現在の契約期間が終了するまではHamCareプレミアムをご利用いただけます。

Test Portalは支払方法変更・請求履歴・期間末解約のみ。顧客メール変更・プラン変更は無効。Preview billingはUID単位で、解約予約・利用期限・次回請求を表示する。支払失敗時は実際の契約状態で判定し、独自の猶予日数を文面だけで追加しない。

## 3. Live StripeとPreviewの実差分

2026-11-19 20:59 JSTに専用Secretをメモリ内だけで読み、Stripe APIの **GETだけ** で実設定を照合した。最終スナップショットは8読取り（Price各1、Portal各1、Webhook一覧各1、Live Tax設定、直近Live Session1）。先行7件の再照合も含めGET計15回・変更0回。秘密キー・各識別子・顧客情報を報告へ転記しない。サニタイズ済み [読取り結果](evidence/pricing-legal-20261119/stripe-read-only-sanitized.json) を保存。

| 項目 | 現在のLive（変更なし） | Preview Test | 次の切替準備 |
|---|---|---|---|
| Product | Hamster Care Premium Plan、active、live | HamCare プレミアム（Previewテスト専用）、active、test | 公開名称を揃える設計。既存契約の商品は今回変更しない |
| Price | 500 JPY、month×1、active | 550 JPY、month×1、active | 別途承認後に本番用550円設計。既存500円Priceは変更・移行しない |
| `tax_behavior` | **exclusive** | **inclusive** | 550円総額を維持できる税設定の最終判断 |
| Automatic Tax | アカウントTax設定active、default exclusive。ただし直近Sessionは `enabled=false`、tax0、subtotal/total500、expired。現行作成コードもautomatic_tax未指定 | Session/Subscriptionともfalse、550円を固定、追加税0 | アカウント設定activeを全決済で自動税ONと混同しない。税込内訳・領収書・税務運用を確認 |
| Checkout | 既存hosted、promotion codes許可、元体験を渡す処理なし | embedded/日本語、cardsのみ、promotion無効、元trial_end | 新Webフローの本番接続は別作業。旧関数を550円フローと見なさない |
| Portal | default active。カード・請求履歴・期間末解約。**氏名・メール・住所・電話変更が有効**。プラン変更無効。default return空（Sessionで指定） | 専用active、顧客情報/プラン変更無効、カード・請求履歴・期間末解約、Preview return | 既定Portalの変更が既存契約へ及ぶ範囲を確認し、分離を含め設計 |
| Webhook | `stripeWebhook`、asia-northeast1、enabled、API `2026-05-27.dahlia` | `stripePreviewWebhook`、us-central1、enabled、API `2025-02-24.acacia` | イベント/API版/検証/同期の本番接続計画が必要。既存endpointは変更しない |
| 受信イベント | `checkout.session.completed`、`customer.subscription.updated/deleted`、`invoice.payment_failed/payment_succeeded` | `checkout.session.completed`、`customer.subscription.created/updated/deleted`、`invoice.paid/payment_failed` | `invoice.paid`と`payment_succeeded`を同一の既存設定と扱わない |
| Firestore | `users/{uid}/billing/subscription` | `preview_checkout_task4/{subjectHash}/billing/subscription`、連絡先は `preview_billing_contacts/{uid}` | 本番billing書込みは今回なし |

旧Testの `stripeWebhook` endpointはdisabledで残っている。削除・有効化はしない。直近Live Sessionは1件の観測であり、すべての既存請求や契約の税額を代表すると主張しない。Live顧客・Subscriptionの一覧は取得していない。

公開中の特商法等は旧「500円（税込）」で、Live Priceは500円 **exclusive**。この差を「現在のLiveは税込550円」と読み替えない。Test inclusive550は税を含む固定総額の検証であり、「Stripeが税50円を自動計算した」証拠ではない。

## 4. 返金：現状と本人確認用の候補

現行特商法は、支払い後の利用者都合の当期キャンセル・日割り返金を原則受け付けず、重複請求・決済誤り・法令上必要な返金はサポートへ、と記載。旧規約には独立した返金条項がなく、旧契約確認は「日割り返金は原則なし」という短縮形で例外が読み取りにくかった。Stripe Portalの期間末解約・prorationなし自体は、例外返金の実運用や法的方針を決めない。返金API・自動返金処理の追加もしていない。

今回、特商法の原文は保持。規約はその条件を参照し、契約確認の短縮形にも既存の例外案内を揃えた。**新しい法的返金方針を確定したものではなく、公開前の本人・必要に応じた法的確認が残る。**

- **候補A（既存記載の明確化）**：「支払い完了後の利用者都合による当該請求期間のキャンセル・日割り返金は原則として受け付けません。重複請求、決済上の誤り、法令上返金が必要な場合はサポートへご連絡ください。内容を確認して対応します。」
- **候補B（障害対応を追加）**：候補Aに「当社側の技術的な不具合によりサービスを提供できなかった場合の取扱いは、発生状況を確認してご案内します。」を加える。ただし対象障害・期間・算定・返答期限を決める必要がある。金額・日数を仮定して公開しない。

一律に法定の返金権を否定する文案や、物品売買の8日返品制度をこの役務にそのまま当てはめる案は採用しない。

## 5. 特商法の項目別点検（個人値を転記しない）

| 項目 | 現状・今回の扱い | 未確定点 |
|---|---|---|
| 販売事業者 | 氏名・住所・電話をまとめて請求に応じて開示する記載。内容はバイト不変 | 正式名を含む開示方法、購入判断前に遅滞なく渡せる実運用の確認 |
| 運営責任者 | 独立項目なし | 事業形態と必要な氏名表示を本人確認 |
| 所在地 | 上記の開示方式 | 公開/省略の要件・開示手順の確認 |
| 電話 | 上記の開示方式 | 確実に連絡できる窓口と代替表示運用の確認 |
| 問い合わせ | 既存サポートメールあり | 本番窓口の継続利用、重要通知/Relay配送 |
| 販売価格 | 改定案を月額550円（税込）、補助税抜500円へ | 税務最終確認。公開版・Liveは未変更 |
| 追加費用 | 通信費を利用者負担と記載 | 追加徴収の有無の本人最終確認 |
| 支払方法 | Stripe決済画面で利用できるカードを記載 | Live接続時に実際の支払手段と再照合 |
| 支払時期 | 体験3ケース・初回金額/時期・月次更新へ修正 | 残48時間＋1分未満ガードは後続判断 |
| 提供時期 | 契約通知の反映後に利用、遅延あり | 遅延時の提供期限・返金/サポート運用の具体化 |
| 自動更新 | 解約しない限り1か月ごと550円 | なし（本番設定は未切替） |
| 解約方法 | WebからPortalへ修正 | 本番Web接続前。既存管理は変更しない |
| 解約期限 | 現在期間終了前の手続完了と追記 | 実日時はPortal、独自の○日前なし |
| 返金 | 既存特商法原文を保持 | 上記候補A/B・法的確認 |
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
| 名称・料金・税抜補助・対象アカウント | 実HTML/モデルで表示 |
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

## 9. 本人判断が必要な事項

| 項目 | 現在/問題 | 候補・判断 | 影響 |
|---|---|---|---|
| 返金 | 原則なし、重複/誤請求/法令例外。障害時基準が未明示 | 候補Aの明確化、またはBの障害対応を加え範囲確定 | 特商法/規約/確認/サポート |
| 事業者情報 | 氏名・住所・電話の請求開示文言。責任者独立項目なし | 正式な事業者表示を公開するか、条件を満たす省略運用を確認。必要項目だけを本人の管理下で入力 | 特商法 |
| 税務 | 550総額方針は確定、Liveはexclusive500でTax設定とSessionが別 | 税務上の課税関係/税込内訳/証憑/自動税の最終扱いを確認 | Price/領収書/全料金表示 |
| サポート | 既存窓口あり、Relay宛て配送未検証 | 継続窓口・応答体制・代替解約支援を決める | 全法務/重要通知 |
| 保存・削除 | 独立連絡先等の保持期限/退会連携未確定 | 具体的期間・削除手順と本番送信基盤を承認して実装 | Privacy/サーバー/運用 |
| 提供遅延・契約条項 | 反映後に提供、遅延時具体対応未確定 | 提供期限/障害対応/返金との整合を確認 | 規約/特商法/確認 |

本人の住所・電話番号や秘密情報を回答してもらう必要はなく、判断した表示方法と項目を確認してから本人管理の経路で整える。

## 10. 検証・保護

- 今回の再実行：frontend443/443、Preview backend514/514、体験/Checkout policy91/91、**runtime計1,048件PASS**。TypeScript build PASS。LP84/account171/brand177＝静的432項目PASS。文言変更に関係する既存検査を更新し、カード入力部品を禁止する安全境界・認証フォーム/配色/素材の保護を維持。
- ローカル同一HTML/View/CSSと合成データで体験中/即時の確認を360/390/768/1280pxの8ケース、LP4幅、法務5ページ390pxの計17レイアウトで確認。横はみ出し0、モデルエラー0。表示用fixtureは外部通信/iframe/決済をCSPで禁止し、認証・見積り・Customer/Session/契約を作っていない。実Safari/Androidで今回変更を再試験したという記録にはしない。
- 関連7 HTMLのローカルリンク/素材75参照は解決し、個人事業者情報の段落は開始点と一致。既存公開法務4 URLとPreview accountはHEADで全てHTTP200。確認画像はプロジェクトの `artifacts/pricing-legal-20261119/checkout-trial-390.jpg`（合成データ、390×3182）へ保存。
- 過去のSafari Test550円決済/Webhook/Portal/期間末解約・後始末証拠、連絡先の両実機PASSを再利用。今回追加の実決済・メール送信・VoiceOver専用再検査なし。変更のないEmulator68/旧Stripe pure21を今回再実行件数へ足さない。
- **本番Stripe書込み0、本番Firestore billing書込み0、既存契約変更0、テスター権限変更0**。今回Firestore読書きAPI自体を呼ばず、StripeはGETだけ。Functions/Rules/Flutter/SDK/lock/Apple/ストア設定を変更せず、Hosting/Functions配備も行わない。既存Live Customer/Subscription/Price/Webhook Secretを保持。main merge/pushなし。

## 11. 次工程・残件

本人判断を得た法務の最終確定、対応OS/ブラウザの表示、申込確定段階の法務表示、連絡先の本番送信・Relay実配送・保持/削除、550円本番Price/Tax/Portal/イベント・API版の設計、Flutter CTA整理、未公開法務の配信手順と同じ版へのリンクを準備する。今回は調査・文面整合で停止し、Live設定作成/切替/既存契約移行を開始しない。

既存Preview：<https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account/>。今回の改定はローカル/コミットのみで、前回配信版を維持する。

## 公式資料（2026-11-19確認）

- [消費者庁：申込み段階の表示ガイドライン](https://www.no-trouble.caa.go.jp/what/mailorder/guidelines.html)：最終確認と訂正可能性。
- [消費者庁：通信販売広告Q&A Q15–20](https://www.no-trouble.caa.go.jp/qa/advertising.html)：氏名・住所・電話等の表示と、請求開示の実運用条件。法的適合の個別判断は別途。
- [消費者庁：通信販売広告の解説](https://www.no-trouble.caa.go.jp/what/mailorder/advertising.php)：販売条件、役務、動作環境。
- [国税庁：総額表示](https://www.nta.go.jp/taxes/shiraberu/taxanswer/shohi/6902.htm)：税込総額を主表示とする根拠。事業者自身の税務判断とは区別。
- [個人情報保護委員会：通則編](https://www.ppc.go.jp/personalinfo/legal/guidelines_tsusoku/)：利用目的、保存、安全管理、委託先等の確認。
- [Stripe：税の扱い](https://docs.stripe.com/tax/products-prices-tax-codes-tax-behavior)、[Checkout作成API](https://docs.stripe.com/api/checkout/sessions/create)、[期間末解約](https://docs.stripe.com/billing/subscriptions/cancel)：価格の税込/税別、automatic_tax、period-endの区別。
