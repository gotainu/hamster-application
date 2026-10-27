# HamCare 日本限定・両ストア公開準備（2026-10-18）

## 2026-10-27 Apple App Reviewへの決済方式問い合わせ（受付確認・回答待ち）

- 旧Apple Case22954972は10/27に代替配信／決済担当から当該窓口のscope外との回答を受領。これはStripe導線の可否回答ではない。本人承認の指定文面で、公式 https://developer.apple.com/contact/app-store/ から実窓口「App Review → App Review に関するその他のお問い合わせ → Eメール（公式フォーム）」を選び、2026-10-27 11:46:34 JSTにApp Review宛て新問い合わせを送信。受付結果公式完了画面と11:48:45 JST受信の受付メールで番号一致を確認、新Case ID103009817213。回答は未受領で、A／B導線・Stripe維持条件の判断は回答待ち。
- 対象はApp Store Connectの数値App ID6826783734、名称「Hamster Care｜ハムスター健康管理」、Bundle ID com.gotainu.hamster。既存アプリ・提出候補を維持。問い合わせ送信はアプリ本体のApp Review提出・公開ではない。
- 証拠：既存iOS staging/audit/apple-appreview-inquiry-20261027/。旧Case経緯、選択窓口・承認済み送信文面・受付結果を分離して保持。既存Play送信・実機・通常権限・署名／成果物PASSを維持し、コード／SDK／IAP・Billing／Stripe導線・本番設定・利用履歴を変更しない。秘密情報・不要な個人情報を文書へ転記しない。本人指定の送信本文は既存問い合わせ記録へ原文保存する。

### 送信原文・受付記録（新Case 103009817213）

- 旧Case22954972：2026-10-27 07:28 JSTの代替配信／決済担当メールで、3.1.3適用資格・Web UI・trial／契約表示／契約管理の質問は担当範囲外と確認。公式Contact Usへの案内を受領。旧担当へ同文を再送していない。
- 開始ページ：<https://developer.apple.com/contact/app-store/>。初期フォームのtechnical questionはTSI／コード調査と説明されていたため未送信で離れ、実際に表示されたContact Us → 新たな問題 → App Review → App Review に関するその他のお問い合わせ → Eメールを選択。最終フォーム：<https://developer.apple.com/contact/topic/SC1103/subtopic/30023/solution/CONTACT.EML.GEN/details>。カテゴリや直通メールは推測していない。
- 既存Appleログインを利用。App名「Hamster Care｜ハムスター健康管理」、数値App ID6826783734、iOSを入力。数値IDは既存App Store Connect作成記録と一致。
- 本人指定件名：HamCare — App Review Guidelines 3.1.3 eligibility before submission (ref. Case 22954972)。フォームに独立した件名欄がなかったため、送信メッセージ冒頭へSubject行として含めた。以下2877文字を入力し、本文2778文字と件名が承認文面に完全一致することを画面で確認して送信。内容の言い換えなし。
- 送信：2026-10-27 11:46:34 JST。受付画面「ご連絡ありがとうございました。」とお問い合わせ番号103009817213を確認。11:48:45 JSTにApple Supportから件名「Thanks for submitting your support request.」の受付メールが届き、同じCase IDと受領メッセージを照合。ガイドライン適合への実質回答は未受領。
- 現在：**旧Case22954972は担当範囲外との回答受領。App Review窓口へ問い合わせ送信済み・回答待ち。決済導線の判断は保留。** アプリ実装・課金・権限変更、App Store審査提出、Google Playへの追加操作は0。追加の本人認証操作は不要だった。

```text
Subject: HamCare — App Review Guidelines 3.1.3 eligibility before submission (ref. Case 22954972)

Dear App Review Team,

My name is Go Nakazawa, developer of HamCare. Our Apple Developer Team ID is 3SA77V3SM7. We are preparing to distribute HamCare on the Japanese App Store and would appreciate guidance on the applicable App Review Guidelines before submission.

Our previous inquiry was handled under Case-ID: 22954972. On October 27, 2026 (Japan time), the alternative distribution and payments support team explained that our questions about eligibility under the App Review Guidelines were outside its scope and directed us to the appropriate team through the Apple Developer contact page. We are therefore contacting App Review with the unresolved questions below.

HamCare is a cloud-connected hamster-care service. Its AI consultation feature uses retrieval-augmented generation (RAG) to retrieve relevant information from an online knowledge base. The app also provides care records, personalized analysis and reports, and related video information and links.

The main user-facing features are currently provided through our native iOS and Android apps. We do not currently offer an equivalent browser-based application. Our website would primarily provide registration, subscription purchases, and billing management.

We are considering the following distribution model:

- The app is free to download.
- Users can start a 21-day free trial without a credit card.
- Users independently find our website and subscribe through Stripe for JPY 500 per month.
- The iOS app would contain no purchase buttons, external purchase links, or other calls to action directing users to purchase outside the app.
- Subscribers sign in to the app to use the service.

Could you please clarify the following?

1. Given these features and the proposed model, can HamCare be distributed on the Japanese App Store without implementing Apple In-App Purchase? If so, which provision applies: Guideline 3.1.3(a), 3.1.3(f), or another provision?
2. For Guideline 3.1.3(f), is a browser-based interface for the service’s main functionality required, or can a paid cloud-hosted service primarily accessed through native apps qualify?
3. Under a permitted model without IAP, may the app offer the free trial and display subscription status and expiration dates? May existing subscribers access a billing-management page solely for cancellation or payment-method updates, provided that page offers no new purchases or upgrades?

We are not assuming that cloud delivery or RAG alone makes the app a reader app. We would appreciate guidance based on the actual functionality and proposed distribution model described above. We understand that this guidance does not constitute advance approval of the app.

Thank you for your assistance.

Best regards,
Go Nakazawa
HamCare
Team ID: 3SA77V3SM7
```

## 2026-10-26 指定IPAデリバリ・内部TestFlight配布・本人更新保持／同意説明・設定撤回項目表示PASS

- 本人がMac App Storeの取得認証を完了し、指定IPAで続行を選択。Transporter 1.4.5で既存の同意対応IPAをそのまま1回デリバリした。対象は `/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/hamcare-1.0.1-build2-consent-appstore-20261025.ipa`（107,026,058bytes、SHA256 `67a7305d7934adfa0565e1ca6375bd101a16b80dbb274019e4c268483ad8695e`）、App Store Connect ID `6826783734`／1.0.1（2）と一致。2026-10-26 09:50 JSTに「デリバリ済み／このアプリは処理中」を確認し、その後build ID `9257a2fd-43fd-40b0-ba8d-60747e7158d0`の登録を確認した。再export・再build・新資格発行は0。
- 最初はMissing Complianceだった。実IPAの標準OS外TLS・独自暗号なし・France配布Noの説明を本人が確認し、最終保存を明示承認した後にSaveを実行。Missing Compliance解除を確認した。外部テスト側の状態はReady to Submitだが、外部審査・一般App Reviewには送信していない。
- 初回の内部グループ0／テスター0から、手動配布の「本人実機確認」（`255439d9-ed98-4563-a6df-da297fea0743`）を作成し、既存の本人Account Holder 1名だけを追加。自動配布はオフ。build2をInternal Groupsのこのグループだけへ追加し、「Internal Group ∙ 1 Tester ∙ 1 Build」、1.0.1（2）のTesting、本人テスターのInvited 10/26を確認。内部TestFlight配布はPASS。本人以外の招待・外部テスト配布・一般公開は0で、アプリ内の特別権限付与とは別。証拠は `/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/audit/asc-owner-internal-build2-testing.png`。
- 本人が「TestFlightからインストールした。Home・ログイン状態・既存の飼育記録が保たれている」と回答し、更新と保持は本人確認PASS。AI相談の同意説明表示と「送信しない」（キャンセル）後の入力保持も本人確認PASS。設定の撤回項目は最初見当たらないとの返答だったが、HamCare左上≡→「アプリの設定」→下スクロール（SwitchBot連携の下、AI相談履歴削除とPrivacyの間）と再案内した後、本人が「あった」と表示を確認した。コード修正なし。確認ダイアログの開閉・取消は未確認、実同意承諾・保存済み同意の実撤回は未実施。証拠は `/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/audit/testflight-consent-owner-ui-final-20261026.json`。
- 更新後メタデータはBundle com.gotainu.hamster／1.0.1（2）の維持を照合PASS。builtByDeveloperはtrue→trueのため配布経路の独立証明とはしない。bundle／data container pathは変化したが、パスだけでデータ喪失と判断せず、TestFlight更新・保持PASSは本人の操作報告を根拠にする。更新前のiPhone 17e／iOS 26.5.1・同Bundle／版の読み取り記録も保持する。
- 既存端末Release・通常権限・無料体験の期限と使用量・飼育記録・履歴を保護し、実AI送信・同意承諾操作・Google等の実認証再試験・動画・限定26件の再試験は0。Apple Case22954972の回答待ち・Stripe導線の判断は別件のまま維持する。

### 10/26後続：Release DeviceCheck実動作とAndroidローカル更新

- **サーバー計測によるRelease DeviceCheck実動作PASS。** 本人のTestFlight更新確認10:09:51 JSTと同じ10:09:07〜10:10:07 JSTに、既存のExchangeDeviceCheckTokenがHTTP200／gRPC0で1件。現iOS AppIDのFirestore VALID／ALLOWを保存時点412件確認し、現登録privateKeySet=true・旧登録false・旧AppIDの検証traffic0を合わせて判定した。412件はFirestore App Check検証数で、AI・無料体験の使用量ではない。証拠は `/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/audit/devicecheck-testflight-readonly-final-20261026.json`。
- 個体SDK callback・token文字列・個体token期限は直接未観測。providerのメソッド計測にはAppID／deviceラベルがなく、現AppIDの検証計測にはdevice／providerラベルがないため、時刻・登録状態・旧アプリ除外との組合せによるサーバー計測PASSであり、個体callbackを直接観測したとはしない。設定TTL3600秒を実token期限と読み替えない。追加attach／SDK呼出し／forceRefresh／AI／認証／体験操作は0で、App Check強制・認証・鍵・SDK・ソースを変更していない。旧SIGSTOP・SDK呼出し0の結果は下記の当時履歴として保持する。
- Androidは固定済み最終AABを再compileせずAPK化し、端末の既存署名 `52ab9f417a1008800a5e3eefc55ce1a2539bdedfeebba10855cf79f85208b62e` と合わせて、10:45:26 JSTに `adb install -r` 成功。1.0.1／code2、非Debug、app UID10405と初回導入日時2026-10-03 16:38:47を保持し、起動OK。アンインストール・データ消去・新鍵・鍵変更なし。APK SHA256 `514c000cb00e61c692685654d41f1a652c78cbc558ad720e7e9e68518c78db84`。証拠は `/private/tmp/hamcare-signature-devicecheck-20261026/android-local-replace-result.json`。
- このAndroidローカル更新とPlay配布は別。既存Debug署名アプリからPlay署名配布版への移行は未解決で、ローカル上書き成功をPlay経由更新PASSにはしない。今回のローカル更新後、再ログインせずHome・既存飼育記録と設定撤回項目が表示されるかとの依頼に、本人が「表示されました」と回答。Home・ログイン・既存記録保持とAndroid設定撤回項目の表示は本人確認PASS。実同意承諾・保存済み同意の実撤回は未実施。Play署名配布版の実機確認は別Android実機待ち。証拠は `/Users/gota/hamcare-deploy-staging/android-ordinary-update-20261025/audit/android-local-consent-owner-confirmed-20261026.json`。実AI再送0、Play既存13変更の審査送信0。

2026-10-25同意対応候補の生成（履歴）：通常文字AI同意を局所実装し限定26件PASS後、通常lib/main.dartをXcode27.1／恒久Flutter3.47.7・固定lockで新Release Archiveへビルドし、既存Distribution証明書／App Store ProfileでIPA export PASS。当日の提出対象は`/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/hamcare-1.0.1-build2-consent-appstore-20261025.ipa`（107,026,058bytes、SHA256 `67a7305d7934adfa0565e1ca6375bd101a16b80dbb274019e4c268483ad8695e`）。Archive ZIPは`/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/Runner-consent-development-archive-20261025.zip`（SHA256 `90ced1a78a539f204e22d29c613ffb60f61a001f8e988d7d90c52c24c529c202`）。codesign strict／ZIP／get-task-allow=false／Apple Default／APNs production／Archiveとのコード・資産一致を確認。前回の同意前IPA／Archiveは以下に履歴として保持する。当該生成工程では新資格発行、端末上書き、upload・審査送信・実AIは0。10/26のデリバリ結果は先頭の最新状態を参照。当時のDeviceCheckは前回後の既存ログ0件で、同一processへの最小native確認もSDK呼出し前のSIGSTOPで中断・resume指定detach済みのため、実attestationは未確認だった。10/26のサーバー計測による実動作PASSとは観測方法を区別する。App Check強制設定・認証系を変更していない。

2026-10-25同意実装前の配布準備（履歴）：本人作成のApple Distribution証明書と、明示承認した同一Team／App IDのApp Store Profileで、既存Release ArchiveからIPA export PASS（再ビルドなし）。`/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/hamcare-1.0.1-build2-appstore-20261025.ipa`、SHA256 3f2b61b017e93c451b5c96e10447cea82feaea987445cb23665f2c447c2cfd48。get-task-allow=false、Apple／APNs権限、codesign strict／ZIP／元コード・資産一致PASS。証拠は既存audit/appstore-ipa-result-20261025.json。端末上書き／upload／審査送信なし。以下のDevelopment Archiveまでの記載は前段の履歴であり、現在の配布署名待ちへ戻さない。当時の通常AI同意不足は、本書先頭の最新工程で局所実装・限定検証と最終候補再生成まで完了。この前工程ではDeviceCheck実attestationは未確認だった。10/26のサーバー計測による実動作PASSは先頭の後続結果を参照。

10/25後続の公開準備（履歴）：既存成功Xcode27.1／恒久Flutter3.47.7・固定lockを隔離再利用し、通常lib/main.dartのRelease Archive PASS。Development署名（get-task-allow=true）であり、Distribution export／IPA／uploadは未実施。既存staging `ios-device-runtime-20261019/artifacts/Runner-development-archive-20261025.zip`（157,930,706bytes、SHA256 2c0931038ef0649ec137fd94c32cbd1443336a4389d283c4eac3dec0a1e770ae）、同audit/release-archive-result-20261025.jsonに保存。source／native／locks／SDKは保護し、既存iPhone Releaseを上書きしていない。App Store Connect ID6826783734／1.0.1手動公開・日本のみ・無料・掲載原稿／Privacy URL保存PASS。配布署名・審査は別残件。

2026-10-25文書照合：進捗の正本は[PROJECT_STATUS.md](../../PROJECT_STATUS.md)の「検証済みの状態」「タスク一覧」。本書の10/18実行ログ・当時の判断は履歴として残す。この文書照合段階では環境の再照会・ビルド・実機操作・テスト再実行・本番変更は行っていない。同日後続の限定実行結果は次段落と正本へ追記する。

> 続報（10/25照合）：iOS OAuth設定同期、元ワークスペースの新Xcodeビルド、実機起動、Releaseホーム起動・ログイン保持、通常版Appleサインインは完了済み。Google実OAuth・アプリ復帰・Home・再起動保持も現Releaseで本人PASS。最新両版のAI各1件は本人完了報告を受領し再送しない。技術準備の進展と、Stripe購入導線の適合確認・Apple問い合わせ／適用確認待ちは別。下記の規則調査は10/18時点の記録で、今回再調査していない。

## 判断と今回の範囲

現在：日本限定・両ストア同時公開目標、Stripe維持第一希望・IAP／Play Billing未実装を維持。旧Apple Case22954972は10/27に代替配信／決済担当から当該窓口のscope外との回答を受領。これはStripe導線の可否回答ではない。本人承認の指定文面で、公式 https://developer.apple.com/contact/app-store/ から実窓口「App Review → App Review に関するその他のお問い合わせ → Eメール（公式フォーム）」を選び、2026-10-27 11:46:34 JSTにApp Review宛て新問い合わせを送信。受付結果公式完了画面と11:48:45 JST受信の受付メールで番号一致を確認、新Case ID103009817213。回答は未受領で、A／B導線・Stripe維持条件の判断は回答待ち。 同文追加送信・購入導線変更を行わず、アプリ本体の審査提出・公開とも区別する。以下は10/18の調査と各日作業範囲の履歴。

日本限定、iOS／Android同時公開を目標とし、Stripeを第一希望とする。Apple IAP／Google Play Billingは今回実装しない。これは公開方針であり、現行の購入画面が両ストアの規則へ適合済みという意味ではない。

現行の「アプリ内の登録ボタン → 外部ブラウザのStripe Checkout」をStripeだけで提供するA案は、確認した日本向け外部決済制度の条件を満たさない。両社とも対象制度ではストア決済の選択肢も要求する。B案の「購入誘導を置かず、Web契約済みの利用者がログインして使う」はGoogleでは消費専用アプリとして検討可能。AppleではHamCareが3.1.3(f)の対象になるかを問い合わせる必要がある。

本工程では調査、隔離コピーのiOSビルド、必要最小限のiOS依存ロック同期と文書更新を行う。Stripe／Functions／Firebase設定／Cloud Run／APK／ストア設定を変更せず、申請・アップロード・本番配備・実決済・実AI利用を行わない。Appleへの問い合わせも送信しない。

## 現行の機能・契約構造

- 飼育状況、体重、回し車の走行距離、飼育環境を記録し、変化や個体別レポート、AI相談を利用する個人向けアプリ。獣医診療や対人専門サービスとして説明しない。
- 利用プラン画面は月額500円（税込）の自動更新契約を案内し、登録は認証済み利用者向けのStripe Checkoutへ遷移する。`lib/screens/subscription_plan_screen.dart`、`functions/src/index.ts`を確認した。
- 契約確認・解約・支払方法変更はStripe Customer Portalへ遷移する。実際のPortal設定に追加購入／アップグレード導線があるかは今回変更・実決済していない。
- 21日間の無料体験はアプリ内で明示開始するカード不要の機能利用権限。体験開始時にStripe契約を作成せず、終了だけで自動課金されない。AI相談20件等の既存上限は別に存在する。`functions/src/trialPolicy.ts`、`functions/src/featureTrials.ts`を確認した。
- 消費者向けWebは紹介・規約・サポート・課金完了等のページであり、ブラウザで飼育記録・分析を利用できる完全なWeb版サービスは未実装。管理者専用分析ダッシュボードを消費者向けWebサービスと数えない。
- 現行アプリにIAP／Play Billingや日本向け課金選択制度の連携はない。B案向けの購入誘導抑制も未実装である。

## A／B比較

| 案 | Apple（日本） | Google Play（日本） | 現状との差・審査上の問題 |
| --- | --- | --- | --- |
| A：アプリからStripe Checkoutへ誘導 | 日本向け制度の利用には、対象OS・ストアフロント、申請、StoreKitの適格性確認・通知・報告等に加えてApple IAPの提示が必要。Stripeだけを置く現行案を、この制度で適合済みとはできない。 | 2026-09-30開始の日本向け課金方法選択制度でも、Play Billingと代替課金／外部リンクを併設する必要がある。登録・選択画面・API・報告等が必要。 | 両社の制度対応は未実装。今回はIAP／Play Billingを実装しない方針なので、A案のまま提出可能と判断しない。 |
| B：アプリ内で購入させず、Web契約済み利用者がログイン | 無料の有料Webツール用コンパニオンに関する3.1.3(f)が候補。ただしHamCareの機能とWebの実態で対象となるか未確定。購入／外部購入を促す導線を残せない。 | 消費専用アプリはカテゴリを問わず認められる。アプリ内で購入できず、禁止される外部購入誘導を置かない条件で、Web購入済みサービスを利用できる。 | ネイティブ側の購入ボタン、料金を伴う勧誘、無料体験終了時の案内、Portal等を経由する購入経路の確認が必要。Web側の認証済み契約開始方法も整理が必要。Apple確認前に適合を断定しない。 |

B案でも既存Stripeの契約処理そのものを廃止する必要はない。アプリからの購入誘導を抑えることと、Stripeサーバー処理を変更することは別の作業になる。今回その実装はしていない。

## Appleの適用規則

- **3.1.3(f)** は、一定の有料Webツールに対する無料コンパニオンを扱う。HamCareが該当するかは、支払いページがあるだけで決めず、実際のWeb機能を明記して確認する。**3.1.3(b)** のマルチプラットフォーム規定にも、同じデジタル商品をアプリ内課金でも購入可能にする条件があり、Stripeだけにする包括的な免除ではない。HamCareをメディア閲覧用の「Readerアプリ」とも扱わない。[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/#free-stand-alone-apps)
- 日本向け制度は日本ストアフロントの**iPhone／iOS 26.2以降**等が対象。外部購入リンクの権限、StoreKitによる適格性確認と通知、Apple IAPの選択肢、取引報告・手数料等を伴う。全iOS版やiPadへ自動的に適用される制度ではない。Stripe利用料だけで完結するとも判断しない。[日本向け支払いオプション](https://developer.apple.com/support/payment-options-on-the-app-store-in-japan/)

サポート回答は制度の適用確認として保存し、最終的なApp Reviewの合格保証とは区別する。D-Lab等の他アプリの事例、日本限定、Android版の存在だけを適合根拠としない。

## Googleの適用規則

- デジタル機能・サービスには原則Play Billingが必要で、例外／承認済み制度を使わずボタンや登録経路から外部購入へ送ることはできない。[支払いポリシー](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en)
- 消費専用アプリはWeb等で購入した内容をログイン後に利用できる。ただしアプリ内購入や禁止される外部購入誘導を設けない。アカウント管理リンクも、実際の遷移先が購入へ誘導しないか確認する。Googleで認められる非リンクの説明がAppleでも同様に認められるとは限らない。[支払いポリシーの解説](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en)
- 日本の新しい課金方法選択制度は**2026-09-30開始**。Play Billingと他の選択肢の併設、参加登録、所定UI・情報画面、保護者向け制御、取引の報告等を要求する。外部リンクでもストア手数料がなくなるわけではない。[日本向け課金方法選択制度](https://support.google.com/googleplay/android-developer/answer/17161464?hl=en-en)、[Billing Choice実装要件](https://developer.android.com/google/play/billing/billingchoice)
- 旧日本向け外部決済制度は同日から新規登録を停止し、2027-03-31終了予定。旧制度を新規公開の逃げ道として使わない。[旧制度の案内](https://support.google.com/googleplay/android-developer/answer/16787536?hl=en)

## Apple Developer Supportへの問い合わせ文案（10/18作成・当時未送信）

件名：日本限定の飼育記録・分析アプリにおけるWeb契約利用とガイドライン3.1.3(f)の適用確認

Apple Developer Support ご担当者様

現在、ハムスターの飼育支援アプリ「HamCare」の初回公開を準備しています。配信地域は日本のみとし、iPhone／Android版の同時公開を目標としています。以下の構成について、適用される規則と必要な対応をご教示ください。

HamCareは、個人の飼い主が毎日の様子、体重、回し車の走行距離、飼育環境を記録し、クラウド保存、変化の確認、個体別レポート、AIを用いた飼育相談等を利用する無料ダウンロードのアプリです。獣医による診療や対人専門サービスを販売するものではありません。一般ユーザー向けには未公開です。

有料のデジタル機能は月額500円（税込）の自動更新契約として設計しており、現在の実装ではアプリ内のプラン登録ボタンから外部ブラウザのStripe Checkoutへ移動します。契約確認、解約、支払方法変更にはStripe Customer Portalを使用します。Appleのアプリ内課金は現時点では実装していません。

別に、利用者がアプリ内で明示的に開始する21日間の無料体験があります。カード登録は不要で、体験開始時にStripe契約は作成されず、体験終了だけで自動課金されることはありません。AI相談には件数等の利用上限があります。

現状の利用者向けWebサイトは、紹介、利用規約、サポート、支払い結果等のページで構成しています。ブラウザから飼育記録や分析を利用できる完全なWeb版サービスはまだ提供していません。この点を踏まえ、次の二つの構成について確認したく存じます。2は現在の実装とは異なる候補構成です。

1. アプリから外部ブラウザのStripe Checkoutへ誘導する構成で、Apple IAPを併設せず公開できる適用規定はありますか。日本向け外部決済制度ではApple IAPの選択肢も必要と理解していますが、HamCareに適用できる別の条件があるか確認したいです。
2. アプリから料金・購入ボタン・外部購入を促す導線を取り除き、Webで別途契約した利用者がログインして利用する構成は、上記のWeb機能の範囲でも3.1.3(f)の無料コンパニオンとして認められますか。対象外の場合、どの機能上の条件が不足するかをご教示ください。
3. 2の構成で、無料アカウントの作成、カード不要の21日体験、体験終了後に利用権限がない旨だけを示す表示は可能ですか。認められる表示・導線の条件を確認したいです。
4. 既存契約者の解約・支払方法変更だけを目的とするStripe Portalへのリンクは残せますか。購入・追加契約・アップグレード等へ進めないようにした場合の条件もご教示ください。
5. マルチプラットフォーム規定3.1.3(b)をIAPの包括的な免除とは解釈していません。上記で適用可能な制度がある場合、必要な申請、権限、対象OS／ストアフロント、表示、報告等をご案内いただけますと幸いです。

審査前に構成を整理するための問い合わせであり、他アプリの事例を根拠とした例外や審査合格の保証をお願いするものではありません。必要に応じて、実際の画面と操作経路をご提示します。

よろしくお願いいたします。

送信はユーザーが[Apple Developer Support](https://developer.apple.com/contact/)から行う。契約キー、Stripeの秘密情報、審査用パスワードは文案に含めない。

## iOS構成の確認

現在：Google Client／URL Schemeの不足は後続工程で同期済み。メール・Apple通常実機ログイン、署名／Profile照合、Release起動はPASS。Google実OAuth・復帰・Home・再起動保持は本人PASS。Release DeviceCheckは10/26のサーバー計測による実動作PASS。個体SDK callback・token・期限の直接観測は未確認で、サーバー側成功と混同しない。下記は10/18時点の構成確認であり、解消済み不足を再び未完了にしない。

| 項目 | 結果 |
| --- | --- |
| Bundle ID | `com.gotainu.hamster`。Xcodeプロジェクト、FirebaseのDart設定、iOS用plistは一致。 |
| 最小iOS | プロジェクト／Podfileとも15.0。 |
| Firebase | iOS用plistはRunnerリソースへ登録済み。各サービスへの実ログインや実データ操作は未実施。 |
| Googleログイン | Dart実装はあるが、iOS用のOAuth client ID／reversed client IDとURL schemeが不足。現在の初期化にもiOS用client ID指定がない。実機ログインは未確認。 |
| Appleログイン | UI／Firebaseプロバイダ呼び出しとSign in with Apple entitlementがある。DeveloperのApp ID capability、Firebase側Apple設定、配布用profileの一致は未確認。 |
| ネイティブプラグイン | 16プラグインの宣言上の最小OSはプロジェクトの15.0以内。実行時の通知・録音・画像選択・認証等の動作保証とは区別する。 |
| App Check | リリースはDeviceCheckを指定。App Attest entitlementの存在をApp Attest実行確認と読み替えない。 |
| 署名／配布 | 今回は署名なし。証明書・profile・端末導入・TestFlight／ストアアップロードは未実施。 |

## ビルド環境・結果

現在：Xcode27.1／SDK27.1、恒久Flutter3.47.7／Dart3.13.5で元workspaceのGUI起動と通常Release AOTを確認済み。macOS27.0.1は本人報告。10/25のAndroid同署名上書き・本人保持PASSは履歴。10/26は固定AABを再compileせず同既存署名APKでローカル上書き・起動PASS、UID／初回導入日時保持を確認。再ログインなしのHome・既存記録保持と設定撤回項目の表示も本人確認PASS。Play署名移行と別Android実機での確認は残件。以下の旧環境・未署名成果物は履歴として保存する。

**署名なしDebug／Releaseの両方がPASS。** ただし、既存のiOS依存ロックに必要な同期を加えた構成での成功であり、元の古いロックのままで成功したとは記録しない。端末実行やストア提出のPASSでもない。

- Flutter 3.32.8／Dart 3.8.1、CocoaPods 1.15.2、Xcode 16.2／iOS SDK 18.2を使用。CocoaPods推奨1.16.2以上の警告はあるが、今回の両ビルドは完了した。ツール自体の更新はしていない。
- 元ソース294ファイルを隔離コピーし、既存のDart依存ロックを固定して取得。`pubspec.lock`とアプリのDartソースは変更していない。
- 初回のCocoaPods実行はUTF-8ロケール不足で停止。コマンド実行時の環境変数だけを調整した。
- 次に、元のPodfile.lockのGTMSessionFetcher/Core 5.3.1と、GoogleSignIn 9.2.0が要求する3.xの競合を確認。隔離コピーで該当項目だけ再解決し、3.5.0へそろえた。既存Dart依存にあるGoogleログイン／録音のPod登録と必要な従属ライブラリが追加された。Firebase 12.0.0等の無関係なPodの版とPodfileは不変。
- `flutter build ios --debug --no-codesign --no-pub`、続いて`flutter build ios --release --no-codesign --no-pub`が終了コード0。Release完了は2026-10-18 14:09:58 JST。元の制約競合を含め、失敗・再解決・成功のログを保存した。
- 成果物はarm64の`Runner.app`（ビルド表示150.7MB）、Bundle ID `com.gotainu.hamster`、1.0.1+2、最小iOS 15.0。署名検査でも未署名を確認した。配布用IPAやTestFlight版ではない。
- 検証済みコピーと通常プロジェクトの差分が`ios/Podfile.lock`だけであることを確認し、この最小ロック同期を通常プロジェクトへ採用。開始時のdirtyな元バイトは別保存した。Stripe処理・アプリUI・Dart依存版は変更しない。

### ストア提出用ツールチェーンの不足

後続工程で新Xcode導入・実機起動・配布署名と同意対応提出物生成まで完了。指定iOS IPAは10/26に1回デリバリし、暗号回答・本人内部TestFlight配布、本人のTestFlight更新後のHome・ログイン・記録保持までPASS。実機の同意説明表示・キャンセル後の入力保持も本人確認PASS。設定の撤回項目表示も本人確認PASS。確認ダイアログ開閉・取消は未確認、実同意承諾・保存済み同意の実撤回は未実施。以下は10/18の不足記録であり、現在のOS更新要求ではない。

ローカルはmacOS 14.8.9、Xcode 16.2／iOS SDK 18.2。2026-04-28以降のApp Store ConnectアップロードにはXcode 26以降・iOS 26 SDK以降が必要で、現在の環境では提出要件を満たさない。[Appleの提出要件](https://developer.apple.com/news/upcoming-requirements/?id=04282026a)

Xcode 26系の対応には少なくともmacOS 15.6以降が必要。Mac本体の対応可否・容量を確認し、バックアップ後の環境更新を別作業として行う。今回、macOS／Xcode／Flutter／CocoaPodsをアップグレードしていない。[Xcodeのシステム要件](https://developer.apple.com/xcode/system-requirements)

## 次に着手する最小作業

現在の最小残件は正本の `REL-02`／`REL-03` を参照する。旧Case22954972は担当範囲外との回答受領済み。本人承認のApp Review新問い合わせを2026-10-27 11:46:34 JSTに送信し、新Case103009817213を受付画面・受付メールで確認。決済導線の判断は回答待ち。既存Playの14変更は11:09 JST送信・送信ID1審査中という直前確認を維持し、本問い合わせではGoogle Playを操作していない。既存のiOS TestFlight／Android Play更新・Home／ログイン／記録保持・DeviceCheck・通常AI各1件等のPASSは維持し、再実施しない。一般公開や12人／14日達成へは読み替えない。以下は10/18時点の順序を保存した履歴で、環境準備・通常版起動を未完了へ戻すものではない。

1. 上記文案をユーザーがAppleへ送信し、B案の適用条件を確認する。回答を待つ間も、署名やOAuth設定等の準備は進められる。
2. 提出可能なmacOS／Xcode環境を用意する。現行環境とKnown Goodの検証記録を保持する。
3. Google iOS OAuthの正規設定をFirebase／Google Cloudで確認し、URL scheme等を限定修正する。Apple capability／Firebaseプロバイダ／署名設定を照合する。推測したclient IDや秘密鍵は追加しない。
4. 採用済みの最小iOS依存ロックを使い、更新後のXcode環境で署名・実機ログイン・通知等を確認する。今回の未署名ビルドを実機動作確認へ昇格させない。
5. Appleの回答後に、B案ならiOS／Androidの購入誘導だけを抑える最小差分を決める。Stripe課金ロジックは維持する。A案を選ぶ場合は、今回は実装しない方針との整合を改めて判断する。

10/18時点の残件記録（履歴）：日本のみの配信地域、両ストアの公開日調整、審査用アカウント・プライバシー申告・ログイン動作は当時の提出前残件。10/18工程ではストアConsoleでの設定や申請を行っていない。後続の完了結果は正本と本書先頭を参照し、日本設定・申告・既存認証を再び未完了へ戻さない。

## 保護・証拠

以下は10/18工程の変更・保護記録。後続の同意実装・成果物生成・内部TestFlight配布は本書先頭と正本の最新記録を参照する。

- 開始時の294ファイルを照合し、通常プロジェクトで変更したアプリ側ファイルは`ios/Podfile.lock`だけ。文書は本書、審査メモの注意書き、PROJECT_STATUSの追記に限定する。ストア掲載文面は不変。
- Git reset／clean／stash、Known Goodの変更、課金処理変更、IAP／Play Billing実装は行っていない。既存テストの全再実行も行っていない。
- 原本ロック・文書の変更前コピー、ソースのハッシュ一覧、隔離ソース、失敗を含むビルドログ、限定差分、未署名Releaseアプリは`/Users/gota/hamcare-deploy-staging/ios-store-preparation-20261018/`へ保存。署名鍵や個人認証情報は新たに取得・追加していない。
