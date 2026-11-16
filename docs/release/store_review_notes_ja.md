# Hamster Care 審査メモ（日本向け初回提出）

<!-- hamcare-private-relay-audit-20261116:start -->
## 2026-11-16 Apple Private Email Relay：送信元2件登録済み／配送は本人用宛先待ち

- **方針の保存**：`0d761c3f1876`（`docs(release): record contact email and accessibility policy`）で、指定4文書だけを保存。旧一時worktreeが存在しなかったため、コミット済み `f66f019052ad` と同じ専用ブランチから `/private/tmp/hamcare-web-relay-20261116` を復元し、失われた未コミット差分そのものを回収済みとはせず、本人の確定指示から方針を反映した。元アプリのdirty／未追跡素材は作業対象外。
- **Apple登録の実結果**：本人の確定直前承認後、個別送信元 `noreply@hamster-breeding-app.firebaseapp.com` と `gotainu@gmail.com` の2件を登録。`Email Source Registration Complete` の2アドレス／0ドメインと、その後の一覧で両方の緑SPFチェックを確認。初回はセッション期限切れで未登録、再読込後に同じ承認済み2件だけを登録した。`gmail.com`／`stripe.com`等の第三者ドメイン全体、未使用ドメインは登録せず、既存登録の削除・App ID／Service ID／Key・DNS変更0。
- **配送を止めた理由**：本人から「今はない」と回答があり、本人所有のAppleリレー配送先がない。前回のApple E2EはAuthメール未設定であり、Relayありのユーザーと混同しない。Firebase／サポート／Stripeの今回メール送信は0通、転送・迷惑メール・返信・バウンスは未検証で、配送PASS・バウンスなしとは記録しない。他ユーザー、新規本番アカウント、架空のRelay宛先、Appleへのパスワード方式追加で代替しない。
- **コード・限定検証**：両Relayドメインは現行の表示／認証設計で受理可能。`account-model.mjs:maskEmail`／`checkout-model.mjs:projectCheckoutReview` に旧ドメインだけのallowlistはなく、`account-identity.mjs:projectAccountIdentity`／`auth-policy.ts:authorizePreviewIdentity` は署名検証済みFirebase UIDと現在Apple provider subject一致を正本にする。`privaterelay.appleid.com`／`private.icloud.com`各4項目（表示・review、正規Apple、別UID拒否、binding欠損拒否）の合成8チェックPASS。既存account-model／account-identity／checkout-model計82件PASS。既存Node22を使用しSDK・依存更新0、コード差分0。ドメインだけでメール確認済み・認証済みとは判定しない。
- **保護・Preview**：既存Preview `/account/` HTTP200／no-storeを確認し、デプロイ0。今回本番Stripe／Customer／Subscription／Firestore billing／既存契約／Authユーザー／体験／テスター権限の変更0、Stripe Test書込み0、Flutter／live Hosting／購入CTA／main merge・push・ストア操作0。Apple送信元登録だけが外部設定変更。メール未設定の本人Preview購入ガード・UID正本は保持。
- **判断・次工程**：送信元登録は完了、実配送は未完了で本番公開前の残件。連絡用メール補完フローの設計・独立Preview実装へは別承認で進められるが、今回実装しない。VoiceOver追加対応は非ブロッキングのまま。実配送を未確認のまま本番切替準備完了／公開可とは判断しない。詳細な送信元・代替設計・根拠は[戦略Cリリース記録](japan_store_payment_and_ios_readiness_20261018.md#relay-sender-inventory-20261116)を参照。
<!-- hamcare-private-relay-audit-20261116:end -->

<!-- hamcare-contact-accessibility-policy-20261116:start -->
## 2026-11-16 戦略C・本番切替前の確定方針

本節を現在の方針とし、以下の旧日付節にある「回答待ち」や追加実機確認の記載は当時の履歴として保持する。

- **VoiceOver**：専用の追加実機確認、読み上げ順の調整、反映待ち／契約管理ボタンの詳細検証は初回公開の非ブロッキングとし、公開後の改善候補へ残す。追加開発・再テストは行わず、App Storeで対応保証・申告を行わない。既存の視認性、十分な文字コントラスト、44px以上の操作領域、フォームlabel、キーボード操作、フォーカス表示、明らかな操作不能がない基本品質は維持する。
- **連絡先と契約主体**：Appleの非公開リレーアドレスを正式な連絡用メールとして認め、個人の実メールアドレスは必須にしない。契約主体の正本はFirebase UIDであり、メール文字列を契約判定、Stripe Customer紐付け、アカウント統合、UIDの代替、権限付与に使わない。
- **メールの状態**：Firebase Authに確認済みの通常メールがある場合はそれを使用し、Appleから得たリレーアドレスがある場合はそのリレーを使用する。A：通常メールあり／B：Appleリレーありには追加の実メール登録を求めない。C：AuthにもRelayにもメールが本当にない場合だけ、本番有料登録前に受信可能な連絡用メールを補完し、確認メールで確認済みになってから本番契約へ進める。個人の実メールに限定せず、Appleリレーも許可する。
- **補完時の用途**：「契約・請求・解約・重要なお知らせを受け取るメールアドレスを登録してください。Appleの非公開メールアドレスもご利用いただけます。」「このメールアドレスは、契約確認、請求、解約、重要なサービス通知、サポート対応に使用します。広告配信には使用しません。」を基準とする。補完UI・確認フローは後続タスクで、今回実装しない。
- **現在のPreview**：メール未設定の本人Appleアカウントを受理する承認済み挙動と、UID／provider／既存アカウント／ペット／契約ガードを維持する。メール未設定だけを理由にPreview契約確認を阻害しない。Private Email Relay送信元登録とFirebase／HamCare重要通知／サポート返信／Stripe領収書等の配送確認は本番公開前の残件とし、個人の実メール取得を目的にしない。
- **Apple Case 103009817213**：本人共有の回答済み。「事前承認なし。実提出後に審査判断」。戦略CやStripe導線の事前承認・ストア審査合格と解釈せず、回答待ちへ戻さない。
- **保護範囲**：本方針整理により本番Stripe、live Hosting、Flutter、既存契約、現在の体験、テスター権限を変更しない。公開・本番切替は別指示とする。
<!-- hamcare-contact-accessibility-policy-20261116:end -->

2026-10-31最新：Google Play送信ID1の既存14変更・Alpha1.0.1／code2は2026-10-27 11:09 JST送信、11:19 JST「公開」と本人確認済み。今回も送信詳細・リリース一覧で読取照合した。日本のみ・既存テスターを維持し、製品版一般公開・必要人数／期間の達成とは分ける。以下の未送信・審査中記載は当時の履歴。Apple旧Case22954972は担当範囲外回答を受領、新Case103009817213は10/27 11:46:34 JSTにApp Reviewへ送信・受付確認済みで回答待ち。決済導線は保留。本人指定のアバターは制作待ち、次期code3／build3は画像完成後に生成・別途配布承認を得る。通常テスターは既存21日無料体験を利用し、審査用の通常0円契約・アクセス準備と区別して保持する。

履歴（10/25）：App Privacy確定／Play掲載・Data Safety保存、API24確定、動画表示等、同意実装・限定26件／AAB・IPA生成済み。当時未確認だったDeviceCheckとupload・本人内部更新は10/26に完了済みで、残件へ戻さない。

更新日: 2026-10-31

この文書は提出内容の原本です。審査用アカウントのパスワードなどの秘密情報はリポジトリへ保存せず、App Store Connect / Google Play Consoleの審査欄へ直接入力します。

> 2026-10-18確認：現行のStripe購入誘導は審査適合済みではありません。日本向け外部決済制度はApple IAP／Google Play Billingの併用を要求するため、現時点では提出せず、購入誘導のない利用形態の適用条件を確認します。下記の支払い説明・操作手順は現行実装の説明案です。[今回の規則照合・Apple問い合わせ文案・iOS結果](japan_store_payment_and_ios_readiness_20261018.md)を優先してください。

2026-10-25再開時点：Apple Case-ID 22954972への追加返信は本人送信済み・回答待ち。Appleサインイン、iOS Releaseホーム起動・ログイン保持、Android更新後のHome・ログイン・記録保持に加え、最新両版の通常AI各1件も本人完了確認済みで再送しない。初版は既存RAGを使い、反復検索・専用beta権限は追加しない。Play Consoleの日本設定、既存Alpha作成／プレビュー・13申告等の保存は確認済みで、送信・審査・公開とは分ける。

10/25前段の記録：本人承認でApp Store Connect ID6826783734を作成。版1.0.1／手動公開／日本1国／無料、説明・キーワード・support／Privacy URLを保存PASS。Privacyの限定分析／AI経路2段落をHosting1path限定公開PASS。Google現Releaseの本人実認証・Home復帰／再起動保持、最新upload鍵署名AAB、Development署名Release Archiveは完了。配布署名／upload、審査用情報・画像・App Privacy質問票、決済回答／通常テキストAIの明示許可等の提出前残件は正本へ集約し、審査送信・アプリ公開済みとはしない。

## 2026-10-27 Apple App Reviewへの決済方式問い合わせ（受付確認・回答待ち）

送信原文と受付の正本は[既存Apple問い合わせ記録](japan_store_payment_and_ios_readiness_20261018.md#送信原文受付記録新case-103009817213)を参照する。

- 旧Apple Case22954972は10/27に代替配信／決済担当から当該窓口のscope外との回答を受領。これはStripe導線の可否回答ではない。本人承認の指定文面で、公式 https://developer.apple.com/contact/app-store/ から実窓口「App Review → App Review に関するその他のお問い合わせ → Eメール（公式フォーム）」を選び、2026-10-27 11:46:34 JSTにApp Review宛て新問い合わせを送信。受付結果公式完了画面と11:48:45 JST受信の受付メールで番号一致を確認、新Case ID103009817213。回答は未受領で、A／B導線・Stripe維持条件の判断は回答待ち。
- 対象はApp Store Connectの数値App ID6826783734、名称「Hamster Care｜ハムスター健康管理」、Bundle ID com.gotainu.hamster。既存アプリ・提出候補を維持。問い合わせ送信はアプリ本体のApp Review提出・公開ではない。
- 証拠：既存iOS staging/audit/apple-appreview-inquiry-20261027/。旧Case経緯、選択窓口・承認済み送信文面・受付結果を分離して保持。既存Play送信・実機・通常権限・署名／成果物PASSを維持し、コード／SDK／IAP・Billing／Stripe導線・本番設定・利用履歴を変更しない。秘密情報・不要な個人情報を文書へ転記しない。本人指定の送信本文は既存問い合わせ記録へ原文保存する。

## 提出方針

- 初回公開地域は日本のみです。App Store / Google Playの同時公開を目標とし、両ストアの準備状況と公開操作を提出前に調整します。
- Stripe Checkout / Stripe Customer Portalによる月額プランの維持を第一希望とします。アプリ内の購入誘導を残すA案と、Web契約済み利用者がログインするB案の適用条件を確認してから、提出時の導線を確定します。
- AppleのApp内課金およびGoogle Play Billingは、現時点では実装しません。この方針だけで日本向け制度の条件を満たすとは判断しません。
- 却下された場合は、指摘された規約番号、審査文面、画面、日時を保存し、指摘内容に限定した対応を判断します。

## 審査担当者への機能説明

Hamster Careは、ハムスターの毎日の様子、体重、回し車の走行距離、飼育環境を記録するアプリです。有料プランでは、SwitchBot温湿度計との連携、温湿度の自動記録と環境評価、異常検知通知、飼育記録を踏まえたAI相談を利用できます。

有料プランは「Hamster Care Premium Plan」、月額500円（税込）、1か月ごとの自動更新です。アプリ内の「利用プラン」画面に料金、更新条件、解約後の利用期限、利用規約、プライバシーポリシーを表示しています。登録操作は外部ブラウザのStripe Checkout、契約確認・支払方法変更・解約はStripe Customer Portalで行います。

## 審査用アカウント

- 10/25時点のメールアドレス候補（履歴）: 審査用メール（Consoleで管理）。現在の使用決定・有効な審査アクセスの証明ではない。10/27に本人指定メールの通常登録・メール確認・Home保持、カードなし0円正規契約と既存Webhookによる通常権限同期をPASS確認。Android有料gateも本人PASS、Console資格情報／アクセス申告の保存・再読取もPASS。初期経緯と現在の手順を下記へ分離する
- パスワード: App Store Connect / Google Play Consoleへ直接入力（このファイルには記載しない）
- 前提: Googleの審査員がアカウント作成・無料体験開始・購入をせずに、提供した再利用可能な資格情報で有料領域を含む全機能へ入れる必要がある。一般テスターの21日／20件とは分ける。通常の有効契約付き審査専用アカウントの準備を推奨し、特別有料扱い・UID許可リスト・trial resetを勝手に追加しない。分析上の除外も利用権限と別
- 全機能へのアクセス保証と、AI回数・費用枠を無限化することは同義ではない。承認済み有限枠と履歴は維持し、Googleが後日／再審査時にもログインできる状態を用意する。専用betaは初版対象外の本人決定を維持し、実装済みとは説明しない

## 確認手順

1. アプリを起動し、審査用アカウントでログインします。
2. 下部の「今日」で現在の状態と記録を確認できます。
3. 「記録」で今日の様子、走行距離、体重を入力できます。
4. 「変化」で活動量、温度、湿度、体重の推移を確認できます。
5. 「相談」でAI相談を確認できます。初回の通常文字送信前に、OpenAIへ送る相談文・会話・関連する飼育情報と、Pineconeへ送る検索用ベクトルを説明する画面が出ます。「同意して送信」で進み、「送信しない」／戻るでは送信しません。左上≡→「アプリの設定」を開き、下へスクロールした「SwitchBot連携設定」の下にある「データとプライバシー」欄→「AI相談の情報送信への同意を取り消す」から取り消すと、次回送信前に再提示します。
6. メニューから「設定」→「利用プラン」を開くと、料金と契約状態を確認できます。無料体験は本人の開始操作から21日間、AI相談最大20リクエストで、再操作や別端末利用による期限延長・枠の再付与はありません。
7. 「プランを管理する」を選ぶと、外部ブラウザでStripe Customer Portalが開きます。

## Google Play審査アクセスの現状と保存待ち文案（2026-10-27）

- 審査用アカウントは、Google審査担当者がHamCareへ入るためのアプリ内アカウント。Play内部テストのGoogleアカウント／参加リストとは別で、Consoleへ資格情報を記入してもFirebaseの新規登録はされない。
- 初期確認と準備の履歴：当初はFirebase未登録で全premium利用可説明を立証できず、通常登録・メール確認・Home保持後に限定100% forever割引を用意した。Checkoutのカード要求を避ける本人選択により、10/27 10:03 JSTにDashboardで同じPremiumの通常契約を作成。Couponを直接適用し上限1回を維持（Promotion Codeでの適用完了とはしない）。カードなし・trialなし、契約Active、初回0円Paid・次回11/27も0円を確認。初回invoice.payment_succeededの500はbilling/stripeSubscriptionIdのCOLLECTION_GROUP_ASC索引不足が原因。Customerの既存認証連携metadataをAuth hash一致で照合し、同Subscriptionへ通常Checkoutと同じ連携情報を補記したところ、customer.subscription.updatedの既存Webhookが自動同期。Firebase paid／active・期限11/27・Customer／Subscription hash一致、trial文書なしを確認。手動再送・コード／deploy／DB直接編集・索引追加は0で、索引不足経路自体は未修正。秘密値・個人識別子は文書へ転載せず既存auditへ証拠を分離する。
- 初期の保存拒否履歴：当初は455文字案の「全機能アクセス確認」を立証できず未保存入力を閉じた。その時点では通常登録・契約を未実施で、旧資格情報が残っていた。以後の登録・カードなし0円通常契約・通常同期・本人有料gate確認を経て、現在は新資格情報と456文字手順を保存PASS。
- 審査アクセスの残件完了：本人が新登録HamCareのパスワードをConsoleへ直接入力し、456文字の英語手順・全機能アクセス確認を「追加」→親画面「保存」で保存PASS。別画面へ移動後の再読取でも、対象username・456文字・確認項目の一致を確認した。パスワードはチャット・文書・証拠へ転記していない。 本人がAndroid「変化」を無料体験なしで開けたことを確認し、有料gate PASS。実AI再送・SwitchBot実機連携の再確認は行っていない。手順には必要な機器依存を明記し、実施済みと偽らない。今回対象の審査用アクセスは準備・保存完了。Play下書きは14変更保存済み・未送信で、本人の送信判断へ提示できる状態。Apple Case22954972に依存する決済導線の保留は維持し、契約・権限成立をストア決済適合PASSへ読み替えない。
- Googleの現ガイダンスは、有効・再利用可能・地域非依存の資格情報と、審査員が無料試用や自身のアカウント作成を行わず全機能へ入れる情報を求める。[公式要件](https://support.google.com/googleplay/android-developer/answer/15748846?hl=en)。

初期未保存英語案（455文字・履歴。現在は下記456文字手順をConsoleへ保存・再読取PASS）：

> Sign in with the credentials above. Today: Home/records; Records: daily inputs; Changes: charts; Consultation: saved answers and AI. Before text is sent, a notice explains OpenAI/Pinecone data use; Cancel sends nothing. Withdraw consent via the top-left menu > App settings, below SwitchBot settings. Plans show the ordinary 21-day/20-request trial or current subscription. Purchases open Stripe Checkout; contract management opens Stripe Customer Portal.

上記455文字は初期未保存案の履歴。現在は通常契約・権限・本人有料gateを確認したうえで、下記456文字手順と本人入力の新資格情報をConsoleへ保存・再読取PASS。14件の審査送信は行わず、決済導線の適合判断保留と送信承認待ちを維持する。

Play Console保存済み英語手順（456文字・別画面から再読取一致、通常権限反映／本人有料gate確認後に保存）：

> Sign in with the provided email/password; no sign-up, trial or payment is needed. Today/Records/Changes show records and charts; Consultation shows saved answers and AI. Text AI first asks permission for OpenAI/Pinecone data use; Cancel sends nothing. Withdraw consent via menu > App settings, below SwitchBot settings. Plan status is in App settings > Subscription Plan. SwitchBot features require compatible hardware; settings can be reviewed without it.

維持条件：現在の通常Premiumは月額500円・月次自動更新だが、承認した対象商品／Customerの100% forever割引を適用した契約を維持する間は0円とする。本人はカード不要のStripe Dashboardで契約を確定済み。カード未登録・初回0円Paid・次回0円を確認した。通常の有効契約でも共有AI枠は適用され、今回の読取値は11/25件使用済み・残り14件、予約費用550,000/1,250,000 micros使用済み・残り700,000 micros。既存履歴と上限を保持し、審査用に無制限とは申告しない。

## 審査欄へ記載する支払い説明案

本アプリの初回配信地域は日本のみです。有料プランの料金と自動更新条件は購入操作の直前にアプリ内で表示されます。決済は外部ブラウザでStripe Checkoutを使用し、契約確認、支払方法変更、解約はStripe Customer Portalから行えます。解約後も支払済み期間の終了までは有料機能を利用できます。

## アカウント削除

- アプリ内: 「設定」→「アカウントを削除」
- Web: https://hamster-breeding-app.web.app/account-deletion/
- 有料プラン利用中でもアカウント削除を妨げません。削除前にStripe契約は自動解約されないことを案内し、契約管理画面への導線と、そのまま削除を続ける選択肢を表示します。

## 公開ポリシー

- プライバシーポリシー: https://hamster-breeding-app.web.app/privacy/
- 利用規約: https://hamster-breeding-app.web.app/terms/
- 特定商取引法に基づく表記: https://hamster-breeding-app.web.app/commercial-transactions/
- サポート: https://hamster-breeding-app.web.app/support/

## Stripe決済に関する根拠資料

- 公正取引委員会 スマホソフトウェア競争促進法: https://www.jftc.go.jp/smartphone_msca.html
- 公正取引委員会 よくある質問（アプリ事業者向け）: https://www.jftc.go.jp/msca/index_yokuarusitumon.html
- 公正取引委員会 運用ガイドライン: https://www.jftc.go.jp/houdou/pressrelease/2025/jul/250729_01-4_smartphone_shishin.pdf
- Stripe解説: https://stripe.com/jp/resources/more/what-are-app-fees-japan-smartphone-law

これらは審査担当者へ最初から長文で主張するためではなく、決済方法を理由に却下された場合に、具体的な指摘内容と照合するための内部資料として使用します。

## 却下記録テンプレート

- ストア:
- 提出日時:
- 回答日時:
- 規約番号:
- 審査文面（原文）:
- 指摘画面・操作経路:
- 添付画像:
- こちらの回答:
- 再提出内容:
