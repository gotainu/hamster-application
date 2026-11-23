# HamCare：本番切替Runbook（一般購入・一般メール停止／既存契約同期稼働）

## 2026-11-23 Apple提出準備①〜⑤の限定確認結果（⑥現行掲載画像は継続）

本人の`54970b2802f8`を基準とする①〜⑥一括承認を実行した。**現在の正本は、一般購入false/private・一般メール停止・新Webhookの正規同期process稼働**である。この実績が、下段に履歴として残す「新旧Webhook両停止」「Live adapter未実装」「Hosting45不変」等の旧計画・保留記録に優先する。App Storeへの審査送信・ストア公開・新規実契約・実課金・契約条件変更は今回行っていない。

### ①既存契約の通常同期を維持したWebhook切替：完了

1. 旧source/設定/署名参照を退避し、新Acacia/7event endpoint `we_1Uel9zK6h5kxGn4c1ZwNaGlN`を作成直後disabledにした。完全JSON `HAMCARE_LIVE_WEB_BILLING_CONFIG:1`と既存compute SAのSecret単体Accessorを登録。新署名は新endpoint生成値、旧署名は`STRIPE_WEBHOOK_SECRET:3`を使い、値や用途を混用しない。550円Price/非default Portalは既存作成物を再利用し、再作成しなかった。
2. 継続版`stripewebhook-00011-pez`は旧署名を同期継続、新署名だけverify_onlyとした。既存canonical eventに対する**管理者作成HMAC probe**は503/`verification_only`/Retry-After60、receipt未消費/billing・outbox不変。これはStripeからの配送ではない。
3. 続けて、同じ既存イベントのStripe CLI正規再送を受け付け、実配送の503を2要求確認した。verification中のreceipt不存在とbilling・outbox不変を別途GET照合した。この段階も同期完了とは扱わない。
4. 新処理を`HAMCARE_WEBHOOK_MODE=process`/`HAMCARE_WEBHOOK_ENABLED=true`にして、対象の既存実イベント1件を正規再送。UID/Customer/Subscriptionの結合、Stripe正本再取得、同UID lease/CAS/削除フェンスを経てreceipt processedを確認。同じ審査用契約の旧Price/status active/契約期間、100%forever割引、最新0円Paid Invoiceが一致し、審査用通知outboxは0件だった。
5. 新同期を確認した後、旧`we_1U4IAnK6h5kxGn4cDdYtGpsy`をdisabledへ変更。確認時刻は**2026-11-23 09:58:30.471 JST / 00:58:30.471 UTC**。その後legacy=false、新process=trueで最終revisionを配備・照合した。旧署名Secret/旧Price/割引・契約は削除・変更しない。

| 経路 | 版・event・署名参照 | 最終状態 |
|---|---|---|
| 旧Live endpoint | `2026-05-27.dahlia`/既存5event/`STRIPE_WEBHOOK_SECRET:3` | disabled、legacy処理false。署名原本は復旧用に保持 |
| 新Live endpoint | `2025-02-24.acacia`/指定7event/`HAMCARE_LIVE_WEB_BILLING_CONFIG:1`内の新署名 | enabled、mode=process/処理true。固定同URLで正規同期済み |

**書込みの区別**：設定作成・Secret/IAM・Functions/Hosting/Schedulerは本番構成変更である。また、processでbillingのschema/canonical情報・処理済みreceipt/同期記録を更新したため、**本番Firestore書込み0件ではない**。これは承認済みの通常同期で、契約・Customer・Checkout Session・Invoice・割引・契約期間の作成変更は0件。管理者probe/verify_onlyの書込み0と、process正規同期の書込みを混同しない。11/27 10:03:01 JSTは現在期間末であり、自然更新後の権限同期はまだ未確認。

### 限定5関数の実配備照合：完了

以下のrevision・source commit・実配備archiveをGET比較し、5関数すべてsource一致。Checkout private/IAM検査を維持し、他の公開transportは既存の本人認証/署名を維持した。

| Function | 最終revision | 配備元 / source照合 | 呼出し境界 |
|---|---|---|---|
| `createStripeCheckoutSession` | `createstripecheckoutsession-00007-lob` | `90d8f237d8bf` / 168ファイル | private/IAM検査有効 |
| `stripeWebhook` | `stripewebhook-00013-zew` | `90d8f237d8bf` / 168ファイル | public/署名検証 |
| `createStripeCustomerPortalSession` | `createstripecustomerportalsession-00010-duf` | `90d8f237d8bf` / 168ファイル | public transport/本人認証 |
| `deleteMyAccountAndData` | `deletemyaccountanddata-00007-kuh` | `54970b2802f8` / 164ファイル | public transport/本人認証 |
| `retryAccountDeletions` | `retryaccountdeletions-00001-soq` | `54970b2802f8` / 164ファイル | private/IAM検査有効 |

- 課金3関数のsource archive SHA256：`251873473c38e1c0fb3d52cd4412829cb056bc91888fba0b183d3242dac2d056`。
- app削除2関数のsource archive SHA256：`60cc57226f10058f4089b4ac2ffb5e3a224d4f544a51c9e79243aada45de29ca`。
- 専用JSONはversion1を固定参照。Webhookだけは旧継続/復旧のため既存API key/旧署名bindingも維持する。Secret値をソース・Git・診断へ含めない。
- 匿名probeはCheckout403、Portal401、アプリ内削除401、retry worker403。いずれも副作用経路へ入らず、起動失敗や資格情報不足を停止制御PASSに読み替えない。実削除要求を作成していない。

### ②本番Webの停止接続：実装・Hosting反映完了

- 配備元は`d9109f8008fb51aef77f440d7d540b27072ed391`。固定Git archiveからのoverlayで、Hosting`22b8c97c2532f11c`→`58e5ed12aaa990f6`。**49ファイル＝既存11差替え＋新4＋既存34hash保持**。source全体の一括deployは行わず、削除申請ページ等の既存ファイルを保持した。
- 対象はaccount/index、account-view/account/checkout-model/checkout-view、billing/success、LP、Terms、特商法、Support、Privacyと新4module。contact停止HTML/JSは差替えない。cloneで再生成された`/__/firebase/init.js`と`init.json`は元hashへ復元し、finalize前後・release後に全49map/configを照合した。
- CSPは既存`/account/**`の許可先を固定Live Callable2件・contact/Auth/Firestore・必要なStripe SDK/frame/APIへ限定更新し、`/billing/success/**`の固定復帰用ruleを追加。他の設定・非CSP headerを保全し、Preview APIを許可しない。
- Live専用Callable envelope/flat DTO、同じ認証世代/UIDでのbilling再読取、専用Portalへ接続した。契約・権限の正本はFirebase UIDのまま。`/billing/success/`は固定`/account/?checkout=return`へ戻り、queryは確認のきっかけだけとする。URL到達や403/不明結果/期限切れactiveで完了表示しない。Preview DTO・Test key・保存先へのfallbackなし。
- `LIVE_PURCHASE_ENABLED=false`でreview/createを画面/dispatch前でも閉じ、server false/privateを重ねて維持。既存契約のPortalは新規申込・連絡先補完から独立する。購入の一般受付は、後続の別承認で対象者制限・server/IAM/build設定を揃えるまで開始しない。
- LP/規約/特商法/FAQは月額550円と既定の解約/返金方針へ整合。Privacyは現行連絡先の取扱いと一般送信停止を説明し、公開済み音声開示5箇所を保持した。本人連絡先実配送・同UID確認済み原本・既存履歴は再試験/移行/書換えなし。
- 検証：関連Node407/407、LP静的86/86、Hosting helper Mock20/20。Chrome local Mockのaccount/planに加え、desktop Chromeの明示viewport360/390pxで本番匿名accountの停止banner・正本outline icon・scrollWidth=clientWidthを確認し、viewportを復元した。IAB接続不可のためChromeで実施。**実iPhone Safari/Android・ログイン後表示・実決済は未確認**であり、desktop viewport/Mock結果を実機PASSにしない。安全証跡は非公開実行領域の`live-account-responsive-safe.json`。
- account静的172/176。未解消4件の正確な検査名と旧baseline/再exportの理由はPROJECT_STATUS同日欄を参照。実認証条件とsource比較は上記別検証で維持し、失敗を隠す検査無効化はしていない。

### ③アプリ内安全削除backend・再試行Scheduler：配備・接続完了

- `54970b2802f8`から既存のStripe停止確認・削除フェンス・データ削除を行う`deleteMyAccountAndData`、同要求の安全な再試行を行う`retryAccountDeletions`を限定配備した。新Web削除申請API/運営経路は配備していない。
- Schedulerは`firebase-schedule-retryAccountDeletions-asia-northeast1`、`*/15 * * * *`、`Asia/Tokyo`、最終ENABLED。workerはprivateで、既存compute SAの継承Invokerを再利用。worker IAM追加0、project IAM追加0。通知workerとは別であり、一般メール送信を開始しない。
- 作成後にURI末尾の表記差分を検知し、PAUSEDへ停止。同じ宛先/認証/IAMであることを厳密照合して採用後にresume。接続直前のqueueは0（未解決/不明0）、手動dispatch0。workerの配備/接続は稼働状態だが、実削除や実Apple失効の検証ではなく、実アカウント削除0件。
- 停止/復旧はまずSchedulerをPAUSEDにし、privateを維持したまま同じ失敗要求の状態とworker sourceを確認する。Auth/Firestoreの直接削除や削除フェンス解除で代替しない。既存の再試行状態を消して処理済みにしない。

### ④〜⑥の到達点と本人操作待ち

| 段階 | 確認できた到達点 | 未実施・未確認 |
|---|---|---|
| ④本人内部TestFlight：配信・本人更新確認完了 | `1.0.1 (6)` IPA、`54970b2802f8`固定397入力のsource hash・署名PASS。10:05 JSTにTransporter Delivered/処理完了。既存2〜5と同じStandard OS/TLS・独自暗号なし・France Noの根拠で輸出コンプライアンスを保存し、既存「本人実機確認」グループへ6を追加。15:30 JSTに1 Tester/5 Builds、6 Testing/90日を実UI確認。本人は通常アカウントを維持した更新後のHome・ログイン/プロフィール/既存記録保持・利用状況・購入/価格/Portal/Web誘導なしに「更新保持・表示とも問題なし」と回答 | 更新保持確認は完了扱いとし再依頼しない。外部配信/新規招待/審査送信なし |
| ⑤Apple削除/審査アクセス：限定確認PASS | iPhone build6で正しい審査用0円契約UIDの新セッション/Homeを15:59:52 JSTのAuth lastLoginと照合し、契約状態/変化/相談等の必要機能も本人PASS。承認済みApple検証候補の削除直前ログイン16:25:29 JST/有効/Apple連携と実機Homeを確認し、本人がアプリ内削除/同Apple再認証を実施。16:32:55 JSTにAuth/users再帰配下/contact不存在とcompletedフェンス、Preview/Testと別審査UIDの保全を読取確認 | 一般削除完了と本人によるApple連携消失確認を分ける。SDK失効生レスポンスの独立採取ではない。削除後再ログイン/新規登録0。有料契約の停止失敗後に同UIDで再ログイン・削除再開する経路はMockのみ/実機未確認 |
| ⑥提出情報保存：進行中 | ASC 1.0.1にbuild6選択・Save後6表示/Save disabled/Manual維持を確認。Description/Review Notes/Support/copyright保存、電話番号・審査用passwordは本人保存済み。Primary Lifestyle/Secondaryなし、年齢質問の保存とApple算出13+（overrideなし）を確認。既存App Privacy10types/Privacy URL Published、App Accessibility未申告を維持。Japan Available on App Release/他174地域Notは読取のみ | Screenshot0。旧01/02/04は現行UI差分のため更新し、03は現行実画面と照合後に維持できる候補。iPhone実機の審査ログイン・契約/必要機能画面は本人回答と同UID lastLoginで確認済み。Mac撮影用は別セッションのKeychainエラーでローカル検証パッケージの署名修復中。配布IPA/ソース/バックエンドは不変。Content Rightsは既存ライセンス/制作記録と具体的3素材群の本人確認に基づきYesを選択し、Savedと権利あり表示を再読取済み。以前の伏字値を使ったAuth REST検査は無効であり、本人パスワード不正の根拠ではない。追加REST試行/審査送信なし |

### ⑤既存Apple検証用アカウントの削除実行結果（本人承認済み1UID）

- 対象は過去のApple E2Eと本番連絡先確認に使用した **Apple Web E2E Owner** の同じFirebase UIDに固定。本人は2026-11-23に「通常利用ではない。この範囲で削除検証を承認する」と回答した。審査用0円アカウントとは別UID、Apple単独/メール未設定、有効なowner/petテスト名をGET照合した。新しいAppleアカウント作成やiPhone全体のAppleアカウント切替を前提にしない。
- 削除対象は既存処理の`users`親/再帰配下（プロフィール、ペット/履歴、相談、体験、スター/起動状態等）、Auth、**確認済み本番連絡先とその確認履歴**。初回読取32文書、後続baseline33文書という時点差を保持し、UIDの差替えや対象縮小で説明しない。SwitchBot親/固定ペット画像なし。本番billing/Customer/Checkout対応/既存削除要求なし。Preview Test Subscriptionはcanceled1、Session complete1/open0。
- 残すものはPreview namespace/Preview連絡先、Stripe Test Customer/解約済み契約/会計・処理証跡、削除フェンス等。一般の削除処理だけでPreviewまで消したと記録しない。同じApple認可の解除はHamCare Webログインにも影響し得るが、Appleアカウント自体/別UID/審査契約は対象外。
- 実行順は、本人の更新保持確認完了→審査用機能確認を終える→必要なら**HamCare内だけ**で検証候補へ切替→テスト名/UIDを非公開で再照合→アプリ内削除説明と最終操作を本人に案内する。既存実装は同UID Apple再認証/短命codeの即時失効→サーバーのStripe停止確認→既存データ/Auth削除。手動解除案内/再認証キャンセル/失効結果不明を自動失効PASSへ読み替えない。失敗時は同じ対象の状態を確認し、別UID作成やAuth直接削除で補完しない。
- 一般削除の完了はAuth/users再帰配下/本番contact不存在とcompletedフェンスを読み取り確認する。Git外の固定対象スクリプト`verify-deletion-candidate-readonly.py verify`はGETだけでPreview/Testと別審査UIDの保全も確認し、Apple認可失効を証明しない。Apple失効は実機の再認証/自動経路とApple側の連携状態を別に確認する。削除後の新規Apple登録を検証のために行わない。
- **一般削除の実績**：審査用機能の本人PASS後、本人が承認した同候補のAppleログインを16:25:29 JSTにGET照合し、QuickTimeの実機Homeも確認した。本人がアプリ内削除を実行して「削除完了」と報告。16:32:55 JSTの固定対象checkerでAuth不存在、users親/再帰配下0、live contact/固定画像不存在、completedフェンスを確認した。対象の確認済み本番連絡先と確認履歴も削除済みであり、本番Firestore/Auth等の業務データ変更あり・実アカウント削除1UIDと記録する。checker自身の書込み0を、タスク全体の本番変更0へ転記しない。
- **Apple認可の実績**：本人は事前のHamCare連携確認→アプリ削除時の同Apple再認証→Apple設定での連携消失確認を行い、「Apple連携も消えた」と回答。一般削除のDB結果と独立して、本人による連携消失確認として記録する。SDKの失効生レスポンス/Appleサーバー応答を独立採取したとはしない。削除後の再ログイン/新規登録/別UID生成は行っていない。
- **保全と残件**：Preview namespace/Preview連絡先とStripe Test Customer/解約済みSubscription/Sessionはhash一致、別審査UIDのAuth identity・billing全文も不変。通常の本人用/審査/外部テスターは削除対象外。本候補は本番Stripe契約なしであり、有料Subscriptionの実停止や「Apple失効成功後のStripe停止失敗→同UID再ログイン/削除再開」は既存Mockのみ・実機未確認として残す。一般購入/一般メール停止、配布IPA/ソース/バックエンドは維持する。

年齢質問は親制御・年齢確認・自由Web閲覧・UGC・social/chat・位置共有・広告すべてNo、成熟/性的/暴力/賭博None、Medical Infrequent/Wellness Yesを保存した。App Privacyの音声endpoint非保持についての限定再評価根拠は既存`privacy_disclosure_checklist_ja.md`、Simulator/端末・提出情報の進捗は既存`ios_signing_physical_auth_20261018.md`にも追記する。旧スクリーンショットは現行画面の証拠として流用しない。今回のこの確認・保存工程ではコード/Cloud設定を変更していない。

### 最終停止状態・本番変更の分類・復旧

- 一般購入client false/server false/private、contact false、契約通知worker未配備。Preview・本人確認済み連絡先・無料テスター・既存飼育記録/体験開始・期限・利用枠を維持。実メール0、新規実契約/実請求0、実削除0、実Apple失効0。正規同期のbilling/receipt更新は上記の承認済み本番書込みとして分離する。
- Secret version1/単体Accessor、限定5関数、Webhook切替、Hosting49、private retry/Scheduler接続、Transporter送信と提出情報保存は**実施した設定・配備操作**であり「本番変更0件」としない。一般通知の過去outbox一括送信・イベント全体の一括再処理・権限の手動付与0。
- 新Webhookに問題があれば、旧Secret/退避sourceの対応とlegacy同期を先に確認してから旧endpointを再開し、新endpointを止める。新旧を両方止めたまま審査契約の更新日を越えない。購入/一般メールは開かない。Hostingは対象helperの`--execute --restore`で厳密な45map/configの`22b8c97c2532f11c`へ復旧できるが、①の同期継続を止める操作とは連動させない。復旧の実行は今回0。
- 秘密値・実UID・受信者・確認リンク・パスワードはGit/報告に含めない。Relay実配送と追加VoiceOverは既存の非ブロッキング方針を維持する。

## 2026-11-23 本番550円準備を一部実行（審査用0円契約の同期保護により切替を保留）

本人が`b9d6e160eb940f1d0f6d483d0d7391d882ed44b9`からの設定作成・3関数停止配備・記録を一括承認した。ただし「旧Webhook停止で既存の審査用0円契約等へ影響があれば、その工程と依存変更だけ保留」を実行条件に追加した。開始HEAD/branchは同承認ID/`feature/web-first-stripe-checkout`、開始時clean。以下は実績であり、事前の3関数切替計画を全て実行したとは扱わない。

### 停止前の限定確認と保留判断

- 既存記録の審査用0円契約をStripe GETと同UIDのFirestore billingで照合。旧500円Price＋100%/forever割引、Active、最新Invoiceは0円Paid、現在期間末は**2026-11-27 10:03:01 JST**、期間末解約予約なし。Customer/Subscription/Priceの保存参照とUID metadataが一致した。一般の有料利用者0人という方針は「Live契約自体が0件」を意味しない。旧Price関連のGET対象6件/非終端4件のうち該当0円契約1件だけを詳しく照合し、契約全体の再監査へ広げない。
- 現行アプリの通常権限は契約の保存期限も参照するため、旧endpoint停止＋新処理falseのまま次回更新を越えると期限延長が同期されず、審査アクセスを失い得る。さらに事前計画の`legacyPriceId`省略では、新Portal/Webhookはこの旧500円契約を認識できない。したがって**旧Webhook停止・同名Webhook置換・専用Portal handler置換・新Webhook署名/専用JSONの登録を保留**した。既存0円契約の移行/取消/割引変更/手動延長では解決しない。
- 対象0円契約の、直近29日で`delivery_success=false`の関連Stripe eventは検索範囲で0件。新namespaceの同UID未完了receiptも検索範囲で0件。ただしこれだけで旧endpoint個別の再送待ち全件0とは断定せず、endpoint別配送ログの全照合や実再送は行わない。現在のbilling/期間は一致し、切替保留の判断には将来の更新同期への影響が根拠となった。

### 実際の設定作成・再利用・配備

| 対象 | 実績 | 保護・停止状態 |
|---|---|---|
| Product | 既存`prod_UgrYD6tAObiCcy`を再利用 | 名前/default_price/旧設定不変 |
| 新550円Price | `price_1Uek2xK6h5kxGn4c9ji94qtp`を新規作成 | Live/active、JPY550、month/interval_count1/licensed、inclusive/per_unitをGET照合。新規申込は未接続、旧`price_1U4DbCK6h5kxGn4c2p3Y3dyN`とProduct defaultは不変 |
| 新専用Portal構成 | `bpc_1UekYpK6h5kxGn4ctmpsyYh9`を新規作成、非default | 請求履歴/支払方法/期間末解約のみ。name/email/address/phone更新・プラン変更・公開login・解約理由収集は無効。法務URL/固定returnあり。旧default`bpc_1U4eAcK6h5kxGn4c5GgRlrtk`不変、Portal Session作成0、現行handlerへ未接続 |
| Live公開可能キー | 既存Stripe Live画面から取得 | API keyの属する同アカウントIDとDashboardのアカウントが一致、pk_live/Live表示を確認。Test値代用/新規発行/rotation0。値は非公開0600実行入力だけ、専用Secret登録は下記依存保留 |
| Checkout | **`createStripeCheckoutSession`だけ**b9から先行配備。`createstripecheckoutsession-00006-ruf` ACTIVE | `HAMCARE_WEB_PURCHASE_ENABLED=false`,`HAMCARE_WEBHOOK_ENABLED=false`、既存private Invoker/IAM検査有効。旧4つのSTRIPE Secret binding/版を保持し、新JSON Secretには未接続 |
| Webhook Function | `stripeWebhook`は`stripewebhook-00010-kuq`のまま | source/updateTime/serviceConfig/IAM不変、旧Secret参照を維持 |
| Portal Function | `createStripeCustomerPortalSession`は`createstripecustomerportalsession-00009-hec`のまま | source/updateTime/serviceConfig/IAM不変。旧0円契約の管理経路を壊す置換を行わない |
| 新Secret/IAM | `HAMCARE_LIVE_WEB_BILLING_CONFIG`作成/版登録/Accessor追加は**未実施** | 新署名値のない不完全/仮JSONを作らない。旧署名値を新Webhook用に流用しない。既存Secret/認可不変、追加権限0 |
| Hosting/contact/通知 | 配備0 | Hosting22b8、contactは`billingcontactemail-00007-vah`/false、確認済み原本/履歴保持。通知worker未配備、実メール0、連絡先確認の再試験0 |

Portal作成では、署名や鍵ではなくAPIの入力検証400が2種類発生した。`cancellation_reason.options`が無効時にも必須で、1件では2件以上を要求されたため、**enabled=falseを維持してoptions=[other,unused]**を補った最終payloadで1件だけ作成した。初期要求と同じidempotency key/同じpayloadで拒否理由を診断取得した3回を含め、400応答は5回。各拒否と旧journalは保持し、結果不明を無視した再POSTや、既存設定の上書きはしていない。最終GETで専用設定1件/旧default不変を確認した。これらは設定APIの試行であり契約・請求の書込みではない。

Checkout単独先行配備は、b9の停止判定が設定/認証/DB/Stripeより前にあるため、新JSON未登録でも成立する。既存bindingを維持するためgcloudのset/update/remove/clear-secretsを全て省略した。旧STRIPE値を新設定のfallbackとして読むコードはなく、仮に誤ってpurchase=trueへ変えても新JSON欠損で停止し旧500円へ接続しない。privateを配備前後で保持し、後から閉じ直す工程はない。Node22/256Mi/1CPU/60秒/concurrency80/max20・既存実行/ビルドSAを保持した。

### Webhook設定・署名対応と停止時刻

| 経路 | ID・版・イベント・Secret参照 | 今回の状態 |
|---|---|---|
| 旧Live | `we_1U4IAnK6h5kxGn4cDdYtGpsy`、API`2026-05-27.dahlia`、URL`https://asia-northeast1-hamster-breeding-app.cloudfunctions.net/stripeWebhook`。受信5件：checkout.session.completed / customer.subscription.updated / customer.subscription.deleted / invoice.payment_succeeded / invoice.payment_failed。署名は現行Functionの`STRIPE_WEBHOOK_SECRET:3`、API keyは`STRIPE_SECRET_KEY:3` | **enabledを維持、停止時刻は未実施（停止していない）**。署名値は変更/新用途流用0 |
| 新550円予定 | **ID未作成**、API`2025-02-24.acacia`予定、同固定URL予定。7件：checkout.session.completed / customer.subscription.created / customer.subscription.updated / customer.subscription.deleted / invoice.paid / invoice.payment_failed / invoice.payment_succeeded。対応署名は新endpoint作成応答→`HAMCARE_LIVE_WEB_BILLING_CONFIG.webhookSecret`へ登録予定 | 作成/署名取得/配備/処理有効化を全て保留。旧署名Secretで代用しない |

新endpointを作成していないため、新作成直後の通知や短いenabled区間は発生していない。旧受信の権限同期を維持したまま、今回新しいbilling/outbox/通知を発生させる受信経路は作らなかった。

### 限定確認・本番変更の分類

- b9 exact sourceの隔離compileは1回、3entry登録/起動確認はhandler実行0。追加の懸念に限定し、新JSON/旧Stripe envなし＋purchase=falseでactual callable.runの旧/空/review/create 4入力を確認：unavailable、設定読取/Auth/DB/network0。既存490件や完了済み連絡先実機E2Eの再実施0。
- 配備されたCheckout archiveの**164ファイル全hashが承認b9のsrc/lib/package/lock/tsconfigと一致**、SHA256 `0f27bc3577773379074cdb96b3740109b5463c31fd7393ecc601431dd426708c`。Secrets/環境ファイル/node_modules/テストを配備に同梱しない。Functions/Run両経路へtokenなし空callableを各1回→403。IAMの拒否とhandlerのローカル副作用0は区別する。ACTIVEの正常起動を確認し、設定不足エラーを意図した停止と取り違えない。
- Stripe設定の成功書込みは**Price1件/Portal1件**。旧Price/Product/default Portalのfingerprint不変。Webhook設定書込み0。Cloud設定変更はCheckoutのsource/revision/両false flagだけ、既存Secret参照/IAM有効bindingは不変。専用Secret/IAM追加/他Functions/Hosting/Rules/Index/ストア変更0。復旧実行0。
- 審査対象のSubscription状態・期間・discount/items・最新0円Invoice、同UID billing全文は前後一致。確認済み連絡先はverifiedのまま、contact Functionのrevision/falseは不変。今回の契約/Customer/Checkout Session/Invoiceの作成変更0、billing/権限/体験/Auth/プロフィール/既存テスター/Preview/Storage変更0、実メール/再送/実削除/実Apple失効0。構成変更があるため「本番変更0件」とは記録しない。

### 再開前の照合と残件（今回は実行しない）

1. 審査用0円契約の継続同期を止めない受信経路/切替条件を先に確定する。**新旧endpointを両方止める旧計画を、0円契約が有効なまま無条件に実行しない。**既存legacy認識を使うPortal/Webhook用JSONでは`legacyPriceId=price_1U4DbCK6h5kxGn4c2p3Y3dyN`の保持が必要。ただしこれだけではWebhook false/旧停止による期限更新停止を解決しない。新しい移行システム、契約取消、割引変更、手動権限延長へ広げない。
2. 旧停止/新再開を別承認で進める場合、停止開始/終了のUTC・JSTと旧新ID/API版/署名参照の組を必ず記録する。今回は停止期間自体がない。再開直前にStripeの同Subscription・discount・Price・最新Invoice/periodとFirestoreの同UID Customer/Subscription/Price/currentPeriodEnd/状態をGET照合する。日時・課金・UIDに差があれば停止し、Firestoreを手書き修正しない。
3. 対象期間の7イベントを、対象Customer/Subscriptionに限定して既存endpointの配送履歴・失敗/未処理receiptと照合し、欠けた具体的eventだけを特定する。イベント全体のdelivery_success/pending_webhooksだけで個別endpointの未処理0と断定しない。旧経路の通常`stripeWebhook`、または新経路の署名/同UID/Stripe正本再取得を伴う既存Webhook engineへ、**別承認後に対象eventを正規再送して同期**する。実再送・既存イベント一括再処理は今回0。成功ページや手動billing変更で同期済みにしない。
4. 同期維持が成立してから、新7event endpoint/新署名の完全Secret＋単体Accessor、Webhook/Portalの限定切替、Checkoutの旧未使用binding→専用JSON接続を再開する。Live pk取得は完了済み。再発行せず、後続時に保存済みの非公開入力を確認して同じ既存キーを再利用する。署名・JSONがないまま新処理を有効化しない。
5. その後にLive callable adapter/DTO、決済後の正規status照合への復帰、必要なHosting/CSPを実装・限定確認する。これらは未実装で今回変更0。一般購入・メール・新Webhook処理の有効化、最小Live契約、請求/同期確認はさらに別承認の工程。Relay実配送/追加VoiceOverは非ブロッキングを維持する。


## 2026-11-22 事前承認計画：550円・課金API・Webhook（11/23の実行で一部保留）

**以下は事前計画の記録。審査用0円契約を確認したため、新旧Webhookの両停止とlegacy省略のままの切替は保留した。今後の実行条件・現状は冒頭の2026-11-23実績を正本とし、この旧計画だけで残工程を実行しない。**

連絡先確認は承認済み`cd624d4c9ae7c4357f578c6981c325a53c9b670f`で**完了**。今回再試験せず、確認済み原本・累計2通・履歴・購入停止・contact falseを維持する。本節は既存26工程の次の設定依存だけを実行可能にしたもので、一般購入・一般送信・実契約の開始手順ではない。今回実行したのは対象設定のGETとローカル最小修正/試験だけで、本番の作成・配備・IAM/Hosting変更は0。

### 配備元と照合した現在地

- branch：`feature/web-first-stripe-checkout`。開始HEAD `cd624d4c9ae7`、clean。配備元は**今回の停止制御・test・本節を含む準備コミット**（完了報告の40桁IDを`BILLING_DEPLOY_COMMIT`へ固定）。branch先端の自動採用は禁止し、実行前に承認IDとclean状態を照合する。
- project：`hamster-breeding-app`（797691641198）、region：`asia-northeast1`。2026-11-22の対象GET結果は以下。識別子は設定オブジェクトだけであり、UID/Customer/Subscription/受信者/資格情報は記録しない。

| 対象 | 既存状態 | 次の承認後の変更 |
|---|---|---|
| Product | `prod_UgrYD6tAObiCcy`、Live/active、Hamster Care Premium Plan | 再利用。名前/default_price/旧設定を変更しない |
| Price | `price_1U4DbCK6h5kxGn4c2p3Y3dyN`、JPY500/month、active、exclusive。550円Priceなし | 同ProductへJPY550/月1回/licensed/inclusiveを**新規1件**。旧500円は変更/削除せず、default_priceも500円のまま保持。新規申込の唯一の`priceId`を新550円IDへ |
| Portal | `bpc_1U4eAcK6h5kxGn4c5GgRlrtk`、Live/default。期間末解約は正しいがname/email/address/phone更新を許可、法務/return未設定 | 旧defaultは維持し、非defaultの専用Configurationを**新規1件**。下記payloadへ限定 |
| Webhook | `we_1U4IAnK6h5kxGn4cDdYtGpsy` enabled、固定stripeWebhook URL、API`2026-05-27.dahlia`、5イベント | 旧endpointは削除せず**disabled**へ。SDK固定版に合う新endpointを**1件作成→直ちにdisabledへ更新**。新署名Secretとの対応を一本化し、今回の接続準備終了時は両endpoint停止 |
| API版 | 既存endpoint/未指定API応答はdahlia。実装のStripe17.7.0は`2025-02-24.acacia`固定 | SDK更新なし。新endpointの`api_version`を`2025-02-24.acacia`へ明示。固定版付きPrice GETはHTTP200/同版の応答を確認済み |
| 専用Secret | `HAMCARE_LIVE_WEB_BILLING_CONFIG`未作成 | 完全なLive JSONのSecret/versionを新規登録。旧`STRIPE_*`とcontact用mail Secret v3は変更しない |
| Web | Live version`22b8c97c2532f11c` FINALIZED、45hash/CSPは停止版と一致 | **Hosting/CSP変更0**。Live adapter/DTO/成功後status接続は未実装で今回対象外。購入受付をtrue/publicにする前の別実装・限定検証が必須 |

旧endpointのAPI版は作成後に変更できないため、イベントの追加だけでは版の不一致は解消しない。[Stripe公式Endpoint仕様](https://docs.stripe.com/api/webhook_endpoints/object)、[版切替手順](https://docs.stripe.com/webhooks/versioning)を根拠とする。既存SDKのv1 createにはdisabled指定がなく、作成と停止は別操作である。作成直後の短い有効区間は旧handlerが新署名を受理しないため非2xxとなり得る。実行時に両操作の時刻と当該区間の対象イベント有無をGETで確認し、発生があれば未処理として停止・報告し、黙って処理済みにしない。queryによる二重経路、2署名Secret対応、別の新Functionは追加しない。

### 次の承認後だけ使用する設定payload

生成される新`price_...`/`bpc_...`/`we_...`は返却値を非公開実行記録へ束縛し、IDを推測しない。既存の一致する専用設定が実行前に見つかれば厳密GET照合して再利用し、同じものを重複作成しない。POSTには操作ごと固定のidempotency keyを付け、結果不明時は一覧/metadataで照合し、新しいkeyで再作成しない。

- Price POST `/v1/prices`：`product=prod_UgrYD6tAObiCcy, currency=jpy, unit_amount=550, recurring.interval=month, recurring.interval_count=1, recurring.usage_type=licensed, tax_behavior=inclusive, lookup_key=hamcare_premium_monthly_550`、metadata purpose=`hamcare_web_live_550_v1`。Customer/契約/Invoiceは作成しない。新PriceのLive/active・Product・550・月1回・inclusiveをGET検査。`automatic_tax=false`/割引なし/数量1は既存Checkout実装で維持し、ユーザー向け正式表示は月額550円のみ。
- Portal POST `/v1/billing_portal/configurations`：`features.customer_update.enabled=false, allowed_updates=[]; invoice_history.enabled=true; payment_method_update.enabled=true; subscription_cancel.enabled=true, mode=at_period_end, proration_behavior=none, cancellation_reason.enabled=false, cancellation_reason.options=[other,unused]; subscription_update.enabled=false; login_page.enabled=false; default_return_url=https://hamster-breeding-app.web.app/account/?portal=return; business_profile.privacy_policy_url=https://hamster-breeding-app.web.app/privacy/; business_profile.terms_of_service_url=https://hamster-breeding-app.web.app/terms/`、metadata purpose同上。旧defaultを変更せず、返却の`is_default=false`と全機能を検査。Portal Sessionはこの準備では作らない。[公式Configuration仕様](https://docs.stripe.com/api/customer_portal/configurations/create?api-version=2025-02-24.acacia)
- 新Webhook POST `/v1/webhook_endpoints`：`url=https://asia-northeast1-hamster-breeding-app.cloudfunctions.net/stripeWebhook, api_version=2025-02-24.acacia, connect=false`、description/metadata purpose同上。eventsは厳密に`checkout.session.completed`, `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.paid`, `invoice.payment_failed`, `invoice.payment_succeeded`の7件。最後の旧success aliasを維持し、全イベント`*`を使わない。返却直後に同IDへ`disabled=true`、GETで停止を確認する。secretは作成時の値をメモリから専用Secretへ渡し、stdout/Git/ログに出さない。
- `HAMCARE_LIVE_WEB_BILLING_CONFIG`のJSON field：`secretKey`（既存`STRIPE_SECRET_KEY:3`の同Live keyをメモリで再利用）、`publishableKey`（同じStripeアカウントの実`pk_live`）、`priceId`（新550）、`webhookSecret`（新endpointの署名値）、`portalConfigurationId`（新専用構成）、`origin=https://hamster-breeding-app.web.app`, `returnUrl=https://hamster-breeding-app.web.app/account/?portal=return`。事前計画では有料契約者0人を根拠に任意`legacyPriceId`を省略する予定だったが、2026-11-23に実在の審査用0円契約を確認したため、そのままのPortal/Webhook置換は不可。既存のlegacy認識と通常同期を維持する条件を冒頭の保留実績に従って解決する。旧500円の移行/記録更新は追加しない。
- **実行前に必要な未登録値は同アカウントのLive公開可能キー1件**。関連Secret一覧・既知の環境ファイルでは見つからなかった。本人がStripe Live画面から非公開の設定入力へ渡す（チャット貼付不要）。仮値/Test値/Preview値で補完しない。これが揃う前に旧endpointを止めたり3関数を更新したりしない。新設定IDと新whsecは作成後に取得する生成値であり、追加の方針判断ではない。

### 承認対象となる適用順序・成功条件・復旧

| 順 | 実施対象と変更 | 購入/メール停止・成功確認 | 停止・復旧 |
|---|---|---|---|
| 0 | 承認commit、3関数の現行source世代/環境/Secret参照/Invoker、旧Stripe設定を非公開退避。実Live pkを用意 | Checkoutのservice/project公開Invokerなし、IAM check有効を実行前に再照合。contact false/既存確認済み原本は変更しない。新Api/Project IAM追加なし | source/設定/鍵の対応を確定できなければ本番変更前に停止 |
| 1 | 新550円Priceを作成、既存Productを再利用 | Live/550/JPY/月1回/数量仕様に一致、旧500円/default_price不変 | 不一致なら後続停止。新Priceは記録を消さず必要時inactive、旧500へ接続しない |
| 2 | 専用非default Portal構成を作成 | 支払方法/請求履歴/期間末解約だけ、氏名・メール・プラン変更/公開loginなし | 設定不一致なら参照せず停止。旧defaultはそのまま |
| 3 | 旧`we_1U4IAn...`をdisabled、新Acacia endpoint作成→直ちにdisabled | URL/7event/版/新whsecの対応、短いenabled区間の記録。新旧を同時enabledにしない | new disabledを維持。旧handler/旧whsecが不変なら旧endpointだけ復旧可能。切替途中のイベントを消去/一括再処理しない |
| 4 | 新Live課金Secret作成/完全JSON1版登録。既存compute SAへ当該Secret単体Accessor | `797691641198-compute@developer.gserviceaccount.com`にSecret単体`roles/secretmanager.secretAccessor`。旧Secret/Preview/mail v3不変。秘密値非表示 | 欠損/IAM不備なら配備しない。旧Secretを削除/上書き/失効させない |
| 5 | `createStripeCheckoutSession`だけ限定更新 | 環境`HAMCARE_WEB_PURCHASE_ENABLED=false`,`HAMCARE_WEBHOOK_ENABLED=false`。既存非公開Invokerを最初から維持。handlerも設定/Auth/DB/Stripe前で拒否 | 購入403が維持されなければ後続停止。公開を後から閉じ直す工程に依存しない |
| 6 | `stripeWebhook`だけ限定更新。専用Secret/新署名へ切替 | public Invokerは既存のまま、`HAMCARE_WEBHOOK_ENABLED=false`。有効署名でもprocess/claim/Stripe API/DB前503+Retry-After60。新旧Stripe endpointはdisabledのまま | 新endpoint停止を維持。旧source/旧STRIPE_*参照を対で復元した後だけ旧endpointを再開。片側だけ切戻さない |
| 7 | `createStripeCustomerPortalSession`だけ限定更新 | 既存public Invoker/本人認証・同UID既存Customer限定を維持。確認連絡先を管理の必須条件にしない。匿名要求はAuth拒否、Customer/Session/契約作成0 | 失敗時はこの1関数の退避source/旧Secret参照だけ復旧。新規購入は停止のまま |
| 8 | 対象3関数と新Stripe設定をGET照合、下記停止smoke | 承認source/Secret version/flags一致、購入両経路403、署名不正400・正署名停止503。業務データ/送信0を確認 | 想定外の権限書込/メール/起動エラーなら終了扱いにせず停止・復旧。構成変更と業務データ変更を分けて報告 |

**この次回準備配備の終了状態**は購入false/非公開、Webhook処理false/新旧Stripe endpoint disabled、contact false/日次1、通知worker未配備、Hosting45不変。Webhookの登録/署名/関数接続が準備できた状態であり、受信同期の稼働PASSではない。新Webhookのenabledと処理true、一般購入true/public、一般メール開始、実契約はこの停止準備の承認に自動で含めず、専用の実課金確認/公開判断で明示する。

### 限定配備方法と停止を維持する根拠

配備は既存の3 Function/対応Run serviceだけ。同名・同entrypointを更新し、sourceへ含まれる他export/workerを配備しない。現在のrevisionはCheckout `createstripecheckoutsession-00005-ceb`、Portal `createstripecustomerportalsession-00009-hec`、Webhook `stripewebhook-00010-kuq`。service名はそれぞれ`createstripecheckoutsession`/`createstripecustomerportalsession`/`stripewebhook`。

- 呼出入口はcallable2件＋HTTP webhook1件を維持。`onCall({invoker:'private'})`は現Firebase Functions SDK7.0.1のmanifestへ反映されないため、見かけのオプションを安全根拠にしない。Firebase CLI13.29.3はcallable新規時にpublicを設定し、限定filter前に無関係Secretを要求し得るため、今回使わない。gcloudの**既存関数更新**は公開化を要求しなければInvokerを維持する。
- Checkoutは**配備前から公開bindingなし**を必須条件にし、`--allow-unauthenticated`を付けない。`--no-allow-unauthenticated`の防御指定があっても、配備後に閉じ直すことで安全を得る計画にはしない。HTTPへ到達しても新runtimeの`purchaseEnabled !== true`が最初に停止する。非公開IAMと明示falseの両方を維持し、設定完成だけで受付を開かない。
- 全3関数は既存実行/ビルドSA（上記compute）、Node22、256Mi/1CPU/60秒/concurrency80/maxInstances20を明示して現行リソースを維持。sourceのFirebase CLI向けmaxInstances10を自動適用する方法と混在させず、今回はgcloud設定を正本とする。新規API有効化/サービスID作成/追加Project roleなし。
- 承認commitから隔離したFunctions sourceを作り、既存lock一致の依存でcompile後にsrc/lib/package/lock/tsconfigだけを配備。`.env`/node_modules/テスト/私用ファイルを同梱しない。実配備archiveのsource/compiled hashを今回commitと照合する。
- 各関数は旧`STRIPE_*`**参照を専用JSON参照へ置換**するが、Secret Manager内の旧Secret/版を変更しない。新Secret version番号を確認して固定し、`latest`/Test/Preview/旧価格fallbackを使わない。

承認後の各1関数更新コマンドの形（**今回は実行していない**。source path/Secret版は実行記録へ確定する）：

```sh
CLOUDSDK_CORE_DISABLE_FILE_LOGGING=1 gcloud functions deploy FUNCTION_NAME \
  --project=hamster-breeding-app --region=asia-northeast1 --gen2 \
  --runtime=nodejs22 --source="$BILLING_DEPLOY_SOURCE_DIR" \
  --entry-point=FUNCTION_NAME --trigger-http \
  --service-account=797691641198-compute@developer.gserviceaccount.com \
  --build-service-account=projects/hamster-breeding-app/serviceAccounts/797691641198-compute@developer.gserviceaccount.com \
  --memory=256Mi --cpu=1 --timeout=60s --min-instances=0 --max-instances=20 --concurrency=80 \
  --update-env-vars=HAMCARE_WEB_PURCHASE_ENABLED=false,HAMCARE_WEBHOOK_ENABLED=false \
  --set-secrets="HAMCARE_LIVE_WEB_BILLING_CONFIG=HAMCARE_LIVE_WEB_BILLING_CONFIG:$BILLING_SECRET_VERSION" \
  --docker-repository=projects/hamster-breeding-app/locations/asia-northeast1/repositories/gcf-artifacts \
  --quiet
```

`FUNCTION_NAME`は上記順序で1件ずつ置換する。Checkoutだけ`--no-allow-unauthenticated`を追加し既存privateを維持、Portal/Webhookは認証公開フラグを付けず既存publicを維持する。3件完了後の全体deploy、Scheduler作成、通知/削除/体験/AI等の更新はしない。

### 配備後の成功確認（次の承認後のみ）

1. 3関数のACTIVE/source/専用Secret版/flags、Run Invoker差分を照合。資格情報不足・起動失敗を停止制御PASSにしない。
2. Checkoutの通常Functions/Run経路へtokenなし空callableを各1回→403。これはIAMの証拠でありhandler falseの実行証明ではない。handler副作用0は今回のMock/compile/実配備hash照合と分けて記録する。
3. Portalへtokenなし空callable1回→unauthenticated（Customer/Portal Sessionを作らない）。contactの再送・受信試験は行わない。
4. Webhook不正署名1回→400。次に新whsecをメモリだけで使った**合成Live eventの正しい署名POST1回**→503/Retry-After60。実Stripe event/Customer/契約/Invoiceは作らない。合成event hashのFirestore receipt不存在を前後でGET確認し、claim/Stripe API/billing/outbox書込0を照合する。これは停止handlerの確認で、Stripeからの実配送/同期E2E PASSではない。
5. 専用Secretの配置・API/Price/Portal/新Webhook版と全flagを読み直し、新旧endpoint disabled、購入非公開、contact false/確認済み原本保持、worker不存在、Hosting版不変で終了する。既存テスター実データ更新/AI送信/全アプリE2Eをしない。

### テスター・通知・Web接続の境界と残件

- 更新対象は3 exportだけ。通常ログイン/飼育記録/21日体験/権限取得/既存アプリ内削除は配備しない。`billing_contacts`不存在を通常利用の条件にしない。停止中WebhookはFirestore receiptすら作らず、無料ユーザーのbilling/体験/権限を変えない。稼働後の既存engineもUID/Customer/Subscription/Priceの照合、元trial_end、CAS/遅延event/削除フェンスを維持する。料金・体験や権限評価ロジックは変更していない。
- `processBillingNotificationOutbox`は現在未配備、今回も配備しない。送信は同workerの15分Schedulerだけで、Firestore outbox作成を直接送信するtriggerはない。Webhookが将来有効になるとpending outboxが作られ得るが、今回falseなので作成0。**contact falseを通知workerの送信停止の代替にしない**。mail Secret v3は本人限定/消費済み2枠のまま、一般通知へ変更せず、過去通知の一括送信/再処理0。通知の一般設定/workerは有料受付前の別工程。
- Hostingは22b8/45を維持。canonical accountは`checkoutService=null`でLive課金APIへ未接続。Preview transport/DTO（testMode/pk_test/cs_test）をLiveへURLだけ差し替えない。Live callable adapter/安全なDTO projectionと、旧`/billing/success/`の静的成功断定から署名同期済みstatusへ戻す接続は未実装。一般購入をtrue/publicにする前の別実装・限定検証が必須。今回は旧13HTMLも変更しない。
- 将来Web接続時だけ`/account/**`のCSP connect-srcへ固定Checkout/Portalの2 URL（上記function名のasia-northeast1 cloudfunctions.net）を追加する。WebhookはブラウザCSPへ追加不要。Stripe script/frame/購入CTAは別の公開判断まで追加しない。この未接続を残したまま「本番購入可能」とは報告しない。
- 新旧endpointがdisabledの準備状態は無期限のイベント保管ではない。StripeのLive自動再送は最大3日で、disabledのendpointは以後の再送が抑止される。[Stripe配送仕様](https://docs.stripe.com/webhooks#automatic-retries)。稼働開始時に対象期間/イベントを確認して未処理を特定し、古いイベントの一括再処理を自動で行わない。
- 復旧は購入false/private→新endpoint disabled/Webhook falseを優先。退避した**各関数の元source世代と元環境/Secret参照を対で**同名関数へ限定再配備する。旧Webhook復元の正常性を確認後だけ旧endpointを再enable、新endpointは停止。新Price/専用Portal/Secret/receipt/既存履歴は削除しない。Runの旧revisionへtrafficだけ戻してFunctions管理状態と不整合のまま放置しない。Hostingは今回変更0のためrollback不要。

### 今回の限定検証と未実行事項

strict TypeScriptと今回直接関連のMock回帰**490/490 PASS**。購入flag missing/false/不正値はconfig/Auth/DB/Stripe0、旧空要求/同UID認証/Apple連絡先reader/Portal既存管理/550/元trial終了/署名Live/重複・遅延・削除フェンスを維持。Webhook falseは署名後503/Retry-After60でprocess/claim0、不正署名400。連絡先の受信・確認済み保存・復帰の再試験0。依存/SDK更新0。実環境は構成GETだけで、停止probe・新設定作成・関数/Hosting/IAM変更・実メール/契約/削除は0。次の承認対象は本節の0〜8の停止準備だけである。


## 2026-11-22 追加1通で本番連絡先確認を完了（累計2通・停止復帰済）

開始点`69c2667947d5`。本人が「追加最大1通・前回を含む累計最大2通」、同じ本人UID/画面指定1宛先、必要な最小コード/設定/1関数配備、本人contact/確認情報/制限記録の書込み、完了後停止を承認した。準備配備のやり直しや古いSecretへの巻戻しは行わない。

- **宛先・前提**：前回の予約1/要求履歴1/日次全体・本人各1/期限切れpending/verified=falseを読み取り、追加枠が未使用であることを確認。本人は別宛先を選び、Mac内の一時入力画面へ直接指定。最初の保護判定によるRejectedは宛先保存/送信前に修正し、再入力・本人所有チェックを受理。選択値は非公開0600ファイルだけに保持し、メールは正規の本番フローから発行。Apple ID/Authのメールを宛先の正本にしない。
- **累計2の制御**：trusted Secretの`maxTotalSends:1|2`、UID/宛先hash各1、有限期限。max2は旧slot1の厳密7項目/schema1/同owner/正規hash/予約時刻を確認し、固定slot2だけtx.create。slot2にはordinal2/旧notification hashを記録。旧宛先のslot1は変更せず、新指定宛先をslot2へ束縛。同key再送、slot2消費後、翌日・再起動・期限/上限再設定でも3通目なし。送信直前transactionが最終防壁で、既に枠消費済みのrequestはpending変更前に拒否する。
- **検証/配備**：4srcとtest2のみ、strict TypeScript・関連330/330・Hosting helper10/10 PASS。Secret v2の送信専用認可をメモリで再利用し、同UID/新宛先/累計2/6時間を明示したv3を追加。既存scope gmail.sendだけをrefresh確認、OAuth設定/同意/Previewのread/write変更0。`billingContactEmail`だけfalse/日次2/v3で配備し、revision`billingcontactemail-00005-sas`、164ソース/compiled/package一致、archive SHA256 `c7af10c1e7c66e9744f5fd084ccf2d2b09bc250eb4ba053ab0ca0b141e182d4a`。本人限定trueのrevision`billingcontactemail-00006-fuj`へ切替。他Functions/IAM/Rules/Index/Stripe/Flutter/ストア変更0。
- **実機E2E PASS**：本人が本番で同じAppleアカウントへログインし、送信直前のスマホ準備確認に「今から確認できる」と回答。新指定宛先で追加メールの受信・差出人/本文/スマホ表示に問題なしと報告。新しい確認リンクを開き「連絡用メールを確認済みです」を確認。同UID/正規Live原本で新宛先verified=true、pending消去、usedTokenHashes1、要求履歴2/旧prefix保持、旧slot1 full-document hash不変/slot2正規、同UTC日のglobal/owner counter各2を照合。token/link全文のGit/診断/Firestoreへの保存・表示なし。初回1通の実配送は未確認の履歴のまま維持する。
- **送信操作と保存の照合**：UI要求後、一度「再送が続いています」と確認済みパネルが同時表示された。直ちにDBを照合すると追加枠は消費済み・確認済み保存済みだったため、既に進んだ処理を引継ぎ、再送しない。要求と送信の順序/操作主体は推測せず、実績は永久2予約・日次2・履歴2・本人受信報告で確認。上限拒否は3通目の送信成功とは扱わない。以後のアカウント再表示は正常で、Web画面の追加改修は行わない。
- **画面復帰 PASS**：スマホで固定「プラン確認へ戻る」→「アカウント確認へ戻る」→再読込後も「確認済みの連絡先を利用できます」を本人確認。Macでも固定plan/アカウント復帰と確認済み連絡先表示を照合。Authメールは未設定のまま、別の連絡先補完が保存された状態であり、購入受付/課金/無料体験を開始しない。
- **停止復帰**：revision`billingcontactemail-00007-vah` ACTIVE、enabled=false/日次1/v3参照。POST status/request/confirm各503+`contact_service_unavailable`、購入API403（tokenなし、送信0）。Hostingの一時案内4aadを終了し、停止版`22b8c97c2532f11c`へ直接再release、45hash/CSPと実画面を確認。旧journalを再利用/巻戻しせずround2専用journalへ記録した。資格情報/確認済み原本/全履歴/旧永久slot/追加slotは取り消さず保持。
- **書込みの分類**：構成変更はLive Secret v3・対象1Functionのcode/revision・一時flag/日次枠・Hostingの案内切替/復元。業務書込みは本人`billing_contacts/{uid}`の正規pending再発行→verified保存/usedhash、既存日次global/ownerの2docの1→2、追加attempt予約とslot2の新規2doc。日次枠は停止時1へ戻してもcounter2を保持し、リセットしない。Auth projection/owner/pet/trial/billingの基準hashは停止後も不変、他テスター/Preview/契約/利用権限/Stripe/Storage/Apple設定変更0。
- **終了条件**：今回追加1通・累計2通、受信/確認/同UID保存/スマホ復帰を完了。3通目・旧リンク利用・期限延長・履歴削除は行わない。一般受付/一般送信を停止したまま、このコード/test/既存2文書だけを1コミット。実Relay配送等の別タスクを今回のPASSへ混ぜない。

## 2026-11-22 準備配備の承認範囲と現在地の再照合

準備配備は`14b7904edb53`から実行し、`d475c8b229e1`で記録済み。今回求められた購入停止の実効性と静的検査3件目の具体的説明も同記録に含まれる。後続の本人限定連絡先確認`304465659444`を巻き戻さず、今回は再配備・Secret登録・OAuth変更をせず、現行停止状態の再確認とこの追記だけを行った。

- 購入serviceのInvoker IAMチェックは有効、service/projectの公開bindingなし。一般向けFunctions URLとRun URLへのtokenなし空callable要求はともに403。Live Checkout SessionをGETで再読取りし、open 0/有効な未完了0。失効・契約取消・Customer/Session作成なし。
- contactはACTIVE/revision`billingcontactemail-00004-luf`、`HAMCARE_BILLING_CONTACT_ENABLED=false`/日次1/Secret v2。正規Originのstatus/request/confirm各503・`contact_service_unavailable`で、起動失敗ではない。Hosting最新versionは`22b8c97c2532f11c`で停止版のまま。旧13保全＋追加32/CSP限定の配備実績は下記記録を維持する。
- 静的3件目は`production billing/Auth source unchanged functions/src/index.ts`。旧基準との全文不一致を保持し、共有認証と停止条件の欠落ではないこと、旧58関数を配備しないことを根拠に準備配備を進めた。168/171をPASSへ変更せず、検査も無効化しない。
- この再確認の構成変更・配備・実メール・Stripe書込み・ユーザー業務データ変更は0。後続承認で登録済みのSecret v2/送信専用認可は維持し、本人pendingも変更しない。先行タスクの1通受付を実配送・確認完了として扱わない。一般受付/送信を引き続き停止し、今回の文書追記だけを1コミットにする。

## 2026-11-22 本人限定の連絡先実確認（1通受付・確認未完了、停止復帰済）

開始点`d475c8b229e12af3b64c7498a0c86c4b74fd989f`。本人が1UID/1宛先/最大1通・必要な最小実装/配備・本人連絡先/送信制限の書込み・確認後停止・1コミットを承認。購入/Stripe/通知worker/他Functions/一般送信/削除/Flutter/ストア/merge/pushは範囲外。前工程の全監査/E2Eをやり直さず、今回の変更境界だけを確認する。

| 対象 | 実施内容/現時点の結果 |
|---|---|
| 本人/宛先 | 前回Preview Secretの許可hashと既存verified情報を本人同定にだけ使用。該当1UIDを現在Auth/既存owner/petで再照合、Apple/emailなし・本番contact未作成を確認。Liveのverified値をPreviewから移さない。個人値は非公開の実行用束縛情報だけに保持 |
| OAuth | 既存sender grantをrefreshしgmail.send単独を確認。新しいOAuth同意/取消/Preview Secret変更なし。Auth Platformへgmail.sendの宣言と用途を追加、既存YouTube宣言/用途を維持。検証要求表示は残り、一般向け検証完了とは扱わない |
| Live Secret | `HAMCARE_LIVE_BILLING_MAIL_CONFIG` version2。明示Live設定、許可UID/正規化宛先のSHA各1、`limitedContactTest:{expiresAtMillis,maxTotalSends:1}`。期限は登録時から6時間、日次1を明示。資格情報は同じ送信専用grantを再利用し、Preview設定へのfallbackなし。Secret Accessor/IAM拡張なし |
| 最小実装 | `billingNotificationGmail` parserで限定markerと厳密1件のリストを許可し、裸のLive allowlist/不正policyは拒否。Runtimeは既存false停止を維持し、true時のAuth後・アプリDB前にUID/宛先を拒否。Storeの固定`billing_notification_delivery_limits/_limited_contact_test`へ送信直前にtransaction create。既存なら同じkeyでも再POST不可。TTL/返却/日次再利用なし。失敗/未知結果でもslot保持。request前read guardで最初のpendingを守る |
| 他sender/Preview | 通常LiveとPreviewの既存分岐を維持。限定Secretを誤って通知senderへ渡しても予約callbackがなければ送信前に停止。既存OAuth前失敗の有限backoffは維持し、Gmail不可逆POSTは最大1。PreviewのSecret/認可/関数/確認済みデータに変更なし |
| 試験 | backend/共有Gmail306、関連Web85、ローカルHosting helper9 PASS、strict TypeScript PASS。合成Mockのみ。UID不一致/宛先違い/期限/日次設定違い/同時要求/翌日/再起動/unknown後の2回目を拒否。最初のproof保持と通常メール/Relay/Preview回帰を確認。Mockを実アカウントの拒否試験済みとは扱わない |
| 配備 | `billingContactEmail`のみ。v2参照/falseのrevision`billingcontactemail-00002-hox`→本人ログイン後trueの`billingcontactemail-00003-kin`（19:54:56 JST）。既存SA/1CPU/256MiB/max1/concurrency5/60秒/日次1を維持。未認証status401、購入受付停止は変更しない |
| 一時Hosting | `22b8c97c2532f11c`→`4aad15f145ca5691`、2 HTMLの案内だけを本人限定へ変更。43ファイルとCSP/JS/Auth不変、45全hashを公開前後に照合。終了時に旧停止版を直接再releaseし、同じ45hashへ復元済み |
| 実送信 | 本人が本番Appleログイン後、同じsessionのcontact statusが登録可能を表示。照合済み宛先へUI要求を1回だけ実行。UI送信済み・pending deliveryState sent・requestedAt1・全体日次1/本人日次1・永久slot存在を確認。受信/ブランド/本文/スマホ/リンクは未確認のまま15分期限到達。事前テストメール/再送なし |
| 許可されたFirestore | 本人`billing_contacts/{uid}`のpending（正規のpurpose/schema/UID、メール、token hash、15分期限、送信状態、request履歴）。既存Live日次全体doc、本人hash別doc、attempt予約doc、固定永久slotの計4制限doc。仕様上は確認時に同じcontactのverified/usedTokenHashesへ遷移するが、今回は未達。raw token/確認URL/認可情報は保存しない |
| 保護/停止 | owner/pet/initial_trial_v2/billingはhash不変、Authメール/プロフィール/契約/権限の更新0。当初は確認完了と固定plan復帰の後に停止する予定だったが、今回は確認未達のため失効後false/停止版復元を実施。本人原本は未確認pendingのまま保持し、共用OAuthは取消さない |

### 最終実績（確認E2Eは未完了）

- 実送信要求**1回**。Gmailが受け付け、UIと本人pendingの`deliveryState:sent`/`requestedAt:1`、日次全体/本人各1、永久slot存在を確認。受信・ブランド差出人・本文・スマートフォン表示の本人報告は得られず、実配送をPASSにしない。15分以内に同UIDのverified保存がなく、最終確認でも`verified:false`、`usedTokenHashes`0、pending失効。リンク確認/確認済み保存/固定plan復帰は未達。
- 失効後は追加送信せず停止復帰。**20:13:15 JST**、`billingcontactemail-00004-luf` ACTIVE、`HAMCARE_BILLING_CONTACT_ENABLED=false`/日次1/Secretv2。POST status/request/confirm各503かつ`contact_service_unavailable`、購入API403。起動失敗ではなく実handlerの停止応答。Secretの資格情報・Preview grantを取り消さない。
- Hostingの一時版`4aad15f145ca5691`を終了し、元の`22b8c97c2532f11c`を再release。全45hash/CSPを再照合し、本番Chromeの静的停止案内を確認。原本JS/Auth/価格/LP/法務は不変。一時2HTMLの表示変更はGitの製品コードへ混ぜない。
- 本番業務データ書込みは許可された本人`billing_contacts/{uid}`1docのpending（token hash/15分期限/送信結果/request履歴）と、`billing_notification_delivery_limits`の全体日次doc・本人hash別日次doc・attempt予約doc・`_limited_contact_test`の**4doc**。確認済みへの書込みは0、原本と必要な予約記録は保持。raw token/link/OAuth値は保存/診断表示しない。期限延長、回数リセット、slot削除0。
- Auth管理readで同UID・Authメール未設定・provider構成不変を確認。owner/pet/initial_trial_v2/billingの基準hashも一致。既存テスター/他Functions/Preview設定/連絡先/送信認可/既存契約/Stripe/Flutter/ストアに変更なし。既存のSecret単体Accessor/public Invokerを維持し、新しい権限を付与しない。
- 配備ソースarchive SHA256 `c4dc79e735daab07d32417a9f32223f5f2a1f96eed2fb3b330a1c5e63ad46d6d`、162のソース/compiled/packageをstaged内容と照合（base d475＋今回4source）。Secret/env/依存をarchiveへ含めない。停止への更新は環境フラグだけ。
- 受信・表示と確認E2Eは残件。既存メールは失効しているため、この1通だけでの確認完了を今後PASSへ変えない。再開には本人が操作できるタイミングで、追加の送信範囲と新しい1回制限を別途判断する。現行枠を勝手に戻さず、過去の予約証跡を保持する。一般受付・一般メール送信は引き続き停止。Relay/追加VoiceOverは今回の条件へ追加しない。

本番メールの送信受付だけで実配送PASSとしない。送信結果が不明でもslot/日次枠を戻さず、受信・既存記録を照合する。今回上限1の許可は追加メールや一般向け有効化の承認ではない。実施結果/未達項目・停止復帰・本番書込み実績と残件を確定してから、今回のコード/test/この2文書だけを1コミットにする。

---

## 2026-11-22 一般受付停止での本番準備配備：承認済み範囲と実行記録

本人が提示一覧・既存購入受付停止・復旧を一括承認し、2026-11-22に以下の限定配備を実行した。配備元は`14b7904edb53f8270420a4c2e58fd35d5be5dd44`、`feature/web-first-stripe-checkout`。実行開始時の未コミット差分は承認資料の指定2文書だけで、他の差分・素材は変更していない。現在は無料テスターのみ・一般有料利用者0人。正式ローンチの別判断まで購入停止を維持する。後段26工程全体や一般受付・送信・削除の有効化を承認/実施したものではない。


### 実行結果（2026-11-22 JST）

| 実施対象 | 実績・限定確認 |
|---|---|
| 開始/配備元 | 19:04:03 JST開始、`14b7904edb53`のFunctionsをGit archiveで隔離展開。既存lock/dependencyを再利用、TypeScript build PASS。配備後GCS sourceのsrc/lib/package162ファイルはstaged承認ソースと一致、`.env`/node_modules同梱0。archive SHA256 `829403e8cf23e5865f024ea493395f1c3a46e6772126cec4770dc2d883c54bb2` |
| 購入停止 | `createstripecheckoutsession`の`allUsers → roles/run.invoker`を除去。公開project Invokerなし・Invoker IAM検査有効を再照合。反映直後の拒否確認は期待値に未到達だったため待機し、Functions URL/Run URLとも未認証の空callable要求が403となった後に続行。購入コード/旧Secret/旧500円Priceは変更0。今後の再公開は別承認 |
| 発行済みSession | 現行Liveキーで`GET /v1/checkout/sessions?status=open`を読み取り、open0/有効0。失効・契約取消0。作業開始後のCustomer/Session/SubscriptionもGET照合で新規作成各0（確認時点）。ID/メール/URL/Secret値を記録しない |
| Secret/IAM | `HAMCARE_LIVE_BILLING_MAIL_CONFIG`新設・停止用version1（資格情報なし）と、既存compute SAの当該SecretだけのAccessorを設定。新contact serviceだけpublic Invoker。project IAM変更の監査0、既存9 API/サービスエージェントbinding不変、新API有効化の監査0 |
| 新Function | `billingContactEmail`のみ配備、19:10:44 JST更新、ACTIVE、revision `billingcontactemail-00001-wor`。Node22/256MiB/1CPU/max1/concurrency5/timeout60秒、実行・ビルドとも既存compute SA/既存gcf-artifacts。`HAMCARE_BILLING_CONTACT_ENABLED=false`、`HAMCARE_BILLING_MAIL_DAILY_LIMIT=1`、Secret version1参照を再読取り確認 |
| 停止API | 正規OriginのPOST status/request/confirmは各503かつ`contact_service_unavailable`、no-store/正規CORS。異Origin403、OPTIONS204。ACTIVEの実handlerによる応答であり、起動失敗/Secret失敗を停止成功にしていない。全要求はtoken/実UID/実受信者なし。flag判定がAuth/DB/Gmailより前のため確認記録・mail・削除処理を発生させない |
| Hosting | 19:14:53 JST、旧`2365135bf558c278`から新`22b8c97c2532f11c`へrelease。**旧13の全hash維持＋追加32＝45**をfinalize前/release前/release後に照合。clone時のFirebase予約init.js/init.json自動再生成を公開前に検出し、同じ未公開cloneの元hashへ復元。既存ファイル再uploadなし。新コンテンツ10hashをupload、残りは既存cache再利用。CSP差分は`/account/**`だけ |
| 公開確認 | `/account/`と`/account/contact/`・全依存32件HTTP200/plainSHA一致、旧LP/Privacy/Terms/Support/特商法/削除案内/billing戻り/robotsの10件HEAD200、既存URLへaccount CSPの漏れなし。IAB実表示で現行outlineロゴ/星空/停止案内、横はみ出しなし、5つの未使用Test/Portal枠はcomputed display:none、Console error/warn0。実ログイン/フォーム送信/物理端末の再E2Eは行っていない |
| 表示用の範囲内仕上げ | 既存JSがcontact bannerをneutral文へ戻すため、contact mainへIDなしの静的停止案内1段落を追加し、初期化後も停止表示を維持。32paths・29原本asset・JS/認証/CSPは不変。最終manifest SHA256 `57a78cd87a510e0e275f36c538f23e1bdedbdbc09cb92086754ff33e2acd3a38`、contact HTML SHA256 `dce2b45723537b69264f993f79a8fcd821c1aa51f238a0d55b55eab8dda24f9a`。manifest/実行helperは非公開。ServingConfig SHA256は承認時の`79611ac282f6b9467e4edbb6ac919c0705f1e6f504279c7b906f992bfbf043d9`を維持 |
| 他関数/互換性 | 58→59件、追加contact1件だけ。旧58件はupdateTime/runtime/実行SA/buildSA/Secret参照等のresource差分0（独立した全コードhash照合とは区別）。新通知/削除worker・Web削除2関数は不存在、Web削除URL各404。既存アプリ内削除/体験/権限/認証は更新しない。`billing_contacts`なしを通常利用拒否条件にする変更なし |
| エラー/監視 | 配備後短区間の旧58関数稼働ERROR0。意図した新contact停止503が3件、初回作成の制御面エラー1件を分離。配備前30分の既存stardailycheckinwritten ERROR2件は本作業前の記録で、異なる長さの区間を発生率比較しない。Secret権限・ACTIVE・正規JSON応答を確認し、未解決の起動エラーなし |
| 本番変更の分類 | **構成変更あり**：旧購入IAM、新Secret/version/単体Accessor、新Function/build/revision/public Invoker、Hosting版/32追加files/scoped headers。**今回の業務データ変更0**：Firestore/Auth/プロフィール/飼育記録/trial/billing/テスター権限/Storage画像変更0、実メール0、Stripe書込み0、実削除/Apple失効0。構成変更を「本番変更0件」とは記録しない |

配備中の限定的な調整：Firebase CLI13.29.3は単関数filterより前に対象外`HAMCARE_LIVE_WEB_BILLING_CONFIG`を要求したため入力せず中止した。対象外Secretを作らず、同じ1関数をgcloudで直接指定して配備。最初の直接指定は既定CPU<1とconcurrency5の不整合で制御面が拒否し、元のFirebase CLIが256MiBに割り当てる1CPUを明示して成功した。SDK/ソース/追加権限の変更なし。Hosting複製の予約2ファイル差分もLive公開前に解消してからreleaseし、保全検査を緩めていない。

静的3件は下表の**168/171のまま**、検査無効化0。特に3件目は、旧`98f3fb8a...`のindex全文と、承認済みLive runtimeへの抽出・削除core接続・連絡先追加後のindexを比較する検査（150行追加/827行削除）である。現行本番58関数の破損を示したものではないが、全体配備が安全だという証明でもない。今回その58関数を更新せず、承認済みの新contact1件だけに限定し、実配備後resource不変を確認したことが非ブロッキングの根拠。認証の実体は共有関数と関連148/148 Mock PASSで照合した。

復旧/後続：今回Hosting rollbackやcontact閉鎖は不要。必要時は旧版`2365135bf558c278`を再releaseし、contactをfalseのままpublic Invokerを外す。**購入停止は復旧時も維持**し、独断でallUsersを戻さない。次はGmailのscope宣言/検証又は例外条件・本番資格情報/送信設定を整理し、別承認で専用未契約アカウント1件＋確認メール1通の本番復帰確認へ進める。今回の日次上限1を送信許可とは扱わない。Live550円Price/Portal/Webhook/課金API接続・実契約・安全削除の本番配備・アプリ新ビルド/ストアは未実施。実Apple失効/その後の同UID復帰、Relay実配送等の既存残件を維持。Relay/追加VoiceOverは非ブロッキング。

### 承認済みの変更一覧（計画記録）

| 対象 | 承認後に行う変更 | 停止状態・範囲 |
|---|---|---|
| プロジェクト/リージョン | `hamster-breeding-app`（番号`797691641198`）、Functionsは`asia-northeast1` | Previewプロジェクト/関数/保存先/送信枠は変更しない |
| 旧購入APIの受付停止 | 既存Cloud Run service `createstripecheckoutsession`から`allUsers`の`roles/run.invoker`だけを外す。`createStripeCheckoutSession`のコード・Secret参照は更新しない | 独立した購入停止フラグが未実装のためIAMで停止する。現状はInvoker IAM check有効、当該serviceの公開bindingあり、projectに公開Invoker bindingなし。通常アプリのFirebase tokenはCloud IAMの実行権限ではない。一般の新規購入だけ403にし、旧500円へ切り替えない |
| 新Function 1件 | `billingContactEmail`だけを名前指定して新規配備。Node22/Gen2、256MiB、maxInstances1/concurrency5/timeout60秒、HTTP `/status` `/request` `/confirm` | `HAMCARE_BILLING_CONTACT_ENABLED=false`を明示、`HAMCARE_BILLING_MAIL_DAILY_LIMIT=1`。canonical Origin以外403、正規Originの本処理は503でAuth/Firestore/Gmail処理より前に停止。OPTIONSだけ204。購入受付を有効化する機能はない |
| Secret | 未登録の`HAMCARE_LIVE_BILLING_MAIL_CONFIG`を作成し、**OAuth資格情報を含まない停止用バージョン1件**を登録・新Functionへ参照設定 | SDKが起動時にbound Secretを必要とするための準備。内容は表示しない。Previewの資格情報・許可リストをコピーしない。有効化フラグが誤ってtrueになっても設定検証で停止。既存`STRIPE_*`・Preview Secretは変更しない。`HAMCARE_LIVE_WEB_BILLING_CONFIG`は作らない |
| IAM | 既存実行SA `797691641198-compute@developer.gserviceaccount.com`に上記Secret単体の`roles/secretmanager.secretAccessor`。新`billingContactEmail`のRun serviceだけ`allUsers`へ`roles/run.invoker`を付与 | 利用者管理の新SA・project全体の追加権限・Gmail代理送信権限なし。HTTP到達を許可しても上記server停止が先に働く。既存SAの広い権限を今回拡張しない |
| CLI基盤処理 | Firebase CLI13.29.3がGen2配備時に行う既存Pub/Sub・Eventarcの`generateServiceIdentity`（サービスID確保）を含める | 対象は`service-797691641198@gcp-sa-pubsub.iam.gserviceaccount.com`と`service-797691641198@gcp-sa-eventarc.iam.gserviceaccount.com`。既存project bindingは確認済み、管理agentの個別describeは権限不足のため不存在とは判定しない。このAPIは未作成ならGoogle管理IDを作成し得る。利用者管理SA/追加role/イベント経路は作らない |
| Hosting | 現行Live version `2365135bf558c278`を未公開版へcloneし、既存13ファイルを同hashで残したまま、承認ソースから作る`/account/`・`/account/contact/`と必要な`/assets/`だけ追加してrelease | `public/`全体やPreview設定を本番へコピーしない。LP/法務/サポート/既存削除案内/`billing/*`/Firebase予約URLは不変。新2 HTMLだけPreview/Test専用の案内を「準備中・受付/送信停止」に置換し、追加CSSで未使用Test/Portal/Checkout表示枠を非表示。JS/認証ロジックは承認ソースのまま。CSSは表示整理であり安全境界ではない |
| Hosting/CSP | 新`/account/**`に限定しno-store/no-referrer/nosniffとCSPを追加。scriptはself・Firebase SDK12.17.1・Google認証、connectはFirebase Auth/Firestoreと`https://asia-northeast1-hamster-breeding-app.cloudfunctions.net/billingContactEmail/`配下だけ、frameは固定Firebase Auth handler/Google認証 | Previewの`us-central1` endpointとStripe iframe/APIは許可しない。globalヘッダー・既存LP等には適用しない。canonical `https://hamster-breeding-app.web.app/account/`、`/account/contact/`を公開準備表示。Hosting共通aliasの`firebaseapp.com`にも同じ静的pathが追加されるが、既存origin検証により操作不可。`/__/auth/handler`は変更しない |
| Rules/Index | 配備なし | 新保存先はAdmin処理用で既存client default-denyを維持。今回停止中は新保存自体がない。Firestore/Storage Rules・Index・TTLは変更しない |

**今回配備しないもの**：`createStripeCustomerPortalSession`、`stripeWebhook`、`deleteMyAccountAndData`、`processBillingNotificationOutbox`、`retryAccountDeletions`、`confirmSupportAccountDeletion`、`supportAccountDeletionOperator`、体験/権限/AI等の既存Functions。通知workerには独立送信停止フラグがなく、購入runtimeにも独立受付停止フラグがないため、未設定Live Secretを使って一括配備しない。Webhook/Scheduler/Eventarcの追加・更新・過去イベント再処理0、新しいWeb削除endpointは未配備のまま（404）。既存アプリ内削除・既存Webhook/Portalは現行版のまま。本番StripeのPrice/Portal/Webhook/Customer/Subscription設定は一切変更しない。

基盤read-only確認：Cloud Functions/Run/Build/Artifact Registry/Eventarc/PubSub/Storage/Secret Manager/Firebase Hostingの9 APIは既に有効。今回のHTTP1件に対しCLIの`ensureServiceAgentRoles`は追加roleを要求しない。既存compute/Functions/Build/PubSub/Eventarc/Runの必要bindingを確認。新API有効化・service agent role追加は承認範囲に含めず、予期しない要求が出たら変更前に停止する。Functions CLIのprepare自体がAPI/Secret IAMを変更し得るため、承認前にdeploy/dry-run prepareは実行しない。配備のbuild/revision/artifact/log作成は上記1関数に伴う構成変更として記録する。

承認提示時のHosting成果物はGit外のbuild artifact（新しい監査書/管理表ではない）。`/tmp/hamcare-prep-hosting-overlay/`の公開対象は32件（HTML2・準備CSS1・承認コミットと全バイト一致のassets29）、既存13件との衝突0、ローカル依存不足0。既存と合わせ45件を照合する。提示時manifest SHA256は`db8df270816dd5c3a23c3361401189900a85788406d179d14ae8c948ebeec52d`、account HTMLは`77dab04596d975183932110a8f813fbbf3f0075269882e679a91c40bddab9be2`、contact HTMLは`16d0a485738027e497577b176bbcdfa0e0f90ff5a8448211a4c20b322895d8bd`、準備CSSは`fb2a1c99946576252d3862a0a1ec5a76a9a4f7d6616693e2a0e161e1c105fd1a`。実配備時は静的停止段落の追加でcontactとmanifestだけが冒頭実績のhashへ変わり、他のpath/JS/認証は維持。manifest自体は非公開。Hosting用gzip hashもCLI相当のNode22圧縮で全32件一致。scoped ServingConfig artifactは`/tmp/hamcare-production-prep-20261122/hosting-serving-config.json`、SHA256 `79611ac282f6b9467e4edbb6ac919c0705f1e6f504279c7b906f992bfbf043d9`。派生表示を含む範囲を承認されており、配備元全バイトが14bのままとは主張しない。

### 既知の静的検査3件：失敗を残した判断

`python3 tools/check_web_account.py`は**168/171 PASS**で同じ3件が失敗。検査を無効化・成功扱いにしない。

| 不一致 | 実動作への影響と今回の停止要否 | 根拠 |
|---|---|---|
| `server Apple policy binds Admin UID/disabled and exact current token provider` | 検査は旧`preview-functions/src/auth-policy.ts`内の文字列を探すが、現在は共有関数のre-export。実際の照合欠落ではなく、今回の限定配備は止めない | `functions/src/webBillingShared.ts`の`authorizeWebBillingIdentity`がAdmin UID/disabled、現在の`apple.com` provider、1件のsubjectとAdmin provider UIDの完全一致を維持。呼出側はAdmin token失効検査後に同UIDを取得 |
| `server non-Apple policy retains both actual verified-email checks` | 同じre-exportによる検査位置の不一致。メール/Googleの検証緩和ではなく、今回の限定配備は止めない | 共有関数がtokenの`email_verified`とAdminの`emailVerified`の両方を要求。Apple連携があるだけの非Apple sessionを特例化しない |
| `production billing/Auth source unchanged functions/src/index.ts` | `98f3fb8a6cd8a3fdcee91149ea3a72f2fe404b9a`からの全文不変検査と、後続の承認済み課金/削除/連絡先追加が不一致。全体配備の免責には使わない。今回1新関数と旧購入serviceのIAM停止に限定するため停止不要 | 現在本番のbilling/削除/体験/権限関数を更新せず、Secret不足で既存Webhook/Portalを止める変更を除外。該当定義・importを読み取り、実行される対象を限定 |

関連する既存純粋/Mock試験（Preview auth policy、本番management identity、Web billing runtime、initial trial start）は**148/148 PASS**。既存357件の連絡先接続検証・ビルド結果も再利用し、実アカウント/実AIの全E2Eは繰り返さない。

### 配信中アプリとの互換性

- `lib/`と体験/権限経路は`billing_contacts`の存在を要求しない。契約状態は既存`users/{uid}/billing/subscription`、無料体験は`initial_trial_v2`等から読む。連絡先未作成だけでログイン・通常利用・体験・有料権限を拒否する接続はない。
- 既存のログイン/通常利用/無料体験/AI/権限Functions・Rules・Flutter配信版は更新しない。`deleteMyAccountAndData`も現行のままで無料テスターのアプリ内削除を変えない。今回の新安全削除coreが本番稼働済みだとは記録しない。
- 旧配信版の新規購入ボタンを押した場合だけ、旧購入APIのIAM停止により利用できなくなる。これは今回の一般受付停止の意図した影響。Webhook/Portalの現行処理は止めない。現在有料契約者0人という本人確定を維持する。

### Gmail認可：読取り結果と実送信前の残件

- Google Auth Platformの公開状態は**本番環境/外部**、検証が必要との表示・user上限1/100。既存desktop client「HamCare Preview Billing Contact Mail」を確認。設定は変更していない。
- 現存Preview認可をメモリ内だけでrefreshでき、実際に付与済みのscopeは**`https://www.googleapis.com/auth/gmail.send`だけ**。メール送信/受信箱閲覧は行っていない。token/Secret/宛先情報はログ・Gitへ出していない。
- 一方、Data Accessの宣言済みscope画面は既存YouTube readonlyのみで、Gmail sendの宣言は見当たらない。実送信前に`gmail.send`の宣言/用途と検証又は適用除外の条件を整理し、必要なら本人に送信専用の再認可を依頼する。既存YouTube設定を削除したり、SA代理送信/DWDへ変更したりしない。今回の停止配備ではOAuth設定変更・本番への資格情報コピー・実送信を行わない。
- 1回のrefresh成功を長期稼働保証としない。発行時のTesting条件、本人による取消、長期未使用、Gmailパスワード変更等の失効条件を確認し、`invalid_grant`/401/403では送信停止・本人再認可へ。Testing発行の7日期限を現在の本番表示だけで否定しない。一次資料：[OAuth token失効条件](https://developers.google.com/identity/protocols/oauth2#expiration)、[Gmail send scope](https://developers.google.com/workspace/gmail/api/auth/scopes)、[機密scopeの本番準備](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)。

### 承認後の実行順・限定判定・復旧

1. **再照合/退避**：承認ソース・2文書以外のGit差分なし、現行Hosting版/13ファイルhash・既存58 Functionsの更新時刻・旧購入service IAM・基盤API/Secret不存在を再確認し、非公開のローカル退避へ保存。承認対象が変わっていたら止める。Secret値を退避ログへ出さない。
2. **旧購入受付停止**：上記公開Invoker bindingだけ除去。Cloud Functions URLとRun URLの通常・未認証POSTを各1回、空のcallable要求で403になることを確認。Stripe呼出しが起きるprivileged呼出しや実UIDは使わない。停止が確認できなければ後続へ進まない。
3. **停止用Secret/IAM→Function**：停止用SecretとAccessorを設定してから、隔離した承認ソース/明示envを使い`--only functions:billingContactEmail`で配備。CLIが他関数・API・roleの変更を要求したらそこで止める。Function設定/Secret参照/実行SA/コードhash/公開Invokerを照合する。
4. **停止API確認**：canonical Originで`/status`・`/request`・`/confirm`を各1回だけ、実UID/token/個人メールを含まない合成bodyで呼び503を確認。異Originは403、OPTIONSは204。flag停止はAuth/DB/Gmail構築・操作より先にreturnする実装と照合。新Web削除2関数は一覧に存在せず、各URLの非認証要求が404であることを確認。全て拒否試験であり、Customer/契約/確認記録/メール/削除要求を作らない。
5. **Hosting差分だけrelease**：退避した現行版から`finalize:false`でclone→上記ファイルだけpopulate→configへscopedヘッダー追加→ファイルhashと既存13件不変を再確認→finalize/release。公開前に追加2 HTML/依存のhash、canonical API参照、Preview/Testカード非表示、購入service=nullを照合。予期しない法務/LP差分やPreview接続があればreleaseしない。手順根拠：[clone](https://firebase.google.com/docs/reference/hosting/rest/v1beta1/sites.versions/clone)、[populateFiles](https://firebase.google.com/docs/reference/hosting/rest/v1beta1/sites.versions/populateFiles)、[patch](https://firebase.google.com/docs/reference/hosting/rest/v1beta1/sites.versions/patch)、[release](https://firebase.google.com/docs/reference/hosting/rest/v1beta1/sites.releases/create)。
6. **配備後照合/監視**：新ページ/依存HTTP200・hash/CSP、canonicalが本番contact APIだけを選ぶこと、準備CSSが200かつ該当枠非表示、旧ページhash不変を確認。実ログインや実送信はせず、新関数の起動失敗/5xx（意図した停止503と区別）、Secret権限、既存認証/体験/権限/削除関数の新しいERRORを短い配備前後区間で集計する。本文/UID/メール/tokenを表示しない。ログ無異常を実機E2E完了としない。新削除/通知worker/新Webhook/Schedulerが作られていないことも確認する。
7. **復旧**：途中失敗なら後続停止。Hostingは退避版`2365135bf558c278`（直前版が変わっていれば再照合後の承認済み退避版）を再release。新contactは`false`を保持し、必要なら新serviceのpublic Invokerも外して到達を閉じる。Secret/停止証跡は消さず、新規資格情報登録はしない。旧購入APIの公開権限は受付停止を維持するため勝手に戻さない。再公開は別承認。既存58関数をrollback目的で全体再配備しない。
8. **記録**：設定変更（旧購入IAM、新Secret/version/Accessor、新Function/revision/Invoker、Hosting版/headers/artifacts）と業務データ変更を分けて実績記録する。「本番変更0件」とまとめない。実施結果が確定してからこの文書と`PROJECT_STATUS.md`だけを明示stageし、記録1コミット。merge/pushなし。

次の実確認案（今回の承認には含めない）：OAuth/本番送信設定を整理した後、本人所有の専用未契約アカウント1件と確認メール1通で本番連絡先→確認→プラン復帰を確認する。Stripe契約/課金0、実削除/Apple失効0、AI送信0。購入・削除の実確認や一般受付開始は対象を別途決める。Relay実配送/追加VoiceOverは従来どおり非ブロッキング。

---

承認前の履歴（現在の配備実績は冒頭）：2026-11-22連絡先確認追記：Previewで完成した確認engineを共通化し、本番`billing_contacts/{uid}`・`billingContactEmail`・canonical Webの確認/プラン復帰へ接続するコードを追加。本番課金と通知は同じ確認済み原本の共通readerを利用し、既存削除処理も同じ原本を削除する。設定定義・Mock/Emulator/ローカル表示の段階であり、本番配備・実配送・受付開始ではない。削除窓口の3営業日/7暦日/7日ごと、完了履歴90日/未確認期限切れ30日は確定済み。範囲・手動担当/頻度は[削除窓口運用](web_account_deletion_support_20261121.md)に従い、TTL/履歴整理は今回実行しない。

削除接続実装時の履歴（2026-11-22）：メール削除申請を既存Web認証・安全な削除処理へ接続するコードと限定試験を追加。[削除申請の運用手順](web_account_deletion_support_20261121.md)を参照。新public確認endpointとprivate運営endpointは今回の準備配備でも未配備、server/Webの有効化は停止状態。実アカウント削除・削除実行関連の本番操作・メール送信は0。削除有効化の本番手順は未実行。

旧計画の履歴：2026-11-21、開始点`4aeab766f90e`では方針・公開前文面・Runbookの最終化だけを行い、本番工程は実行しなかった。各GOは方針決定又は既存検証の状態であり、それ自体は本番変更の実行承認ではない。その後の限定承認・停止準備配備は冒頭実績を参照し、既存の配信アプリ・テスター・契約を維持する。

本番APIのコード準備は[2026-11-21実装記録](production_web_billing_api_20261121.md)を参照。一般購入の本切替は未実行（冒頭の停止準備配備だけ完了）。後続のFunctions切替には専用`HAMCARE_LIVE_WEB_BILLING_CONFIG`の全必須項目と旧500円対応の事前確認が必要であり、旧`STRIPE_*`から自動補完しない。設定なしの先行配備は既存Webhook/Portalも停止するため行わない。新規購入は明示的なWeb見積り/同意を必要とし、旧アプリの空の購入要求は安全停止する。Web課金のLive API接続・本番連絡先の有効化/実配送・本番通知と実データ互換確認は、今回の停止準備配備と別工程として残す。

通知は[契約outbox・Gmail Worker実装記録](billing_notification_outbox_20261121.md)にコード準備と本人限定Preview5通の受信/表示確認を保存。本番Workerは未配備で、共用Secretは停止用・資格情報なしversionだけ登録済み。送信枠/IAM/OAuthの長期利用・不明送信/不達の有人運用確認を終えてから別承認で有効な送信設定とWorkerを配備する。以下の「本番通知未実装」は配備・本番接続が未完了という状態として読み、コード自体の準備と区別する。一般購入/通知の有効化は未実行で、冒頭の停止準備配備とは区別する。

## 確定した運用方針

- **価格**：HamCare プレミアム、正式表示は「月額550円」。1か月ごとの自動更新、次回以降も550円。Test Priceは550円を維持。本番切替時に新しいLive550円Priceを作成して**新規申込だけ**へ接続する。旧Live500円Price・既存Customer/Subscriptionは変更・削除・一括移行しない。税務上の申告・納税はバックオフィスで別管理し、表示分岐や公開判断に持ち込まない。
- **返金**：「利用者都合による支払済み料金の返金は原則として行いません。ただし、重複課金、当方のシステムによる誤請求、その他法令上返金が必要となる場合は個別に対応します。」規約・特商法・最終確認・FAQで意味を統一。追加の返金候補は採用しない。
- **解約**：Customer Portalから期間末解約。即時解約なし、次回更新以降の請求停止。利用者都合の日割り返金なし。返金手続きとは分離する。「解約手続き後も、現在の契約期間が終了するまではHamCareプレミアムをご利用いただけます。」
- **特商法**：氏名・住所・電話を請求に応じて書面又は電子メール等で遅滞なく開示する方式。購入判断前に十分な時間的余裕をもって提供できる実体制が必要。[開示手順と条件確認](commercial_disclosure_operations_20261121.md)を参照。自宅住所・個人電話を常時公開しない。バーチャルオフィス契約は不要、将来規模拡大時だけ再検討。
- **サポート**：`gotainu@gmail.com` を問合せ、特商法開示請求、契約課金、不具合の窓口とする。差出人は現在のHamCare／Go / hamster well-being等のブランドを維持し、個人本名へ変えない。開示すべき法定情報をブランド名で代替しない。本人の非公開情報をGit・チャットへ転載しない。
- **メール**：Firebaseは認証確認・パスワード再設定等。Gmail API／既存Gmailは連絡先確認、重要な契約通知、契約開始、解約予約、契約終了、支払失敗、必要なサポート通知の初回リリース基盤として採用。外部メールサービスは追加しない。Stripe領収書等は補助とし、重要通知をStripeだけに依存しない。既存Previewメールをそのまま本番対応済みとは扱わない。
- **Relay**：登録済み2送信元と過去のSPF確認を維持。実Relay配送は未確認で**非ブロッキング**。他の準備を止めず、本人のRelay宛先が確保できたら本番前又は公開直後に確認する。Stripeメールが届かなくても、HamCare管理下の登録済み送信元から重要通知を送る構成を正本とする。必要な場合だけ本人へ受信可能な連絡先の再確認を案内し、個人実メールを必須化しない。
- **連絡先**：契約・Customerの正本はFirebase UID。確認済み通常メールとApple Relayを使用し、本当にメールがない場合だけ独立連絡先を補完・確認してから新規契約を認める。メール一致でUID/Customerの紐付け・統合をしない。体験3ケースと元の終了日時を維持する。

## Go/No-Go（方針と実装を区別）

| 項目 | 現在の状態 | 根拠・実施上の注意 |
|---|---|---|
| 正式価格 | GO | 月額550円、実請求550円。Live Price新設は未実施 |
| 返金方針 | GO | 上記文を正式決定、公開前HTMLへ反映。公開は未実施 |
| 解約方針 | GO | 期間末解約、期間末まで利用、日割りなし |
| 特商法表示方式 | 条件照合済み・実体制確認後GO | CAA Q15/Q17と照合、公開前文面を用意。遅滞ない実開示体制は運営者の確認待ち |
| バーチャルオフィス | 不要 | 初回は契約しない。将来検討のみ |
| サポート窓口 | GO | 既存Gmailを共用、ブランド表示を維持 |
| Firebase認証メール | GO（既存機能） | 通常メール確認・再設定経路あり。Relay実配送は別項目 |
| Gmail API | 初回リリース採用・一般送信停止 | 本人限定の本番確認はcd624d4で完了。contact false/日次1/mail v3を維持し、通知Worker未配備。一般用設定/一般OAuth検証・通知稼働は別工程 |
| Apple Relay送信元登録 | GO（過去の登録証拠） | 2送信元登録・SPF確認済み。今回設定再確認/変更なし |
| Relay実配送 | 未確認・非ブロッキング | 本人所有の宛先確保時に確認、成功したとは記録しない |
| 連絡先補完 | Preview GO | 既存の実配送1件と確認済み連絡先・UIDガードの証拠を維持 |
| 本番連絡先確認 | 本人限定実機確認完了・一般向け停止 | cd624d4承認済：受信/同UID確認済み保存/スマホ復帰PASS、今回は再試験0。確認済み原本/累計2/履歴保持。Relay実配送は別の非ブロッキング項目 |
| Stripe Test | GO（既存検証） | 550円、体験/即時、Webhook、Portalの既存証拠。今回追加決済なし |
| Safari E2E | GO（既存Test E2E） | 既存Apple購入・同期・Portal・期間末解約PASS。今回の本番検証ではない |
| Android Chrome表示 | GO（既存表示検証） | 連絡先ページの実機表示/入力PASS。Androidの購入E2E全体とは区別 |
| Live Stripe | 550円Price/専用Portal構成を作成済・切替一部保留 | 2026-11-23実績を参照。Checkout停止版のみ先行配備。審査用0円契約の同期保護で旧Webhook/Portal handler/新専用Secretは維持・保留。購入・契約接続は未実施 |
| live Hosting | 準備2ページだけ追加済 | 旧13hash不変＋32追加。LP/法務/一般購入公開は未実施。新旧版は冒頭に記録 |
| Flutter CTA撤去 | 新規購入・Portal導線ともコード撤去済・未配信 | [Portal撤去記録](flutter_customer_portal_removal_20261121.md)。Webの契約管理とアプリの権限読取りは維持。本人確認では現在有料契約者0人。[削除前の請求停止](account_deletion_billing_safety_20261121.md)と[Apple失効統合](apple_account_deletion_revocation_20261121.md)はコード・ローカル試験準備済、未配備/未配信。専用実機失効E2E・配備/監視等は残件 |
| Web削除申請 | メール→本人確認→運営実行のコード接続/限定試験済・未配備 | 固定された既存UID/作成日時、1回限りリンク、同じ申請の意思確認、IAM privateのdry-run/実行。既存Stripe停止/削除フェンス/workerを再利用。未確認申請は実行不可。公開窓口はPreviewのみ、実機Apple失効・運営IAM・本番削除の確認は残件 |
| Apple審査 | 戦略C版は未提出 | Case103009817213は回答済み、事前承認なし・実提出後判断 |
| Google審査 | 戦略C版は未提出 | 既存Alphaの審査提出・配信履歴はある。Google審査を一度もしていないという意味ではない |

既存の実機・Test証拠は [戦略Cリリース記録](japan_store_payment_and_ios_readiness_20261018.md) に保存。新しい外部確認を実施したという記録にしない。

## 実行前の共通条件

以下は後続実装・本人の本番実行承認が揃った時だけ使用する。**現在は実行準備完了ではない。**

1. 認証・UID所有者照合・重複契約防止・既存Customer再利用・元trial終了維持を備えた本番用Web API、Webhook、Portal、連絡先確認、重要通知を別工程で実装・検証する。`preview-functions` はTestキー/`livemode=false`/固定Preview Origin/隔離保存を強制しており、キーやURLの差替えだけでLive化しない。Previewガードの撤去で代用しない。
2. 本番用のドメイン、Auth復帰、Origin/CSP、Secret、許可Price、Portal構成、Webhook API版/イベント/署名・再送・順序逆転・UID照合を確認する。TestとLiveのデータを混ぜず、既存Live endpoint/Secretを上書きしない。新経路は別構成又は影響範囲が確認された構成として承認する。
3. Gmailの本番通知は [不足通知と後続実装](launch_notifications_and_flutter_scope_20261121.md) に従う。確認済み宛先、有限の送信枠、永続キュー/重複抑止、429/一時障害の上限付き再試行、認証失効時停止、不明な送信結果の手動照合・再送判断を用意する。API成功は受信完了ではない。配送不能の確認・サポート手順と既存OAuthの継続利用可否を確認し、権限を無断追加しない。Previewの本人許可リスト・送信上限を本番のために解除しない。
4. 独立連絡先・確認履歴・送信記録の保持期間、期限切れ情報の削除、退会時削除/法定保持の分離を実装・確認し、Privacyを実態と揃える。15分のトークン期限を保存データの削除期限と取り違えない。特商法の請求開示体制と公開前法務一式も確認する。Relay配送未確認だけでこれらの準備を止めない。
5. 既存Live設定/Hosting版/配布版/対象本人契約の安全な照合記録と、承認済み変更の一覧を準備する。復旧手段を事前に実装・リハーサルし、存在しない停止スイッチを使用可能と書かない。個人値・UID・Token・カード情報を公開証跡へ出さない。
6. Web削除申請は次の独立した本番操作を別承認後に行う。新規購入/連絡先補完とは結合せず、購入用profile/pet guardを流用しない。

## Web削除申請の本番反映（未実行）

| 実施対象/変更 | 成功条件 | 停止条件 | ロールバック/継続対応 |
|---|---|---|---|
| 削除core/workerと専用Live設定の配備計画 | 既存`runAccountDeletion`/tree walk/Stripe停止確認をそのまま呼ぶ。無料はStripe API0、課金ありは停止確認前にAuth/データ削除0 | 未配備旧削除Functionに依存、Secret/IAM/Scheduler/監視不備、別UID/請求書未解決 | 新受付/実行を停止し原因確認。既存永続要求・停止証跡・完了フェンスは保持。安全版workerの継続/復旧を確認し、途中処理を放置しない |
| 新確認Function・private運営Function | `HAMCARE_SUPPORT_DELETION_ENABLED`未設定では停止。運営は`invoker:private`、専用SAに当該サービスだけのRun Invoker、担当者のToken Creatorも当該SA限定。不要な広域Admin権限なし。publicendpointはcanonicalOrigin/失効検査/最新Auth/UID固定 | allUsers/allAuthenticatedUsersの運営権限、ブラウザから運営API、任意UID実行、token/リンクのログ | enableをfalse、運営Invokerを外し新規実行を止める。データをrestoreしたと扱わず既存要求を照合 |
| Web本人確認画面/法務/公開窓口 | Web側enable定数を承認済みリリースだけで有効化し、canonical限定。最小CSPは既存Firebase SDK12.17.1/Auth/当該endpointだけ。Previewはfalse/connect-noneを維持。申請は匿名、後段は本人認証と意思確認 | Previewの本番API接続、UID/メール/tokenのURL漏れ、profile/pet登録/購入を削除条件化 | 有効化前のWeb版へ戻し、公開窓口とサポートで受付継続。申請/停止済み記録は消さない |
| 専用合成/本人承認済み削除用アカウントの配備後確認 | private IAM拒否、別UID拒否、同意/課金停止/cleanup/完了判定を確認。実Apple失効は専用アカウントの別承認後だけ | テスター/既存本人アカウントの無承認削除、Mockを実機PASS扱い | 検証停止、対象/実施済み工程を照合。不可逆な削除をコードrollbackで取り消せるとしない |
| 運営手順/保持/案内/監視 | dry-run→対象/範囲/キャッシュ契約状態確認→明示実行→completedフェンス+Auth不存在照合。毎日pending/古いrunning/retryable/manual_review/worker失敗を確認。完了連絡は照合後 | 受付メールだけで削除、直接Auth削除、billingStopped手動偽装、未確定の全消去期限を約束 | 個別対応へ切替え、未完了を案内し再確認。返信目安・履歴保持の推奨案を運営承認後に公開文面へ反映 |

申請リンク24時間・再認証5分・review5分は実装済みの認証期限であり、申請データの自動削除ではない。初回返信はJSTの土日祝を除く原則3営業日以内、本人確認と削除意思確認後は原則7暦日以内が完了目安。遅延理由/見通しを知らせ、その後7日ごとに連絡する方針が確定。完了窓口履歴90日/期限切れ未確認30日は窓口のメール/添付・support申請・CLI受付/リンク/reviewファイルだけを対象とし、処理中・既存再試行/停止証跡・完了フェンス・会計へ一括適用しない。担当Go、毎営業日の期限確認と週最初の営業日の手動整理確認を予定し、本番運用/自動purge/TTLは未開始。会計の法定期間は記録種別ごとに確認し、Apple実失効後のStripe失敗→同UID再ログイン/再開も実機未確認を維持する。

## 本番連絡用メール確認の有効化手順（本人限定実機確認完了・一般向け停止、以下は一般有効化時の参考）

既存の認証・プラン・課金・通知を作り直さず、確認engineとGmail sender/予算を共有する。詳細・試験記録は[戦略C連絡先確認](japan_store_payment_and_ios_readiness_20261018.md)の2026-11-22節を参照。Previewの過去の実配送成功を、本番の配送成功へ読み替えない。

| 対象 | 必要な定義/操作 | 成功/停止条件・復旧 |
|---|---|---|
| Function | `billingContactEmail`、`asia-northeast1`、HTTP `/status` `/request` `/confirm`、POST JSON/Bearer、2KiB、canonical Origin固定。maxInstances1/concurrency5/timeout60秒 | 別UID/任意UID本文/query/異Origin/失効tokenを拒否。公開HTTPのためInvokerは利用者に到達可能な構成が必要だが、実データはAdmin検証後だけ。未承認の本番配備はしない |
| 有効化 | `HAMCARE_BILLING_CONTACT_ENABLED`は既定未設定/false。本番用の明示trueを別承認後に設定 | これだけで新規課金受付を開始しない。異常時falseへ戻し新送信/確認を止める。旧verifiedメールを削除しない |
| Secret/OAuth | 既存の本番定義`HAMCARE_LIVE_BILLING_MAIL_CONFIG`を通知と共用。JSONは`enabled:true,environment:'live',from:'gotainu@gmail.com',clientId,clientSecret,refreshToken`。秘密値をGit/診断へ出さない | 本人承認済みgmail.send専用OAuth・継続利用可否を確認してSecret Managerへ別途登録。Preview用Secret/allowlist/Test値からの補完なし。資格情報不備で日本語の利用停止案内、送信/DB変更前に停止 |
| 送信枠 | `HAMCARE_BILLING_MAIL_DAILY_LIMIT`は明示整数1〜100、未設定/不正なら停止。`billing_notification_delivery_limits`の全体/UID/予約/`_sender`停止期限を既存通知と共有 | 連絡先は既存60秒間隔・3回/時・5回/24時間も維持。Previewの10件枠とは別。Gmail429/枠不足/バウンス等は成功扱いしない。枠をリセット/自動増枠しない |
| IAM | 当該Function実行SAに当該SecretのAccessor、Authの検証/対象ユーザー読取り、必要なFirestoreアクセス。既存Gmailの送信専用本人OAuthだけを使用 | 不要なSecret/ストア/Stripe/管理権限を与えない。Gmail impersonation/DWDや新しいメール権限で回避しない。既存通知worker/SchedulerのIAMも維持 |
| 保存/削除 | 本番`billing_contacts/{uid}`、purpose`billing_contact_live`、firebaseUid/schemaVersion1/verified/verificationStatus/source/verifiedAt/email。pendingは同一docに独立保持、確認時だけ切替 | 課金・通知の共通readerが同じ原本を読み、削除coreは同じdocを削除。削除フェンスをtransaction内で確認し、遅延確認による復活を拒否。Preview原本のコピー/移行なし |
| Web接続 | canonical`https://hamster-breeding-app.web.app`だけLive endpointへ。既存Preview originは従来endpoint/保存/枠のまま、他originは停止。Authアプリ名も環境別 | 本番contact経路からPreview checkout/Portalを呼ばない。課金UI全体のLive切替は別工程で、今回canonicalの新規Checkout受付は開かない。既存Preview管理と本番Portal APIは連絡先未確認でも独立 |
| Hosting/CSP | `/account/`と`/account/contact/`の既存テーマ/SDK12.17.1/Auth/Firestore読取りを維持。`connect-src`へ`https://asia-northeast1-hamster-breeding-app.cloudfunctions.net`を追加、canonical用にはPreview API hostを接続先にしない | `script-src`はself/固定gstatic SDK/Google auth、`frame-src`は固定Firebase Auth Handler/Google、`base-uri 'none';form-action 'none';frame-ancestors 'none';object-src 'none'`、no-store/no-referrer/nosniff。既存Stripe購入画面のCSPは別工程、広い`*`/unsafe-inlineで解決しない。停止準備配備とscoped CSPは冒頭実績のとおり完了。確認/送信有効化と購入CSPは未実行 |
| 復帰/配送後確認 | 固定の`/account/?contact=verified&view=plan`だけを使用し、ログイン後に連絡先を再読込みして読取り専用プラン確認へ復帰 | 外部URL/任意returnTo/URL内UID・メール・tokenを拒否。リンクのtokenはfragment→SDK前に削除→メモリのみ。実配送/本番での復帰/Relay/不達を別途確認。API受理を受信成功としない |

本番反映時は、既存の本番課金API/通知/削除coreの承認済み版と上記を照合し、必要なFunctionだけを選んで配備する。`firebase deploy`で全体を一括変更したり、Previewガードを取り払って本番化したりしない。連絡先の確認成功は課金受付開始の承認ではない。既存課金設定/Live Secret未設定で新規申込が停止する境界を維持する。

## 共通の停止・ロールバック原則

- 金額違い、誤UID、重複契約、署名未検証、通知・権限同期の不整合を検知したら、後続工程と**新規申込の受付だけを停止**する。500円Priceへの自動フォールバックはしない。
- 認証済み既存ユーザーの契約読取/解約/支払管理と、成立済み契約のWebhook処理を維持する。版を戻す場合も、記録済み決済の台帳や受信証跡を消さず、成功した支払いを自動的に巻き戻したと扱わない。
- 返金・即時終了は本人の検証契約だけを特定し、金額・対象・影響の本人確認後に個別実施する。一般利用者へ一括適用しない。Live CustomerやWebhookを清掃目的で削除しない。
- 各工程を対象・実行者・結果・停止有無だけ記録し、失敗した段階から先へ進まない。税務区分、バーチャルオフィス未契約、実Relay配送未確認は単独の停止条件としない。

## Webhookイベントの照合対象（未設定）

新規Web購入経路では、既存Previewで検証した `checkout.session.completed`、`customer.subscription.created`、`customer.subscription.updated`、`customer.subscription.deleted`、`invoice.paid`、`invoice.payment_failed` の6イベントを照合対象とする。既存Liveの `stripeWebhook` と `invoice.payment_succeeded` 等の現行受信イベントは今回の計画で削除しない。

工程6・7では、同じ契約の更新責任を持つ経路、API版、署名、UID/Customer/Subscription/Price、Invoiceを基準にした重複処理防止を先に確定する。既存経路と新経路が同じbillingを競合して更新しないよう検証する。TestのAPI版を既存Live endpointへ無断で上書きしない。API版による期間・試用・Invoiceのフィールド差も検証してから受信構成を承認する。

## 本番メールの安全要件（設計、今回は実装しない）

- Firebaseは認証関連、Gmail APIは独立連絡先確認とHamCareの契約関連通知に分ける。現状で不足している通知は [通知一覧](launch_notifications_and_flutter_scope_20261121.md) を参照する。
- 同じ契約上の出来事を識別するキーを作り、Webhook受領・状態遷移・送信要求を永続記録で重複排除する。単なるWebhookの再送で同じ通知を増やさず、送信処理をWebhook応答から分離する。
- 状態を少なくとも未送信、送信中、送信済み、再試行待ち、送信失敗、結果不明、配送不能に分ける。API受理と実際の到達を混同しない。送信済みを未送信へ無条件に戻さない。
- 送信制限・429・明確な一時的失敗は有限の再試行と指数バックオフ・ばらつきで処理する。再試行回数/期限、共有送信枠、監視担当を本番実装で固定する。認証失効・恒久的な拒否は停止して担当者へ。宛先や送信量の制限を無断で解除しない。
- タイムアウト等で送信されたか不明な場合は、同じメールを自動的に送り直さず送信記録と非公開のGmail側情報を照合して判断する。Gmail APIだけでexactly-once送信・到達保証が成立するとは扱わない。
- バウンス/配送不能は担当者が既存窓口で確認し、失敗状態を記録して必要な連絡先確認へ回す。受信箱読取権限や新たなメールサービスは無断追加しない。メール本文、完全な宛先、Token、UID、カード情報を運用ログへ出さない。
- StripeからのメールがRelayへ届かなくても、HamCare登録済み送信元のGmail経路で必要な重要通知を扱えることを成功条件にする。Relayの実宛先がまだないだけで全準備を停止せず、用意できた時点の配送検証を追跡する。

独自ドメインやResend等のトランザクションメールサービスへの移行は、人数・送信数・到達率・運用負荷から個人Gmailが不適切になった場合の将来タスクとする。初回のブロッカーにせず、今回契約・設定追加しない。

実550円の確認には、本番で未契約かつ体験未開始/終了済みの本人所有アカウントを使う。体験中しかない場合は元の終了日時を維持し、当日0円だけで実550円請求確認を完了にしない。本人の別アカウント又は通常の初回請求まで待つ方法を判断し、Liveの体験期限をテストのために書き換えない。

## 26工程（本公開時の指定順序・停止準備配備とは区別）

| #・工程 | 実施対象 | 変更内容 | 成功条件 | 停止条件 | ロールバック方法 |
|---|---|---|---|---|---|
| 1 最終状態バックアップ・Git確認 | 承認ソース、Live設定/Hosting/配布版の安全な記録 | clean状態・commit・旧設定の参照と復旧版を固定。非公開情報はGit外で管理 | 承認対象/旧版/実行者/復旧手段が一意、旧500契約の保護範囲が判明 | 未整理差分、対象不明、復旧元なし、本人実行承認なし | 読取りだけで停止。現行版を変更しない |
| 2 法務ページ最終確認 | 規約/Privacy/FAQ/最終確認/サポート | 正式価格550、確定返金、期間末解約、連絡先用途を同版に整合 | 申込確定前に読めて訂正可能、同意前後で条件一致 | 条件の矛盾、リンク切れ、カード独自入力、Privacyと実装の不一致 | 公開せず承認済み文案へ戻す。既存公開条件を勝手に差替えない |
| 3 特商法表示 | 特商法ページと開示運用 | 請求窓口/書面又はメール/購入前の遅滞ない開示を用意 | 正式な非公開情報と担当体制が揃い購入判断前に提供可能、CAA条件に適合 | 開示体制がない、購入済みを要求、私的値が公開へ混入 | 公開を保留し、窓口/文面を修正。個人値をGitから配信しない |
| 4 Live Stripe Product／550円Price新規作成 | HamCare用Live Productと新Price | 別承認後にJPY550/月次1の新Price作成。旧500円は保持 | Live・総額550・新規用Price一意、旧Price/契約不変 | モード/金額/周期違い、旧契約の変更が必要 | 新Priceを未接続のまま停止。使用中Priceや旧契約を清掃削除しない |
| 5 Live Secret | 本番専用の非公開設定 | 本番用API/署名/許可設定の参照を限定登録。クライアントへ秘密値を渡さない | 最小権限、Live/Test分離、旧Secret不変、失効/復旧方法確認 | Testキー混在、画面/ログへの秘密値露出、既存Secret上書き | 新規受付を止め、旧Secret参照へ戻す。無断で旧キーを破棄しない |
| 6 Live Webhook | 承認されたLive通知経路 | 本番署名・API版・再送/順序逆転/UID照合を備えた経路を接続 | 署名検証、現在Stripe正本との照合、他契約へ影響なし | Previewガード解除で代用、署名未確認、旧経路との二重付与 | 新規購入停止、成立済み契約の受信と証跡は保持し安全に再処理 |
| 7 Event一覧 | Live endpointの許可イベントと処理コード | checkout、subscription、invoiceのイベントを処理実装と一致させ記録 | invoice.paid/payment_succeeded等の差を理解し、成功/失敗/解約/再送を扱える | 未実装イベント、二重処理、古い通知で権限巻戻り | 受付停止し、既存の必要イベントを残して対象設定を戻す。通知証跡を消さない |
| 8 Live Customer Portal Configuration | Liveの専用Portal構成と本人Customer | 支払/請求履歴/期間末解約と安全なreturnを設定 | 新規購入/プラン追加/意図しない顧客メール変更/即時解約なし、UID一致 | default設定変更で旧契約へ影響、別UID進入、購入追加可能 | 既存管理を維持し対象構成だけ切戻す。安全なサポート経路を残す |
| 9 Price allowlist | 本番サーバーのplan key解決 | premium_monthlyを新Live550円へ接続し旧契約参照と分離 | 金額/任意Priceをclientから受けず、新規だけ550、重複契約拒否 | 旧500の新規受付、任意Price許可、全Subscription置換 | 新規申込を停止。500円へ自動fallbackせず、成立済み550契約は保持 |
| 10 本番billing保存先 | users配下の本人billing/通常権限経路 | 本番用の同期・連絡先・記録の保存/削除設計を配備 | 同一UID、通常権限判定互換、Previewと分離、他UID書込なし | Preview直結、手動解放前提、期限/保持設計未完成 | 新規受付停止、証跡保持し通常同期を修復。全billing削除やtrial resetなし |
| 11 本番メール設定 | Firebaseと既存Gmail API・登録済み送信元 | 不足通知とキュー/状態/再試行/重複抑止/バウンス手順を別実装で有効化 | ブランド表示、確認済み宛先、有限枠、送信済/失敗追跡、Stripeのみへ依存しない | 現Previewをそのまま流用、送信機能未実装、無制限再送、認証失効 | 未送信通知を保持し送信を安全停止。再送は照合後、追加権限や新サービスで回避しない |
| 12 live Hostingデプロイ | 承認された本番Web/API/法務一式 | ここまでの設定/実装が揃った版だけ公開 | 550円/条件/リンク/認証/安全ヘッダー一致、購入停止と復旧が可能 | 本番API/通知/保持削除が未完成、旧法務リンク、復旧不能 | 新規受付停止して確認済みHosting版へ戻す。既存管理と成立契約の同期を維持 |
| 13 本人アカウントでWebログイン | 本人所有の既存HamCare UID・owner/pet | 通常認証と連絡先を確認し契約対象を確定 | UID一致、既存プロフィール有、確認済み連絡先、体験/実データ不変 | 別UID、プロフィールなし、メール統合が必要、外部テスター使用 | 購入せず停止し本人再認証。Auth/プロフィール/体験の書換で通さない |
| 14 最小Live契約 | 本人の申込確認・新Price・Stripe入力欄 | 対象/金額/操作の本人承認下で通常申込を1件だけ行う | 同一UID/Customer、新Price、二重操作でも1契約、実カードはStripe内だけ | 本人確認なし、モード/金額違い、既存有効契約、状態不明 | 追加支払いせず照合。未払いSessionは安全に失効し、必要な後始末は工程20で個別承認 |
| 15 実550円請求確認 | 対象Subscription/Invoiceと元体験期限 | 初回の有料請求・継続額・元trial_endを照合 | 未開始/終了済みは実550円。体験中は当日0円と元期限の初回550円予定を区別し、実請求は未完として追跡 | 550円超過/不足、延長/リセット、成功ページだけで請求成功判定 | 受付停止、重ねて払わず対象だけ照合。実請求済み効果はコードrollbackでは消えない |
| 16 Webhook同期確認 | 本人契約の受信・billing・Web表示 | 署名/Live/UID/Customer/Price照合後の通常同期を検証 | 正本active/trialingと権限一致、反映待ち→完了、重複/古い通知で不変、重要通知が追跡可能 | 誤UID、未署名付与、手動解放依存、長期反映待ち、通知不整合 | 新規受付停止、受信証跡を残して再処理。決済再送や台帳消去で隠さない |
| 17 アプリ権限反映確認 | 同一UID・起動/復帰・有料gate | 通常の権限解放と再起動/復帰更新を確認 | 体験を変えず有料利用、server状態と一致 | 別UID反映、復帰で古い状態、手動付与が必要 | 次のアプリ更新停止。安定版を維持し通常同期を修復 |
| 18 Customer Portal確認 | 本人のLive Customer・専用構成 | カード/請求履歴/帰還を確認 | 別UID拒否、550円履歴、ログイン維持、新規購入/プラン追加なし | 意図しない顧客変更・プラン変更・即時解約が可能 | 新規受付停止し対象Portal構成を切戻す。既存解約/支払管理は維持 |
| 19 期間末解約確認 | 本人の対象Subscription | Portalで予約しGmail通知とbilling反映を確認 | cancel_at_period_end、期限まで利用、次回請求停止、日割りなし | 即時解約、利用期限違い、通知/同期失敗 | 現状態照合、追加操作停止。予約取消は本人承認後だけ、Webhook保持 |
| 20 必要なら本人テスト契約を返金／終了 | 明示特定した本人検証契約/Invoice | 本人承認の対象額だけ個別返金又は終了、Customerは保持 | 不要な継続なし、通知/権限一致、他契約不変 | 対象/金額不明、二重返金、一般利用者影響 | 一括取消せず照合。返金の効果をコードrollbackで戻せるとしない |
| 21 Flutterの購入CTA撤去 | 別紙の購入導線/価格/Portal入口 | アプリの新規購入・契約管理導線を除去。Web管理とアプリの権限読取りを維持 | 購入/外部Web購入/Portal/価格なし、試用/読取/権限/起動復帰・無料ユーザー削除を維持。契約ありの安全な削除を別タスクで整備 | Web管理や権限の喪失、体験変更、継続請求を残した削除 | アプリ候補を旧ソースへ戻し配布しない。契約は触らない |
| 22 Android／iOS新ビルド | 固定ソース・既存署名/版番号 | 既存成功手順で生成、依存/ID/鍵維持 | 正式署名、版競合なし、CTA不在の候補固定 | 署名違い、無断SDK更新、dirty混入 | uploadせず既存配布版維持。識別を訂正 |
| 23 TestFlight／Google Playテスト | 承認済み本人テスト範囲 | 同じ候補で認証/試用/権限/CTAを実機確認 | データ保持、許可範囲内配布、復帰更新PASS | 配布対象逸脱、回帰、版競合 | 新候補の配布拡大停止、既存版保持、修正版は別版番号 |
| 24 App Review Notes | 当該iOS候補の審査原稿 | 実際のCTA不在・アプリ外購入・21日体験・既存権限を記載 | 実候補一致、両Apple Caseを事前承認と誤記しない | CTA残存、資格情報不足、将来仕様を実装済みと記載 | 未送信草案へ戻し修正、審査送信しない |
| 25 Google Play審査説明 | 当該Android候補・審査アクセス | アプリ外Web起点・既存契約利用を実候補と照合 | 有効な審査アクセス、既存Alpha履歴と戦略C新版を区別 | 購入誘導残存、説明/実装不一致 | 未送信草案へ戻す。既存Alphaや資格情報は維持 |
| 26 ストア提出 | 本人承認済み候補・原稿・地域 | 対象/公開範囲の最終承認後に提出 | Consoleで提出結果確認、公開操作とは区別 | 最終承認なし、回帰/未解消不一致 | 可能な範囲で提出/公開を取り下げ又は保留、既存配信版維持 |

工程15で本人の既存体験が有効なら、初回550円の予定確認を実550円の支払済み証拠と偽らない。元期限まで待つか、本人所有の別の未開始/終了済み既存アカウントを別途承認して使う。体験の書換・追加契約の乱造はしない。

今回は本Runbookを実行せず、Live Stripe/Hosting/Flutter/ストア設定、メール送信実装、main merge/pushを変更しない。

## 一次資料

- [消費者庁Q15/Q17](https://www.no-trouble.caa.go.jp/qa/advertising.html)：請求開示の条件。実体制は別途確認。
- [Gmail APIのエラー処理](https://developers.google.com/workspace/gmail/api/guides/handle-errors)：送信上限・一時障害への対応。採用方針を実装済みとみなさない。
- [Stripeの商品/Price管理](https://docs.stripe.com/products-prices/manage-prices)、[期間末解約](https://docs.stripe.com/billing/subscriptions/cancel)：既存契約保護と新規Price/period-endの技術照合。
