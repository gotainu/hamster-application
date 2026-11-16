# HamCare 日本限定・両ストア公開準備（2026-10-18）

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

<!-- hamcare-safari-e2e-20261115:start -->
## 2026-11-15 戦略C・Apple Safari Web購入E2E（実Test決済・Portal・後始末完了／本番切替前の残件あり）

- **今回の再開承認**：本人が修正コミット `4892d48450fe` を承認し、同じ本人AppleアカウントによるiPhone Safari・Stripe Test Modeの購入E2Eを再開。コードは変更せず、問題時は停止して報告する。本番Stripe／Customer／Subscription／billing／体験／外部tester権限・Flutter・live Hosting・mainを変更しない。Test見積り・Customer／Subscription・隔離billing・Portalと、既存のTest予算／Webhook receipt／leaseの通常更新だけを使い、共通枠のリセットや上限変更はしない。結果確定後に既存文書2件だけを `docs(release): record Apple Safari web purchase E2E` で独立コミットする。
- **今回の開始状態**：`feature/web-first-stripe-checkout`／HEAD `4892d48450fecee3dc36d5604423ee6e1ad15d58`、未コミット差分は従来の本書／既存リリース記録2件のみ。コード差分なし、Preview accountはHTTP200／no-store。本人証跡でAuth exact1件・本人業務4文書・Preview3文書だけを20:31:31 JSTに読取り、owner／main_petあり、メールなしApple binding有効、production billingなし、fixtureなし、Preview見積りrootのみ・attemptなし・Test Customer対応なしを確認。過去の作成操作0の証跡と合わせ、同アカウントのTest Subscription／未完Session未作成を確認し、他人Customerの探索はしない。以前の3分見積りは期限切れでも通常手順で再作成可能。
- **今回のSafari本人確認**：Safariで再読込→Web logout→説明・同意→同じAppleで再ログインし、アカウント確認画面に到達。本人から「Safariログイン成功・古いエラーなし」の返答を受領した。コード上の現cross-origin PreviewはPopup方式であり、Redirect実機成功とは記録しない。
- **今回の実Test決済・反映**：本人がiPhone Safariで申込みを完了し、「有料登録が完了しました。」と表示、表示・入力とも問題なしと返答。20:39:54 JSTの同じ本人証跡による限定readで、Test Customer binding一致・Test Subscription1件active・Checkout Session1件complete／paid・未完Session0、即時Invoice550円（total／due／paidすべて550、paid=true、trial_endなし）を確認。契約期間は2026-11-15 20:37:31〜2026-12-15 20:37:31 JST。Preview billingはactive／paid・entitlement=trueで、同じUID／attempt／Stripe status／cancel／Invoice各照合true。対象Subscriptionに紐付く署名検証後processed receiptはcheckout.session.completedとcustomer.subscription.updatedの2件。未紐付けprocessing／retryable receiptは対象外で、Webhook全体pending0や実再送テスト成功とは記録しない。
- **今回のPortal実往復・支払方法変更・期間末解約**：本人がSafariの契約管理でTestカードを変更して既定設定、期間末解約予約後HamCareへ戻り、解約予定と利用可能期限が表示されたと返答。21:01:32 JSTの限定readで同じTest Customer／Subscription・同じperiod_endを維持、Subscription優先のeffective payment method指紋変更、status=active／cancel_at_period_end=true／期間末までentitlement=trueを確認。Previewもactive／解約予定／mirror=trueで全照合一致、Invoice550 paid保持・未完Session0・対象processed receipt4件。Portal専用設定は支払方法更新・請求履歴・期間末解約だけを有効とし、即時解約・顧客情報／メール変更・プラン変更・共有loginは無効。別UIDや他Customerを探索せず、既存のUID bindingガードを維持した。
- **今回のTest契約後始末・最終Webhook**：Portal解約予約を証跡に残した後、開始時Customerなし・今回作成時刻・本人binding・同Customer／Subscription・550paid・本番4文書保持を再照合し、承認済みの不要Test契約1件だけを21:03:48 JSTに即時終了（invoice_now=false／prorate=false）。21:04:44 JSTの別readでStripe canceled／有効Test契約0／未完Session0、Preview canceled／plan=none／entitlement=false、Stripe／cancel／権限／Invoice全照合true、customer.subscription.deleted processedを含む対象receipt計5件を確認。Customer・Webhook・テスト用owner／petは削除せず保持。期間末解約予約時の有効状態と、後始末の即時終了による最終失効を区別する。自然なWebhook反映と再読取では巻戻りなしだが、実Webhookの意図的な古いevent再送は未実施で、既存合成テストと区別する。
- **今回のVoiceOver・Safari最終本人確認**：本人が完了メッセージと「プラン確認へ戻る」をVoiceOverで読み上げ・操作できたと返答。後始末後、Safari再読込→契約アカウント／メール「未設定」／契約状態→プラン確認票の550円／自動更新／同意チェック／Stripeへ進むボタンの読上げ（押さない）→戻る→logout→Appleボタン読上げ→同じAppleで再loginの手順に対し「問題ない」と返答した。日本語の画面表示・カード入力時キーボード・Portal Web復帰も本人問題なし。21:09:55 JSTの同じ本人1件だけの最終readではTest Sessionは従来の完了1件のまま、同じcanceled Subscription1件・有効0／未完Session0・Preview失効と全同期照合true・本番4文書／Auth保持を再確認し、読上げ確認のための再決済は発生していない。
- **実測と未確認の区別**：現在のcross-origin PreviewはPopup方式であり、SafariでのAppleログイン／Web復帰成功をRedirect成功へ読み替えない。本人の今回のiPhone表示が正常なことと、360／390px両方の実機測定・blur非対応時のフォールバック実証は別で、後者は未実施。VoiceOverは上記8対象と戻る操作を実確認したが、即時同期で消えた「反映待ち」と、有効契約時の「契約管理ボタン」の実読上げは未確認で、追加契約して再現しない。実機で意図的に二重クリック／古いWebhook再送を発生させる試験も未実施で、既存idempotency／順序逆転の合成回帰と区別する。重大な操作不能・読み上げ不能の報告はない。
- **画面取得の最終結果**：本人が公開紹介ページを表示して撮影を許可したが、QuickTime取り込みには古い対象外frameが残っていたため、確認画像へ採用・保存しなかった。USB再接続後もQuickTimeの映像入力候補にiPhoneがなく、devicectlも端末情報を取得できず、公開可能な実機キャプチャは未保存。録画は開始せず、Apple認証／カード入力／Portal一時URL／ログイン後の非公開画面を保存しない。本人の実機目視・操作結果と限定サーバー証跡は成立しており、画像取得の環境制約をアプリ不具合や実画像PASSへ読み替えない。
- **今回の本番保護・保存**：Authは同じ既存Apple binding・メールなしを維持し、開始前→購入→Portal解約予約→後始末の各段階でowner／pet／trial／live billing内容指紋とAuth identityフラグはすべて不変。本番billingは未登録のままで、Test領収書用メールのAuth逆同期なし。本番Stripe／本番billing／既存本番契約変更0。隔離Test見積り・予算・mapping・receipt／lease・billingの正規更新は発生しており、Firestore総書込み0件とはしない。コード／Apple設定／デプロイ／Flutter／live Hosting／main変更は0、変更は既存2文書だけ。UID／Token／生のCustomer・Subscription・Session ID／メール／カード情報はGitへ保存しない。Test petは保持する。本タスクの同じPreviewは `https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account/`（既存version `f506c3ce46d86608`／期限2026-11-22 19:30 JST）を維持。匿名化した状態・内容指紋・必要日時だけをMacの本人用非公開監査フォルダへ保存し、今回の読取り・後始末用ローカル確認プロセスはすべて停止した。
- **本番切替準備へ進める条件・残件**：既存AppleメールなしアカウントによるSafari購入→署名検証後Webhook権限反映→Portal支払方法変更→期間末解約予約→Web復帰→Test契約終了の主要E2Eは成立し、準備作業へ進める。live公開・本番課金切替の承認とは扱わない。本番公開前に、Private Email Relay送信元登録、Firebase／HamCare・Stripe領収書・サポート各配送、既存公開法務の500円税込／旧名称と550円表示の整合・事業者表示確認を残す。未実測のVoiceOver2対象・実Safari Redirect・360／390両幅／blur非対応フォールバック・安全な実機画像も上記の範囲で区別し、Apple Case 103009817213は回答待ちを維持する。通常pet単独削除の安全な経路が未確認のため、テスト用owner／petは識別名で保持する。文書2件だけを指定メッセージの独立コミットとして保存し、merge／pushせず停止する。以下は前回の登録・停止までの経緯であり、今回の最新状態は本節冒頭を優先する。

- **承認と範囲**：Apple Webログイン `c4c767ab9360` を本人承認済み。既存の同UIDを使い、iPhoneの通常アプリでテスト用ペットを登録した後、同じHosting Preview／Stripe Test Modeで購入・Webhook・Portal・実Safari表示・VoiceOverを確認する。main merge／push、live公開、Flutter変更、本番Stripe／billing／既存契約変更、外部テスター利用、Apple設定変更は行わない。
- **登録前の事実**：2026-11-15 16:27:58 JST、以前の本人UID照合証跡と現在のApple Webセッションを照合し、Auth exact1件と本人のowner／main_pet／trial／live billingの4文書だけを読み取った。ownerとmain_petは未登録、live billingなし、メール未設定・emailVerified=false・既存Apple bindingあり。実UID・メール・Token・生データは記録せず、非公開監査領域へ存在確認・内容指紋・必要日時だけを保存した。
- **体験と今回の期待値**：既存trialは保存status=activeだが、終了日時は2026-11-14 16:13:40.771 JSTで期限経過済み。statusだけで有効と扱わず、今回のTest申込は即時550円／activeが期待値。体験延長・リセット・fixtureによる上書きは行わない。実決済結果と初回請求日時は未確認。
- **本人が承認した登録例外**：飼い主のニックネーム「Apple Web E2E Owner」だけの通常登録、ペット「Apple Web E2E Test」の通常新規登録、および識別・履歴等の付随保存と通常起動の通知トークン・起動スター更新を許可する返答を受領。地域・年齢・飼育経験は推測入力しない。pet通常保存はmain_petに加えてmutation／subject／history／revision／users markerの計6文書を対象とし、1文書の書込みとは記録しない。今回の許可された本番Firestore登録分と、購入フローによる本番billing書込み0件を分けて集計する。本人が飼い主・ペットとも「Apple Web E2E Owner」で登録し、Home表示を確認したと返答。17:49:29 JSTの同じ証跡を使うexact読取りでownerとmain_petの存在、Auth identity一致、trial内容指紋／更新時刻とlive billing未登録が登録前と不変であることを確認した。Chrome Webのペット未登録ガードも消え、月額プラン確認が利用可能。通常登録の付随文書すべての実write回数や起動付帯更新回数は未計測のため、総書込み0件や厳密な総回数は主張しない。
- **ガードと後始末**：現行契約ガードの必須存在条件はmain_petであり、owner欠損時はニックネーム未設定表示となる。ガードは変更しない。既存ペットが表示された場合は上書きせず停止する。通常のpet単独削除機能は確認できず、アカウント削除や直接DB削除は代用しない。完了後の安全な削除が確認できなければ、明示したテスト名で保持する。
- **実機と未実施**：本人のUSB接続返答後、QuickTimeの画面入力を接続端末へ切替え、録画せず表示プレビューを準備。本人からiPhone SafariでAppleログイン後のアカウント確認画面を表示できたと返答。直前の一瞬のpopup-blocked相当案内は本人がLINE内ブラウザで開いた操作によるものと説明し、Safariの不具合確定とはせず追加調査を中止。本人はプランの550円税込／500円税抜・月次自動更新・申込時550円・契約ニックネームの一致を確認したと返答。ただし最終checkout reviewの成立とは区別する。Embedded決済・Webhook・Portal・期間末解約・VoiceOverは未実施。blur・360／390px・キーボード・戻る操作の実機詳細は未確認。現cross-origin PreviewはPopupを使うため、実Popup復帰とRedirectを区別し、設定を変えてRedirectを強制しない。360／390pxの実機表示とMac Responsive Design Modeも別結果として扱う。
- **画面取得の安全境界**：ログイン後のiPhone画面の未加工取得は自動承認レビューが個人情報・請求情報を露出し得るとして拒否。該当取得は未実行、回避せず、本人の画面確認と限定read-only証跡を利用する。Safari以外を表示した直前の対象外frameは確認画像・成果物へ採用しない。公開可能な実機画面キャプチャはまだ未保存であり、保存済みとは扱わない。
- **購入前Preview境界**：17:52:25 JST、本人証跡で限定したnamespaceのroot／fixture／Preview billingはすべて未登録、Test Customer対応なしを確認。既存fixtureや別アカウントのTest契約は流用しない。購入・Session作成・Stripe書込みはまだ0。
- **停止理由（要修正）**：`public/assets/checkout-model.mjs:14` の `projectCheckoutReview` は `raw.account.maskedEmail` を伏字メール形式のみに限定している。一方、`preview-functions/src/index.ts:37,63` はメールを持たない正規Appleの表示値として固定文字列「未設定」を返す。既存moduleへ同じ合成reviewのメール表示だけを変えて与えた限定2ケースで、正規伏字は受理、「未設定」は `preview/invalid-response` となることを再現。Controllerのreview投影で停止するため同意／Session作成へ進まない。本人へ直前のStripe申込案内を取り消して停止を伝えた。その後、本人からiPhone Safariでも「申込内容を安全に確認できませんでした。」と表示され、エラーで進めないとの返答を受領。合成再現だけでなく実機でも同じ契約確認の停止を確認した。Auth・petガード・Stripe設定を緩和せず、コード／配信は変更しない。
- **停止時点の証跡**：18:12:17 JSTの同じ本人証跡による限定readで、本人UIDとbinding一致のPreview rootが新規作成され、attemptなし・fixtureなし・Preview billingなし・Test Customer対応なしを確認。サーバーreviewの見積り保存による隔離namespaceの書込みが発生したもので、Stripe Customer／Session／Subscriptionの作成やWebhook成功ではない。既存アプリUIDに対応する見積り要求が受け付けられたことと、最終画面・決済成功を区別する。本タスクのlive Stripe／本番billing／既存契約変更は0。許可済みowner／pet通常登録とPreview見積り保存まで含めたFirestore総書込み0件とは記録しない。
- **最小修正案（未実装・本人判断待ち）**：`projectCheckoutReview` で、従来の正規伏字メールまたは厳密な固定値「未設定」だけを許可する。null・空文字・生メール・任意文字列の拒否は維持。model／checkout viewにメールなしAppleのreview受理、同意前Session作成0回・同意後1回の回帰を追加する。サーバー認証・Apple設定・価格・Customer／Subscription／Webhook・native変更は不要。修正の承認後、同じ本人アカウントでSafari E2Eを契約確認から再開する。今回の既存892 runtime／391 static PASSでこの欠落を検出できたとは扱わない。
- **後始末と残件**：この時点で終了すべきTest Subscriptionはない。期限付きPreview見積りを消すための直接削除はしない。テスト用pet／ownerは承認済みテスト名で保持し、通常pet単独削除が未対応のため削除しない。Safariの安全な公開画像・VoiceOver、実決済からWebhook／Portal／期間末解約／Test契約終了の実証、Private Relay送信元／Firebase・HamCare・Stripe領収書・サポート配送は未完了。既存公開法務の500円税込・旧名称とPreview550円の整合、事業者表示の確認は本番切替前の残件として維持し、このタスクで法的判断や文面確定をしない。
- **保存状態**：Web worktree開始時はクリーン、HEADは承認済みc4c767ab9360。今回のコード変更・デプロイ・Stripe書込みは0、文書更新のみ。Preview review用見積り保存は上記の隔離データ書込みとして別記する。既存の合成892runtime／391static PASSは引き継ぎ、今回の実機E2E PASSへ読み替えない。Private Email Relay送信元登録、Firebase／HamCare配送、Stripe領収書、サポート配送は引き続き本番公開前の残件。
<!-- hamcare-safari-e2e-20261115:end -->

<!-- hamcare-apple-missing-email-review-fix-20261115:start -->
## 2026-11-15 戦略C・Appleメール未設定の契約確認修正（実装・実Preview限定確認完了／決済E2Eは次の本人承認待ち）

- **対象と保護**：承認済み `c4c767ab9360`／`feature/web-first-stripe-checkout` を維持。開始時の未コミット文書2件は内容指紋を保存して保護し、本文を改変せず今回の記録を別節へ追加。既存E2E節・管理行の未コミット差分を今回のコミットへ混ぜない。main操作、Flutter／Apple設定／認証サービス／サーバー認可・契約ガード・Stripe Customer／Subscription／Webhookの変更なし。
- **原因と表示契約**：正規Appleのサーバー応答「未設定」を `projectCheckoutReview` の伏字メール必須条件が拒否していた。APIの固定値を維持し、null／hasEmail等への広範変更はしない。現在の本人確認済みAppleセッション、captured User／UID／generation、同じUIDのowner／main_petのserver-read、サーバーが返した正確な固定値、応答objectそのものが揃った場合だけservice内WeakMapで記録する。modelはmodule内で登録されたservice verifierだけを受け付け、裸の固定値・独自のtrue判定・複製応答は拒否。切替・clear・Apple subject変更／欠損／重複後も無効。証跡はメモリのみで、Tokenを保存せず、UID／subjectを画面・URL・ログへ追加しない。通常の正規伏字メールの経路は維持。
- **メールの意味**：契約主体・Customer解決は従来どおりUID。サーバーが未確認のAppleメールを省略した場合も正規の「未設定」応答として扱い、Auth.email／emailVerifiedを書き換えない。架空メールへの補完・Stripe連絡先のFirebase逆同期なし。今回Customerメール処理の変更・Customer／Session／Subscription作成は0。
- **一瞬のログイン案内**：本人はLINE内ブラウザで開いた事象と説明しており、実Safari原因を断定しない。コード上にあった正常読取後の遅いpopup-blocked通知の競合だけをUI側で最小修正。同じApple試行のfresh本人確認＋成功した現在アカウント読取だけで古いPopup通知を抑制／消去し、取消・通信・provider衝突・読取失敗は維持。logout／pagehide／破棄／別ユーザーの古い結果を無効化。Popup→Redirect fallbackは存在せず追加しない。現cross-origin PreviewはPopupを維持し、同origin固定authDomain時だけRedirectとする既存選択条件も不変。[Firebase Apple公式](https://firebase.google.com/docs/auth/web/apple)はmobileでRedirect推奨だが、[cross-origin storageの公式対策](https://firebase.google.com/docs/auth/web/redirect-best-practices)を満たす必要があり、この小修正で認証ドメイン・Apple設定を変更しない。
- **限定検証**：frontend全357件（今回新規41件）・既存Preview policy91件、計448 runtime PASS。静的account142／brand165／LP84の391件PASS、TypeScript noEmit・JavaScript構文・diffチェックPASS。正規go伏字、正規Apple未設定のreview表示、同意前Session0／同意後1回は合成テストで確認。空／空白／任意文字列／UID風／生メール／未認証／空UID／owner-pet欠損／別UID／clone／失効証跡を拒否。既存メール・Google・Apple正常経路を維持。全テストはmock／オフラインで実Firestore・Stripe書込みなし。初回のdefault Node／functions側TypeScript探索失敗は、更新・installせず既存Node22と既存preview依存のコマンド限定参照で解決した環境要因として分ける。
- **Previewと本番保護**：同じchannel `web-first-task1` へ最終 **2026-11-15 19:30 JST**、version **`f506c3ce46d86608`**、期限 **2026-11-22 19:30 JST**。公開35ファイルSHA／安全ヘッダー一致、除外6経路404。live version `2365135bf558c278` と既存57 Functionsの状態／更新日時は不変。Functions・Rules・Auth設定のデプロイなし。
- **実Preview限定確認**：本人が「本人用Preview見積り1件の保存だけ許可する」と追加承認。既存Apple Webセッションを維持したChromeで最終Previewを再読込し、同じ本人アカウント・ニックネーム・メール未設定・pet未登録案内なし、月額550円／税抜500円とプラン選択を確認した。reviewボタンを1回だけ押し、サーバーの正規応答と本人UID配下owner／petの読取りを通過して、最終契約確認にニックネーム・「未設定」・550円の即時請求表示が出ることを確認。20:04 JSTに識別子を含まない検証記録を保存し、以前の「申込内容を安全に確認できませんでした」は出なかった。確認用チェックを付けるとStripe開始ボタンが有効化されることだけを確認し、開始ボタンは押さずチェックを外してdisabledへ戻した。新たなApple再認証・Safari実機最終review／Stripe決済E2Eは再開していない。
- **書込みと停止**：追加承認された期限3分のPreview見積り1文書保存だけを実施（review操作1回）。本番業務プロフィール・体験・billingへの書込み0、Stripe書込み0、Customer／Session／Subscription作成0、既存契約変更0。総Firestore書込みを0とは記録せず、隔離Preview見積り1件を明確に例外計上する。期限切れ見積りの削除や再発行は行わない。今回の修正コード・回帰テスト・本節だけを `fix(web): allow verified Apple accounts without email` の1コミットへ保存する。成立と最終hashはGit履歴・完了報告を参照。本人の修正版採用承認後に、Safari実機の決済／Webhook／Portal等のE2Eを再開できる準備までとし、今回の承認で自動再開しない。
<!-- hamcare-apple-missing-email-review-fix-20261115:end -->

## 2026-11-15 戦略C・タスク8：Apple Webログイン有効化（実装・実UID一致確認済み／実購入E2E保留）

準備コミット `94571d9a71af` は本人承認済みで改変しない。事前明示同意付きのFirebase標準trusted-provider連携を許容し、独自メール比較によるUID統合・別UIDへのコピーをしない方針で実装した。1メール1アカウント、既存メール／Google、UID基準のCustomer・Subscription・Webhook／billing構造は維持。実Appleログイン・UID一致は確認した一方、本人アカウントのpetガードで実購入E2Eは保留であり、全要件完了とは扱わない。

### 設定・同意・認証方式

| 項目 | 最終結果 |
| --- | --- |
| Services ID／Primary | `com.gotainu.hamster.web` を本人のRegister後に確認し、既存HamCare Primary App IDへ関連付けて保存。既存Bundle ID・Team・native設定を維持。 |
| Domain／Return URL | 固定 `hamster-breeding-app.firebaseapp.com`／`https://hamster-breeding-app.firebaseapp.com/__/auth/handler` を確認概要からSave。固定handlerでの実Chrome Appleログイン成功で経路を確認。一時Preview URLのApple登録・live Hosting公開なし。 |
| Key／Firebase | 既存Sign in with Appleキーを再利用し、新規作成／失効／置換なし。本人がFirebaseへ鍵を直接入力・保存し、Service／Team／Key参照・秘密鍵設定の一致を値非表示で確認。Key ID・秘密値・個人UID等を本書／Gitへ保存しない。 |
| 明示同意 | 標準仕様の既存アカウント関連付け、非公開メール中継、独自統合／コピーなしを事前説明。未同意ではUI／serviceとも開始不可。取消・ログアウト等で同意を消去、公式Appleボタンを維持。 |
| Popup／Redirect | 現cross-origin Previewでは標準SDK Popup。同一origin固定authDomain＋モバイルSafari＋短期同意状態が回復可能な場合だけRedirectを選択。マーカーは15分の非秘密同意情報だけでSDK state／nonce／CSRFの代用にしない。実Safari OAuth／Redirectは未確認。 |

### 実Appleログイン・本人UIDの比較

- 最初のメールexact1件lookupは一致0件だったが、その入力元はiPhone Apple ID設定だったと本人確認できた。HamCare未登録の証明とは扱わず、追加メール探索・全Auth一覧取得へ広げなかった。全Auth一覧は自動承認レビューが本人以外の個人情報取得として拒否し、コマンド未実行・取得0。
- 本人がiPhoneの表示と既存Firebase Auth UID全文一致を確認し、非公開画面へUIDを直接入力。localId exact1件で既存Apple bindingを確認し、salt付き仮名証跡を準備した。その後、実Chrome Appleログイン済みWeb SDKと比較し、**projectMatch=true／appleProvider=true／uidMatch=true** を確認。nativeとWebが同じUIDで、メール状態は **emailPresent=false／emailVerified=false** のまま。実UID・メール・Apple subject・private入口／proof値は文書／ログへ転載しない。
- 初回比較器のrecency=falseは、最終の静的診断で日時有効・未来ではない・15分超過と確認した。日時不正・Apple認証失敗・UID不一致とは扱わず、有効な通常Firebase sessionへ新しい15分制限を導入しない。
- nativeのscope未指定経路とemailなし時のUID表示は限定読取りで確認したが、メール未取得の原因は断定しない。Webはemail／name scopeを要求したが、今回メールは正規フローでも補完されなかった。Auth管理編集・メール補完・Flutter変更は行わない。

### メールなしAppleのPreview限定互換

- `preview-functions/src/auth-policy.ts` はAdmin `verifyIdToken(...,true)` 後、token UIDと同じ有効Admin User・現在providerがApple・tokenのApple subject1件とAdmin provider binding1件の厳密一致から別`authBasis`を作る。実emailVerified=falseをtrueへ偽装しない。メール／Googleは従来のtokenとAdmin両側のverified条件を維持し、Google sessionへAppleがlink済みというだけでは例外にしない。
- フロントもfresh SDK tokenのproject／issuer／UID／current provider／subject bindingを検証し、同UIDでもUserオブジェクト入替・logout・遅延結果は破棄する。transportは401だけ1回再検証し、ネットワーク／業務エラー／不明な決済結果は再送しない。authBasis・UID・メールはHTTP bodyへ渡さず、サーバーが独立検証する。
- 未検証メールはStripeへ渡さず、Customer作成時はemail属性を省略。UID対応表・既存Customer再利用・Test 550円月額・元trial終了・Webhook／署名・lease・固定returnを維持する。本人認証の確認と有料権限の付与を混同せず、本番User.emailVerified・業務データは変更しない。

### 限定動作結果と実購入E2Eの保留

- 最終Previewをhard reloadしても再ログイン不要でaccount panelへ進み、メール確認未完了／読取り不能パネルでは止まらなくなった。一方、main_pet未登録案内とplan無効は維持された。
- 実read-only billing APIは認証拒否ではなく`app_account_required`で停止し、Apple本人確認を通過した後の既存petガードが働いた。Stripe／Firestore writerは呼ばない。Native `PetProfileRepo`とWebの正本は同じ `users/{uid}/pet_profiles/main_pet` であり、別collectionへのパスずれは確認できなかった。この本人UIDのmain_pet登録は確認できず、理由を推測せずデータ作成／ガード回避をしない。
- このため、**Apple経由の実Embedded決済・Webhook反映・Portal往復は未実施で保留**。既存の課金経路検証や今回の合成テストを、この実購入E2EのPASSへ読み替えない。実メール共有／非公開メールの別ケース、実同メールGoogle／Apple連携、実Safari OAuth、実スクリーンリーダーも未確認。同メール連携の証拠はEmulatorに限る。

### 検証・Preview配備・本番保護

- frontend316／backend445／policy91／Apple Auth・Firestore Emulator25／旧Auth Emulator15のruntime計**892件PASS**。静的LP84／account142／brand165の計**391件PASS**、TypeScript／`git diff --check` PASS。非公開照合helperのオフライン24件PASSは別枠で扱う。
- 同じchannel `web-first-task1`、最終Preview version **`268f5115e3afec45`**、期限 **2026-11-22 15:37 JST**。新identity moduleを含む公開35 resourceのSHA／安全ヘッダー一致、除外6経路404を確認。Apple entry=true・同意必須、既存メール／Googleとブランド表示を維持する。
- 更新対象は既存Preview Checkout／Portalの2 FunctionsだけでAPIからACTIVEを確認。他55 Functions（Task5 Webhookを含む）のstate／updateTimeは不変。CLIはcleanup policy未設定の後処理警告により終了1だったが、対象2件の配備成功・API ACTIVEを区別して記録し、cleanup設定は変更しない。Functions resource全体のhash一致までは主張しない。
- live Hosting、Auth policy・Authorized domain、元アプリHEAD・dirty10件SHA・全2,120行status、無関係な保護12ファイルSHAは保持。承認済みApple Provider設定以外の本番認証方針・署名・Rules・ストア設定を変更しない。
- 今回の新Auth作成・業務を含む本番Firestore／Stripe書込み・既存契約変更は0。新規Appleは専用Emulatorで検証し、既存Auth onCreateによるjourney書込みを迂回しない。private helperの個別readと、Authユーザー作成／本番業務writeを区別する。

### Private Email Relayと次の確認

FirebaseはDEFAULT送信・SMTPなし・custom domain未開始、確認／再設定／変更通知のsender local partはnoreply。既定Firebase送信元と必要な公開サポート送信元を、Apple DeveloperのServices → Sign in with Apple for Email Communication → Email Sourcesへ個別登録し、SPF／DKIMを確認する手順を整理した。[Apple公式手順](https://developer.apple.com/help/account/capabilities/configure-private-email-relay-service/)、[Firebase公式Apple設定](https://firebase.google.com/docs/auth/ios/apple)

登録・配送試験は未実施。Stripe領収書／契約通知の実From・Return-Path／Dashboard設定も未確認で、推測による登録や大量のメール送信をしない。ログインとメール到達は別結果とする。実購入E2Eの再開には、本人の既存main_pet登録状態を通常経路で確認し、承認範囲内のテストアカウント条件を整える必要がある。今回データを新規作成したりガードを回避したりはしない。

### 保存して停止

今回の実装・設定・実Appleログイン・native↔Web UID一致確認を `feat(web): enable Sign in with Apple` の1コミットへ保存予定。実購入E2Eと未確認ケースは残件として維持し、全要件完了とはしない。コミット成立と最終hashはGit履歴・完了報告を参照する。準備コミットの改変／squash、main merge／push、live公開、本番課金・契約変更、Flutterアプリ変更を行わず、保存後停止する。

## 2026-11-15 戦略C・タスク7：Apple Webログイン準備（94571d9a71af・本人承認済み）

本人の追加指示で準備コミットを承認済み。以下の標準自動linkの扱い・停止条件は当時の履歴であり、現在は先頭のタスク8の新方針・確認結果を優先する。

本人承認済みタスク6 `a2e73511ecef` から同じ専用ブランチ・PreviewでApple Webログインを準備。既存メール／Google・プラン・Embedded・Webhook・Portalは維持する。一方、Apple Developer設定と同一メール自動link／Auth新規作成時の本番書込みに未解決事項があり、一般有効化しない。今回分を `feat(web): add Sign in with Apple` の1コミットへ保存し、本人の設定完了返答後の読取り・表示確認結果も同じコミットへ含めて停止する。実Apple成功や全要件完了とは扱わない。

### 既存Apple構成・必要な本人設定

| 項目 | 確認済みの事実／未実施 |
| --- | --- |
| native iOS | 既存 `AppleAuthProvider` による通常Appleログインは過去の本人確認済み。既存Bundle ID `com.gotainu.hamster`／Team `3SA77V3SM7`を維持し、Flutter・署名は変更しない。本人操作後のApple設定ダイアログで既存App IDの「Enable as a primary App ID」選択済みを確認し、変更せずCancelした。 |
| Firebase Provider | API読取りでApple enabled=true、Web client IDなし・OAuth Key設定なし。nativeの成功とWeb未設定を区別し、native設定不良と断定しない。Key ID・Private Key・認証コード等は取得／文書保存しない。 |
| Apple Developer | 当初Access Unavailableだったが、本人から最新PLA同意・ログイン完了の返答を受け、設定画面へのアクセス復旧を確認。既存Sign in with Appleキー1件が既存App IDへ関連付いている。Downloadは無効、既存秘密鍵の保管先・利用可否は未確認。Key ID・秘密値を記録せず、削除・置換・再発行・設定保存はしない。 |
| Service ID | Services IDs一覧がGetting Startedで登録0件と確認。**`com.gotainu.hamster.web` は未作成の提案値**で、確認済みの既存Primary App IDへ関連付ける案。実登録や設定変更はしない。 |
| メール中継 | Sign in with Apple for Email CommunicationのEmail SourcesはNo result found、登録0件。必要な送信元の登録・到達検証は未実施で、ログイン成功やrelay配信成功とは扱わない。 |
| Domains・Return URL | 現authDomainの固定 `hamster-breeding-app.firebaseapp.com` と標準web.appホストをWeb Domains案にし、Return URLは **`https://hamster-breeding-app.firebaseapp.com/__/auth/handler`** へ固定する案。既存HandlerはHTTP200。Appleへ一時Previewドメインを恒久登録しない。 |
| Preview／本番の関係 | Firebaseで既存許可済みのPreview domainは保持。標準固定Handlerを使うためのlive Hosting公開は不要で、今回実施しない。本番も固定Handlerを使う案とし、Preview終了時に一時許可だけを削除する。既存固定ドメインを削除しない。 |

### 実装準備と安全上の停止条件

- Apple公式日本語PNGを無加工で表示する準備と、Firebase標準SDKのOAuthProvider／Popup、email・name scope、日本語の取消／衝突／失敗案内を追加した。`appleSignInEnabled` はfalse、通常UIはdisabled／設定確認中を維持する。UIの公開flagはFirebase全体のセキュリティ制御ではなく、一般有効化が安全になったとは主張しない。
- OAuthのstate／nonceは標準SDKへ委ねる設計で、実Appleフローでは未確認。Apple subject・UID・token・codeを独自保存／URL露出しない。実アカウント値や秘密はGitへ記録しない。
- アカウント確認は同じ本人UIDの既存3文書に `pet_profiles/main_pet` 存在確認を加える4文書読取り。アプリ登録済みの存在が確認できなければ、プラン・契約へ進めない。新UIDへ他UIDのプロフィール・ペット・体験・契約をコピー／移行しない。メールをStripe紐付けの正本にしない。
- **同一メールの自動linkは未解決**：Firebaseのtrusted Apple providerでは同一メールの既存別providerへ自動linkする場合があり、アプリにlinkWith呼出しがないだけでは防げない。Emulatorでも既存password UIDへlinkされる挙動を観測した。統合防止のPASSではなく、一般有効化を妨げる制約として記録する。globalの重複メール許可設定は変更しない。
- **新Auth作成による本番書込みも未解決**：既存 `analyticsAccountRegistered` はAuthのonCreateから本番journey文書を保存する。Apple新規ユーザーを無条件で作る経路は本番Firestore書込み0要件を満たせない。既存triggerやRulesを変更して迂回せず、新規Auth実作成は行わない。
- **次の案は未実装**：Apple provider identityをサーバーで照合し、既存Firebase UIDにだけ認証する限定方式を提案する。メール比較・新Auth作成・UID統合を行わない設計を別途検証し、本人判断後に進める段階。設定同意後に通常Popupを開放するだけで完了とはしない。

### 検証・未確認・停止

- frontend197件、backend383件、既存policy84件、既存Stripe pure unit21件、既存Auth Emulator15件、専用Apple Auth／Firestore Emulator19件の計**719件PASS**。静的はLP84／account124／brand163の**371件PASS**、strict TypeScript／`git diff --check` PASS。
- Apple Emulatorは明示的なPopup stubから実Emulator credential交換を使い、合成Apple subject→seed UID、公開／非公開メール形、2回目のname／email欠落、異subject別UID、新UIDにmain_petがない場合の契約拒否、変更していない本番RulesのcrossUID／billing書込み拒否、ログアウトを確認した。実Apple OAuth／署名／state／nonce／iOS実UID一致を確認した代用にはしない。
- 既存Auth Emulatorは専用Task2 projectへ再起動後に15件PASS。初回9失敗はTask7 default projectとTask2 fixtureの不一致であり、差分コードの失敗とは区別。合成同一メールの自動linkは観測結果で、防止成功として数えない。
- 同じchannelのPreview version **`354b4f1c6ac4c40f`**、期限 **2026-11-22 11:43 JST**。公開34ファイルのSHA／安全ヘッダー一致、除外6経路404を確認。live version `2365135bf558c278`・Firebase Apple Provider／Auth project configの前後hash一致、既存57Functionsの状態／更新日時不変を最終照合した。元アプリHEAD・dirty10ファイルhash・未追跡を含む全2,120行のstatus、保護8ファイル、Preview設定も不変。
- 本人のMac解除後、Safari Responsive Design Modeの360×844／390×844で実スクリーンショットを目視し、無効Appleボタンと設定待ち説明の文字切れ／横はみ出しがないことを確認。物理iOS Safariの確認とは区別する。公式PNG自体の寸法・内容・出典SHAは確認した。実Appleの既存／新規ユーザー・メール公開／非公開・再ログイン・取消・Safari／モバイルChromeのOAuth、native iOS↔Web UID一致、Apple経由のEmbedded／Webhook／Portal往復は未確認。既存native本人確認、既存課金経路の検証と混同しない。
- 今回の実Appleログイン・新規本番Auth作成・本番Firestore／Stripe書込み0。Apple／Firebase設定変更、既存契約／テスター権限変更、Flutter／ストア・live Hosting公開は行わない。本人のPLA／Macロック待ちは解消。Service ID登録・Primary関連付け・固定Return URL・既存秘密鍵の安全な利用確認とFirebase Web設定、必要なメール中継設定、および自動linkを防ぐ安全方式の判断が残る。同じ1コミットへ確認結果を保存後に停止。物理端末E2E・本番切替へ進まない。

## 2026-11-15 戦略C・タスク6：Preview用Customer Portal（a2e73511ecef・本人承認済み）

本人のタスク7指示で上記コミットを承認済み。以下はタスク6実施時の検証・制約の履歴であり、現在の作業・停止点は先頭のタスク7節を優先する。

本人承認済みタスク5 `283a8114e524` を起点に、同じ専用ブランチ／Hosting PreviewへTest専用Customer Portalを追加。既存LP・認証・プラン確認・Embedded・Webhook／隔離billingを維持した。今回分を `feat(web): add subscription management portal` の1コミットへ保存した後に停止し、次工程は本人承認後とする。コミットの成立・ハッシュはGit履歴と完了報告で確認する。

### 実装・有効機能・認可

| 項目 | タスク6の実装と証拠 |
| --- | --- |
| 専用設定 | Test Modeの非default・Preview専用Configuration。支払方法更新・請求履歴・期間末解約・任意の標準6理由を有効化。Customer Updateの全情報、プラン／価格／数量／Promotion Code、即時解約、新規契約・追加商品、pause・共有ログインは無効。at_period_end／prorationなし。解約理由未回答のまま予約できることを実画面で確認した。 |
| ブランド | 専用headline・Privacy・規約だけを設定。事業者名・ロゴ・色・サポート等の共有設定を本番保護のため変更しない。locale=jaでも一部Billing／Reasonの英語が残るが、Stripe提供文言やDOMを不正に上書きしない。 |
| Function | 別名 `createPreviewStripeCustomerPortalSession`。Adminで失効・UID・メール確認等を検証し、空objectのPOSTだけを受け取る。UID／メール／Customer／Subscription ID・金額・任意return URLをクライアント入力から採用しない。Origin・JSON・サイズ・パス・queryも制限する。 |
| UID・Test分離 | 本人UIDのhashから既存Preview Customer対応を取得し、Customer metadata・最新Subscription・Price・専用Configuration・Webhook設定を確認。Live／他UID／未契約／取得不能は拒否。メール検索・Customer作成・本番契約管理はしない。Task4の終端履歴2件だけはUID field欠損かつ同Customer／scope／hash／Priceが一致する場合に読み取り許容し、管理対象化や履歴補完は行わない。 |
| 管理対象 | trialing／active／past_due等の管理可能な契約だけにボタンを表示。past_dueは支払方法の確認を案内し、新Checkoutや重複Subscriptionを作成しない。管理可否と有料権限は別であり、支払確認が必要な状態へ新しい猶予を付けない。 |
| 復帰 | 同じPreview originの固定 `/account/?portal=return` へ戻り、既存ログインと最新Preview billingの再読込みを確認する。URLを任意指定できず、Open Redirectを防ぐ。ブラウザBackでの復元時も待機解除・最新状態取得を行う。 |
| 保存・発行上限 | Sessionは操作ごとに新規作成。Portal URL・カード詳細をDOM／独自永続化／Firestore／本体ログへ保存しない。隔離namespaceの専用counterに回数だけを保存し、3秒間隔・10分20回／1日80回で制限。Checkout quotaやアプリ体験・利用枠とは分離する。 |
| 利用者への案内 | Stripeでカード変更・請求履歴・期間末解約ができること、有効な契約は期間末まで利用できること、自動返金ではないこと、HamCareがカード情報を保存しないことを説明。解約理由の自由記述に個人情報を書かない案内と、管理終了時にStripe画面も閉じる案内を表示する。 |

### 限定検証・実操作と限界

- **runtime623件PASS**：backend383、frontend140、既存policy84、Emulator16。認証／UID／設定／固定復帰先／Test/Live／quota／状態／多重操作・URL非保存・BFCache復元・ログアウト等を検証。静的はLP84／account113／brand157の**354件PASS**、strict TypeScript compile／`git diff --check` PASS。既存依存・SDKは更新しない。
- **本人Webの実操作**：Firebaseログイン→Portal、正常Testカード変更、理由未回答の期間末解約予約→期間末までの権限mirror維持→予約取消、固定returnで最新billing表示を確認。Tab／EnterでPortalへ進み、ログアウト後に管理カードを消すことを確認した。本人の本番業務4文書SHAは前後一致。支払方法はSubscriptionのdefaultを優先し、未設定ならCustomerのinvoice defaultを使う順序と、実Invoiceで使われた方法を照合した。実UIDの値・個人の日時は記録しない。
- **別Clock fixtureの実操作**：実UIDのWeb E2Eと別に、Auth Emulator UID＋engineの専用Clock fixture2件で3D Secure・拒否・変更取消を検証。新PMが初回550円と翌月550円に使われたことを確認。失敗側は同Subscriptionのpast_due→カード更新後active／550円paidへ回復し、新Checkoutを作らない。成功側はPortal解約予約→Clock期間終了canceled／mirror=falseを確認した。
- **真正Event再送**：成功側9件を2巡して重複18回・回復0、失敗側9件を2巡して重複14回・回復4。最新正本の再取得後もcanceledを維持。最終監査ではreceipt53件すべてprocessed、retryable／processing／error0。本人の真正イベントでsubject_busyだった2件も原bytes・新署名で各1回再送して200へ回復し、canceled／mirror=falseを維持。DB直接編集による回復は行わない。
- **Portalの実請求履歴**：本人の0円／過去550円、成功Clockの0円／初回550円／翌月550円を一覧で確認。失敗Clockでは0円Invoiceと550円の失敗表示を確認し、カード更新後に同じ550円Invoiceが支払い済みへ変わったことを確認した。将来日時はClockの仮想時間で、実請求・実経過月とは扱わない。返金／void／uncollectibleは新たに作成せず、実表示未確認として区別する。
- **URL寿命の制約**：未使用Session URLの5分失効を実確認。利用開始後はStripe側の最終操作から1時間以内に失効する仕様で、HamCare／Firebaseログアウト時に既発行Sessionを即時失効するAPIはない。ログアウト後の新発行拒否・本体表示消去と、既に開いたStripe画面の寿命を分けて記録する。
- **表示確認**：Chrome360／390／430／768／1440pxで目視・横はみ出しなし。Safari実ブラウザはdesktop／390pxのログイン画面だけを確認。Safari認証後Portal往復・物理Android／iOS・実スクリーンリーダーは未確認で、全実機PASSとは記録しない。
- **非公開観測の是正**：旧検証helperがTest Portal／Invoice URLを一時出力したため、後続観測器を全面マスクへ修正。本体のserver／アプリログ、Firestore、GitへURLを保存しない検査と区別し、ツール履歴にも一切出力なしとは主張しない。本書へ実URL・識別子は転載しない。

### Preview・本番保護・後始末・停止

- 同じ既存Preview・channel `web-first-task1`、最終version **`94a1f8464397f250`**、期限 **2026-11-22 10:40 JST**。新Portal Functionと既存Preview申込Functionの2対象だけを配備してACTIVEを確認。Task5 Webhookは再配備せず、state／updateTimeは不変。
- 本番54 Functionsのstate／updateTime、live Hosting release SHA／version、Auth許可ドメイン4件、保護13ファイルSHA、元アプリHEAD・dirty10件SHA・全2,120行のstatusは開始時と一致。Portal設定専用Secretを追加して既定runtime SAだけへ権限付与し、本番Secret・共有brandingを変更しない。
- 本番Stripe・Customer／Subscription・業務billing／体験／既存テスター権限への変更0。本番業務と異なるPreview namespaceにはcounter・同期等の書込みがあり、Firestore全体の書込み0とは記録しない。
- 最終監査でTest Customer5件、readyのTest Clock4件を保持、Subscription10件すべてcanceled・有効0、open Checkout0、有効fixture0を確認。Invoiceはpaid15件（550円paid7件）とopen1件で、元Task5の550円失敗証拠を保持。receipt53件は全processed、retryable／processing／error0。Webhook／専用設定／Secretは再利用・遅延通知確認のため保持する。
- Task6だけを指定メッセージで1コミットに保存し、本人承認まで停止。main merge／push、live Hosting、本番Stripe／billing、Flutter／ストア変更は行わない。

## 2026-11-14 戦略C・タスク5：Preview専用Webhook・契約状態同期（283a8114e524・本人承認済み）

本人のタスク6指示で上記コミットを承認済み。以下はタスク5実施時の検証・未確認の履歴であり、最新の作業・停止点は先頭のタスク6節を優先する。

本人承認済みタスク4 `b94eb7a5f2c0` を起点に、同じ専用ブランチ／Hosting Previewでタスク5だけを実装した。本番アプリの権限は変更せず、Test Subscriptionの最新状態を署名検証済みWebhookから隔離billingへ同期し、同一申込の反映完了をWebで確認する。今回分を `feat(billing): sync preview Stripe subscriptions by Firebase UID` の1コミットに保存した後で停止し、Task6 Customer Portalは本人承認後とする。コミットの成立・ハッシュはGit履歴と完了報告で確認する。

### 実装と分離境界

| 項目 | タスク5の実装・証拠 |
| --- | --- |
| Webhook | 別名 `stripePreviewWebhook` と既存Preview申込Functionだけを配備。raw body署名・300秒以内の署名時刻・Content-Type・Test Modeを確認し、不正署名／古い時刻／Live flagを拒否する。登録先とハンドラは checkout.session.completed、customer.subscription.created／updated／deleted、invoice.paid、invoice.payment_failed の6イベントで一致。 |
| Secrets | credentials／Price／Webhook設定の専用3 Secretだけを参照し、本番Secret・Webhookを流用しない。Webhook URL・署名SecretはGit／HTML／JavaScript／Firestore／ログに保存しない。本書にもendpoint名だけを記載し、URL・実UID／メール／Customer／Subscription／Event ID・個人の体験日時は転載しない。 |
| UID照合 | Admin検証済みFirebase UID→専用Test Customer→Test Subscriptionのmetadataと隔離対応表を照合する。メール一致で紐付けず、別UID・scope／価格不一致・Live objectは安全拒否。一般HTTP入力からUID・体験日時・金額・Price・Customer IDを採用しない。 |
| 保存先 | `preview_checkout_task4/{sha256(uid)}/billing/subscription`、同namespaceの対応／予約枠／fixture、および `preview_checkout_task4/_events/events/{eventHash}` のみ。本番users配下のbilling／trial／プロフィール／利用権限へ書かない。隔離namespaceへの実書込はあるため、Firestoreプロジェクト全体の書込0とは記録しない。 |
| 最新状態・冪等性 | payloadはroutingにのみ使い、最新Test Subscription・Customer・Price・最新Invoiceを再取得。subjectとeventの期限付きlease、billingとprocessed receiptの同一transactionで、並行処理・順序逆転・再送・一時失敗を扱う。古いイベントや他attemptの状態だけで成功扱いにしない。 |
| 状態・権限mirror | incomplete／incomplete_expired／trialing／active／past_due／unpaid／paused／canceledを別保存し日本語表示へ変換。本番のpaid＋active/trialing＋期間内という条件だけをPreviewの参照表示へ写し、past_due／unpaidへ新しい猶予は与えない。実アプリの有料機能を解放する処理ではない。 |
| Web反映 | 同じattemptのWebhook同期前は反映待ち。同期後にカード登録完了／最初の請求予定または有料会員登録完了を表示し、支払確認が必要・確認不能・タイムアウトと区別する。最大6回／30秒の再確認・手動再確認・ログアウト／別UID時の消去。Portalは次タスク案内のみ、Portal Session作成0件。 |
| fixture | 未開始／期限切れは本人UIDのPreview operator fixtureを使い、テスト用データと明記して実Stripeへ接続。本番体験は書き換えない。無効化済みfixtureは新規HTTPへ適用せず、本来のapp factsへ戻る。有効のまま期限切れになったfixtureは拒否。Auth Emulator由来の無効化済みfixtureだけは、署名検証済み遅延Webhookが元trialを照合する正本として保持する。 |

### 検証結果と証拠の区別

- **runtime395件PASS**：backend unit176、frontend122、既存policy84、Firestore Emulator13。Emulator13件にはクライアントRules拒否72ケースを含む。8状態、API一時失敗・再試行・順序逆転・別UID・lease競合等は合成検証の範囲として記録する。実unpaid到達を確認済みとは扱わない。
- **静的347件PASS**：LP84、account106、brand157。strict TypeScript compile／`git diff --check` PASS。保護11ファイルSHA一致、既存依存／lock／SDKは更新しない。
- **実Embedded3ケース**：本人所有アカウントの既存app trialは当日Invoice0円・trialing・元終了日時一致。未開始／終了済みはPreview operator fixtureで各550円即時paid・activeを確認。本番trial未開始／期限切れの実データへ変更した試験ではない。対象の本番業務4文書SHAは前後一致で、延長・リセット・新21日付与なし。
- **実Clock**：共有Embedded Customerとは別の専用Auth Emulator UID／Test Customerを使用。初回550円paid→翌月550円paid、期間末解約予約→canceled／mirror=falseを確認。失敗ケースは初回550円Invoice open・入金0円→past_due／mirror=falseを確認。trial_will_end Testイベントは2件観測したが、今回の権限遷移には不要なため登録イベントへ追加しなかった。
- **実署名イベント再送**：所有する真正Event14件を逆順で2巡、28送信でHTTP200。重複21回のbilling再書込なし、canceledを維持。不正署名・古い署名時刻・Live flagの合成送信は400／状態不変で、真正イベントの証拠と区別する。
- **実表示**：Chrome360／390／430／768／1440px、Enterによる再確認・再読込・ログアウトを確認。別UIDへの非漏洩は合成テスト／Emulatorで確認し、実アカウント2人目のログインとは区別。物理Android Chrome／iOS Safariのblur／実スクリーンリーダー等は従来どおり後続の公開前確認とし、全実機PASSにはしない。

### Preview・本番保護・後始末と次工程

- 同じ[ログイン・申込Preview](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account/)・channel `web-first-task1`、最終version **`bd3f9a9e5afe22f2`**、期限 **2026-11-21 21:41 JST**。専用2 Functionsの配備成功を確認した。
- 本番54 Functionsのstate／updateTime、live Hosting release SHA／version、Auth許可ドメイン4件は前後不変。構成全体のバイト／SHA一致まで主張しない。保護Web11ファイル、元アプリHEAD・dirty10ファイルSHA・全2,120行のGit statusも開始時と一致する。
- 本番Stripe・本番業務billing／trial／権限の変更0。Preview namespaceには実書込みあり。最終実照合ではTest Customer3件／Clock2件を保持、Subscription7件（旧Task4履歴2件を含む）はすべてcanceled、有効0・open Checkout0・有効fixture0。receipt28件はすべてprocessed、retryable／error0。Clockの真正retryable3件は再送200＋重複200・billing不変で回復した。失敗証拠の550円未払いopen Invoice1件、Webhook／専用Secretは保持する。旧取消済み2件のUIDフィールド未保存は履歴として識別し、補完・変更していない。
- Task5だけを1コミットに保存して停止する。Task6 Portalは未実装／Session作成0件で、本人承認後に着手。main merge／push、live Hosting、本番Stripe／billing、Flutter／ストアの変更は行わない。

## 2026-11-14 戦略C・タスク4：Stripe Embedded Checkout（b94eb7a5f2c0・本人承認済み）

本人のタスク5指示で上記コミットを承認済み。以下はタスク4実施時の検証・未確認を保存した履歴であり、現在の作業・停止点は先頭のタスク5節を優先する。

本人承認済みタスク3 `98f3fb8a6cd8` を起点に、Test Mode限定タスク4の実装・Test Preview確認を完了。本人のTestキー保存と既存未契約アカウントでのログイン後、実Embedded操作・各カード拒否・3D Secure・成功に加え、実2タブの同一Session共有・明示失効・戻るを確認し、競合対策の最終backend配備もACTIVE。開始HEADは `98f3fb8a6cd8`。本実装・検証・記録を独立1コミットへ保存し、本番公開可能・全実機確認済みとは扱わない。保存後に停止し、タスク5Webhook／権限同期は次工程として本人の別承認後に実装する。

### 実装した境界

| 項目 | 実装・制約と現在の証拠 |
| --- | --- |
| Functions | `preview-functions/`、codebase `hamcare-checkout-preview`、別名HTTP `createPreviewStripeCheckoutSession` を専用 `firebase.checkout-preview.json` から配備しACTIVEを確認。本番Functions entryや既存Stripe clientを呼ばず、既存依存・lockを再利用。`gcp-build`空指定でクラウド再buildを抑止し、コンパイル済み4ファイルを同梱する。maxInstances2／concurrency10。 |
| Secrets・IAM | 別名 `HAMCARE_PREVIEW_STRIPE_TEST_CREDENTIALS`／`HAMCARE_PREVIEW_STRIPE_TEST_PRICE` だけを参照。本人保存のcredentials有効v1を値非出力で確認。配備関数の既定runtime SAが専用Secret2件のAccessorを持つことを確認した。Testキーprefix／livemode=falseを検証し、値をHTML／Git／Firestore／ログ／文書へ保存しない。codebase分離をFirestore IAMの完全隔離とは扱わず、書込先をコードで限定する。 |
| Firebase UID | Authorization HeaderのID TokenをAdmin SDKで検証し、失効・disabled・メール確認状態とserver-only `pet_profiles/main_pet` の存在を確認。本文からUID／メール／金額／Price／Customer ID／trial_endを採用しない。Origin／JSON body／サイズ／操作名も限定する。 |
| 保存先 | Test Customer対応・attempt・quote・予約枠はルート `preview_checkout_task4` のみに限定し、現在は隔離namespace内2文書へ実書込みあり。本番 `users/{uid}/billing/subscription`、プロフィール、体験、権限等の本番業務データ書込みは0。同一Firestoreプロジェクト全体の書込み0とは混同しない。 |
| 料金 | Test Product `prod_VcunlHPeZzngHQ`／Test Price `price_1UbexYGqALYlhFyzkAHsBm1j` はpremium_monthly用・JPY550円・月次1か月・inclusive。実Checkout／Subscriptionも正本Price・数量1・月次550円で一致し、Automatic Tax無効・税／割引の追加なし。Price IDは公開クライアントへ渡さず、カード入力はStripe iframe内だけ。既存本番500円税込Price・公開条件は変更しない。 |
| 21日体験 | 既存startedAt／endsAtをサーバーで確認し、既存終了日時由来のtrial_endとbilling_cycle_anchorが実Stripeの値に一致。体験中のため初回Invoiceは0円、次回Invoice previewは550円で、期間開始も元の体験終了に一致した。Unix秒精度への切上げは最大999ms。体験の延長／リセット／新21日付与は行わず、残り48時間＋60秒未満は安全拒否。未開始／終了済みの即時550円はpolicy／mockで確認し、本人実アカウントのE2Eは未実施。 |
| 重複・回復 | 3分の確認proofと条件再照合、UID単位lease、サーバーidempotency、Customer再利用、Test Subscription／open Session再確認、期限切れcreatingの同attempt照合、状態更新のCASを実装。新Session作成予約だけUID10件／日・全体100件／日とし、全API呼出回数の上限とは混同しない。 |
| Webhook混線 | Test metadataは専用scope／subject hashのみ。既存本番Webhookが解釈するfirebaseUid／client_reference_idは付けない。実APIでTestの有効Webhook送信先0件を確認。今後有効送信先がある場合は安全側に拒否する。タスク5のWebhook・Firestore権限同期は未実装で、有料機能利用可能とは表示しない。 |
| Web UI | 既存プラン確認からサーバー請求内容・規約同意を経てEmbeddedへ進み、成功／未確定／拒否／期限切れ／取消／戻るを区別する構造を追加。認証方法・標準セッション・LP・既存ブランドは維持。Stripe.js／専用backend用の接続はaccount CSPだけへ限定追加。本番公開・Flutter導線・ストアは変更しない。 |

### 実施済み検証と未実施

- **合成runtime：263件PASS**。Web102、純粋policy84、engine68、HTTP9。認証拒否・token失効／未確認・別UID・任意入力拒否、価格／体験／多重処理／cancel・statusのpending回復／同attemptのlease・phase競合保護／日本語表示等をmock・合成データで検証した。policy再実行の初回はNODE_PATH不足による既存module読込失敗、正しい既存module指定後に84件PASSで、依存更新なし。Client Secretは長さ制限付きTest用opaque値としてStripe SDKだけへ渡し、URL／画面／ログ／独自永続化へ出さない。実Stripeの結果は下記と区別する。
- **静的：340件PASS**。LP84、account99、brand157。実CSSコントラスト43ケース、最小本文5.06:1・境界／focus3.09:1。strict TypeScript build／`git diff --check` PASS。保護10対象、元アプリdirty10件／未追跡2,110件、既存lockのバイト一致とsecret patternを確認。依存／SDK更新・既存テストの広範再実行は行わない。
- **実Stripe／Chrome UI**：取消→Session expired、通常のカード拒否、資金不足、期限切れカード、CVC不正、3D Secure失敗／成功、通常テストカード成功を確認。公式Test Modeカードだけを使用した。同一Test Customer1件を再利用し、最終Sessionは計4件（expired2／complete2）、Subscription2件を順に作成。二重クリックでも新Sessionは1件だけ、有効Test契約がある状態での新reviewは拒否。試験用Subscription2件は最後にどちらも請求／prorationなしで取消済み、有効Test契約0・open Session0、Customer1件は再利用用に保持し、本番契約には触れない。
- **実Stripe価格・請求日**：HamCare表示550円、通常成功した2件目SubscriptionのJPY550円／inclusive／月次／数量1・既存体験中の当日Invoice0円を照合。次回Invoice preview550円は1件目の取消前に確認済み。Stripe trial_endとbilling_cycle_anchorは既存HamCare終了日時からのサーバー判断に一致し、将来請求開始も元の体験終了に一致した。個人の体験終了日時や実アカウント値は本書へ転載しない。未開始／終了済みの即時課金は本人実アカウントでは未実施で、policy・mockの証拠と分ける。
- **実2タブ・失効**：複製タブでも認証を保持し、review／startが同じopen Sessionを返すことを確認。Stripe上のscope内Sessionは全4件で、当該操作は1タブ目で新規1件・2タブ目の追加0件。最後のopen SessionをStripe Test APIで明示失効し、両タブの再確認で「支払い画面の期限が切れました」と表示、旧iframe消去を確認。結果見出し→Tabでプランへ戻る→Enterでプラン見出しへ戻れ、ログインも維持した。自然経過による失効は実施せず、実API明示失効・合成テストと区別する。
- **限定表示・未実施**：Chromeの360／390／430／768／1440pxでStripe iframeの視認性と横はみ出しなし、Tabのカード番号→有効期限→CVC→名義への移動を確認。360〜768pxは100％、1440pxは50％拡大率でCSS viewport1440pxを確認した条件付き結果。物理Android Chrome／実機Safari／実スクリーンリーダーは未実施。Safari・読み上げは一連の購入フロー完成後へ繰越し。自然失効と、未開始／終了済みの本人実アカウント即時550円E2Eも未実施として残す。
- **Preview反映**：競合対策を含む専用backendの最終配備はACTIVE、updateTime **2026-11-14 20:59:45 JST**（cloud-final.json）。同じ[Preview](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account/)はClient Secret形式の限定修正を含むversion **`9332c8153d265143`**・期限 **2026-11-21 21:04 JST**へ更新。初回CLIのversion空欄は推測せず実metadataで確定した。タスク3の古い請求日説明だけを、次画面でサーバーが体験状態に応じて確認する文言へ合わせた。最終説明文を含む公開33リソースHTTP200／SHA／安全ヘッダー一致、除外6経路404、Test Price ID非含有と配備拒否HTTP4件PASS。
- **本番保護と操作件数**：最終配備後も既存54FunctionsのupdateTimeは全件不変で、追加・更新対象は専用1関数のみの計55関数。本番live release SHA／version `2365135bf558c278`／Auth許可設定・元アプリ作業状態は維持。本番Stripe書込み0件、本番業務Firestore・既存契約／体験／権限変更0件。隔離namespace内2文書へは書込みがあり、Firestoreプロジェクト全体の書込み0とは表記しない。Test Product1／Price1／Customer1／Session4／Subscription2とSecret／Preview配備は許可済みのTest専用操作。両Test契約は請求・prorationなしで取消済み、有効Test契約0・open Session0で後始末を完了した。

### 本人操作・残る順序・停止

1. 本人によるTestキー保存と未契約の本人既存アカウントでのWebログインは完了。秘密値・実メール・UID・個別の体験日時をチャット／Git文書へ転載しない。審査用有料アカウント・本番体験・利用枠は維持する。
2. 実2タブ・明示失効・最終競合対策のbackend反映と照合は完了。自然経過失効／物理Android／Safari／読み上げ／本人即時課金E2Eは未確認のまま区別し、本番公開・全実機試験の完了へ読み替えない。
3. タスク4の実装・Test Preview確認が完了したため、今回の対象だけを明示stageし、`feat(web): add Stripe embedded checkout` の独立1コミットで保存して停止する。コミットハッシュはGit履歴と完了報告で確認する。main merge／push、live Hosting、本番Stripe／Customer／Subscription／billing、アプリ／ストア変更は行わない。次のタスク5Webhook／権限同期は未実装で、本人の別承認後に進められる。

## 2026-11-14 戦略C・タスク3：独自月額プラン確認（98f3fb8a6cd8・本人承認済み）

本人の後続タスク4指示で、このコミットの実装とPreview表示を承認済み。以下はタスク3実施時の記録であり、当時のChrome白画面・未確認を自動検証PASSへ書き換えない。最新の実施範囲・停止点は先頭のタスク5節を参照する。

本人承認済みの `320c726`（ブランド統一）と `57e625c`（輪郭アイコン訂正）を起点に、同じ `feature/web-first-stripe-checkout`／専用worktreeで、ログイン後のプラン・契約対象・条件確認だけを追加。決済接続はタスク4以降とし、今回Checkout／Portal／Customer／Subscription／Webhook／Functions／本番billingを操作しない。

### 表示とデータ境界

| 項目 | 今回の実装・制約 |
| --- | --- |
| プラン | `public/assets/plan-model.mjs` の固定 `premium_monthly` 1種類。月額550円税込／500円税抜・10％想定のPreview専用表示。年額・割引なし。実Price／Product IDは未接続。金額やplan keyをサーバーへ送信しない。 |
| 契約アカウント | 既存確認画面から進む際、本人のowner profile／billing subscription／initial trial v2の3文書を毎回再取得し、nickname・マスクメール・登録済み方法・保存契約／体験状態を表示。取得不能は未確認表示と選択不可にし、未確認メール／ユーザー切替では経路を遮断する。 |
| 選択 | 単一のネイティブラジオで確認中プランと税込総額を表示するだけ。ローカル仮選択を永続化せず、再読取／ログアウト／アカウント変更時に消去。申込・決済ボタンは全状態でdisabled。 |
| 契約記録がある場合 | `paid`＋`active`／`trialing`（期間末解約予定を含む）は管理確認を優先し、新規プラン選択を不可にする。既存アプリの「アプリの設定 → 利用プラン → プランを管理する」を案内し、WebからPortalを開かない。 |
| 不明・不整合の場合 | 未知／incomplete等の支払い確認状態／型不整合／読取失敗は契約確認を優先し選択不可。日時や欠損を未契約・利用可能へ変換しない。 |
| 文書なし／明示none／整合したキャンセル済み（plan=none） | 内容確認だけを許可し、Stripe側の未契約・契約再開可能とは断定しない。実処理前のサーバー再照合は後続タスク。 |
| Customer・Checkout | 既存 `stripeCustomerId` フィールドの保存参照の有無のみを安全な文言へ変換。実IDは表示・URL・ログへ出さず、Customerの現在の存在を確認したとは扱わない。Checkoutは常に「未照合（決済接続時にサーバーで確認）」と表示。過去ID・時刻・履歴だけで進行中か判断しない。 |
| 料金・更新日時 | 現行公開規約／特商法の月額500円税込とPreview550円の不一致を画面内で明示。本番公開前に税務・法務・最終請求額を一致させる。currentPeriodEndは保存済み契約期間末として表示し、正確な次回請求日時を独自計算しない。 |

- 既存公開文書を基に、含まれる機能、自動更新、サービス提供、解約方法／期限、返金、カード不要21日体験との違い、動作環境、規約／Privacy／特商法／サポートを画面に整理する。未確定条件を確定済みとしない。
- `projectPlanReview()` は保存契約の安全な表示・重複申込を避ける画面制御であり、権限解放やWeb独自の期限評価を行わない。Stripe server allowlist／Price解決・既存契約／進行中Checkoutの実照合はタスク4以降で設計する。
- 既存の黒背景・白輪郭アイコン、星空・ガラス・ブランドトークンを維持。新 `plan.css` のみで、プラン表示時の最大1000px・900px以上2列／モバイル1列、ネイティブラジオ・44px以上の操作領域、文字折返し、Reduced Motion／forced-colorsを実装。既存共通CSSは変更しない。

### 変更・検証と未確認

- 変更対象は既存account HTML／`account-model.mjs` の安全なprojection／`account-view.mjs` の再読取・選択・クリアと状態guard、新 `plan-model.mjs`／`plan.css`、直接関連する既存UI・静的テストと新 `tools/test_web_plan_model.mjs`、本書／PROJECT_STATUS。認証entry／service／Firebase config／Preview config／brand.css／account.css／LP HTML／LP CSSの**8ファイルは開始時とバイト一致**。
- Node **59/59 PASS**。LP静的 **84/84**、account **61/61**、brand／plan／安全境界 **152/152**、計 **297/297 PASS**。うち実CSSコントラスト **38ケース**、最小本文 **5.06:1**・境界／focus **3.09:1**。構文と`git diff --check` PASS。既存Emulator15件は引継ぎで、今回の実行数へ加えない。
- **Chrome表示確認は未完了**。操作ツールでlocal／実Preview双方が白一色、ページ本文も取得できず、本人へMacの表示状態／ロック解除の確認を依頼中。今回の7幅・200％・プラン画面目視をPASSにしない。下記の過去のChrome確認とは区別する。
- **Safariと実スクリーンリーダーは本人の指示で後続へ繰越し**。Embedded Checkoutを含む一連の申込フロー完成後に確認する項目とし、タスク3の完了判定を妨げるものとはしない。今回の未検証を実施済みへ変更しない。

### Preview・保護・停止

- 同じ[LP](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/)／[ログイン・プラン確認](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account/)、channel `web-first-task1` へ **2026-11-14 18:19:30 JST**反映、version **`38180b0967ad3f37`**、期限 **2026-11-21 18:19 JST**。専用Preview設定と`--no-authorized-domains`を再利用。明示29リソースHTTP200・SHA／安全ヘッダー一致、対象外5経路404。
- 本番live version `2365135bf558c278`／公開Privacy／Auth許可ドメイン4件は不変。元アプリの既存dirty10件・未追跡2,110件を保持。本番Firestore書込み0、Stripe書込み0、Customer／Subscription／Webhook／契約／体験／利用権限変更0、Functions配備・アプリ変更0。Previewの静的更新は別操作として記録する。
- 今回の確認画面だけを `feat(web): add subscription plan confirmation` の独立1コミットに保存後、本人確認まで停止。main merge／push、live公開、タスク4の決済接続、アプリ／ストア変更は行わない。

## 2026-11-14 Webアイコン正本の訂正（限定修正・Preview反映済み）

本人の追加指定により、最新アイコンは**黒背景に白いハムスター輪郭**の図案と確定。正本は `store_assets/icons/hamster_pencil_mark_master.png`（1254×1254px）。直前の `320c726` では白い立体ハムスター＋シアン心電図を現行と誤認したため、この採用判断と、配信nativeの輪郭アイコンを「旧」とした説明を訂正する。白い立体ハムスター＋心電図は今回使用しない。

| Web用の新しい版名 | 寸法 | 用途 |
| --- | --- | --- |
| `public/assets/landing/hamcare-mark-outline.png` | 256×256px | LP／ログイン・アカウント確認のヘッダー |
| `public/assets/landing/favicon-outline-32.png` | 32×32px | favicon |
| `public/assets/landing/apple-touch-icon-outline.png` | 180×180px | Apple Touch Icon |
| `public/assets/landing/og-hamcare-outline.png` | 1200×630px | OGP／Twitter Card |

- 元の輪郭正本を再利用し、アプリ素材や既存候補画像は変更・削除しない。新しい版名により従来Web画像のキャッシュと区別し、両HTMLの画像参照・説明を合わせる。撤回したWeb派生4件は非公開監査とGit履歴へ保存し、publicからは除外した。
- 認証JS・Firestore読取り・Firebase／Preview設定・CSS・本番契約には変更を加えない。既存の星空・ネイビー・ガラス表現、実Home画面、既存機能・リンクを維持する。
- 同じ[Preview](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/)へ最終反映 **2026-11-14 16:47:36 JST**、version `bc548fb3fe72eaeb`、期限 **2026-11-21 16:47 JST**。LP84／account46／brand137の静的267件・`git diff --check` PASS。元アイコン／native素材は不変、OGは[64,70,172,178]のアイコン矩形外が前版と画素一致。配信27ファイルHTTP200・SHA／安全ヘッダー一致、撤回した白ハムスター派生4URLを含む9経路404。Chrome実PreviewのLPヘッダー・favicon・ログインの図案を目視。認証JS／Firebase設定／CSS、本番live／Privacy／Auth許可ドメインは不変。Preview更新2回は本番書込みと区別し、本番Firestore／Stripe操作は0。前回の認証34件・Chrome7幅は引継ぎであり今回再実行していない。
- `fix(web): use current outline app icon` の独立1コミットで保存後、本人確認まで停止。main merge／push・本番Hosting・Stripe／Firestore書込み・タスク3は行わない。

## 2026-11-14 戦略C・Webブランド統一（320c726・本人承認済み）

同じ `feature/web-first-stripe-checkout`、開始HEAD `d969c1955e2861a8eea4a3a4b5a101561532b7b3` から、LP・ログイン・アカウント確認のデザインだけを独立1コミットで保存する。タスク3は本人確認後。下記タスク2の認証機能・許可ドメイン等は維持し、今回Firebase設定を追加変更しない。

### Flutter正本からの対応

| 調査対象 | 実装の正本 | Webへの反映 |
| --- | --- | --- |
| ThemeData／ColorScheme／文字階層 | `lib/theme/app_theme.dart` の `AppTheme.darkTheme` とdark token、`lib/screens/auth.dart` | primary #315DAF、surface #232635、入力#24273B、白／白70系。本文16px相当、見出しはrem＋clamp。日本語はWebのOS標準フォント、既存Caveatをブランド名へ再利用。 |
| Drawer／影／blur | `app_theme.dart` drawer token、`lib/widgets/main_drawer.dart` | 18pxの局所blur、#121924系のガラス、#222A38系の濃い確認面、0/9/18の黒.18 shadow。Webの読みやすさのため不透明度と枠を増やした。 |
| BottomSheet／ナビ／ボタン | `lib/widgets/quick_record_sheet.dart`、`floating_bottom_navigation.dart`、app_themeのquickRecord token | #0f151e系surface、cyan/mint #79E2DD、Primary青、控えめな境界glow。新しい固定モバイルナビは追加しない。 |
| Home／状態別背景 | `lib/widgets/app_habitat_background.dart`、app_themeのHabitat token | standard night／day、状態別背景とfallback、黒overlayの既存構造を確認。Webは承認済み `assets/images/theme/bg_default_night.webp` の同一コピーを使用し、文字側に濃いoverlay。状態によるWeb背景切替は追加しない。 |
| アバター | `lib/widgets/hamster_avatar_view.dart`／既存Resolver | 既存stable3種・既存alphaのままcontain配置。アプリのモデル／Resolver／88アセットは変更なし。 |
| ブランド書体 | `main_drawer.dart` のCaveat30、`screens/auth.dart` のCaveat40 | 同じCaveat-Bold.ttf／OFLを再利用。フォント追加・依存更新なし。 |

### Web共通トークン（public/assets/brand.css）

| Token | 値 |
| --- | --- |
| `--hamcare-bg-deep` | `#181a20` |
| `--hamcare-bg-surface` | `#232635` |
| `--hamcare-glass` | `rgba(15,21,30,.90)` |
| `--hamcare-glass-strong` | `rgba(34,42,56,.97)` |
| `--hamcare-border` | `rgba(255,255,255,.20)` |
| `--hamcare-border-glow` | `rgba(121,226,221,.38)` |
| `--hamcare-text-primary` | `#ffffff` |
| `--hamcare-text-secondary` | `#c5cbd4` |
| `--hamcare-accent-cyan`／`--hamcare-accent-mint` | `#79e2dd` |
| `--hamcare-accent-blue`／`--hamcare-primary-action` | `#315daf` |
| `--hamcare-danger` | `#ff6b6b` |
| `--hamcare-warning` | `#ffc857` |
| `--hamcare-radius-card` | `24px` |
| `--hamcare-blur` | `18px` |
| `--hamcare-shadow` | `0 9px 18px rgba(0,0,0,.18)` |

入力境界は#8390a6を使い、無効状態は文言／disabled属性でも区別。背景の明部を最悪白としてoverlayとガラスを合成したコントラストも検査する。blur非対応時は先に指定した不透明面を使用し、WebKit prefix、prefers-reduced-transparency／prefers-contrast／forced-colors／prefers-reduced-motionに対応する。これらの実OS表示全組合せを確認済みとはしない。

### アイコン・画像・ページ変更

- **後続本人確認による訂正**：`320c726` では `assets/branding/hamster_care_app_icon_master.png` の白い正面ハムスター＋シアン心電図を現行と誤認し、対応するWeb素材を整備した。本人が指定する最新正本は黒背景・白い輪郭の `store_assets/icons/hamster_pencil_mark_master.png`。前の採用判断と、code5 AAB／build5 IPAの輪郭launcherを「旧」とした説明を撤回する。Webの限定訂正は先頭節を正とし、アプリ素材は変更しない。
- 当時のfavicon32、Apple Touch180、OG1200×630と両HTMLのメタ情報の整備履歴を保持し、アイコン図案だけは先頭節の本人指定へ訂正する。輪郭図案を旧と分類しない。PWA manifest／Service Workerなし。OGへメール／UID／契約情報を入れず、ログインURLに私的情報を付けない。
- LPは星空・草原、実Homeを中心にしたヒーロー、承認済み3アバター、4機能の実画面、濃いFAQ／法務リンク。キャッチフレーズ「うちの子と、もっと健康で幸せに」をヘッダーにも追加。全リンクと順序、2入口、プラン／無料体験条件は不変。Homeは本人提供1000017308.jpgからOSバーだけを切り取り、テストプロフィールの「記録待ち」の実画面を使用。画像を生成・捏造しない。既存4機能PNGはバイト一致を維持。
- ログインは紺ガラス・明確な入力境界・白文字・青Primary・穏やかな赤エラー。Google Gは[公式アセット／ブランド要件](https://developers.google.com/identity/branding-guidelines)を確認し、公式PNGを未加工で白ボタンに配置。ボタンID／イベントを維持。
- アカウント確認はログインより濃いsurfaceと区切りを使い、ニックネーム・マスクメール・ログイン方法・契約・体験を整理。本人3文書だけを読む既存JSは変更せず、再確認／ログアウト／準備中ボタンも不変。
- 変更対象：`public/index.html`、`public/account/index.html`、`public/assets/landing.css`、`account.css`、新`brand.css`、既存`landing/provenance.json`、新画像6点（favicon／Touch／night／Home／OG／Google G）、限定検査`tools/check_web_brand.py`、既存進捗／本書。原画・比較候補・アプリ・authJS・Firebase設定・lock・Rulesを追加stageしない。

### 検証・実ブラウザの範囲

- 再実行：`node --test tools/test_web_account.mjs tools/test_web_account_view.mjs` **34/34**、`python3 tools/check_web_landing.py` **84/84**、`check_web_account.py` **46/46**、`check_web_brand.py` **130/130 PASS**。静的計260（うちコントラスト28）。`git diff --check` PASS。タスク2Emulator15件は引継ぎで今回の実行数へ加えない。
- [WCAG AAの通常文字4.5:1](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)に対し、対象CSSの最小本文5.06:1、focus／入力境界3.09:1。これは色の計算結果であり、全ページの包括的な適合認証を意味しない。
- Chrome DevToolsで **320／360／390／430／768／1024／1440pxの7幅**をLP・ログイン・確認画面に適用し、主画像の切れ／文字折返し／横はみ出しなしを目視。ログインと確認画面の幅比較は非公開localhostで同じHTML/CSS・既存viewを架空データ表示し、個人情報や実認証通信を使わない。同じPreview反映後のLPとログインも表示確認。LP／ログイン200％拡大、FAQのTab→Enter展開・可視focusを確認。
- ヘッダーは非固定。44px以上の操作領域、alt、form label、見出し、role=alert／ARIA、色だけに依存しない状態、装飾を無視する指定を確認。実スクリーンリーダー読上げ、確認画面200％、OS高コントラスト／Reduced Motionの実描画、実機Android Chrome／iOS Safariは未確認。SafariのWebKit blurは実装済みだが、Mac Safariは操作ツール起動timeout、iOS Safariは今回接続していないため実描画PASSにしない。
- PreviewのDevToolsで現れるSDK map3件のCSP遮断は以前と同じデバッグ情報取得制限。ログインSDK自体は読込み済みで、警告を消すためCSPを広げていない。今回新たな本番認証・AI送信・Emulatorデータ操作・課金は行わない。

### Preview・本番保護・停止

- URL：[LP](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/)／[ログイン・確認](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account/)。既存channel `web-first-task1`、2026-11-14 **16:25:38 JST**、version `c1b4a97c5eff76c0`、期限2026-11-21 **16:25 JST**。下記の既存専用Previewコマンドと `--no-authorized-domains` を再利用し、liveへ反映しない。
- 明示27リソースのHTTP200／SHA／noindex／nosniff／no-referrer、account no-store PASS。Hostingの29ファイルはこの27とFirebase生成の `/__/firebase/init.js`／`init.json` の2件。内部素材台帳・旧billing／Privacy・ローカルfixtureの5経路は404。LPのscript／connect禁止、account限定接続、法務リンク先は不変。
- 反映前後の本番live version `2365135bf558c278`／release、公開Privacy SHA、Auth許可ドメイン4件は一致。認証4module・Web config・Preview configの6ファイルが開始時とバイト一致。元アプリHEAD／status／dirty10件の内容・未追跡2,110件を保持。秘密情報・私的プロフィールをコミットしない。
- **本番Firestore書込み0、Stripe書込み0、本番Functions／契約／体験／権限変更0**。Preview静的反映1件とは区別する。`style(web): align pages with HamCare app theme` の1コミット後に停止し、本人デザイン確認までタスク3・Stripe・main merge／pushへ進まない。Safari等の未確認は公開前に残す。Apple回答の最新扱いは下記タスク1を維持する。

## 2026-11-14 Webファースト戦略C・タスク2（Webログインのみ）

タスク1 `98e4b204e05a` は本人承認済み。今回は既存ブランチ `feature/web-first-stripe-checkout` の専用worktreeでログイン・本人情報の読取りだけを追加し、1コミット後に停止する。下記タスク1の「未実装」「許可ドメイン3件」は当時の記録であり、現在は本節を優先する。

- **Firebase登録**：同プロジェクトのWeb一覧0件を作成直前に再確認し、`HamCare Web` 1件を登録。Analyticsは未追加。公開Web Configはクライアント設定4項目だけで、Admin SDK資格情報・サービスアカウント・計測IDを含めない。Firebase公開apiKeyは秘密鍵とは区別する。
- **許可ドメイン**：既存のlocalhost／firebaseapp.com／web.appを保持し、`hamster-breeding-app--web-first-task1-lco08m60.web.app` だけ追加。その他Auth設定は不変。Preview終了後に正確なこの1項目だけを削除し、既存ドメインは削除しない。ワイルドカード追加なし。
- **Preview**：[LP](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/) →「有料会員になる（アカウント確認）」→ [ログイン](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account/)。同じ `web-first-task1` channelへ2026-11-14 15:39:11 JST更新、version `ba068e9852825333`、期限2026-11-21 15:39 JST。反映コマンドは下記タスク1と同じ専用config／`--no-authorized-domains`。live Hosting・Functionsへ反映しない。
- **認証**：既存メール／パスワードとGoogle Popupのみ。メール新規登録なし、Appleは準備中表示。未確認メールは次画面とFirestore読取りを遮断し、再確認のみ行う。メール確認とパスワード再設定の再送は既存アプリへ案内し、Webからメール送信しない。Firebase SDKは既存と同じ12.17.1、標準browserSessionPersistence、Firestore Liteのサーバー読取り。独自token保存なし、URLへtoken／UID／メール／Customer IDを載せない。ログアウト／ユーザー切替／遅れて完了するGoogle Popupでも別ユーザー情報を残さない。
- **Google仕様**：未登録のGoogleはFirebase Authが新UIDを作成し得るため画面で明記し、new-user時はアプリへの案内と次ボタン無効化を行う。信頼済みプロバイダ同メールはFirebase標準側で既存アカウントへ連携される場合もある。独自email照合・UID統合・linkWithCredentialは実装しない。衝突はアプリで使った方法を選ぶ日本語案内。既存Auth onCreateの `analyticsAccountRegistered`（`functions/src/analyticsJourneyEvents.ts`）が新規Auth登録時にjourney_eventsへ記録し得る点は既存挙動であり、将来の新Google利用全件をFirestore書込み0と保証しない。本番で新規Google作成試験はしていない。

### 本人情報の正本と表示の限界

| 情報 | 読取り先（すべて認証中の本人UID直下） | 表示・制約 |
| --- | --- | --- |
| ニックネーム | `users/{uid}/owner_profiles/main.displayName` | trim後の値、未設定は「未設定」。Auth displayNameを代用しない。 |
| 契約 | `users/{uid}/billing/subscription` | 保存済みplan／status／currentPeriodEnd／cancelAtPeriodEndのみ。契約ID・Customer IDは表示しない。 |
| 21日体験 | `users/{uid}/feature_access/initial_trial_v2` | 保存済みstatus／endsAt／存在する利用回数のみ。体験を開始しない。 |
| アカウント | Firebase Auth | マスクメールと登録済みプロバイダ名のみ。UID・tokenを出さない。 |

- 文書なしとpermission-denied／通信失敗は分離して表示。実Previewの本人既存アカウントではニックネーム・契約保存記録・マスクメール・方法を取得し、体験は「開始記録なし」、取得不能項目0。本人メールとGoogleで同じプロフィール・契約記録を表示した。
- Flutterの `BillingStatus`／`InitialTrialAccess` とサーバーの `getFeatureAccess` を確認。保存済みactiveと期間末は現在の権限を保証しないため、Webで期限計算や権限判定を複製しない。必要なら後続で既存サーバー判定を返す安全な読取り専用APIを検討する。今回の次ボタンは「プラン確認画面は現在準備中です」だけで、プラン申込・Checkout・Portalは存在しない。

### 検証と反映境界

- `node --test tools/test_web_account.mjs tools/test_web_account_view.mjs`：**34/34 PASS**。モデル／マスク／日本語エラー／固定3文書／未確認遮断／遅延レスポンス／ログアウト優先／表示切替／二重操作／準備中画面を確認。
- Auth／Firestore Emulator：**15/15 PASS**。既存SDKを使い、`demo-hamcare-web-auth-task2` とloopback以外では実行を拒否する。現行Rulesをそのまま使用し、別UID読取り拒否、ログアウト後拒否、billing／体験書込み拒否を確認。owner profileには従来の本人更新権限があるが、このWeb実装はwriterを持たない。再現は既存Node22と既存functions/node_modules、専用のローカルEmulator設定を利用し、依存やRulesを更新しない。
- `python3 tools/check_web_landing.py`：**73/73 PASS**、`python3 tools/check_web_account.py`：**43/43 PASS**、Node構文・`git diff --check` PASS。
- 実Chrome：本人メール／Google成功、再読込保持、別タブ／終了後はログイン要求、ログアウト消去、Google Popupを閉じた日本語エラー、LP入口と準備中画面を確認。360／390／768／1440pxで切れ／横はみ出しなし、Tab／Space可視フォーカス、パスワード表示切替、空入力の日本語エラーを確認。role=alert／ARIAの実装・AX表示は確認、実読み上げは未確認。モバイル幅はChrome DevToolsであり実機Android Chrome／iOS Safariの成功とは扱わない。Mac Safariは操作ツールの起動timeoutで未検証。
- ブラウザconsoleのSDK source map取得3件は限定CSPにより遮断。デバッグ用mapの制限であり、ログイン・本人読取りは成功し、メッセージに個人情報なし。表示上の警告を消すためにCSPを拡大しない。アプリ独自console出力・Analytics送信なし。
- LPのscript／connect禁止は維持し、`/account/**` にだけ固定SDK／Auth／Firestore／Google Popupの必要な接続を許可。フォーム送信は禁止、初期操作disabled、URL送信を避ける。ログインHTMLにno-store、共通noindex／no-referrer／nosniff。旧billing／法務／内部素材台帳はPreview配信から除外したまま。
- **今回のWeb実装・実Preview確認：本番Firestore書込み0（Emulatorの合成データを除く）、Stripe書込み0、本番Functions課金呼出し0、契約・Firestoreプロフィール・体験・権限変更0**。本人のAuthログインと、承認済みWeb登録1・Auth許可ドメイン追加1・Preview更新1は別に記録する。本番live version `2365135bf558c278`／11月12日release／Privacy内容は不変。実Previewの新規Google登録は未実施。証拠はMacの非公開一時監査領域、資格情報・個人情報・実アカウント値はGitへ保存しない。
- **次工程**：タスク2コミットの本人承認後に、独自の月額プラン確認（タスク3）。Apple WebログインはService ID／Return URL等を本番公開前の独立タスクとし、実機ブラウザ確認も残す。今回の停止地点でmain merge／push、live反映、Stripe／Webhook変更、申込／課金、アプリ変更へ進まない。

## 2026-11-14 Webファースト戦略C・タスク1（Preview限定・本人承認済み）

- 最新の本人決定はStripe継続、月額1種類、Firebase UID正本、独自プラン確認＋Embedded Checkout。年額／Pricing Tableは追加しない。今回の実装はLPのみで、ログイン・決済・Webhook・Portalは後続の個別承認タスク。現在のアプリ購入導線／既存Customer・Subscription・本番Price／テスターは変更しない。
- 既存Apple問い合わせの最新回答は本人共有に基づく。Case22954972はユーザーが独立して発見したWeb上で開始・完了する購入が日本の代替決済ビジネス条件の対象外との案内、Case103009817213は提出前の事前承認を行わず実際の提出で判断との回答。以下の10/27節は受付当時の履歴であり、回答待ちを現在の状態へ戻さない。戦略CをApple事前承認済みとも書かない。
- 専用ブランチ `feature/web-first-stripe-checkout`、クリーンworktreeで実装。本番の `firebase.json`／法務ページは変更なし。素材の原本は保持、Web用コピーと出典／SHAだけを追加。Web公開価格は550円税込／500円税抜（標準税率10%想定）のPreview専用表示。現行本番の請求条件との差を明記し、契約ボタンは無効化した。本番公開前に税務と最終請求額を照合する。
- Preview URL：<https://hamster-breeding-app--web-first-task1-lco08m60.web.app/>。2026-11-14 14:58:32 JST反映、2026-11-21 14:58 JST期限。Androidリンクは正式Google Play詳細URLで、現在は日本の登録済みAlphaテスター向け。iOS一般公開は準備中、架空のストアリンクは作らない。
- 専用設定 `firebase.preview.json` は静的Hostingだけ。API／Functions／rewritesなし、旧billing・法務・内部素材台帳は配信から除外。法務リンクは現行liveページへ向ける。CSPはスクリプト・外部通信・フォーム送信を禁止、noindex／no-referrer／nosniffを付与。フォントとOFLは配信に含める。
- 再現確認：`python3 tools/check_web_landing.py` →71/71 PASS、合成unsafe設定5ケースはすべて拒否、`git diff --check` PASS。Chromeで360／390／768／1440pxを目視し、390pxの実画面4点・360pxの価格と申込不可・FAQキーボード開閉／可視フォーカスを確認。実機各ブラウザの網羅確認はしていない。配信12リソースのHTTP200／SHA一致／安全ヘッダー、除外3経路404を確認。
- Preview反映時は既存のNode22環境と以下の専用コマンドを使用する。`firebase deploy` や live channelへの操作に置き換えない。Authドメインの自動追加も行わない。

```sh
firebase hosting:channel:deploy web-first-task1 --expires 7d --no-authorized-domains --project hamster-breeding-app --config firebase.preview.json --non-interactive
```

- 反映前後の本番Hosting live version `2365135bf558c278`／release時刻、公開PrivacyのSHA、Auth許可ドメイン3件が一致。本番Hosting反映・Firestore書込み・Functions配備・Stripe操作は0件、Preview反映は1件。非公開証拠はローカル監査領域へ保存し、資格情報・トークンはGitへ入れない。
- タスク1は指定メッセージ `feat(web): add HamCare public landing page` の1コミットで終了する。本人がPreviewを承認するまでタスク2（Webログイン）、本番公開、main merge／pushを行わない。


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
