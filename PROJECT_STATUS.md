# Hamster Care プロジェクト状況

## 2026-11-23 Apple提出準備①〜④の配備・内部配信完了（⑤実機・⑥提出情報を継続）

- **現在地と履歴の優先順位**：本人の①〜⑥一括承認を、基準`54970b2802f8`から実行。①課金backendは`90d8f237d8bf`、②Webは`d9109f8008fb`、③アプリ内安全削除backendは`54970b2802f8`を配備元とする。以下が最新の実績であり、下段の「新旧Webhook両停止」「Live adapter未実装」「Hosting45不変」等は、その時点の計画・保留履歴として残す。現在も一般購入false/private・一般メール停止を維持し、既存契約の正規同期だけを稼働する。
- **①Webhook切替完了**：新Acacia/7event endpointを通常処理へ接続。実在する既存イベント1件をStripeの正規再送で処理し、同じ審査アカウントのUID/Customer/Subscription/旧Price/status active/期間、100%forever割引、最新0円Paid InvoiceがStripe正本と一致。正規receiptはprocessed、審査用通知outboxは0件。旧endpointは**2026-11-23 09:58:30.471 JST（00:58:30.471 UTC）**にdisabledを確認し、その後`HAMCARE_LEGACY_WEBHOOK_ENABLED=false`、新`HAMCARE_WEBHOOK_MODE=process`/`HAMCARE_WEBHOOK_ENABLED=true`を維持。11/27 10:03:01 JSTは現在の契約期間末であり、自動解約日ではない。自然更新後の実績はまだ未確認。
- **検証の区別と書込み**：最初の管理者HMAC署名probeは503/verification_only/Retry-After60、receipt消費なしで、Stripeからの実配送とは区別する。次のStripe CLI正規再送では実503配送を確認し、verification中のreceipt不存在/billing・outbox不変を別に照合。その後のprocess正規再送でbillingのschema/canonical情報と処理記録を更新した。これは承認済みの通常同期書込みであり「本番Firestore書込み0件」とは記録しない。契約・請求・Customer・Session・割引・期間の変更は0件。
- **限定配備と設定**：5関数のrevision/配備元/実配備archiveを照合PASS。課金3関数は168ファイル、削除2関数は164ファイルのsource一致。`HAMCARE_LIVE_WEB_BILLING_CONFIG:1`と既存compute SAへのSecret単体Accessorを接続し、新旧の署名値は分離。550円Price/非default Portalは既存作成物を再利用し、再作成0。Checkout private、Portal本人認証、削除retry worker privateを維持。詳細revision/SHAは[既存Runbook冒頭](docs/release/web_billing_live_cutover_runbook_ja.md)に記録。
- **②本番Web反映完了**：`d9109f8008fb`の固定Git archiveから、Hosting`22b8c97c2532f11c`→`58e5ed12aaa990f6`へoverlay。既存11差替え＋新assets4＝49ファイル、既存34hashを保持。cloneで再生成された予約init2ファイルは元hashへ復元してからfinalize/releaseし、全49map/configを照合。CSPはaccountの本番接続と固定success復帰に限定、他設定を保全。Live adapter/flat DTO/同UID status・billing再読取/Portalと550円・法務表示を反映し、URLだけの成功断定/Preview fallbackなし。匿名の本番account実画面で停止bannerを確認。今回のスマホ実Live表示・実ログイン・実決済は未確認。
- **②限定検証**：関連Node407/407、LP静的86/86、Hosting helper Mock20/20。local Mock account/planに加え、本番の匿名accountをChromeの明示viewport360/390pxで確認し、停止banner・正本outline icon・scrollWidth=clientWidthをPASS確認（確認後viewport復元）。これはdesktop Chromeの実Live表示であり、実iPhone Safari/Androidや認証後表示のPASSには置き換えない。Privacyは公開済み音声開示5箇所を保持。contactのHTML/JS・確認済み原本・既存履歴を保ち、連絡先確認/実配送の再試験0。
- **③安全削除backend・再試行接続完了**：`deleteMyAccountAndData`/`retryAccountDeletions`を限定配備。後者はprivate、15分ごと/`Asia/Tokyo`のSchedulerをENABLEDで接続。作成後のURI末尾の表記差分を検知した時点でPAUSEDにし、同じ宛先・認証・IAMを厳密照合して採用後にresume。既存compute SAの継承Invokerを再利用し、worker IAM追加0/project IAM追加0。接続直前queue0、手動dispatch0、実アカウント削除0。Web削除申請APIや通知workerは今回配備しない。
- **停止・利用者保護**：購入APIの匿名呼出し403、Portal/アプリ内削除401、retry worker403を正常起動と区別して確認し、副作用経路へ入っていない。購入client固定false/server false/private、contact false、契約通知worker未配備を維持。Preview/既存確認済み連絡先/無料テスター/飼育記録/21日体験の開始・期限・利用枠を変更しない。新しいエラー回避のための手動権限付与やbilling手書きは行わない。実メール/実Apple認可失効/新規実契約/実請求0。
- **④本人内部TestFlight配信完了**：`1.0.1 (6)`のIPAは`54970b2802f8`の固定397入力/source hash/署名を確認。Transporterで2026-11-23 10:05 JSTにDelivered・処理完了。輸出コンプライアンスは既存2〜5と同じStandard OS/TLS・独自暗号なし・France Noの根拠で保存し、既存「本人実機確認」グループへ6を追加。15:30 JSTに1 Tester/5 Builds、build6 Testing/90日を実UI確認した。外部配信/新規招待/審査送信なし。その後の本人端末の更新保持確認は次項の本人報告を根拠とし、配信完了だけを端末動作PASSとしない。
- **⑤本人実機：更新保持PASS、審査・削除の限定確認を継続**：本人がiPhone TestFlight `1.0.1 (6)`へ更新し、「更新保持・表示とも問題なし」と回答。更新後Home、ログイン状態/プロフィール/既存飼育記録の保持、利用状況表示、アプリ内の購入/価格/Portal/Web購入誘導がないことを本人確認PASSとする。更新をまたぐ保持確認前のログアウト/アプリ削除は行わず、この回答済み範囲は再依頼しない。審査用については本人から「HamCare審査用でHome開いた」、使用場所は「iPhoneのHamCareアプリ」と回答があり、既存の正しい審査用0円契約UIDのAdmin Auth lastLoginを15:59:52 JSTに読み取り照合した。提出候補build6の実機新セッションでの審査用ログイン/Home到達は本人確認PASSとする。契約状態/変化/相談など必要機能の追加本人確認は待ちで、ログイン成功だけで一括PASSにしない。Mac Device Hubの隔離iPhone16 Pro/iOS18.3.1は掲載画像取得用の別セッションで、ログイン操作を依頼中・成功画面は未確認。新しいAppleアカウントやiPhone全体のAppleアカウント切替は前提にせず、既存検証用「Apple Web E2E Owner」のApple連携UIDを削除候補として読み取り確認済み。本人は「通常利用ではない。この範囲で削除検証を承認」と回答し、本番の確認済み連絡先原本を含む提示範囲での削除検証を承認済み。ただし現時点の削除/失効は0件で、承認と実行結果を区別する。通常の本人用/審査用0円契約/外部テスターは削除対象にしない。一般削除とApple失効、失効後の同UID再ログイン/削除再開は各々未確認のまま。
- **⑥提出情報：進行中**：ASC 1.0.1でbuild6を選択・Save後に6表示/Save disabled/Manual維持を確認。Description/Review Notes/Support/copyrightを保存し、電話番号・審査用パスワードは本人が保存済み。審査用targetは既存記録と照合したが、以前のAuth REST検査はブラウザの伏字値を使った無効な検査で、本人パスワード不正の根拠ではない。実機新セッションの審査用ログイン/Homeは上記本人回答と正しいUIDのlastLogin照合でPASS、契約状態/変化/相談等の機能画面とMac画像取得用ログインの確認待ちは分け、追加REST試行なし。Primary Lifestyle/Secondaryなしを保存。年齢質問は親制御・年齢確認・自由Web閲覧・UGC・social/chat・位置共有・広告すべてNo、成熟/性的/暴力/賭博None、Medical Infrequent/Wellness YesでApple算出13+・overrideなしのSavedを確認。App Privacyは既存10typesとPrivacy URLのPublishedを維持し、音声endpoint非保持の限定再評価根拠は既存Privacyチェックリストへ記録。App AccessibilityはGet Startedのまま保証未申告。AvailabilityはJapan Available on App Release/他174地域Notを読取確認のみ（変更0）。Screenshotは現在0。既存4枚を比較し、01 Home/02クイック記録/04相談は現行との差分があるため更新対象、03変化は現行実画面の最終照合後に維持できる候補とした。全面撮り直しや未搭載画面の合成はしない。Content Rightsは実際の質問/選択肢を再確認し、既存台帳で確認できた根拠と本人にしか確認できない具体的3群を提示。本人の「記載素材は利用可能と確認できる」回答を受け、第三者コンテンツあり・必要な権利ありのYesを選択し、Done→Save→Saved表示と保存後の権利あり文言を再読取した。根拠は既存素材台帳に追記、確認画像はGit外`proof/content-rights-saved.jpg`へ保存。審査送信/ストア公開/merge/pushなし。
- **静的検査の未解消4件**：account172/176。FAILは`server Apple policy binds Admin UID/disabled and exact current token provider`、`server non-Apple policy retains both actual verified-email checks`（共通policy抽出/再export後も旧inline文字列を要求）、`production billing/Auth source unchanged functions/src/index.ts`、`production billing/Auth source unchanged functions/src/stripeSubscriptionSync.ts`（旧baselineとの全文一致を要求）。実条件は共通policyのAdmin UID/disabled/provider/二重verified判定と直接testで維持。Sync差分は同tx削除fence用persist接続で、契約条件/権限評価を緩和していない。FAILをPASSとせず、検査を無効化していない。

## 2026-11-23 本番550円設定を作成・購入停止版のみ先行配備（審査0円の同期保護で残工程を保留）

- **承認/開始**：`b9d6e160eb940f1d0f6d483d0d7391d882ed44b9`/同専用branch、開始時clean。本人が設定/3関数停止配備・記録を承認し、0円審査契約の同期へ影響があればその工程と依存変更だけを保留する条件を追加した。連絡先確認は完了扱いで再試験0。
- **影響を確認して保留**：実Live審査契約は旧500円＋100%forever割引でactive、最新Invoice0円Paid、期間末2026-11-27 10:03:01 JST。Stripe参照と同UID billingをGET照合。旧Webhookを停止し新処理falseのままにすると期限更新が止まり審査権限を失い得る。legacyPriceId省略の新Portalも同契約を拒否するため、旧Webhook停止/差替え・Portal handler切替・新Webhook/完全JSON Secret登録を保留。一般有料利用者0人とLive契約0件は区別する。旧受信/署名/契約/割引は維持した。
- **独立して完了**：既存Product再利用でLive550円Price `price_1Uek2xK6h5kxGn4c9ji94qtp`、非default専用Portal `bpc_1UekYpK6h5kxGn4ctmpsyYh9`を各1件作成。550/JPY/月1回/licensed/inclusiveと許可機能・固定return/法務URLをGET検証、旧500/default Product/旧default Portal不変。既存Live公開可能キーも同アカウント/Live一致で取得、rotationなし/値非表示。Portalの入力400は理由選択肢を収集無効のまま2件指定して解消し、作成物は1件だけ。
- **先行配備は1関数だけ**：購入API `createStripeCheckoutSession`をb9 exactへ更新、`createstripecheckoutsession-00006-ruf` ACTIVE。purchase=false/webhook=false/private/IAM検査有効、旧4つのSecret bindingを保持。新JSONがなくても設定/Auth/DB/Stripe前で止まり、旧500円fallbackなし。Functions/Run両経路403。164ファイルのsource/compiled hashを照合。Webhookは00010-kuq、Portalは00009-hecのsource/設定/IAM不変。
- **本番変更の分類/保護**：Stripe成功書込みはPrice1/Portal1の設定だけ、契約/請求/Customer/Session変更0。旧Webhookはenabledのまま、停止時刻/新endpoint/新署名Secret/専用Secret/追加Accessorは未実施。審査Subscription/期間/割引/最新0円Invoiceとbilling全文は前後不変、確認済み連絡先/既存履歴/contact false/テスター/体験/権限/Previewを維持。Hosting/メール/通知worker/削除/Flutter/ストア/merge/push変更0、復旧実行0。
- **検証/残件**：既存490件は再実施せずcompile1回＋起動/falseの4局所入力確認。停止中の設定読取/Auth/DB/network0。既存設定・0円契約の限定GETを行い、未処理eventを一括再送しない。[既存Runbook冒頭](docs/release/web_billing_live_cutover_runbook_ja.md)へID/版/5現行event/7予定event/署名参照・保留理由・再開前の契約/期間/配送履歴照合・対象eventの正規同期手順を記録。同期維持条件を解決してから残るSecret/Webhook/Portal接続、その後Live画面adapter/DTO/status復帰へ進める。今回の記録2文書だけを1コミットにまとめ停止する。

## 2026-11-22 550円・課金API・Webhook接続の次回本番変更一覧を準備（未実行）

- **現在地**：承認済み`cd624d4c9ae7`/同じ専用branch、開始時clean。連絡先の受信・同UID確認済み保存・スマホ復帰は完了扱いで再試験0。購入private/contact false・確認済み連絡先/累計2通/既存履歴を維持する。
- **対象の読取り**：Liveは旧500円Price1件のみ（同Product再利用可）、550円未作成。旧default Portalは個人情報変更を許可するため新専用構成が必要。旧Webhookはdahlia/5event、SDKはAcacia固定で新endpointが必要。専用`HAMCARE_LIVE_WEB_BILLING_CONFIG`未作成。同アカウントの実Live公開可能キーだけ実行前入力が必要。旧Price/設定/記録を変更せず、対象GETのみで判定した。
- **最小修正/検証**：`HAMCARE_WEB_PURCHASE_ENABLED`の明示true以外はconfig/Auth/DB/Stripe前に停止。Webhookは`HAMCARE_WEBHOOK_ENABLED`の明示true以外、正署名/Live判定後かつprocess/claim前に503/Retry-After60。不正署名400、Portal/元21日trial/UID/権限評価は変更なし。runtime/index/直接testの3ファイルだけ修正、strict TypeScript・関連490件PASS、SDK/依存変更0。Callableの見かけのprivate宣言に頼らず、既存非公開IAMを保つgcloud限定更新を正本にする。
- **次承認の具体範囲**：既存Productへ新550円Price1、非default Portal構成1、旧Webhookを保持して停止→Acacia新endpoint1を作成直後停止、新署名/IDの専用Secret登録と既存compute SAのSecret単体Accessor、既存3 Functionの停止版限定更新。終了時は購入false/private・Webhook false/新旧endpoint disabled・contact false/通知worker未配備。作成直後の短いenabled区間・署名対応・失敗時復旧を[既存Runbook冒頭](docs/release/web_billing_live_cutover_runbook_ja.md)に明記。
- **Web/通知の境界**：Hosting22b8/45hash/CSP不変、今回配備0。canonicalのLive adapter/DTO/成功後status接続は一般購入前の別実装残件とし、PreviewをLiveへURL差替えしない。通知/削除worker・新Web削除・Flutter・ストアは対象外。contact falseだけを通知worker停止とみなさず、現在未配備のworkerを今回も配備しない。Relay/追加VoiceOverは非ブロッキングを維持する。
- **本番未変更/次段階**：Price/Portal/Webhook/Secret/IAM/Functions/Hostingの本番新規変更0、業務データ/実メール/実契約/Stripe書込み/実削除0。実Live公開可能キー等の事前入力値・準備コミットIDを確定して承認を受け、承認後の新設定ID/署名値は作成応答へ束縛してRunbook順に実行する。今回は設定/停止制御/手順の準備と既存2文書を1コミットにまとめ、merge/pushせず停止する。

## 2026-11-22 追加1通で本番連絡先確認を完了（累計2通・停止復帰済）

- **開始/本人指定**：`69c2667947d52e6d846cbc95bcb495f72ad29c97`・同じ専用branch/worktree・開始時clean。前回の同じApple UIDを維持し、本人がMac内の非公開入力画面で新しい受信可能な連絡先を指定。宛先指定の保護判定を直して再入力後に受理し、この段階のメール送信0。Apple IDメールから宛先を推測せず、Authメール/ログイン方式/UIDを変更しない。
- **追加枠の最小実装**：既存`limitedContactTest`の明示累計上限を1または2に限定。旧永久slotのschema/同owner/hash/予約時刻を検証した場合だけ`billing_notification_delivery_limits/_limited_contact_test_2`をtransaction create。旧slot/送信履歴/日次counterをリセットせず、別宛先1件への変更にも対応。同key再試行・3通目・未知結果後・翌日/再起動で追加POST不可。Auth/確認engine/期限15分/使い切り/固定復帰は維持。4source/直接test2だけ変更、TypeScript・関連330件、Hosting helper10件PASS。
- **設定/限定配備**：Live Secret v2の同じgmail.send認可を再利用し、v3へ同UIDhash1/新指定宛先hash1/有限6時間/累計2だけを設定。OAuth設定/認可/Previewは変更せず、Preview Secretのreadも0。日次枠は既存消費1を含め一時2、`billingContactEmail`だけfalseで配備（`billingcontactemail-00005-sas`）し、164ソース/compiled/packageの一致を確認。本人限定trueは`billingcontactemail-00006-fuj`。他Functions/IAM/Rules/Index/Stripe/Flutter/ストア変更0。
- **実確認PASS**：本人が本番Appleログインし、送信直前にスマホで今回の宛先を開けると回答。追加分の受信・差出人/本文/スマホ表示に問題なし、新しいリンクで確認済み表示を本人確認。同UIDの`billing_contacts`は新指定連絡先のverified=true/pendingなし/使用済みhash1、requestedAt履歴2・旧prefix保持・永久slot1不変/slot2正規・UTC全体/本人counter各2を照合。送信枠消費後の要求は上限拒否され、既に進んだ確認を引継ぎ、3通目は送らない。初回メールの実受信は未確認の履歴のまま。
- **復帰PASS**：本人のスマホで「プラン確認へ戻る」→「アカウント確認へ戻る」→再読込後も「確認済みの連絡先を利用できます」を確認。Macでも固定plan復帰・同じテストnickname/Apple/Authメール未設定と独立した確認済み連絡先を表示。契約/購入/体験開始へ進まない。
- **最終停止/保持**：停止revision`billingcontactemail-00007-vah`がACTIVE、enabled=false/日次1/Secret v3。status/request/confirm各503+正規停止code、購入API403。Hostingは本人限定版4aad→停止版`22b8c97c2532f11c`へ再release、45hash/CSP不変、実画面の停止案内を確認。今回追加1通・累計2通で停止し、再送/期限延長/回数リセット0。確認済み原本/旧履歴/2永久予約を保持。
- **本番書込み/保護**：本人contactの正規再発行/確認済み遷移、既存日次全体/本人2docの1→2更新、追加attempt/slot2の新規2docのみ。Authメール未設定/provider構成とowner/pet/trial/billing基準hashは停止後も不変。既存テスター/Preview/Stripe/契約/利用権限/Apple設定/実削除/他配備変更0。秘密値/UID/宛先/token/link全文はGit/診断へ出さない。既存PROJECT_STATUSとRunbookを今回のコード/testと1コミットにまとめ、main merge/pushなしで停止する。

## 2026-11-22 本番準備配備の承認範囲を再照合（再配備なし）

- `14b7904edb53`を配備元とする準備配備と静的検査3件目の説明補足は、記録コミット`d475c8b229e1`で完了済み。後続承認の本人限定確認`304465659444`を維持し、古いコードの再配備・Secret v1への巻戻し・OAuth変更は行わない。
- 現行状態を読み取りで再確認：購入serviceのInvoker IAMチェック有効、service/projectの公開bindingなし。Functions/Run両経路の空callable要求は403。有効な未完了Live Checkout Sessionは0件（open 0/未失効0、Stripe GETのみ）。contactはACTIVE/revision`billingcontactemail-00004-luf`、enabled=false/日次1/Secret v2、status/request/confirm各503かつ`contact_service_unavailable`。Hosting最新は停止版`22b8c97c2532f11c`。
- 実際の3件目の検査名は`production billing/Auth source unchanged functions/src/index.ts`。旧基準との全文不一致を失敗のまま保持し、共有認証・停止条件・1関数限定配備と旧58関数不変の根拠は既存Runbookに記録済み。検査無効化/PASS扱いなし。
- この再確認での設定変更・配備・実メール・Stripe書込み・ユーザー業務データ変更は0。先行タスクの本人宛送信受付1件と未確認pendingを取り消す記録ではない。購入/メール停止を維持し、今回の追記だけを独立した文書1コミットにする。

<!-- hamcare-owner-live-contact-20261122:start -->
## 2026-11-22 本人限定1通の本番連絡先確認（送信受付1・確認未完了／停止復帰済）

- **範囲**：承認済み`d475c8b229e12af3b64c7498a0c86c4b74fd989f`/同じ専用branch・worktreeから継続。本人1UID/本人所有1宛先/今回総数1通/日次1だけの本番確認。購入受付停止を維持し、通知worker/他Functions/Preview/Flutter/ストア/Stripeは変更しない。今回分をコード・関連test・既存2文書の1コミットにまとめる。
- **本人照合**：既存Preview許可hashと前回の本人確認済み連絡先を照合し、同じ既存Apple UID・Authメールなし・既存テストowner/petを確認。本番連絡先docは未作成だった。Previewデータは本人特定にだけ使い、確認済みデータをLiveへコピーしない。個人値・UID・token/link全文をGit/診断へ出さない。
- **設定/コード**：既存Gmail送信専用grantをrefresh確認（scopeはgmail.sendだけ、本人再認可不要）、Preview Secret/認可は不変。Google Auth Platformの宣言へgmail.sendと送信目的を追加し、既存YouTube用途を維持。一般向けOAuth検証完了とは扱わない。Live Secret version2へ本人hash各1/有限6時間/総数1を明示。4sourceの最小変更で、認証後DB前のUID/宛先拒否、Gmail POST直前の永久1回slot、repeat要求による最初のproof上書き防止を追加。slotは翌日/再起動/失敗/未知結果でも再利用しない。日次1も維持。
- **限定検証/配備**：backend/共有sender306件、Web4対象85件、Hosting helper9件の合成試験とTypeScriptがPASS。`billingContactEmail`だけをまずfalse/Secretv2で配備（revision`billingcontactemail-00002-hox`）、本人ログイン後にtrueへ限定変更（`billingcontactemail-00003-kin`、19:54:56 JST）。未認証statusは401。本人以外・別宛先・同時/再送拒否はMockと配備設定で照合し、別の実アカウントを使った試験はしない。
- **一時Web表示**：停止版`22b8c97c2532f11c`→本人限定案内`4aad15f145ca5691`。2 HTMLの文言だけを変更し、残る43ファイル/JS/認証/CSP不変・45hashを照合。終了時に同じ停止版を再release済み。
- **実送信/結果**：本人の本番ログインからUI要求を1回だけ実行し、Gmail受付/UI送信済み/pending sent/requestedAt1/日次全体1・本人1/永久slot1を確認。raw tokenなし、hash/15分期限だけ保存。受信・ブランド/本文/スマホ表示の報告と確認完了保存を得られないまま期限到達し、配送成功・確認E2E成功とは扱わない。再送/期限延長/回数リセット0。
- **最終結果/停止復帰**：送信要求は1回（Gmail受付済み）、実受信・ブランド/本文/スマホ表示は未確認。確認済み保存/固定plan復帰は未達で、本人docはverified=false/失効pending/usedTokenHashes0のまま保持。20:13:15 JSTにfalseのrevision`billingcontactemail-00004-luf`がACTIVE。status/request/confirm各503+正規停止code、購入API403。Hostingは`22b8c97c2532f11c`へ復元し、45hash/CSP不変・本番画面の停止案内を確認。検証完了とは記録しない。
- **本番書込み/保護/残件**：本人contactのpending/リクエスト・送信状態と、日次全体/本人/attempt/永久slotの4制限docを保存。確認済み保存は0。Authメールなし・provider構成、owner/pet/trial/billingの基準hash不変。Preview/他Functions/既存テスター/Stripe/Flutter変更なし。追加権限なし。実配備162ソース/compiled/packageの一致を確認。次は受信状況の本人照合と、失効済みのため追加検証をどう行うかの別判断。現行の1通枠では再送せず、永久予約/期限/未確認状態を勝手に書き換えない。
<!-- hamcare-owner-live-contact-20261122:end -->

<!-- hamcare-stopped-production-preparation-20261122:start -->
## 2026-11-22 一般受付停止での本番準備配備（完了・購入再開は別承認）

- **承認/配備元**：本人が具体的一覧・購入停止・復旧を一括承認。`14b7904edb53f8270420a4c2e58fd35d5be5dd44`/`feature/web-first-stripe-checkout`、開始時は承認資料の指定2文書だけdirty。他素材/差分を保護。19:04 JST開始、詳細は[既存Runbook冒頭の実績](docs/release/web_billing_live_cutover_runbook_ja.md)。新管理表/監査書は作らず、この2文書だけ今回1コミットにする。
- **購入停止**：旧`createstripecheckoutsession`からallUsersのRun Invokerだけを除去。IAM反映後Functions/Run両経路で未認証空要求403。Live発行済みopen/有効Session0、失効/契約取消なし。正式ローンチの購入受付判断まで停止を維持し、復旧でも公開権限を勝手に戻さない。現在は無料テスターのみ・一般有料利用者0人。
- **本番設定変更**：`HAMCARE_LIVE_BILLING_MAIL_CONFIG`新設/資格情報なし停止version1、既存compute SAへのSecret単体Accessor、新contact service単体public Invoker。9基盤API/既存service-agent roles不変、API有効化/Project IAM変更監査0。Preview資格情報コピー0、対象外Live課金Secret登録0。
- **新Function1件**：`billingContactEmail`のみ19:10:44 JSTにACTIVE、revision`billingcontactemail-00001-wor`、Node22/256MiB/1CPU/max1/concurrency5/60秒。enabled=false/dailyLimit1/Secretv1を照合。status/request/confirm各503+正規停止code、異Origin403、OPTIONS204。handler正常起動と意図した停止を確認し、起動/Secretエラーを成功扱いにしない。token/実UID/実受信者なし、Auth/DB/Gmail前で停止。配備GCS sourceの162ファイルが承認stagedソース/compiled/packageと一致、env/依存同梱0。
- **Hosting**：19:14:53 JST、`2365135bf558c278`→`22b8c97c2532f11c`。旧13全hash保全＋追加32＝45を公開前後に厳密照合。cloneで自動再生成されたFirebase予約2ファイルは未公開版で元hashへ復元後release。`/account/`・`/account/contact/`と依存だけ追加し、LP/法務/サポート等は不変。scoped CSPはFirebase Auth/Firestore/本番contactだけ、Preview/Stripe接続なし。初期化後も残る静的停止案内をcontactへ1段落追加（範囲内の表示仕上げ、JS/認証不変）。
- **Web確認**：全追加32件HTTP200/SHA一致、旧10ページ/リンクHEAD200、account CSP漏れなし。IABで正本outlineロゴ/星空/停止表示・未使用5枠display:none・横はみ出し0、Console error/warn0。個人情報なし画像をGit外へ保存。実ログイン/フォーム送信/物理端末E2Eの繰返しは行っていない。
- **既存互換/静的3件**：58→59関数、旧58のresource更新/実行設定差分0。通知/削除worker・新Web削除2endpointは未配備、削除URL404。既存ログイン/通常利用/体験/権限/アプリ内削除/Rules/Flutter/テスターは変更0。billing_contacts不存在で通常利用を拒否する依存なし。静的168/171の3失敗は保持し、2件はpolicy共通化と旧文字列検査、3件目は旧index全文と承認済み抽出/追加の150追加827削除の差分。全体配備を正当化せず1関数限定と旧58不変を根拠に非ブロッキング。関連Mock148/148と既存357件を再利用。
- **障害と監視**：CLIが無関係Secretを要求したため入力せず中止し、同じ1関数を直接指定。初回CPU既定値とconcurrency5不整合は元CLI既定1CPUを明示して解消。稼働停止成功とは分離記録。配備後旧58の稼働ERROR0、意図したcontact503が3、初回制御面エラー1。配備前の既存ERROR2とは区間長が違うため率比較しない。未解決の起動エラーなし。
- **構成変更と業務データを分離**：本番のIAM/Secret/Function/build/Hosting変更は上記あり。今回のFirestore/Auth/飼育記録/trial/billing/テスター権限/Storage画像の業務書込み0、実メール0、Stripe書込み0、実削除/Apple失効0。作業開始後のLive Customer/Session/Subscription新規作成も各0。Rules/Index/SDK/Flutter/ストア/既存Apple設定/merge/push変更0。
- **次工程/残件**：Gmailのscope宣言/検証又は例外条件・本番資格情報・送信設定を整えてから、別承認で専用未契約アカウント1件/確認メール1通の確認→プラン復帰を行う案。日次上限1は送信承認ではない。Live550円Price/本番課金API/Portal/Webhook/通知/安全削除の配備、実契約、アプリ配信/ストアは未実施。実Apple失効後復帰/Relay実配送等を未確認として維持し、Relay/追加VoiceOverは非ブロッキング。一般購入停止は本人の次の判断まで維持する。
<!-- hamcare-stopped-production-preparation-20261122:end -->

<!-- hamcare-production-contact-20261122:start -->
## 2026-11-22 有料登録前の連絡先確認の本番対応（コード・限定検証、未配備）

- **開始点/再利用**：承認済み`c88955cecd81`、同じ専用branch/worktree、開始時clean。Preview確認engineを共通化し、既存15分/1回token・送信制限・旧確認済みメール保持・発行済みPreview hashを維持。本番Store/API/Webの必要部分だけを追加し、Preview実配送/既存の全課金・認証・削除E2Eを繰り返さない。
- **本番接続**：`billingContactEmail`（asia-northeast1）のPOST status/request/confirm、canonical Origin/JSON/Bearer/失効検査・現在Admin UID/Apple subject照合。明示`HAMCARE_BILLING_CONTACT_ENABLED==='true'`、既存本番`HAMCARE_LIVE_BILLING_MAIL_CONFIG`、有限`HAMCARE_BILLING_MAIL_DAILY_LIMIT`が不足すると日本語で停止。Preview設定/データ/URL/枠へfallbackなし、今回有効化0。
- **原本/消費者**：`billing_contacts/{uid}`・`purpose:billing_contact_live`・firebaseUid/schemaVersion/verified/verificationStatus/source/verifiedAt/email。課金/通知は共通`readVerifiedBillingContact`、既存安全削除は同じdocを削除。Storeのtransactionでも削除フェンスを確認し、遅延確認による復活を拒否。Auth逆同期/メール統合/Customerメール検索なし。A通常確認済み/B Apple Relayは追加実メール不要、C本当にメールなしだけ補完、既存未確認メールはAuth確認を案内する。
- **送信/変更**：旧確認済み連絡先は新しい確認のtransaction完了まで維持。Gmail sender/OAuth/通知と共有するLive予算・停止期限を再利用し、新メールサービス/Secret/OAuth追加0。60秒/3回時/5回24時間、未知送信の自動再送禁止、明確な送信前失敗だけ最大1回の1秒backoff。新規申込は引き続き停止し、既存Preview Portalと本番Portal APIの連絡先非依存を維持。canonicalのLive購入/Portal UI有効化は後続切替で、今回PASSとは扱わない。
- **Web復帰**：固定Origin/endpoint/Auth保存名と応答modeを厳密分離。確認tokenはSDK前にfragmentを消してメモリのみ。同じUIDで明示確認後、固定`/account/?contact=verified&view=plan`→連絡先再読込み→読取り専用プランへ復帰。任意復帰先・他UID・期限切れ・旧link上書き・再利用拒否。既存購入用ガード/体験/550円/有料権限は維持。
- **検証**：Functions/Preview strict TypeScript build PASS。関連backend179（新Live15、Preview互換62、既存課金/通知reader99、Checkout境界3）＋Web176＋Firestore Emulator2＝**357件PASS**。専用demo/localhost18689、Auth/Gmail/Stripe/StorageはMock。実transactionの二重消費1回、原本→共有reader/通知、既存削除core→原本消去→古い確認で復活不可を確認。LP86/brand178 PASS、旧account静的168/171の既知3件は維持し、今回影響6件だけstrict環境分離/固定復帰の検査へ更新。
- **表示/証拠**：外部connect禁止の実HTML/View/CSS＋合成fixtureで360/390px、入力/待ち/確認/完了・Relay追加入力なし・削除案内SLA/保持説明を確認。横はみ出し0、入力16px、正本outlineアイコン/テーマ維持。worktree外`artifacts/billing-contact-live-20261122/`に個人情報なし画像。物理スマホ/実メール配送/実Relay確認とは区別する。ローカルserver/Emulator/依存参照は後始末する。
- **確定削除運用値**：原則初回3営業日（JST土日祝除外）、本人確認＋意思確認後は原則7暦日目安、遅延理由/見通し→以後7日ごと連絡。完了窓口履歴90日/期限切れ未確認履歴は失効後30日。窓口メール/添付・support申請・CLIファイルだけが対象で、処理中/既存再試行/復活防止/会計へ一括適用しない。Go担当の毎営業日期限確認・週最初の営業日の手動整理手順を既存文書/公開予定HTMLへ反映。TTL/履歴削除/整理稼働0、確認リンク期限延長0。
- **残件/保護**：Secret/IAM/明示枠/有効化、Hosting/CSP、本番配備後の実配送・復帰・Relay/不達・課金/通知参照確認は別承認後。[本番Runbook](docs/release/web_billing_live_cutover_runbook_ja.md)と[連絡先実装記録](docs/release/japan_store_payment_and_ios_readiness_20261018.md)を更新。前工程の実アカウント削除・実Apple失効/その後の同UID再ログインは未確認のまま。本番Firestore/Stripe/Auth/Storage操作・実メール0、Hosting/Preview/Functions配備0、テスター/契約/Flutter/ストア/Apple設定/SDK/lock変更0、main merge/push0。今回分だけ1コミットで停止する。
<!-- hamcare-production-contact-20261122:end -->

<!-- hamcare-verified-support-deletion-20261122:start -->
## 2026-11-22 メール削除申請→Web本人確認→既存安全削除の接続（未配備）

- **開始点/対象**：承認済み`fcdd64465613`、同じ`feature/web-first-stripe-checkout`/専用worktree、開始時clean。現在有料契約者0人の前提を維持。今回の接続・限定試験・既存文書だけを1コミットとし、Flutter/SDK/依存/Apple設定/ストアを変更しない。
- **本人確認**：運営がAdminで選択した既存UID/Auth作成時刻と受付番号へ申請を固定。192bit申請ID/256bit秘密値（hash保存）、24時間/1回限り、直近5分かつ発行後のFirebase再認証、失効検査、現在のAdminレコード/Apple subject照合。メール/本文UID/画像は証拠にせず、別UID/新規/再作成/期限切れ/流用/再使用を拒否。同じ申請へ削除/課金停止意思をtransactionで記録。メール確認/購入/飼い主/ペット登録を削除条件にしない。
- **運営実行**：private IAM endpoint、未設定時falseのenable switch、固定先OIDC CLI（秘密値/UIDを標準出力へ出さず0600ファイル）。既定は読み取りdry-run、確認済み申請のUID hash/範囲/Firestore契約snapshot/処理状態を確認し、5分期限のsnapshot digest+明示executeだけで実行。任意UIDへ差し替え不可。`runAccountDeletion`と既存`deletionDependencies`をそのまま共有し、Stripe停止/排他/再試行/tree walk/Auth/Storageを迂回しない。完了はcompletedフェンス+Auth不存在の再照合。実メールは送らず受付/途中/完了の案内文を用意。
- **Apple**：既存JS12.17.1の再認証/`revokeAccessToken`を再利用する独立Web接続。申請UID preflight→Apple再認証/UID・subject再照合→失効→同意記録。token/codeはメモリ限り、保存/送信/ログなし。失効取消/失敗/30秒未確認時だけ明示manual fallbackを提示し、不一致は迂回不可。server記録はclient申告と区別。実失効/失効後Stripe失敗からの同UID実機再ログインは未確認を維持。
- **限定検証**：Functions strict TypeScript build PASS。今回関連Mock/pure6ファイル66/66（core17、HTTP8、CLI5、Web25、既存匿名ページ8、Preview境界3）、Firestore Emulator2/2で計68件PASS。Emulatorは専用demo/loopback18687、Auth/Storage/StripeはMock。未確認運営実行/別UID/期限/再使用拒否、プロフィールなし/Appleメールなし、Stripe停止失敗とcleanup失敗後の同じ申請からの再開、二重要求/完了証跡を確認。LP86/86、brand178/178 PASS（現行outline masterの正本/派生を含む）。全アプリ/既存購入E2Eの繰返しは行わない。
- **Preview表示**：[申請案内](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account-deletion/) / [本人確認説明](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account-deletion/confirm/)。同じchannel、最終version`e01a69d94cb66f1f`、期限11/29 08:10 JST。確認機能false+canonical限定でSDK読込/認証/Apple失効/API送信/削除0、CSP connect-noneを維持。CSS幅360/390・本文16px・横はみ出しなし、説明/正本アイコン/停止状態とconsole error/warnなしをCUAで確認。配信6リソースHTTP200/SHA一致、本番live`2365135bf558c278`不変。画像はworktree外`artifacts/support-deletion-20261122/`へ保存。今回の物理Safari実機削除PASSとは扱わない。
- **運用値/公開残件**：正式な対応SLA/保持期間は既存未設定。推奨案は初回3営業日・本人確認後7暦日目安・7日ごと途中連絡、完了履歴90日/未確認期限切れ30日で整理（未承認/自動purge未実装）。完了フェンス等は現在TTLなし。会計保存期間は記録種別ごとに確認し、全消去期限を約束しない。運営IAM/最小権限・本番core/worker/Secret/監視・新endpoint配備・Web有効化/最小CSP・専用アカウントの配備後確認は別承認の残件。今回の接続タスク完了と本番削除運用開始を区別する。[現行運用/返信案/保持一覧/反映手順](docs/release/web_account_deletion_support_20261121.md)と[本番Runbook](docs/release/web_billing_live_cutover_runbook_ja.md)を更新。
- **保護**：本番Firestore/Stripe/Auth/Storage操作・実ユーザー削除・実Apple失効・実メール送信0。Functions/live Hosting/テスター/契約/Play Console変更0、main merge/push/新ビルド配信0。Hosting Previewの停止状態の静的表示だけ反映。既存の未追跡素材に触れず、検証用依存symlink/Emulatorは後始末して今回1コミット後に停止する。
<!-- hamcare-verified-support-deletion-20261122:end -->

<!-- hamcare-web-deletion-request-20261121:start -->
## 2026-11-21 Google Play向けWeb削除申請ページ（Preview確認、live未公開）

- **開始点/実装**：承認済み`6940aec7ca6d`、同じ専用branch/worktree、開始時clean。既存`/account-deletion/`を現行outlineロゴ/星空/すりガラスで改訂。ログイン・再インストール・登録メールからの送信を求めず、Appleメールなし/Relayもメールで申請可能。件名入りmailto、公表サポートメールのコピーと失敗fallback、申請≠完了、削除/保持データ、本人確認後のStripe停止を説明。新API/購入CTAなし。LP/Privacy/Supportのsource導線も整えた。
- **Preview**：[申請ページ](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account-deletion/)、同じ`web-first-task1`、version`037676ed8b90b69f`、期限11/28 21:48 JST。Hosting専用の新設定で削除ページだけ追加し、元Preview/Auth CSP・法務案除外を維持。Privacy/Supportリンクは既存canonical live。liveはversion`2365135bf558c278`・release不変。
- **確認**：Web pure454/454、LP86/86、brand178/178 PASS。配信10リソースSHA/HTTP200、対象外4経路404、canonical法務3リンク200。実Previewの匿名閲覧、CSS幅360/390・本文16px・横スクロールなし、コピー成功、LP導線、console異常なし。旧account監査168/171の3件は、今回不変の既承認サーバーsourceと古い固定検証の不整合として記録し、削除/認証を勝手に変更しない。
- **本人確認/公開残件**：申請メールと認証UIDを安全に結ぶ機能・運営用の安全な実行経路は未実装。メール/UID/スクリーンショットだけでは削除しない。受付リンク→既存Web認証→明示確認記録、および既存安全処理を再利用する承認済み運営実行経路を最小追加案として報告。Apple失効→Stripe失敗後の同UID再ログイン/再開は実機未確認を維持。準備後にcanonical `/account-deletion/` をPlayへ登録する。現時点で削除運用の本番GOとは扱わない。
- **保護/記録**：本番Stripe/Firestore/契約/Auth/Storage操作0、実ユーザー削除0、Flutter/Functions/テスター/Play Console/Apple設定変更0、live公開/main merge/push/新ビルド配信0。メール送信0、Preview配備だけ1回。[本人確認・削除運用と検証記録](docs/release/web_account_deletion_support_20261121.md)を参照。今回の1コミット後に停止する。
<!-- hamcare-web-deletion-request-20261121:end -->

<!-- hamcare-apple-deletion-revocation-20261121:start -->
## 2026-11-21 Apple認可失効をアカウント削除に統合（コード・Mock、未配信）

- **開始点/範囲**：承認済み`e1fe0524dbb9`、同じ専用branch/worktree、開始時clean。有料契約者0人の前提を維持。Apple関連のclient処理・直接試験・記録だけを変更し、前工程のStripe停止・削除フェンス・worker・データ/Auth削除を不変とする。
- **API/順序**：既存Firebase Auth6.0.0の再認証/失効APIを再利用しSDK更新0。削除確認後、Apple連携があれば既存Userを再認証し元/返却/現在Firebase UIDと既知Apple subjectを確認。codeを直ちに失効し、その後だけ既存Callable→Stripe停止確認→データ/Auth削除→ローカル同意消去/signOut/完了へ進む。短寿命codeをStripe待機/workerへ持ち越さず、保存/ログ/Callable送信しない。
- **失敗/他provider**：UID・既知subjectの不一致や本人認証異常は停止。初期Apple情報/code欠損、認証取消、失効未確認/30秒timeout、Android/Web非対応は手動解除案内と明示的な「削除を続ける」を用意し、TN3194どおり削除を永久拒否しない。Apple連携なしは処理をスキップし、複数providerはapple.comの有無で判定する。Apple失効だけで完了扱いにせず、Stripe失敗は既存の未完了/再試行を維持。
- **検証/保護**：関連Flutter26ファイル385/385件PASS（新規service43件、Settingsの再認証/失効→既存削除・明示手動fallback・UID拒否・サーバー失敗/再試行等）。Dart新規指摘0、既存activeColor info6件のみ。Functions/Stripe停止/worker/フェンス/深い削除/Web/native設定/依存は開始HEADから不変。実Apple認可・実アカウント削除・本番API呼出/書込0、Functions/Hosting/Apple設定/ストア/テスター変更0、SDK/依存更新0、main merge/push/新ビルド配信0。[API根拠・失敗時の扱い・順序・試験記録](docs/release/apple_account_deletion_revocation_20261121.md)を参照。専用アカウントでの実機失効E2Eは別途事前承認後の残件であり、Google Play Web削除導線の独立実装は次指示で着手可能。
<!-- hamcare-apple-deletion-revocation-20261121:end -->

<!-- hamcare-account-deletion-billing-20261121:start -->
## 2026-11-21 アカウント削除前の継続課金停止（コード・ローカル検証、未配備）

- **開始点**：承認済み`6e85a3c25640`、同じ専用branch/worktree、開始時clean。運営者確認では有料契約者0人、無料テスターのみ。既存ユーザーの移行処理や実削除は行わない。
- **サーバー**：既存`deleteMyAccountAndData`とFirestore再帰削除・analytics/sensorフェンスを再利用。本人UIDの削除要求をtransactionで保持し、同UIDの新規Checkout/Customer予約を禁止。無料・Stripe手掛かりなしならStripe生成/API呼出0。契約ありはUID/Customer/Price/mode/Session/Invoiceを照合し、`invoice_now=false,prorate=false`で即時キャンセル、個別再取得と一覧で停止確認後にだけデータ/Authを削除する。通常Web解約は期間末のまま。
- **失敗/通知競合**：11分lease、15分worker/batch4、有限指数backoff/最大12回、manual_reviewと運営確認手順を用意。通信断・停止後のFirebase失敗を再開でき、`billingStopped`保存後は再キャンセルしない。Webhookの最終transactionは停止確認済み/completedだけ書込抑止し、未同意の削除中止時には支払通知を失わない。別UID不変。
- **削除/UI**：既存users/switchbot_users/Authに加え、本人の固定ペット画像と非会計の補完連絡先だけを削除。Stripe会計記録・Customer・運用証跡は一括削除しない。Flutterは無料には課金説明なし、有料だけ停止/残期間利用終了/原則日割り返金なしを確認する。新規購入/Portalリンク0を維持し、`ok=true`だけ完了扱い。
- **検証**：課金関連Mock504件、削除Emulator9件、Rules Emulator2件、Flutter334件＋小画面/キーボード1件PASS。TypeScript strict build PASS、Dart新規指摘0（既存activeColor info6件）。専用demo localhostと合成Auth/Storage/Stripeを使用し、実アカウントは削除しない。既存Golden font SHA制約は維持。
- **公開前残件/保護**：Apple認可トークンの明示失効は既存未実装で、Auth削除と同一視せず別途解消する。専用Live設定/Secret/IAM/Scheduler・運用監視通知・保持削除方針・配備後検証は未実施。本番Stripe/Firestore/Auth/StorageへのAPI呼出/書込0、本番Functions/Hosting/テスター/ストア変更0、新ビルド配信0、依存SDK更新0、main merge/push0。[実装・検証・再試行手順](docs/release/account_deletion_billing_safety_20261121.md)を参照し、今回1コミット後に停止する。
<!-- hamcare-account-deletion-billing-20261121:end -->

<!-- hamcare-app-portal-removal-20261121:start -->
## 2026-11-21 戦略C：Flutter契約管理導線の撤去（ローカルコード、未配信）

- **前提訂正/開始点**：本人の訂正により現在の有料契約者は0人、利用中は無料テスター。旧Live500円Priceの存在から契約者の存在を推定しない。今回新たな移行・互換処理を追加しない。承認済み`d23820c42c4b`、同じ`feature/web-first-stripe-checkout`の専用worktree、開始時clean。
- **撤去**：利用状況のPortal callable/URL/外部起動/管理ボタンと、削除確認から管理へ進む経路・削除続行の迂回を撤去。内蔵Termsの「利用状況から管理」も読取りだけへ訂正。WebサイトのCustomer PortalとFunctionsは維持。前工程のF例外は今回の承認で失効し、以下の前工程記録は履歴として読む。
- **維持**：21日体験・明示開始/AI枠、契約状態、UID単位の有料権限取得/再取得、Web契約による機能解放、起動/復帰時読取り、通常アカウント管理・無料削除、Privacy/Terms/Supportを維持。iOS/Androidの共通ソースに購入経路差なし。
- **削除の暫定境界**：本人UIDのbillingをserverから確認し、契約あり/不明/取得失敗/cache/pending/UID変更では削除要求しない。文書なし/契約なし/Customer参照のみの無料アカウントは既存確認→削除Functionへ。確認前後に読取り、`ok=true`以外は成功扱いせずsignOutしない。これはクライアント側の暫定拒否であり、Stripe正本の不存在や競合防止を保証しない。
- **独立次タスク**：`deleteMyAccountAndData`は今回未変更。Stripe継続請求を停止・確認してからAuth/データを削除するサーバー処理、Webhookの遅延/再作成、Customer対応・連絡先/outboxの保持削除、失敗/再試行を別タスクで実装する。今回、有料契約の安全削除や配信準備完了とは扱わない。
- **検証**：関連25ファイル322/322件PASS。無料削除の実Settings/Callable wrapper21件、guard28件、境界16件、利用状況28件・entitlement race37件、21日体験、明暗Home/Drawer/Settings/利用状況、AI/記録/通知/レポートを含む。186 Dart、同梱asset27指定/137ファイル（文字4）のスキャン5件PASS、購入/Portal/Web購入導線0、非購入外部起動8箇所。変更/追加9 Dartのanalyzeは新規指摘0、既存Settings activeColor非推奨info6件のみ。既存カレンダーGoldenのfont SHA不一致は前工程の制約として残し、今回の導線は非Goldenで確認。画像全件OCR/実機再確認・実アカウント削除は行わない。
- **保護/詳細**：実Firestore/Auth/Stripe API呼出0、本番契約/体験/テスター権限変更0、Web/Functions/Hosting/ストア/ネイティブ設定/SDK/依存/版番号変更0、新ビルド配信0、main merge/push0。[今回の撤去・削除境界・検証記録](docs/release/flutter_customer_portal_removal_20261121.md)を参照。
<!-- hamcare-app-portal-removal-20261121:end -->

<!-- hamcare-app-strategy-c-cta-20261121:start -->
## 2026-11-21 戦略C：Flutter新規購入CTA撤去（契約管理は安全例外、本番未配信）

- **開始点/監査先行**：承認済み`eb731dbee423`、同じ専用branch/worktree。Flutter実装変更前に[購入導線A〜G監査](docs/release/flutter_strategy_c_cta_audit_20261121.md)を記録。直接Checkout1箇所、間接誘導（機能ガード/設定/レポート）、旧500円の価格と内蔵規約の申込説明を分類した。今回の差分はFlutterと直接関係する試験/記録だけ。
- **撤去/中立化**：Flutterの`createStripeCheckoutSession`呼出・購入処理/ボタン/価格を削除。レポート購入widgetと2つの使用箇所を撤去。設定は「利用状況」、lockedは「このアカウントでは、現在この機能を利用できません。」を基本にし、AIエラーのプラン誘導も中立化した。新規購入へ進むアプリ内ルート/URL/価格比較/QRを追加せず、iOS/Android共通で同じsourceを使う。
- **維持/再取得**：21日体験・カード不要/自動課金なし・開始条件/AI枠・既存の明示開始・有料機能判定・課金モデル/Repo/バックエンドを維持。利用状況は同一UIDのserver確認済みbillingと体験を読取り、active/有効trialing/期限内の解約予約を利用可として扱う。再確認ボタンは読取streamを再購読するだけ。起動/UID切替時の監視を維持し、専用の復帰時再取得が元sourceになかったため、利用状況と機能ガードへread-onlyのresume再購読を追加。期限・認証切替・キャッシュ/pending writeによる誤解放を防ぐ。無料体験未開始を終了済みと表示しない。
- **残したリンク**：Privacy/Terms/サポートmailto/YouTube参照/研究DOIの非購入8箇所を維持。既存analyticsの定義・レポート内容/生成・記録・condition score・AI文脈・通知は変更しない。価格履歴の表示UIは見つからず、旧500円は新規申込説明にのみ存在した。
- **最終検証**：23ファイル271/271件PASS（状態/UID/キャッシュ/期限/再確認/復帰、無料体験、AI同意/認証/ペット切替、Home/Drawer/Settings/利用状況の明暗実ナビゲーション、レポート閲覧/analytics、記録Repo、通知等）。利用状況は360px/文字2倍も確認。185 Dart source・27 asset指定/137 unique asset/4テキストの共通スキャン5件PASS、新規Checkout/購入価格/購入CTA/QR/購入URLは0、F Portal1とG非購入8は保持。変更17 Dartファイルのanalyzeはerror/warning0、新規指摘0、既存Settings activeColorの非推奨info6件は同じsourceのまま残した。既存カレンダーGolden系列はfont固定SHA不一致で準備/終了時の2エラーとなり未検証（既知環境制約）。期待画像/helper/固定SHAを変更せず、今回の導線は別の非Golden試験で確認。実機/ネイティブ新ビルド/ストア承認の確認とは区別する。
- **重大ブロッカー/F例外**：既存削除処理は有効契約でも「削除へ進む」で迂回でき、解約予約/past_due/読取失敗等では警告を通らず削除へ進む。サーバーもStripe契約を確認/終了せずAuthとusers配下billingを削除し、継続請求・対応消失が残り得る。今回は削除本体をbyte単位で維持し、既存契約だけのPortal呼出/「契約管理」と削除警告→利用状況の経路を安全例外として残した。UID確認中/未契約には管理を出さず、非同期中のUID変更でも古いURLを開かない。**「契約中ユーザーのアカウント削除」を独立必須タスクとして解消するまで、Portal完全撤去・戦略C版の正式提出/配信はNO-GO**。このタスクで削除問題を解決したとは扱わない。
- **保護**：実Firestore/Auth/体験/契約/テスター権限変更0、Stripe/Functions/Webhook/メールoutbox/Hosting/ストア変更0、Android/iOSビルド配信0、実機install0、main merge/push0。pubspecとlock/バージョン`1.0.1+3`は開始点から不変。既存の一致する依存情報とキャッシュ済みFlutter3.47.7/Dart3.13.5を利用し、SDK/依存更新・pub getなし。
<!-- hamcare-app-strategy-c-cta-20261121:end -->

<!-- hamcare-billing-notifications-20261121:start -->
## 2026-11-21 戦略C：契約通知outbox・Gmail Worker（本人Preview配送確認、本番未配備）

- **開始点/範囲**：承認済み`81ac23933fda`、同じ専用branch/worktree。通知基盤だけの実装・合成検証・本人限定Preview5通。Webhookの契約/体験/料金判断は変えず、既存transactionの通知hookを不変の契約snapshot付きoutboxへ変換した。Gmailの成功をbilling同期・権限更新の成功条件にしない。
- **通知と重複抑止**：契約登録（体験0円/即時）、支払成功（初回/更新）、支払失敗、解約予約、予約取消、契約終了の6種類。contract/trialを登録1通へ、初回/更新や別名eventをinvoice単位の支払1通へ統合。未確認支払いの繰返しを同一invoiceで重複通知せず、単なるmetadata/内部同期/再送では送らない。新規550円、既存500円は明示legacy snapshotの実額を維持。宛先/本文/Secretはoutboxへ保存しない。
- **送信境界**：本番`billing_notification_outbox`とPreview`preview_billing_notification_outbox`を分離。UIDから現在の確認済みAuth通常メール→Apple provider根拠のある両Relayドメイン→同一UIDの確認済み補完連絡先を解決。未確認/宛先なしは`blocked_no_verified_contact`で停止。Previewは本人UID/宛先hashの二重allowlistと本人だけのsmoke runnerに限定し、任意送信APIは追加しない。
- **OAuth/Worker**：個人Gmailの既存送信専用本人OAuthをPreviewでメモリ利用。DWD/サービスアカウントによるGmail impersonationなし、新規認可/Secret変更なし。本番用Secretは宣言だけで未登録。将来のWorkerは15分周期・最大instance1・batch5・lease120秒。初回含む最大5回、送信前の一時障害/明確な拒否は有限指数backoff、quotaは最低24時間。送信後5xx/timeoutや送信中lease切れは`uncertain`で隔離し、二重送信を避けて有人照合する。送信専用APIだけでexactly-once配送を保証しない。
- **本人実配送**：既存Secret/本人の同一UID/飼い主/ペット/確認済み補完連絡先を読み取り照合後、Preview fixtureから契約登録・支払成功・支払失敗・解約予約・契約終了を各1通、計5通送信。Gmail API受付/outbox sentは5/5・各attempt1。本人が5通の受信、件名、HamCare表示、Reply-To、本文、550円、日付、固定管理リンク、迷惑メール判定、Gmailスマホ表示、日本語表示すべて問題なしと回答。予約取消は合成試験のみ。実Relay配送は未確認・非ブロッキングの既存残件を維持する。
- **最終検証/再実行**：Functions/Preview strict TypeScript build PASS。本番API・通知関連21ファイル984/984、Preview既存11ファイル514/514、専用demo Rules Emulator2/2・228アクセス操作で計1500テストPASS。Worker62/Gmail95/宛先・本文110/Runtime・送信枠116/通知変換11/固定runner6の新規400件、既存関連584件を含む。Gmail制限後は全通知共通の送信停止期限も保存し、後続通知はGmailへ進まず延期。旧500円metadata同期から過去の支払通知を作らず、後から届く実支払eventはinvoice単位で1通とする。実runner再実行でproviderSendCalls0、送信済み5件/attempt1維持を確認。再実行時刻が変わって増えた未送信fixture1件は、当該run/UID/未送信を照合して削除し、run時刻を固定して再発を6件の回帰試験で防いだ。追加メール0通、送信枠/履歴のリセットなし。Emulator停止・loopback閉鎖確認済み。
- **本番前の残件**：本番OAuth/Secretの本人承認・長期利用可否（同意画面の公開状態等）、明示送信枠/IAM/Scheduler、独立連絡先確認producer、通知失敗/不達/uncertainの有人運用と保持削除、実Live契約・通知E2E。通知コード準備と本人Preview配送は、本番配備承認・長期配送保証とは別。Flutter CTA撤去は別指示の独立タスクとして着手可能で、今回変更しない。
- **根拠/保護**：[通知実装・配送記録](docs/release/billing_notification_outbox_20261121.md)。本番Stripe API呼出/書込み0、本番Firestore/billing変更0、既存契約/体験/外部テスター権限変更0、外部テスターへの送信0、Functions/Hosting配備0、Flutter/ストア変更0、main merge/push0。Secret値/ID token/メール全文のログ出力なし、依存/SDK更新なし。新しいWorkerを配備せず指定の1コミットへ整理して停止する。
<!-- hamcare-billing-notifications-20261121:end -->

<!-- hamcare-production-web-billing-api-20261121:start -->
## 2026-11-21 戦略C：本番Web課金APIの準備（コード・ローカル試験のみ、未配備）

- **開始点/範囲**：承認済み`4dc423fbcebd`、`feature/web-first-stripe-checkout`の同じ専用worktree。既存3 export名/region/callable transportを維持して安全なLive専用runtimeへ委譲。既存の非課金処理・21日体験・有料判定・Flutterは変更しない。旧subscription同期の純粋モジュールは保持し、旧Portal/Checkoutから直接billingを書いていた入口と旧Secret/defaultへのfallbackを除去した。
- **共通/分離**：PreviewとLiveはUID/provider・メール分類・固定550円と元体験終了日時の純粋policyを共用。Preview専用Secret、Test Customer/Price、URL、namespace、Webhook、Portal設定は保持。Liveは専用JSON設定、Customer/Session調整文書、event/UID lease、billing保存先を明示。現設定が空でもimport/登録は可能、操作は設定検査を最初に行いAuth/Firestore/Stripeへ進まず「現在お申し込みを受け付けていません。」で停止する。
- **新規550円/既存500円**：新規は`premium_monthly`から将来のLive550円Priceだけを解決。Test/旧500円へ代替しない。UID metadataと既存billing/対応表でCustomerを解決し、同一UIDのlease・transaction・固定idempotencyで多重Customer/Sessionを防ぐ。結果不明の古い操作を新規作成し直さず照合待ちで停止。既存500円を改価/移行/解約しない。PortalはFirebaseの失効確認済み同一UIDによる管理用認証を新規購入条件から分離し、連絡先未設定/未確認だけでは既存管理を妨げない。Apple provider照合は維持する。
- **権限正本**：本番契約状態の書込みはLive Webhookのtransactionだけ。raw署名、Live mode、event冪等性、最新Stripe状態、UID/Customer/Subscription、許可Price、元trial_end、snapshot versionを検査。旧500円も同期対象に残し、登録後のプロフィール削除だけで既存契約の支払/解約同期を止めない。通知hookは同じtransactionのoutboxへ重複なく保存するだけで、メール送信は未実装。
- **影響/配備前提**：現在の配信版/本番設定は未変更。将来配備すると旧アプリの空の購入要求は安全停止し、旧500円画面から550円を勝手に課金しない。旧Portalの空payload/`portalUrl`は維持。専用Live設定一式と旧500円のUID対応、Portal互換性を事前確認せず既存APIだけを切替えてはいけない。WebのLive API接続、Cの本番連絡先確認producer、Gmail本番通知worker、保持削除、実IAM、Live構成/E2E、CTA撤去/ビルド/提出は残件。
- **根拠**：[API実装・互換性・設定schema](docs/release/production_web_billing_api_20261121.md)、[Rules/IAMローカル監査](docs/release/production_billing_rules_audit_20261121.md)、[未実行Runbook](docs/release/web_billing_live_cutover_runbook_ja.md)。テスト結果は本節の最終検証記録に集約する。本物のLive mode APIは呼ばず、合成依存/専用demo Emulatorだけで検証する。
- **最終検証**：Node22、既存依存だけでFunctions/Previewのstrict TypeScript build PASS。本番API関連13ファイル581/581 PASS（新規8ファイル463件＋既存policy/Stripe優先度/旧同期/体験5ファイル118件）、Preview既存11ファイル514/514 PASS。Rules専用demo Emulator 2/2 PASS・183アクセス操作、終了/8297閉鎖確認。合計1097テストPASSであり、実Stripe/IAM/配備済Rulesの検証とは区別する。設定欠損時のAuth/DB/Stripe呼出0、UID/Live-Test境界、体験3状態、連絡先A/B/C、未確認メールの既存管理、多重実行/timeout/lease期限、署名/再送/順不同/同期競合、通知hook重複抑止を確認。旧indexのbilling以外の後半処理と有料判定helperは変更せず、差分/保護対象検査を行った。
- **保護**：実Stripe書込み0、本番Firestore/billing書込み0、既存契約/テスター権限変更0、Secret/IAM/Apple/ストア変更0、Functions/Hosting配備0、main merge/push0。依存/SDK更新なし。メール送信なし。指定の1コミットへ整理後に停止する。
<!-- hamcare-production-web-billing-api-20261121:end -->

<!-- hamcare-launch-policy-final-20261121:start -->
## 2026-11-21 残存方針確定・本番切替Runbook最終化（未実行）

本節と[26工程Runbook](docs/release/web_billing_live_cutover_runbook_ja.md)を現在の正本とし、旧節の返金候補/メール基盤未決定/Relay配送待ちの公開条件は採用しない。

- **確定**：月額550円、旧Live500円と既存契約は保持して新Live550円は後日新規申込だけへ接続。返金は利用者都合を原則行わず、重複課金/当方システム誤請求/法令上必要な場合を個別対応。期間末解約・期間末まで利用・次回請求停止・日割り返金なしを別に案内する。
- **特商法/窓口**：CAA Q15/Q17を照合し請求開示方式の文面・窓口を用意。購入判断前の十分な時間的余裕と遅滞ない書面/メール提供の実体制を本人が確認すればGO。氏名/自宅住所/個人電話を常時公開せず、個人値を転記しない。VO契約不要、将来検討のみ。公開窓口は既存Gmailを共用、ブランド差出人を維持する。
- **メール**：認証関連はFirebase、連絡先確認と契約開始/解約予約/契約終了/支払失敗/重要/必要なサポート通知は初回Gmail API採用。Stripeメールは補助。現実装は本人限定Preview確認のみで、本番通知・有限再試行/指数バックオフ/429/重複抑止/送信済失敗状態/バウンス等の不足を別紙へ。今回新規送信実装なし。独自ドメイン/Resend等は将来検討、初回非ブロッキング。
- **Relay/連絡先**：登録2送信元/SPF/両ドメイン対応を既存証拠として維持、実配送未確認は非ブロッキング。本人宛先確保後、本番前又は公開直後に確認。UID正本、確認済み通常メール/Relay、メールなしだけ確認済み補完というPreview実装と整合。実メールを必須にしない。
- **現状態**：方針/既存Test・Safari E2E/Android連絡先表示はGO。Gmail本番通知、Live接続、保持削除、CTA撤去、戦略C版ビルド/提出は未実施。既存Alphaの提出配信履歴はあり、Google審査を未経験とは扱わない。Go/No-GoはRunbookで方針採用と実装完了を区別する。
- **今回だけの差分**：文書・Runbook・指定された公開前Web文面/表示文字列と関連検査のみ。新メール機能/Functions/Rules/Flutter/SDK/Live Stripe/Hosting/ストア設定変更なし、決済/メール送信/本番billing/既存契約/テスター権限への変更0、Runbook実行0、main merge/push0。指定メッセージの1コミットへ整理して停止する。
- **関連**：[開示運用](docs/release/commercial_disclosure_operations_20261121.md)、[不足通知とFlutterの削除/維持対象](docs/release/launch_notifications_and_flutter_scope_20261121.md)、[料金・法務整合](docs/release/pricing_legal_alignment_20261119.md)。
- **今回の限定検証**：既存frontend12ファイル443件、静的LP84/account171/brand177＝432項目PASS。指定順序26工程と各5記載項目、Go表19項目、規約/特商法/最終確認/FAQの正式返金文・解約文、6 HTMLのローカル68参照、関連新文書リンク、diff check PASS。フロント金額の数値定数・認証/契約ガードは維持。既存Safari Test E2E/Android連絡先表示/実配送1件を再利用し、今回新しい実機・決済・配送・バックエンド試験は行っていない。個人値/Secretパターンなし、Flutter/Functions/Rules/SDK/設定差分なし。指定の1コミット保存後に停止する。
<!-- hamcare-launch-policy-final-20261121:end -->

<!-- hamcare-price-policy-20261121:start -->
## 2026-11-21 正式価格を「月額550円」に固定（文書更新のみ）

- **現在の正本**：HamCare プレミアムは「月額550円」。Preview／本番Web／Stripe Test／Stripe Live／利用規約／特商法で、この価格とStripeの最終請求額550円を正本とする。税抜500円の補助表示や税務上の区分による表示分岐は採用しない。申告・納税上の扱いはバックオフィス事項として別管理し、料金UXやリリースRunbookの判断条件にしない。以下の過去節にある旧表示・税務確認待ちの記載は、現行の料金方針・公開条件として採用しない。
- **本番切替方針**：旧Live月額500円Priceと既存契約は直接変更・削除・自動移行しない。別途承認後、新しい月額550円Live Priceを作成し、新規申込だけをそのPriceへ接続する。Preview Test Priceは550円を維持する。元の体験終了日時、0円/550円の初回分岐、UID正本、Webhook/権限/Portalの安全境界を維持する。
- **今回の範囲**：料金・法務整合文書、提出草案の方針部分、[本番切替Runbook案](docs/release/web_billing_live_cutover_runbook_ja.md)を更新。追跡文書に独立した課金切替Runbookがなかったため、既存監査書の切替案を料金関係に限定して分離した。HTML/JavaScript/Flutter・掲載用txtへの実表示反映は後続で、今回は変更・配備していない。過去の監査台帳とStripe読取り証拠は保持する。
- **保護**：本番Stripe変更・新Live Price作成・Stripe Test変更・Firestore billing/既存契約/テスター権限変更・Hosting/Functions/ストア操作・main merge/pushは0。今回は外部APIを呼ばず文書だけを変更する。返金、事業者表示、連絡先保持/削除・Relay配送、最終申込画面、Flutter購入CTAなど価格以外の残件は維持する。
<!-- hamcare-price-policy-20261121:end -->

<!-- hamcare-pricing-legal-20261119:start -->
## 2026-11-19 戦略C：料金・法務の改定案整合（未公開・本番切替不可）

- **範囲**：本人が `9e2b26ce36f5` の連絡先Preview・両実機確認を承認。専用 `feature/web-first-stripe-checkout` の同じ承認済みHEADから、表示文言・法務改定案・未提出原稿・記録だけを更新。消失した一時worktreeはプロジェクト内の永続worktreeへ復元し、元アプリのdirtyを混ぜない。今回のコミットは `docs(web): align pricing and subscription terms` 1件のみ。
- **確定料金**：HamCare プレミアム、主表示「月額550円（税込）」、補助「税抜500円」、10％前提、月額1種類。LP/FAQ・プラン/確認/Portal周辺・規約/特商法/Support・提出草案を整合。旧Live500円・既存契約・日付付き履歴・テスト拒否値は保持。全件台帳は指定語1,171行＋数値補足97行＝183ファイル/1,268行、A14/B5/C1,228/D21、本文・個人情報を転記しない。
- **契約条件**：既存体験中は本日0円・元体験終了日時に550円、未開始/終了済みは本日550円、新しい体験・延長・リセットなし。残48時間＋1分未満は既存の拒否ガードを維持し、終了後の申込案内を明記。解約しない限り1か月ごと550円、実際のStripe周期/日時を使用。Web Customer Portalで期間末解約、指定の期間末まで利用できる文へ統一。機能ロジック変更0。
- **実Live読取**：2026-11-19 20:59 JST、Stripe GETだけで確認。Live Price500 JPY/month・**exclusive**、Test550 JPY/month・**inclusive**。Live Tax設定はactiveだが直近expired Sessionはautomatic_tax=false/total500/tax0であり、全既存請求へ一般化しない。Live既定Portalは氏名/メール/住所/電話変更が有効、Test専用は無効。Webhookの地域/API版/受信invoiceイベントにも差があり、次工程の分離した切替計画へ。今回は本番設定を変更しない。
- **法務の未確定**：返金は既存特商法案と例外を参照し、本人判断候補A/Bを監査書へ。氏名・住所・電話の請求開示方式の実運用、責任者、税務/証憑、サポート、提供遅延対応を本人確認。PrivacyにUID正本、Relay、独立連絡先の用途非広告・Auth逆同期なし、Stripeのみカード処理、token hashを追加。15分は使用期限で削除期限ではない。独立連絡先の保存期間・期限切れ/退会時削除連携・本番メール基盤・Relay配送は残件。
- **検証**：再実行frontend443/backend514/policy91＝runtime1,048 PASS、TypeScript build PASS。静的LP84/account171/brand177＝432 PASS、関連HTMLローカル75参照解決、公開法務4 URL/既存Preview accountはHEAD全て200。ローカル実HTML/View/CSS＋合成データの17レイアウト（360/390/768/1280を含む）横はみ出し0。既存Safari決済/Portalと両実機連絡先PASSを再利用し、新しい実決済・メール送信・VoiceOver専用試験なし。今回Emulator68/旧Stripe pure21を再実行数へ足さない。
- **保護と判断**：本番Stripe/billing/既存契約/テスター権限の変更0、Firestore API呼出0。Flutter/Functions/Rules/SDK/lock/Apple/ストア設定変更なし、Preview/live Hosting/Functionsデプロイ0、main merge/push0。現在のPreviewは前回配信のまま、法務改定案は未公開でリンク先の旧条件とは注意表示で区別。ストア原稿はFlutter購入CTA撤去待ちで未提出・提出不可。法務/税務と実際の最終申込確定段階、保持削除運用等を確定後に本番切替準備を進める。詳細は [料金・法務監査](docs/release/pricing_legal_alignment_20261119.md)。本工程完了後は停止する。
<!-- hamcare-pricing-legal-20261119:end -->

<!-- hamcare-billing-contact-20261119:start -->
## 2026-11-19 戦略C：確認済み連絡用メールのPreview補完

- **範囲**：専用 `feature/web-first-stripe-checkout`、開始HEAD `ffd0a02a8e70` を維持。Authメールなし本人Appleアカウント用の独立連絡先確認を追加。前節の「メール未設定でも新規Preview申込可能」は今回の新規申込ガードで更新し、既存契約管理は維持する。本番公開・本番自動メール送信の承認ではない。
- **正本と分類**：サーバーで現在のFirebase署名／失効／UID／provider bindingと既存petを再確認。A＝Auth両側で確認済み通常メール、B＝現在Apple認証かつ確認済みRelay（`privaterelay.appleid.com`／`private.icloud.com`）、C＝Authにもproviderにもメールがない状態。A/Bは追加入力なし。未確認メール・不正値はCへ丸めず拒否する。連絡先は契約主体・アカウント統合のキーにせず、Firebase UIDを正本として維持。
- **保存・ガード**：`preview_billing_contacts/{uid}` に独立保存、送信共通枠は `preview_billing_contact_delivery_limits/{UTC日}`。Auth/provider・本番users・billing・体験を更新しない。未確認Cはreview見積り／Customer／Checkout Sessionより前に拒否し、確認後も作成直前に再読取。既存UIDに紐づくPreview Portal管理は阻害しない。連絡先変更中は旧確認済みメールを維持し、新しい確認完了時だけ置換する。
- **確認と配送**：32byteランダム・15分・UID/宛先binding・ハッシュのみ保存・一度限り。固定 `/account/contact/#token=...` のfragmentをSDK読込前に消去し、同一認証UIDの明示POSTだけで確認。厳密Origin/Bearer/JSON、60秒間隔・3回/時・5回/日/人・全体10回/日、未知結果の自動再送なし。本人がPreview専用Gmail利用、Gmail API有効化／新しい送信専用Desktop OAuthクライアント追加と `gmail.send` のみの認可を承認・実操作済み。送信元はApple登録済み管理アドレス。送信先／対象UIDは専用Secret内の各1件のハッシュ許可リストだけ。既存Googleログインクライアント・同意画面・Apple設定は変更しない。
- **検証の現在地**：backend514、frontend443、Emulator68（新Contact Store9/Rules3、既存Auth15/Apple25/Preview Store16）PASS。既存申込policy91/Stripe pure21もPASSでruntime計1,137件。静的LP84/account171/brand177、構文14、TypeScript build、diff check PASS。Emulatorは専用demo projectのみで停止済み。Preview用2 FunctionsはACTIVE、他56 Functionsとlive版 `2365135bf558c278` は不変。同じPreview最終版 `b9d352cc8225b204`（期限2026-11-26 20:02 JST）へ反映し、新規公開9resourceのSHA／安全ヘッダー一致、認証なし401・異Origin403・preflight204を確認。本物HTML/View/CSS＋合成AppleのIAB fixtureで5幅の横はみ出しなし、390pxのpending/complete/errorと入力エラー/Tab/focusを確認（実端末・実配送と区別）。本人Apple→管理Gmailへの確認メール1通→本人リンク確認→対象UIDのverified/source/used hash1→月額550円のサーバー契約確認→戻るまで実ChromeでPASS。Stripeへ進む/同意/新規Session/決済0。本人用Preview見積り1件の通常更新のみ別記し、Auth email/providerと本番4文書不変・送信予約1を最終readで照合。詳細は戦略Cリリース記録の同日節へ。
- **実機表示の本人確認（追加）**：2026-11-19、連絡先ページのiPhone Safari／Android Chromeでの文字切れ・横はみ出し・入力時のキーボードによる隠れを確認する依頼に、本人から「両方とも表示・入力に問題なし」と回答。両端末の表示・入力を本人確認PASSとする。合成5幅の実測とは別の根拠で、実機寸法・OS版・実機キャプチャは未採取。Stripe決済／Portal／Relay配送の追加検証やVoiceOver確認には広げない。
- **残件**：本人Relay宛先がないためRelay実配送は未確認。個人の実メールを取得するために別アカウントを作らない。GmailはPreviewだけで、本番の送信基盤・Relay配送・法務550円整合を公開前に確認する。VoiceOver専用追加開発・再試験は初回非ブロッキングのまま。
<!-- hamcare-billing-contact-20261119:end -->

<!-- hamcare-private-relay-audit-20261116:start -->
## 2026-11-16 Apple Private Email Relay：送信元2件登録済み／配送は本人用宛先待ち

- **方針の保存**：`0d761c3f1876`（`docs(release): record contact email and accessibility policy`）で、指定4文書だけを保存。旧一時worktreeが存在しなかったため、コミット済み `f66f019052ad` と同じ専用ブランチから `/private/tmp/hamcare-web-relay-20261116` を復元し、失われた未コミット差分そのものを回収済みとはせず、本人の確定指示から方針を反映した。元アプリのdirty／未追跡素材は作業対象外。
- **Apple登録の実結果**：本人の確定直前承認後、個別送信元 `noreply@hamster-breeding-app.firebaseapp.com` と `gotainu@gmail.com` の2件を登録。`Email Source Registration Complete` の2アドレス／0ドメインと、その後の一覧で両方の緑SPFチェックを確認。初回はセッション期限切れで未登録、再読込後に同じ承認済み2件だけを登録した。`gmail.com`／`stripe.com`等の第三者ドメイン全体、未使用ドメインは登録せず、既存登録の削除・App ID／Service ID／Key・DNS変更0。
- **配送を止めた理由**：本人から「今はない」と回答があり、本人所有のAppleリレー配送先がない。前回のApple E2EはAuthメール未設定であり、Relayありのユーザーと混同しない。Firebase／サポート／Stripeの今回メール送信は0通、転送・迷惑メール・返信・バウンスは未検証で、配送PASS・バウンスなしとは記録しない。他ユーザー、新規本番アカウント、架空のRelay宛先、Appleへのパスワード方式追加で代替しない。
- **コード・限定検証**：両Relayドメインは現行の表示／認証設計で受理可能。`account-model.mjs:maskEmail`／`checkout-model.mjs:projectCheckoutReview` に旧ドメインだけのallowlistはなく、`account-identity.mjs:projectAccountIdentity`／`auth-policy.ts:authorizePreviewIdentity` は署名検証済みFirebase UIDと現在Apple provider subject一致を正本にする。`privaterelay.appleid.com`／`private.icloud.com`各4項目（表示・review、正規Apple、別UID拒否、binding欠損拒否）の合成8チェックPASS。既存account-model／account-identity／checkout-model計82件PASS。既存Node22を使用しSDK・依存更新0、コード差分0。ドメインだけでメール確認済み・認証済みとは判定しない。
- **保護・Preview**：既存Preview `/account/` HTTP200／no-storeを確認し、デプロイ0。今回本番Stripe／Customer／Subscription／Firestore billing／既存契約／Authユーザー／体験／テスター権限の変更0、Stripe Test書込み0、Flutter／live Hosting／購入CTA／main merge・push・ストア操作0。Apple送信元登録だけが外部設定変更。メール未設定の本人Preview購入ガード・UID正本は保持。
- **判断・次工程**：送信元登録は完了、実配送は未完了で本番公開前の残件。連絡用メール補完フローの設計・独立Preview実装へは別承認で進められるが、今回実装しない。VoiceOver追加対応は非ブロッキングのまま。実配送を未確認のまま本番切替準備完了／公開可とは判断しない。詳細な送信元・代替設計・根拠は[戦略Cリリース記録](docs/release/japan_store_payment_and_ios_readiness_20261018.md#relay-sender-inventory-20261116)を参照。
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

最終更新: 2026-11-21

このファイルを、開発進捗・優先順位・重要判断の**正本**とします。日常の更新はこのファイルへ記録し、変更履歴はGitで管理します。従来のExcel管理表は2026-09-06時点の履歴スナップショットとして保存し、今後は原則更新しません。

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

<!-- hamcare-web-first-task8-20261115:start -->
## 2026-11-15 戦略C・タスク8：Apple Webログイン有効化（実装・実UID一致確認済み／実購入E2E保留）

- **承認・方針**：準備コミット `94571d9a71af` は本人承認済みで改変しない。事前明示同意があるFirebase標準trusted-provider連携を許容し、独自メール検索によるUID統合・データコピーをしない。1メール1アカウント方針、既存メール／Google、UID基準のStripe Customer／Subscription・Webhook／billingを維持する。タスク7の旧停止条件は履歴とし、現在は本節を正本とする。
- **設定完了**：`com.gotainu.hamster.web` を本人のRegister操作後に確認し、既存Primary App IDへ関連付けた。固定Domain `hamster-breeding-app.firebaseapp.com`／Return URL `https://hamster-breeding-app.firebaseapp.com/__/auth/handler` を確認概要からSaveし、Firebaseは本人が既存Sign in with Appleキーを直接入力・保存。Service／Team／Key参照・秘密鍵設定の一致を値非表示のAPI読取りで確認した。既存キーの失効・置換・新規作成、一時Preview URLのApple登録、live Hosting公開は行わない。Key ID・Private Key等をGit／文書へ保存しない。
- **同意と認証方式**：Apple公式ボタンを維持し、標準連携の可能性・非公開メール・別アカウントを統合／コピーしないことを事前説明。未同意はUI／service両方で開始不可、取消・ログアウト等で同意を消去する。OAuth state／nonceは既存SDKへ委譲。現在のcross-origin PreviewではPopup、同一origin固定authDomain＋モバイルSafari＋回復可能な短期同意状態の場合だけRedirectを選ぶ。Redirectマーカーは15分の同意版・開始時刻・方式のみで、認証情報や個人値を保存しない。実Safari OAuth／Redirect成功は未確認。
- **実Apple・UID一致**：最初のメールexact1件lookupは0件だったが、入力元はiPhone Apple ID設定と本人確認でき、HamCare未登録とは扱わない。全Auth一覧は自動承認レビュー拒否で未実行・取得0を維持し、探索を広げなかった。本人がiPhone表示と既存Auth UID全文一致を確認して非公開入力したlocalId exact1件で既存Apple bindingを確認。そのsalt付きUID仮名証跡と実Chrome Appleログイン後のWeb SDKを比較し、**project一致・現在Apple認証・nativeとWebのUID一致はすべてtrue**、**emailPresent=false／emailVerified=false** を確認した。UID・メール・Apple subject・private入口／proof値は本書・Git・公開ログへ転載しない。
- **認証時刻の区別**：最初の比較器の15分以内判定はfalseだった。最終の読み取り診断で時刻は有効・未来ではない・15分超過と確認し、無効時刻やUID不一致とは扱わない。通常の有効なFirebaseセッションへ新しい15分制限は導入していない。
- **メールなしApple互換**：native `lib/screens/auth.dart:180` のscope未指定経路と、`lib/screens/settings.dart:1235` のemailなしUID表示を限定監査したが、本人のメール未取得の原因は断定しない。Webはemail／name scopeを要求済みでも今回メールは補完されなかった。Preview限定で、Admin `verifyIdToken(...,true)`＋同UIDの有効Admin User＋現在のApple認証＋tokenのApple subject1件とAdmin binding1件の厳密一致を別`authBasis`として確認する。実emailVerified=falseを維持し、メール／Googleの両側verified条件は維持。未検証メールはStripeへ渡さず、メール属性を省略する。Auth管理編集・独自メール補完・Flutter変更は行わない。UID対応表・550円Test価格・元trial・Webhook・leaseは維持する。
- **限定結果・残るガード**：更新Previewをhard reloadしても再ログイン不要でaccount panelへ進み、メール確認未完了／読取り不能パネルには止まらなくなった。一方、main_pet未登録案内とplan無効は維持。実read-only billing APIは認証拒否ではなく`app_account_required`で停止し、Apple本人確認を通過した後の既存petガードが働くことを確認。Stripe／Firestore writerは呼ばない。Native RepoとWebの保存正本は同じ `users/{uid}/pet_profiles/main_pet` だが、この本人UIDのmain_pet登録は確認できず理由は未断定。データ作成・ガード回避をせず、**Apple経由の実Embedded決済・Portal往復は保留**とする。
- **テスト**：frontend316／backend445／policy91／Apple Auth・Firestore Emulator25／旧Auth Emulator15のruntime計**892件PASS**。静的LP84／account142／brand165の計**391件PASS**、TypeScript／`git diff --check` PASS。非公開helperのオフライン24件PASSは別枠。同メールGoogle／Apple標準連携・別UID非混入・新空UIDの契約拒否・false状態保持・失効／provider不一致・遅延／ログアウト競合・401の1回再検証／不明結果再送なしを合成検証した。実メール／relay選択、実同メール連携、実Safari OAuth、実スクリーンリーダーは未確認で、Emulatorを実証代用にしない。
- **Preview・配備**：同じchannel `web-first-task1`、最終version **`268f5115e3afec45`**、期限 **2026-11-22 15:37 JST**。Apple entry=true・同意必須を維持し、新identity moduleを含む公開35 resourceのSHA／安全ヘッダー一致・除外6経路404を確認。既存Preview Checkout／Portalの2 Functionsのみ更新しAPIでACTIVE確認。CLIはcleanup policy未設定の後処理警告で終了1だったが2対象の配備成功・ACTIVEを区別し、cleanup設定は変更しない。他55 Functions（Webhookを含む）のstate／updateTime、live Hosting、Auth policy／許可domainは不変。Functions resource全体のhash不変とは主張しない。
- **本番保護・保存・停止**：今回の新Auth作成・業務を含む本番Firestore／Stripe書込み・既存契約変更は0。元アプリHEAD・dirty10件SHA・全2,120行status、無関係の保護12ファイルSHAを保持した。実装・実Appleログイン・実UID一致確認は完了したが、petガードで実購入E2Eは保留であり、全要件完了とは記録しない。メール中継は既定Firebase送信元等の登録手順を整理済み、登録／配送は未検証。今回分だけ `feat(web): enable Sign in with Apple` の1コミットとして保存し、成立と最終hashはGit履歴・完了報告を参照する。main merge／push・live公開・本番課金・Flutter／ストア変更は行わず保存後停止する。
<!-- hamcare-web-first-task8-20261115:end -->

<!-- hamcare-web-first-task7-20261115:start -->
## 2026-11-15 戦略C・タスク7：Apple Webログイン準備（94571d9a71af・本人承認済み）

本人の追加指示で準備コミットを承認済み。以下の標準自動linkの扱い・停止条件は当時の履歴であり、現在は先頭のタスク8の新方針・確認結果を優先する。

- **承認・範囲**：本人承認済みタスク6 `a2e73511ecef` から同じ `feature/web-first-stripe-checkout`／専用worktreeを継続。Appleボタン・標準SDKの認証コード・日本語の中止／エラー案内と同UIDのアカウント読取りを準備した。既存メール／Google・プラン／Embedded／Webhook／Portalは維持するが、Apple実認証と要件の安全性は成立していないため**一般有効化は保留**。今回分は `feat(web): add Sign in with Apple` の1コミットへ保存。本人の設定完了返答後は読取りと最終表示確認だけを再開し、確認結果の文書追記を同じ1コミットへ含めて停止する。物理端末E2E・本番切替へ進まず、最終ハッシュはGit履歴と完了報告で確認する。
- **既存構成・本人操作**：native iOSの既存 `AppleAuthProvider` とBundle ID `com.gotainu.hamster`／Team `3SA77V3SM7`を維持。最初はAccess Unavailableだったが、本人から最新PLA同意・ログイン完了の返答を受け、設定画面へのアクセス復旧を確認した。App ID設定ダイアログでは「Enable as a primary App ID」が選択済みで、変更せずCancelした。既存Sign in with Appleキー1件がこのApp IDへ関連付いていることを確認したが、秘密鍵ファイルの保管先・利用可否は未確認で、Key ID・秘密値は記録しない。Services IDs一覧はGetting Started表示で登録0件、Email SourcesもNo result foundで0件。**`com.gotainu.hamster.web` は未作成の提案値**。前回Firebase APIで確認したApple provider enabled=true／Web client ID・OAuth Key未設定は維持し、今回Apple／Firebaseの設定は変更していない。
- **固定ドメイン案**：既存のauthDomain `hamster-breeding-app.firebaseapp.com` を維持し、既存Firebase OAuth Handler **`https://hamster-breeding-app.firebaseapp.com/__/auth/handler`** のHTTP200を確認。Service IDを既存Primary Appに関連付け、Web Domainsはこの固定firebaseapp.comと標準web.appのホストを候補として本人に提示する段階で、未登録。Appleへ一時Preview URLを恒久登録しない。Firebaseで許可済みの既存Preview Auth domainは維持し、固定Handlerを使うためのlive Hosting公開は不要。最終本番も固定Handlerを使う案とし、Preview期限後は追加した一時許可だけを撤去する。
- **Web実装と無効状態**：Apple公式の日本語ボタンPNGを無加工で使用。標準Firebase SDK PopupとOAuthProviderのApple・email／name scopeを準備し、state／nonceの実装はSDKへ委ねるが、実フローの検証済みとはしない。通常UI／サービスの `appleSignInEnabled` はfalse、準備中の説明とdisabled表示を維持する。これは通常のアプリ経路を止める公開設定であり、Firebaseプロジェクト全体のセキュリティ境界ではない。ログイン方式Appleの表示、個人情報消去・遅延応答破棄・取消／衝突の日本語案内を用意した。自動link・UID間コピー・Auth削除は実装しない。
- **アカウント存在ガード**：本人UIDの従来3文書にserver-only `pet_profiles/main_pet` の存在読取りを加え、既存アプリのアカウント判定と揃えた。新しい空UIDやpet未作成・読取り不能ならプラン確認／契約へ進めず、別UIDのデータを読まない。Firestore Rules・本番Functions・既存課金経路は変更せず、メールをStripe紐付けの正本へ使わない。
- **有効化を妨げる2条件**：Firebaseは信頼済みApple providerの同一メールで既存別providerへ自動linkする場合があり、アプリがlinkWith APIを呼ばないだけでは防止できない。合成Emulatorでも同一メールの既存password UIDへlinkされる挙動を観測したため、統合防止PASSとは扱わない。また既存 `analyticsAccountRegistered` はAuthユーザー作成時に本番のjourney文書を書き込むため、新規Appleログインを無条件に許可すると今回の本番Firestore書込み0要件を満たせない。globalの重複メール設定や既存Auth triggerを変更せず、未解決を隠して有効化しない。
- **次の安全方式案（未実装）**：メール比較を使わず、サーバーでApple provider identityから既存Firebase UIDだけを照合し、新規Auth作成を行わない限定ログインを検討する。現時点では設計提案・本人判断待ちであり、実装済み／認証安全性確認済みとはしない。Apple設定の本人操作と、この方式が要件を満たすことの検証を経てから有効化を判断する。
- **検証結果と環境差**：frontend197件、backend383件、既存policy84件、既存Stripe pure unit21件、既存Auth Emulator15件、専用Apple Auth／Firestore Emulator19件の計**719件PASS**。Apple Emulatorは合成provider subject・seed UID・公開／非公開メール形・2回目プロフィール欠落・新空UIDの拒否・本番Rulesによる別UID読取／billing書込拒否・ログアウトを確認した。Popupは明示stubで、実Apple OAuth・暗号state／nonce・iOSとWebの実UID一致の代用ではない。同一メールの自動linkは制約の観測であり、防止の成功ではない。既存Auth Emulatorは専用Task2 projectへ再起動して15件PASS。初回9失敗はTask7 default projectにTask2 fixtureを接続した環境不一致で、コード差分の失敗と区別する。
- **静的・Preview**：LP84／account124／brand163の計**371件PASS**、strict TypeScript／`git diff --check` PASS。既存同channelのPreview version **`354b4f1c6ac4c40f`**、期限 **2026-11-22 11:43 JST**。公開34ファイルのSHA／安全ヘッダー一致・除外6経路404を確認。live version `2365135bf558c278`・Firebase Apple Provider／Auth project configの前後hash一致、既存57Functionsの状態／更新日時不変を最終照合した。本人のMac解除後、Safari Responsive Design Modeの360×844／390×844で実スクリーンショットを開き、無効Appleボタン・設定待ち説明の文字切れ／横はみ出しがないことを確認した。物理iOS Safariや実OAuthの成功とは区別する。元アプリのdirty10件／全2,120行のstatusを開始時に保存・維持し、Flutter／署名／ストア・本番Stripe／契約／課金権限を変更しない。
- **未確認・停止**：native iOS↔Webの実UID一致、実Appleのメール公開／非公開・再認証・取消・実state／nonce、Apple経由の契約／Portal往復は未確認。実Appleログイン・新規本番Auth作成・本番Firestore／Stripe書込みは今回実行していない。PLA／Macロック待ちは解消した。残る設定はService ID新規登録・既存Primaryとの関連付け・固定ドメイン／Return URL・既存秘密鍵の安全な利用確認とFirebase Web設定、必要なメール中継送信元登録であり、既存設定の削除・置換や鍵の無断再発行は行わない。UI準備を全要件完了へ読み替えず、1コミット後に本人設定と安全方式判断を待つ。
<!-- hamcare-web-first-task7-20261115:end -->

<!-- hamcare-web-first-task6-20261115:start -->
## 2026-11-15 戦略C・タスク6：Preview用Customer Portal（a2e73511ecef・本人承認済み）

本人のタスク7指示で `a2e73511ecef` を承認済み。以下はタスク6実施時の検証・制約の履歴であり、最新の作業・停止点は先頭のタスク7節を優先する。

- **承認・範囲**：本人承認済みタスク5 `283a8114e524` を起点に、同じ `feature/web-first-stripe-checkout`／専用worktreeでタスク6だけを実装。LP・Firebase Web認証・プラン確認・Embedded・Preview Webhook／billing同期を維持し、本人ログインからTest契約の支払方法・請求履歴・期間末解約を管理する。今回分を `feat(web): add subscription management portal` の1コミットへ保存後停止し、次工程は本人承認後とする。コミットの成立・ハッシュはGit履歴と完了報告で確認する。
- **専用設定・機能**：Test ModeにPreview専用Portal Configurationを作成。支払方法更新・請求履歴・期間末解約・任意の標準6理由を有効化し、customer update（メール・氏名・電話・住所・税ID等）、プラン／価格／数量変更、Promotion Code、即時解約、新規契約・追加商品、pause・共有ログインを無効化した。解約はat_period_end／prorationなし。理由未回答でも実際に解約予約が成立することを確認。共有の事業者名・ロゴ・色等は本番保護のため変更せず、専用headline・Privacy・規約だけを設定した。
- **Function・UID認可**：別名 `createPreviewStripeCustomerPortalSession` を追加。Admin検証済みID Token・メール確認・本人UIDから隔離対応表とTest Customerを解決し、最新Subscription・Price・専用Configuration・Webhook設定を再照合する。本文は空objectだけ、Customer／Subscription ID・UID・メール・任意return URLは受け取らない。正常管理対象はtrialing／active／past_due等に限定し、未契約・取得不能・別UID・Live Customerは拒否。Task4のUID未保存の終端履歴2件は、同Customer・scope・subject hash・Priceが一致しUIDフィールド自体がない場合だけ読み取り許容し、管理対象化・補完・移行はしない。
- **保存・復帰・表示**：Portal URLは毎回新規作成し、DOM／独自ストレージ／Firestore／アプリログへ保存しない。固定の同Preview `/account/?portal=return` に復帰し、ログインを維持してPreview billingを再読込み。管理カードは状態・550円月額・請求予定・解約予定・期間末・利用状態・同期時刻を示し、管理中契約から新Checkoutを作成させない。発行回数だけを隔離namespaceの専用counterへ保存し、3秒間隔・10分20回・1日80回を上限とする。ブラウザBackの復元時も待機状態を解除し、最新billingを取得する回帰条件を追加した。
- **623件の限定検証**：backend383件、frontend140件、既存policy84件、Emulator16件の計**623件PASS**。静的はLP84／account113／brand157の計**354件PASS**、strict TypeScript compile／`git diff --check` PASS。認証拒否・空UID／別UID・Test/Live・設定／戻り先・同時操作・URL非保存・quota・状態・復元・ログアウト等を検証し、既存依存・SDKは更新していない。
- **本人Webの実操作**：実UIDでFirebaseログイン→Portalへ進み、正常Testカードへの変更、理由未回答の期間末解約予約→期間末までの権限mirror維持→予約取消を確認。固定returnで最新billingを再読込み、Tab／EnterでPortalへ進め、ログアウト後に管理カードを隠すことを確認した。本人の本番業務4文書SHAは不変。支払方法はSubscriptionのdefaultを優先し、未設定時にCustomerのinvoice defaultを使う順序と、実Invoiceで使用された方法を照合した。カードの詳細をHamCare側へ複製せず、本番契約・体験・権限を書き換えない。
- **別Clock fixtureの実操作**：実UIDのWeb操作とは別に、Auth Emulator UIDとengineを使う専用Clock fixture2件で3D Secure・拒否・変更取消を検証。新しい支払方法が初回550円と翌月550円で使われたことを確認。失敗ケースは同じSubscriptionのpast_due→カード変更後active／550円paidへ回復し、新Checkout・重複契約を作らない。成功ケースはPortalで期間末解約予約→Clock期間終了後canceled／mirror=falseを確認した。成功側Event9件×2の重複18回、失敗側9件×2の重複14回・回復4件で、最新正本を読み直してもcanceledを維持した。
- **プラットフォームの制約**：未使用Portal URLが5分で失効することを実確認。利用開始後はStripe側で最終操作から1時間以内の期限となり、Firebaseログアウトと同時に既発行のStripe画面を失効させるAPIはない。新発行拒否・画面消去と、既に開いたStripeセッションの寿命を区別し、利用終了時にStripe画面も閉じる案内を表示した。locale=jaでも一部Billing／Reasonの英語表示があり、Stripe DOMを上書きしていない。
- **表示・未確認**：Chrome360／390／430／768／1440pxの目視で横はみ出しなし。Safari実ブラウザはdesktopと390pxのログイン画面だけを確認し、Safariの認証後Portal往復／物理Android・iOS／実スクリーンリーダーをPASSへ含めない。Portalの請求履歴では本人の0円／過去550円、成功Clockの0円／初回550円／翌月550円、失敗Clockの550円失敗→同じInvoiceの支払い済み表示を確認。Clockの将来日時は仮想時刻であり、実経過月・本番請求とは扱わない。返金／void／uncollectibleの実表示は未確認。
- **Preview・本番保護**：同じ既存Previewの最終version **`94a1f8464397f250`**、期限 **2026-11-22 10:40 JST**。追加Portal Functionと既存Preview申込Functionの2対象だけを配備しACTIVE、Task5 Webhookは再配備せずstate／updateTime不変。本番54Functions・live Hosting・Auth許可設定、保護13ファイルSHA、元アプリHEAD・dirty10件SHA・全2,120行のstatusは不変。専用Portal設定Secret1件を追加し既定runtime SAだけに権限付与、本番Stripe・Customer／Subscription・業務billing／体験／テスター権限変更0。Preview namespaceへの書込みはあるため、Firestore全体の書込み0とは記録しない。
- **観測と後始末・停止**：旧い非公開検証helperがTest用Portal／Invoice URLを一時出力したため、後続の観測器を全面マスクへ修正した。本体のserver／アプリログ・Firestore・GitへURLを保存しない検査と区別し、ツール履歴の出力も0とは主張しない。最終監査でCustomer5件を保持、Clock4件すべてready、Subscription10件すべてcanceled／有効0・open Checkout0・有効fixture0を確認。Invoiceはpaid15件（550円paid7件）／open1件で、元Task5の550円失敗証拠を保持。receipt53件は全processed、retryable／processing／error0。本人の真正イベントでsubject_busyだった2件は原bytesと新しい署名で各1回再送し200へ回復、canceled／mirror=falseを維持した。DB直接編集による回復は行っていない。main merge／push・live公開・本番課金／billing・Flutter／ストア変更は行わず、1コミット後に本人承認を待つ。
<!-- hamcare-web-first-task6-20261115:end -->

<!-- hamcare-web-first-task5-20261114:start -->
## 2026-11-14 戦略C・タスク5：Preview専用Webhook・契約状態同期（283a8114e524・本人承認済み）

本人のタスク6指示で `283a8114e524` を承認済み。以下はタスク5実施時の検証・未確認の履歴であり、最新の作業・停止点は先頭のタスク6節を優先する。

- **承認・範囲**：本人承認済みタスク4 `b94eb7a5f2c0` から、同じ `feature/web-first-stripe-checkout`／専用worktreeでタスク5だけを実装。既存LP・Web認証・プラン確認・Embedded Checkoutを維持し、Stripe Test Subscription→署名検証済みWebhook→隔離billing→Web反映確認を接続した。今回分を `feat(billing): sync preview Stripe subscriptions by Firebase UID` の独立1コミットへ保存した後に停止し、タスク6は本人承認後とする。コミットの成立・ハッシュはGit履歴と完了報告で確認する。
- **Webhook・Secret境界**：別名 `stripePreviewWebhook` と既存Preview申込Functionの専用2関数を配備済み。raw bytes・署名・署名時刻・Content-Type・Test Modeを検証し、登録先と処理対象は `checkout.session.completed`、`customer.subscription.created/updated/deleted`、`invoice.paid`、`invoice.payment_failed` の6イベントで一致させた。Test credentials／Price／Webhook設定の専用Secret3件だけを参照し、Webhook URL・署名Secret・カード情報をGit／HTML／JavaScript／Firestore／ログへ保存しない。本番Webhook・Functions・Secretを流用しない。
- **UID・保存先**：Admin検証済みFirebase UID、専用Customer対応、Customer／Subscriptionの専用metadataを照合し、メール一致を識別根拠にしない。実UID・メール・契約IDを本書へ転載しない。書込先は `preview_checkout_task4/{sha256(uid)}/billing/subscription` と同namespace内の対応／fixture／予約枠、`preview_checkout_task4/_events/events/{eventHash}` だけ。本番 `users/{uid}/billing/subscription`、体験・プロフィール・アプリ利用権限への書込みは0であり、隔離namespaceへの実書込みとは区別する。
- **最新状態・競合保護**：イベントpayloadを正本にせずTest APIから最新Customer／Subscription／Price／最新Invoiceを取得する。UID・scope・価格・数量・税／割引・元trial終了の照合後、subject／eventの期限付きleaseを検証してbillingと処理済みreceiptを原子的に保存する。再送・順序逆転・古いSubscription・API一時失敗・期限切れleaseを扱い、同一Eventの処理済み再送は再書込しない。`incomplete`／`incomplete_expired`／`trialing`／`active`／`past_due`／`unpaid`／`paused`／`canceled` を区別し、本番のpaid＋active/trialing＋有効期間内というガードをPreview表示へ反映する。past_due／unpaidに新しい猶予権限は付けない。
- **Web表示**：認証済み本人のPreview契約状態・550円月額・期間・最初／次回の請求予定・解約予定・反映時刻を表示する。成功は同じattemptのWebhook反映を確認してから表示し、反映待ち・取得不能・支払確認が必要な状態を分ける。再確認は最大6回／30秒と手動操作、ログアウト・別UIDへの切替で情報を消去する。Preview契約は本番アプリの利用権限に反映しないと明記し、Customer Portalは次タスクとして未実装、Portal Session作成0件。
- **395件の限定検証**：backend unit176件、frontend122件、既存policy84件、Firestore Emulator13件の計**395件PASS**。EmulatorにはクライアントRules拒否72ケースを含む。8状態・再送・API失敗等の合成検証と実Stripeの証拠を区別した。静的はLP84／account106／brand157の計**347件PASS**、strict TypeScript compile／`git diff --check` PASS。認証・設定・ブランドの保護11ファイルSHAは不変で、依存／SDK更新なし。
- **実Embedded・体験保護**：本人所有アカウントで実アプリtrial由来の当日0円→trialing・元終了日時一致を確認。未開始／終了済みは本人UIDに限定した明示的なPreview operator fixtureで各即時550円→activeを実Embeddedから確認した。本番trialを未開始／終了済みへ書き換えた検証ではなく、画面にもテスト用データと表示した。対象の本番業務4文書SHAは前後一致、体験延長・リセット・新21日付与なし。無効化済みfixtureは新規HTTPへ適用せず、本来のapp factsへ戻る。有効のまま期限切れになったfixtureは拒否し、Auth Emulator由来の無効化済みfixtureは遅延署名Webhookの元データ照合だけで参照できる境界を維持した。
- **実Test Clock・再送**：共有Embedded Customerと別の、専用Auth Emulator UID／Test CustomerでClockを使用。初回550円paid・翌月550円paid・期間末解約予約→canceled／権限mirror=falseを確認し、別の失敗ケースで初回550円Invoiceがopen・入金0円→past_due／mirror=falseを確認した。実unpaid到達まで確認したとは扱わない。trial_will_endはTestイベント2件を観測したが今回の権限遷移に不要なため登録対象へ増やしていない。所有する真正Event14件を逆順で2巡、計28送信してHTTP200、うち重複21回はbilling更新なし・canceledを維持。不正署名・古い署名時刻・Live flagの合成拒否は400／状態不変を確認した。
- **実表示と未確認**：Chromeの360／390／430／768／1440px、キーボードEnterによる再確認、再読込、ログアウトを確認。別UID混入防止は合成テスト／Emulatorで確認し、実アカウント2人目のログイン確認とは区別する。物理Android Chrome／iOS Safariのblur／実スクリーンリーダー等は従来どおり公開前の限定確認へ繰り越し、全実機PASSとは記録しない。
- **Preview・本番保護・後始末**：同じ[ログイン・申込Preview](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account/)の最終versionは **`bd3f9a9e5afe22f2`**、期限 **2026-11-21 21:41 JST**。既存本番54Functionsのstate／updateTime、live Hosting release SHA／version、Auth許可ドメインは不変。構成の全バイト／全SHA不変までは主張しない。元アプリHEAD・dirty10件のSHA・全2,120行のstatusは開始時と一致した。本番Stripe・本番業務billing／trial／権限の変更0、隔離namespaceには実書込みあり。後始末の実照合はTest Customer3件／Test Clock2件を保持、Subscription7件（旧Task4履歴2件を含む）はすべてcanceled、有効0・open Checkout0・有効fixture0。receipt28件はすべてprocessed、retryable／error0。Clockの真正retryable3件も再送200＋重複200・更新不変で回復した。失敗証拠の550円未払いopen Invoice1件とWebhook／専用Secretを保持する。旧取消済み2件はUIDフィールド未保存の履歴として識別し、補完・変更していない。live公開・main merge／push・Flutter／ストア変更は行わず、Task6 Portalの承認を待つ。
<!-- hamcare-web-first-task5-20261114:end -->

<!-- hamcare-web-first-task4-20261114:start -->
## 2026-11-14 戦略C・タスク4：Stripe Embedded Checkout（b94eb7a5f2c0・本人承認済み）

本人のタスク5指示で `b94eb7a5f2c0` を承認済み。以下はタスク4実施時の検証・未確認の履歴であり、最新の作業・停止点は先頭のタスク5節を優先する。

- **承認・現在地**：本人承認済みタスク3 `98f3fb8a6cd8` と既存LP／Webログイン／ブランド／プラン確認を維持し、同じ `feature/web-first-stripe-checkout`／専用worktreeでタスク4の実装・Test Preview確認を完了。本人所有の未契約・既存アカウントで実Embedded操作を確認した。開始HEADは `98f3fb8a6cd8`。本実装・検証・記録を独立1コミットへ保存し、全実機確認済みとは扱わない。保存後に停止し、次のタスク5実装は本人の別承認後とする。
- **バックエンド分離・配備**：`preview-functions/` の別codebase `hamcare-checkout-preview` と別名HTTP `createPreviewStripeCheckoutSession` を専用 `firebase.checkout-preview.json` から配備し、ACTIVEを確認。Secretは `HAMCARE_PREVIEW_STRIPE_TEST_CREDENTIALS` と `HAMCARE_PREVIEW_STRIPE_TEST_PRICE` だけを参照し、TestキーprefixとStripeオブジェクトのlivemode=falseを要求する。本人保存のcredentials有効v1を値非出力で確認済み。既定runtime SAにはこの専用Secret2件のAccessorがあり、maxInstances2／concurrency10。IAMによるFirestore完全分離とは扱わず、コードと保存先制約による分離とする。既存依存・lockを再利用し、`gcp-build`空指定とコンパイル済み4ファイル同梱により配布元外の再buildを避ける。SDK更新なし。
- **認証・保存境界**：Firebase AdminでID Tokenの失効・メール確認状態と本人UIDのserver-onlyペットプロフィールを確認。UID・メール・金額・Price／Customer ID・体験終了日をクライアント入力から採用しない。Test Customer対応・作成状態・予約枠はルート `preview_checkout_task4` だけに保存し、現在は**隔離namespace内2文書へ実書込みあり**。本番 `users/{uid}/billing/subscription`、既存プロフィール・体験・権限等の**本番業務データへの書込みは0**。同一Firestoreプロジェクト全体の書込み0とは記録しない。Client Secretは長さ制限付きTest用opaque値としてメモリ内でStripe SDKへ渡すだけで、画面・URL・ログ・独自永続化へ出さない。
- **550円と21日体験**：Test Product `prod_VcunlHPeZzngHQ`／Test Price `price_1UbexYGqALYlhFyzkAHsBm1j` は単一premium_monthly・JPY550円・月次1か月・inclusive。通常成功した2件目の実Subscriptionも同Price・数量1・月次550円、既存体験中の初回Invoice0円で一致し、Automatic Tax無効／税・割引の追加なし。次回Invoice preview550円は1件目の取消前に確認済み。Stripeのtrial_endとbilling_cycle_anchorは既存体験終了日時からのサーバー判断と一致した。体験の延長／リセット／新21日付与は行わない。秒精度への切上げは最大999ms、残り**48時間＋60秒未満は安全拒否**。未開始／終了済みの即時550円はpolicy・mockでPASSだが、本人実アカウントによるE2Eは未実施。
- **多重操作・表示**：3分の確認proof、UID単位のlease・サーバーidempotency・同一attemptの回復・状態更新時のCAS・Stripe側の既存契約／open Session再確認を実装。期限切れや結果不明を即座に別申込へ置き換えない。新Session作成予約はUID10件／日・全体100件／日で、全API呼出回数の上限とは別。Test metadataは専用scope／subject hashだけとし、既存Webhookが利用するfirebaseUid／client_reference_idを付けない。Test webhook混線時は拒否する。カード入力はStripe iframe内だけ、申込条件・サーバー請求日・成功／拒否／取消／再確認を囲むUIを用意し、タスク5のWebhook権限同期は未実装と明記する。
- **合成・限定検証**：Web **102件**、純粋policy **84件**、engine **68件**、HTTP **9件**の計 **263件PASS**。LP静的 **84/84**、account **99/99**、brand **157/157**、計 **340件PASS**。実CSSコントラスト43ケース、最小本文5.06:1・境界／focus3.09:1、strict TypeScript build／`git diff --check` PASS。policy再実行の初回はNODE_PATH未指定で既存moduleの読込みに失敗し、既存moduleを正しく指定した最終実行で84件PASS、依存追加・更新なし。合成検証と以下の実Stripe／Chrome結果を区別する。
- **実Stripe／Chrome確認**：取消→Session expired、通常のカード拒否・資金不足・期限切れカード・CVC不正、3D Secure失敗／成功、通常テストカード成功を確認。同一Test Customer1件を再利用し、最終Sessionは計4件（expired2／complete2）、Test Subscription2件を順に作成した。実二重クリックは新Session1件だけ、有効Test契約がある状態での新しいreviewは拒否。複製した2タブでも認証を保持し、同じopen Sessionを返すことを確認（1タブ目の新規操作で1件、2タブ目の追加0件）。最後のopen SessionをTest APIで明示失効させると、両タブの再確認で「支払い画面の期限が切れました」と表示し、旧iframeを残さないことを確認した。
- **限定表示と未確認**：Chromeで360／390／430／768／1440pxのStripe iframe表示と横はみ出しなしを確認。360〜768pxは100％表示、1440pxは50％拡大率でCSS viewport1440pxを確認した条件付き結果。Tabでカード番号→有効期限→CVC→名義へ移動でき、失効後の結果見出し→Tabで戻る→Enterでプラン見出しへ戻る操作もログイン保持のままPASS。物理Android Chrome／実機Safari／実スクリーンリーダーは未実施で、Safari・読み上げは一連の購入フロー完成後へ繰越し。経過時間だけによる自然失効は未実施で、実APIによる明示失効・合成テストとは区別する。
- **反映・本番保護**：競合対策を含む専用backendの最終配備はACTIVE、updateTime **2026-11-14 20:59:45 JST**を確認（cloud-final.json）。Hosting Previewの最終metadataはversion **`9332c8153d265143`**、期限 **2026-11-21 21:04 JST**へ更新。初回CLIの空version欄を推測で埋めず、実metadataで確定した。タスク3の古い「請求日を作成しません」は、次画面でサーバーが体験状態に応じたTest請求日を確認する説明へ限定修正した。最終説明文を含む公開33リソースのHTTP200・SHA／安全ヘッダー一致、6経路404、配備拒否HTTP4件PASS。既存54FunctionsのupdateTime・本番live release SHA／version `2365135bf558c278`／Auth許可設定と元アプリ作業状態は不変。追加・更新対象は専用1関数だけの計55関数。
- **実操作・後始末・停止点**：Test Product1件／Price1件、Customer1件、Session4件、Subscription2件のTest専用操作とSecret／専用backend／Hosting Preview更新を実施。試験用Subscription2件はどちらも請求・prorationなしで取消済み、有効Test契約0・open Session0、Customer1件は再利用のため保持。本番Stripe書込み0件、本番業務Firestore・既存契約・体験・権限変更0件、隔離Firestore namespaceは2文書への書込みあり。タスク4の実装・Test Preview確認は完了し、今回だけを `feat(web): add Stripe embedded checkout` の独立1コミットへ保存して停止する。コミットハッシュはGit履歴と完了報告で確認する。タスク5Webhook／権限同期は未実装で、次工程として本人承認後に進められる。本番公開判断・全実機検証の完了とはせず、main merge／push・live Hosting・本番課金／契約／Firestore billing・アプリ／ストア変更は行わない。
<!-- hamcare-web-first-task4-20261114:end -->

<!-- hamcare-web-first-task3-20261114:start -->
## 2026-11-14 戦略C・タスク3：月額プラン・申込内容の確認（98f3fb8a6cd8・本人承認済み）

本人が後続のタスク4指示で、上記コミットの実装とPreview表示を承認した。以下はタスク3実施時の検証・未確認の履歴であり、当時のChrome白画面を自動検証PASSへ変更しない。現在の作業・停止点は先頭のタスク5節を優先する。

- **承認・範囲**：本人承認済みのブランド統一 `320c726` と輪郭アイコン訂正 `57e625c` を維持し、同じ `feature/web-first-stripe-checkout`／専用worktreeで月額プラン確認だけを実装。黒背景・白い輪郭の現行アイコン、星空・ガラス表現は不変。元アプリHEAD・dirty10件の内容・未追跡2,110件を維持する。タスク4の決済接続へは進まない。
- **画面と価格**：ログイン後の「月額プランを確認する」から、毎回本人の既存3文書を再読取りして同じ画面内のプラン確認へ進む。候補は `premium_monthly` の1種類だけ、**月額550円税込／500円税抜・10％想定のPreview専用表示**。年額・割引を追加せず、実Price IDやProduct IDを送信・解決しない。ラジオ選択は画面内の仮選択のみで保存しない。契約アカウント・マスクメール・方法・保存契約／体験状態と、機能・自動更新・解約／返金等の既存条件を表示し、申込・決済ボタンは常に無効。
- **重複申込を避ける表示**：保存済み `paid`＋`active`／`trialing` は期間末解約予定も含め新規選択を止め、既存アプリの契約管理手順を案内。未知・不整合・支払い未完了・読取不能は確認優先として選択不可。文書なし／明示的none／キャンセル済みは内容確認だけを許可し、Stripe上の未契約や再契約可能とは断定しない。Customerは既存 `stripeCustomerId` の**保存参照の有無だけ**、Checkoutの進行状況は常に「未照合」。ID・保存時刻・過去履歴を最新Stripe状態の証拠にしない。権限解放・Web独自の体験期限判定・実Stripe照合は行わない。
- **料金・日時の限界**：現在の公開規約／特商法の500円税込とPreviewの550円との差を画面内で明示し、本番公開前に最終請求額と法務表示を一致させる。保存済みcurrentPeriodEndは契約期間末としてのみ表示し、正確な次回請求日時を計算・捏造しない。Price許可リスト／サーバー再照合／実決済はタスク4以降の独立範囲。
- **変更と保護**：account HTML／安全な保存状態projection／viewへ確認画面・再読取・ローカル選択・クリア処理を追加し、新 `plan-model.mjs`／`plan.css` と直接関連テストを追加。認証entry／service／公開Firebase config／Preview config／共通brand.css／account.css／LP HTML／LP CSSの**8ファイルは開始時とバイト一致**。認証プロバイダ・セッション・Rules・Functions・アプリ・署名・依存更新なし。ユーザー切替／ログアウト／再読取失敗・未確認メールで個人情報や選択を残さない。
- **限定検証**：既存認証・UIと追加プランprojection／選択テストの **Node59件PASS**。LP静的 **84/84**、アカウント **61/61**、ブランド／プラン／安全境界 **152/152**、計 **297件PASS**（実CSSコントラスト38ケース、最小本文5.06:1・境界／focus3.09:1）。構文・`git diff --check` PASS。既存Emulator15件の証拠は維持し、今回は再実行数へ加えない。
- **表示確認の未完了と繰越し**：現時点のChrome操作ツールはlocal／実Previewの双方で白一色の画面となり本文を取得できず、画面表示確認は未完了。本人へMacの表示／ロック解除確認を依頼中で、今回の7幅・200％・実プラン画面の目視PASSは先取りしない。Safari／実スクリーンリーダーは、本人指示によりEmbedded Checkoutまで一連の申込フローが完成した段階で確認する後続項目とし、タスク3のブロッカーにはしない。過去のChrome表示確認を今回の成功へ転記しない。
- **Previewと本番境界**：同じ[LP](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/)／[ログイン・プラン確認](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account/)、channel `web-first-task1`、**2026-11-14 18:19:30 JST**、version `38180b0967ad3f37`、期限 **2026-11-21 18:19 JST**。明示29リソースのHTTP200・SHA／安全ヘッダー一致、対象外5経路404。本番live version `2365135bf558c278`・公開Privacy・Auth許可ドメイン4件は不変。**本番Firestore書込み0、Stripe書込み0、Customer／Subscription／Webhook／契約・体験・権限変更0**。Previewの静的更新とは区別する。
- **停止点**：今回だけを `feat(web): add subscription plan confirmation` の独立1コミットへ保存後、本人確認まで停止する。Checkout／Portal呼出し、Functions配備、本番Hosting、アプリ／ストア変更、main merge／pushは行わない。次工程の決済接続は別の本人承認が必要。
<!-- hamcare-web-first-task3-20261114:end -->

<!-- hamcare-web-icon-correction-20261114:start -->
## 2026-11-14 戦略C・Webアイコン正本の訂正（Preview反映・表示確認済み）

- **本人の確定指定**：最新アイコンは、黒背景に白いハムスター輪郭の図案。`store_assets/icons/hamster_pencil_mark_master.png`（1254×1254px）を正本として再利用する。白い立体ハムスター＋シアン心電図の図案は今回使用しない。直前の `320c726` で両者の新旧を逆に説明した判断を訂正し、配信nativeの輪郭図案を「旧」とした説明も撤回する。
- **限定変更**：Webだけに版名を分けた `hamcare-mark-outline.png`（256px）、`favicon-outline-32.png`（32px）、`apple-touch-icon-outline.png`（180px）、`og-hamcare-outline.png`（1200×630px）を用意し、LP／ログイン・アカウント確認／favicon／Touch／OG・Twitterの参照を合わせる。アプリ素材・認証JS・Firebase設定・CSS・本番データは変更しない。撤回したWeb派生4件は非公開監査領域とGit履歴へ保持し、publicの配信対象から外した。
- **反映・確認**：同じ[Preview](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/)へ最終反映 **2026-11-14 16:47:36 JST**、version `bc548fb3fe72eaeb`、期限 **2026-11-21 16:47 JST**。LP84／account46／brand137の**静的267件PASS**、`git diff --check` PASS。元アイコン／native素材不変、OGはアイコン矩形以外の画素が前版と一致。明示27配信ファイルはHTTP200・SHA／安全ヘッダー一致、撤回した白ハムスター派生4URLを含む9除外経路404。Chrome実PreviewでLPヘッダー／favicon・ログインの輪郭図案を目視確認。認証／CSS／本番live／公開Privacy／Auth許可設定・元アプリ作業状態は維持。今回のPreview更新は説明alt訂正を含む2回、本番Firestore／Stripe書込みは0、main merge／push・タスク3は未実施。
- **停止点**：`fix(web): use current outline app icon` の独立1コミット後、本人の確認まで停止する。前回のネイビー／星空／ガラス表現と既存認証機能は維持する。
<!-- hamcare-web-icon-correction-20261114:end -->

<!-- hamcare-web-brand-20261114:start -->
## 2026-11-14 戦略C・Webブランド統一（320c726・本人承認済み）

- **範囲・保護**：タスク2の `d969c1955e2861a8eea4a3a4b5a101561532b7b3` から同じ `feature/web-first-stripe-checkout`／専用worktreeを継続。LP・ログイン・アカウント確認の見た目だけを独立1コミットにする。元アプリHEAD・dirty10件の内容・未追跡2,110件は開始時と一致。認証JS4件・公開Firebase config・Preview configの計6件はバイト一致、Flutter／Functions／Rules／依存／本番法務は変更なし。
- **デザイン正本**：`lib/theme/app_theme.dart` のThemeData／ColorScheme、Drawer・QuickRecord・FloatingNavの色／blur、`app_habitat_background.dart` の背景と `main_drawer.dart`／`screens/auth.dart` のCaveatを調査。Web共通の `public/assets/brand.css` にネイビー#181a20、surface#232635、Primary#315daf、mint/cyan#79e2dd、glass18px、24px角丸を定義。Webで読めるようガラス面と枠の不透明度を上げ、非対応時は不透明面にする。詳細トークン／対応ファイルは既存の日本公開準備書先頭へ記録した。
- **アイコン判断の訂正**：`320c726` では白い正面ハムスター＋ネイビー＋シアン心電図を現行図案と誤認し、その図案のWeb素材を整備した。後続の本人確認によりこの採用判断を取り消す。黒背景・白い輪郭の `store_assets/icons/hamster_pencil_mark_master.png` が最新の正本であり、配信nativeの輪郭図案を「旧」とした説明も撤回する。今回のWeb限定訂正は先頭節を正とし、アプリ側は変更しない。PWA manifest／Service Workerなし。
- **画面**：「静かな夜に、うちの子を見守る。」の星空・草原と控えめな発光へ統一。Homeは本人提供の実画面1000017308.jpg（テスト用プロフィール、記録待ち）をOSバーだけ除いて再利用、画面内の値やUIは変更しない。承認済みstable3種と既存の実画面4点を維持。4機能・FAQは濃いガラス面、ログインは読みやすい入力欄、アカウント確認はさらに不透明度の高い面へ。Googleボタンは公式Gを未加工で使用し、白地と標準色を維持。LPの2入口・全リンク・項目・同意／料金／体験条件は維持。
- **限定検証**：既存認証モデル／サービス／UI **34/34 PASS**、LP静的 **84/84**、アカウント静的 **46/46**、ブランド／素材／安全境界 **130/130**（計260静的、うち実CSSコントラスト28ケース）PASS。最小本文5.06:1、境界／focus3.09:1。形式・構文・`git diff --check` PASS。タスク2のEmulator15件は既存証拠を維持し、今回再実行・新規本番ログインはしない。
- **実ブラウザと限界**：Chrome DevToolsの320／360／390／430／768／1024／1440pxでLP・ログイン・確認画面の切れ／折返し／横はみ出しを目視確認。ログイン／確認の7幅比較は同じHTML/CSSと既存view moduleに架空データを与えた非公開localhost表示で、実認証成功とは区別する。同じPreview反映後のLP／ログインも表示確認し、FAQのTab→Enter展開と可視focusを確認。LP／ログインの200％拡大を確認。ヘッダーは非固定で本文を覆わない。44px領域・alt／label／見出し・role=alert／ARIA・reduced-motion／forced-colors／透過非対応fallbackはコード検査済み。実読み上げ、OS高コントラスト等の実描画、確認画面200％、Android実機Chrome／iOS Safariのblurは未確認。Mac Safariは操作ツールの起動timeoutのため確認できておらずPASSにしない。SDK map取得3件のCSP遮断は既存制限のまま維持。
- **反映・本番不変**：同じ[LP Preview](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/)／[アカウント](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account/)、channel `web-first-task1`、**2026-11-14 16:25:38 JST**、version `c1b4a97c5eff76c0`、期限 **2026-11-21 16:25 JST**。明示27ファイルはHTTP200・SHA一致・noindex／nosniff／no-referrer、account no-store PASS（Hosting合計29はFirebase自動init2件を含む）。内部出典台帳・旧billing／Privacy・ローカル表示fixtureは404。本番live version `2365135bf558c278`・公開Privacy・Auth許可ドメイン4件は反映前後で不変。**本番Firestore書込み0、Stripe書込み0、契約／体験／権限変更0**。静的Preview更新1件とは区別する。
- **停止点**：本人のデザイン確認待ち。タスク3の独自月額プラン確認・Checkoutは未着手。main merge／push・本番Hosting・ストア・アプリ変更は行わない。Safari等の未確認を公開前の確認として残す。最新Apple回答と戦略Cの制約は下記タスク1節を維持する。
<!-- hamcare-web-brand-20261114:end -->

<!-- hamcare-web-first-task2-20261114:start -->
## 2026-11-14 戦略C・タスク2：Webログイン（Preview確認済み・本人承認待ち）

- **開始・保護**：本人承認済みタスク1 `98e4b204e05a` を起点に、既存の `feature/web-first-stripe-checkout`／専用worktreeを継続。元アプリ作業ツリーのHEAD・dirty10件・未追跡2,110件は維持し、main merge／push・アプリ変更・依存更新なし。今回のログインだけを `feat(web): add Firebase account sign-in` の1コミットで保存して停止する。
- **登録・公開範囲**：作成直前にWebアプリ0件を再確認し、同じFirebaseプロジェクトへ **HamCare Webを1件**登録。Analyticsは追加しない。Auth許可ドメインは既存3件を保持し、正確な `hamster-breeding-app--web-first-task1-lco08m60.web.app` **1件だけ追加**。その他Auth設定は不変。Preview終了後にはこの一時ドメインだけを削除する必要がある。
- **実装**：既存LPの会員CTAから `/account/` へ進む。メール／パスワードとGoogle Popupを既存Firebase Authへ接続。メール新規登録・自動リンク・統合は実装しない。未確認メールでは本人情報読取りと次画面を遮断し、確認／パスワード再設定は既存アプリの手順を案内。Apple Webログインは未対応。標準 `browserSessionPersistence`、ログアウト、表示切替、日本語エラー、連打防止、ユーザー切替／ログアウト後の遅延レスポンス破棄を実装。SDKは既存と同じ12.17.1固定、Firestore Liteによるサーバー読取り、独自token保存・Analytics・Functions呼出しなし。
- **本人確認画面**：本人UID直下の `owner_profiles/main.displayName`、`billing/subscription`、`feature_access/initial_trial_v2` の3文書だけを取得。ニックネーム／マスクメール／登録済みログイン方法／契約保存状態と期間末／体験保存状態と終了日時を表示し、文書なしと取得不能を分ける。実Previewではニックネーム・マスクメール・方法・契約記録を表示、体験文書は「開始記録なし」、取得不能項目なし。保存済みstatusは現在の権限判定と同一とは限らないため、Web独自の期限判定・権限解放は行わず、実利用可否は既存アプリで確認する。「月額プランを確認する」は準備中表示だけで、Checkoutを作成しない。
- **Googleの注意**：未登録Googleでの初回ログインはFirebase Authが新UIDを作成し得る。Firebase標準の信頼済みプロバイダ処理で同メールの既存アカウントへ連携される場合もあり、衝突が必ずエラーになるとは扱わない。アプリ独自のメール照合／UID統合はない。今回の本人Google確認は同じ既存プロフィール・契約記録を表示し、新規ユーザー警告なし。将来の新規Auth作成では既存 `analyticsAccountRegistered` の登録イベント書込みが発生し得るため、将来の全Google利用までFirestore書込み0とは保証しない。今回、新規ユーザーの本番試験はしていない。
- **限定検証**：モデル／サービス／UI **34件PASS**、Auth＋Firestore Emulatorと現行Rules **15件PASS**（既存／誤入力／未確認・確認済み／Google新規・既存・衝突／本人3文書・別UID拒否／billing・体験書込み拒否／ログアウト）。LP静的 **73/73**、ログイン安全境界 **43/43**、構文・`git diff --check` PASS。Chrome実Previewで本人メールとGoogle成功、再読込保持、別タブ／終了後の再ログイン要求、ログアウト消去、Google Popupを閉じた日本語案内、準備中画面、LP入口、360／390／768／1440px・Tab／Space可視フォーカス・表示切替・空入力エラーを確認。エラー通知のrole/ARIAは確認したが実読み上げは未確認。実機Android Chrome／iOS Safariは未確認、Mac Safari起動確認は操作ツールのtimeoutで未完了。DevToolsの3エラーはSDK source mapの取得を狭いCSPが遮断したもので、認証／読取りの失敗ではなく個人情報も含まない。CSPを広げて消していない。
- **Previewと本番境界**：[Webログイン](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account/)、同じ `web-first-task1` channelへ **2026-11-14 15:39:11 JST**反映、期限 **2026-11-21 15:39 JST**、version `ba068e9852825333`。静的LPの通信禁止を維持し、ログイン経路だけ必要なFirebase／Google接続を許可、no-store／noindex／no-referrerを付与。本番live version `2365135bf558c278`・公開Privacyは不変。**本実装・実Preview確認による本番Firestore書込み0（Emulatorの合成データを除く）、Stripe書込み0、本番Functions課金呼出し0、契約／体験／権限／Firestoreプロフィール変更0**。Web登録1・許可ドメイン追加1・Preview反映1・本人Authログインは許可された別操作として区別する。
- **次工程・停止**：本人承認後のタスク3は独自の月額プラン確認画面。Stripe／Webhook／Portal／本番billing・アプリCTA変更へは進まない。Apple WebログインのService ID／Return URL等とモバイル実ブラウザ確認は公開前の残件。Apple回答・戦略Cの最新扱いは下記タスク1節を維持し、事前承認済みとはしない。
<!-- hamcare-web-first-task2-20261114:end -->

<!-- hamcare-web-first-task1-20261114:start -->
## 2026-11-14 戦略C・タスク1：公式ランディングページ（98e4b204e05a・本人承認済み）

- **範囲と保護**：本人指定の `feature/web-first-stripe-checkout` を、開始HEAD `f696b24663a2a03d7d55385f16a70cd6bcc8ee2c` からクリーンなworktreeに作成。元作業ツリーのdirty10件・未追跡2,110件・元HEADは維持し、コピー／stash／reset／clean／混在コミットなし。今回のタスク1だけを1コミットで保存し、タスク2へは本人承認後に進む。main merge／pushなし。
- **実装**：`public/index.html` と専用CSSで「HamCareを試す」「有料会員について」の2入口、4機能の実画面、21日体験、FAQ、正式Google Playリンクを実装。Androidは登録済み日本Alphaテスター限定、iOS一般公開は準備中と明示。ログイン・申込・決済は未実装、申込CTAはdisabled。月額1種類だけ、550円税込／500円税抜は10%想定のPreview表示で、既存の本番Price・契約を変更しない。
- **素材**：採用済みstable3種（syrian/golden、djungarian/normal、roborovski/normal）、既存アプリアイコン、Caveat＋OFL、公開フォーム用の実画面4点を再利用。新規AI送信・画面捏造・アバター再生成なし。画像の出典／SHA／表示例／個人情報目視確認は `public/assets/landing/provenance.json`。4画面は以前の公開用抜粋で、最新build5を撮り直したものではない。
- **Preview**：[確認ページ](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/)。既存Hostingの別channel `web-first-task1` へ2026-11-14 14:58:32 JSTに反映、期限2026-11-21 14:58 JST。Preview version `6987069cc164351e`。`firebase.preview.json` のみ使用し、`--no-authorized-domains`、Functions／rewrites／ログイン／Stripe SDKなし。法務リンクは現在の公開URLへ向け、古い法務・billingページと内部素材台帳はPreview配信から除外、OFLはフォントと一緒に配信する。
- **限定検証**：標準ライブラリの `tools/check_web_landing.py` は71/71 PASS、安全境界を崩す合成設定5ケースは5/5拒否PASS。Chromeレスポンシブ表示で360／390／768／1440pxの冒頭・画像と文章の折返しを目視、390pxで実画面4点を順に確認、360pxで料金／申込不可表示を確認。FAQはTab→Enterで展開、Spaceで折りたたみと可視フォーカスPASS。主要操作領域はCSSで44px以上を設定。CSSのreduced-motion／alt／見出し階層も確認。実機Safari／Androidブラウザ・支援技術の全組合せは未検証。アプリE2E／Flutter全体再試験は今回対象外。
- **配信・本番不変**：PreviewのHTML／CSS／画像8点／フォント／OFL計12リソースはHTTP200・SHA一致・CSP／noindex／nosniff／no-referrer PASS。除外3経路は404。本番live version `2365135bf558c278` と11/12のrelease、公開PrivacyのSHA、Auth許可ドメイン3件は反映前後で不変。本番Hosting反映・Firestore書込み・Functions配備・Stripe操作・既存契約／テスター権限変更は**0件**。同じFirebaseプロジェクト内のPreview channel／静的コンテンツ反映は**1件**であり、プロジェクト全体の書込み0件とは区別する。
- **確定方針と残り**：Firebase UIDを契約主体とし、将来のWebログイン／独自プラン確認／Stripe Embedded Checkout／テスト専用billing同期／Portalは後続タスク。年額・Pricing Table・Apple Webログイン・アプリCTA／Deep Link変更・本番税込550円課金は未実装／未実施。本人からの最新Apple回答共有は「Case22954972：独立Web購入は日本の代替決済条件の対象外」「Case103009817213：事前承認せず実際の提出で判断」。回答待ちへ戻さず、戦略CのApple承認済みとも扱わない。以下の旧日付節は当時の記録であり、本節の最新状態を優先する。
<!-- hamcare-web-first-task1-20261114:end -->

<!-- hamcare-ui-polish-release5-20261109:start -->
## 2026-11-09 微修正反映版code5／build5（Play未送信2変更・build5内部Testing）

- **対象と保護**：固定ソースは `402737048c36b0e592475c764fe05a25abf0454b`。既存専用ブランチと成功済みFlutter／Xcode／署名手順を再利用し、dirty／未追跡素材はビルドへ混入させない。アプリID・Bundle ID・署名鍵・依存lock・88アバターを維持。旧code3／build3以前の互換P1は本人の要件変更による非ブロッキングで閉じたまま、部分保存はcode4／build4以降の正規仕様。新たな旧版互換実装、サーバー配備、main merge／push、外部テスター追加・招待・連絡、製品版公開は行わない。Apple Case103009817213の回答待ち／決済判断保留を維持する。
- **修正・限定証拠**：「Ham Care」表記とログイン同様の手書き書体、Home／クイック記録のアバター拡大・背景統一、選択中ペットのhappy完了アバターと黄色いぼかし、体重時期未選択→不明、レポート準備中の選択中ペットアバターを含む。直接関連114件PASS／既存ListTile診断2件FAIL、新規失敗0、ぼかし描画17件PASS、analyze既存57件・新規0を引き継ぐ。今回のストア名原稿の完全一致を含むrelease identity追加確認は6件PASS。完了済みAI／認証／課金／DeviceCheck等の再試験、実AI送信・体験リセットは0。
- **Android成果物とAlpha最終送信待ち**：`1.0.1／code5`、`hamcare-1.0.1-code5-ui-polish-signed.aab`（172,392,335bytes、SHA-256 `49d8019de8d3cf44bdd09c72515cc95d9908d5cc5bb58aeb276042617f651171`）を生成・既存upload署名検証済み。88PNG／Caveatの含有と整合PASS。既存Alphaの `5 (1.0.1) UI polish Alpha` へ同AABをアップロードして保存済み、日本のみ・既存internal-testers本人1名を再読確認。掲載名を含む最終2変更について、自動操作での最終確認に加え、本人から「押した」との回答を受領。その後、公開の概要と送信履歴を読込み完了後に再読したが、Consoleは **未送信2変更**、送信履歴はID1〜3だけのまま。新しい送信ID・送信受付日時・送信成功は未確認。エラー表示はなく、**本人操作後も受付未確認・原因未特定** と記録する。残る操作はConsole受付の再確認と、承認済み2変更の送信のみ。**審査送信済み・審査中・code5のAlpha公開・端末更新PASSとは扱わない。**
- **iOS成果物と内部配信**：`1.0.1／build5`、`hamcare-1.0.1-build5-ui-polish-appstore.ipa`（135,534,552bytes、SHA-256 `9e00e9a12c7f706e3b9199367dc9c0a4ef831527d528189c4065cebe1e019cd8`）を既存Distribution署名／App Store Profileで生成・検証PASS。codesign strict／ZIP、get-task-allow=false、88PNG／Caveatの含有・整合を確認済み。同IPAはTransporterで **2026-11-09 11:09 JSTにDelivery完了**、ASC処理完了後のMissing Complianceを確認。本人が従来同値の「Apple OS以外にも標準暗号を使用／独自暗号なし／フランス配布なし」の最終保存を明示承認した後にSaveし、既存 **本人実機確認グループの1 Tester／4 Buildsで1.0.1(5) Testing・90日** を確認した。外部テスター追加・App Store製品版審査提出は0。**端末4→5更新・ログイン／既存データ保持の本人確認は未実施**。
- **ストア表示名**：本人の追加指定により両ストアの掲載名原稿を正確に `Ham Care` へ同期し、既存のtitle／name txtと掲載情報文書を更新。App Store ConnectとGoogle Playの日本語名はいずれも `Ham Care` で保存した表示を確認済み。Playは本人操作後も掲載名を含む2変更が未送信で、送信受付は未確認・原因未特定。保存と審査送信・公開反映を区別する。iOS build5の内部Testingは、App Store製品版の公開を意味しない。説明本文・画像・課金方式・IDは変更しない。
- **保存先と状態の区別**：成果物と非公開監査は `/Users/gota/hamcare-deploy-staging/pre-optin-release5-20261109/`。AAB／IPAの生成、アップロード、審査送信、テスト配信可能、端末更新・ログイン／データ保持の本人確認を分ける。以下のRC4およびローカルDebug確認は前版・各確認時点の履歴であり、release5の配信済みや実機PASSへ転記しない。
<!-- hamcare-ui-polish-release5-20261109:end -->

<!-- hamcare-pre-optin-rc4-cutover-20261108:start -->
## 2026-11-09 本人限定RC4の利用確認PASS・旧版互換P1は非ブロッキング

- **候補固定・保護**：承認済み7コミットにP1条件だけの独立文書コミット `f5f09c2b65536022f0d75e140de757610b691ef2` を追加し、このSHAをRCとした。クリーンなdetached worktreeから隔離ビルドコピーと関数別反映パッケージを作成。main／GitHub mainは0055e93ed003のまま、旧originはローカル旧repoであることを区別。既存フォーム差分・iOSローカル設定・未追跡素材は保持し、候補へ混入させない。
- **サーバー反映**：指定健康consumer6件とpersonalityDailyReportsを先行反映。各現配備ソースを基準に今回の直接必要な3共有module（personalityは1）だけを重ね、全Functions反映・無関係な新機能を避けた。配備ソース・lock一致、Ready／新revision100%、環境変数・資源・上限・IAM保持を確認。personalityの旧named revision pinとCLIによるScheduler呼出先変更は勝手にrollbackせず本人へ報告し、追加承認の2操作だけで00009-wajへ100%切替・元の呼出URLと実効設定へ復元した。頻度・時刻・retry・codeは変更せず、API既定値のaudience／User-Agent明示化だけを区別して記録。手動Scheduler実行0。
- **旧完全入力の互換ゲート**：指定テストアカウントでiPhone build3とAndroid code3専用AVDの正規保存・再読込・Homeを確認。Raw→Silver→Gold history/latest更新・AI文脈metadata生成・通知処理完了、対象ERROR0・通知送信／失敗0を照合。その後saveDailyCheckinだけを00001-zuv→00002-gimへ反映（ソース23件・lock・設定／IAM一致、Ready／100%）。新writerでも旧code3の完全入力1件を正規保存し、互換26/26項目PASS。別distance-trigger1件は日次保存と分離し、数値経路の反映・調査へ広げていない。実AI送信0。
- **バックアップ・新部分記録ゲート**：本人が追加承認したテストアカウント7対象だけを非公開退避。global照合も別途承認された入力版／部分markerのmetadataと件数だけを保持。writer直前の新部分記録0を確認。現在日のbaseline履歴・Raw／ledger／event／revision整合をID非保存で確認し、正規取消が旧記録を消さないことの確認条件を準備。新部分記録0件は配備前後のmetadata照合時点の証拠として保持し、現在件数や全実機ケースのPASSを意味しない。P1の現在の扱いは下記11/9の本人決定を正とする。
- **ビルド作成済み**：番号4未使用をConsole全履歴で確認し、既存成功環境から両OSを生成・署名・検証PASS。Androidは `hamcare-1.0.1-code4-pre-optin-signed.aab`（172,244,527bytes、SHA256 f3344659dee8cbcbae51702d0f8d12d2a1c343c59b19ca5376525a7aad675ace）、iOSは `hamcare-1.0.1-build4-pre-optin-appstore.ipa`（135,394,372bytes、SHA256 0fd38f47cca2db05db924130d22d33c2aa6198eeb4708f098192a7fbec5711e0）。保存先は既存stagingのpre-optin-rc4-20261108/artifacts。既存Upload／Distribution署名・App ID・Team、正式88PNG、manifest／AOT、RC968 tracked sourceとlock／SDK／旧成果物の保全PASS。clean候補へ未追跡の説明用analysis_preparing画像を含めなかった差を正式88枚の欠損と混同しない。
- **ストア送信・配信**：同AABをuploadし、既存Alpha release4/code4だけの1変更を2026-11-08 21:31 JSTに審査送信（送信ID3）。同日22:39 JSTに「公開」となったことを11/9の公式送信詳細で1変更・日時表示とともに再読確認し、審査待ちは終了。日本のみ・既存本人1名・管理対象公開off、製品版／他track／テスターリスト変更0。Alpha公開と実端末の導入・更新は区別する。SamsungのPlay新規導入後のログイン・記録・動作は11/9本人PASS、AVDの正式旧版更新保持は未確認。同IPAはTransporterで同日21:28 JST Delivery Complete、ASC処理完了。本人が追加承認した既存同値の輸出申告を保存し、既存内部本人1名グループへbuild4を追加、groupでTestingを確認。外部group／tester追加とApp Store製品版審査提出0。
- **本人端末の確認済み範囲**：iPhoneはTestFlight build3→build4更新、再ログインなしHome・既存プロフィール・飼育記録保持が本人PASS。ハムケア見出し／分析準備アバター／クイック記録アバターの3点も表示問題なしと本人PASS。ニックネームの保存・設定表示・完全終了後の保持も本人PASS。変更／空欄解除の追加実操作は本人が不要と指定し未実施、stored trimのDB実値照合は未確認で、既存serialization testとUI表示証拠に分離する。追加の本人確認を要求しない。
- **Androidの受取経路**：既存Play専用AVDはcode3とPlay署名DA77・導入元Play、Linux UID／初回導入日時／dataDir・88PNG/AOTの更新前基準を保存。Chrome規約は本人が操作。正式Alpha参加URLのBecome a testerからYou are testerへ遷移し、表示アカウントの本人一致を値非保存で確認。内部URLはAccept inviteで未受諾、Store表示はInternal Early AccessからEarly Accessへ変わった。テスターリスト変更・内部track変更・削除は0で、内部退出操作を行ったとは断定しない。code4は11/8 22:39 JSTにAlpha公開済み。専用AVDの正式3→4更新は未実施で、Samsungへの新規導入とは別の更新保持確認として残す。
- **所有環境と本人確認**：Samsung SM-S911Nの削除前アプリはローカル署名code2でPlay署名と非互換。別Android実機はない。11/8は旧アプリを本人が閉じ主process0を確認して維持していたが、11/9に本人がこのローカル版1件の削除を追加許可。端末内の未同期データ・ログイン状態を失い再ログインが必要になることを説明済みで、08:37 JSTにcom.gotainu.hamsterだけをADB公式uninstallしSuccess／pm path消失を確認した。従来の削除禁止はこの1件に限り解除し、クラウドの飼育記録・体験・利用権限の削除／リセット、鍵変更、新APK生成は0。Play版code4の新規導入後の正常ログイン・記録・動作は11/9の本人報告でPASS。新規導入を上書き更新・ログイン保持PASSとは扱わない。他AVD2台は停止、Simulator保存55構成はShutdown、Play専用AVDの正式3→4更新保持は未確認。iPhoneはbuild4への正式更新・保持確認PASS。旧版互換をリリース要件から外す本人決定により、残る旧環境の一斉更新をP1のブロッカーにはしない。
- **検証・現在の判断**：RC由来コピーのFake Clock16件PASS、物理時計変更0。既存統合監査のFlutter800PASS／共通25FAIL、Functions824PASS／既存4FAIL、analyze main／HEAD57件・追加0を引き継ぎ、全体PASSと表記しない。Android実機の正常ログイン・記録・動作は本人確認PASSとして引き継ぐ。部分8ケース・iPhone部分保存・新部分に対するRaw／Silver／Gold／AI文脈／通知の個別実測は未実施で、全ケースPASSとは記録しない。本人は現状を成功と判断し、P1旧reader互換は下記の要件変更で非ブロッキングとして閉じる。追加の旧版互換実装・全環境切替確認・同じ本人確認の反復は不要。外部約15名は未招待で、案内対象はcode4のみ。今回main merge／push・外部連絡・製品版公開は行わず、Apple Case103009817213の決済判断は回答待ちを維持する。
- **証拠・非公開境界**：既存stagingのpre-optin-rc4-20261108/auditへGit開始状態・配備前後設定／ソース・限定metadata・ビルド前提を保存。メール／UID／本文／token／鍵／秘密値を本書やGitへ転記しない。下記の過去の「実行前」「未配備」は各確認時点の履歴として保持する。
- **審査待ち間の旧AVD停止**：11/8 22:09 JSTに専用AVDの旧HamCare code3だけをforce-stopし、主process0／package stopped=trueを確認。userdata・既存ログイン／記録・Playアプリは削除／変更せず保持。配信後の正式更新確認まで旧アプリを起動しない。Samsungの本人終了・他AVD／Simulator停止と区別して記録し、正式Android更新や部分保存PASSを意味しない。
- **停止前の入力版照合**：11/8 22:04:56 JST開始の承認済みmetadata再照合で、新partial／未回答marker／condition:nullは全対象0、全走査件数一致。本文・UID・メール保存0、データ変更0。
- **11/9の導入状況・本人確認**：Samsungローカル版は本人の追加許可で08:37 JSTに削除済み。公式Play Webの遠隔導入はGoogle再本人確認前で未成立のため中止し、本人スマホの公式Playページからの導入を案内した。その後、本人から正常ログイン・記録・動作に問題なしとの報告を受領し、Play code4の新規導入後の利用を本人確認PASSとする。これは旧code3→code4の上書き更新・ログイン保持試験ではない。AVDは公式PlayのUpdateを1回選択したが、最終読取の08:49 JST時点はcode3であり、正式3→4更新保持は未確認のまま。追加の手動確認や再テストは要求しない。
- **2026-11-09の確定方針・P1クローズ**：本人は旧code3／build3以前を実運用しておらず重要なユーザーデータもないとして、旧版後方互換性を今回のリリース要件から外した。新しい部分保存をcode4／build4以降の正規仕様とし、P1の旧クライアント誤読は要件変更に基づく非ブロッキングとして閉じる。コード上の完全後方互換を実装・検証した意味ではない。旧版互換の追加実装・二段階配布・強制更新機構は不要。外部テスターへの案内対象はcode4のみで、今回の方針決定自体では招待・メール送信・対象拡大を実施しない。以下の過去の一斉切替ゲートより本決定を優先する。
- **部分保存の仕様と確認範囲**：code4／build4以降の部分保存を正規仕様とする。本番の新部分記録0件は11/8 22:04:56 JSTのmetadata照合時点の結果で、現在件数の再照会は行わない。個別の部分保存8ケース・新部分に対するRaw／Silver／Gold／AI文脈／通知の実測は未実施のまま区別する。本人の正常ログイン・記録・動作確認を受領したことを、これら全ケースのPASSへ読み替えない。旧版の全環境切替や完全後方互換を追加のリリース条件にはしない。
- **表示調整完了（ソースのみ）**：端末のAndroid／iOSアプリ表示名・Flutter title・ドロワー名を「Ham Care」へ統一。Home本体のアバターを190→224px、分析準備を108→128px（compact88→104px）、クイック記録3画像を44→58pxに拡大した。クイック記録は既存52px枠で軽微な見切れを許容し、Resolver／状態対応／fallback／タップ動作は維持。既存関連テスト66件PASS、実Widget合成描画4件（320／390px・明暗）PASS、Drawerとクイック記録の実Widget描画も目視確認。端末でこの表示変更を確認したという意味ではない。flutter analyzeはmain基準と同じ既存57件（新規0）、git diff --check・iOS plist形式PASS。過去の固定fontによるGolden全体再実行・期待画像更新は行わない。描画・ログは `/private/tmp/hamcare-display-polish-20261109/` と同名接頭辞のログへ保存。配信済みcode4／build4・署名・成果物・版番号は変更せず、新ビルド／upload／配信、main merge／pushは行っていない。次回配布で表示修正を取り込む場合は、新しい未使用build番号を使用し、配信済み4を差し替えない。
- **11/9のローカル表示確認用起動**：追加の本人依頼により、320c6d7の名称／サイズ修正6ファイルだけを成功済みAndroidビルド環境の新規一時コピーへ重ね、提出物とは別のローカルDebug APKを生成。専用AVD `HamCare_Display_Preview_20261109`（emulator-5556）へ新規導入し、表示名Ham Care・MainActivity起動Status ok・ログイン画面を確認した。旧Play用AVD／Samsung／iPhone・配布済みcode4/build4・元の署名設定と版番号は保持。専用AVDはログイン前で、Home／拡大アバターの本人操作確認はまだ行っていない。ログイン・AI送信・記録保存・課金・Store uploadは代行せず、APKと起動記録は `/private/tmp/hamcare-display-preview-runtime-20261109/` に分離。専用ブランチのソース・mainは変更せず、本行だけを既存進捗へ未コミット追記。
<!-- hamcare-pre-optin-rc4-cutover-20261108:end -->

<!-- hamcare-display-five-polish-20261109:start -->
## 2026-11-09 追加微修正5点完了（実装・ローカル検証時点の記録）

- **体重保存**：測定時期を選ばない場合も、有効な体重だけで保存可能。既存の `unknownMeasurementTiming`（precision／confirmationともunknown）を明示し、対象日は保持する。選択済みの時期・保存済み時刻・訂正・legacy本人確認・pending同一再送は維持。既存Repo／サーバーは同形式を受理しており変更不要。
- **限定検証と既存失敗**：直接関連8ファイルのテストは114件PASS、既存のListTile／DecoratedBox診断2件FAIL（旧記録の本人確認・狭幅操作）。両失敗は前回main／HEADにも同一の診断で存在し、今回由来の失敗0。新規の未選択→不明・不正体重の保存禁止・既存測定時期保持・同一再送はPASS。実アカウントの体重保存、評価／通知／AI／課金の変更、Store反映は0。
- **クイック記録**：3アイコン枠の背景／境界線を既存の中立なすりガラス調Surfaceへ統一し、種類別の画像・58px表示・タップ／遷移は維持。保存完了は選択中ペットのhappyアバター（欠損時は同外見stable→既存安全表示）へ変更。円形の塗り・枠・切抜きを除き、黄色のぼかしshadowだけを維持。完了中のペット切替も合成ストリームで確認した。
- **ドロワー書体**：文字列「Ham Care」と副題は維持し、ログインと同じCaveat・700へ統一。既存google_fonts 6.3.2が使う同一BoldファイルをGoogle公式配布から取得し、SHA一致を検証してOFLとともに同梱。依存更新なし。ネットワーク取得を禁止したDrawerテストでも実フォントの読込・320／390px明暗・文字1.3倍・6遷移・非切れをPASS確認。
- **うちの子レポート**：「うちの子らしさを集めています」の肉球を、選択中ペットのinsufficient_dataアバターへ変更。同外見stableと安全表示の既存fallback、ペット／owner切替を確認し、レポート生成・履歴・A3処理は維持。将来の頬袋アセットは制作せず、種類・毛色・状態キーを追加しない。
- **検証・実行境界**：今回由来の失敗0、flutter analyzeは前回mainと同じ57件（新規0）。既存8ファイルの114PASS／既存2FAILに加え、実際のぼかしで再描画したクイック記録17件もPASS。git diff --check PASS。確認画像とログは `/private/tmp/hamcare-polish-five-20261109/`。未選択の体重は既存の不明形式として扱い、サーバー／重み・閾値・通知・権限・課金・Auth／App Check／DeviceCheckは変更しない。
- **エミュレータ反映**：成功済み一時コピーでローカルDebug APKを更新ビルド。専用AVD `HamCare_Display_Preview_20261109`（emulator-5556）の既存APKと署名一致を確認してinstall -rがSuccess、MainActivity起動Status ok。初回導入時刻09:50:15とデータ領域を保持し、再ログインなしで既存ペットのHome表示を10:32に観測した。初回UID比較はAndroid項目名appIdをuserIdとして読んだため未成立で、UIDの前後完全比較PASSとは記録しない。実記録の追加保存・AI送信・同意操作は0。既存Play用AVD・Samsung・iPhone・配布済みcode4/build4／提出用成果物・署名設定・版番号は変更せず、Store upload・tester連絡・main merge／pushは0。5点の本人操作による最終確認はこれからとする。
<!-- hamcare-display-five-polish-20261109:end -->

<!-- hamcare-pre-optin-audit-c-final-20261108:start -->
## 2026-11-08 統合再監査の残件C確定（一斉切替で対応可能・実行前）

- **最新の配信対象**：11/8 19:30〜19:34 JSTにConsoleを読み取り。Play既存Alphaは1.0.1／code3有効、internal-testers選択は本人1名だけ。ダッシュボードの実opt-inは0人。TestFlightの全テスターは本人のInternal1名だけ、本人実機確認グループにbuild2／build3があり、本人端末は1.0.1(3) Installed。外部グループ・外部テスターは0、外部テストは未開始。Playリスト確認ダイアログは何も編集せず閉じ、保存ボタン無効を確認。配信設定変更・招待・送信は0。
- **本人の事実確認**：約15名の応募者を含め、本人以外へAlpha参加リンク／TestFlight招待／旧版を提供していないとの回答を受領。応募者は現Alpha許可リストにも含まれず、opt-in前。本人所有の全環境をcode4／build4へ更新し旧版で開かないよう管理でき、ほかの端末・共有環境はないとの回答も受領。更新できるという確認であり、実更新済みとは記録しない。
- **本番データの最終照合**：11/8 19:32:58 JST開始のread-only再照合でも、daily_checkins全23件、observation_days全2件、観察revision4件／event3件／receipt4件の新partial_v1・部分回答／未回答マーカー・明示condition:nullは0。件数と全投影走査が一致し打切り0。旧writer未配備変更なしの既存確認を維持し、本文・メール・UID・tokenを本書へ保存せず、本番書込み0。
- **P1判定**：旧版利用者は開発者本人だけ、外部応募者はopt-in前、本番に新部分記録0、全所有環境を更新・管理可能という4条件が揃ったため、**「外部公開前の計画的一斉切替で対応可能」**。旧readerが未回答をnormalとして読むコード上の非互換は残り、完全な後方互換・実切替済み・P1コード修正完了とは扱わない。
- **必須の実行ゲート**：外部案内を止め、旧code2等も含む全所有reader環境を対象にする。将来の別指示で健康consumer群とpersonalityDailyReportsを先に、saveDailyCheckinを最後に反映。部分記録生成前だけに現行legacy入力互換を確認し、その後は旧版を停止。全所有環境の新reader更新・データ保持と旧版停止を実確認してから、最初の新部分保存を行う。確認後に外部案内へ進む。Play署名版／ローカル署名版は各既存署名を維持し、署名差を削除・data clearで解消しない。部分記録生成後は旧reader／旧consumerへの一括rollbackをせず、新欠損保護を保持する。
- **対象環境**：Samsung SM-S911N、保存Android AVD3台（HamCare_Play_20261101／HamCare_Prelaunch_A_20261004／Pixel_7_API_34）、iPhone17e、保存iOS Simulator4台。今回は起動・インストール版照合・更新を行わず、未使用環境にも旧版を起動させない管理を含める。
- **修正・再監査の確定結果**：Aは3abfbd710d9c、Bはc58628e15289の2コミットを維持。A新16件とB指定2ファイル全24件PASS。最終HEADの全Flutter800PASS／mainと共通25FAIL・HEAD追加失敗0、Functions824PASS／既存fixture4FAIL、TypeScript build／noEmitとRules内部52件PASS、analyzeはmain／HEADとも57件・追加0、git diff --check PASS。全体PASSとは表記せず、既存環境／fixture失敗を分離する。今回、完了済みテストの再実行は0。
- **現在の判断と保護**：今回差分由来の失敗・新規要修正は0で、上の切替ゲートを条件に監査上mainへマージ可能と判定する。ただし実行承認は別で、main merge／push、server deploy、code4／build4、Store upload、端末更新、tester案内は今回行わない。既存5＋新2コミットは変更せず、今回の確認結果は本節を未ステージ・未コミットで追記する。既存フォーム文書差分・iOSローカル設定・未追跡素材を保持し、新しい独立管理表は作らない。
<!-- hamcare-pre-optin-audit-c-final-20261108:end -->

<!-- hamcare-pre-optin-audit-fix-b-20261108:start -->
## 2026-11-08 統合監査の残件B完了・C事実確認中（未配布／再監査へ）

- **旧UIテスト7件の更新**：care_action_input_testの2件とobservation_identity_ui_testの5件だけを、新しい部分保存契約へ合わせた。全空保存不可、未操作ケアの省略、単独の総合状態で保存可能、観察タイミング入力不要とunknown表現、未選択項目のnormal／false／0非補完を確認する。旧date-only履歴の訂正、訂正と新規観察の明示区別、pendingの完全同一リクエスト再送、取消／replay後の旧メモ・選択解除を保持・強化。削除／skip／本体変更は0。
- **限定検証**：指定2ファイル全24件PASS・skip0、2テストファイルの解析指摘0、git diff --check PASS。Aのコミット3abfbd710d9cを先行し、本節とテスト2ファイルだけを別コミットにする。この後、修正後の全Flutter／main解析比較・サーバー全テスト等を統合再監査し、既存環境失敗と差分由来失敗を区別して別途報告する。単独PASSを全体PASSへ読み替えない。
- **P1の本番事実**：11/8 18:53 JSTに本番daily_checkins全23件・observation_days全2件・関連する全観察revision4件／event3件／receipt4件の入力版と必要メタデータを読取照合。新daily_checkin_partial_v1／部分回答マーカー／明示condition:nullは0。配備済みsaveDailyCheckinは10/13更新の旧history_v1で、新部分writer未配備。本文・メール・UID・tokenは本節へ記録せず、本番書込み0。Playダッシュボードの現在opt-inは0、Alpha code3有効を読取確認した。
- **P1判定は未確定**：既存記録ではAlpha許可登録本人1名・TestFlight内部本人1名／外部テストなし。今回のPlay許可リスト行が表示されず、TestFlightも再サインイン待ちのため、古い人数を最新確認値と扱わない。本人以外への案内／旧版提供の有無、応募者の未登録、全所有端末の更新・旧版停止可否を本人確認中。Samsung実機、保存Android AVD3台、iPhone17e、保存iOS Simulator4台等は旧reader潜在対象。全条件が揃うまで「一斉切替可能」「完全後方互換」「P1解消」とは記録しない。
- **範囲**：既存5コミット・main・開始時の3ファイルdirty差分と未追跡素材を保持。main merge／push、server deploy、code4／build4、Store upload、端末更新、応募者案内は0。今回の本番情報・ローカル端末一覧・詳細監査は非公開一時領域へ保持し、新しい管理表は作らない。
<!-- hamcare-pre-optin-audit-fix-b-20261108:end -->

<!-- hamcare-pre-optin-audit-fix-a-20261108:start -->
## 2026-11-08 統合監査の残件A完了（日付跨ぎの確認・未反映）

- **限定修正**：当日として開いた新規の「今日の様子」／ケアは、保存前に端末ローカル日付の変化を検知して保存を止める。案内を承認した場合だけ、未保存の総合状態・選択項目・メモ・ケアを保持して今日へ切替。対象日を画面に表示し、切替と同時には保存せず、内容を確認した次の保存操作で新日付へ送る。キャンセルでは対象日も下書きも維持する。局所now注入で確認し、端末の時計は変更しない。
- **既存記録の保護**：明示過去日、訂正・取消・durable pending再送は元の日付／識別子を維持。当日既存ケアに新規健康記録を加える場合や既存健康記録から新しい観察を選ぶ場合も、保存intentで判別する。元日の確定ケアを新日へ複製しない。移動先に既存記録／pending／未確認・別subjectがある場合、旧日訂正と新規入力が混在する場合は、保存も日付変更もせず下書きを保護。確認・読込中だけカード内の追加操作を止める。
- **検証**：新規16件＋直接関連の既存52件＝68件PASS。承認／取消、メモ・選択保持、別日の既存記録・pending保護、訂正／新規／ケア混在、再送同一性、再保存先と既存カレンダー部品への合成受理日反映を確認。390pxの実Widget描画2枚を開き、日付と案内の非切れを目視確認（実機／本番カレンダーE2Eではない）。flutter analyzeは既存57件・新規指摘0、git diff --check PASS。
- **保存境界**：本体1ファイル・専用新テスト1ファイル・本節だけを専用ブランチの1コミットにする。開始時のフォーム文書差分、iOSローカル設定、未追跡素材は保持し除外。次にBの旧UIテスト7件を別コミットで更新し、Cの実配信範囲確認とDの全体再監査へ進む。P1の旧版reader互換性は未解消で、一斉切替可能とはまだ判定しない。本番・端末・配布版・SDK／依存・署名の変更、main merge／push、code4／build4生成は0。
<!-- hamcare-pre-optin-audit-fix-a-20261108:end -->

<!-- hamcare-pre-optin-task5-20261108:start -->
## 2026-11-08 オプトイン前の微修正・タスク5完了（今日の様子の部分保存／全件承認待ち）

- **開始と保護**：本人のタスク5着手指示を受領。`codex/pre-optin-polish-20261108`、開始HEAD `db3d9e227856aa855c35b9ffc5248b505bd3f1d1`、開始status・既存3,074ファイルのSHAをローカル監査へ保存。既存フォーム文書差分・iOSローカル設定・未追跡素材を保持し、今回のコミットから除外する。配布記録／pubspecのAndroid `1.0.1／code3`・TestFlight `1.0.1／build3`は維持し、Console再確認・SDK／依存更新・新ビルドは0。
- **原因と保存契約の限定修正**：旧フォームは総合状態と観察タイミングを必須とし、保存時に未操作のケアを「なし／0分」へ確定、サーバーは未選択の観察項目へnormalを自動補完していた。新入力だけ`daily_checkin_partial_v1`で識別し、総合状態／気になる項目／メモ／ケアを独立して保存可能にする。完全空・空白メモのみはUI／VM／サーバーで拒否。新規の観察時期は既存unknown表現で日時を捏造せず、時期の選択欄は非表示。旧履歴の訂正／新観察の区別と保存済みタイミングは保持する。
- **未回答と後方互換**：総合状態欠落はnull、選択タグだけ既存のchanged／concerningの意味を持たせ、他項目をnormalへ埋めない。メモはtrimし空文字を回答に数えない。未操作ケアは未回答表示・新リクエストでは省略し、明示的に選んだ「なし／0分」と区別する（サーバー内部の既存unanswered表現は維持）。旧`history_v1`の完全入力／履歴／timing／未送信リクエスト・pending再送の内容とfingerprintを維持し、既存データの移行・一括更新・履歴消去は0。nullの総合状態をnormalやhasConcernへ誤変換せず、明示concernタグ／levelsはconcernとして保持する。
- **Silver／Gold・通知の境界**：既存Evaluatorはnull／insufficientDataに対応済みのため、重み・閾値・スコア設計は変更しない。メモだけのRawは保存するがSilverの健康回答ありに数えず、Goldは未入力／score:null。項目だけの明示concernは従来の評価経路で扱い、全体未回答フラグを付与する。既存のcondition通知を欠損や未回答だけで「解消」へ進めない局所guardを追加し、この不足フラグ自体を新規incidentにしない。他domainの通知判定・実通知送信・過去のGold再計算は0。Homeは従来のGold読込を維持し、AI文脈の既存整形は未入力を未入力と表すためコード変更不要。
- **限定検証**：Flutterは重複を除く関連75件PASS（新model／VM／Repo15＋既存identity／care Repo23＋部分保存の実Widget13＋既存入力／care24）。総合3状態だけ・掃除だけ・散歩だけ・食欲／排泄だけ・メモだけ・複数の一部・全空・0／normal非補完・旧完全入力／timing・pending再送・ケア／健康の独立保存を合成Storeで確認。Functionsは新16＋既存30＝46件PASS、Raw履歴／projectionのメモリ内整合・Silver／Goldの欠損評価・新旧再送・欠損時の新規／解消通知抑止・旧評価値の同値を確認し、`tsc --noEmit`PASS。既存RAG formatterをAST抽出した4件で未入力をnormalとしてAIへ渡さないことを確認（実AI要求0・外部RAGソース変更0）。
- **目視と解析**：実カードを既存Theme／実アセットで390px明色・320px暗色に描画して画像を開き、観察タイミング欄なし、未回答表示、項目選択、スクロール・保存までの操作を限定確認。実機／ネイティブIMEは未確認。既存UIテストの画面外tapだけはスクロール前提に修正し、期待値を弱めない。最終`flutter analyze --no-pub`は既存57件（warning39／info18・error0）で終了1、前タスクの診断とmessage／path／code照合で追加0。変更Flutter6ソースの解析は指摘0、`git diff --check`PASS。Nodeは壊れた旧Homebrew実体を更新せず、既存nvm Node22.23.1を明示して実行した。Functions生成lib・既存SDK／lock／署名は不変。
- **コミット・反映待ち**：本タスクのFlutter6ソース・Functions4ソース・関連5テスト・本節のみを、指定メッセージで専用ブランチへ1コミット。モデル／入力／評価欠損の直接範囲だけで、課金・認証・App Check／DeviceCheck・アバター・利用権限・飼育実データ・本番Functions／Firestore／通知／AIは変更0。新入力版はサーバー側受理対応を必要とするため、将来の承認済み反映時はFunctions対応を先に適用してからアプリ更新する。今回はデプロイ／main merge・push／code4・build4／アップロード／テスター案内を行わず、本人のタスク5完了承認と、全5件の差分レビュー等への別指示を待って停止する。
<!-- hamcare-pre-optin-task5-20261108:end -->

<!-- hamcare-pre-optin-task4-20261108:start -->
## 2026-11-08 オプトイン前の微修正・タスク4完了（任意ニックネーム／停止）

- **開始状態・範囲**：本人のタスク4指示を受領し、`codex/pre-optin-polish-20261108`、開始HEAD `847ce4cb3cff2d10e7153cc2531ee68c30b9b2de`を継承。開始status・既存3,073ファイルのSHAをローカル監査へ保存。既存フォーム2文書の差分、iOSローカル設定、未追跡素材は保持し今回コミットから除外する。既存配布記録／pubspecのAndroid `1.0.1／code3`・TestFlight `1.0.1／build3`を維持し、Console再照会・新ビルドは0。
- **既存保存経路と最小追加**：OwnerProfileには表示名が未定義だったため、任意の`displayName`を追加。`users/{uid}/owner_profiles/main`と既存`merge:true`保存を再利用し、読込／保存ともtrim、空欄はnull＝未設定とする。既存4項目・未知の既存フィールドを維持し、未設定ユーザーの移行・一括更新は不要。既存Rulesはこのフィールドを許容するためRules／Functions／Firebase Auth.displayNameは変更0。
- **画面とユーザー分離**：飼い主プロフィールに「ニックネーム（任意）」の読込・編集・解除・保存を既存のカード／Themeで追加。設定アカウント欄は設定済みなら主表示＝ニックネーム・副表示＝従来のメール、未設定／読込エラーなら従来のアカウント＋メール表示。設定を開き直すと最新値を再読込する。UID変更時は表示Stateを作り直し、Repoを作成時UIDへ束縛、古い編集画面から別UIDへの保存を拒否し、遅延fetchも別UIDへ返さない。
- **限定17件PASS**：合成ユーザーとメモリ内FlutterFireだけでtrim／空欄／既存・不正型読込、保存→更新→解除→Repo再生成、mergeと既存4項目・未知フィールド保持、UID隔離・未ログイン／古い画面save拒否・遅延fetch排除、実Editor操作、実Settings反映とUI全再生成、未設定fallback、320／390px×明暗・文字1.3倍を検証。HTTP／RPC／Auth更新を禁止し、本番・飼育記録・通常権限への変更は0。永続性は合成保存データを保ったUI／Repo再生成の確認で、実機再起動ではない。
- **目視・既存警告の切分け**：実Widgetの編集画面1枚と設定4枚を保存して実際に開き、任意ラベル・名前／メールの優先順・折返し・非切れを確認。ネイティブIME／実機は未確認。初回のテスト側スクロール不足は限定テストだけで修正。新SDKが既存Settings ListTileへ出す装飾／ink警告は変更前HEADの画面でも同一再現し、この固定診断だけをテストで記録、その他の例外は失敗判定を維持した。既存ListTileの改修やSDK変更へ広げない。
- **解析・完了境界**：既存Flutter3.47.7の最終`flutter analyze --no-pub`は既存57件（warning39／info18・error0）により終了1。前タスクの診断とmessage／path／codeを照合し追加・解消とも0、タスク4テストへの指摘0。`git diff --check`PASS。モデル・Repo・編集画面・設定・限定テスト・本節だけを指定メッセージで専用ブランチへ1コミット。既存dirty差分・mainを維持し、merge／push・code4／build4・アップロード・配信・本番変更は0。タスク5のRaw／Silver／Gold／Home／AI／通知は未着手とし、タスク4完了報告後に停止する。
<!-- hamcare-pre-optin-task4-20261108:end -->

<!-- hamcare-pre-optin-task3-20261108:start -->
## 2026-11-08 オプトイン前の微修正・タスク3完了（クイック記録3アバター／停止）

- **承認・開始状態**：本人のタスク2完了承認とタスク3着手指示を受領。`codex/pre-optin-polish-20261108`、開始HEAD `e14c388c719f37edbaf5c830e1e592027ddf13f2`を引継ぎ、ブランチ再作成・上書きは0。開始statusと既存3,072ファイルのSHAをローカル監査へ保存。既存フォーム文書差分、iOSローカル設定、未追跡制作素材は保持し、今回コミットへ混ぜない。配布記録と`pubspec.yaml`のAndroid `1.0.1／code3`・TestFlight `1.0.1／build3`を維持し、Console再照会・新ビルドは行わない。
- **最小修正**：QuickRecordSheet内で既存`PetProfileRepo.watchMainPet()`のstreamを一度作成し、従来のPaidFeatureGate配下のカテゴリ一覧だけで現在ペットを購読する。3画像は既存Appearance／Asset Resolver・HamsterAvatarViewを再利用し、走った記録=`activity_high`、今日の様子=`happy`、体重=`stable`。装飾用の静止画像であり、健康／活動状態の判定は追加しない。Widgetへアバターのファイルパスを直接記載せず、プロフィール・識別子・共有Resolver／モデル／Theme／画像は変更0。
- **枠・フォールバック**：既存52px角丸枠・枠線・色・レイアウトを維持。枠線1pxと内部余白3pxを除いた44pxでBoxFit.containを使い、耳・足が切れないよう表示する。指定状態が欠損した場合は同じ外見のstable、その先は既存petsアイコン。外見情報不足／読取エラーは元の各Icon／ブランドマークへ戻し、異なる種類・毛色で代用しない。
- **限定16件PASS**：シリアンdark・ジャンガリアンsapphire・ロボnormal／白黒piedの各3実PNG decode・状態対応、開いたままのmain_pet種類／毛色／subject更新、未登録／legacy／空毛色、状態欠損→同色stable、未制作white_face／全欠損時の安全表示、既存3入力画面→戻る、openAllRecords返値、既存有料gateを確認。既存オフラインbackendを再利用し、RPC要求0と合成documentsの前後一致を各ケースで検証。保存・購入・体験開始・同意操作・本番データ変更は0。
- **目視・解析**：同じテストで任意保存した実Widgetの4画面（320／390px、明暗、4外見）を実際に開き、文字・アバター・余白・切れなしを確認。実機試験ではない。既存Flutter3.47.7の`flutter analyze --no-pub`は既存57件（warning39／info18・error0）で終了1、全所在ファイルの開始SHA一致を照合。変更2ファイルの解析は指摘0、`git diff --check`はPASS。旧Golden・タスク1／2の完了済み確認は再実行しない。
- **完了・停止**：クイック記録本体・専用限定テスト・本節だけを専用ブランチへ指定メッセージで1コミット。タップ・閉じる／戻る・入力／保存／報酬・有料gate・Tabs入口・認証／課金／AI／DeviceCheck／App Check／署名／SDK／lock／アセットを維持。mainへのmerge／push・code4／build4作成・アップロード・配信は0。タスク3完了報告後、本人の次の明示指示まで停止する。
<!-- hamcare-pre-optin-task3-20261108:end -->

<!-- hamcare-pre-optin-task2-20261108:start -->
## 2026-11-08 オプトイン前の微修正・タスク2完了（分析準備アバター／タスク3未着手）

- **承認・開始状態**：本人のタスク1完了承認と「タスク2だけ進める」を受領。`codex/pre-optin-polish-20261108`、開始HEAD `6e9df65e4e9b42cbd609f3ca2cabe5eb6065ffe6`を引継ぎ、同名ブランチの再作成・上書きは0。開始statusと既存3,072ファイルのSHAをローカル監査へ記録。既存フォーム文書差分、iOSローカル設定、未追跡素材は保持・今回コミットから除外する。配布記録と`pubspec.yaml`のAndroid `1.0.1／code3`・TestFlight `1.0.1／build3`を維持し、Console再照会・新ビルドは行わない。
- **原因と最小修正**：Homeはすでに`PetProfileRepo.watchMainPet()`の現在プロフィールを購読していたが、分析準備カードへ渡さずThemeの固定画像を表示していた。既存`main_pet` snapshotをカードへ1引数で渡し、既存Appearance／Condition／Asset ResolverとHamsterAvatarViewを再利用する。準備中のConditionは既存resolverのassessment不足分岐で`insufficient_data`とし、健康評価やサーバーの準備完了判定を変更しない。
- **画像の順序と互換性**：同じ種類・毛色の`insufficient_data`→同外見`stable`→現行Themeの汎用画像。種類・毛色が未登録の既存プロフィールは推測して書き換えず汎用表示、全候補欠損時は既存petsアイコンまで安全に表示する。候補欠損の実テストで、旧Imageエラーを次候補の読込中にも再利用してstableを飛ばすことを再現したため、共有ViewのImageへ`ValueKey(path)`を1行追加して解消した。Resolver・モデル・画像88枚・Theme／枠108／88px・BoxFit・進捗文言・既存CTAは維持。
- **限定テスト27件PASS**：カード既存／追加25件（シリアンdark・ジャンガリアンsapphire・ロボnormal／白黒piedの実PNG decode、プロフィール／毛色情報欠落、欠損fallback順、同一Widgetの外見変更、準備完了表示・既存ボタン等）＋Homeの現在ペット／毛色更新と解除に追従するオフライン1件＋共有Viewの既存終端fallback1件。全て合成データとメモリ内backendのみで、本番アクセス・飼育記録／権限変更・実AI送信は0。
- **目視・解析**：実Card＋既存PNGを合成readinessで6ケース描画し、シリアンdark／ジャンガリアンsapphire／ロボnormal／pied／毛色なし／未制作white_faceを実際に開いて確認。描画6件PASS、画像の切れ・表示例外なし。実機確認ではない。既存SDK Flutter3.47.7の`flutter analyze --no-pub`は既存57件（warning39／info18・error0）で終了1だが、全所在ファイルの開始SHA一致を確認。変更5ファイルの解析は指摘0、`git diff --check`はPASS。旧Golden／固定font期待値は変更・再実行しない。
- **停止範囲**：タスク2だけを専用ブランチへ1コミット。PROJECT_STATUSの既存フォーム関連差分は部分ステージで除外し、mainへのmerge／push・code4／build4作成・アップロード・配信は0。クイック記録・認証／課金／AI／App Check／DeviceCheck／署名／SDK／lock／既存アセットを変更しない。タスク3は未着手で、本人の完了承認と次の着手指示まで停止する。
<!-- hamcare-pre-optin-task2-20261108:end -->

<!-- hamcare-pre-optin-task1-20261108:start -->
## 2026-11-08 オプトイン前の微修正・タスク1完了（ドロワー見出し／次タスクは停止）

- **開始状態と専用ブランチ**：開始は`main`、HEAD `0055e93ed003514217c95bd747389c7245c97b8b`。同名ブランチがないことと既存ステージ差分0を確認し、このHEADから`codex/pre-optin-polish-20261108`を作成した。開始時の`git status --short`と保護対象3,072ファイルのSHAはローカル監査へ保存。既存のフォーム関連2文書、iOSローカル設定（CLIENT_ID／REVERSED_CLIENT_ID）、未追跡の制作素材等は保持し、今回のコミットへ混ぜない。
- **現行配布版の引継ぎ**：既存提出・配信記録と`pubspec.yaml`の`1.0.1+3`を照合し、Android既存Alpha `1.0.1／code3`、iOS TestFlight `1.0.1／build3`を維持。今回はConsoleの再照会・版変更・code4／build4作成・アップロード・配信を行わない。
- **最小変更**：`lib/widgets/main_drawer.dart`のサービス名1文字列だけを`Hamster Project`→`ハムケア`へ変更。依頼中の具体的な実装・テスト条件の日本語表記を採用した。共通NotoSans／既存titleLarge・21px・w900・色・余白・1行表示を維持。認証画面にあるCaveatは欧文専用のため日本語へ移さず、新フォント・依存関係・Theme変更は0。ペット名由来の副題、プロフィール画像、既存6項目と選択先、他画面のHamCare表記、アプリ名／署名／ID／Firebase設定は変更しない。
- **限定検証5件PASS**：既存のオフラインWidgetハーネスを再利用。合成プロフィールの「いぶきの記録と管理」を保ったまま、320／390px×明暗・文字1.3倍の4ケースで実Drawerを開き、日本語見出しと副題の非切れ・枠内表示を検証。既存6項目のタップ先、旧見出し消失、既存TextStyle維持、メモリDB書込み0を1ケースで確認。生成した4画面を実際に開いて目視確認した。実機・本番データ・認証／AI／課金／DeviceCheckの再試験ではない。
- **解析・既存検査の扱い**：`flutter analyze --no-pub`は既存57件（warning39／info18、error0）により終了1。全57件の所在ファイルは開始SHAと一致し、今回の変更2ファイルだけの解析は指摘0。`git diff --check`はPASS。旧Goldenの準備はOS標準日本語フォントの固定SHA不一致で停止したため、期待画像・共通helper・固定値は変更せず、現在Macの既存フォントをテスト内だけで読み込んで上記レイアウトを確認した。
- **完了範囲**：本体1行・直接関係する既存テスト・本節とブランチ表示だけを専用ブランチへ1コミットとする。既存フォーム文書差分は部分ステージで除外する。実データ変更・秘密情報の追加・mainへのmerge／push・他タスク着手は0。本人が次タスクを明示するまで停止する。
<!-- hamcare-pre-optin-task1-20261108:end -->

<!-- hamcare-closed-recruitment-20261102:start -->
## 2026-11-02 クローズドテスト募集素材・フォーム公開完了（未投稿・REL-02）

- **今回のConsole実測**：既存Alpha 1.0.1／code3は有効、11/1 18:47 JST公開・日本のみ1国を維持。Alphaの許可リストinternal-testersは登録1名だが、11/2のダッシュボード表示は「現在、0人のテスターがオプトイン」「12人以上／14日」で、製品版アクセス申請ボタンは無効。登録数1と実opt-in0は別値で、10/25の古い0人表示を流用したものではない。今回の申請・人数／日数達成は0。正式Alpha参加URLと同packageのStore詳細を実画面で確認し、参加URLは従来どおり個別案内で管理する。
- **募集素材と方針**：既存google_play_closed_test_plan_ja.mdへ、X先行／不足時YouTubeの未投稿文、採用後案内・正式参加手順、2週間に数回の利用、6問の応募／フィードバック、個人情報を保存しない段階別管理を整備。目標20〜30名、日本在住・18歳以上・Android7以降・現在飼育中優先。毎日起動・毎日記録・AI送信・購入は必須にしない。通常21日体験を利用し、カード不要・体験終了だけで自動課金なし・最大20件と既承認の有限共有枠を維持。各人20回答保証・体験延長／枠reset・新beta権限は用意しない。AI共有残枠は未照会で、必要時に確認し増額は別承認とする。
- **保存・公開済み実フォーム2件**：保存可能な既存の本人アカウントで応募／フィードバックを応募6問（5必須・1任意）／フィードバック6問（3必須・3任意）で作成・保存済み。Drive保存名は「HamCare Androidクローズドテスト｜応募受付」「HamCare Androidクローズドテスト｜参加報告・アンケート」。編集者・回答閲覧は本人1名だけ、結果概要共有OFF、Googleログイン強制なし。応募ではPlay用Googleメールを専用設問で手入力し、許可リスト登録・選考／参加案内・必要連絡という用途を明記。フィードバックは参加ID方式でメールを再収集しない。全設問・必須表示をpreviewで照合し、応募メールの形式検証UI・customエラー文も保存確認。preview送信が無効のため送信試験は未実施で、架空回答作成0・両フォーム0回答を維持。実体はDrive保存名と既存非公開staging監査closed-recruitment-20261102/preparation-result.json／確認画像3件で管理し、監査と編集用URL・応募者情報・回答内容・個人とIDの対応表はGit／Markdownへ保存しない。
- **公開・回答受付PASS**：本人が「2フォームの公開・回答受付開始」を追加明示承認後、2026-11-02 13:32 JSTに両フォームを実公開。公開UIと作成者以外の回答画面で入力可能・Submit表示を確認した。応募回答用URLは https://forms.gle/d3G4JSmycuZgPpBy8、フィードバックは https://forms.gle/5H5xNQYg3cYWJNcp6。前者だけをX／YouTubeの募集原稿へ差し込み、後者は採用後の個別案内用とする。回答者はリンクを知る全員、編集／回答閲覧は本人のみ・概要共有OFF・Googleログイン強制なしを維持。送信テスト0・現0回答で、応募や参加実績はない。
- **承認経緯・未実施範囲**：当初は自動承認レビューが公開を下書き作成の許可とは別として拒否し、公開せず本人へ確認した。その後の本人追加明示承認で解消した経緯を保持する。下書き保存の記録65959d7は書き換えず、実公開結果を後続docsコミットへ分ける。募集文とフォームは、本人がX募集投稿を出せば応募受付できる状態。X／YouTube投稿・個別招待・Playリスト追加や配信設定変更は今回0のまま。フォーム公開を募集投稿／採用／opt-in達成へ読み替えない。
- **非公開管理・保持方針**：既存Privacy／サポート公開ページと連絡先を確認し、フォームにも記載。個別回答・連絡情報・ID対応表はテストと製品版アクセス申請への対応終了後90日以内に削除し、匿名化改善メモだけ残す。公開Gitへ実応募者の連絡先や個別参加履歴を加えない。今回の0回答を実応募・採用実績へ読み替えない。
- **共用リストの注意**：内部track code2も同じinternal-testers登録1名を選択していることを11/2に確認。新規募集者をその共用リストへ追加すると内部配信にも及ぶため、将来は既存Alphaだけへ新募集用専用メールリストを追加し、既存本人1名と内部配信を維持する案を推奨。これは未設定の案で、募集内容の本人確認と別途承認後に実施する。今回Consoleの設定変更・保存・送信・tester追加・個別招待・X／YouTube投稿は全て0。
- **正本・保護**：既存REL-02のタスク行と既存計画／Play手順書を更新し、新しい管理ファイルは作らない。code3／build3の配信・端末確認・88枚・限定12件PASS、Apple Case103009817213回答待ちは維持。コード・署名・SDK・ビルド・通常権限・本番データ／課金は変更しない。ローカル設定2件、生成原画・旧候補を保持し、応募情報を含まない既存3文書だけをGit保存し、原画・非公開監査／画面・編集リンクを除外して通常pushする。公開証拠は同じ非公開staging監査のpublication-result.jsonと確認画面に保持する。
<!-- hamcare-closed-recruitment-20261102:end -->

<!-- hamcare-github-avatar3-20261101:start -->
## 2026-11-01 code3／build3関連成果のGitHub main反映

- 既存mainとgithub/mainの分岐なしをfetchで確認し、通常pushを実施。`815a8da`（Pied選択・旧プロフィール互換／関連test）、`0be653f`（採用アバター標準88枚・pubspec＋3／台帳／限定確認）、`bce646e`（既存タスク表と提出手順へAlpha code3審査中・TestFlight build3内部配信／本人確認の結果）の3コミットを反映した。初回push後、リモートmainの`bce646e5d64873545ed396b82e6370912965de43`とローカルHEADの一致を確認。最後の保存記録コミットはGit履歴を参照する。
- 新規追跡は本番PNG73枚（既存15枚と合わせ標準88枚）と必要なコード・関連テスト・小さい匿名検証結果・制作台帳・既存管理文書に限定。追加テキストの秘密情報／個人メール候補0、追加PNGの私的メタデータ0。旧原画・不採用候補・巨大な比較画像・署名AAB／IPA・非公開Store画面はGitへ加えない。
- 既存ローカル設定のios/Runner/GoogleService-Info.plist、tools/analytics/output/bigquery-connection-result.json、未採用ダルメシアン説明画像と未追跡の制作領域は、そのままローカルに保持。削除・reset／clean／stash・強制push・branch／upstream変更なし。これらの除外ファイルがあるため、作業ツリー全体をcleanとは記録しない。
- Git保存を配信／審査通過の証拠と混同しない。Alpha code3は送信ID2の18:47 JST公開を確認済み。TestFlight build3は既存本人1名Testing・本人更新保持／Pied／white_face代替表示PASS。Android専用AVDの正式Play2→3配送・データ領域継続と現code3利用／Pied再表示はPASS、更新をまたぐ再ログイン不要は未確認という下記の実状態を維持する。
<!-- hamcare-github-avatar3-20261101:end -->

<!-- hamcare-test-distribution3-20261101:start -->
## 2026-11-01 code3／build3の承認済みテスト配信（REL-02／REL-03／AVT-06）

- **今回の承認・再利用**：既存Alphaのcode3審査送信と、既存TestFlight本人向け内部グループのbuild3配信を本人承認。指定済み署名AAB／Distribution IPAのSHAは前回候補と一致。88PNG含有・内容一致と限定12件PASSを引き継ぎ、再ビルド・再署名・既存E2E／AI／Auth／課金／DeviceCheckの再実行は0。
- **Google Play upload／保存**：既存Alpha（track4700032976627342279）に指定署名済AAB code3を1回upload。Consoleで3(1.0.1)／API24以上／target36を確認し、新release3「3 (1.0.1) avatars88 Alpha」を保存。前回の署名整合結果・登録Upload証明書との一致を引継ぎ、Console受理時の署名エラー0。日本のみ1国、既存internal-testersリスト1名、管理対象公開オフを読取確認し変更しない。内部トラック・製品版・署名鍵・テスター範囲は変更0。
- **Google審査・Alpha公開**：未送信はAlpha code3「完全公開を開始」の1変更だけと照合し、2026-11-01 18:19 JSTに送信（送信ID2）。送信詳細で当初の審査中を確認後、同日18:47 JST「公開」へ更新されたことを公式画面で読取確認した。1変更／既存Alpha／release3だけが対象で、日本・既存internal-testers1名を維持。code3の審査通過・Alphaテスト配信可能を確認済みだが、製品版の一般公開ではない。旧送信ID1・14変更とcode2公開の履歴も保持。
- **Apple upload／処理／内部配信**：指定IPAを既存Transporterからデリバリし、Transporter表示は11/1 17:44成功。ASC既存アプリ6826783734で1.0.1(3)の処理完了を確認。前版と同じ暗号申告（OS外標準暗号あり・独自暗号なし・フランス配布なし）を保存し、Missing Complianceを解消。既存「本人実機確認」Internal Groupの1Tester・自動追加なし（Manual for Xcode Builds）を読取確認後、build3を追加。18:24 JST確認時点で1Tester／2Builds、build3と既存build2はともにTesting。本人のTestFlightから更新可能。外部招待・App Store一般審査は0。
- **iOS端末更新**：本人が既存TestFlightから1.0.1(2)→1.0.1(3)へ削除なし更新し、再ログインなしのHome・既存プロフィール・飼育記録保持をPASS報告。変更許可のある検証用プロフィールでロボロフスキー／パイド保存→再表示、白黒アバターと毛色保持も本人PASS。white_faceの既存代替表示が正常との本人回答も受領し、保存せず元パイドを維持した。全8状態の実機切替は未実施で、既存ローカル12PASSと分離する。
- **Androidの導入経路・更新PASS**：普段使い実AndroidにはPlay版未導入。旧専用VMは現存しないため、既存SDKのAPI34 Google Play ARM64を使う新しい独立AVD HamCare_Play_20261101を永続stagingへ準備した（追加SDK0、既存AVD114ファイル不変）。最初のcode2は保存済みConsole取得のPlay署名Universal APKを新規直接導入したもので、Playストア新規取得・旧VM復元ではない。その後の最小観測でcode3を確認し、installer／initiatingともcom.android.vending・導入4APK全てDA77署名、code2基準からLinux UID／firstInstallTime／dataDir一致を確認。固定code3 AABとarm64 AOTを含むnative3件・標準88PNGが全SHA一致、mismatch0。正式Play配送による2→3更新とデータ領域の継続はPASSで、直接APKのcode3上書きは行っていない。
- **Android本人確認・限界**：本人が通常ログインし、現code3のHome・既存プロフィール・飼育記録表示を確認。変更許可のある検証用プロフィールでロボロフスキー／パイド保存→再表示と白黒アバター・毛色保持も本人PASS。指示前にすでにcode3へ更新されており、手動／自動の操作主体は未確定。code2でログイン済みだった基準と時系列は確定していないため、更新をまたぐ「再ログイン不要・記録保持」の厳密PASSへ読み替えず、現code3の通常利用・既存データ閲覧PASSと区別する。結果は新専用AVDのもので、普段使い実Androidの2→3保持確認ではない。既存アプリ削除・データ消去・downgrade・追加AI／体験／課金操作は0。Android white_faceと両OS全8状態の新端末切替は未確認だが、既存ローカル12PASSを維持し、追加の強制状態試験・本人操作は今回要求しない。証拠は既存staging/android-play-verification-20261101/audit/code3-play-runtime-verification-20261101.json（11/1 20:15 JST）。
- **Git保存範囲**：今回のPied必要コード／関連test、標準88PNG、pubspec・checker・制作台帳／README、限定testソースと小さい検証結果を選択commit。原画・旧候補・巨大比較PNG・配布成果物・未採用説明PNGと、既存ローカル設定2件は除外保持。PROJECT_STATUSの既存タスク表と2提出手順書も今回実状態へ更新。commit／通常pushは上のGitHub反映節のとおり完了し、リモート一致を確認した。
- **証拠**：既存stagingのandroid-ordinary-update-20261025/audit/avatar-code3-distribution-20261101/およびios-device-runtime-20261019/audit/avatar-build3-distribution-20261101/のdistribution-result.jsonとConsole／TestFlight画面。非公開の画面・アカウント情報はGitへ追加しない。新しい独立管理表は作成しない。
- **残る公開条件**：両OSの今回のテスト配信は利用可能。既存21日体験でのクローズド参加者確保・必要期間を維持。Androidの更新をまたぐ再ログイン不要は未確認事項として残し、今回の正式配送／現code3利用PASSを取り消さない。Apple Case103009817213の回答と決済導線方針は保留。製品版公開・追加機能開発・テスター募集投稿は今回行わない。
<!-- hamcare-test-distribution3-20261101:end -->

<!-- hamcare-avatar-final-rc3:start -->
## 2026-11-01 アバター88枚の最終統合・code3／build3ローカル候補（配信前の履歴・AVT-06／REL-02／REL-03）

- **採用・制作の実態**：本人がblack／白黒piedの各8状態を採用対象とした。保存済み実体はstable2枚だけで残14状態は未制作と判明し、本人から「未制作14枚も制作して統合する」の追加明示回答を得て制作した。stable2枚の本人目視承認と、新14枚の制作統合承認・自動目視PASS（個別画像の本人目視は未実施）を別フィールドで保持する。既存72枚と承認stableはbyte不変。
- **14枚の生成**：内蔵imagegenで1枚ずつ、外見A＝同じ承認stable、ポーズB＝採用ダルメシアン同状態、品質C＝承認Djun normal同状態を明示。原画即時保存→既存整形→512px実透過→技術／目視検査→記録の順で14/14 PASS。前の状態を次の外見参照にしない。新規試行14・再生成0。黒いシリアンの体型と白黒パイドのロボ体型を維持し、旧茶色案・不採用候補・原画は保存する。
- **本番統合**：syrian/dark8＋roborovski/pied8を無加工コピーし、標準11外見×8状態＝88枚。pied stableはready/stable_bw_v2.png（SHA647f4018…bdf40）だけを本番pied/stable.pngへ採用し、旧茶色ready/stable.pngは不採用履歴のまま保持。pubspecへ実在2末端フォルダを追加、版を1.0.1+3へ更新。アプリ機能コード・プロフィール形式・識別子・円形枠・状態判定は今回変更0、以前の独立pied実装を維持する。
- **限定確認**：checkerは96予定／88配置／white_face8保留・errors0。新16の採用元＝report＝配置先SHA、512×512 RGBA実透過PASS。保護747ファイルは欠損0・想定外差分0（許可したpubspecだけ変更）、既存72PNG・raw／ready・native／SDK／lock／ローカル設定は不変。恒久Flutter3.47.7の新2色限定12件PASS、実bundle16枚decode、48／72明暗・Home190／詳細132／編集142の112表示セルで意図しないstable代替0・例外0。通常Repoモックsave→reloadの色保持2/2・既存プロフィール互換PASS。実機の新画像確認と2→3更新は今回未実施。
- **保留の扱い**：white_faceは未制作8枚だが、既存petsアイコンへのfallbackを確認し今回の阻害にしない。他の種類で代用しない。analysis_preparingは意味確定待ち、説明素材2件は標準88枚へ数えない。円形アイコンの既存顔中心トリミングは今回変更しない。
- **番号と候補ビルド**：11/1 15:46 JSTにPlay全AppBundleはcode1／code2の2件、ASC Version1.0.1／All StatusesのBuild Uploadsもbuild2 Completeのみと読取確認し、3未登録。恒久Flutter3.47.7／Xcode27.1・既存署名／固定lockを使い隔離コピーでAndroid code3／iOS build3を生成・検証完了。原本native設定とcode2成果物を維持する。両候補の最終生成・検証は下記のとおりPASS。
- **Android code3 PASS**：署名済AAB `/Users/gota/hamcare-deploy-staging/android-ordinary-update-20261025/artifacts/hamcare-1.0.1-code3-avatar-signed.aab`、173,681,642bytes、SHA256 `d541d07fd248102925221eb910ecfa86dffc5a126df0fd090e1c881ea6b54f37`。通常main、com.gotainu.hamster／1.0.1／code3、min24／target36、非Debug、既存Upload署名7e9b…とcode2一致。jarsigner／Bundletool1.18.0／ZIP CRC、全88PNGの原本SHA一致、権限差分0を確認。隔離環境のGradle8.14／AGP8.11.1／Kotlin2.2.20を既存成功レシピから再現し、元Android設定は変更しない。将来版予告は非阻害。
- **iOS build3 PASS**：Distribution署名IPA `/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/hamcare-1.0.1-build3-avatars88-appstore-20261101.ipa`、136,840,837bytes、SHA256 `841aeee93dbccdab87d2f092a71ab435dbb8a73de2613947a83b88f90e92076f`。通常main／1.0.1(3)／iOS15、既存Team3SA77V3SM7／com.gotainu.hamster／Distribution証明書・App Store Profileを維持。codesign deep strict／ZIP CRC、get-task-allow=false／APNs production、ArchiveとIPAの実行コード・Flutter資産（署名差分を除く）・AssetManifest一致、88PNG全SHA一致、登録26パス実在を確認。ArchiveZIP `/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/Runner-avatars88-build3-development-archive-20261101.zip`、SHA256 `7c27b0c8c44a41fe26521581960f14ae6f55c7e6f3656d47461dcf471763aa95`。初回は隔離コピーへの既存ストアアイコン1件のコピー漏れで停止し、ログから特定して無加工コピーだけで解消、再試行成功。原本コード修正0、失敗ログも保持。
- **更新方式と残件**：既存アプリID／Team／Upload署名・Profile・データ形式を維持し、2→3の通常更新候補。AABのUpload署名とPlay配布署名の役割を混同しない。実際のPlay／TestFlight経由2→3更新・Home／ログイン／既存記録保持と追加画像の実機表示は未実施で、別途upload／テスト更新承認後に最小確認する。新候補のupload前のローカル阻害0。番号はupload直前に再照合する。Apple決済判断待ちとクローズド人数／期間・製品版公開は別残件。
- **証拠・一覧**：既存制作領域output/hamcare-avatar/revisions/pose-v2-20261031/_tools/final_integration_20261101/のplacement-result.json／limited-verification-summary.json／store-version-check.json。比較は同revision/index.html#final-two-looksと両色final_index.html。全プロンプト・参照・SHA・原画・最終ready・個別reportを保持。新しい独立管理表は作らない。
- **実行範囲**：追加AI／認証／課金／DeviceCheckの再試験0、体験や利用枠のreset0、端末更新0、Storeのupload／保存／配信／審査送信0、commit／push0。既存Alpha code2公開・TestFlight build2確認・Play署名更新・DeviceCheck PASSは維持。Apple Case103009817213は回答待ちで決済方針は保留。候補完成とStore配信・実機更新を区別する。
<!-- hamcare-avatar-final-rc3:end -->

<!-- hamcare-avatar-pied-bw:start -->
## 2026-11-01 ブラックstable正式採用・パイドstableの白黒毛色修正（制作・採用前の履歴・AVT-06）

- **ブラック正式承認**：本人がsyrian/darkの既存stableについて顔立ち・体型・毛色とも合格とし、本人承認済み・採用対象へ更新。ready/stable.png SHA de76928f0c60ffae8af4f600e76a1cd3b92a63af61e27d9d69326841106746bcは不変。canonical／最終試行report・visual_review・CSVへ承認を反映。再生成・加工0、本番配置は未実施。残7状態は今後の制作対象として維持するが、今回は生成しない。
- **パイドの本人判定を分離**：旧茶色案の体型・顔立ち・画風は本人合格、毛色は茶系ではなく白黒へ修正要求。旧原画・master・ready/stable.png・初回試行reportを保持。旧案の履歴はreports/stable_brown_v1.jsonにも保存し、体型等の合格と毛色修正を記録した。
- **実際の編集・保存**：内蔵imagegenへ旧piedの個別原画だけを編集対象として指定し、毛色と必要最小限の斑表現だけを白地＋黒〜濃い中性チャコールへ変更する指示でstable1枚を作成。シリアン／ダルメシアン参照を流用しない。新原画raw/stable_bw_v2.png、1024px masters/stable_bw_v2.png、512px実透過ready/stable_bw_v2.png、prompt／個別reportを同じroborovski/pied内へ別名保存。識別子pied／状態stableと将来の本番パスは変えない。
- **現在の候補正本**：roborovski/pied/reports/stable.jsonは白黒v2のrecordを指し、outputs.readyはready/stable_bw_v2.png。旧ready/stable.pngは茶色の履歴であり、承認後の状態展開へ誤って使わない。新白黒版のSHAは647f40182c1385303b02eaac2304b5e6d0b4a0640e10c89f8dbc3092a8bfdf40。owner_approved=false／owner_coat_review=pending、本人確認待ち。旧案の外見合格を新版の最終採用へ自動転記しない。
- **限定検査**：既存PNG検査・全decode・RGBA・512×512・実alpha0..255はPASS。原画と512px白暗を開き、茶／ベージュ／オレンジ毛の残りは目視上なし、黒部に毛の濃淡あり、耳鼻足のピンクを維持。顔・低いロボ体型・落ち着いた姿勢・構図を旧案と比較。見えるbbox端の差は最大1px、alpha silhouette IoU約0.986で、全体の大きさと配置は概ね一致。これは自動限定確認で、本人毛色承認とは区別する。
- **確認入口**：既存output/hamcare-avatar/revisions/pose-v2-20261031/index.html#two-stable-coat-reviewを更新。白／暗・384／192／72／48pxで旧茶色案と新白黒版を同じ列に比較。既存の前回比較画像は保持。ブラックは承認済みと表示し、再承認を求めない。
- **次と保護**：白黒v2 stableが本人承認されたら、その同じ承認原画を外見Aとしてダルメシアン同状態B・承認済みnormal同状態Cと共に7状態へ展開。ブラックの残7状態も維持し、最終追加は各8、計16枚の計画。今回の状態差分0・本番配置0、既存72枚・プロフィール／ID・pied実装／既存12件PASS・円形枠・権限／課金・署名／SDK／pubspec／lockは維持。white_face／analysis_preparingは別保留。ビルド・配信・commit／pushなし。
<!-- hamcare-avatar-pied-bw:end -->

<!-- hamcare-avatar-two-stables:start -->
## 2026-11-01 ブラック／パイドstable外見候補2枚（旧茶色案提示時点の履歴・AVT-06）

- **既存の完成状態を維持**：アプリ配置済み標準72枚、修正版50枚の本人承認、登録・限定13件PASSは完了済み。再確認・再制作を求めず、通常権限・プロフィール・署名／SDK・pubspec・円形表示枠を変更しない。
- **syrian/dark**：既存の全体黒／チャコールstable候補を再利用。制作未着手ではなく、制作・形式／自動目視確認済みで本人の毛色確認待ち。既存golden stableと原画・reportの対応を再照合。512px PNG SHA256 de76928f0c60ffae8af4f600e76a1cd3b92a63af61e27d9d69326841106746bc不変。別blackキー／選択肢追加0、再生成0、本番未配置。全体黒の濃さ、胸腹にも黒を使う案かを本人が確認する。
- **roborovski/pied**：今回は本人が代表模様案の制作を許可したため、特定個体の写真不足では停止せず内蔵imagegenでstable1枚を作成。既存normal stableだけを顔・低い体型・画風の参照に使い、白地と砂茶／灰褐色の斑が分かれる案とした。white_face改名・ダルメシアン流用なし。原画保存→従来の全キャンバス縮小→512px RGBA実透過／PNG・CRC・全decode・明暗目視を確認し、本人外見確認待ちで保存。coat_reference_verified=false、design_proposal=trueで、白斑の位置・面積を確定済みとは扱わない。独立pied実装・既存12件PASSは保持し、コード変更／再試験なし。
- **候補・比較の場所**：両方ともoutput/hamcare-avatar/revisions/pose-v2-20261031/<body>/<color>/raw・ready・reportsに保持。今回の2色だけを既存index.html#two-stable-coat-reviewへ追加し、既存Syrian golden／Robo normal stableとの白／暗・256／144／72／48px比較を用意。生成指示はroborovski/pied/prompts/stable.txt。既存72枚や承認済みポーズの再承認は不要。
- **次工程はstable採用後だけ**：両stableの顔立ち・毛色・模様が本人承認された後、各色の同じstableを外見A、採用済みダルメシアン同状態をポーズB、承認済みDjun normal同状態を品質Cにして7状態ずつ、1枚生成→保存→検査→記録で展開する。最終予定は各8状態・計16枚（stable2＋状態差分14）。今回の状態差分0・本番配置0。将来16枚を採用配置した場合は標準72→88枚で、今回88枚になったとは記録しない。
- **別の保留**：roborovski/white_faceは白い範囲の資料待ち、analysis_preparingは意味確定待ちのまま。dark／piedは「stable候補2枚の本人外見確認待ち」であり、「資料待ちのため制作未着手」へ戻さない。下記の旧記載は当時の履歴。
- **今回の範囲**：本番assets・アプリ／円形枠・署名・依存・ビルド・端末・upload・配信・commit／pushは変更なし。既存制作台帳16行のstatusと本書AVT-06を更新し、独立管理表は追加しない。
<!-- hamcare-avatar-two-stables:end -->

<!-- hamcare-avatar-pose-expansion-progress:start -->
<!-- hamcare-avatar-approved-placement:start -->
## 2026-11-01 承認済み修正版50枚の採用・アセット配置（AVT-06）

- **本人承認**：今回の43枚（Djun sapphire／pearl／cream各7、robo normal7、syrian cream／white各7、golden alert1）を全て合格・採用承認。既承認Djun normal7枚と合わせ、修正版50枚を本人承認済み・採用対象としてcanonical report／同じ最終試行report／visual_review／既存CSVへ反映した。自動PASS・本人承認・配置を別フィールドで保持し、旧差戻し／再生成前reportや原画は採用へ昇格しない。
- **最終PNG選定・配置**：比較一覧の最終readyとreportのSHAを照合。robo environment_discomfortは再生成1回後の最終readyを採用し、初回は不採用履歴のまま保持。50枚の512px RGBAをassets/avatarsへ無加工コピーした。既存採用シリアン15枚はbyte不変。候補領域にのみあった現在のstable7枚は、本人の維持・配置指示に基づき既存report対応の512pxを無加工コピーし、原画・候補stableは不変。再生成0・旧画像置換0・新規配置57枚。
- **総数・登録**：標準アバターは9外見×8状態＝72枚（既存15＋修正版50＋stable7）。pubspec.yamlへ実在7末端フォルダだけを追加。種類／毛色／状態キー、Resolver、プロフィール保存、権限／課金／記録、版数・SDK・署名・lockは維持。候補PNG・比較画像・rawは本番アセット登録しない。
- **限定検査**：既存checkerで9外見の全8状態を必須確認しPASS（台帳96／配置72／保留24、errors0）。新規57枚はコピー元と配置先のSHA一致、PNG構造・CRC・512×512・RGBA・実アルファを確認。既存15枚の形式差は変更せず保持。恒久Flutter3.47.7の限定13件PASS。72実PNGを実bundleからdecodeし、9外見のプロフィール色ラベル再読込・全8状態のResolverを確認。既存HamsterAvatarViewを使う計729セルで指定状態自身を表示、意図しないstable代替0・例外／overflow0。48／72／150px、Home190・詳細132・編集142枠154のBoxFit.containで全身の切れなし。実機は今回未確認。
- **円形アイコンの既存表示**：Drawer66px内88px＋Y5、相談70px内96.6px＋Y5は以前からの顔中心拡大・円形トリミング。実Widget画像で足元／ひげ端／補助表現等の一部が切られることを確認し、全身無欠損PASSとはしない。顔や毛色の識別はできるが、全状態の全身を円枠内へ表示するには表示枠側の別調整が必要。今回は承認画像・既存UIコードを変更せず、既存表示を維持した。
- **保留**：syrian/dark、roborovski/pied、roborovski/white_faceは各8状態、計24予定を未配置のまま保持。配置対象外の最新状態はdark stableが本人正式承認済み・採用対象／残7状態は今後、piedは顔・体型・画風の旧案合格を維持した白黒v2 stableの本人毛色確認待ち（独立実装と既存12件PASSを維持）、white_faceは白い範囲の資料待ち。今回この3外見の未配置は維持する。analysis_preparing11案は意味未確定の別枠。台帳外ダルメシアン説明候補1件は説明素材の分類を維持し、標準72枚へ数えない。
- **証拠・保護**：既存制作領域output/hamcare-avatar/revisions/pose-v2-20261031/_tools/integration/のsource-audit.json／placement-result.json／checker-result.json、既存reportのproduction_asset_path／production_sha256。変更前の管理・検査記録は同領域prior_recordsへ保持。古い「未承認・未配置」は下記の当時の履歴として残す。
- **同内容の再依頼の照合（2026-11-01）**：修正版50枚と維持stable7枚の採用元・配置先・report SHA／本人承認／配置状態・既存CSV・pubspec末端登録が現在も一致。既存シリアン15枚を含む標準72枚を確認し、新規コピー0・置換0・追加登録修正0。既存13件PASS／729表示セル・fallback0の証拠を再利用し、画像生成や表示テストの再実行はしない。直近のブラックstable正式承認と白黒パイドv2の本人毛色確認待ちは維持し、過去の「両方資料待ち」へ戻さない。証拠は既存placement-audit.jsonのidempotent_recheck_20261101。
- **現在**：50枚の本人承認反映・57枚の追加配置と登録、実PNGと既存部品の限定参照／表示確認まで完了。登録・参照のビルド阻害0。既存円形枠のトリミングと実機未確認は上記のとおり分離。次期AAB／IPA・端末更新・upload・配信・commit／pushは今回行わない。完了済み認証／AI／DeviceCheckの再試験なし。
<!-- hamcare-avatar-approved-placement:end -->

## 2026-10-31 本人承認7枚を基準にした43状態のポーズ展開（承認・配置前の履歴）

- **承認の引継ぎ**：修正版ジャンガリアンnormalの非stable7枚は、既存reportの`owner_approved=true`／`owner_pose_review=approved`で本人ポーズ承認済み。`production_placement=not_placed`を維持し、本番配置0。前回の「7枚の本人確認待ち」は下記の経緯として残し、再び未承認へ戻さない。
- **今回の確定対象43枚**：既存台帳と作業前記録から、Djun sapphire／pearl／cream各7、robo normal7、未採用syrian cream／white各7、golden alert1を順に展開。既存採用シリアン15枚・提供stable2枚・既存毛色stable・承認済みnormal7枚を再生成／上書きしない。
- **保存・検査現在値**：新規生成43/43対象（試行計44回）、PNG／実透過等の技術PASS 43、ポーズ自動目視PASS 43、要確認0、目視／ポーズ記録待ち0、原画保存済み・記録待ち0、未着手0。残る実行・確認対象0。今回の新候補は本人承認0・本番配置0で、自動PASSを本人承認へ読み替えない。
- 保存先は`output/hamcare-avatar/revisions/pose-v2-20261031/<body>/<color>/`。原画は生成直後`raw/`へ保存し、`masters/`・512px透過`ready/`、明暗preview、参照／prompt／SHA／試行回数／技術・目視結果／本人承認状態を`reports/<state>.json`・`visual_review.json`へ保持。毎回対応stableと承認済みポーズ基準を明示し、実際の入力は個別reportとpromptを正とする。新しい管理表は作らず既存CSVの対応statusを使用する。
- 総覧はoutput/hamcare-avatar/revisions/pose-v2-20261031/index.html。
- 毛色別の比較入口`<body>/<color>/index.html`、白／暗`comparison_*.png`・実48px／72pxの小表示比較から個別PNG・raw・report・promptをたどる。現在の比較済みフォルダ：djungarian/sapphire／djungarian/pearl／djungarian/cream／roborovski/normal／syrian/cream／syrian/white／syrian/golden。B・旧候補・新候補を区別し、旧画像と旧記録を保持する。
- **説明用ファイル分類**：`assets/avatars/syrian/dalmatian/analysis_preparing_v1.png`を実画像で開き、頬袋を大きく描いた白黒説明候補、現AppTheme未参照・標準8状態外と確認。RGB／アルファなしの元画像で、透過ready品質や本番採用をPASSとしない。checkerの`ILLUSTRATIONS`へこの正確な1パスだけ追加し、既存golden説明画像と分けて分類。PNG SHA256 `f53e62434014a74cfb229911d47627c37a1d039626cd82678f32251dba5ca2a2`不変。分類後の既存checker1回は96予定／15実在／81pending・errors0・PASS。説明素材の分類による解消で、pied画像の完成や再テストを意味しない。証拠は`/Users/gota/Documents/Codex/2026-08-22/referenced-chatgpt-conversation-this-is-an/work/hamster_project/output/hamcare-avatar/revisions/pose-v2-20261031/_tools/expansion/illustration-classification/classification-result.json`。
- **今回の生成補足**：ロボロフスキーnormalのenvironment_discomfortは、初回の細い連続背線を修正するため同じA/B/Cから1回だけ再生成。初回＋修正版の原画・PNG・reportを保持し、修正版を比較一覧へ表示する。今回43対象・計44試行。最終検査証拠は既存revisionの_tools/expansion/final-audit.json。
- **保持する保留**：darkは黒系stable候補の本人毛色確認待ち・状態差分未展開。piedは独立ローカル実装と既存12件PASSを保持し、白斑資料／stable待ちで未制作。white_faceは未制作、analysis_preparingは意味確認待ち。これらを43対象へ混入させず、パイド関連テストも再実行しない。
- **保護確認**：作業前からのPNG 726ファイルとアプリ／テスト／設定 643ファイルのSHAが不変。今回許可した既存コード差分はcheckerの1パス分類のみ。アバター状態切替・識別子・プロフィール・課金／権限・SDK／署名／版数・既存dirty設定を変えず、ビルド・upload・配信・commit／pushは行わない。既存Alpha公開、TestFlight／DeviceCheckの成功、Apple Case103009817213回答待ちは維持。
- **現在**：43対象の制作・検査工程完了。本人確認待ち。次：`43対象の生成・検査終了。新候補の本人ポーズ確認待ち`。中断後は保存済みraw・report・CSVから再開し、重複生成しない。各対象は初回＋必要な再生成1回まで。
<!-- hamcare-avatar-pose-expansion-progress:end -->

## 2026-10-31 ポーズ本人差戻し・ジャンガリアンnormal再制作／パイド独立対応

- **現在地（`AVT-06`）**：前回55候補のうちstable5枚は維持、stable以外50対象は「形式検査済みでもポーズ品質は本人差戻し」。原画・前回512px・コンタクトシートは全て保持し、旧report／visual_reviewの退避を`output/hamcare-avatar/revisions/pose-v2-20261031/prior_records/`へ保存して、現記録に本人差戻しを追記した。自動目視PASSの履歴を本人の採用承認とは扱わない。提供stable2枚・既存採用シリアン15枚もbyte不変。
- **今回の画像**：内蔵imagegenでジャンガリアンnormalの非stable7状態を1枚ずつ生成→原画保存→512px実透過／PNG構造・CRC・alpha・全デコード→原画と明暗背景の目視→記録の順で完了。全7枚で外見A＝同じ本人提供normal stable、ポーズB＝採用済みダルメシアンの同状態画像を明示入力。直前状態の連鎖参照0。技術検査7件PASS・自動目視記録済みだが、ポーズ品質の最終合否は未判定（本人確認待ち）。候補は本番未配置。
- ダルメシアン8状態は個別に実画像を開き、方向・胴・重心・四肢・表情・必要な補助表現を[既存アバターREADME](assets/avatars/README.md#ダルメシアン実画像のポーズ読取と再制作2026-10-31)へ記録。目／前足だけの微差という旧制限を撤回し、alertは左3/4、environment_discomfortは背面から肩越し、activity_highは左向き横長の跳躍、condition_concernedは頭を下げた低い伏せへ変更。種類・毛色・画風はAを維持し、Bの斑点やシリアン体型は移さない。既存整形の全状態共通足元固定は使わず、同一の全キャンバス縮小で姿勢ごとの輪郭／高さを保持した。固定足元・円形位置等の旧layout規則は新指示により技術合否から分離し、適用しなかった項目もreportへ残した。
- **比較**：[新旧比較入口](output/hamcare-avatar/revisions/pose-v2-20261031/djungarian/normal/index.html)。同状態を列にしてダルメシアン／旧候補／新候補を3行で白・暗背景へ合成し、実48px／72pxも別画像で確認。全7列に欠損なし、個別原画・512px・report・全生成promptへのリンクあり。状態名を隠したシルエットも目視し、背面・跳躍・伏せ・左3/4の違いを確認した。本人のポーズ承認は今回未受領。
- **ブラック**：現行resolverの「ブラック・濃色系／black」→`dark`、assetDirectory=`syrian/dark`を照合。新blackキー・選択肢は不要。既存golden stableを外見／画風／体型基準に黒系stable候補1枚を生成し、原画・512px・明暗preview・reportを`output/hamcare-avatar/revisions/pose-v2-20261031/syrian/dark/`へ保存。形式・自動外見確認済みだが、具体的な黒白分布の参照資料はなく`coat_reference_verified=false`／本人毛色確認待ち。全体黒／チャコール案を確認済み実毛色とは扱わず、7状態へ展開しない。
- **パイド**：旧roborovski判定が「パイド」をwhiteFaceへ吸収する事実を確認し、ローカルで`pied` enum末尾／assetKey、毛色選択肢、white判定より先の`パイド／pied／piebald`判定、編集時ラベルを独立追加。旧normal／white_face・他種判定は維持。保存は既存color文字列の通常Repo経路を利用し、新DBフィールド・一括移行・本番書込なし。曖昧な旧白系からpiedは推測しない。主CSVへroborovski/piedの8状態を追加し、一般88行＋ダルメシアン8行＝12外見96状態へ更新。checkerの許容キーにもpiedを追加。実画像は白斑の位置・面積・地色・顔／耳／背中の色の残し方が分かる対応写真／原画待ちで未制作。white_faceの改名代用0。
- **関連検証**：恒久Flutter3.47.7を使用し、`flutter test --no-pub test/hamster_avatar_pied_test.dart test/measurement_profile_quality_test.dart`はexit0・12件PASS。最終経路アサーション版で新規8件だけ再実行exit0・8件PASS（ツール実行記録20098/193ad3、90147/95fb09）。選択／判定順、通常Repoモックで保存→再読込→ラベル／外見再表示、旧white_face維持、pied欠損状態→同pied stable→petsアイコンのWidget経路を確認。実プロフィールへの保存・実機E2Eは行っていない。画像未配置のためpubspec leaf登録はせず、既存fallbackを使用する。
- **台帳検査の切り分け**：読み取り専用`tool/check_avatar_assets.py`は96予定・本番15実在／81pendingを認識し、piedキー／8行の不整合は0。ただし作業前から未追跡の`assets/avatars/syrian/dalmatian/analysis_preparing_v1.png`が標準台帳外と検出され全体結果はFAIL。この1件は今回生成・pied実装の失敗ではなく既存ファイル分類の問題で、無断削除・新状態化・黙った検査除外は行わない。個別新PNG8枚の形式検査と、pied関連12件PASSとは分離して記録する。
- **次**：7枚の本人確認後、Djun sapphire／pearl／cream各7、robo normal7、未採用syrian cream／white各7とgolden alert1（計43状態）へ新ポーズ参照方式を展開する。既存採用シリアン15枚は対象外。darkはstable毛色確認後、piedは毛色資料とstable確認後に進める。white_faceとanalysis_preparingは今回の制作範囲へ追加しない。
- 本番assets配置・アプリ版数／署名／SDK／lock／課金／権限／記録・既存dirty設定の変更、AI送信、ビルド成果物作成・upload・配信・commit／pushは0。Play Alpha code2公開済み、TestFlight・DeviceCheck成功、Apple Case103009817213回答待ちは保持する。

<!-- hamcare-avatar-sequential-progress:start -->
## 2026-10-31 基準stableからの逐次候補制作（前回履歴・本人差戻し前の自動確認）

- 最新依頼に基づき、受け入れ準備から実際の内蔵imagegen候補制作へ移行。1回1外見・1状態・1枚、同時生成なし。毎回対応stableを入力し、他状態を連鎖参照しない。既存画像を再生成・上書きせず、原画保存→512px候補→形式／透過・目視検査→既存台帳status更新の順で記録する。
- 標準制作台帳は既存11外見×8状態＝88件。配置済み再利用15件／本人提供stableの保存・整形再利用2件／今回生成55対象（試行計57回）。生成対象の自動・目視検査PASS 55件、要確認0件、目視待ち0件、原画保存済み・記録待ち0件、標準対象の未着手16件（外見資料待ち16件／実行可能な未着手0件）。PASSも本人採用承認・本番配置の完了を意味しない。
- roborovski/normal stable原本：`/Users/gota/Downloads/例_ロボロフスキーハムスターのノーマルのstable.png`、SHA256 `67899f4d0ad73e86e3333e81dbbe410c61f23c8e950c81cdea9faa138952352c`。原本を保持して再利用。
- djungarian/normal stable原本：`/Users/gota/Downloads/例_ジャンガリアンハムスターのノーマルのstable.png`、SHA256 `fa514d218265675907f568e949ea13eaf4d8ee3bac46353276ba329e1c41bf21`。原本を保持して再利用。
- 制作領域は既存キットが定める`output/hamcare-avatar/<body_type>/<color_variant>/`。`raw/`へ原画を直ちに保存し、`masters/`へ1024px、`ready/`へ512px透過PNG、`reports/<state>.json`・`visual_review.json`へ参照／出力先・SHA・技術／目視結果・初回＋再生成回数・本人未承認を保持する。新しい独立タスク管理表は作らず、既存CSVの対応statusだけを更新する。
- 白／暗背景の状態名付き`contact_sheet_white.png`／`contact_sheet_dark.png`と、個別原画・PNG・検査記録へのリンク付き`index.html`を毛色単位で作成。現在の一覧：roborovski/normal／djungarian/normal／syrian/golden／syrian/cream／syrian/white／djungarian/sapphire／djungarian/pearl／djungarian/cream／syrian/dalmatian。個別PNGへ背景や状態名は書き込まない。
- 全外見の確認入口は`output/hamcare-avatar/index.html`、縮小一覧は`overview_white.png`／`overview_dark.png`。既存採用15件は読取参照で一覧へ載せるが、過去の台座・小物等を今回仕様への新規適合PASSとは扱わない。本人提供ジャンガリアンstableの原本台座も保持し、新規差分へ追加しない。
- 外見資料保留は標準88件の内数16状態：`syrian/dark`8状態は具体的な模様・白胸／白腹の指定根拠不足、`roborovski/white_face`8状態は顔の白化範囲・耳周辺・背中との境界が未確定。基準画像の品質不合格とは別の保留で、模様を推測してstableや状態差分を量産しない。確定できる他外見の制作は続ける。
- Downloadsの既存制作キットは参照資料として利用するが、同梱99件案の`analysis_preparing`11件は意味・表示条件未確定として標準88件とは別に保留する。既存の説明画像`analysis_preparing_v1.png`や未追跡ダルメシアン版を勝手に対応付け・再生成しない。共有キャンベル専用画像・新しいキーを追加しない。
- 前回終了時点：確定対象生成完了・外見資料待ち。その後、stable以外50対象はポーズ品質を本人差戻し（現在地は上の再制作節）。この節の88件／55自動PASSは当時の履歴で、現行pied追加後の96件や本人ポーズ承認を意味しない。
- 次の未完了対象：`確定外見の実行可能対象は制作済み。syrian/dark・roborovski/white_faceの外見資料16状態分と本人採用承認を待つ。`。再開時は原画・report・CSVを照合し、保存済み画像を重複生成しない。再生成は同じstableから各対象1回まで。新しい毛色stableは検査PASS後のみ本人未承認の暫定基準として展開する。
- 既存PNG・アプリコード・SDK／署名・バージョン／lock・プロフィール／記録／通常権限・ローカル設定は保護。候補の本番assets配置、ビルド・upload・配布、コミット／pushは行わない。既存Play Alpha公開／TestFlight／DeviceCheckの完了状態とApple Case103009817213回答待ちは維持する。
<!-- hamcare-avatar-sequential-progress:end -->

## 2026-10-31 アバター受け入れ準備・次期テスト版（画像制作待ち）

- 完成条件は「新アバター画像の受け入れ準備完了・新ビルド配信待ち」。本人のPNGはまだ未提供。画像生成・仮画像配置・既存画像置換やruntime変更は行わない。既存assets READMEへ形式・命名・種類／毛色キー・8状態・保存データ互換性と追加手順を確定した。
- `AVT-06`：実在は通常色`syrian/golden`7状態（alert未制作）とダルメシアン8状態。別のanalysis_preparing_v1は説明素材。主CSVの実在7行だけを配置済みへ整合。実際のfallback「指定状態→同じ種類／毛色stable→petsアイコン」を文書へ反映し、roi.pngへ代替する旧説明を修正。Firestoreのspecies／color／imageUrl・subjectId・記録に変更なし。
- 読み取り専用`tool/check_avatar_assets.py`を追加。既存2CSVの88予定・PNG構造／CRC／寸法／alpha対応・末端assets登録を検査する。通常検査15実在／73pendingとダルメシアン8状態必須はPASS、通常色8状態必須はalert未制作1件で想定FAIL。新画像のデザイン承認・実機確認済みとはしない。
- `REL-02`：本人報告を受領し、Play送信ID1・14変更・Alpha1.0.1/code2は2026-10-27 11:19 JST「公開」と確定。今回Consoleの送信詳細／リリース一覧でも同表示を読取照合。11:09の審査送信／当初審査中の経緯を保持し、Alpha公開をProduction一般公開や12人／14日の達成に読み替えない。
- 次期はAndroid1.0.1/code3・iOS1.0.1/build3。Play全App Bundleはcode1/2の2件、ASC Version1.0.1／Build Uploads All StatusesはCompleteのbuild2だけで、3は未登録と読取確認。画像統合時に元pubspecの1.0.1+2を+3へ更新し、upload直前も番号衝突を確認する。既存署名・アプリID・トラック／グループを維持し、Androidの成功済み隔離native構成・iOSの既存Archive/export工程を再利用する。次回の手順は既存Play登録／iOS署名文書へ追記した。
- クローズドテストは本人決定で既存の21日無料体験を利用。カード不要・開始から21日・AI最大20件／個人費用枠と有限共有枠を維持し、自動課金なし。期限・回数の再付与はしない。正規0円契約を準備済みの審査用アクセスは別用途として保持する。テスター確保・必要期間は未完了、共有予算残量は今回未照会で全員20件保証とはしない。
- Apple Case103009817213の回答待ち・決済導線保留、完了済みTestFlight／Android／Play署名更新／DeviceCheckのPASSを保持。既存ローカル設定2件はbyte不変・コミット対象外。新AAB／IPA／Archive、ストア保存／upload／配信・本番変更・実AI／再認証テスト・体験resetは0。

## 2026-10-31 Git保存に向けた管理表の整合

- 正式な管理表は本書「タスク一覧」。既存の移行記録・`AGENTS.md`・`MATOME.md`に従い、旧Excelを複製・二重更新せず、`REL-02`／`REL-03`の表と既存クローズドテスト計画の「日程」表を更新した。
- 完了済みのTestFlight同意対応版、Androidローカル更新の保持確認、Play署名での新規導入とStore経由code1→code2更新、Release DeviceCheckサーバー計測、審査用アクセス準備、Alpha14変更の送信を維持する。新たな実機テスト・AI送信・配信・審査送信は行っていない。
- 審査状態の根拠は10/27の受付記録と本人の引継ぎ。本作業ではConsole・Appleメールを再照会していない。Play送信ID1の最終確認は「審査中」、審査通過・Alpha実配信・製品版一般公開は未確認。Apple新Case103009817213は受付確認済み・回答待ちとして保持し、決済導線の判断は保留する。
- 既存の開発成果467ファイルと前回の保存記録はGitHub `github/main`の`a6d4a1c`まで反映済みであることを再確認。今回の追加保存は管理表の整合差分のみ。ローカルFirebase設定と実接続由来の生成監査JSONは対象外として保持し、パスワード・秘密鍵・認証トークンを追加しない。

## 2026-10-27 開発成果・管理正本のGitHub保存（通常push・反映確認）

- 開始時の`main` HEADとGitHub `github/main`はともに`342b293d0e634989b0012a27e27fafb575e11b2d`。`origin`は別のローカル作業コピーで、同remoteのahead 3はGitHub未pushを意味しなかった。GitHub最新をfetchして分岐なしを確認し、正規の`github` remote（`gotainu/hamster-application`）の`main`へ通常pushした。既存upstreamは変更していない。
- 保存コミット：`84a5013455bb8377c83b03548bb53e9c30041394`（実装・AI同意・個体別Insight／統合レポート・iOS設定・テスト352ファイル）、`d902eb573bf92b9b7917ddd0f6462215d8be4ddc`（運営分析・合成データ研究基盤78ファイル）、`aa5f70faded7fc8ae27d0f54a2a7e2215ad4e3c4`（管理正本・進捗・リリース／研究文書・申告／掲載原稿37ファイル）。計467ファイルを選別して保存。
- この3コミットの通常pushは成功。push後の`git ls-remote --heads github main`でGitHub側のSHAがローカルHEAD `aa5f70faded7fc8ae27d0f54a2a7e2215ad4e3c4`と一致することを確認した。本節はその確認結果の追記であり、追記後の最終HEADはGit履歴を参照する。
- タスク管理表の正本は本書「タスク一覧」。`AGENTS.md`・本書の2026-09-06移行記録・`MATOME.md`を照合し、旧Excelの追加／複製／二重更新は行っていない。`MATOME.md`、既存`docs/release/`、`docs/product_quality_rework_plan.md`も保存。Playの「未送信」が残っていた現在地だけを送信済み・送信ID1審査中へ整合。Apple新Case103009817213は回答待ち、Stripe維持方針は変更なし。
- 全対象を明示的なファイル一覧でステージし、ステージ内容と作業ファイルの一致、秘密情報パターン、配布成果物／ビルド／キャッシュの除外、JSON構文と差分を確認。Markdownの意図した改行空白とCSVのCRLFは保持した。文書中の個人端末識別子・審査用メール候補・不要なSandboxオブジェクト識別子は匿名化。既存の実装・実機検証・全テスト・build・本番deploy・ストア操作は再実施していない。
- 未コミットの既存2件は元byteを保持：`ios/Runner/GoogleService-Info.plist`（既に追跡済みのAPIキーを含むため、今回のOAuth識別子追加も対象外。必要な`Info.plist`側の`GIDClientID`／URL schemeは保存）、`tools/analytics/output/bigquery-connection-result.json`（実接続由来の生成集計監査で、合成データサンプルとは分けて除外）。ローカル設定・運用証拠を削除せず、467対象以外の追加ファイルは作成していない。
- 既存Known Goodとdirty差分を保護。実装・テスト・設定の既存byteは変更せず、今回の内容修正は上記の文書整合／匿名化と本結果追記のみ。履歴書換え・reset・clean・stash・force pushは行っていない。

## 2026-10-27 Apple App Reviewへの決済方式問い合わせ（受付確認・回答待ち）

- 旧Apple Case22954972は10/27に代替配信／決済担当から当該窓口のscope外との回答を受領。これはStripe導線の可否回答ではない。本人承認の指定文面で、公式 https://developer.apple.com/contact/app-store/ から実窓口「App Review → App Review に関するその他のお問い合わせ → Eメール（公式フォーム）」を選び、2026-10-27 11:46:34 JSTにApp Review宛て新問い合わせを送信。受付結果公式完了画面と11:48:45 JST受信の受付メールで番号一致を確認、新Case ID103009817213。回答は未受領で、A／B導線・Stripe維持条件の判断は回答待ち。
- 対象はApp Store Connectの数値App ID6826783734、名称「Hamster Care｜ハムスター健康管理」、Bundle ID com.gotainu.hamster。既存アプリ・提出候補を維持。問い合わせ送信はアプリ本体のApp Review提出・公開ではない。
- 証拠：既存iOS staging/audit/apple-appreview-inquiry-20261027/。旧Case経緯、選択窓口・承認済み送信文面・受付結果を分離して保持。既存Play送信・実機・通常権限・署名／成果物PASSを維持し、コード／SDK／IAP・Billing／Stripe導線・本番設定・利用履歴を変更しない。秘密情報・不要な個人情報を文書へ転記しない。本人指定の送信本文は既存問い合わせ記録へ原文保存する。

## 2026-10-27 Play Alpha審査送信（本人承認の14変更／審査結果と配信状況は実値で分離）

- `REL-02`：登録済み同意対応AAB1.0.1／code2（artifact ID4860244546361357551、SHA256 9ac74bc4…b237）を使う既存Alpha release2を再読取。新しいApp Bundleはcode2だけ、保持bundleなし、code1は無効化済みの履歴。日本1国、製品版との地域同期解除、既存internal-testers本人1名を維持。内部配信、code1→code2のPlay更新／保持PASS、iPhone／DeviceCheck等は再検証していない。
- 今回保存した差分は2点。Alphaの空欄だったフィードバック先へ既存support URLを設定し、別画面へ移動後の再読取でも保存を確認。Data Safetyの診断情報は「任意」から「必須（利用者はオフにできない）」へ変更・保存完了を確認。利用者向け停止設定がなくサーバーの技術ログが選択によらず記録される既存実装と、既存申告表の必須分類へ揃えた。収集12種類／共有なし／用途2件（アプリ機能・分析）等は維持し、実際の収集処理は変更しない。
- 名称・短文・本文は保存済みtxt原稿と照合し、本文691文字が完全一致。短文はConsole側を維持し、既存metadata txtにだけ不足した末尾句点1文字を同期。掲載の再保存は行わない。アイコン1枚・feature graphic1枚・携帯スクリーンショット4枚の保存を確認。再upload・再作成なし。公開Privacy／supportはHTTP200かつ既存public原稿とbytes一致、Privacy URLと削除URLの保存も確認した。公開ページの変更／Hosting配備は0。
- 送信前の公開の概要は14件「審査にまだ送信されていない変更」で、本人がAlpha1.0.1／code2・日本・既存本人1名と、管理対象公開オフによる承認後のAlpha配信を含めて明示承認。2026-10-27 11:09 JST、直前の14行・対象AAB・地域・テスター条件を再照合して審査送信した。送信後Consoleは「審査中の変更（送信ID1：審査中）」、審査中14件／未送信0件。送信前14行の内訳は[既存Play手順](docs/release/google_play_submission_runbook_ja.md#未送信14変更の送信範囲2026-10-27)へ保持し、審査送信成功・審査通過・実配信を分ける。
- **カードなし0円契約・通常権限同期PASS。** 通常登録・メール確認・Home／ログイン保持に加え、本人が10/27 10:03 JSTにStripe Dashboardでカードなしの正規契約を作成。既存Premiumへの100%・forever・商品限定Couponを直接適用し、適用上限1回を維持。trialなし、SubscriptionはActive、初回Invoiceは0円Paid、次回11/27も0円を確認。Promotion Code経由の適用完了とは記録しない。
- **初回同期障害と通常metadata経路での復旧。** 初回invoice.payment_succeededはbillingのstripeSubscriptionId向けCOLLECTION_GROUP_ASC索引不足で500。現配備handlerを照合し、対象Customerの既存認証連携metadataを本人Authとのhash一致で確認して、同Subscriptionのmetadataへ通常Checkoutと同じ連携情報を補記。customer.subscription.updatedの既存Webhookが自動同期し、Firebaseはpaid／active、期限2026-11-27T01:03:01Z、最新同期2026-10-27T01:08:36.274Z、Customer／Subscriptionの照合hash一致を確認。trial文書なし。索引自体の作成・修正、手動再送、コード／deploy／DB直接編集は0。metadata経路の同期成功と、索引不足経路の未修正を区別する。
- **審査用アクセスの準備・保存PASS。** 本人がAndroid「変化」を無料体験なしで開けたと回答し、有料gate PASS。本人が新登録HamCareのパスワードをConsoleへ直接入力し、456文字の英語手順・全機能アクセス確認を「追加」→親画面「保存」で保存PASS。別画面へ移動後の再読取でも、対象username・456文字・確認項目の一致を確認した。パスワードはチャット・文書・証拠へ転記していない。 公開の概要の未送信は14件のまま（増減0）。ログインの詳細の手順更新は既存の「お送りいただいた変更」欄に別表示され、14件へ重複加算しない。この保存時点では14件未送信だった。その後、本人承認の同14変更を2026-10-27 11:09 JSTに審査送信。Alpha実配信は未確認（審査通過後の配信待ち）、Production一般公開0。 特別beta・DB直接有料付与・trial再開始／延長・履歴reset・AI枠無制限化なし。
- 初期の審査手順保存拒否履歴：当初未登録で全機能アクセスの根拠がなかったため、455文字案は虚偽確認を付けず未保存として閉じた。登録・カードなし0円通常契約・Firebase同期・本人のAndroid有料gate PASSを経た後、現在の456文字手順と資格情報を保存PASS。旧経緯は[既存審査メモ](docs/release/store_review_notes_ja.md#google-play審査アクセスの現状と保存待ち文案2026-10-27)とauditへ保持する。
- 状態は**審査用アクセス準備・保存PASS／本人承認のPlay Alpha14変更を審査送信済み**。送信時刻2026-10-27 11:09 JST、送信後表示「審査中の変更（送信ID1：審査中）」。審査結果は未確定（審査中・審査通過は未確認）、Alpha実配信は未確認（審査通過後の配信待ち）。管理対象公開オフのため、審査通過後は承認済みAlpha対象（日本・対象リスト＋opt-in条件）への配信と共通掲載／申告反映が自動で進む。Productionへの昇格ではなく、製品版一般公開・App Store一般審査は行わない。Apple Case22954972の決済判断保留を維持し、審査送信成功を決済適合や審査合格へ読み替えない。
- 証拠：既存Android staging/audit/play-alpha-preparation-20261027/と同audit/review-account-preparation-20261027/。登録・メール確認・Home保持、LIVE限定割引、カードなし0円契約、初回Webhook500、同Subscriptionへの認証連携metadata補記と既存Webhook自動同期を分離して保持する。Android有料gateは本人が無料体験なしで開けたと回答しPASS。Console資格情報／456文字案は保存・再読取PASS。コード・署名・成果物・SDK・既存dirty／Known Goodを維持。追加の運用操作は本人承認の限定割引・本人による正規契約・同契約の通常認証連携metadata補記。送信前準備では再build／upload／deploy／索引変更／DB直接編集／手動Webhook再送／実AI／trial reset／招待／審査送信／新配信開始0を保持。その後、本人承認の14変更を審査送信し、今回証拠は既存Android staging/audit/play-alpha-submission-20261027/へ保存。審査送信後のAlpha実配信は未確認（審査通過後の配信待ち）、Production公開0。

## 2026-10-26 Play配信署名の導入・更新確認（独立VMのPlay経由code1→code2更新・保持PASS）

- 既存の同意対応AAB1.0.1／code2（SHA256 9ac74bc4…b237、artifact ID4860244546361357551）と、9:19 JST配布済みの既存内部release2・本人テスター1名を再利用。再upload／再build／新規配信／招待／審査送信0。Alpha code2下書きと13件審査未送信を20時台にも再確認した。
- 正式Consoleの署名付きUniversal APKを通常native ChromeのDownloadでcode1／code2とも取得成功。前工程のERR_BLOCKED_BY_CLIENTは履歴とし、今回は保護解除・設定変更・回避なし。両APKの公開署名SHA256は現Playのda777b3e65d587ff9808d5b87e08725b6368bd5f2ec1217d3169433c2c6f6115と一致。code2 APKはSHA256 511e1f21bbe8a3049b5fc6f815435f0aa4009cc8e2ade30819a6552dd46c8f31、最終AABと81 native／AOT／資産一致。内部アプリ共有を使わず、この取得自体をPlay Storeクライアント配送とは数えない。
- 既存AVD2台の52ab署名アプリ・データを保護し、既存Pixel7/API34のimageと設定を使い、独立した一時userdataで専用VMを起動。元AVD30ファイルのSHA／size／mtime一致を確認。空VMへ正式Play署名1.0.0／code1を直接新規導入・通常起動PASS（UID10190、初回導入2026-10-26 20:05:49）。これはConsole APKの直接新規導入であり、旧版更新やStore取得PASSとは区別する。
- 本人が専用VMのGoogle Playへサインインし、現内部テスターのアカウントhash一致を確認。その後、旧code1で通常ログインしてPlay掲載画面から既存code2へ更新。20:57:21 JSTに1.0.1／code2へ変わり、installer／initiatingPackageはcom.android.vending、UID10190・初回導入20:05:49を維持。導入されたbase＋3split全4APKの署名検証PASS・DA77一致、arm64 AOTを含む75 runtime／資産が固定同意AABと一致。本人が「再ログインせずHome・既存記録が表示される」と回答し、通常起動・ログイン／既存飼育記録保持をPASS確認。これは実際のPlay Storeクライアント経由の旧版更新であり、Console code2 Universal APKの直接置換ではない。同版再導入は未実施。新AI・同意確定／撤回・trial再開始・データ消去0。
- 普段使い端末の52ab→Play署名移行は引き続き非互換であり、独立VMの成功で元端末の移行完了とはしない。既存ローカル更新の本人PASS、iPhone TestFlight同意UI、Release DeviceCheckサーバー計測PASSは維持。取得APKと証拠は既存Android stagingのartifacts／auditへ保存し、更新前証拠はaudit/play-code1-isolated-before-update-20261026.json、最終更新／本人保持証拠はaudit/Play-store-code1-code2-update-final-20261026.json。今回分の追加本人操作は不要。詳細は[既存Play登録手順「正式Play署名APKの取得・独立環境での旧版更新確認」](docs/release/google_play_submission_runbook_ja.md#正式play署名apkの取得独立環境での旧版更新確認2026-10-26)を参照。新しい管理Markdownは作らない。

## 2026-10-26 同意対応版の内部テスト配布（Androidローカル更新・Release DeviceCheckサーバー計測PASS）

前回の同意実装・限定26件・AAB／IPA署名検証とiPhoneのTestFlight確認を引継ぎ、完了済み検証を再実行しない。今回のAndroidは固定AABから実行コードを再compileせずAPK化し、現端末と同じ既存証明書でローカル上書きした。一般公開審査／公開、他のテスターへの新招待は対象外。

| 区分 | 今回の結果 |
|---|---|
| Android upload | 指定consent-signed AAB（SHA256 9ac74bc4e15497728c77c5736344964fb07d268aefdb972d0006e3d3e860b237）の1.0.1／code2をPlayへupload PASS。Consoleのmin24／target36・3ABI表示を確認 |
| Android内部配布 | 既存internal-testers本人1名を維持。内部track4700142116971858603のrelease2「2 (1.0.1) consent internal test」を保存・配布し、Console「内部テスターに公開・10/26 9:19・未審査」を確認。新招待0、一般審査0 |
| Android端末更新 | ローカル同署名更新PASS／普段使いSM-S911Nの52ab→Play署名移行は未実施・非互換。独立VMのPlay署名code1→code2更新は直上の最終結果PASSと分ける。SM-S911Nの旧APKはcom.gotainu.hamster／1.0.1(code2)、Debug52ab9f…b62e・installer=null。固定同意AABから既存bundletoolでAPK化し、同じ既存52ab証明書で署名。2DEXと81native/AOT資産一致、manifest非Debug・min24/target36、署名・16KiB zipalignを確認してadb install -r成功。10/26 10:45:26更新、UID10405・初回導入10/3 16:38:47保持、導入APK SHA514c000c…db84と通常起動成功。本人が再ログインなしのHome・ログイン状態・既存飼育記録表示を確認PASS。Playの現在DA77、過去AC19／92A9はいずれも52abと不一致。upload7E9Bの登録一致は確認したが端末署名とは別。新鍵・鍵更新・削除・データ消去なし |
| Android同意UI | 固定同意AAB由来のローカルRelease APKは現端末へ導入済み。設定の同意撤回項目表示も本人確認PASS。実AI・同意確定・実撤回は行わず、旧版AI／認証／動画PASSを新しい実AI送信の結果へ転記しない。Play配布版への更新・通常起動／保持は直上の独立VMでPASS。同意UIの追加操作は行わない |
| Alpha差し替え | 同じupload済みcode2だけをライブラリ再利用。Alpha release2「2 (1.0.1) consent Alpha draft」を未公開保存・プレビュー保存し、公開の概要でAlpha行がcode2へ置換されたことを確認。13変更は「審査にまだ送信されていない」のまま、送信ボタン未押下。旧Alpha履歴を破棄せず保持 |
| iOS upload／内部配布 | 指定consent-appstore IPA（SHA256 67a7305d7934adfa0565e1ca6375bd101a16b80dbb274019e4c268483ad8695e）をそのままTransporter1.4.5で1回デリバリ、10/26 9:50 JST「デリバリ済み」。ASC ID6826783734の1.0.1／build2（build ID9257a2fd-43fd-40b0-ba8d-60747e7158d0）登録PASS。本人承認後に標準暗号（OS外同梱TLSを含む）・独自暗号なし・France配布Noの輸出回答を保存しMissing Complianceを解除。既存グループ0／テスター0だったため、手動配布の「本人実機確認」グループ255439d9-ed98-4563-a6df-da297fea0743を作成、既存本人Account Holder1名だけ追加。1Tester／1Build、1.0.1(2) Testing・本人Invitedを確認。新しい他テスター招待・外部beta／一般審査送信0。再build／再export／IPA差替えなし |
| iOS端末更新／同意UI | 本人がTestFlightからHamCareをインストールし、再ログインなしのHome・ログイン状態・既存飼育記録の保持をPASS確認。10/26 10:09 JSTのread-only metadataで同Bundle com.gotainu.hamster／1.0.1(2)を照合。bundle/data container pathは更新、builtByDeveloperはtrue→trueで変化せず、このflagをTestFlight移行の独立証明としない。配布経路・保持の根拠は本人の操作報告、path変化だけでデータ喪失としない。実機同意Dialogの説明表示・送信しない・取消後の入力保持と、設定の同意撤回項目の表示は本人PASS。撤回項目はHamCare左上≡→アプリの設定→下スクロール→SwitchBot連携の下で再案内後に発見。確認画面開閉・同意承諾・保存済同意の実撤回は未確認／未実施として分ける。コード修正なし。新AI・削除・データ消去0 |
| Release DeviceCheck | サーバー計測による実動作PASS。本人TestFlight更新10:09:51 JSTと同じ10:09–10:10のExchangeDeviceCheckToken HTTP200/grpc0を1件、現iOS AppIDのFirestore VALID/ALLOW412件（10:09–10:31）を確認。現com.gotainu.hamsterのprivateKeySet=true、旧com.example.hamsterProjectはfalse・同期間検証0で旧登録との曖昧性を除外。前段SIGSTOP／OS attach拒否はSDK前停止の履歴でありDeviceCheck失敗ではない。今回新attach／SDK明示取得／forceRefresh／AI／認証／設定変更0。端末callback・生token・個別expiryは直接未観測、project交換metricはAppID/deviceラベルなしという限界を明記 |

- 本人の追加確認：Androidローカル更新後の「再ログインせずHome・既存飼育記録／設定の同意撤回項目が表示されるか」への回答「表示されました」を受領し、当該表示・保持を本人PASSとして記録。実AI・同意確定・実撤回は未実施。根拠は既存Android staging/audit/android-local-consent-owner-confirmed-20261026.json。Play版への更新成功とは扱わない。
- 今回の追加証拠：既存Android staging/audit/android-signature-route-resolution-20261026.json／android-local-consent-replace-20261026.json、iOS staging/audit/devicecheck-testflight-readonly-final-20261026.json。ローカルAPKはAndroid staging/artifacts/hamcare-1.0.1-code2-consent-local-existing-key-20261026.apk（SHA256 514c000cb00e61c692685654d41f1a652c78cbc558ad720e7e9e68518c78db84）。Play提出用consent AABと明確に区別する。午前工程ではPlay生成APKのダウンロードがChrome ERR_BLOCKED_BY_CLIENTで停止した履歴を保持。夕方以降に通常native Chromeから正式APK2種を取得し、独立VMのPlay経由旧版更新までPASS（直上参照）。保護解除・回避は行わず、52ab→Playのlineageは未取得のまま。公開鍵3件のdownloadと登録値は独立照合済み。
- 証拠：既存Android staging/audit/play-internal-update-readiness-20261026.json／android-device-package-before-play-20261026.json、既存iOS staging/audit/internal-distribution-owner-update-pending-20261026.json（配布時点）とtestflight-owner-update-confirmed-20261026.json（更新後）／testflight-consent-owner-ui-final-20261026.json（同意UI本人結果）、内部配布／Alpha未送信・TestFlight Testingの画面証拠。新たな進捗Markdownは作らない。
- 維持：通常21日・20件・有限個人／共有枠、trial日時・使用履歴・飼育記録・ログインデータ、既存dirty／Known Good。実AI・体験リセット・権限付与・既存26件／AI／認証／動画の再検証0。Playの自動quick-check表示はストア側処理であり、13変更の送信やアプリ実AIテストを指示したものではない。

## 2026-10-25 通常文字AI同意・最終提出候補（限定検証・AAB／IPA生成PASS）

- 既存最小案どおり、通常文字AIの送信先OpenAI／Pineconeと送信情報を示す事前Dialog、UID・説明版別のSecureStorage同意、設定「データとプライバシー」からの撤回を実装。説明版は2026-10-25-v1。本文・直近会話・関連するペット／飼育記録等はOpenAI、質問由来の検索用ベクトルはPineconeという現処理に合わせ、payloadや共有先は変更しない。別UID／別端末／説明版更新は再同意を要求する。
- 同意は開始イベント・request ID・履歴追加・POSTの前に確認。未同意／キャンセル／戻る／保存失敗では送信を止め、キャンセル時は入力保持・履歴追加0。各待機後・HTTP直前にownerと撤回世代を確認し、二重押下を抑止する。既存再送ID・固定payloadを維持し、送信済み回答は撤回で破棄しない。退会成功時は本人の同意keyだけを削除する。音声同意・trial／通常権限・有限予算・履歴・分析・課金は変更しない。
- 限定26件PASS：Store6／Gate7／Dialog4、実相談画面の同意5＋既存再送回帰4。キャンセル／戻る時のHTTP・履歴0、同意後1送信、二重押下、撤回後の再同意と同じpayloadの再送、token待機中撤回のPOST0／trial消費0を偽の通信で確認。保存失敗・UID切替・版不一致・保存からの再読取も限定テストで確認。実AI／実認証／体験開始0。ソース限定解析はerrors／warnings0・新規指摘0、Settingsの既存非推奨info6件は保持。新規依存／SDK／native／lock変更0。
- 同意対応の最終Android候補：`/Users/gota/hamcare-deploy-staging/android-ordinary-update-20261025/artifacts/hamcare-1.0.1-code2-consent-signed.aab`。1.0.1／code2、160,904,769bytes、SHA256 `9ac74bc4e15497728c77c5736344964fb07d268aefdb972d0006e3d3e860b237`、min24／target36・非Debug。既存upload証明書一致、JAR署名／ZIP／Bundletool PASS。3 ABIのAOTに同意key／説明版を確認。既存成功Gradle等の互換overlayは隔離候補だけへ再利用し、元Android設定を変更しない。
- 同意対応の最終iOS候補：`/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/hamcare-1.0.1-build2-consent-appstore-20261025.ipa`。1.0.1／build2、107,026,058bytes、SHA256 `67a7305d7934adfa0565e1ca6375bd101a16b80dbb274019e4c268483ad8695e`。通常lib/main.dartの新Release Archive→既存Apple Distribution／App Store Profileでexport PASS。codesign strict／ZIP、get-task-allow=false、Apple Default／APNs production、署名を除くArchiveのコード・資産との一致PASS。Archive ZIPは`/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/Runner-consent-development-archive-20261025.zip`、157,948,889bytes、SHA256 `90ced1a78a539f204e22d29c613ffb60f61a001f8e988d7d90c52c24c529c202`。Xcode27.1／恒久Flutter3.47.7と固定lockを再利用し、新資格発行なし。最初のmanual exportは既存Xcode-managed Profileと不整合で停止し、前回成功と同じautomatic exportで解消（allowProvisioningUpdatesなし）。
- 両候補は同じ固定344source fileから生成。以前の同意対応前AAB／IPA／Archiveは削除せず履歴として保持し、今回の提出対象から外す。Play現Alphaの1.0.0／code1は未差替え。次のupload対象は上記consent-signed AABであり、Google Playへのupload／13変更の審査送信と、IPAのApp Store Connect ID6826783734へのupload／審査送信はいずれも未実施。端末へのinstall／上書きも0。
- Release DeviceCheck：前回照会後の対象App ID／provider交換・RAG検証ログの該当は0。既存Release同一processへの一時native attachは成功したが、最初の非送信評価がSIGSTOPで中断しSDK呼出し前にresume指定でdetach成功。providerやtokenの実値は取得できず、実attestationは未確認（FAILと断定しない）。App Check更新0・AI／認証／trial呼出し0、アプリ／署名／強制適用／認証設定は変更なし。証拠不足だけで認証再作成や追加AIを行わない。
- 証拠は既存stagingのauditへ集約：Androidのrelease-aab-consent-signed-result-20261025.json／protection-release-aab-consent-20261025.json、iOSの同意対応Archive／IPA検証結果とtext-consent-20261025-*。最新両版AI各1件・認証保持・両端末動画等の本人PASSは維持し、同意対応候補の実機確認済みとは転記しない。新しい管理Markdown、本番変更、端末更新、ストアupload／送信／公開0。既存dirty／Known Goodを保護。

## 2026-10-25 提出前残件の限定確定（同意実装前の確認・申告確定・配布IPA書き出し）

- 完了済みの最新両版AI各1件、Google実認証／Home／再起動保持、通常権限・trial・記録を引継ぎ、新AI・認証の再試験は0件。既存回答の動画は本人が両端末でタイトル／画像表示と外部動画からHamCareへの復帰をPASS確認。10/1保存回答32/32ケース・87動画のtitle/url/thumbnail契約証拠も再利用し、実機結果とは分ける。
- 通常文字AIの事前同意は不足確定：通常送信処理には送信先・対象データを示す同意分岐／専用記録がなく、音声用SecureStorage同意と新規登録時の一般legalConsentを代用できない。一般同意記録の書込は現Rulesで拒否され得て例外捕捉もあるため、保存成功とはしない。今回の指示は不足時の修正具体化までなので、アプリコードは未変更。最小案は送信前modal、既存SecureStorageのUID＋説明版別記録、設定から本人の同意だけ撤回、各await後の既存owner guard・同意失敗時送信0。詳細・文案・限定検証は既存privacy_disclosure_checklistの「通常文字AIの事前同意：確認結果と最小修正案」。Functions／Rulesやtrialの変更は不要案。
- Android最低OSを本人がAndroid7.0／API24以降で確定。現AABのmin24はFlutter3.47.7標準と保存済み自動migrationに由来し、直接pluginの最大min23とは別。元native min23・SDKは変更していない。旧API23対応成果物は履歴。最低OSだけを理由とする再ビルドは不要で、掲載文にAndroid6対応の約束もない。Play登録済みbundleはcode1のみ、code2検索は「結果はありません」。ただし上記同意UIを反映する最終候補には新AAB／Archive／IPAの生成が別理由で必要。
- App Store Connect ID6826783734のApp Privacyは、実装・公開説明を照合して10typeの用途／アカウント関連あり／trackingなしを保存。Google認証で取得するNameと既存契約分析のPurchase History用途も反映。本人が正確性・適合・変更時更新の最終確約を明示承認し、Published表示を確認。アプリの審査送信・公開とは別。音声は現トラフィック100%のrevisionでAI_TRANSCRIPTION_ENABLED=0、処理後保持なしのApple定義に基づき初版は非収集。端末内処理だけとは説明しない。
- Play掲載名／詳細説明を既存確定原稿へ保存し、21日・20件／体験後の範囲を同期。Data SafetyはOAuth、Name、録音データ転送、UID／購入履歴のAnalytics、飼育コンテンツのApp functionality、診断の機能用途を補正し、実装にない一般Files/Documentsの旧選択を除去して保存PASS。Googleは短時間の端末外転送も開示対象なので音声収集を申告（任意／機能用）。メモリだけの処理を保証できずephemeralはNo。これは長期保存を確認した意味ではない。ストア本文の既存txtも同期。既存13変更を再利用し、送信は0件。
- 13変更の内訳と条件は既存Google Play submission runbook「既存13変更の送信範囲」へ反映。現Alphaは依然1.0.0／code1なので、13件をそのまま送ると旧版が対象になる。最終同意対応版への差替え、決済導線確定／審査説明、通常審査アクセスの確保、送信承認が先。日本設定・内部配布・既存質問票を作り直さない。
- iOSは既存Archiveを再ビルドせずexport。最初はDistribution証明書／App Store Profile不足でexit70。本人がApple Distribution証明書を作成し、Profile作成・取得と書出しを明示許可後、同じTeam・App IDのApp Store Profileでexport exit0。新IPAはApple Distribution leaf一致、get-task-allow=false、Apple Default／APNs production、codesign strict／ZIP CRC PASS。署名を除くAOT・Runner・Flutter engineと資産は元Archiveと一致。元Archive／SDK／iPhone Releaseは保持。成果物と証拠は下記「iOS提出環境」。現在コードの配布署名を確認したもので、同意修正済み／審査適合済みとはしない。
- DeviceCheckは登録・Release指定を維持。10/24以降の対象iOS App ID／ExchangeDeviceCheckToken監査を1回だけ照会して0件（権限拒否なし）。起動や利用プラン表示はtoken cacheの再利用を区別できず、現Releaseの閲覧UIだけではprovider交換成功を証明できない。未確認を維持しFAILとしない。追加AI・forceRefresh・ログ設定変更なし。次回同意修正候補で行うなら、生tokenを出さない非AIの限定attestation確認を別途組み込む。
- アップロード実績：AAB→Google Play、IPA→App Store Connectとも今回0。Apple Privacy回答の確定と、Apple署名Profileの作成取得だけを実施。Apple Case22954972は本人追加返信済み・回答待ちを維持。アプリの審査送信・公開は0。

## 2026-10-25 公開必須残件の再開（本人完了報告反映・実AI再送なし）

- 本人から、最新iOS Release／Android更新版の通常アカウントによるAI相談各1件は完了済みとの報告を受領。未反映だった記録を更新し、再送信しない。過去版の結果の転記ではなく、今回受領した最新両版の完了報告を根拠にする。新しい使用回数・費用・時刻や動画表示の完了は推測しない。
- 初版範囲は本人決定：既存RAGを使用、AI-02の反復検索・BETA-01の専用権限は初版に追加しない。旧「専用beta実装後にクローズド再開」の条件は今回の決定で初版条件から外す。通常21日・20件・有限個人／共有予算と履歴は維持する。
- Apple Case-ID `22954972`への追加返信は本人が送信済みで回答待ち。再送せず、回答に依存する購入導線だけを保留する。
- Play Consoleを現画面で読取り：内部テスト1.0.0／code1の配布、Alphaの1.0.0／code1作成・プレビュー、地域日本のみ、テスター選択は済み。ダッシュボード4/5完了、13変更は審査未送信、現在オプトイン0人、12人・14日条件未達で本番アクセス申請ボタンは無効。古いExcelや準備全体の未着手扱いへ戻さない。管理対象の公開はオフのため、審査送信・公開操作は今回行わない。
- 掲載文の恒久無料との誤認を解消し、21日体験・体験後の有料範囲・作成済レポート閲覧を実装に合わせて確定。本人の①②③明示承認後、公開Privacyの標準User-ID／限定Google Cloud分析とAI送信経路の説明2段落をHostingへ反映PASS。新version `97be910a4b4a9079`、release `1792917972740000`。live13path中privacy1pathのみ変更・追加削除0、他12pathとconfigを保持し、実URL200と承認HTMLのSHA一致を確認。App Store掲載原稿／Privacy URLの下書き保存もPASS。両ストアのデータ種別申告の最終保存・審査とは区別する。
- 初回読取り時iPhone unavailable／Android接続なし。その後本人がiPhoneを接続・ロック解除し、既存Release起動成功（導入／削除なし）。Google本人OAuth→HamCare復帰→Homeを本人PASS、その後同じReleaseの終了／再起動でも再ログインなしのHome・ログイン保持を本人PASS。Firebase Consoleのcom.gotainu.hamster iOS登録はDeviceCheck／App Attest登録済み、ReleaseソースのDeviceCheck指定は維持。既存iOS App ID成功ログの限定照会は該当0、Console集計は複数アプリを含み当該Releaseへ一意照合できず、実attestationは未確認（FAILとはしない）。追加AI0件。
- 提出物：恒久Flutter3.47.7／既存JDK17と成功済みGradle8.14・AGP8.11.1・Kotlin2.2.20を隔離最新ソースへ再利用し、Release AAB build・Bundletool1.18.1 validate・ZIP CRCはPASS。
  - 1.0.1／code2、minSdk24／target36、debuggable=false、160,796,026bytes、SHA256 `cd1f2f791fba3a7c490ffd94e4acb55e81c6f15109c6cfa21416e01b35c866ca`。
  - 未署名版を保持したうえで、本人が明示許可した旧署名設定1ファイルをRAM内参照。設定側JKSは指定JKSとbytesのSHA一致、Playの公開アップロード証明書とも一致し、別名signed AABの署名／JAR／ZIP／Bundletool検証までPASS。秘密値の表示・保存・引数出力なし、新鍵／Debug代用なし。元minSdk23と候補24の違いは提出前確認に残す。
  - 当時の同意対応前署名済み候補 `/Users/gota/hamcare-deploy-staging/android-ordinary-update-20261025/artifacts/hamcare-1.0.1-code2-signed.aab`。160,854,886bytes、SHA256 `b3d496a67ae1631dd9ce03e8e35943e1521113ef126555ac60173b5a19f57615`。未署名版も保持。既存auditのrelease-aab-signed-result-20261025.json／protection-release-aab-20261025.jsonに証拠。元Dart／native／lock・SDK変更0。今回の最終対象は先頭節と「Android提出物」のconsent-signed版。
- iOS配布：初回ローカル照合ではDevelopment／実機Profileは有効、Distribution・App Store Profile／既存Archiveは確認経路に不在。成功済みXcode27.1／恒久Flutter3.47.7／固定lockを隔離再利用し、通常lib/main.dartのRelease Archiveを作成PASS。codesign strict／Bundle・Team・Profile・Apple entitlement・AOT・Release engine・source保護を確認。Development署名（get-task-allow=true）なのでDistribution／App Store exportは未完了。ZIPは既存staging `ios-device-runtime-20261019/artifacts/Runner-development-archive-20261025.zip`、157,930,706bytes、SHA256 `2c0931038ef0649ec137fd94c32cbd1443336a4389d283c4eac3dec0a1e770ae`。新証明書／Profile発行・端末上書き・uploadなし。
- App Store Connect：利用規約は本人同意、アプリ作成および①②③を明示承認。ID `6826783734`／Bundle・SKU com.gotainu.hamster／日本語／既存名称で作成PASS。版1.0.1、手動公開、日本のみ（1 available／174 unavailable）、基準Japan JPY ￥0.00を保存し再読取で確認。既存説明・キーワード・プロモーション文・support URLは再読取で原稿一致、Privacy URLも保存PASS。状態はPrepare for Submission。スクリーンショット・審査用アクセス情報・App Privacy質問票・配布署名／upload・審査送信は別残件。Mac／Vision Pro互換配信の既定値はオンのため、既存iPhoneのみ方針に合わせた提出前確認も残る。アプリ公開は行っていない。
- 今回の保存証拠は既存staging `ios-device-runtime-20261019/audit/asc-saved-result.json`と確認画像、`privacy-hosting-20261025-deployment-state.json`等へ同名非上書きで永続保存。最終保護照合は元880fileの集合不変、変更が既存11Markdown＋承認HTML1fileだけで、アプリsource／native／locks／SDKの追加変更0。新しい進捗管理ファイル・自動AI送信・iPhone上書き0。

## 2026-10-25 Android修正版APKの同署名上書き（当時の記録・実AIは後続本人報告で完了）

- 無料体験開始の拒否原因／修正：startInitialTrialに残った検証UID限定の入口（Auth／App CheckはVALID）と設定不足への誤表示を修正し、通常アカウントへ同じ21日・20回・個人費用枠を適用。trial再開始・期限延長・特別権限の付与なし。
- AI相談の拒否原因／修正：本人1/20回に対し共通枠5/5回・250,000/250,000microsへ到達していたため、既存消費を保持して承認済み累計25回・1,250,000microsへ変更し、RAGの通常契約／体験判定と原因別エラー処理を修正。個人枠・使用履歴のリセットなし。
- 別件のiPhoneホーム起動制限：Flutter Debug JIT制限は上記2つの権限拒否とは別で、10/24に同署名Releaseへ削除なし上書き済み。Home起動・ログイン保持は本人PASS。今回はiPhoneへのinstall／Debug上書き・Xcode／Scheme変更なし。
- Android：SM-S911Nの現行1.0.1／code2から同版の修正版へadb install -rだけで上書き。署名SHA-256・package・要求権限を一致確認し、導入後APK SHAが候補と同一、app UID・データディレクトリ／inode・初回導入日時を保持。通常MainActivityの前面起動と本人のHome／ログイン／既存記録表示をPASS。アンインストール・データ消去なし。
- 更新前後のread-only比較：既検証Android／iOSのtrial開始・終了・利用回数・個人費用枠・使用記録metadataは不変。Android飼育関連6collectionは件数不変（内容dumpなし、現在端末UIDをmetadataだけで断定しない）。認証・Stripe・分析・本番設定／データへの直接変更なし。
- 実AI確認は分離：iOS現行Releaseの追加実AI送信は本人確認待ち、Android更新APKの追加実AI送信も本人確認待ち。過去のDebug版／旧Androidの回答PASSを新版のPASSへ転記せず、自動AI送信0件。
- ビルドは恒久Flutter3.47.7／Dart3.13.5と既存JDK17を使用。Gradle8.14／AGP8.11.1／Kotlin2.2.20・minSdk24等の互換調整と既存Debug署名鍵の明示は隔離作業コピーだけで、元Gradle8.12・AGP8.10.1・Kotlin2.1.0・minSdk23、Flutter／iOS成功構成・pubspec／lock・既存dirty／Known Goodは保持。Android公開用の最低OS方針を変更したものではない。
- 証跡・署名照合・APK・実AIの機種別確認状況：`/Users/gota/hamcare-deploy-staging/android-ordinary-update-20261025/`。git reset／clean／stashなし。

## 2026-10-24 通常アカウントの無料体験・文字AI相談（本番反映・実機回答表示・Releaseホーム起動／ログイン保持PASS）

- 原因：iPhoneの15:16 JST startInitialTrialは403／Auth・App CheckともVALID。配備入口にTRIAL_TEST_UIDS 3件の制限が残り、Flutterが設定不足へ誤変換していた。当日Appleログインの一意照合でiOS UIDをAndroidと別に特定し、両検証rosterの対象外と確認。特別な有料権限やUID追加は行っていない。配備policyは正常な21日・20回・予約50,000micros／本人1,000,000microsだった。
- Androidの15:18 JST /chat 429は本人上限ではなく既存共通枠の到達。本人は10/5 12:00:59Z〜10/26 12:00:59Zのactive trial、1/20回・50,000/1,000,000microsに対し、共通prelaunch_202610が5/5回・250,000/250,000micros。拒否はdispatch／reservation commit前で、当該失敗による追加消費0。期限・履歴・残回数をリセットしていない。
- ユーザーが2対象の本番反映と、使用済み5件を保持したまま共通上限を累計25件／1,250,000microsにすることを明示承認。startInitialTrial入口のUID制限だけを撤去し、分析testOnly分類・21日・20回・個人費用枠・再開始／延長禁止を維持。RAGは明示entitled modeで通常の有効な契約／trialを判定し、既存共有予算ID・履歴・有限上限を必須化。UID rosterは分析区分のみに使用。Auth／App Check・Stripe・実決済は未変更。
- 配備元の固定source archive／immutable imageを照合し、FunctionsはstartInitialTrialだけ（src／libの2file差分）、RAGはentitlement.py／chat_service.pyだけを置換。RAGはhamster-rag-api-00021-pobへ100%、未認証/chat 401・稼働200。Functionはstartinitialtrial-00003-colへ100%。最初の再試行403が旧版00001に流れたことを実ログで発見し、既存の旧revision固定を修正。ACTIVE／source更新だけでは実到達版を保証しないため、トラフィックまで照合した。失敗した再試行にtrial作成・AI消費なし。
- Flutterは個人の期間／枠、短時間送信、運営設定／共有枠、認証／App Check、通信／結果未確認を固定文言で区別し、生の例外を回答欄に出さない。request ID・本文を既存SecureStorageにUID別で固定して再送時に履歴を再構築せず、各待機後にUIDを再確認。他アカウントへの混入・二重履歴・異なるpayloadの409を防止し、自動再送なし。正確な本文がない旧履歴の同文再送は保守的に停止し「新しく相談」で明示開始する制約あり。
- 検証：Functions full tsc build／6件PASS。Flutter関連57件PASS・変更7file analyze No issues、既存権限競合33件も前段PASS。配備中33 Python／Dockerfile／requirementsと一致する実体＋変更2件のRAG関連34件を全通信禁止でPASS。元workspaceのGUI⌘Rで新Dartソースの署名Debug build→上書き導入→Running Runner on iPhone17eを確認。Xcode27.1／恒久Flutter3.47.7／native・署名・lockは保持。
- Android修正版APKは隔離コピーでのみ試行。Flutter3.47.7が要求するGradle8.14に対し既存8.12で停止。旧3.32.8も固定lockが要求するDartと互換でなくenforce-lockfileが拒否。SDK／Gradle／依存を更新せず、候補に自動発生したminSdk24等のnative差分は元へ移植していない。元Android設定39fileとpubspec／lockのSHA不変、APK導入なし。
- 本番反映後、Android本人の新規AI1件が07:11:08Z succeededとなり2/20回・100,000/1,000,000micros。iPhoneは正規操作で10/24 16:13:40 JST〜11/14 16:13:40 JSTの21日体験が作成され、20回・1,000,000micros／testOnly=false。本人が文字AI1件の回答表示を確認し、07:18:52Z succeeded・1/20回・50,000/1,000,000microsに反映。共通は7/25回・350,000/1,250,000micros。エージェントからの実AI0件、個人の手動付与・履歴リセットなし。GUI停止→⌘R再起動もRunningを確認し、開始／終了日時・利用量・成功記録・共通残枠の不変をread-onlyで照合。Androidの回答表示は本人もPASS確認。iPhoneをホーム画面から起動するとFlutter Debug版のiOS14以降のJIT起動制限画面になったため、ホーム起動は未達。これはサーバーtrial消失や再認証失敗とは区別。元Debug構成を変えず隔離した通常lib/main.dartの署名Release AOTをビルド成功し、同Bundle／Team／Profile・Apple entitlement・キーチェーン整合を検証して削除なしで1回上書き。devicectlによるデバッガなし起動成功後、本人が完全終了→ホームアイコン起動でHome表示・ログイン保持をPASS確認。体験開始／終了日時・testOnly=false・1/20回・50,000microsはRelease後も不変。更新でcontainer UUIDは変更したが、Apple TN2285で更新時の絶対パス変更を確認し、path一致を内容保持の判定にしない。container内容のdump・削除・復元なし。
- Release対応は恒久Flutter3.47.7／Xcode27.1と固定依存を使用。候補だけの生成Pods相対参照をpod install --deploymentで再作成し、依存更新なし。元272ソース・native／署名／lock14件・成功Debug主要5件SHA不変。通常⌘RのDebug Schemeは変更しておらず、今後Debugで上書きした場合のホーム起動制限は残る。Release既存App Check DeviceCheckの実attestationは別途未確認で、今回追加AI送信は行っていない。16:39 JST read-only確認時点のAndroidは既存成功追加で3/20回、共通は10/25回・500,000/1,250,000microsへ進行。iOSは1/20のまま、全体使用量の増加を履歴リセットやRelease導入の消費と混同しない。
- 文字送信の直前に音声入力/transcribe 403が1件あり、既存の検証限定・音声停止設定によるprovider実行前拒否と確認。枠消費なし、今回の文字AI成功とは別。音声を独断で有効化しない。
- 分析除外は利用権限と別にread-only照合。既存ダッシュボードの除外18 UIDにAndroidは含まれ、今回のiPhone開発者UIDは含まれていない。ユーザーの明示承認後、ANALYTICS_CONFIG_JSON.excluded_user_idsだけを18→19へ追加し、hamcare-analytics-admin-00002-kibへ100%切替を確認。旧18件・image／code／他config／resources・IAP有効・IAM bindingsは同一。trial.testOnly=false／権限／利用履歴を変更せず、BigQuery再集計も実行していない。分析除外と通常の利用権限は独立。
- 変更はDart4source／3test、Functions1source／1test、RAG2source／5test、本進捗だけ。無関係なUI・分析・記録／課金・本番飼育データ・SDK・Known Good・既存dirtyを保持し、git reset／clean／stashなし。実UID／パスワード／認証トークン／相談本文は永続調査資料へ含めない。証跡／変更前bytes／配備元SHA／承認・実効設定：`/Users/gota/hamcare-deploy-staging/ordinary-trial-access-20261024/`。

## 2026-10-24 元ワークスペースのXcode ⌘R実機起動（PASS）

- 最新の14:43 `PhaseScriptExecution`詳細ログを確認。実効FLUTTER_ROOTは恒久SDKだったが、`.dart_tool/package_config.json`のflutter／flutter_localizations／flutter_test／sky_engineとflutterRootが削除済み一時SDKを参照し、最初にdart_plugin_registrant.dart欠落、その後Flutter型エラーが連鎖していた。14:28の旧キャッシュ障害と区別し、推測による追加設定・キャッシュ一括削除を行わない。
- 保存済み10/19通常ソースを隔離コピーし、恒久Flutter3.47.7／Dart3.13.5、Xcode27.1（27A9275）／SDK27.1、Runner／Debug／lib/main.dart、専用DerivedDataで再ビルド。Dart／Podのlockを固定したままxcodebuild終了0・codesign deep/strict PASS。検証専用entryや一時SDKは使用しない。
- 元では恒久SDK `/Users/gota/tools/flutter-3.47.7-hamcare-ios` の `pub get --offline --enforce-lockfile` で生成参照だけを再作成。現在のSwiftPM／CocoaPods混在構成と固定済みnative版、Podfile・pubspec／Pod／両Package.resolved lock、pbxproj・scheme・entitlement・手動設定を保持。保存成功側CocoaPodsとの差だけを理由にnative版を戻さない。既存875ソースのSHAは進捗更新前に全件一致、欠落0。
- 元の `ios/Runner.xcworkspace` をXcode27.1で開き、接続iPhone17e（iOS26.5.1）／Runnerを選んでGUIの⌘Rを実行。2026-10-24 15:07、Build succeeded（43.0秒）→インストール→Running Runner on 🐰／Dart VM起動を確認。ユーザーもiPhoneの通常画面表示を確認し、ビルド・導入・起動PASS。既存workspaceのDerivedData-HamCare27設定を維持し、CLI限定の追加キャッシュ引数なし。
- 今後開く場所は元プロジェクトの `ios/Runner.xcworkspace`。新SDK導入・依存一括更新・アプリ削除・本番設定／課金／飼育データの操作・Known Good変更・git reset／clean／stashなし。今回Google／Apple認証や公開審査を新たにPASSへ変更しない。
- 成功／失敗ログ、生成設定の前後、固定lock・保護hash、実行引数、GUI結果は `/Users/gota/hamcare-deploy-staging/ios-xcode-manual-20261024/` に保存。一時Runner.appの存在だけで再ビルド可能と判断せず、今回の再実行結果を根拠とする。

## 2026-10-18 実機認証環境の最小更新案（macOS15.6＋Xcode26.3、OS更新承認待ち）

- 限定再確認：MacはmacOS14.8.9／23J631、選択中Xcode16.2（別途15.2も存在）。有線pairing済みiPhone17eはiOS26.5.1／23F81、Developer Mode enabled、DDI unavailable。
- 読取り実機操作1回でCoreDeviceError12040、0xe800010f／kAMDMobileImageMounterPersonalizedBundleMissingVariantErrorを再確認。DeveloperDiskImageのboardID22／chipID33104用variantがない。Firebaseや署名エラーではなく、実機サポート部品のmount段階で停止。既に実施したhardware support更新や署名buildは繰り返さない。
- Apple公式要件でXcode26.3はmacOS Sequoia15.6以降（公式表の対応上限はTahoe26.x）、SDK26.2、Device SupportはiOS15以降。前回答のmacOS26.2＋Xcode26.5/26.6必須という案内は最小条件ではなく訂正。最低候補はmacOS15.6＋Xcode26.3で、現在14.8.9では導入不可。iPhoneのiOS26.5.1という版だけで同版SDKを必須とはしない。
- OS更新はユーザー承認待ち。承認後の最小案はSequoia15.6以降の対応15.xへ更新→既存Xcode16.2を残して26.3を別名で並行導入→当該iPhoneのDDI／実機接続確認。26.3でこの新hardware variantが実際mountできることは未検証であり、認証PASSとはしない。今回OS／Xcodeのdownload・install、Firebase認証／Stripe／本番データ変更、全体再監査や無関係なtestなし。[Apple要件表](https://developer.apple.com/xcode/system-requirements)、[Xcode26.3公式資料](https://developer.apple.com/documentation/xcode-release-notes/xcode-26_3-release-notes)。変更は本進捗と既存署名報告の訂正だけ。既存dirty／Known Goodは保護。

## 2026-10-18 iOS署名・実機認証準備（署名整合確認・実機は新Xcode環境待ち）

- ユーザーがApple Developerの既存App ID com.gotainu.hamster／Sign in with Apple有効／Primary App ID／新規約同意を確認済み。管理画面の追加変更なし。ローカルは全構成のBundle ID／Team／entitlement参照一致、有効なApple Development証明書とProfile内公開証明書一致を確認。既存の新しい明示App ID ProfileにはApple権限・接続iPhone登録があり有効期限2027-09-24、再発行不要。古い同App ID ProfileはApple権限なしのため選ばない。Xcode表示用SignInWithApple metadata3行だけを同期。
- 通常アプリと隔離認証probeの署名付きReleaseをXcode16.2／SDK18.2／Automaticでbuildし、両方終了0／BUILD SUCCEEDED。両成果物のcodesign deep/strict、署名済Apple entitlement、embedded Profile／Team／Bundle／対象iPhone登録を照合PASS。通常版1.0.1+2／arm64／min15、Google Client／URL Scheme一致・probeフラグなし。初回Flutter CLIの汎用署名エラーも保持し、generic iOS destinationのXcodeで成功。新SDK／実機ログイン成功とは区別する。
- iPhone17e／iOS26.5.1は有線pairing済み。ユーザーがDeveloper Modeを有効化し実APIでenabled。実機操作はDDI mountのCoreDeviceError12040／MissingVariantで停止。Apple公式のXcode16.2向けhardware support更新を1回実施、終了0／Install Succeeded／DDI変更後の接続再確認1回も同じエラー。SDK番号だけで断定せず実エラーに基づき、無断OS更新・手動DDI差替えへ広げない。最小更新候補はmacOS15.6＋Xcode26.3へ訂正（直上の限定再確認を参照）。実機アプリ導入とGoogle／Apple承認・Firebase最終ログインは未実施。
- 通常ログインの同意／通知token保存・Home callable／新Auth登録triggerを監査し、本番データ不変条件のため通常mainから実ログインしない。隔離probeはFirebase接続情報を外しAnalytics／FCM自動初期化停止、Google native authenticate／Apple AuthenticationServicesまででFirebase交換なし。probeは通常repoへ反映せず、各プロバイダ承認とFirebaseログイン成立を別判定する。
- 変更はpbxproj metadata3行＋文書3件だけ。課金／本番Functions・Firestore・Stripe設定／既存dirty・Known Goodは保護し、reset／clean／stash、OS・Xcode本体の更新、ストア申請・本番配備なし。[署名・実機結果と再開手順](docs/release/ios_signing_physical_auth_20261018.md)。

## 2026-10-18 iOS公開準備・第2工程（既存XcodeのSimulator PASS・新SDKはOS更新待ち）

- M1 Pro／MacBookPro18,3（14-inch 2021）は対応macOSへ移行可能。ただし現OS14.8.9ではXcode26系を実行できず、新Xcodeの導入・ビルドはOS更新待ち。既存Xcode16.2／SDK18.2とFlutter3.32.8を維持し、DEVELOPER_DIRを検証コマンド単位で指定。OS／Xcode／Flutterのアップグレード、xcode-select変更なし。Flutter3.38の公式Xcode26対応とUISceneの導入時期を確認し、現3.32.8を新SDK対応済みとはしない。ユーザーのmacOS更新画面は今すぐ実行せず、バックアップ・容量・移行版を決めて別工程と案内。
- Firebase管理APIをread-onlyで照合し、メール／Google／Appleが有効、Bundle ID／iOS App ID対応も一致。初回403は割当先header不足で、既存projectをheaderに指定して解決。権限やprovider設定は変更しない。最新の既存iOS SDK設定にある正規Google Client ID／Reverse IDを同期し、GoogleService-Info.plistへ2項目、Info.plistへGIDClientID／URL Schemeだけ追加。API key／App ID／Bundle ID・既存値は不変、OAuth新規作成なし。候補2fileの独立レビューとSimulator内Google SDK初期化PASS。
- 専用iPhone16／iOS18.3 Simulatorを新規作成し、demo-hamcare-ios-stage2＋Auth／Firestore／Storage loopbackだけで既存MyApp／AuthGateと実画面を検証。Functions既定／東京を未起動loopbackへ固定、RAGもloopback、Analytics／FCM停止・AppCheck未起動。登録／再ログインと同UID復帰、初期案内、Home、＋クイック記録、日々の記録、架空保存済みレポート、実戻るボタンの一連シナリオが終了0／All tests passed（最終build43.5秒、test約21秒）。7画面PNGとJSONを保持。測定保存・AI生成・実Stripe・本番ユーザー作成なし。Homeは空データ／初期読込みを含む表示確認で、全backend計算確認とはしない。
- 初回native plistの本番project自動初期化はAuth操作前のguardが停止。隔離native／Dartもdemoへ固定。架空キーのiOS形式エラーと、標準test helperの英語Back検索の不一致も記録し、隔離設定／実ローカライズbutton操作だけを修正して完走。失敗やassertを消して合格化しない。Simulator用test main分岐・firebase_options／7test依存・telemetry停止・fixture・local Rulesは通常repoへ反映しない。
- 残件：ユーザーによるmacOS／新Xcode環境準備、必要に応じ隔離Flutter互換性確認、新SDKビルド、Apple Developerの既存AppID Sign in with Apple capability／profile照合、Google／Apple実プロバイダ認証・URL復帰、署名実機のDeviceCheck／APNs等。Apple providerのServiceID等空欄だけでnative login不備とはしないが、削除時token取消は別確認。Apple決済問い合わせはユーザー担当、課金導線・Paywall・Stripe権限は維持。[詳細とユーザー最短操作](docs/release/ios_runtime_preparation_stage2_20261018.md)。
- 通常repoはplist2件＋文書3件だけ。開始時299file hashと変更前bytesで既存dirtyを保護、Known Good・Functions／Firestore／Stripe設定／APK不変、git reset／clean／stashなし。証拠・通常ソース候補・隔離harness・前後設定は`/Users/gota/hamcare-deploy-staging/ios-runtime-preparation-20261018/`へ保存。

## 2026-10-18 日本限定・iOS／Android公開準備（未署名iOS Debug／Release PASS・決済導線はApple確認待ち）

- 日本限定・両ストア同時公開目標・Stripe第一希望・IAP／Play Billingを現時点で実装しない方針を確認。現行Checkout／Portal・21日カード不要の明示開始trialを読み取り、Apple／Googleの現行公式規則と照合。両社の日本向け外部決済／課金選択制度はストア決済の併設を要求するため、Stripeだけの現行アプリ内購入誘導を適合済みとしない。Googleの購入なし消費専用B案は条件付きで検討可能、Apple 3.1.3(f)はHamCareへの適用確認が必要。マルチプラットフォーム／D-Lab事例だけで免除としない。
- 消費者向け完全Web版は未提供であることを明記し、Apple SupportへA／B案・無料登録／trial・解約専用Portalの条件を尋ねる文案を作成。送信はユーザーが行い、今回は送信・ストア申請・本番配備をしない。[規則照合・問い合わせ文案・iOS結果](docs/release/japan_store_payment_and_ios_readiness_20261018.md)を参照。既存審査メモは適用条件確認待ちの注意書きへ更新し、Stripe維持の希望を審査適合の断定と区別。
- 元294fileのhashを保持して隔離し、既存Dart lock固定で取得。CocoaPodsのUTF-8環境不足と、旧GTM/Core 5.3.1／GoogleSignIn 9.2.0の3.x要求競合を記録。該当Podだけ3.5.0へ再解決し、既存Dart依存のGoogleログイン／録音に必要な登録・transitiveだけ追加。Firebase等の既存Pod版／Podfile／pubspec.lockは不変。独立差分レビュー後、未署名debug・release両方が終了0、Release完了14:09:58 JST、arm64 Runner.app 1.0.1+2／min iOS15／署名なしを確認。検証済み差分がPodfile.lockだけであることを照合し、その1fileだけ通常repoへ反映。Dartソース／課金ロジック／UIに変更なし。
- Bundle ID com.gotainu.hamsterとFirebase iOS設定は一致。Google iOS OAuth client／reversed IDとURL schemeが不足。Appleログインのコード・entitlementはあるが、Console capability／Firebaseプロバイダ／配布profile・実機ログインは未確認。16 native pluginの最小OS宣言は15.0以内、両ビルドのcompileはPASSで、実機動作保証とは区別する。
- ローカルmacOS14.8.9／Xcode16.2／iOS SDK18.2は、2026-04-28以降のApp Store提出要件（Xcode26以降／iOS26 SDK以降）を満たさない。Xcode26系には少なくともmacOS15.6以降が必要。次の最小作業はユーザーのApple問い合わせ送信、対応Mac／Xcode環境準備、正規Google OAuth／Apple providerと署名設定の照合。OS／SDK更新、IAP／Play Billing実装、実AI／実決済、端末導入なし。
- 開始時のdirtyな旧lock・文書、元source hash、隔離source、失敗／成功ログ、差分と未署名Release成果物は`/Users/gota/hamcare-deploy-staging/ios-store-preparation-20261018/`。通常repoの変更は当該lock＋本件文書3件だけ。既存dirty／Known Good／Functions／Stripe／Firestore／BigQuery／APKを保護し、Git reset／clean／stashなし。日本限定のConsole設定と同時公開操作は今回未実施。

## 2026-10-18 運営ダッシュボードCloud Run移行（配備・認証・実集計・4パネル・許可外拒否PASS）

- 既存tools/analyticsのHTML・共有SQL・localhost入口をbyte不変で再利用し、独立Cloud Run `hamcare-analytics-admin`（asia-northeast1）へ隔離11file contextから配備。revision `hamcare-analytics-admin-00001-nqv`、immutable image digestとtraffic100%を実APIで照合。既存Functions／RAG／Firestore／Stripe／Scheduler／APK・BigQuery table/SQL定義は変更しない。
- Cloud Run直接IAP有効・invoker IAM有効。当該service直下のRun invokerはIAP service agentだけ（既存project-level継承権限は不変）、service単位IAP viewerはユーザー明示のGoogleアカウント2件だけ。アプリもGoogle署名JWTのissuer/audience/期限/nbfとemail allowlistを検証し、HTML・APIを保護。allUsers/allAuthenticatedUsersなし。専用実行SAはproject jobUser＋server_events_raw table dataViewer＋GA4 dataset READERだけで、秘密鍵・Mac認証情報をimageへ入れない。
- min0/max1、1CPU/512Mi、request-based、PORT8080。起動時/無人timerのqueryはなく、閲覧中に15分TTL・単一in-flight・既存100MB上限で再集計。既存一般0人/N/A/未接続/更新失敗/古さ・18testUID除外・NULL watermarkの意味を維持。軽量管理用途の計画概算US$0〜3/月（無料枠共有・実query量等で変動）。LB・独自domain・新Schedulerなし。
- 追加認証/同一origin/metadata認証BQ/キャッシュの10限定テストPASS。実配備のsource hash・revision・image・実行設定・IAM差分を照合。初回はOAuth未設定502で閉じていたが、ユーザーが当該serviceのカスタムOAuthをConsoleで自動生成/保存後、未認証の正規/既定URL root/API GETはGoogleログインへ302、refresh POSTは401でHTML/集計を非公開。実ブラウザの許可アカウント認証→実行専用SAのBigQuery実job DONE（113440byte）→4パネル表示までPASS。一般0人、18testUID除外、NULL watermark/率N/A、取得成功2026-10-18 11:43:43.547 JSTを確認。ユーザー提供の実ブラウザ画像で、許可外Google accountのIAPアクセス拒否と、許可アカウントの接続済み表示を確認し、最終E2EはPASS。当該Cloud Run移行の残件なし。個人メールを文書/分析イベントへ転記せず、画像は非公開の復元記録へ保持。収集完了/研究利用等の別判定をPASSへ変更しない。OAuth secretは取得/ログ出力/Git保存しない。
- 正規URL： https://hamcare-analytics-admin-797691641198.asia-northeast1.run.app 。ソースはtools/analytics/README.md、配備前後設定・限定権限・image/context hash・検証/復元手順は `/Users/gota/hamcare-deploy-staging/analytics-admin-cloudrun-20261018/` 。初回は旧revisionがないため、問題時はIAPを維持して当該serviceの外部入口を閉じる。既存table/新しい集計根拠を削除せず、以後は正常revisionへtrafficを戻す。通常dirty/Known Goodを保護、reset/clean/stashなし。

## 2026-10-18 行動分析・最終E2E（Samsung更新PASS／GA4受信・画面確認は参照待ち）

- 接続済みSamsung実機の現行APKと保存済み検証版を署名照合し、一致後に`adb install -r`成功。app identity／dataDir／初回install時刻を維持し、起動後の認証済みHomeでログイン保持を確認。再ビルド・アンインストール・data clearなし。
- 起動時の既存home_viewを1件発生。実SDKサービスでevent_id／app_start／analytics_environment=test／test_only=1／firebase_uid_v1と対象app upload bundle、GOOGLE_ANALYTICS通信成功を確認。AI・実決済・飼育記録保存は0。送信API成功をGA4の受信確定へ昇格しない。
- GA4 Realtime APIは既存認証の参照scope不足で403。再認証・権限変更なし。FirebaseManagementのapp／stream／property549839505対応は一致。BQは日次exportの最新10/16、当日・intradayなしのため新event到着は未確認。設定やapp IDの無断修正・export待ちの繰り返し走査なし。
- 実eventのtest区分が一般SQLの採用条件を満たさず、既存18testUID（B含む）の除外も維持。一般集計は0人。ただし新eventのBQexport後のUID／重複照合は未実施。標準UIDを今回のupload logから抽出できたとは記録しない。
- ダッシュボードHTTPは接続済み、一般0人、N/A、更新日時を保持。失敗なし／stale=false。root／独立agentの各1回の既存tab取得はnative pipe closedで停止し、実画面は人間へ確認依頼中。失敗・古さ表示の既存12チェックは再利用し、再試験・障害注入・UI/SQL変更を行わない。
- 一時debug/log設定3件は元値へ復元。Functions／Rules／Stripe／BigQuery／Scheduler再変更なし。通常dirty・Known Goodを保護し、本進捗だけ追記。端末旧APK・署名・起動画面・実event根拠・GA4参照結果は`/Users/gota/hamcare-deploy-staging/journey-analytics-20261018/final-e2e-20261018/`。残件はGA4受信、自然export、ダッシュボード実画面確認と既記の公開前運用事項。完了済みserver／署名／installは繰り返さない。

- 追記：ユーザーが4パネル（ファネル／継続率／有料転換／A3比較）、一般0人／N/A、取得成功日時の実画面表示を確認。ダッシュボード画面確認は人間確認PASSへ更新。GA4受信と新eventの自然exportは未確認のまま。

- 追記：ユーザーがGA4 DebugViewで09:36:54.997 JSTのhome_viewとanalytics_environment=test／test_only=1を確認。GA4受信は人間確認PASS。Samsung更新・ログイン保持・テスト除外・ダッシュボード表示もPASS、新eventのBigQuery自然exportだけ未確認。追加送信・再デプロイなし。

## 2026-10-18 行動分析基盤の本番接続（server／BigQuery PASS・APKは端末待ち）

- `hamster-breeding-app`／`asia-northeast1`で承認対象15件だけを反映。既存9件を現行配備sourceから隔離した差分で更新し、新規6件を作成。第1段階のStripe最新状態CAS同期・Portal修正も含む。実API／Cloud RunのACTIVE、Gen2 traffic100%、配備64fileのhash、既存のIAM・trigger・timeout・memory・Secret参照を照合。旧4記録triggerの未指定maxがAPI上20へ正規化されたが、既存Runサービス上限20と実効上限は同じ。承認済み20を維持し、Scheduler／Rules／Stripe設定・対象外Functionsは変更しない。
- BigQuery `hamcare_trial_analytics.server_events_raw`へnullable `environment`／`account_classification`／`billing_livemode`の3列だけ追加。旧42列・既存47行、dataset ACL・partition／clusteringを維持。履歴移行・unknownの一般化なし。
- ローンチ前・一般0人の前提と既存Auth UID一覧を照合し、既存18アカウントをtestとして明示除外（Bを含む）。UID一覧はGit外の非公開設定だけへ保存。一般集計はlive＋general＋test_only=falseかつ除外一覧外に限定し、GA4はそのserver rosterへだけ結合。新しいdebug APKもtest区分。
- Bへ接続確認専用metadata1件だけを作成し、Firestore→実ingester→BQを確認。サーバー受理2026-10-18 08:20:38.710 JSTとevent_atが一致、BQ到着08:20:39.730、raw1／dedup1／一般採用0。A1/A2/A3の達成を捏造せず、AI・Stripe決済・飼育記録・既存report・課金状態への試験writeなし。既存GA4／serverの正確なreport JOIN証拠（15表示／1account）は前日の確認を再利用。
- 完成済みHTMLに同じSQLのlocalhost接続runnerを追加。`http://127.0.0.1:8877`で集計のみを返し、15分再集計／手動更新／成功日時／締切／失敗／30分経過を区別。実BQ接続・一般0人・5集計を確認。watermarkはNULLで、収集完了を捏造せず成熟率はN/A。追加12限定テストPASS（既存85件の全再実行なし）。ブラウザ操作接続が停止しており、今回のlive画面の画像／DOM再確認は未実施。HTMLの既存検証を実画面の再確認へ昇格しない。
- 最新第1〜第3段階Flutterを既存依存で隔離debug build PASS、299source／asset／lockのhash保持、前回配備APKとの署名一致。SamsungのADB一覧は空のため、現端末署名照合・上書き更新・起動／ログインと新GA4イベント到着は未実施。保存先は下記リリース領域の`apk/app-debug.apk`。
- 復元資料・前後設定／source／IAM・配備検証・E2E・APK：`/Users/gota/hamcare-deploy-staging/journey-analytics-20261018`。`start-dashboard.sh`で同じprivate設定から再起動でき、runner停止中は更新も停止する。新しい公開API・Looker二重実装・クラウドSchedulerなし。分析の説明／同意方針・ストア申告、GA4/BQの保持・本人削除運用、watermarkの確認手順とtest registry維持は公開前の残件。通常dirty・Known Goodを保護し、今回の8接続file＋文書追記以外にrepoを変更しない。

## 2026-10-17 第3段階③・行動分析とダッシュボード（ローカルPASS／本番計測・Looker反映待ち）

- 既存AppAnalytics／GA4・Firestore journey_events／analysis_events・BigQuery server_events_rawとSQLを再利用。A1の成功・21日trial・初回記録・ready・first／個性レポート生成・表示成功・Paywall／Checkoutの既存イベントを維持し、新規登録、本人の受理済みmanual revisionによる日々の有効利用、確定済み契約の成立／解約予約／終了／支払失敗を追加。新しい健康・予測・課金計算や独立分析基盤は作らない。
- serverでlive/test/emulator/unknownとaccount分類、trusted Stripe livemodeを記録し、一般指標はlive＋general＋test_only=falseに限定。保存済みunknownを後日の再送でliveへ昇格させず、現在のテストUID一覧による除外も優先。GA4標準UIDにevent_id／区分を追加し、アカウント切替の誤帰属とpresentation再送を抑止。観察回答／タグ数／メモ有無の送信を停止。契約イベントはStripeの確定documentと有効期限から判定し、Checkout成功画面を契約の正にしない。既存権限式は不変。
- 新しい非同期metadata writerはsourceと削除開始markerを同一transactionで確認。正規削除は追加metadataをrecursive対象に含め、Auth削除完了までrootガードを保持。Auth失敗／data-only cleanupは最小ガードを残す。変更は新writerが削除後にデータを再作成しないための限定ガードで、既存全データ保持・削除基盤の再設計は行わない。
- 対象限定のread-only BigQuery確認でGA4日次13table／server raw47件、共通UID2アカウント、UID＋pet＋report＋revision一致の実表示15機会／1アカウントを確認。これは既存テスト利用の接続証拠で、一般ユーザー0人の前提を変更しない。新イベントの本番稼働やLookerへの継続接続は未反映。Cloudに永続table／view／dataset／IAMを作成・変更せず、データ変更もなし。
- tools/analyticsに架空metadata→正規化・重複排除→共有SQL→集計JSON／manifest→単体HTMLを実装。4パネルは厳密な順序のファネル、登録JST日をD0とするD1/D7/D14/D21継続、trialコホートの課金率、A3 ready／生成／実表示とlandmark比較。能動利用だけを継続に含め、watermark不明は分母未確定／N/A。課金率は変更可能な分析初期値28日（21日体験＋7日追跡）。A3比較はtrial14日で区分、D21利用・その後〜28日の課金を同一追跡期間で比較し、因果効果とは扱わない。
- 関連85 checks PASS（server22＋既存Stripe回帰1、Flutter15×2環境、集計27、renderer5）、Functions full tsc noEmit／Dart analyze PASS。実BigQueryの完全架空CTEで5集計を実行しSQLiteとの一致PASS。ファネル5→4→4→2→2→2→2→2、継続2/4・1/4・2/4・1/4、成熟trial3中2契約／未成熟1除外。初回BQで予約語AT・最小bytes・fixtureのGA4列名対応を検出し、期待値を変えず原因箇所だけ修正した。既存UI325件・全環境監査・実AI／Stripeテストは再実行しない。
- 最終HTML tools/analytics/output/dashboard.htmlで一般0人／N/Aと架空表示を切替可能。ブラウザDOMで各値と構成を確認。画像captureはCDP timeout／native startup失敗により未取得で画像QA済みとはしない。証跡は /private/tmp/hamcare-journey-dashboard-20261017/audit/（server/client/sql結果、元hash、BQ接続・全5集計parity等）。本番反映前にBQ3列→削除guard→対象イベント／ingest Functions・分類設定→AppAnalytics→到着確認→制限付き集計とLooker4パネル接続が必要。詳細と正確な対象は docs/analytics/trial_journey_schema.md。
- 本番Functions／Firestore／Rules／Scheduler／Stripe設定・APK／Known Goodは未変更。通常dirtyを元hashで保護し、今回のallowlistだけ反映。旧データの一般化・全件移行なし。分析の同意説明／ストア申告、保持・本人削除とoperator権限の運用確認は一般公開前の残件。

## 2026-10-17 第3段階②・既存Stripe Sandbox課金E2E（PASS／本番・APK未反映）

- ユーザーが用意したGit管理外0600設定からtestキーをメモリ内で参照し、指定gota sandbox／既存JPY500月額Priceのlivemode=falseをAPI確認。本番Firebase向きSandbox Webhookがdisabled、ほかの有効外部配送先がないことを確認してから開始。Stripeキー・署名Secretをコード／ログ／Gitへ保存せず、出力に実キーの複製がないことを照合。新しいStripeアカウント・Cloud Firebase project・商品／Priceは作成しない。
- 既存の検証済み最新sourceを隔離compileし、Auth9195／Firestore8795／Functions5295を127.0.0.1のdemo-hamcare-stripe-e2eへ限定。既存Checkout／Portal／Webhook／有料保存確認用saveWeightRecordだけを公開し、他trigger・Schedulerを起動しない。Auth Emulator専用ユーザーを新規作成しtrial未開始、テスターB・本番ユーザーは未使用／未変更。架空profile／記録・不変report fixtureはEmulatorだけに保存。
- 実Sandbox Checkout＋Stripe標準テストカードで契約成立（complete／paid／active）。Stripe CLI経由の実イベントで署名検証→Webhook200→Emulator billingのpaid／active→既存getFeatureAccessと体重保存transactionの許可を照合。Portalから期末解約予約を実操作し、cancelAtPeriodEnd=trueでも期限内の権限を維持。Stripeテストクロックを同じ新規テスト顧客へ設定し期末を進め、実customer.subscription.deleted→canceled／plan none→新規有料記録拒否を確認。既存記録とfirst／日次reportの内容・本人読取りは保持。
- 支払失敗は主Checkout／Portal契約の終了後、同一テスト顧客に補助のSandbox更新検証契約を作り、公式の失敗用PaymentMethod＋テストクロックで実invoice.payment_failed／past_dueを発生。実Webhookだけでbillingがnone／past_dueへ反映し有料保存を拒否、既存reportは読め、既存Portal callableと画面でPayment failed／支払方法更新への入口が利用可。Firestoreの契約状態や期限を手動で捏造しない。実Stripe live決済・実AIは0。
- 実Sandboxイベント13件、6種類（Checkout完了・subscription作成／更新／削除・支払成功／失敗）がすべてローカルWebhook200。別途不正署名400。未契約／active／解約予約／期末終了／支払失敗の5状態で実server権限・保存許可／拒否・report保持をPASS。実Webhook capture4状態を現在のFlutter BillingStatusへ渡す4/4テストもPASS（同じsource hash）。既存325件・UI／初回体験fixtureや逆順／重複mockの再実行は行わない。Flutterの実機課金画面を確認したとはしない。
- 初回のローカル実行失敗は古いCLIのdiscovery環境制限／cloud credential自動注入／Admin namespace関数bindによるFieldValue等の欠落。隔離launcher／wrapperだけでmetadata専用processとruntimeを区別し、credential注入を抑止、実SDKのstatic class3つを復元。demo／loopback／testキーruntimeガードと実業務処理は維持、元source／installed SDK・CLIは無変更。初回Checkoutで作られた1顧客を重複作成せずEmulatorの顧客参照だけ復旧し、有料statusは実Webhookのみから確定した。失敗・成功ログを保持。
- 証跡・確認画像・実event ID／状態／snapshot・hash・秘密値を含まないharness：`/Users/gota/hamcare-deploy-staging/stripe-sandbox-e2e-20261017-173909`（audit/final-result.json、sandbox-event-deliveries.json、state-*.json、access-*.json、PNG／log）。対象8source hash一致、出力へのAPIキー複製0、Auth token／private sessionを永続監査資料へコピーせず、検証用listener・Emulator・戻り先serverを停止し4port閉鎖を確認。Sandbox向きではなく本番Firebase向きだった既存Sandbox endpointはdisabledを維持し、自動復帰しない。
- 変更は本進捗のみ。通常dirty／Known Good・健康評価・UI・課金policyを保護。本番Functions／Firestore／Rules／Scheduler／Stripe live設定・APKへ反映なし。課金E2Eの残件は解消し、ローンチ前に必要な第1段階serverの対象限定リリースと最新Flutter APK／実機課金表示は別途残る。今回のE2E成功を本番反映済み・ストア審査合格とは扱わない。

## 2026-10-17 第3段階②・既存Stripe Sandbox接続の準備（APIキー参照先待ち）

- ユーザー指定の既存gota sandbox（SandboxアカウントID（非掲載））を認証済みDashboardのSandbox表示で確認。既存商品Hamster Care Premium Plan（Sandbox商品ID（非掲載））、既存月額Price Sandbox価格ID（非掲載）（JPY500／月、Active）をread-only確認。新しいStripeアカウント／Firebaseプロジェクト／商品／Priceは作成しない。
- Sandboxの既存Webhook Firebase stripeWebhook sandbox（Sandbox Webhook ID（非掲載））がActiveで、本番hamster-breeding-appのstripeWebhookへ配送する状態だった。ユーザー指示に従い対象と理由を先に報告し、このSandbox配送先だけをDisable。Disabled表示とテスト送信ボタンdisabledを確認、削除・Secret rollなし。本番Stripe設定は未変更。自動で再有効化しない。
- Stripe CLI標準設定、project .env／.secret.local、継承環境変数にSandbox用test鍵の参照が見つからず、安全な保存先のパス／変数名／Secret項目名だけをユーザーへ確認待ち。鍵自体をチャットへ貼らないよう案内。DashboardのAPIキー表示／コピー、コード／ログ／Gitへの鍵保存なし。APIでのアカウント・Price livemode照合、Checkout／署名検証Webhook／Portal E2Eは未開始でPASS扱いにしない。
- Emulatorは既存sourceの隔離コピーと明示demo project／loopbackのAuth・Firestore・Functionsを使い、本番既定設定・credential／.envを継承しない方針までread-only確認。新規専用ユーザーはEmulator内に作成可能で、テスターBの変更は不要。今回はまだEmulator起動・ユーザー作成・決済・Firestore書込みなし。
- 変更は上記Sandbox配送先の停止と本進捗のみ。本番Functions／Rules／Scheduler／Stripe live設定・APK／通常dirtyコード・Known Goodは保護。証跡：`/private/tmp/hamcare-sandbox-e2e-20261017/audit/result.json`、`sandbox-production-webhook-disabled.png`。再開時はSandbox keyを安全に参照し、同アカウント／test PriceのAPI確認→Emulator限定で課金E2Eへ進む。既存の合格済みUI／fixture／Webhook mockは再実行しない。

## 2026-10-17 第3段階②・Stripe環境の限定確認（live参照のためE2E未実施）

- 許可された3つの課金経路だけをread-only確認。Firebaseはhamster-breeding-app／asia-northeast1。稼働中stripeWebhook（stripewebhook-00009-jib）、createStripeCustomerPortalSession（createstripecustomerportalsession-00008-kot）、createStripeCheckoutSession（createstripecheckoutsession-00005-ceb）はすべて同じSTRIPE_SECRET_KEY version3を参照し、実際の鍵をメモリ内判別した結果はlive。秘密値を表示・保存せず、Stripe APIは未呼出し。latestの推定ではなく各配備の参照versionを照合した。
- ユーザーのtest-mode限定条件を満たさないため、対象2Functionsのdeploy・最新APKのbuild／install・Checkout／Portal／Webhook E2Eは開始せず停止。既存test環境への無断切替や新環境作成、Stripe／Firestore／アカウントへの書込みはなし。今回の修正対象はstripeWebhook＋createStripeCustomerPortalSessionであり、Checkoutの追加deployは不要。既存UI・fixture／Webhook mockの成功済み検証は再実行しない。
- trialなしの専用課金テストアカウント、および使用する既存Stripe test環境／対応Firebase接続の指定・確認が残件。テスターBの期限・課金・飼育データは未変更。test契約成立→Webhook→Firestore→client権限→Portal解約／終了・支払失敗は未確認で、課金E2E PASSとはしない。第1段階serverと最新Flutterの修正は未反映のまま。
- 変更は本進捗だけ。通常dirty／Known Good・Functions／Rules／Scheduler／APKを保護。安全な環境確認結果：`/private/tmp/hamcare-stripe-e2e-20261017-162934/audit/`（function-environment-safe.json、stripe-mode-safe.json）。実行設定・Stripe設定の変更、決済・アカウント作成はなし。

## 2026-10-17 第3段階①・未確認項目の限定検証完了（fixture／Emulator PASS・実機focus PASS）

- 既に実機PASSのレポート統合／履歴／既読／trial中の変化タブは再検証せず、残件だけを架空fixture・mock・専用demo Emulatorで確認。初回体験は設定完了／一部skipからmock AI成功→紹介→必要なprofile／直径入力→初回体重／走行保存receipt→Tabs復帰まで通した。体重に不要な環境／飼い主入力を必須化せず、完了flagの再送不変も確認。既存アカウントの初回状態・実AI・実Stripeは使用しない。
- 分析準備の両learning／体重のみready／活動量のみready／両readyをWidget・Goldenで確認。learningは3/7件・8/14日、ready fixtureは7/14以上かつserver状態を使用。短い準備メッセージ・頬袋イラスト・記録／レポート導線、両readyでは既存compact入口を確認。ready条件は変更せず、activity-only Golden1枚だけ追加、既存4枚のbytes不変。
- 明確な不具合を固定時計のRED（7件中3FAIL）で再現：画面を開いたままtrial／有料期限を跨いでもFirestore snapshotが来るまでgateが開く問題、有料期限ちょうどのFlutterとserverの境界差。既存gateへ期限timerとdispose取消を追加、paid期限をserver同様now<endへ一致。注入可能な時計を使用し、UI再設計・21日／AI20件／予算／readiness条件の変更なし。今回のFlutter修正はローカルのみでAPKへ未反映。
- Flutter関連55/55、準備Golden5/5、初回体験／発光focus／保存復帰／flag冪等性7/7、変更Dart7fileのtargeted analyze PASS。サーバーは体重・活動量・観察・ケアの期限直前1ms／到達／後1ms／有料有効を実handler＋Emulatorで19/19、AIの実権限・dispatchをoffline mockで9/9、計95件PASS。期限到達から新規保存を拒否しcurrent／履歴／receipt／報酬が部分更新されないこと、既存first／日次／履歴／既読は利用可、AI残回数・個人／共有予算と期間終了が別判定であることを確認。サーバー実装とRulesの修正不要。
- Samsungでは既存環境編集→直径欄へタップし、focus／数値keyboard表示→保存せずHome復帰を確認。値入力・保存、試験用記録・初回flag・本番trial期限の変更なし。不足項目の自動発光と保存後復帰はfixture確認、初期状態・4準備状態・期限境界は実機確認へ昇格しない。実機画像はaudit/device/09-wheel-focused.png。
- 初回失敗ログを保持：初回fixtureのFlutterFire delegate cache／FakeAsync間Analytics barrier持越し／サーバー確定receiptとrequestの混同をfixtureだけ局所修正し、元の3結合ケースを同時再実行、復帰・保存件数assertを維持。Emulator初回のRules読込失敗はJava日本語localeのbundle欠落で、同じRules／assertを英語localeで19ケース全体再実行して解消。RAGのimport用stubは局所化し、最終bodyの同じ9件を再PASS。単独再実行のみの合格化や期待値弱化なし。
- 変更はFlutter3実装、関連test／新Golden、サーバー回帰testと本進捗。RAG repoにはoffline回帰test1件だけ追加し実装は不変。開始時496fileのhash照合で通常dirty変更を保護。Known Good／本番Functions・Firestore・Rules・Scheduler・Stripe設定・APKは変更なし、全325件の再実行なし。証跡・開始hash・失敗／成功ログ：`/private/tmp/hamcare-stage3-remaining-20261017-155845/audit/`。
- 第3段階②の課金E2Eへ進むための今回の検証残件は解消。ただし実決済／Stripe E2Eは未実施。第1段階server同期修正の対象限定反映と、今回のFlutter期限修正を含む端末更新は別のリリース作業として残す。実機での初回操作感はfixture確認と区別し維持する。

## 2026-10-17 第3段階①・ロック解除後の残り実機確認（確認可能な導線PASS／状態別ケースは未確認）

- ユーザーの解除済み返信を受けSamsungだけで再開。再build／再install／コード修正／全テスト再実行／サーバー作業なし。最終配備版で認証済みHomeを表示し、前回の既読後の新着カードが消え、常設の共通レポート入口だけが残ることを確認。健康警告・下部navを維持し、確認終了時はHomeへ戻した。
- HomeとDrawerから同じ「うちの子レポート」が開き、最新作成日時2026/10/16 09:00 JSTを確認。履歴・10/14の過去日次・10/8の旧個性レポートを閲覧。活動量の直近値はそれぞれ4m／8m／628mで、当時の値が新しい内容へ置換されない表示を確認。履歴に正しい日付と閲覧済み状態があり、過去閲覧後も新着カードは再浮上しない。
- 旧firstは「初回分析の記録」、作成2026/10/7、体重8件、9/22〜10/5だけを表示。存在しない体重・活動量数値は補完せず、不変snapshotを再生成しない。実機画像とUI treeを証跡に保存。表示確認は本番文書の全内容hash比較とは区別する。
- 変化タブの実グラフを閲覧でき、レポート末尾から既存利用プランへ遷移し「有料プランは未契約です」を確認。現在アカウントは有料権限によるbypassではなく、initial_trial_v2ゲートのactiveTrial経路と実装・UIから判断できる。21日終了の境界・開始／終了Timestamp自体は未検証／未変更であり、ここまでを全trial E2E成功とはしない。契約ボタン・実Stripe決済・AIリクエストは操作しない。
- 初期skip A1→A2、learning／片ready、不足直径の発光／focus、実記録の保存・復帰は従来どおり実機未確認。初回完了・両readyの既存アカウントからの推測PASSにしない。新着リンクの色修正は前回の6件PASSと配備を維持するが、既読状態を戻さないため次の自然な新着での実機再確認は未実施。新しい不具合・追加修正なし。
- 変更は本進捗とリリースauditの追記だけ。通常dirtyコード・Known Good・本番Functions／Rules／Scheduler／飼育記録を保護。レポート閲覧による通常の既読・Analytics以外の試験用データwriteなし。残件は上記の状態別確認と課金同期server反映／Stripe試験条件の別途確認。実機証跡：`/Users/gota/hamcare-deploy-staging/ux-stage1-2-device-20261017-125227/audit/device-resume/`（result.json・PNG／XML）。

## 2026-10-17 第3段階①・第1／第2段階Samsung確認（APK更新PASS／実機導線はPARTIAL）

- 当日の現行Flutter・素材316fileを隔離してdebugビルド（既存Flutter／Android Studio JBR／成功済みGradle8.12 cache、依存version変更なし）。第1段階client21日trial／利用プランと第2段階統合レポート・頬袋素材を含む。署名は端末現行とSHA256一致、既存Samsung実機／com.gotainu.hamsterへadb install -r成功。アンインストール・data clearなし。最終APKは配備後hash一致、appId／dataDir／初回install時刻を保持。
- 更新後の実画面でログイン保持、Homeの健康警告を保った新着表示、両指標readyの共通レポート入口、未読カードから最新うちの子レポート（体重100g・参考133g・IQR100〜160g、活動量の保存済みbaseline／直近比較）の表示を確認。レポートを開いた通常の既読／Analytics処理以外に、確認用の飼育記録・状態を直接書き換えない。
- 明確な視認性不具合：dark Homeの新着リンクが暗い青。既存dark quickRecordGlow／light accentをTextButtonへ指定する4行だけ修正、Widget6/6（既存4＋明暗2）・対象2file analyze PASS。追加テスト初回失敗はTextButton.iconの派生型をexact-type finderが捕捉しないharness誤りを修正し、同じ6件を再実行。レイアウト・既読・gate等は不変。修正版も再ビルド・署名再照合・上書き更新と最終APK hash readback PASS。
- 途中で端末がsecure lockになり、履歴／旧first、Home復帰後の未読消去、変化タブ／21日trialと最終版リンク色の実画面は未確認。ロック解除を依頼し、回避・時計／ロック設定変更なし。最終APKのam startはStatus ok、画面の再確認は解除待ち。黒いAOD画像はレポート確認証拠に使用しない。
- learning／体重だけready、必要項目不足時の発光／focus、実際の記録保存後の復帰、設定skip A1→A2は実機未確認。既存アカウントは両ready／初回体験完了であり、mock／GoldenのPASSを実機PASSへ昇格しない。既存の安全な実機fixture入口はなく、フラグや直径の消去・架空記録・実AI requestを使わない。確認できた両ready Home／両指標レポートの範囲では指標有無の矛盾なし。
- 本番Functions／Rules／Scheduler・Stripe設定／決済・データ移行・Known Goodを変更せず、325件全体は再実行しない。通常dirty差分は局所2Dartと本進捗のみ追加。初回verifyのAndroid userId欄期待は実appId欄へ修正し、identityとAPK一致を確定。元ソースの新ViewModel再hashはread待ちで停止したため、そのverifierをinstall前に終了し、開始時にコピーしてhash取得した隔離sourceでbuild/readbackを確認。sourceの修復やdependency更新へ広げない。
- 残件：ロック解除後の上記実機確認、実記録1件での保存・復帰、非完了状態を安全に確認する手段。課金E2E前には第1段階server同期修正の対象限定リリース（今回は未承認／未実施）とStripe試験条件の確認が必要。実決済・AI・研究作業は行わない。
- APK／元アプリ退避・署名・source manifest・screen PNG／XML・限定修正とログ：`/Users/gota/hamcare-deploy-staging/ux-stage1-2-device-20261017-125227`。最終APK：`flutter/build/app/outputs/flutter-apk/app-debug.apk`。再開時は成功済みbuild／server監査を繰り返さず、未確認の画面操作から進める。

## 2026-10-17 分析準備イラスト・頬袋の調整（ローカルPASS）

- ユーザー提供写真を頬袋の形状参考とし、既存analysis_preparing_v1.pngの左右の頬袋をふっくら膨らませた透過画像へ更新。既存の顔・種を持つポーズ・描画スタイル・表示寸法は維持。参照写真そのものや背景・手・食べ物はassetへ追加しない。built-in image_gen編集のpromptはassets/avatars/README.mdへ記録。
- 準備カード・Home／Drawerの影響範囲のみ、関連Widget／Golden28/28 PASS。意図した画像差分7枚を更新し、通常比較・小サイズ／狭幅／文字拡大・明暗の描画を目視確認。イラスト非表示のall-ready Goldenはbytes不変。前項325件の全再実行は行わない。
- 変更は画像asset1、影響Golden7、素材README・本進捗だけ。Dart／分析・課金・報酬・本番・APK・Known Goodは変更なし。今回退避・hash・検証ログ：`/private/tmp/hamcare-ux-stage2-9iy54lx3/audit/pouch-update/`。

## 2026-10-17 第2段階・A1→A2→A3 UX改善（ローカルPASS／本番・APK未反映）

- A1成功後のA2案内を、初期設定の完了／skipではなく初回記録の未完了に接続。既存初回フラグと再送時の無変更を維持。初回記録では本人のprofile／subjectだけを確認し、不足時は既存プロフィール編集へ案内。体重に不要な環境・飼い主設定を必須化しない。活動量の未入力直径は既存StatusCard／AnimatedShiningBorderの強調から環境編集の同じ直径欄へ進み、欄を1か所だけ上部表示・focus、入力で消灯、戻って再読込み。画面表示だけの保存なし。
- 分析準備はModel／ViewModel／共通カードに分離し、サーバーの指標別currentStatus・有効記録数・観察期間・必要量を表示。readyをクライアント件数から推定しない。不足した必要量は確認中とし、体重だけreadyにも対応。「毎日連続でなくても大丈夫。」を明示。既存マスコットを参照した透過イラストを準備カード専用に追加、[素材来歴](assets/avatars/README.md)に生成方法とpromptを記録。育成機能・実ペット写真の代替・avatar状態判定には使用しない。Themeはopt-in tokenだけを追加。
- メインを「うちの子レポート」へ統一。Home・変化・ドロワーは共通navigation、メイン内の履歴からmodern／日次／旧firstを振り返る。メインと実Home未読は同じwatchNewestで生成日時の新しいpointer先を選択し、同時刻は日次を優先。通知からはその正確なIDを開く。既存pointer保存形式は変更なし。履歴は同reportIdのページ重複だけ除去し、異なるsnapshotを内容の類似で消さない。
- 旧firstは既存pathから型付きread-only adapterで読み、生成日時（JST）・当時readyだった指標・保存済み件数／期間だけを簡略表示。存在しない体重・活動量の数値を現在分析で補わない。実在確認前の履歴入口や重複メイン入口を除去。過去snapshot／生成処理は変更せず、既存A3 marker／Analyticsは本人・route表示成功後だけ確定し最初の閲覧時刻を保持。レポートに新しい課金gateは追加せず、末尾に任意の既存プラン画面リンク、未契約説明に継続価値と保存済み閲覧可を短く記載。
- 関連27 testファイル、計325/325 PASS（A1／A2・保存49、レポート192、実Home／Drawer・既読／履歴・準備UI・第1段階trial／課金回帰84。Golden25件を含む）。新準備4枚／統合3枚、既存v3／観察のみ・Home／Drawerの意図差分を目視し、更新なし比較でPASS。日本語固定font・幅360/393/320・明暗／1.5倍文字・下部insetのfixtureを使用。変更39 Dartのtargeted analyze No issues。
- 初回失敗を保持：A1 fixtureのidle Futureがfake／real clockを跨ぐ待機を、実行中だけのlockへ限定して競合条件を保持。必要なflag保存はawait、Analyticsは既存キューで非同期にして遷移を妨げない。直径欄のlazy位置／focus完了、重複page fixtureの日付、統合後のラベル／意図したGolden差分とif波括弧lintを限定修正。assert削除・単独再試行だけの合格化なし。
- 第1段階の課金／21日trial、AI20件・予算・分析ready条件、健康警告の優先順、環境／測定履歴、記録カレンダー・報酬、日次発行・既読・first不変を保持。Functions／Rules／Firestore／Scheduler／Stripe／APK・Known Goodへ変更・実AI接続なし。通常dirty内容は開始時356fileのhashを照合し、今回の差分だけ反映。隔離検証・開始時退避・失敗を含むログ：`/private/tmp/hamcare-ux-stage2-9iy54lx3/audit/`。実機の見え方・発光／キーボード・ログインアカウントでの通常操作は未確認、次回の対応Flutter更新後に確認する。

## 2026-10-17 第1段階・課金同期と21日trialの最小修正（ローカルPASS／本番未反映）

- Stripeのcreated／updated／deleted、Checkout完了・invoice・既存Portalの契約再同期を、subscription IDから最新状態を取得する共通処理へ統一。イベント内の古いstatus／期限を権限の正にしない。既存の別有効契約優先選択を維持し、同一IDが再度activeになった場合も最新list結果を採用する。
- 同一ユーザーのbilling文書を、Stripe取得前のupdateTimeに対するupdate precondition／初回createで確定。競合時はDBとStripeの両方を最大5回まで再取得し、API失敗では書き込まない。同値同期も監査時刻と版を進め、古い進行中の取得結果を遮断する。重複通知は業務状態を重複変更せず、event ID永続基盤・新しい課金システムは追加しない。
- 変化タブを既存initial_trial_v2ゲートへ統一し旧5日判定を除去。体験開始操作、21日期限、AI20件・予約／共有予算、分析ready条件は変更なし。利用プランでは機能権限と既存契約管理を区別し、期限切れactiveを利用中にせず、past_due／unpaidでも既存Portalへ進める。解約予約中の期限内権限は維持。
- Functions関連21/21（新同期17＋既存優先選択4、すべてmock）とTypeScript全体compile PASS。Flutter関連36/36（先行35＋実Tabs接続guard1、権限競合・gate・追加model／Widget）と変更6fileのanalyze PASS。初回compileのStripe Response型と隔離Flutterの不足asset参照を修正し再実行で解消。競合条件やassertを弱めず、実Stripe／本番Firestore／テスト決済には接続しない。
- 本番適用候補はstripeWebhookとcreateStripeCustomerPortalSession、対応Flutter。Rules／Index／Scheduler／Stripe設定・無料体験policy変更は不要。A1→A2、個性レポート、ダッシュボード、健康評価、報酬、既存dirty内容、Known Goodを保護。本番deploy／APK更新／Git reset・clean・stashは未実施。隔離・退避・開始hash: /private/tmp/hamcare-billing-trial-work-46nhmd1n/audit/。

## 2026-10-16 研究初版の窓・L・主ラベル確定（Markdownのみ）

- 採用済み：T0=09:00 JST、T1=翌09:00 JST、(T0,T1]、L=T1+24時間。主ラベルは選択観察の初回回答、訂正版は比較／感度分析用。Lまでの取消は欠測、後続観察へ自動差替えしない。
- 24時間は研究初版の現時点の運用値。将来の実データ評価でpolicy versionを上げて変更可能。以前の記録のL／主ラベル「未確定」はこの決定で更新する。同意・研究利用・学習等の未承認状態は維持。
- dataset契約・両README・研究仕様・ロードマップの該当記述だけを更新。コード／fixture／生成物・テスト再実行・本番作業なし。

## 2026-10-16 予測用学習table materializer v1（ローカルPASS／ローンチ前データ基盤一区切り）

- [dataset契約 v1.7 §17](docs/prediction_dataset_contract_v1.md)と[materializer README](research/prediction_materializer/README.md)へ契約を追記。read-only SnapshotRepository／履歴adapter／既存generator共通core／table serializer／writerを分離。予測T0/T1/L・完成時点はconfigから明示入力し、materializerに09時を固定しない。
- subject、観察／体重／活動／careの保存履歴、既存profile／environmentの時点解決API応答＋全根拠revision、sensor quality／terminal evidenceをcanonical inputへ正規化。実際の保存契約に沿い、care／envのsubject対応は独立した期間根拠がある場合のみ。履歴前・時期不明・未回答・実測0・PARTIAL・device未知を区別し、現在値で過去を補わない。profile／env resolverを新実装／SDK importせず再利用する境界とした。
- 既存generatorへcanonical入口を追加、行・label・featureの選択は唯一のgenerateRows／既存selectorで共有。旧wrapperの7行・manifest・hashは固定codeIdentityで変更前と完全一致。source scan不完全とsensor内部PARTIALを区別し、特徴量はunknown品質へ、観察scan partial／unknownはhold・復元不能はineligibleとして未確定ラベルをクリア。材料不足をnormalにせず、任意sensor不足で有効体重を破棄しない。
- 生成物は全行JSONL／意味同値のtyped-JSON CSV、candidate／excluded JSONL、effective config、manifest、audit／execution metadata。source／config／code／Catalog・window・state／reasonと内容hash、artifact hashを保存。日時・run_idを意味内容hashから分離、IDはローカルalias、同point／row重複拒否・run directory排他作成で上書きなし。Parquet／新しい依存基盤は追加しない。
- 完全架空snapshot E2Eで7行（技術候補4／label_missing2／hold1）。alphaの42→44g、環境23→28cm、実測活動0、同一観察normal→slightlyConcerned、取消後無差替え、履歴前unknown、device未知のsafe omissionを確認。候補は研究利用承認ではなく、全行researchEligibility／Prediction Readyはnot_assessed。fixtureの必須feature未指定では、任意値が欠測でも有効labelを持つ行は技術候補になり得る。
- 既存83を含む関連132/132 PASS（共通generator94、adapter23、CLI E2E7、materializer/writer8）、両tsconfig strict noEmit PASS。SDK／network拒否・credentialなし・異TZ、入力順hash一致、JSONL／CSVのnull/0/false/quote/改行/Unicode同値、同runId拒否・既存bytes保護を検証。先行REDで観察source不完全による誤確定・featureIdsの過剰alias・scan不完全による誤採用を局所修正し、期待値弱化なし。Node22.23.1／既存固定TSを使用し依存version変更なし。
- 代表の新規不変tableはresearch/prediction_materializer/examples/synthetic_v1へ保存。旧generator examplesは当時のcode identityを保持して変更しない。検証隔離・開始時保護情報・ログは`/private/tmp/hamcare-materializer-v1-xhl8d1wr/audit/`。今回の変更はresearch領域＋Markdownのみ、本番Functions／Firestore／Rules／Scheduler／APK／Known Good・通常dirty内容は保護、Git操作なし。
- ローンチ前の保存・ローカルtable生成基盤は本工程で一区切り。live/test-account adapterは未追加、CLIはsynthetic以外を拒否。実データ抽出・研究利用／学習・予測／shadow／RCTは開始せず、L／主ラベルは上記で採用済みとし、同意・撤回・保持／削除、source完全性／個体対応の研究確認・モデル採用／Prediction Readyは未確定のまま。

## 2026-10-16 架空fixture専用の予測用データセット生成器（ローカルPASS）

- [dataset契約 v1.6 §16](docs/prediction_dataset_contract_v1.md)へ今回の架空検証条件を追記し、[research/prediction_dataset](research/prediction_dataset/README.md)へTypeScriptの純粋関数・固定架空runner・JSON／manifest正本を分離。既存日付・Observation／Care Catalogだけを再利用し、本番Functionsの公開export／SDK初期化へ接続しない。ロードマップに最小参照を追加。
- 09:00 JSTの(T0,T1]、観察時期とoriginal受理の両窓、受理順・信頼sequence／安定ID fallback、同一観察の初回値とLまでの訂正版、取消欠測／無差替え、訂正での適格性無効化を実装。Lとデータ完成基準は外部必須入力、L前はhold。T0より後のrevision・利用可能情報を特徴量へ混入せず、未来revisionの存在も採用特徴量の品質へ漏らさない。
- feature別採否とrow採否を分離。実測0・未回答・非実施・unknown・PARTIALを保持し、PARTIAL observed1を日平均／完全coverageへ昇格しない。model入力候補にはfeatureEligibilityを明示し、任意センサー不足で他の有効情報を破棄しない。全行の研究利用／Prediction Readyはnot_assessed。
- 完全に架空の2030年・synthetic_ fixture：7起点、10観察、20feature revisions。代表生成は候補2／欠測3／不適格2、初回normal→訂正版slightlyConcernedの同一観察1件。保留は別fixtureで検証。型付きJSON＋manifestをexamplesへ保存し、配列順・timezone・繰返し実行で内容hash一致、入力不変、audit実行日時を別管理。
- 関連83/83 PASS、TypeScript strict noEmit PASS。事前期待値を置き、境界ns／隣接窓、後入力、L前後、訂正・取消、不正revision／順序、PIT・0・部分品質、Unicode含むhash再現性をassert。SDK・network拒否／credentialなしで実行。先行REDで検出したrevision検証・時間逆行・Unicode順序・明示feature採否を局所修正し、期待値／assertの弱化なし。既定Node18は既存ICU欠落のため既存Node22.23.1を使用し、依存version変更なし。
- 今回は研究ローカルコード＋関連test／架空examplesとMarkdown3件だけ。開始時hashで既存dirty内容を保護。本番／Firestore／Functions／Rules／Scheduler／APK／Known Good未変更、実データの読取り・コピー／一括抽出・学習／予測／シャドー・同意自動付与・Git操作なし。Lの研究採用値、初回／訂正版の最終選択、同意・撤回・保持／削除、モデル／Ready／表示試験は別途承認待ち。
- 隔離検証証跡：`/private/tmp/hamcare-synthetic-dataset-rwv4igrw/audit/`。実データへ接続する次工程は未承認。

## 2026-10-16 センサー工程の区切り・学習データ契約具体化（Markdownのみ）

- 取得品質基盤の初版実装・通常取得／根拠保存・v2期間query・新snapshot作成readbackを工程完了として記録。snapshot全体品質はPARTIAL、observed有効reading1件、旧形式・device／個体対応・予定枠・測定鮮度のunknownを維持。研究利用／Prediction Readyは未判定。追加再集計・poll・deploy・不明補完開発へ戻らない。
- [dataset契約 v1.5](docs/prediction_dataset_contract_v1.md)へ推奨と代替・理由・承認待ちを集約。09:00 JSTの(T0,翌09:00]、観察／受理の両窓で適格性＋original受理順という変更案、初回値維持／訂正版別案、取消欠測／次候補差替え別案、L候補と未承認の猶予、遅延実行とcausal replayの区別を記録。旧submitted-only案を経緯／代替として残し、数値や研究規則を確定しない。
- feature別のPIT・品質採否とrow全体の個体／label／同意・必須feature gateを分離。センサー1件を日代表値／十分なcoverageにせず、nullを0へ補完しない。研究利用scope・撤回後の新規利用停止・原記録／派生／モデル／backup・保持／正規削除・法務倫理確認の実施前決定事項を整理。90日保持の自動採用なし。
- 後入力・訂正・取消・時刻不明・部分センサー・label欠測を架空例で確認し、旧JSON例のE後1時間の時刻を除去してL未承認のholdに変更。次の候補はfixtureだけの窓／label／feature gate／manifestのローカル純粋関数とテスト（別承認）。実データ抽出・予測器・シャドー・学習は未着手。
- sensor契約／研究仕様／ロードマップは最新状態と主契約への最小参照、進捗を含むMarkdown5件のみ変更。リンク・表／JSON・未承認表示・差分範囲を静的確認。コード／テスト・本番Firestore／Functions／Scheduler／Rules／Index／TTL／APK・Known Goodは変更せず、Git操作なし。通常dirty内容を開始hashで保護。

## 2026-10-16 修正版品質snapshot再集計（PARTIAL／新規保存・readback PASS）

- 検証済みquality.ts（SHA256 `5f8cccab26226a7df6b2e49076956342d281cea17ad7d0ccc34ef8da86ebe7bb`）とacquisition.tsだけを隔離し、Node22.23.1／固定依存で新しくcompile。実行JS hashとmodule解決先・quality/read仕様v2を確認し、旧compiled JSを使わない。成功済みテスト／本番設定監査は再実行しない。
- 元live snapshotの期間・device・完全cutoffを元実行記録と照合して再利用。期間2026-10-16 JST、UTC `[2026-10-15T15:00:00Z,2026-10-16T15:00:00Z)`、cutoff `2026-10-16T03:20:15.594000000Z`を秒／nanosecondのTimestampへ復元。今回生成日時は2026-10-16 13:27:57.424 JSTで、過去の知識締切と分離。
- 元snapshot `e2942b968d256fcc2e546bd72e80d3a2a2cc79ba678ea0c023eb6704bf34af86` → 新snapshot `0914f4f3457697f3d3f2738a03373b00816926ccf15d3b6f633f38a0116a496b`。supersedesSnapshotId／集計仕様sensor_acquisition_quality_v2／読取仕様sensor_quality_window_read_v2を保存。再集計1回、新create-only snapshot1件だけを作成しreadback一致、元snapshotと既知attempt/readingの内容・updateTime不変。
- string／Timestamp期間queryはcomplete、3,000件上限未達。延べ走査はattempt3＋reading77＋state0（reading77は旧形式inventory64を含む）。候補reading13のうち、cutoff・device根拠が確認できるobserved有効reading1件（温度1／湿度1）。確認済み試行1、失敗・未完了・手動試行0。cutoff後の値は採用しない。
- 旧形式全populationを64件で証明できずlegacy_timestamp_population_unverified、期間内旧readingのdevice_membership_unknownが残る。全体件数／有効値数・取得／受理分布・空白はnull/unknown、observedだけを部分実績とする。予定分母expected_schedule_unknown、割合・機器鮮度もunknownを維持。クエリ完走を全データ品質の確定としない。
- 最初の確認用harnessは保存・内容readback後にgeneratedAt=createTimeの過厳な等値assertで停止（実差63.511ms）。再集計・再作成せず新旧snapshot＋既知attempt/readingの4文書のみreadonlyで確認し、今回生成時刻・不変性を確定。失敗logも保持。
- writeは新品質snapshot1件のみ。poller再deploy、Rules/Index/Scheduler/TTL・接続設定・追加API取得・APK／端末・通常source・Known Good変更なし。進捗Markdownだけを開始hash照合して更新、Git操作なし。永続実行証跡・ソース／JS識別・引数・結果：`/Users/gota/hamcare-deploy-staging/sensor-quality-reaggregate-v2-20261016-132757`（audit/result.json、audit/runtime-identity.json）。

## 2026-10-16 センサー品質の期間読取り・未確定値修正（ローカルPASS／本番未反映）

- 原因は旧readerが全期間のreadingを文書ID順で3,000件まで走査し、aggregateで初めて期間を除外すること。前回の別アカウント／同device、2026-10-16 JST、cutoff12:20:15.594 JST・page100/cap3000を実artifactで確認。通常取得／保存側の再検証や追加poll・設定変更はしない。
- production変更は共通sensorQuality/quality.tsのみ。string UTC／Timestamp tsの期間query＋ts/document snapshot cursor、同budget内の最大64件旧形式inventory、reading参照attemptの優先確保と遅延reading補完を実装。既定3,000/hard5,000・全kind合算上限を維持し、旧形式母集団を未検証ならpartial、query範囲completeと区別する。
- 集計spec v2／read spec v2。実走査・選択数はroot readDiagnostics、読めた観測はobserved、期間全体のcount/validValueCount・時間分布/空白は未確定ならnull／unknown、完全な実0件だけ0。未知device・受理不明・欠落tsを安全に扱う。cutoff後を観測へ混ぜず、空白の右端はmin(end,cutoff)。新snapshotはoptional supersedesSnapshotIdで同owner既存snapshotを参照しcreate-only。過去snapshotは不変。
- Unit30/30（既存23＋新規7）、専用demo Emulator16/16（既存6＋新規10）、TypeScript noEmit PASS／skip0。期間外3,001・同時刻page・JST/締切/nanosecond・真の上限・旧形式・境界前prepare/翌日応答・旧cutoff後65件・attempt上限・snapshot不変を確認。初回の旧0期待は本要件どおりnull＋observed/statusの強いassertへ更新、mockのexistsを実SDK契約へ合わせ、既知otherdeviceの除外をコード側で修正した。assert削除・単独再実行だけでの合格化なし。
- 共通コード修正のため本番再集計／snapshot作成は未実施。旧partial snapshotを上書きしない。次回承認後に新quality moduleを使う明示実行経路で同期間/cutoff＋元snapshot参照の1件を作成する。公開Function/定期jobからqualityへの呼出しはなく、今回のためのpoller再deploy・Rules/Index追加は不要。
- 旧形式の全件検証／device対応ができない範囲、正規予定分母・率・機器鮮度はunknown。入力版やbounded読取範囲が変わる場合に旧cutoffのhash同一を無条件保証せず、過去snapshot不変と区別。[契約§11](docs/sensor_coverage_contract_v1.md)へ根拠と制約を集約。隔離検証・変更前hash・結果：`/private/tmp/hamcare-sensor-quality-window-v2-c9fw5r30`。
- 今回の変更6fileだけを開始時hash検証後に反映。ポーリング・API回数、Scheduler、Functions配備、Rules/Index/TTL、本番reading・設定・環境評価・飼育記録・report、APK／端末、Known Goodを変更しない。通常dirty内容を保護、Git操作なし。

## 2026-10-16 センサー通常取得E2E（PASS／品質snapshotは部分取得）

- 前回の取得候補1件はTest User Bではなく別アカウント。現行のregistry・device設定・paid権限条件を満たし、資格情報の取得・表示やBへの連携追加なしで、12:14 JSTの通常Scheduler実行を確認。
- 実行候補→invocationId→attempt→readingのID／参照／ts／原子的受理時刻を照合し、API200／provider100・温湿度有効・保存成功、環境latest／当日historyの更新と同実行の完了logを確認。必須取得根拠の欠落なし。正規groc予定枠・機器測定時刻／鮮度・未登録個体対応はunknownを維持。
- 既存buildAndSaveSensorQualityを1回だけ明示実行し、不変snapshot1文書をcreate／readback照合。対象2026-10-16 JST、知識締切12:20:15.594 JST。attempt1件確認、失敗／未完了／手動0。readingの全期間document ID順scanが3,000件上限に達しpartial、新readingが取得集合に入らずreadingSaveUnknownCount=1／confirmed_reading_missing・集計内有効値0を返した。実際のreading欠落／取得0件を意味せず、件数・時間分布・空白を完全な実績として扱わない。予定分母／率はexpected_schedule_unknown、鮮度もunknown。
- snapshot以外の本番writeなし。確認したattempt／readingの内容・updateTime不変、追加API取得・手動poll・Scheduler強制実行・再deploy・設定／Rules／TTL・コード／APK／Known Good変更なし。確認用harnessの初回参照は旧環境historyの日付ID形式を誤り、集計呼出し前・write前に停止。既存YYYYMMDDへ参照だけ合わせて再開し、assert削除・本番修正は行わない。
- 証跡は `/Users/gota/hamcare-deploy-staging/sensor-quality-v1-20261016-112428/audit/data/natural-e2e-confirmed.json`／`snapshot-result.json`。残件はreadingの完全取得による品質確認。今回は承認の1 snapshotで終了し、上限引上げ・再集計・追加基盤修正へ広げない。

## 2026-10-16 センサー取得根拠・品質集計リリース（サーバーPASS／自然取得未確認）

- Project hamster-breeding-app／asia-northeast1。削除ガード先行→限定Rules→poll3件→新config triggerの順で5件だけ反映。全5 ACTIVE／traffic100%、配備ZIP63fileのbyte一致、既存IAM／env／timeout／memory／スケール等保持を確認。revisionは[取得品質契約§10](docs/sensor_coverage_contract_v1.md)とrelease-result.jsonへ集約。
- 本番同一source4件を基準にセンサー差分のみを隔離し、src／lib計8artifactだけ変更・削除0。ローカルの未反映trial権限／module、RulesのAI feedback・研究基準差分を除外。既存本番paid-only条件、温湿度・健康評価、readiness／report／報酬処理を維持し、通常treeの別変更は巻戻さない。
- 現行Rulesへ新3collectionのserver-only deny13行だけ統合。ruleset5810e42e-8bd6-420f-bf0d-7ed3851b91c2／SHAc0edc3982ca93233790e07b7629c104c8147b35a39ec0431083f29b5ac0300c1。隔離sourceの49件、fresh統合RulesのEmulator5件PASS／期待値変更なし、既存150件の結果を再利用。Node22親子9process確認。
- Scheduler every60minutes／UTC／ENABLEDの定義不変、新job・強制実行なし。既存接続＋現行資格から自然取得確認対象を選択し、Bのdeviceを仮定しない。確認時は次の通常実行前で自然取得E2E未確認、品質snapshotは条件未成立で未実施。追加SwitchBot API実行・Firestore business write0。
- 既存不変report4文書の内容hash／updateTime不変、非存在1も作成なし。飼育記録・接続設定・first・履歴の試験write／移行／再生成なし。削除ガードは実配備確認、境界検証は既存Emulator結果を利用し、本番アカウント削除なし。
- TTL／自動削除を有効化せず、90日保持は案。運用ログと長期根拠の保持、一般公開／研究利用前の同意・削除範囲をロードマップ／契約へ追記。追加8read・2writeは現時点見積もり、再試行・品質集計は別。根拠削除後の再現不能範囲を明記。
- リリース退避・設定／コード・実配備照合・判定・復元手順：`/Users/gota/hamcare-deploy-staging/sensor-quality-v1-20261016-112428`。新writer稼働中に削除ガードのみを外さず、復元でも根拠を削除しない。Flutter／APK／Samsung・モデル作業なし。通常source513fileの範囲固定harnessで今回Markdown3件以外の変更・削除0を確認、Known Good未アクセス、Git操作なし。

## 2026-10-16 60分ポーリング取得根拠・Silver品質（Phase A／BローカルPASS）

- [取得品質契約§9](docs/sensor_coverage_contract_v1.md)へ今回の確定差分・コスト・検証を集約。既存の60分／UTC、利用資格・対象選択、温湿度／健康評価式を維持。UI／Flutter・Golden・APK、実API・本番・Schedulerは変更しない。
- 共通取得helperへserver受理start／一度だけのterminal、API／有限値／保存の品質、現在登録のdevice／subject・環境参照を追加。安定したacq IDとfingerprintで並行・再送・ACK喪失・fallbackを処理し、品質復旧だけの追加poll／reading増殖をしない。根拠障害時は既存取得をunverifiedで継続、pendingを成功扱いしない。
- configの新trigger sensorPollingConfigurationWrittenが既存選択／登録／解除の意味ある変更だけを不変stateへ保存。正規groc枠・連続対象／資格・物理設置は不明を維持。旧データへ現在個体や24枠／日を遡及適用しない。
- 期間／JST境界／nanosecond知識締切の共通集計を、明示内部API＋不変sensor_quality_snapshotsへ実装。read-only transactionでpage取得し上限／page失敗はpartial、同枠dedup／manual分離、未来を除く端／最大空白、分母不明と0を区別。健康特徴量・readiness・report・rewardへwriteせず、自動毎時の全履歴scanは接続しない。
- 削除後の非同期イベントによる履歴再作成を防ぐため、既存deleteMyAccountAndDataへ必要な開始barrierだけを追加。全新writerは同じ現在設定の存在／blockをtransactionで検証。通常の根拠障害と削除停止を分離し、遅延create／update／deleteとAPI待ち・品質保存競合でも再作成しない。本人も含めclientの新3collection read/write禁止、既存reading閲覧／device選択権限を保持。
- 最終：新規単体／統合49、専用demo Emulator24（並行・保存失敗・PIT・不変snapshot・Rules・正規削除）、既存関連77、計150件PASS／skip0。Functions compile／noEmit PASS。既存健康／baseline／Insight／first freeze／trial／報酬の関連回帰PASS。UI変更なしでFlutter／Goldenは対象外。
- 初回Emulator ja_JP resource欠落は英語localeで同じassertを再実行、依存読込み停滞はpackage／lock一致の既存依存へ隔離stage参照のみ切替。依存更新／テスト弱化なし。通常dirty treeは対象file開始hashを照合して最小反映、Known Good未変更、Git操作なし。証跡・変更前退避：`/private/tmp/hamcare-sensor-quality-v1-ugllqh9g/`。
- 本番未反映。候補は既存poll3件＋deleteMyAccountAndData＋新config trigger、限定Rules。Phase Bは内部明示実行のみ。90日保持案はTTL未設定、予定枠の外部証拠・連続資格履歴・運用保持／研究同意・Prediction Ready閾値は未確定。研究抽出・予測器・モデルは作らない。

## 2026-10-16 センサー取得品質・coverage契約 v1（設計完了／未実装）

- [設計契約](docs/sensor_coverage_contract_v1.md)を追加し、dataset契約・ロードマップへリンク。既存SwitchBot／Firestore資料の15分記載は、現行と異なる旧説明である旨だけ追記。既存計算式・保存schema・コードは変更しない。
- リリース記録を先に確認し、対象switchbotPollerと単一Scheduler・配備source ZIPのGETだけで照合。2026-10-16 10:22 JST時点でevery 60 minutes／UTC／ENABLED、revision switchbotpoller-00026-kec／generation1790992428798739。取得・保存・全対象処理・定期handlerの4blockはlocalと一致。全Functions／全クラウド監査は行わない。
- tsはAPI応答後の保存直前プロセス時計、createdAtはserver commitであり、機器の測定時刻・独立実測・鮮度の証明ではない。現行は取得経路／device／予定枠・試行／対象履歴が不足し、保存件数だけから予定取得率や稼働率は確定しない。既存環境評価の件数上限・固定時間換算・Silver fallbackと新品質を分離する。
- 次工程の最小attempt／policy・device対応履歴、完全な期間read、Silver品質と不変snapshotへの接続、正常／失敗／接続初日／manual／再試行／遅延／同値／旧設定不明／部分取得の架空検証例を記録。保持90日は運用案で未確定、groc予定枠の証拠・同意・Ready閾値等も未確定。
- Markdownのリンク・変更範囲を確認。実装テスト・追加poll／SwitchBot API実行・Firestore個人データ取得／抽出・本番write／deploy・Functions／Rules／Scheduler／APK・モデル・Git操作・Known Good変更は行わない。既存dirty変更は対象Markdownの開始hash照合で保護。

## 2026-10-15 走行記録の測定期間選択撤去（全体PASS）

- 走行入力の「回転数を測った期間」プルダウン・必須確認・画面内timing stateを撤去。「日付の確認→回転数入力→保存」に戻し、代替dialog／別の期間入力は追加しない。距離preview・編集・取消・直径訂正、旧記録の個体確認と同期待ち再送は維持。
- DistanceRecordsRepoで新規／期間未保存を既存unknown契約に統一し、記録日から暦日coverage・夜間・午前0時・保存時刻を実測期間として作らない。同日の既存timingは保持。日付選択は対象日のcurrentを読み直し、別の日の期間は継承しない。従来どおり活動のlogical日付移動は未対応。最新の競合recordを確認した後も、古い画面のtimingを上書きしない。
- 関連Widget／Repository／quality／Golden計55件PASS（新規13、走行Golden2更新・体重Golden不変を含む）、変更2production＋関連5test Analyze No issues。初回44PASS/11FAILはテストのFilledButton.icon探索と入力後pump不足であり、検証helperだけを修正して同じ一式55件を再実行PASS。失敗ログをaudit/attempt1-related-tests.logへ保全。393px darkと320px文字1.5倍の描画を目視確認。
- 検証済み隔離sourceのproduction差分は走行Widget／Repositoryの2件のみ。APK build PASS（72.84秒）、端末現行署名 PASS、install-r PASS、起動 PASS、login PASS。APK `/Users/gota/hamcare-deploy-staging/distance-period-ui-20261015-212721/flutter/build/app/outputs/flutter-apk/app-debug.apk`。前回成功のFlutter/JDK／隔離Gradle cache・依存versionを維持。アンインストール・data clear・本番記録の試験保存なし。
- サーバー既存unknown契約で保存可能なためFunctions／Rules／Firestore／Scheduler変更・deployなし。履歴・受理時刻・subjectId・receipt・報酬、健康評価・Insight・課金・AI・onboardingは変更せず、Known Good未変更、Git操作なし。現在のdirty treeは対象fileの開始hash一致を確認して最小反映。設計はdocs/measurement_and_profile_history_v1.mdへ追記。証跡・今回変更前file退避: `/Users/gota/hamcare-deploy-staging/distance-period-ui-20261015-212721`。

## 2026-10-15 測定・個体属性履歴 v1リリース（サーバーPASS／全体PARTIAL）

> 後続の端末更新再開で署名・install-r・起動・ログイン保持PASS。以下は初回未接続時の記録。確定証跡は前工程stageのaudit/device-resume/result.json。

- Project `hamster-breeding-app` / `asia-northeast1`。新callable4件と既存saveMainPetProfileのみ反映し、全5 ACTIVE・traffic100%、配備src/lib/package（30files）が隔離候補とbyte一致。対象外42 Functionsのresourceは不変。既存profileはsource限定updateでIAM2種・env・timeout・memory・concurrency等を維持し、Function/revision上限の未指定→20だけが既承認差分。Run serviceの実効上限20は不変、未設定復元作業なし。親・解析子Node22.23.1を確認。
- 現行配備ZIPを基準に検証済み4source差分のみ反映し、未反映の別35moduleを除外。package/lock/Catalog正本・生成物を保持。既存の観察／ケア／環境履歴、カレンダー・UIを取りこぼさない。新callableは既存Auth必須・App Check採用方針を維持し、匿名5入口の401 UNAUTHENTICATED拒否をDBアクセス前に確認。
- 現行本番Rulesのpet_subjects／weight／distanceの3blockのみ統合、他の権限byteを保持。限定Rules11＋既存再帰削除1の専用Emulator12/12 PASS。反映Ruleset `2f51e7b6-275e-4222-842b-666e81397f9f`、SHA256 `96eefd88361fdb67117e65630ae02bc0e889db2496356b7538721f71e2d829c5`一致。履歴・受理日時・receiptは本人read/server-only write、current直接writeの迂回を閉じた。新Index/Scheduler/既存triggerの変更なし。
- サーバー反映前後、Test User Bの既存88文書は内容hash・createTime・updateTime／collection件数不変。記録変更、subjectId強制初期化、履歴全件生成、報酬初期化、既存first/v1/日次report再生成なし。履歴は正規UIの明示保存時から開始し、初回以前を推定しない。正規削除は現行実装が追加17pathsを再帰削除し別owner17を保持することをlocalhost/demoで確認、本番削除なし。
- APK build `PASS`、署名 `not_connected`、install `not_attempted`、起動 `not_attempted`、login `not_inspected_not_connected`。APK `/Users/gota/hamcare-deploy-staging/measurement-profile-history-v1-20261015-194924/flutter/build/app/outputs/flutter-apk/app-debug.apk`。通常ソース／依存versionは未変更。既存Gradle cacheの欠落を切り分け、各中断・失敗ログを残し、必要な生成cacheを隔離して再生成した。詳細試行記録はaudit/apk-build-result.json／audit/device。アンインストール・data clearなし。人間による実際の測定保存・再読込は未実施。
- 今回APKは前回リリースAPKと署名一致。最終ADB確認は端末0件のため、現在インストール済みアプリとの新たな署名比較・上書き更新・起動・login確認は未実施。接続後は端末更新だけを再開し、成功済みサーバー作業は繰り返さない。
- 実機導線：Home下部＋→体重／走った記録。プロフィールは左上メニュー→ペットのプロフィール→必要ならプロフィールを編集。正しい種類／生日は閲覧だけでよく、保存確認は実際に追加／訂正する記録1件だけ。架空の値・取消・日付境界を本番で再現しない。
- 退避・復元: `/Users/gota/hamcare-deploy-staging/measurement-profile-history-v1-20261015-194924`（audit/rollback.md、baseline/backend/security/device/data）。旧profile revision/sourceは復元証跡だが属性履歴に未対応のため無条件にwriterを戻さず、編集停止または互換性のある修正と連携する。生成済み履歴を削除せず、旧Rules／旧APKの直接保存を無条件再開しない。dirty code・Known Goodを保護、Git操作なし。研究抽出／モデル／同意付与／ラベル確定／センサーcoverage／新属性UIは未実施。

## 2026-10-13 体重・活動量・個体属性履歴 v1（ローカルPASS／本番・APK未反映）

- ユーザーによる前工程の観察保存・再読込の実機確認完了を受け、[測定・属性履歴の設計](docs/measurement_and_profile_history_v1.md)を実装。dataset契約§14・ロードマップ・MATOMEへリンク。今回の実装対象は体重、活動量、既存species／birthdayのみ。承認済み記録入力・カレンダー／環境UXへ戻らず、予測・研究抽出・センサーcoverageは未実装。
- 新saveWeightRecord／saveDistanceRecordとreadMeasurementHistoryAtを追加。現在の日次契約を維持し、logical record ledger／不変revision／day対応索引／mutation receiptを同transactionで確定。subjectId・expectedRevision・同mutation別内容・日付衝突を検証。同値はreceiptのみ、取消はtombstoneとcurrent削除、体重の日付訂正は両日を原子的に変更。過去の距離は元直径を保持し、明示直径訂正だけ再換算。実測0と欠測、日付のみ／時刻不明／ユーザー申告時刻を区別。受理経路・数値単位を明示し、測定Evidenceへmemoは複製しない。
- 既存saveMainPetProfileを拡張し、pet_subjects下へspecies／birthdayの属性だけを追記。名前／画像の編集でsubjectIdは不変、属性履歴は増殖しない。生日のdate_only／approximate_date／unknown／legacy_unspecifiedを保持し、readMainPetProfileHistoryAtで評価日と締切までの生日から年齢を導出。旧属性・測定へ一括IDや架空の受理履歴を付与せず、明示save時の確認値からだけ導入。取消済みledgerも個体混合防止へ含める。
- limited Rulesは本人read／server-only write。weight／distanceの旧直接writeを閉じて履歴迂回を防ぎ、本人のreadとserver保存時の既存trial／billing資格判定・取消権限を維持。既存の正規recursive account deleteは全追加subtreeを含み、別owner保持をEmulatorで確認。local revision判定上限2,000では明確な拒否、部分current更新なし。
- Flutter production10件に共通MeasurementHistoryClient／MeasurementInputViewModelと既存Model／Repository／入力の最小拡張。短い時期選択・旧個体対応確認・直径訂正・取消を使用。競合と同期待ちで入力を保持、owner切替中はsubmitせず、再送成功後はserver currentを再読込して後続訂正／取消を表示。未知speciesの旧profileを名前編集だけでシリアンへ変換しない。活動の日付移動は既存導線にないため新設せず、未対応の訂正ボタンを除去。
- Functions Unit98/98（測定15、属性12＋既存観察9、健康／体重Insight／first freeze／報酬等62）、Emulator230/230（測定27、属性14、既存観察15、体重Insight7、Rules／正規削除167）PASS。TypeScript noEmit PASS。同mutation並行・別内容拒否・stale競合・強制transaction中断で、current／履歴／receipt整合と部分保存0を検証。測定currentから既存health readerと報酬handlerへ到達し、再送／取消／再保存でも二重報酬なし。
- 失敗を隠さず証跡を保持：最初の依存読込／localhost接続はassert未到達で停止し、package-lockに一致する検証済み依存・専用localhost権限へ切替。測定fixtureの変数誤記／取消に保存専用field混入は局所修正後に全27再実行PASS。属性の1ns fixtureはFirestoreがmicrosecondへ切捨てるため1,000ns保存確認／999ns除外に修正、純粋resolverの1ns境界テストは維持。既存観察並行の初回14/15失敗はEmulatorのcode3『Transaction is invalid or closed』。fixture消去前にsubject/event/revision/receipt各1、current整合、同mutation正規再送、別内容拒否、部分保存0を確認し、元の競合条件を保った全15再実行PASS。無視・直列化・assert削除・production回避なし。
- Flutter107/107（今回42＋既存65、Golden今回3＋既存体重2を含む）PASS、変更15Dart Analyze No issues。393px light/dark・320px文字1.5倍の入力を描画・目視。初期の狭幅overflow／dialog controller寿命不具合は修正し、旧GoldenのsetUp失敗はTZ指定漏れで、既存画像・assertを変更せずTZ=Asia/Tokyoで全batch PASS。前提不足の初回Functions health scoreテストはstage compile前のlib欠落で、compile後に同batch62全PASS。
- 本番Firestore／Functions／Rules／Scheduler、飼育記録／残高／first／発行済みreport、APK／実機、Known Good、Git変更操作なし。health／baseline／readiness／Insight／報酬・課金／AI／オンボーディング計算は変更しない。通常dirty treeは対象ファイルのpreimage hashを確認して局所反映し、無関係な変更を巻き戻さない。証跡・描画・変更前の局所退避は`/private/tmp/hamcare-measurement-profile-history-v1-a4hc8b2l/`。
- 本番適用は別承認で、新callable4件＋既存saveMainPetProfile、限定Rules、対応Flutterの順に整合させる。新Index／旧版共存／全件移行は今回追加しない。研究同意・ラベル確定／取消後の採用規則・鮮度・Prediction Ready数値・センサーcoverage／独立時計・旧記録の個体対応は未確定または未対応。

## 2026-10-13 永続個体ID・観察回答履歴 v1リリース（サーバーPASS／APK生成PASS／Samsung未接続）

- 新callable3件と既存取消報酬guardだけを hamster-breeding-app / asia-northeast1へ反映。saveMainPetProfile=`savemainpetprofile-00001-ceb`、saveDailyCheckin=`savedailycheckin-00001-zuv`、readDailyCheckinHistoryAt=`readdailycheckinhistoryat-00001-cot`、starDailyCheckinWritten=`stardailycheckinwritten-00004-vov`。全4 ACTIVE/traffic100%、配備ZIPのsrc/lib/package byte一致を確認。対象外39既存Functionsはresource hash不変（Eventarc filter配列順のみ正規化）。Node22.23.1は親・解析子PATHとも固定。
- 既存starはbuildConfig.source限定更新で実行設定／IAM／trigger／envを保持、承認済みFunction・revision・Run service上限20も維持。新3件は検証済みregionのみの標準callable設定（256Mi/CPU1/60秒/concurrency80、Function revision max未指定・Run service max20）。Auth本人限定・DBアクセス前の匿名401拒否を3入口で確認。App Checkの新強制・Scheduler／Index・他Functionsの変更はなし。
- 元の競合失敗はEmulatorのlock timeout→「Transaction is invalid or closed」。変更なしで元の4ファイル並行59/59 PASS。厳格な追加stress初回は4 PASS/2 code3 FAILを証跡に残し、全成功と扱わない。一方のraw messageは未保存で同時刻logとの対応は推定。SDKの再試行判定とのmessage不一致を切り分け、失敗直後の保存整合性と正規再送のassertで部分保存0、current・履歴・receipt整合、同mutationのID増殖0、別内容拒否／stale revision競合を確認。訂正の再送は明示競合拒否、報酬は元handlerの並行再送で回復し各1を確認。実装の直列化・例外無視・assert削除・production修正はなし。Emulator特性を本番無発生の保証とはしない。
- 現行本番Rulesのprofile／checkinの2 blockだけ統合、44/44 Emulator PASS後反映。ruleset=`98de9fe2-d884-4c53-97fc-394ccfc07da3`、SHA256=`340e6567c660df4ace56d9efcc9d8eda5fd80038a3a644f64c60dc5290e5706a`。通常clientのsubject/current/history/receipt改ざん・直接保存を閉じ、本人readと既存再帰削除を検証。他の記録／課金／環境／report等のRules byteは保持。
- Bの既存61文書とcollection数をreadonly比較し、fields hash/createTime/updateTime不変。既存記録・残高／付与／first／v1／発行済dailyは変更なし。正規save・profile初期化・取消・backfill・架空回答・強制発行は本番で実行しない。初回subject/historyは人間の明示save時に作られ、旧記録の個体対応・original回答を捏造しない。
- 対応Flutter505filesを隔離し、前環境releaseからの意図したproduction8 Dart差分を確認。assets/pubspec/lock/Catalogは維持。debug build1回87.9秒PASS、APK SHA256=`fae93a39bb1d978f5cb38caeedd8f18c7c4d3eaf519524eb5d2d71c92cc89db6`。旧release artifactと署名一致、package com.gotainu.hamsterを確認。Samsung実機は最終ADBでも未接続のためfresh端末署名照合・install-r・起動・ログインは未確認。APK保持、アンインストール／data clearなし。全体判定PARTIAL。
- 導線はHome下部「＋」→「今日の様子」。実際の観察だけを時期確認して保存・再読込する。既存回答では「入力の訂正／新しい観察」を選択可能。取消・並行等の境界はEmulator検証を使い、本番で架空回答を繰り返さない。
- 退避／APK／復元: `/Users/gota/hamcare-deploy-staging/observation-history-v1-20261013-093740`（audit/release-result.json、audit/rollback.md）。旧star00003-rup・旧Rules・旧release参考APKを保持。端末未接続のためfresh installed APK退避はまだない。履歴を削除せず、旧APK／旧Rulesの直接保存を無条件再開しない。通常tree552filesは今回進捗・設計release追記2件以外保護、Known Good未アクセス、Git操作なし。研究／モデル・体重／活動／属性履歴・個体入れ替えUIへ範囲を広げない。

## 2026-10-13 永続個体ID・観察回答履歴 v1（ローカルPASS／本番未反映）

- [設計契約](docs/observation_history_and_subject_identity_v1.md)を実装し、データセット契約・ロードマップ・資料索引へ今回の範囲を追記。既存main_petスロットを維持し、server発行subjectIdとプロフィールmutation receiptを導入。同じ個体の編集はID不変、再送・並行保存はtransactionで保護。既存記録へIDを一括付与しない。現行UIに入れ替え導線はなく、UID単位の旧記録・分析と混ざる条件でのreplaceは拒否する。
- daily_checkinsのschema2 currentを維持し、observation_days配下のoriginal event・不変revision・receiptと整合して確定。初回／入力訂正／別時点の新観察／取消を明示区別し、originalと受理順・根拠revisionを保持。旧回答の初回履歴は捏造せず、無変更saveはeventを増やさない。1日2,000revision上限では明確なエラーを返し、current単独更新や自動履歴削除をしない。
- 観察時期の不明／日付のみ／ユーザー申告時刻とserver commit acceptedAtを分離。知識締切readはその時点のrevisionだけを参照し、原回答・訂正／取消状態・復元不能理由・Timestampのnanosecondを返す。日付開始や受理時刻を実観察時刻にしない。別日間の同一受理時刻の順序、ラベル確定締切・訂正／取消後の選択・研究同意は未確定で、研究採用の判断は実装しない。
- 承認済み入力に短い観察時期・訂正／新観察・取消操作だけを追加。owner別pendingの同じmutation再送、確定receipt、cancel後の回答／タグ／メモ同期と最新server currentの再読込を実装。自動normalを項目別明示回答へ変えず、ケアだけsaveから健康回答を生成しない。履歴への新triggerは追加せず、既存currentの分析経路を再利用。取消による旧回答の投影はcondition報酬・継続達成の新規付与を抑止し、報酬額・共有枠・猶予／失効式は維持。
- Functions関連unit132件（新規9を含む）、TypeScript noEmit PASS。専用localhost/demo Emulator329の異なるケース（Rules／Storage／正規削除262、Admin保存・報酬・体重59、観察pipeline8）を確認。既存並行報酬の1ケースは初回Emulator transaction競合で失敗し、同じケース単独再実行でPASS。未修正の失敗は残していないが、全batchの再実行はしていない。
- Flutter関連99件PASS（新規Repository／Model13、Widget9、Golden3と既存74・既存care Golden4）。変更11 DartファイルAnalyzeはNo issues。新規dark／訂正light／狭幅・文字拡大をローカル描画し目視確認。既存健康／Insight／first／trial／ケア／環境・権限の関連回帰を確認。本人限定read・client直接write禁止、履歴／receiptを含む既存再帰削除を専用Emulatorで検証。
- 通常dirty変更を開始時SHAで保護し、隔離ステージで検証した今回ファイルだけを反映。依存version・Catalog正本／生成物・健康算出式・Silver／Gold・レポート生成・Home／カレンダー・課金／AI／オンボーディングは変更なし。Git操作・Known Goodアクセス／変更・本番read/write／deploy・APK／実機更新・研究抽出／学習は行わない。
- 将来の反映は新callable saveMainPetProfile／saveDailyCheckin／readDailyCheckinHistoryAtと既存starDailyCheckinWrittenの取消投影guard→現行Rulesへ限定差分を統合・検証→対応Flutterの順。体重／活動／属性全履歴・センサーcoverage・個体入れ替えUI／全source分離は次工程。本番反映は別承認で実施し、履歴や既存不変レポートを移行・再生成しない。検証・描画・反映前local退避: `/private/tmp/hamcare-observation-identity-v1-32dil4la/`。

## 2026-10-12 予測用データセット契約 v1（設計文書のみ）

- [データセット契約](docs/prediction_dataset_contract_v1.md)を作成。ユーザーの明示指示で初期主目的を次の明示全体観察回答（T-O）、活動量予測を補助候補へ更新し、ロードマップ／研究仕様へ決定とリンクを追記。以前の優先関係は経緯として保持。モデル採用・Prediction Readyの数値閾値・実行Gateは未確定。
- 個体×予測基準時刻、知識締切・観測／受理の分離、source別の履歴の有無、main_petスロットと生物個体の区別、欠測／自動normal／部分日の非実施、submitted-answerとobserved-windowの区別、immutable入力／予測と訂正outcome、再現性／同意／削除／評価splitを設計。架空の採用・除外・保留例を掲載し、現在存在しないrevision等を将来案として明示。
- 飼育環境履歴の実機UX完了は今回ユーザーが報告。入力・記録カレンダー・環境履歴の再調整へ戻らない。本作業では既存Markdownと不足箇所のローカル保存契約だけを確認し、コード変更・テスト・モデル実装／学習・本番調査／抽出／変更・APK更新・Git操作・Known Goodアクセスは行わない。

## 2026-10-12 飼育環境履歴の本番／Samsungリリース（本番・APK PASS／人間の保存確認待ち）

- 本番 hamster-breeding-app / asia-northeast1 へ新 callable 2件だけを配備。saveBreedingEnvironment=`savebreedingenvironment-00001-faz`、readBreedingEnvironmentAt=`readbreedingenvironmentat-00001-xel`、全2 ACTIVE/traffic100%。既存care sourceのpackage/lock/dateKeyと照合した隔離9filesを使用し、配備ZIPの全file/byte一致を確認。Node22.23.1はCLI本体・解析子PATHとも固定。新規定義regionのみの標準callable設定（256Mi/CPU1/60秒/concurrency80、Run service max20）を記録し、既存Functionsへ設定を適用しない。
- Firebase Auth本人限定・匿名2入口のUNAUTHENTICATED拒否をDBアクセス前に確認。App Checkの新たな強制は追加せず既存認証callable方針と一致。新サービスの標準callable呼出権限のみを作成、既存IAM/trigger/runtime/health計算を変更しない。対象外38 Functionsの全resource hashはeventFilter配列順序だけを正規化すると反映前と一致、updateTime/revision不変。Scheduler2件・Indexも不変。
- 現行本番Rulesから環境blockだけ統合、専用Emulator235/235 PASS後に反映。ruleset=`de6dca67-b4c2-47d4-92e5-2228f91f2bfc`、SHA256=`ed3cd3b60878b451be536bbaac476196a7e4373c19a4d6631f52b5713b12ef00`。main_env直接client writeを閉じ、本人のrevision/receipt読取りを追加。他の記録・課金・report権限は全byte保持。初回snapshotは正規UIの明示保存時のみ。
- Bの反映前後・Samsung起動後55 documentのfields hash/createTime/updateTime完全不変。main_env/revisions=0、mutations=0のまま。飼育記録・残高/実績・first/v1/過去daily・readiness・pointer・trial/billing/onboardingの変更なし。Firestore business write/初期化/移行/強制発行/架空変更/過去距離再換算は行わない。既存削除の再帰コードとEmulator削除PASSを再利用し、revision/receiptも削除対象であることを確認。本番アカウント削除は未実施。2,000件上限はメモリのみの2境界ケースでもwrite0で拒否確認。
- 検証済みFlutter全169libを照合してdebug APK1回build PASS（51.6秒、依存/設定変更なし、既存隔離Gradle cache使用）。APK SHA256=`e2053121c7ef15f530d825973cc1b54440df48d1a11f6e653955d5cf7c4459ba`。Samsung実機/com.gotainu.hamsterのfresh旧APKと署名一致後install-r1回Success、installed APK/hash/cert一致。app UID/firstInstallTime/data directory identity保持、アンインストール/data clearなし。
- MainActivity起動Status ok/PIDあり。端末はKeyguardロック中のためログイン済み画面と環境save/readback/historyの人間確認は未実施。導線は左上メニュー→ペットのプロフィール→飼育環境を編集→変更履歴。変更がなければ現在値の確認保存で初回snapshotとしてよく、架空の変更・訂正を繰り返さない。
- release/APK/直前Rules・APK/ソース・実設定/復元手順: `/Users/gota/hamcare-deploy-staging/environment-history-v1-20261012-194309`（audit/release-result.json、audit/rollback.md）。復元でも生成済みhistory/receiptを消さず、旧アプリ/旧Rulesの履歴迂回saveを無条件再開しない。通常tree470filesは本進捗・設計書のrelease追記2件以外不変、Known Good未アクセス/未変更、Git変更操作なし。

## 2026-10-12 飼育環境変更履歴・予測用の日時整合（ローカルPASS／本番未反映）

- ケア入力・継続貯蓄・記録カレンダーの実機UXはユーザー承認済みで完了。今回そのUI・報酬・猶予／失効へ戻らず、[環境履歴v1](docs/environment_history_v1.md)を実装。ローンチ前・一般ユーザー0人、旧版共存／一括移行なし。
- 既存main_envの文字列・タグ・メモ読み取り契約を保持。明示saveで初期snapshot、変更／訂正／取消の不変revisionとmutation receiptをnested collectionへ保存し、currentとtransactionで確定。expectedRevision競合／再送／同値保存、owner限定read／client write禁止、既存再帰アカウント削除を確認。メモ本文／センサー認証情報は履歴へ複製しない。
- effective（不明／JST日付のみ／実施時刻）とserver acceptedAtを分離。retrospectiveとknowledge cutoff APIを追加し、初回以前の補完を禁止。後入力・後日訂正を当時の予測入力へ混ぜず、日内不明の観測は曖昧さと根拠revisionを返す。過去訂正は後続変更・currentを維持。底面積は共通正規化で導出し、不明／不正は0にしない。
- 既存環境フォームに変更時期の明示確認／入力訂正／変更履歴入口を追加。historyは変更項目・日付が中心、内部情報は詳細。サーバー受理確認前は保存完了とせず、owner別secure pending draftを同じmutationで再送。過去distanceの直径／距離、ケア床材交換、健康式／Silver／Gold／reportへ新計算・自動変更を追加しない。
- Functions unit新規19＋既存49 PASS、TypeScript noEmit PASS。Emulator120ケースPASS（環境22／新Rules30／既存ケア・Rules48／継続20）。保護fixtureのfirst／v1／日次report内容・updateTime、fixtureのhealth／readiness／trial・billing／AI／onboarding／care・rewards／distance不変を確認。新保存callableからこれらへの直接writeはなく、既存環境triggerと受理後のプロフィール完了更新は維持。継続の並行テストは混合実行で一時transaction closed、独立最終実行20/20 PASS、既存コード変更なし。
- Flutter新規29＋既存50 PASS、Golden5、対象12Dart Analyze No issues。393px昼夜／320px文字1.5倍の入力・履歴を描画。承認済みcare／calendar、Theme、健康・Insight・課金・onboarding・依存設定は不変。履歴はtransaction最大2,000 revisionで安全に停止し、将来大容量のcheckpointは別設計。
- 今回本番deploy／Firestore本番write／APKbuild・更新／実機操作／Git操作／Known Goodアクセスなし。本番適用時は新callable2件と限定Rules差分、対応Flutterが必要。実機UX・本番適用は未確認。
- 隔離検証・描画・元source退避: /private/tmp/hamcare-environment-history-v1-9jm70a4h/（ui/、work/audit/と直下の検証ログ、local-previous/）。元dirty treeの開始時SHAを照合し、対象差分だけ反映。

## 2026-10-12 記録カレンダー導線統合（UI・APK反映PASS／実機目視待ち）

- Home本文の「今日の記録」見出しと常設たくわえ／直近7日／今日の星ブロック、直前の専用余白だけを除去。健康評価・重要警告・未読レポート・AI・下部ナビ／＋・ケア入力・保存後フィードバックは維持。
- 「今日」AppBar右上に既存カレンダーアイコンを1つ追加（48px以上、アクセシビリティ名「記録カレンダー」、バッジ／残高なし）。ドロワーの星／種累計専用入口も「記録カレンダー」1項目へ統合。両入口は同じ `_TabsScreenState._openRecordCalendar()` で既存 `DailyStarsScreen` を開き、戻ると元の画面へ戻る。画面タイトルも統一。
- 承認済みHero／連続帯／月切替／実達成と休み／今日／猶予／再開／ヘルプ／補助3枠を保持。「これまでの実績」へ保存済み実達成日数・累計獲得数・恒久保有数を分けて表示。旧累計画面への実行時導線は除去し、旧画面・Model／Repository／付与・milestone処理自体は保持。報酬／換算／D+1保持・D+2猶予・D+3 JST0時失効を変更しない。
- ローカル関連115件PASS（重複除外、Golden14件含む）：既存関連41＋新navigation6＋Golden14＋保存／報酬／レポート回帰54。実Tabsの両入口・戻る・記録入口、server受理後の再表示、実達成日と観測日の区別、星／種、月切替、280px／文字2倍を確認。Home／Drawerの393px昼夜Golden4と既存詳細9を更新し、共通日本語font・safe areaを固定。既存compact Goldenと対象外Goldenは不変。変更12itemsのFlutter Analyze No issues、整形check0変更。
- 検証済み隔離sourceからdebug APK初回43.49秒でbuild成功。lib全165fileは元repoとbyte一致、source manifest294件はbuild前後不変。依存version／Gradle設定を変更せず既存隔離cacheを利用。APK SHA cda3c7d453c068ff1226533f04d85bd9fe00d8d975e70225c281f75a205ea9b0。Samsung実機/com.gotainu.hamsterのfresh署名一致後install-r1回Success、更新後base.apk/hash/cert一致。appId／firstInstallTime／dataDir／data directory identityを保持、アンインストール／data clearなし。
- MainActivity起動Status ok、PID／Resumed・当該アプリcrash buffer該当なしを確認。端末はDozing・Keyguardロック中。画面wakeだけで解除できず、ロック解除・記録／AI／レポート閲覧タップは行わない。ログイン済み画面、実機の右上／drawer／戻る／保存後表示は未確認。人間がロック解除して「今日」右上またはメニューの「記録カレンダー」を確認する。
- 開始時482file hashを保護し、検証済みUI6・関連test6・Golden13・設計書・本進捗のみを反映。Theme／Catalog／Model／Repository／Functions／Rules／健康・Insight・課金・onboarding／依存設定は不変。server deploy／設定変更／データ移行／本番データ書き換え操作、Git操作、Known Goodアクセス／変更なし。[設計書](docs/care_action_capture_and_continuity_v1.md)へ導線を記録。次工程は引き続き「飼育環境の変更履歴と予測用の日時整合」。
- APK／描画／証跡／直前APKと対象local source退避: /private/tmp/hamcare-calendar-nav-20261012-9s3iqeaz/（apk/app-debug.apk、audit/release-result.json、local-previous/）。

## 2026-10-12 承認済みケア入力・たくわえUIの本番／Samsung反映（PASS）

- 現行本番と照合した結果、Phase A/Bのnew4・既存報酬3更新・追加Rulesが未反映。実稼働stars sourceを基準にexact7 entryのみの隔離releaseを作成し、保存検証→Samsungの順に反映。Catalog正本/TS/Dartと承認済みUIを保持。対象外Function・Index・Scheduler・依存version・通常sourceは変更なし。
- new: saveDailyCareActions=savedailycareactions-00001-rib、retryDailyCareActionReward=retrydailycareactionreward-00001-zud、refreshCareContinuity=refreshcarecontinuity-00001-dul、continuityWeightRecordWritten=continuityweightrecordwritten-00001-dol。updated: claimDailyOpenStar=claimdailyopenstar-00003-luf、starDistanceRecordWritten=stardistancerecordwritten-00003-yox、starDailyCheckinWritten=stardailycheckinwritten-00003-rup。全7 ACTIVE/実traffic100%、配備source全byte一致。既存max20/env/IAM/timeout/memory/concurrency/SA/trigger resourceを保持し、distance/checkinは承認されたretry=trueのみ追加。新weightもretry=true、DB trigger region nam5。
- 新callable3のallUsers Run invokerは最初の自動承認レビューで実行前拒否→対象3限定・Firebase認証本人限定/匿名データアクセス前拒否を説明し、人間の明示承認後に反映。既存IAMは完全不変、weightはpublicなし。独立最終レビューPASS。新notification/予測/avatarを追加しない。
- 現行Rulesにcare/current・不変revision/mutation・continuity/共有condition award保護のみ追加。対象外ローカルgrantは混入させず、統合Rules205件PASS→公式release反映・配備source一致。ruleset=64dfdea0-7db5-4ce6-af98-c79e7a60241c。旧ruleset/旧3 revision/source/config/IAM/直前APKを復元用に保存。隔離Functions43件/TypeScript/Node22 parent-child source discovery PASS。合格済みWidget/Goldenを再生成・重複実行せず、承認済みsourceをbuild。
- サーバー反映前後でBの68docと全rewards16docのfields/updateTime完全不変。Samsung通常起動後もBronze・既存first/v1/daily・readiness/Insight・AI/trial/billing/onboarding不変。既存open_appの2026-10-12 awardが正規に1件追加され、Bのbalance/total/lifetimeEarnedは10→11。既存award不変、残高reset/架空記録/日付操作なし。Care実保存・共有枠の実機E2Eは未実施。
- debug APK 1回build PASS、SHA f06ad63550010d1addbed2463f78edfa889ec81abc9c83d75b2c9ad3ef2e3216。Samsung実機/com.gotainu.hamsterのfresh既存署名一致後install-r1回Success、配備APKhash/cert一致、appId/firstInstallTime/dataDir/inode保持。MainActivity起動/認証済みUI PASS（アカウントUIDの画面上独立確認はなし）。アンインストール/data clear/agentタップ/実機保存なし。入力操作、Hero/月カレンダー・昼テーマの人間による最終評価は未確認。
- release stage/APK/証跡/復元手順: /Users/gota/hamcare-deploy-staging/care-ui-release-20261012-162709（audit/release-result.json、audit/rollback.md）。通常treeの開始時481file hash不変、本進捗追記のみ。Known Good未アクセス/未変更、Git操作なし。実機導線は「記録→今日の様子→今日やったこと」、Homeの「たくわえ→カレンダー」。

## 2026-10-12 達成UI・ケア入力再設計（ローカルPASS）

- 現在のたくわえを大きなゴールドのHeroへ、Homeは直近7日・記録導線、詳細は月間の連続帯と過去実績へ整理。実達成／休み／今日を形とSemanticsで区別し、週・月境界を正しく処理。既存Home配置と健康警告の優先順位、ダーク＝星／ライト＝種、補助3枠を維持。内部説明はヘルプ・折りたたみへ移動し、失効自体は明示する。
- Catalog v2を正本からTS/Dart生成。掃除なし／汚れだけ／一部／大掃除と任意の独立床材交換、日合計の散歩slider0〜120分・直接入力最大1440分・時間不明を実装。入力v2はitem_selection／batch_confirmation／unansweredを区別し、旧記録は不明のまま安全にcarry。未確認初期値は通常保存時だけ一括確認し、「様子だけ」はCareを保存せず、Careだけでは健康回答を作らない。旧pending・mutation receipt・revision／acceptedAt・不変履歴を維持。
- 入力49件／達成Widget36件、結合関連回帰334件（重複あり、合算しない）、Golden4＋10件PASS。Functions保存19＋報酬・継続回帰24件、保存Emulator17件PASS。Flutter Analyze／TypeScript noEmit／Catalog生成物一致PASS。393pxと狭幅280px・文字2倍、単日・継続・休み・猶予復帰・失効後再開の画像を目視。Emulatorは専用demoのみ、所有process停止。
- 開始時435ファイルをhash照合し、変更は今回範囲のみ。Homeソース、報酬／continuityサーバー計算、健康・Insight・既存レポート・課金・trial・onboarding、Rules・依存設定と対象外Golden34枚は不変。通常dirty treeの既存変更を保持。Known Goodへのアクセス／変更、Git操作、本番変更、APK・実機更新なし。
- [設計文書](docs/care_action_capture_and_continuity_v1.md)を更新し、将来音声も同じDraft確認／検証／保存へ通す方針を記録。今回差分の本番適用はsaveDailyCareActionsの保存検証→Flutter更新の順で、Rules／ゲーム規則の追加更新なし。自動rollback・データ移行なし。実機UXは未確認。証跡・画像: /private/tmp/hamcare-achievement-care-redesign-20261012-gtqx6xio/。

## 2026-10-12 飼育行動・連続期間のたくわえ v1（ローカルPASS）

- [設計契約](docs/care_action_capture_and_continuity_v1.md)へ、記録基盤→継続UX→環境履歴/PIT→観察予測・周期offline/shadow→検証後表示の近接順序を保存。MATOME・予測ロードマップ・既存スター設計から参照。従来の研究対象差分C-01を勝手に確定せず、3以降・予測・avatarは未実装。
- 正本shared/care_action_catalog.jsonからTS/Dartを生成。掃除・散歩の実施/非実施/未回答、任意scope/日合計minutes、detail単位/意味のsnapshotを導入。ケアだけの保存・編集でhealth normal/健康write/初回モニタリング/A3を捏造しない。health-only・memo変更・片側成功・offline durable pending・保存後報酬だけのretryを分離。
- Bronze daily_care_actions/{dayKey}＋不変revisions＋mutation receiptをexpectedRevision/transactionで原子的保存。所有者はAuth UID・既存main_pet、実施時刻はdate_only、受理はserverTimestamp。取消はtombstone、再送は同一mutation、履歴を破壊せず、owner read/server-only write。
- 既存スター/種の固定award額・恒久balance/lifetime/50 milestoneを維持。health/careは同じ受理JST日condition枠で二重付与禁止、手動体重は新通貨なし。たくわえは既存award参照の非消費期間内訳で、新通貨・換算・wallet再加算なし。D+2まで猶予、D+3 JST0時に期間内訳だけ失効。実達成カレンダーと累計は残る。
- 原子的care reward outboxと共通transactionにより、失効/新期間判断前に受理済みEvidenceを確認。最大100件と残件保持、101件では最古受理日から認定。新weight・既存wheel/checkin記録triggerはretry=trueで保留eventをACK/dropしない。受理日優先で遅延報酬の翌日権利欠落・旧期間award復活を防ぐ。新毎分Scheduler・大量履歴移行は追加なし。
- Homeの既存3スター領域を共通CareContinuityPanelへ接続し重複カードなし。詳細で28日実達成カレンダー・累計、必要時だけ猶予、再確認待ちでは未確定残高/失効/達成を確定表示しない。Theme/Model/Service/Repository/ViewModel/Widget/Screenを分離し、低減動作・狭幅/文字拡大・ライト/ダーク・Semanticsを検証。
- Phase A unit11/Emulator12/Rules28 PASSをgateとしてBへ進行。最終unit32、統合Emulator32、関連Functions回帰142、新path Rules31＋既存統合Rules146、Flutter新60（Golden8含む）＋関連回帰275 PASS。TypeScript noEmit、Analyze対象23、Care/Observation Catalog一致PASS。重複するスイート件数は合算しない。新描画8枚を目視、既存Golden34枚byte不変。独立レビューの具体5件を修正・再検証、重大残件なし（確認範囲内）。
- 対象外existing filesを開始時hashと比較して保護。健康score/Silver/Gold/Insight/first freeze/個性report/既読履歴/AI/RAG/課金/trial/onboarding生成処理・dependenciesはbyte不変。通常dirty treeを巻き戻さず、削除なし。localhost/demo Emulatorのみ、本番アクセス/write/deploy、APK/実機、Known Good、Git変更操作なし。
- 本番反映は別作業：new saveDailyCareActions/retryDailyCareActionReward/refreshCareContinuity/continuityWeightRecordWritten、更新claimDailyOpenStar/starDistanceRecordWritten/starDailyCheckinWrittenの必要7件・追加Rules・Flutterを現行本番と照合/隔離。record3件のretry=trueを必要設定として確認し、他のIAM/env/runtime等を維持。新index/研究seed/SQL/Scheduler/ledger初期化は不要。入力5秒・実機UX・本番運用は未確認。証跡: /private/tmp/hamcare-care-continuity-20261012-lu61o9ww/。

## 2026-10-12 予測分析研究仕様 v1の正式統合（文書のみ）

- 提供された研究原案を[docs/predictive_analytics_research_spec_v1.md](docs/predictive_analytics_research_spec_v1.md)へ統合。長期方針の正本[予測分析ロードマップ](docs/predictive_analytics_roadmap.md)は維持し、MATOMEからも参照。観察ラベルと疾病ラベル、point-in-time／後入力／欠測、周期長・位相・振幅と独立発情確認、順序モデル・年齢・階層モデル、シャドー／将来表示試験、Prediction Ready、同意・削除の研究契約を記録。
- 既存ロードマップの『初期対象＝活動量距離／回転数』と原案の『初期主目的＝全体観察回答3分類』は未解決差分C-01／P-12として併記。推奨は既存活動量先行を維持して共通時点基盤を観察研究にも再利用する案であり、優先順位を勝手に確定しない。専用の活動量予測実験書はdocs／ルート設計資料の検索で未確認。原案だけのD表記は、既存合意・仮説・未確定へ分類し直した。
- ローカルの限定した型・保存経路を照合。UIの欠落normal／species fallbackを研究の真値へ流用せず、日別最新状態・再計算Silverだけでは当時の入力／初回提出履歴を再現できないと明記。既存Current D-13〜D、daily D-14〜D-1と研究09時案の窓を分離。通常更新のsnapshot不変性と本人による正式削除を両立し、研究コピー・学習成果物・backupの撤回範囲は未確定とした。
- 参考7件を一次資料／公式docsの範囲で確認し、CONSORT 2025のリンクは解説論文と名称を精密化。研究資料の実在をHamCareの予測有効性・発情同定・表示利益の実証と扱わない。文書内の受け入れチェックは文書化完了のみで、研究テスト／モデル検証／Gate合格を意味しない。
- 変更は本仕様の新規追加、ロードマップ参照・差分注記、MATOME索引、本進捗のみ。既存文書は保全し、提供ファイルも変更しない。モデル実装／学習／テスト／deployなし。本番Firestore・Functions・Scheduler・Rules・APK、Known Good、Git変更操作なし。未確定事項は仕様§14に集約し、将来決定時に根拠・承認主体・日付・versionを記録する。

## 2026-10-11 観察Insight配信 本番・Samsung更新（リリースPASS）

- ユーザー承認に基づき、ローンチ前・一般ユーザー0人の契約に揃えて、personalityHealthFeaturesWritten / personalityDistanceRecordWritten / personalityDailyReportsの3 Functionsだけを最新本番sourceから隔離して反映。旧版専用pointer/二重配信/全履歴移行の追加なし。既存v1/daily pointer・既読・履歴を維持。
- ACTIVE100%: personalityHealthFeaturesWritten=personalityhealthfeatureswritten-00003-lib、personalityDistanceRecordWritten=personalitydistancerecordwritten-00002-noc、personalityDailyReports=personalitydailyreports-00007-juc。公式Cloud Functions v2 APIのbuildConfig.source限定PATCHをexact nameで実施。IAM/env/trigger/runtime/timeout等は保持。Distanceの既存service max20をFunction/revisionにも明示化（承認済み）、Google管理メタデータ以外に未承認設定差分なし。将来max変更時はFunction/revision/serviceの3層を確認する。
- Dailyはsource更新後も旧00005-mip100%が保持されたため、設定・source検証後に公式traffic-only切替を1回実施し新00007-juc100%を確認。追加source再deploy・対象外Function再deployなし。旧revision/source ZIPとsource限定rollback bodyを保持。
- Node22.23.1でCLI相当source解析の親/子PATHを固定。隔離2群のunit144件、TypeScript noEmit/compile、entry metadata/import closure/Catalog生成物一致PASS。既に成功したEmulator/Flutter/Golden回帰検証は再利用。反映後に実際のACTIVE traffic/config/IAM/Eventarcと取得したsource ZIP全体のbyte一致を確認。
- 対象外31 Functions・33 Cloud Run servicesは設定/source/revision不変。Rules不変（SHA3b62e9d67d44c3e961ce719b89f56402d294c40b1102e8828e4db806c04b7736）、Index変更なし、09:00 JST Scheduler/IAM維持。AI/RAG・課金・trial・health計算・onboardingを変更せず、first/v1/過去dailyを再生成しない。
- Bの前後60 documentをreadonly比較し、飼育記録・Silver/Gold・readiness・pointer・trial/billing/onboarding・AI usage/budget/queueと不変report3件のcontent/hash/updateTimeを保持。first SHA1c2233ef5f1db2f49bd8891688ea49bd2fc516b4b932e4fc07ebc4184667fb3f / updateTime2026-10-07T02:52:30.807773Z。有効観察1日、未記録13日、自動normal7/明示回答0、観察Insight0は正常な記録不足。再計算・強制発行・架空記録・配信状態リセット・本番Firestore writeなし。
- Samsung実機の接続済み回答後、fresh既存APKと候補の署名一致PASS。検証済みFlutter source246filesの一致と既存v3/Phase1・2/体重/観察/observation_only契約を確認しdebug build1回exit0（78.426秒）。依存/ソース変更なし、既存隔離Gradle cacheを再利用。APK SHA ddab99a33d2ed14c90df99f36725961e4a08ad91e7031e6eb97e127ec3124613。
- adb install -r1回Success、installed base.apkと候補SHA完全一致。app UID/firstInstallTime/data directory identity/起動前prefs metadata保持。アンインストール・data clearなし。MainActivity Status:ok/foreground、private実画面で認証後「今日」Homeを確認しログイン保持PASS。record/AI/report閲覧操作なし。
- 未確認: 観察だけの本番通常発行E2E、観察のみレポート詳細の実機表示。Emulator成功を本番発行成功と扱わない。十分な通常記録と次回09:00 JSTで確認し、テスト目的で既存記録/不変report/配信状態を変えない。
- 保護: 開始時396filesのhash比較で通常working treeの既存source/test/Goldenは不変（本進捗追記のみ）、削除なし。Known Good未アクセス/変更なし、Git変更操作なし。APK/証跡/復元先: /Users/gota/hamcare-deploy-staging/checkin-delivery-20261011-204123。統合結果audit/release-result.json、復元手順audit/rollback.md。source/API保存情報と旧installed APKで復元可能。

## 2026-10-11 ローンチ前データ契約への統一（ローカルPASS・本番未反映）

- ユーザー訂正を正本へ反映：ローンチ前・一般ユーザー0人。旧版共存対応は実際の配布状況に応じて判断する。確認済みアカウントはテスト用であり、一般利用者数ではない。テスト端末は最新版へ更新できるため、直前の旧v2/v3互換配信・全旧履歴移行によるリリース保留を今回の要件から取り消す。MATOME、予測分析ロードマップ、観察Insight仕様にも同じ前提を記録。
- 直前タスクで新しい旧reader専用pointer/保存先/二重配信/全履歴走査は追加していない。今回追加分のうち、過去の最新report snapshotから配信済み状態を推定する処理だけを削除。既存のv1/daily pointer、旧レポート閲覧、first/v1/過去dailyの不変性は維持し、リポジトリ整理・既存データの削除/初期化へ広げない。
- 発行成功transactionが保存するcheckinPublicationStateを配信済み状態の正本に統一。state未保存の場合は通常の発行成功時に保存し、過去履歴からの推定/移行はしない。A/Bの項目・該当日数帯による意味ある変化、同義B/Cの既出化、Cの初回節目のみ、同日最大1件、再試行/並行実行・100件上限残件・部分失敗・09:00 JSTを保持。
- 今回の関連検証：Functions6ファイル69件PASS、専用localhost/demo Emulator47件PASS（日次43＋実health trigger配信E2E4）、Flutter関連7ファイル62件PASS（Goldenの一致を含む）、TypeScript noEmit PASS。既に成功した全関連テストを無意味に再実行せず、今回の契約訂正と影響範囲を検証。新規Emulator fixtureで、過去snapshotのみでは配信済みと推定しないこと・成功時state保存・C翌日再発行なし・既存state累積とfirst/過去reportのcontent/updateTime不変を追加確認。
- production変更はcheckinPublication.tsとpersonalityDaily.tsの2ファイルのみ。Flutter production変更なし。開始時392ファイルのhash比較で対象8ファイル（上記2、テスト2、文書3、本進捗）以外の既存ファイル・Golden画像は不変、削除なし。既存health計算/体重Insight/first freeze/Rules/課金/AI/onboarding、通常dirty treeを維持。本番・保存済みテストデータへのアクセス/変更、deploy、APK/実機、Known Good、Git変更操作なし。
- 本番適用は未実施。将来は最新本番sourceとの照合と隔離を行い、personalityHealthFeaturesWritten / personalityDistanceRecordWritten / personalityDailyReportsの3 Functionsと検証済み最新版Flutterを同じローンチ候補契約へ揃える。既存環境変数/trigger/IAM・承認済みmax20・09:00 JSTを維持。新規Rules/Index/研究seed/Scheduler変更・全旧履歴移行は不要。旧版共存を今回のリリース阻害条件にはしない。証跡：/private/tmp/hamcare-prelaunch-contract-20261011/、/private/tmp/hamcare-checkin-only-flutter-20261011/prelaunch-minimal-result.json。

## 2026-10-11 予測分析ロードマップ・観察Insightの日次配信（ローカルPASS／本番互換方針未確定）

> 以下は訂正前の作業記録。旧版共存・全履歴移行を理由とした保留は、上記のユーザー訂正により今回の要件から取り消した。

- `docs/predictive_analytics_roadmap.md`を正式資料として新規保存、MATOMEの参照を1行追加。観察配信→複数指標の記述→活動量予測のオフライン比較→ユーザー横断階層モデル→疾患研究の順序を確定。予測対象は回し車距離/回転数、候補特徴量と持続的個体差/日次残差、Prediction Ready、時間/個体分割、校正、同意・プライバシーを記録。飼育環境変更履歴を将来優先課題とし、今回の予測実装/スキーマ追加はなし。
- 既存personalityDaily/queueへ観察A/Bの新規意味・段階とCの初回7日節目を接続。checkin_publication_v1のmateriality key/semanticSignatureはEvidence hashと責務分離し、単なる日付/hash/件数増では発行しない。A/Bは該当日数帯の明確な変化、Cは一度だけ。配信済みkeyを日次pointerへ累積、Aが含む同義B/Cも既出化して再通知を抑制。
- 当日SilverのupdateTimeをtx再検証。保存時TimestampのEvidenceをDateへ復元し既存hashを照合。出版はfresh BronzeのD-14〜D-1、Current D-13〜Dと分離し、08:59の当日記録は翌朝へ送る。訂正/削除の取消・新queue競合はprepared旧値で発行せず翌朝へ保持。固定daily ID/tx.create、数値frontier、100件上限・残件・部分失敗・09:00 JSTを維持。
- 数値指標未readyでもdaily observation_only/readyMetrics=[]/metrics={}と有効な不変checkin snapshotだけで発行。Flutter Model/VM/共通InsightsCardを再利用し、体重/活動量は準備中。Home/既読/Repository/閲覧計測は変更なし、履歴対象ラベルだけ共通VMへ接続。実Emulator生成JSONのModel→VM→画面→閲覧callback契約2件PASS。
- 最終検証：Functions関連21ファイル142件PASS、専用localhost Emulator7スイート164件PASS（日次41/E2E4/観察8/体重7/backfill10/日次権限30/既存権限64）。Flutter関連505件PASS（既存関連491＋AI/初回CTA12＋実backend wire2、新規計16）。新Golden3枚を目視確認、旧31枚はbyte不変。Flutter analyze No issues、TypeScript noEmit PASS。初回Emulator接続は実行権限下で解消、E2E時刻fixtureとTimestamp境界を修正後に必要範囲を再PASS。全Flutter試行は中断済みで全件成功とは扱わない。対象外star_awardsの既存lib参照テストは停滞のため所有子processを停止し、変更せず関連21fileから除外（全Functions suite成功とはしない）。
- 開始時383ファイルのhash比較で対象外の変更・削除なし。productionはpersonalityDaily.ts・新checkinPublication.tsとFlutter4filesだけ。healthTriggers/healthPipeline/既存分析計算/first freeze/v1 publisher/Rules/index/dependencies/catalog/Home/AI/RAG/billing/trial/onboardingはbyte不変。既存first/v1/dailyのhash・updateTimeとtrial/onboardingをEmulatorで保護確認。通常dirty treeを維持、Known Good/Git変更操作なし。本番アクセス・deploy・Firestore本番write・APK/実機操作なし。
- 本番前の未解決：旧v1は従来pointer維持で互換。旧v2/v3はobservation_onlyをdecodeできず最新/履歴を壊すため、未更新クライアントの更新完了または互換配信方針の確定が必要。Flutter先行配布だけで全旧v2/v3の互換性は保証しない。既出stateのない旧ユーザーは最新snapshotのみから推定し、より古い全履歴との厳密重複排除は未実装。現時点で本番有効化準備完了とは判定しない。
- 将来は上記互換方針を解決後、実稼働sourceへ隔離した3 Functions（personalityHealthFeaturesWritten / personalityDistanceRecordWritten / personalityDailyReports）だけを反映。今回新規Rules/Index/研究seed/Scheduler/health計算Function更新は不要。仕様は`docs/checkin_insights_phase3.md`、検証・保護証跡は`/private/tmp/hamcare-checkin-delivery-20261011/`と`/private/tmp/hamcare-checkin-only-flutter-20261011/`。本番反映は未実施。

## 2026-10-11 観察Insight・Observation Catalog 本番リリース（反映PASS・実機詳細確認待ち）

- 検証済み変更を最新本番sourceからhealth/manual/dailyの3群へ隔離し、関連7 Functionsのみsource限定更新。健康評価/中央値/MAD/EWMA/weight selection、manualのfirst/readiness同期なし、既存first freezeとv1/daily不変性を保持。隔離unit217件・TypeScript noEmit/compile・entry metadata一致PASS、既存ローカル検証は再実行せず利用。
- ACTIVE100%: healthWeightRecordWritten=00013-lij、healthDistanceRecordWritten=00014-soj、healthDailyCheckinWritten=00013-pet、healthEnvironmentHistoryWritten=00013-muy、healthEnvironmentLatestWritten=00013-wip、rebuildMyHealthArchitecture=00011-maq、personalityDailyReports=00005-mip。env/runtime/IAM/triggerと承認済みFunction/service/revision max20を保持。無関係27 Functions/29 Run servicesは不変。
- 日次source更新後は旧00002-dir100%が固定され、CF allTrafficOnLatestRevisionはrouting由来の省略に変化。Run v2 traffic PATCHはHTTP409で拒否され変更なし。公式traffic-only CLIを1回実施し新00005-mip100%へ切替、追加revision0・template/runtime/IAM/max20不変をreadback。旧00002-dir/sourceと全7 rollback JSONを保存。将来max変更時は3層の独立上限を確認する。
- 現行Rulesは専用Emulator84件PASSで追加不要。Rulesと09:00 JST Schedulerは完全不変。S日の観察変更対象はS〜min(S+13,today)の最大14日、Current D-13〜D / Report D-14〜D-1を維持。
- Bの正規manual_rebuildを1回実施、2026-10-11 Silver観察Evidence/CurrentGoldの世代・hash一致。有効記録1日、未記録13日、automatic_normal7項目/explicit_answer0、項目回答日数null、観察Insight0（記録不足による正しい非掲載）。体重Insightとbody/activity baseline/健康スコアを保持。Bronzeへのwriteやテスト記録追加なし。
- Bのfirst/v1/過去daily全2件・v1/daily pointers・readiness・飼育記録・trial/billing/onboarding・AI usage/validation budgetはcontent/hash/updateTime完全不変。first SHA1c2233ef5f1db2f49bd8891688ea49bd2fc516b4b932e4fc07ebc4184667fb3f / updateTime2026-10-07T02:52:30.807773Z。新規dailyは強制発行なし。
- Samsung実機のfresh既存APKと候補の署名一致PASS、package com.gotainu.hamster。検証ソースからdebug build1回exit0（57.352秒）、APK SHAbe68c52f05b9fdc9387905adc3f3f3acd86c2c54c243b0dd7024ecc2cf007864。install-r1回exit0/Success、実機base.apk候補と完全一致、app UID/firstInstallTime/CE・DE data identityと起動前settings metadataを保持。アンインストール/data clearなし。MainActivity起動Status:ok/foreground・実画面で「今日」Homeを確認。ログイン情報の保存先を保持したが、ログイン状態そのものの独立確認は未実施。
- 未確認: 十分な本番記録でのA/B/C掲載、次回自然発行の観察snapshot、実機Insight詳細表示とログイン状態の本人確認。既知historical readiness一時イベントは未修正で、通知/新規発行の入力ではない。通常source380file hash不変（本進捗追記のみ）、Known Good/Git/AI/RAG/課金/Auth変更なし。
- APK/監査/rollback: /Users/gota/hamcare-deploy-staging/checkin-insights-phase3-20261011-145915。統合結果: audit/release-result.json。実機表示確認はユーザーへ引き継ぐ。

## 2026-10-11 観察Insight・共通Observation Catalog（ローカルPASS）

- `shared/observation_catalog.json`を単一正本とし、Flutter/Functionsの参照コードを決定的生成。8つの既存ID、表示順/日本語名、有効/廃止、旧ID/旧名称、Insight対象、catalog versionを共有。poop→elimination、廃止chewingの過去読み取りを維持。追加/名称/順序/廃止テストと生成物drift検査PASS。汎用フォーム基盤やクラウドカタログは追加しない。
- 現行schema2の保存/読取りを維持し、新規保存にcatalog versionと回答方式だけを追加。Silverへoptional観察Evidence（実測日/元doc、選択/自動normal/明示回答/未回答/旧schema/不正値の出所、14日件数、品質、hash）を保存。自動normalを項目別回答済みと扱わず、回答日数unknown/nullを保持。自由記述memoは新Evidence/Insightへコピーしない。既存データの一括移行なし。
- 観察A（選択確認7日/項目3日）、B（全体回答7日/気になる様子2日）、C（記録7日）をサーバー算出。A→B→Cから最大1件、同義のA/B重複を抑制。Cはdiscovery=false。metric=conditionの型付きoptional checkinInsightsを既存weight Current/Report APIへ追加し、旧weight配列/specを維持。同じ根拠のsemantic fingerprintは生成日だけで変更せず、記録頻度を実際の発生頻度/診断として表現しない。
- CurrentはD-13〜D、次回の正規新規daily snapshotはD-14〜D-1。S日のcreate/update/deleteはS〜min(S+13,today)を再計算。同日重複は1日として最新更新を採用。Silver/Currentのtransactionと生成世代に加え、Bronze前にSilver版を捕捉し、競合時最大3回fresh再読取。両完了順・同一millisecond・初回同時createをEmulatorで検証、同じ最新結果ならwriteゼロ、上限超過はエラー。first/v1/過去dailyの内容/hash/updateTime不変。
- Flutterの独立readonly CurrentCheckinInsightsRepoはserver確認済みSilver/Gold、本人、当日、生成世代、Evidence hashを照合。cache/pending/別owner/不一致/エラーでは省略。体重baselineや研究データへ依存せず、Model/VM/共通InsightsCardを個性レポートsnapshotと「変化」に接続。既存WeightInsightsCardは互換wrapper。健康スコア/警告への新規表示追加はせず、共通VM/Cardは日付/世代指定で再利用可能。
- 検証：Functions関連136件、専用localhost Emulator関連8スイート180件、Flutter関連449件、生成器5件PASS。新Golden3枚（dark/light/320px文字1.5倍）を目視確認、既存28画像はbyte不変。実TS builder出力fixture3件をDartでdecodeしwire互換を確認。Flutter analyze No issues、TypeScript noEmit PASS。既存健康評価の変更前後の完全出力400ケース一致。
- 保護：開始時348ファイルをhash比較し、対象の既存16production filesと入力テスト・本進捗追記以外の既存ファイルは不変、削除ゼロ。既存の中央値/MAD/EWMA/体重算出、first freeze、Rules/index/dependencies、Home/既読/履歴、AI/RAG、billing/trial、onboardingとPhase1/2/v3修正を保持。Known Good、本番Firestore/Functions/Rules/Scheduler、APK/実機、Git変更操作なし。
- 本番未反映。将来は実稼働sourceとの差分を隔離し、healthPipeline consumerと日次publisherの必要Functionだけを対象確認して反映、検証済みFlutterを更新する。現行Rules/Index追加と既存report移行は不要。観察だけでは既存daily発行queue/frontierを進めず、次回の正規新規reportからsnapshotを含める。実機表示・本番運用は未確認、historical rebuild途中の既存readiness一時遷移は対象外で未修正。
- 仕様：`docs/checkin_insights_phase3.md`。検証/保護証跡：`/private/tmp/hamcare-checkin-insights-20261011/`。今回commit/pushは未実施。

## 2026-10-11 Phase 3 Samsung更新完了（リリースPASS）

- ユーザーのUSB接続済み回答後、Samsung実機のdevice接続を確認。保存済み検証APKのpackage com.gotainu.hamster・SHA 36d227da177e5e20927f1df873e2cf11399a664af33e8d0006b344f740bb534d・147lib source hashes・Phase3/v3/Phase1/2 compiled markersを再確認。実機からfreshに取得した既存base.apkと署名certificate一致PASS。
- 対象serialだけへadb install -rを1回実行しexit0/Success。インストール後base.apkのSHAが検証候補と完全一致、署名一致。app UID・初回install時刻・CE/DE data inode/所有者/permission・起動前settings file metadata不変。アンインストール・data clearなし、既存data/loginを保持。
- MainActivityをam start -Wで起動しexit0/Status: ok・foreground Activityを確認。実スクリーンショットを目視し、認証済み「今日」Homeと既存個体プロフィール表示を確認。AuthGateの未ログイン分岐がAuthScreenへ進むこともreadonlyコードで確認し、ログイン保持PASS。画面タップ/AI相談/レポート閲覧は未実施、Insight詳細の表示評価はユーザー確認待ち。
- 先行server PASS（personalitydailyreports-00002-dir100%、B current Insight100〜100g/端点差0g、既存全report内容/hash/updateTime不変）と合わせリリース作業PASS。新規daily snapshotは次回自然発行時に確認し、強制発行なし。今回server管理API/設定操作・再build・通常source変更・Known Good/Git操作なし（本進捗追記のみ）。運用承認max20と将来のservice/revision/CF API上限確認事項を維持。
- APK: /Users/gota/hamcare-deploy-staging/weight-insights-phase3-20261011-121925/apk/app-debug.apk。実機証跡: 同stage/audit/device-connected-20261011/。統合結果: 同stage/audit/resume-approved-max20/release-result.json。未確認は実機でのInsight詳細表示と次回自然日次snapshotのみ。

## 2026-10-11 Phase 3 再開（server PASS・Samsung USB接続待ち）

- ユーザーがrevision-level maxInstanceCount=20の明示的維持を承認。未設定への復元調査を終了。従来service max20・新revision max20・CF API max20を維持し、現在実効上限20は同じ。将来service上限だけを増やしてもrevision20が独立制約として残るため、service/revision/CF APIの3値を確認すること。運用記録は隔離audit/resume-approved-max20/scaling-operations-note.md。
- fresh live GETと既存証跡を照合し、承認max以外の実行設定差分0。env/SA/CPU/memory/timeout/concurrency/ingress/probes/ports/startup設定・IAM・09:00 JST Scheduler保持。新source全74filesは検証済み隔離ZIPと一致。公式traffic-only CLIでpersonalitydailyreports-00002-dirを100%へ切替・readback PASS、旧00001-gepをrollback用0%で保持。追加revision/source deployなし。成功済み6 Functionsはrevision/updateTime/source generation不変、Rules不変。
- Bの既存正規manual_rebuildを隔離された本番同一manualコードで1回実行し、2026-10-11 Silver/current Insight/当日health evaluationのgeneration整合を確認。観測幅100〜100g（採用9件、9/22〜10/06・15日）、期間端点差0g（実測10件、9/22〜10/10）。期間差は全同値観測幅と意味重複のため別Gold掲載を抑制し、根拠の実測はSilverに保存。欠測補完・健康の断定なし。事前検査のTimestamp.toDate丸め807→808差だけをナノ秒比較へ修正し、書込みmarker前に停止していたことを確認後に唯一のrebuildを実行。productionコードの変更なし。
- first/v1/daily_2026-10-11全report、v1/daily pointers、weight/distance Bronze、body/activity readiness、trial/billing/onboardingは前後content/hash/updateTime完全不変。first SHA 1c2233ef5f1db2f49bd8891688ea49bd2fc516b4b932e4fc07ebc4184667fb3f / updateTime 2026-10-07T02:52:30.807773Z。新dailyは強制発行なし、Insight snapshotは次回自然発行時に確認する。AI API/RAG/課金/Authへの操作なし。
- 保存済みAPK package/hash/sourceマーカーを再確認（SHA36d227da177e5e20927f1df873e2cf11399a664af33e8d0006b344f740bb534d）。Samsung実機はADB devices空・get-state device not found。USB接続を依頼し待機後も不在だったためfresh実機署名比較/install-r/launch/login確認は未実施。前回の署名一致を今回の成功として流用しない。APK保持、アンインストール/data clearなし。
- サーバー側PASS、全体PARTIAL（実機接続待ち）。通常dirty source不変（本進捗追記のみ）、Known Good/Git操作なし。今回の証跡: /Users/gota/hamcare-deploy-staging/weight-insights-phase3-20261011-121925/audit/resume-approved-max20/release-result.json。次はUSB接続後にfresh署名比較→install-r→起動/ログイン画面確認のみを再開する。

## 2026-10-11 Phase 3 PARTIAL解除のmax復元確認（変更せず停止）

- personalityDailyReportsのみを限定確認。旧00001-gepのrevision maxは未設定、新00002-dir/template/Function API maxは20、service-level maxは以前から20のまま。source限定更新時にCF API・template・新revisionへ独立したrevision-level 20が追加された場所を確認。サーバー内部の理由や「default20」とは断定しない。
- 公式Run v2 validateOnlyで単一field/parent scaling削除とproto未設定値0を確認し、公式CLIのmax-instances=defaultと同じv1 annotation削除をdryRun=allでも確認したが、各previewにrevision max20が残存。元の未設定へ安全に戻ることを確認できないため実PATCH/PUT/CLI update・traffic切替・再deployは行わず停止。非永続operationのGET404は保存されないvalidation操作で発生し、実Service etag/latest revisionが不変であることを別GETで確認済み。
- ACTIVEはpersonalitydailyreports-00001-gep 100%、00002-dir 0%のまま。新revision作成なし、Function resource・Run設定・IAM・09:00 JST Schedulerは今回開始時と完全一致。反映済み6 Functionsはrevision/updateTime/source generation不変。Rulesへ操作なし。
- backend復元条件未達につきBの再計算は未実施、individual_insights/2026-10-11は依然未生成。first/v1/daily_2026-10-11の内容/hash/updateTime完全不変。first SHA 1c2233ef5f1db2f49bd8891688ea49bd2fc516b4b932e4fc07ebc4184667fb3f、updateTime 2026-10-07T02:52:30.807773Z。Samsungへのfresh署名検証/install/launchは実施せず、前回build済みAPKは保持。
- 継続にはGoogle公式管理APIでrevision-level maxを未設定へ戻す手段・管理層の補完動作を確定する必要がある。service-level maxの一時削除、20/100明示による置換、CF detach、別Function作成は今回採用しない。実クラウド/Firestore/端末変更0、通常source不変（本進捗追記のみ）、Known Good/Git操作なし。証跡: /Users/gota/hamcare-deploy-staging/weight-insights-phase3-20261011-121925/audit/completion/result.json。

## 2026-10-11 Phase 3 体重Insight本番リリース（PARTIAL・設定差分で停止）

- 本番source/configを取得し、Health5・manual callable・dailyを3隔離集合へ分離。各自の本番sourceへInsight差分だけ追加し、manualへreadiness/first publisherを新規導入しない。package/lock/export/trigger/first freeze・distance today再計算を維持。隔離unit170件、TypeScript3集合、現行本番の健康評価/baselineとの2400ケース比較、Rules Emulator169件＋隔離backend Emulator35件、Flutter415件/Golden/analyze PASS。
- 現行Rulesへindividual_insightsの日付document本人getだけを追加し本番readback完全一致。他の権限と4研究ID限定getを保持。新ruleset e3f7aa13-2e7e-4679-97f8-6382ed4a9176、SHA 3b62e9d67d44c3e961ce719b89f56402d294c40b1102e8828e4db806c04b7736。旧ruleset/sourceは隔離auditへ保存。
- 公式Functions v2 source限定PATCHで6件反映済み・100% traffic。weight=healthweightrecordwritten-00012-mav、distance=healthdistancerecordwritten-00013-vuf、daily check-in=healthdailycheckinwritten-00012-vij、environment history=healthenvironmenthistorywritten-00012-hex、environment latest=healthenvironmentlatestwritten-00012-yay、manual=rebuildmyhealtharchitecture-00010-vec。実source ZIPの全file一致、env/runtime/IAM/Eventarc設定保持を確認。
- personalityDailyReportsはsourceだけのPATCHでもCF serviceConfig.maxInstanceCountが未設定→20になったため保護条件で停止。新personalitydailyreports-00002-dirは0%、旧personalitydailyreports-00001-gepを100%へ公式traffic専用CLIで復元、追加rollback revisionなし。CF max=20の設定表現と新revisionは残存し未解決。日次Scheduler 09:00 JST/IAMは維持。traffic-only RESTは409で拒否されたがCLIによる復元を実値確認済み。今後のsource deploy時は自動latest切替を避け、設定差分の判断が必要。
- Bのcurrent Insight再計算/書込み前に停止したためindividual_insights/2026-10-11は未生成。READ-ONLY previewでは実測10件すべて100g、baseline採用9件9/22〜10/06・15日、観測幅100〜100g、期間10実測9/22〜10/10の差0g（同義重複で期間差掲載は省略予定）。first/v1/既存daily_2026-10-11の内容/hash/updateTime、pointers、Bronze、body/activity readiness、trial/billing/onboardingは前後完全一致。first SHA 1c2233ef5f1db2f49bd8891688ea49bd2fc516b4b932e4fc07ebc4184667fb3f / updateTime 2026-10-07T02:52:30.807773Z。不変レポートの再生成・AI呼出し・飼育記録変更なし。
- 検証済みPhase3＋Phase1/2最終13Flutter filesだけを隔離overlayしAPK1回build PASS（55.441秒/exit0、同成功cacheで修復不要）。Samsung実機を確認しfresh既存APKとの署名一致PASS。APK SHA 36d227da177e5e20927f1df873e2cf11399a664af33e8d0006b344f740bb534d。release停止によりinstall/launchは未実施、既存端末アプリ・data/loginは触らない。新daily snapshot/画面確認は未確認。
- 対象外27 Functions・29 Cloud Run services・Scheduler設定不変、RAG/startInitialTrialへ変更なし。通常sourceの全hash不変（本進捗追記のみ）。Known Good/Git操作なし。隔離source・設定・rollback・APK・証跡: /Users/gota/hamcare-deploy-staging/weight-insights-phase3-20261011-121925/。PARTIALの解除には日次max設定差分を解決/判断後、BスモークとSamsung更新を再開する。

## 2026-10-11 Phase 3 共通Insight基盤・体重2種（ローカルPASS）

- 既存personalBaseline/weightの観測選択を共有し、採用実測のmin/max・評価日から30日以内の実測両端差をサーバー計算。中央値/MAD/EWMA・健康評価の全出力は開始時と一致する元ソースに対して各400ケース（計800）完全一致。MAD=0から全同値とは判断せず、欠測補完・健康/継続増減の断定なし。
- Silver schema5へoptional weightInsightEvidence、日付固定Gold individual_insights/{dateKey}へCurrentInsightSetを追加。同generationの重複txを冪等化し、古いGoldの遅延上書きを防止。新規daily tx.createだけにfresh cutoff由来のReportInsightSnapshotを追加し、liveGoldを流用しない。first/v1/生成済みdailyはhash・updateTime不変、既存queue/発行/pointer制御を維持。
- Flutter共通Model/readonlyRepo/ViewModel/WeightInsightsCardを追加。server確認・owner・評価日・Silver generation完全一致を条件に、変化のグラフ下・整合した体重詳細・今後のdaily snapshot冒頭で再利用。learningの2実測日による期間差はbaselineの準備状況と分離。旧report/noGoldは従来表示へfallback、未確認cache/不整合/エラーはInsightだけ省略。Phase 1・2の単位g/m・短比較ラベル・現在分析への別導線を保持。
- 検証：Functions関連17ファイル110件PASS（新unit13）。専用demo/localhost Firestore Emulator関連217件PASS（新Insight7・最小Rules24含む）、最後のgeneration guard後に影響する35件を再PASS。所有Emulator停止済み。本番Bデータへアクセス・書込みなし。全source TypeScript compileはtmpだけ、noEmit PASS、依存/既存lib更新なし。
- Flutter関連34ファイル415件PASS、Widget新規15件・Golden新規4画像（393dark/light、320px/文字1.5倍、daily snapshot）。新画像を目視確認、既存Goldenは更新なし。backend実計算JSON→Dartのwire契約、cache/pending/owner/day/gen、旧v1/日次、健康score、Home既読・履歴・課金/trial/onboardingの回帰を含む。Flutter analyze最終No issues。初回test fixture/fontの問題と新規lint4件は修正後に最終再実行。
- 新GoldのローカルRulesは本人getのみ、list/create/update/delete禁止。他の既存Rulesは維持。初回権限テストでownergetだけ4失敗→最小ルール追加後24PASS。既存distance unitのローダーはNode標準cryptoの許可1行だけ追加し、既存9assertionケースを維持。
- 開始時323ファイルを比較し、対象外の変更・削除なし。AppTheme、HealthAnalysisViewModelのdate/owner/generation判定、MetricComparisonBar、研究比較、first freeze、v1publisher、healthTriggers（today修正）、index、課金/AI/onboarding等はbyte不変。dirty tree・Known Goodを維持。deploy/本番Firestore/Rules/Scheduler/APK/実機/Git変更操作なし。
- 本番適用は未実施。現行Rulesへ個別get追加を統合、healthPipelineの全consumer（5health triggers＋rebuildMyHealthArchitecture）とpersonalityDailyReportsを隔離sourceで必要範囲のみ反映、Flutter更新が必要。新規index/研究seed/SQL/旧report移行は不要。Current Goldは通常health再計算、Insight snapshotは今後の通常daily発行から利用する。
- 既知課題：旧health並行書込みによりSilverと新Goldのgenerationが不一致の場合はInsightを安全に省略し次の再計算を待つ。historical rebuild途中の一時的readiness遷移も今回は未修正。実機/本番表示は未確認。
- 仕様：docs/weight_insights_phase3.md。証跡：/private/tmp/hamcare-phase3-insights-20261011/、/private/tmp/hamcare-phase3-backend-validation/、/private/tmp/hamcare-phase3-ui/。

## 2026-10-11 個体別分析UI 実機確認後の3点修正（ローカルPASS・APK未更新）

- 「変化」の最新値footerを指標のunitから表示し、体重g／活動量mを修正。7日・30日・全期間と指標切替を検証。既存グラフ・期間・健康評価計算は維持。
- 同種研究カードはv3と同じ共通短ラベルをViewModel定数から使用。100g／133g／160gの実値をグラフ直下へ整列し、共通MetricComparisonBarの数値比例・衝突fallback・範囲外処理は変更しない。v3表示は同一文字列の共有だけ。
- 体重詳細の不整合fallback／保存済み健康スコア・評価日を維持。新しいserver確認済み個体別分析が利用可能な場合だけ、双方の日時と「現在の体重分析を見る」を表示。別画面で当日readonly sourceを新規購読し、旧健康評価を現在分析へ引き継がない。日付・生成時刻・所有者のaligned条件は開始時とbyte完全一致。
- 検証：targeted133件、関連28ファイル374件PASS。Golden合計19ケース24画像（新規dated fallback2画像、意図したPhase 1・2画像6更新、既存v3の12画像はbyte一致）。393pxのdark/light比較・fallbackを目視確認。320px／文字1.5倍の境界・範囲外配置、欠損／cache／owner変更、旧評価→現在分析→戻る、課金・trial・onboarding・Home既読・履歴を含む回帰PASS。Flutter analyze No issues。
- 開始時294ファイルの比較でproduction変更は対象7ファイルのみ。Theme／Model／readonly Repo／Functions／Rules／score service／Home／既読・履歴／日次発行／AI／課金・trial／onboardingはbyte不変。既存dirty変更を維持、Known Good・本番Firestore・deploy・APK・実機・Git変更操作なし。既存の狭幅graph status row課題は対象外で未修正。
- 新規テスト：test/graph_metric_units_test.dart（5件）、test/weight_research_card_layout_test.dart（7件）。health ViewModel12件・画面8件・dated fallback Golden2ケースを追加。初回テスト用stream再購読・戻るfinder・fake async内font読み込みのfixture問題は修正後に再実行してPASS。本番コードの追加修正やエラー無視で回避していない。
- 証跡：/private/tmp/hamcare-phase12-ui-final-20261011/。本修正の実機反映・最終画面確認は未実施。

## 2026-10-11 個体別分析UI Phase 1・2 本番Rules／Samsung反映（反映PASS・画面確認待ち）

- 現行本番RulesをRules APIでfresh退避。公開体重研究4 ID（syrian/djungarian/roborovski/campbell）のroot/versionへの認証済みdocument getだけを追加し、その他の既存Rulesはbyte完全一致。list/write/未認証/その他研究IDは拒否。統合Rules Emulator145件PASS後、firestore:rulesだけ反映し、本番readback SHA `15ac7af43394be56a955f9d72f03137318bd439a19906152173117ecb25b79c4`と完全一致。Functions/index/Firestore document変更なし。通常repoの既存dirty Rulesは維持し、本番の限定版は隔離候補に保存する。
- 前回実機成功v3ソースを基準に検証済みPhase 1・2のFlutter12ファイルだけoverlay。APKに無関係なproduction変更なし。隔離関連340テスト・Golden17ケース22画像PASS（更新なし）、analyze No issues。Flutter/JBR/Gradle成功cache・lib/main.dart・依存・接続設定を維持し、debug APKを1回build、exit0／83.457秒。
- Samsung実機 の既存APKをfresh取得し署名一致を確認、install-rはexit0／Success。実機APK SHAは候補と一致、userId・初回install日時・CE/DE data identity・起動前shared_prefs metadata不変。uninstall/data clearなし。起動exit0／Status: ok、前景Activityと実画面でログイン済み「今日」Home・既存プロフィール・記録待ち表示を確認。追加画面のタップ操作は行わず、ユーザーへ引継ぎ。
- Test Bのread-only比較：body/activity ready、当日Silverあり（体重100g／活動量628.3185307179587m）、種・年齢はsyrian研究比較適合、研究133g／IQR100〜160g。health latestは2026-10-10、Silverは2026-10-11で不整合のためPhase 2の追加分析は安全に省略する。D-1活動記録なしを過去レポートで補完しない。既存firstのcanonical SHA `1c2233ef5f1db2f49bd8891688ea49bd2fc516b4b932e4fc07ebc4184667fb3f`とupdateTime `2026-10-07T02:52:30.807773Z`は不変、読み取った既存Silver/Gold/飼育記録・pointerも反映前後一致。
- 通常ソース354保護ファイルはbyte不変、本進捗記録以外の通常working tree書込みなし。Known Good／Git操作／AI／課金／trial／オンボーディング／日次発行／Schedulerを変更せず。
- 実機未確認：変化→体重グラフ・期間切替・研究比較、総合サマリー→内訳→体重詳細、安全なfallback、個性レポートv3・Home未読・履歴。既存の変化グラフの単位m表記・狭幅status row課題は対象外で未修正。
- APK: `/Users/gota/hamcare-deploy-staging/individual-analysis-phase1-2-20261011-105247/flutter/build/app/outputs/flutter-apk/app-debug.apk`。SHA-256: `e8656cfd253274819d068d093e43008284e6d56029cc3f151e3141d1f95c0480`。証跡: `/Users/gota/hamcare-deploy-staging/individual-analysis-phase1-2-20261011-105247/audit/result.json`。Rules rollbackは退避ruleset `projects/hamster-breeding-app/rulesets/967e5b78-cf8d-4c81-a5b8-1a8667549296`へreleaseを戻す（audit/rules-rollback.json、未実行）。

## 2026-10-11 個体別分析UI共有 Phase 2（ローカルPASS）

- サマリー詳細へ体重の個体別分析のコンパクトな入口、既存内訳から体重詳細への導線を追加。健康スコア／状態／ゲージを維持し、個体内の普段・直近と研究比較は別表示。大きな研究カードは体重詳細だけに配置する。
- Phase 1のModel・readonly Repo・研究ViewModel・Cardを再利用。Gold健康評価のSource.server読取を追加し、評価日／feature日／当日Silver／owner／generatedAt=evaluatedAtを照合する。研究だけ未確認・権限不足でもserver確認済み個体内baselineは保持。研究cache/pendingは比較に使わない。既定のPhase 1 strict挙動は維持。
- 共通HealthAnalysisViewModelと3Widgetを追加。活動量はbaseline readiness、D-1の記録有無、既存Gold健康評価を区別し、readyでも記録がなければ記録待ちを維持。Silverなし／不整合では追加分析だけ安全に省略し、保存済み健康評価を残す。不変レポートや過去Silverで現在値を補完しない。
- 検証：全Flutter413件PASS（7分17秒）後、fallback追加4ケース・詳細リンク視認性調整を含む最終関連312件PASS（14秒）。新規Golden4ケース6画像＋既存v3/Phase 1を含む17ケース22画像一致。新規画像の目視実施、既存画像更新なし。Rules Emulator94件PASS、専用demo/localhostのみ、自分のEmulator停止済み。Flutter analyze最終No issues（exit0、8.6秒）。
- 保護：tracked89ファイルにHEADとの差分なし。Functions production、Models、Theme、Home/履歴/既読/AI/課金/trial/onboardingを維持。既存評価・ゲージ・グラフの内部はbyte同一。Phase 1の既存dirty変更を維持、Known Good／本番Firestore／Functions／Rules／Scheduler／APK／実機／Git変更操作なし。
- 本番Rulesは今回反映せず。Phase 1の公開体重研究root/versionへの認証済みdocument get追加のみを後の一括リリースで適用し、list/write/未認証は拒否。Phase 2の追加権限・Function・統計再計算は不要。実機表示は未確認。
- 仕様・変更一覧：docs/individual_analysis_phase2.md。証跡：/private/tmp/hamcare-health-phase2-20261011/、/private/tmp/hamcare-health-analysis-phase2-rules-20261011/rules-emulator.log。

## 2026-10-11 個体別分析UI共有 Phase 1（ローカルPASS）

- 「変化 → 体重」の既存時系列グラフ下に同種研究比較を補助表示。既存 `MetricComparisonBar` / `StatusCard` / `AppTheme` / `ExpansionTile` を再利用。7日・30日・全期間のグラフ、status/scoring、24h→体重の既存fallbackを維持。
- 現在の比較は当日JSTのSilver `daily_health_features/{dateKey}`＋rawプロフィール＋`reference_cohorts` の現在versionから読み取る。全snapshotのserver確認、owner/version/day切替時のクリア、種類・年齢・観測期間・品質・最新測定鮮度を確認。未準備/研究なし/未知種/年齢不適合/古いSilver/読取失敗は省略し、過去の個性レポートを現在値として使わない。統計再計算・Firestore書込みなし。
- 共通 `WeightResearchComparison` / ViewModel / `WeightResearchComparisonCard` を追加し、個性レポートv3の保存済み比較も同じ差分文言へ委譲。保存済み適用判定・旧v1/daily表示を維持。Models/Repo/VM/Widget/Screenを分離し、Phase 2の総合詳細から再利用可能。詳細は `docs/individual_analysis_phase1.md`。
- ローカルRulesに公開体重研究の認証済みdocument getだけを追加。list・全writeは拒否、既存users権限は未変更。本番Rulesへ未反映のため、現行本番の読取権限ではカードを安全に省略する。後のリリースで追加Rulesの反映が必要。当日Silverなしも省略する。
- 検証：関連Flutter140件、全Flutter349件、Rules Emulator94件PASS（実onSnapshotの認証/未認証も含む）。Goldenは新規2ケース4画像＋既存v3の11ケース12画像を照合、v3画像の更新なし。Flutter analyze最終No issues（6.1秒）。初回のRepository書式指摘1件はblock追加だけで修正。テスト選択の存在しないファイル指定1件を修正し、正しい関連一覧でexit0確認。
- 保護：Functions production全src、baseline/health評価、既存Gold model・Repo・Screen、Home/履歴/既読/A3/AI/課金/trial/onboarding、既存v3GoldenはHEADと不変。Known Good・本番Firestore/Functions/Rules/Scheduler・APK/端末を操作せず。対象外の既存体重chart単位m表記と狭幅/大文字status row課題は未修正。
- 証跡：`/private/tmp/hamcare-weight-phase1-20261011/`、`/private/tmp/hamcare-weight-ui-phase1/ui-final.log`、`/private/tmp/hamcare-weight-comparison-rules-20261011/rules-test-listeners-final.log`。commit/pushは今回未実施。

## 2026-10-10 実機確認版のGit保存チェックポイント

- 個性レポートv1/v2基盤、v3視覚修正、関連するオンボーディング・trial/課金gate等、これまでの未コミットのソース・テスト・設計文書を現在地のチェックポイント対象としてまとめる。既存dirty変更を破棄・巻き戻さない。
- v3の検証結果は関連99／全Flutter307／Golden11ケース12画像／analyze指摘なし。Samsungへの署名一致・install-r・ログイン済みHome起動はPASS。詳細画面の最終デザイン評価は未確認。
- コミット候補532ファイル中テキスト412を秘密鍵・管理用tokenの値を出力せず検査し、該当なし。ローカル認証情報、APK/build出力、キャッシュ、隔離deploy auditはGit対象外。新たな本番deploy・Firestore write・機能修正なし。

## 2026-10-10 個性レポート v3 視覚修正 Samsung反映（PASS）

- 検証済みv3視覚修正7ファイルだけを前回成功ソースへoverlayし、隔離 `personality-v3-visual-device-20261010-222215` からdebug APKを1回build。Flutter/JBR/Gradle cacheとlib/main.dart・既存オプション・依存を維持、exit0（66.647秒）。新APKの生成時刻、package `com.gotainu.hamster`、新Widgetのcompiled markerを確認。
- 接続中Samsung実機 の既存base APKをfresh取得して新APKと署名一致を確認。`adb install -r` はexit0/Success、実機APKのSHAは候補と一致。userId・初回install日時・CE/DE data identity・起動前shared_prefs metadata不変。uninstall/data clearなし。
- 起動exit0/Status: ok、前景Activityと画面を確認。既存ログイン済み「今日」Homeを表示。個性レポート詳細の実機デザイン最終評価はユーザー確認待ち（自動タップなし）。
- 保護対象51ファイルと検証済みUI SHA不変。通常working treeは本進捗記録以外変更なし。Firestore/Functions/Rules/Scheduler/AI/記録保存/Known Good/Git操作なし。
- APK: `/Users/gota/hamcare-deploy-staging/personality-v3-visual-device-20261010-222215/flutter/build/app/outputs/flutter-apk/app-debug.apk`。SHA-256: `39f6950f69845987438c86cacf5c06c24cff2e5fd359cbe8746e12cd4713aea7`。証跡: `/Users/gota/hamcare-deploy-staging/personality-v3-visual-device-20261010-222215/audit/result.json`。

## 2026-10-10 個性レポート v3 承認画像への視覚差分修正（ローカルPASS・APK未更新）

- 追加添付の承認済み画像の右側compact構成に合わせ、冒頭を補助文1行、カードを深い夜色と薄い暖色境界へ変更。主値52sp/w600、数値差を横配置し、体重の実値IQR／活動量のバー右数値を主役にした。長い凡例・最新日・研究注意は展開詳細へ集約し、統計はラベル／値を整列。
- Model／Repo／Home未読／履歴／A3保存仕様は維持。旧v1／日次／partial／研究なし／同値／範囲外／240幅・文字3倍／light-dark／Samsung360×780を確認。数値やペット写真のハードコードなし、健康・安定の断定なし。
- 関連99、Golden11ケース12画像、全Flutter307：全PASS。Flutter analyze：指摘なし。全体には既存課金と初回AI→monitoring CTAも含む。Golden後に人手相当の目視・独立レビューを行い、Golden PASSだけをデザイン承認にはしない。
- 保護対象51ファイルSHA、既読／読込のScreen lifecycle、全ThemeDataは作業前と一致。Functions／Rules／Firestore／AI／APK／端末／Known Good／Git操作なし。通常dirty treeの対象外変更を破棄・整理していない。
- 残る視覚差は既存の青色・目盛り実線・数字の太さ・狭幅の注釈折り返し。写真と大見出しを省きAndroid AppBarを維持。ローカル描画は固定fixture/Hiragino、実機最終評価とAPK反映は未実施。
- 再現仕様：docs/personality_report_v3_design.md。証跡：/private/tmp/hamcare-v3-visual-refine-20261010、スクリーンショットは同ディレクトリscreenshots/。

## 2026-10-10 個性レポート v2 本番リリース（サーバー反映済み・APK失敗、全体PARTIAL）

- 明示承認に従い隔離ソース `personality-v2-20261010-173114` から反映。現在のv1稼働sourceを基準に、個性関連だけ追加。最新distance today修正・first freezeを保持。実デプロイZIP全74productionファイルと候補SHAが一致。無関係な31 Functions・33 Cloud Runサービス、既存Scheduler1件、project IAMは不変。
- 3 Functionsは `asia-northeast1` / Node22 / ACTIVE / 100%：`personalityHealthFeaturesWritten` → `personalityhealthfeatureswritten-00002-lip`、`personalityDistanceRecordWritten` → `personalitydistancerecordwritten-00001-ven`、`personalityDailyReports` → `personalitydailyreports-00001-gep`。Firestore Eventarcの地域は既存databaseと同じnam5。初回CLIはretry policyの非対話確認でsource upload前に停止し、本番未変更を再確認して同じ3対象を確認付きで反映（exit0）。依存更新なし。
- 現行Rulesの全byteを保持した追加ルールだけ反映、実Rules SHA `2163e9377f9b77065dd1fcdd0f6943907271357d88c8dd4a1237ddbfe0ae05f7` 一致。統合Rules Emulator133件PASS。履歴とqueueを含む本番index依存queryは全200、既存indexで対応、index追加なし。研究seed/version・SQLは変更不要、実行なし。
- Scheduler `firebase-schedule-personalityDailyReports-asia-northeast1` は `0 9 * * *` / Asia/Tokyo / ENABLED、次回10/11 09:00 JST。OIDC主体・audience・private Run invoker・Scheduler service-agent roleの設定29項目PASS。認証付き実invokeは未実施。attemptDeadline180秒、Function timeout540秒のため長時間処理時は再試行し得る。queue transactionの冪等性を維持、通常100件超は翌朝以降へ持越し（消失なし）。
- Test B read-only smoke PASS：v1 `personality_v1_body_activity` 1件、100g/628.3185307179587m、v1 pointerと全report/updateTime、Bronze/readiness/オンボーディング/trial/billing/使用量は反映前と完全一致。first SHA `1c2233ef5f1db2f49bd8891688ea49bd2fc516b4b932e4fc07ebc4184667fb3f` とupdateTimeも不変。daily pointer不存在・queue0、dry-run `not_queued`。新記録がないため強制発行せず、実日次発行は未確認。
- 公式Functions deployによる設定表現差分を記録：既存個性health triggerのmaxはCF/revisionにも20が明示化、service-level20は維持。現在の実効上限は同じ20だが、将来service-levelだけ上げてもrevision20が残る。service function-id annotationも追加。他のruntime/権限/ユーザーenvは維持。旧startInitialTrialの0% revisionやRAGは不変。
- 隔離Flutter analyzeはNo issues、関連115件PASS。Samsung実機 は接続を確認し既存APK/署名をread-only取得、v1 APK SHAと一致。v2 debug APK buildは1回・exit1（162秒）：既存Gradle cacheの `kotlin-dsl/scripts/3f26cbb0a9a420934702731ad434ba50/metadata.bin` 欠落。新APKなし、新署名比較/install/起動/実機UI確認は未実施。cache修復・削除・再build・uninstall・data clearなし、既存v1を保持。
- 通常working tree開始時568ファイルは本進捗記録以外567byte不変、削除/対象外変更なし。Known Good/Git/AI/RAG/Auth/課金/本番Bronzeを操作せず。隔離release検証はFunctions unit61/compile/discovery、Rules133、Flutter関連115/analyze PASS。全テストの過去結果を今回再実行した件数として扱わない。
- 証跡・復元資材：`/Users/gota/hamcare-deploy-staging/personality-v2-20261010-173114/audit/release-result.json` と `rollback-plan.json`。異常時はSchedulerを停止、退避したv1 managed Function sourceへ対象限定で復元、必要なら新queue bridgeを停止。追加read保護Rulesを保ち、first/v1/daily/研究version/既読markerは削除・書換しない。復元は未実施。残りはAPK環境復旧/更新後のグラフィック・未読Home・詳細既読・履歴・再起動確認と自然な日次発行。

## 2026-10-10 個性レポート v2 リリース前最終調整（ローカルPASS）

- 3項目PASS。v1の `report_pointers/personality` と日次 `personality_daily` を分離し、旧v1 ready構成別発行も継続。v2はserver確認済みdaily不存在時だけv1へfallback。既存Gold/firstは不変。実staging v1 reader/model＋現backend Emulator Goldの互換replay2件もPASS。
- Home描画write0、詳細画面表示成功後だけreport単位既読、既読後完全非表示、次report再表示、過去閲覧と最新未読の分離を確認。既読/Home/history productionは追加変更なし。
- queue103件で100件上限・overflow保持・部分失敗延期・別呼出/翌朝処理・retry/parallelを確認。古いfailure workerが新queueを延期する競合だけ最小修正。通常schedulerは1日1回なので100件超は翌朝以降の待機となる（消失なし、同日自動drainなし）。
- 検証：Functions関連108、Rules88、Flutter関連60、実旧v1 reader2件PASS。Functions全src TypeScript noEmit、Flutter全体analyze exit0/No issues。今回全Flutter再実行なし（前工程199件PASSは別結果）。
- 開始時568ファイル中12のみ更新、556byte不変、削除/対象外変更0。既存dirty変更、Known Good、統計/health/readiness/first freeze/課金/trial/AI/onboarding/依存は保護。本番deploy/Firestore書込み/APK/実機/Git操作なし。
- 適用順：現行と比較した隔離候補 → 追加Rules → 個性関連3 Functions → 分離pointer/旧版互換smoke → v2 Flutter。研究seed/SQL追加不要。index/Scheduler/IAMと100件上限の待機量は本番適用時確認。詳細・変更一覧・rollback：`docs/personality_report_v2.md`。証跡：`/private/tmp/hamcare-personality-v2-release-adjust-20261010/`。

## 2026-10-10 個性レポート v2（ローカルPhase1–3完了、本番未反映）

- JST翌朝09時、前日cutoff・新しい有効記録日のユーザーだけをqueueから処理し、immutable `daily_YYYY-MM-DD` とlatest pointerをtransaction発行。既存reader/builderを再利用し、欠けた当日Silverだけcreate、既存Silverとfirstは上書きしない。today distanceの既存early returnを保持するためqueue-only bridgeを新設。最大100件/起動、失敗はmetadataだけ保存して翌朝へ延期。
- `MetricComparisonBar`、AppTheme/StatusCard/ExpansionTileを使い、100g・628m/日、適用可能な研究中央値/IQR、個体内活動量比較を描画。健康スコア、正常範囲、推定percentileを作らない。cutoffとSilver分析日を区別し、旧v1 Goldも表示可能。
- Homeは健康hero/重要異常を優先し、最新server確認済み未読だけ表示。実描画後にreportごとのimmutable markerをcreateしてカードを消す。Drawer履歴は20件ページング・exact ID detail・旧first入口を維持。owner切替を分離し、旧firstも描画後に最初のA3日時だけ保存、既存Analyticsイベントの誤owner計測を防止。
- 検証: Functions関連137件（単体97＋Emulator40）、Firestore Rules127件、全Flutter199件PASS（exit0、416秒）。Flutter全体analyzeはNo issues、Functions全source strict TypeScript noEmit PASS。通常repo依存の読取り待ちは同version既存staging依存lookupだけで回避し、package/lock/tsconfig/compiled libは維持。Storage7ケースは今回対象外。
- 元dirty tree553ファイルは削除0・対象外変更0、対象23更新＋新規15。既存baseline/health/readiness/first freeze/trial/課金/AI/記録/onboarding sourceを保護。Known Good、Git、本番Firestore、deploy、SQL、AI API、APK build、実機は操作なし。専用loopback Firestore Emulatorのみ使用し終了済み。
- 本番前: 現行source/Rulesと比較した隔離候補、Rules、対応Flutter更新、個性関連3 Functionsの対象deploy、index/Scheduler/IAM/100件上限の運用確認が必要。既存v1 pointer readerはdaily ID非対応なので、旧版混在のまま日次pointerへ切り替えない。研究seed/version・SQL変更は不要。詳細/変更一覧/rollback: `docs/personality_report_v2.md`。

## 2026-10-09 個性レポート v1 Samsung上書き更新・起動確認

- ユーザー接続済みSamsung実機（SM_S911N）に限定。実機から読み取った既存APKと隔離debug APKの署名SHA-256が一致し、指定APKの検証済みSHA `38b443671ffdd807e5498561b24153c055dd7adf2efb025ca6cfe5c61cedaae7`も一致。
- `adb -s <既存実機> install -r <指定APK>` はexit0／Success。実機base APKのSHAが指定APKと一致。初回install日時とCE/DE data inode不変、アンインストール・data clearなし。
- `am start -W -n com.gotainu.hamster/com.gotainu.hamster.MainActivity` はexit0／Status: ok。前景Activityと実画面を確認し、ログインを保持した「今日」Home、新「うちの子の個性レポート」入口を確認。レポートは操作して開いておらず、内容閲覧・A3実イベントは未確認。
- ソース変更・再ビルド・クラウド設定変更・AI呼び出しはなし。既存dirty変更とKnown Goodは保護。実機証跡: `/Users/gota/hamcare-deploy-staging/personality-v1-20261008-185441/audit/device-update-20261009-120939/result.json`。

## 2026-10-08 個性レポート v1 本番反映（サーバーPASS・実機更新待ち）

- 明示承認された本番リリースを隔離ソース `personality-v1-20261008-185441` から実施。最新本番distance source generation `1791365993364287` を基準とし、既存全ファイルはindexの新export以外byte一致、新4moduleのみ追加。実デプロイZIPとの全SHA照合PASS。既存first freeze／distance today再計算／Flutterオンボーディング修正を保持。
- `personalityHealthFeaturesWritten` のみ新規deploy、`asia-northeast1`／Node22、revision `personalityhealthfeatureswritten-00001-jod` ACTIVE／100%。現在日のSilver written trigger・retry設定を確認。UID allowlist gateなし。既存31 FunctionsとRun servicesの設定・revision・trafficは不変。自然なSilver更新による新triggerの実処理は今後の確認項目。
- VetCompass 4種pointer＋immutable version計8docをcreate-only seed、read-back一致、再実行write0。現本番Rulesへreport/pointer/reference保護の3ブロックだけを追加し反映。旧Rules全byte保持、Rules Emulator103件PASS、実Rules SHA一致。旧Rules releaseと全設定を隔離auditへ退避済み。
- Test B本番smoke PASS。`personality_v1_body_activity` 1件、100g／628.3185307179587m、実profileのsyrian／成体条件を確認し研究IQR100–160g比較を適用。pointer正当、再実行write0／重複なし。既存Bronze/Silver/readiness/health/onboarding/trial/billingと使用量のhash/updateTimeは不変。
- 既存first SHA `1c2233ef5f1db2f49bd8891688ea49bd2fc516b4b932e4fc07ebc4184667fb3f`、updateTime `2026-10-07T02:52:30.807773Z` は完全不変。AI使用1／50000micros、validation使用5／250000micros、billing未作成も現在値で確認。
- bounded補完: 全30 UID、ready候補Bのみ1件、追加発行0／no-op1／失敗0。max100・batch5・ユーザー処理直列。無関係なユーザーへの書込みなし。
- A3 SQL: server viewの生成条件4箇所更新＋不足していたstrict JOIN view新規作成、実read-back/query PASS。APIの空privacyPolicy表示で監査チェックが一度停止したが、01の再PATCHはせず02のみcreate-onlyで完了。dataset/ACL/raw/normalized/previewを保持、任意dashboard未作成。生成eventのBigQuery到着1件を確認。既存test-only ingest境界は維持し、一般UIDのBigQuery集計完了とは扱わない。実閲覧／GA4受信は未確認。
- 隔離Samsung向けdebug APKは1回のbuildでPASS（exit0）、`lib/main.dart`・既存SDK/JBR17/Gradle cacheを維持、pub get/cleanなし。APK SHA `38b443671ffdd807e5498561b24153c055dd7adf2efb025ca6cfe5c61cedaae7`。署名は既存ローカルAPKと一致したが、対象Samsung実機 はADB未接続のため実機署名比較・install-r・画面目視は未実施。アンインストールなし。
- release隔離検証: Functions95件、Rules103件、operator14件、bulk12件、SQL safety12＋resume8件PASS。前工程のFlutter128件／analyze／TypeScript noEmitは検証済み実装を保持。通常working tree553ファイルの完全一致を確認し、今回の通常repo変更は本進捗記録追加のみ。Known Good／Git／RAG／AI API／Auth／課金設定は操作なし。
- 証跡・復元資材: `/Users/gota/hamcare-deploy-staging/personality-v1-20261008-185441/audit/release-result.json`。異常時は新発行停止、退避Rules／SQL定義の復元を対象別にレビューして実施し、既存first・発行済みimmutable report・研究versionは削除しない。実機更新とHome新旧report閲覧／A3到着確認が残るため全体判定PARTIAL。

## 2026-10-08 個性レポート・リリース候補補完（本番未反映）

- 当日Silverがない既存ユーザーのbackfillを修正。既存 `fetchHealthSourceData` / `buildDailyHealthFeatures` を再利用して当日Silverだけをcreateし、確定Silverから新個性レポートを発行する。既存Silver、過去Silver、legacy first/readiness/健康評価/通知は書き換えない。dry-runは再計算previewのみで書込み0。
- テスト先行後に実装。Functions関連95件、Bronze→Silver→Gold Emulator受け入れ10件、既存Gold Emulator回帰9件、Rules58件、実Home導線のWidget E2E6件がPASS。exact B UIDも専用demoの合成データだけで100g／628.3185307179585m、両指標readyを検証し、firstのcanonical SHA/updateTime不変とretry書込み0を確認。
- TypeScript全体noEmit、Flutter全体analyzeは終了コード0。全Flutter回帰128件が成功（終了コード0、5分44秒）。
- 本番deploy、Firestore本番書込み、SQL実行、AI/RAG、実機、APK buildは未実施。既存dirty変更とKnown Goodは保護。現seed/backfill CLIはdemo＋loopbackのみで、本番投入/補完には別途承認されたAdmin運用経路が必要。
- Functions／Rules／研究seed／SQL／Flutterの適用順序とrollback: `docs/personality_report_release.md`。

## 2026-10-08 個性レポート（ローカル完了・本番未反映）

- 既存当日Silverの個体ベースラインを利用し、体重のみ／活動量のみ／両方のimmutable個性レポートと最新ポインタを実装。既存Bronze/Silver計算・健康評価・readiness・initial trial・凍結済みfirstは変更しない。
- 4種のVetCompass成人体重比較基準、誕生日／最古観測日の適用判定、metadata-only生成／閲覧イベント、Home導線／部分レポート画面、owner read／client write拒否Rulesを追加。
- 検証: Functions現行source89件、実Firestore transaction統合9件、新Rules58件＋既存Firestore Rules45件、Flutter全122件が成功。Flutter analyze／TypeScript noEmitは問題なし。Storageの既存7ケースは対象外。
- 本番deploy・Firestore本番書込み・SQL実行・AI/RAG・実機・APK buildは未実施。seed/backfillは専用local emulator＋demo projectのみ。比較基準の投入を新レポート発行より先に行う必要がある。当日Silver欠落の補完は上記リリース候補修正で対応。
- 契約、全変更ファイル、検証範囲、本番適用前事項: `docs/personality_report_v1.md`。

## 現在地

- **最新作業（2026-11-15）**：Task7準備94571d9承認済み。Task8はApple Service ID／既存Primary／固定handler／既存Key再利用・Firebase保存を確認し、同意必須Appleを同Previewへ有効化。実Chrome Appleログインでproject／現在Apple／native↔Web UID一致true、emailPresent/verifiedはfalse。15分recency falseは有効日時の経過超過で、通常sessionへ15分制限は追加しない。メールなしAppleをAdmin失効検証・同UID・現在provider/subject厳密一致の別basisで確認し、メール/Google両verifiedと実falseを維持。runtime892／static391PASS、helper24offlineは別枠。Preview268f5115e3afec45・11/22 15:37 JST期限、35SHA/header/6除外404PASS、Preview2Functions ACTIVE・他55/Webhook/live/Auth policy/domainと元アプリ差分保持。再ログインなしaccount panelへ進むがmain_pet guardでplan無効、billingは認証拒否でなくapp_account_required。データ作成/ガード回避なし、実決済/Portal往復は保留。新Auth/本番Firestore/Stripe/既存契約変更0。今回実装1コミット保存予定、main/live/Flutter操作なし。

- フェーズ: 日本限定・iOS／Android同時公開準備。`REL-02`のPlay Alphaは本人承認の既存14変更を2026-10-27 11:09 JSTに審査送信。2026-10-27 11:19 JSTに送信ID1「公開」を本人確認済み（今回もConsoleで読取照合）。製品版一般公開・必要人数／期間の達成とは区別する。通常登録・カードなし0円契約・通常権限同期・Android有料gate・審査アクセス保存PASS、`REL-03`の既存実機／Play更新／DeviceCheck PASSは維持し再実施しない。旧Case22954972のscope外回答を受け、本人承認のApp Review新問い合わせを2026-10-27 11:46:34 JSTに送信。受付公式完了画面と11:48:45 JST受信の受付メールで番号一致を確認／新Case103009817213、決済判断は回答待ち。
- RC4切替の現在の最優先（2026-11-09）: 旧版互換P1は本人判断で非ブロッキングとして閉じた。後続の微修正反映版1.0.1/code5・build5は署名済み成果物生成・整合確認済み。Play既存Alpha code5と掲載名Ham Careは保存済み、日本／本人1名を維持し、未送信2変更・履歴ID1〜3のまま。本人から「押した」との回答後に読込み完了まで待って再読したが、未送信2変更・履歴ID1〜3のままで送信受付未確認、原因未特定。残る操作はConsole受付の再確認と承認済み2変更の送信のみで、追加の本人クリック待ちとはしない。iOSは11/9 11:09 JST Delivery完了・ASC処理完了、本人の明示承認後に輸出申告Save済みで、既存本人実機確認グループ1Tester/4Buildsのbuild5 Testing・90日を確認済み。両Consoleの日本語名は正確にHam Careで保存表示を確認。端末4→5の更新・保持確認は未実施。既存code4/build4本人確認と限定114PASS／既存2FAIL・analyze57新規0を維持し、同じAI／認証等を再試験しない。外部追加・招待・連絡、main merge／push・サーバー反映・製品版公開は行わず、Apple Case103009817213の回答待ちを維持する。以下の募集準備欄は従来の記録として保持する。
- 最優先タスク: `REL-02`のクローズド募集開始判断。Alpha code3・日本のみ・登録1名と11/2実opt-in0／12人以上14日・製品版申請無効を分離して確認済み。未投稿のX／YouTube募集原稿・参加案内と、応募／フィードバック各6問の実フォーム2件は本人追加承認後11/2 13:32 JST公開・回答受付PASS、現0回答。応募回答URLを募集原稿へ差し込み済みで、本人がXへ投稿すれば応募受付できる状態。投稿・招待・tester追加は今回行わず、採用後Alpha専用リスト案は未設定・別承認待ち。既存code3／build3配信・端末確認・88枚と限定12PASSは維持、Apple Case103009817213と決済判断は回答待ち。
- ブランチ: `codex/pre-optin-polish-20261108`
- ブランド基準コミット: `f972be0 feat: refresh hamster brand mark`
- 完了範囲: iOSの恒久ビルド環境・元workspaceの手動⌘R・実機起動・Releaseホーム起動／ログイン保持、通常版のAppleサインインとGoogle実認証・再起動保持、通常権限での21日体験開始と旧版・最新両版の文字AI回答（本人報告）、Android同署名上書き／Home・ログイン・既存記録保持。
- 公開状況: 同意対応AAB1.0.1／code2はPlay upload・既存本人1名の内部配布PASS、Alpha code2差替えと10/27差分保存後、本人承認の既存14変更を2026-10-27 11:09 JSTに審査送信。2026-10-27 11:19 JSTに送信ID1「公開」を本人確認済み（今回もConsoleで読取照合）。製品版一般公開・必要人数／期間の達成とは区別。指定iOS IPAも10/26 9:50デリバリ・本人承認の輸出回答保存・本人1名のTestFlight内部TestingまでPASS。iOSのTestFlight更新・Home／ログイン／既存記録保持は本人PASS。同意Dialog表示・取消・入力保持と設定の撤回項目表示は本人PASS。Androidは既存52ab証明書のローカルReleaseへ削除なし上書き・起動PASS、本人のHome・ログイン・記録保持と設定項目表示もPASS。独立VMでPlay署名code1→code2更新と本人のHome・ログイン／記録保持はPASS。普段使い52ab端末の署名移行は未実施で、削除や鍵変更で回避しない。Release DeviceCheckはサーバー計測PASS。App Store基本設定・App Privacy確定・Play申告保存も維持。App Store一般審査・Production一般公開は未実施。
- 文書の扱い: 日付別節は当時の経緯・証拠として保持し、後続で解消した旧OS待ち・旧AI拒否・旧APK未導入を現在の残件へ戻さない。MATOMEは全体図、進捗の正本は本書。

## 次に着手する作業

- **今回の停止点**：タスク1の1コミット後に停止。本人承認後だけタスク2「Webログイン」へ進む。以下の既存リリース計画は保持し、今回の範囲へ自動追加しない。

1. `REL-02`：Alpha code3・日本のみを維持。11/2の許可登録1名／実opt-in0と、12名以上が申請直前14日連続で参加する条件を分離する。募集素材と応募／アンケート各6問の実フォームは本人追加承認後に公開・入力画面確認PASS、応募回答URLをX／YouTube原稿へ、feedback回答URLを採用後案内へ差し込み済み。本人が内容確認後にXへ投稿すれば受付可能。募集実投稿・招待・tester追加／Alpha専用リスト設定は今回行わず、共用internal-testersは増員しない。通常21日体験・最大20件／有限共有枠、既存権限、Apple決済判断保留を維持する。
2. `REL-03`／`SEC-03`：Google本人OAuth→HamCare復帰→Home→再起動保持は現Releaseで本人PASS。DeviceCheckは登録・Release指定に加え、TestFlight更新時刻の交換HTTP200と対象iOS AppIDのVALID検証を組み合わせたサーバー計測で実動作PASS。個体SDK callback・token・expiryの直接観測は行っていない。既存AI／Apple／Google認証の再実行は不要。残る公開対象操作は既存回答・履歴で確認しAIを再送しない。
3. `REL-02`／`ANL-01`：App Privacy10typeのPublished、Play掲載／Data Safety差分保存、公開Privacyの1path改訂に加え、通常文字AI同意の局所実装・限定26件は完了。未確認を理由に再開発・実AI再送しない。Playのアイコン／feature graphic／4枚の画像と掲載・Privacyは10/27に保存済みを確認。審査用アクセスも保存・再読取PASS。本人承認後11:09 JSTに14変更を送信し、送信ID1は同日11:19 JSTに公開済み。iOSの必要素材は今回の対象外。
4. `REL-02`：同意対応最終AAB／IPAの生成・署名検証、両ストアupload／本人内部配布、Alpha code2保存は完了。Play14変更は2026-10-27 11:09 JSTに送信済みで、送信ID1は同日11:19 JSTに公開済み。iOS TestFlight更新・Home／ログイン／記録保持と同意説明／取消／設定項目は本人PASS。Androidローカル更新の本人PASSに加え、独立VMの実Play code1→code2更新・署名／導入元／UID保持・本人Home／ログイン／記録保持もPASS。普段使い52ab端末は維持。Release DeviceCheckサーバー計測PASSも再実施せず、実同意承諾／撤回・AI再送は追加しない。
5. `RAG-02`／`REL-03`：既存回答の動画タイトル／画像表示、外部動画を開いてHamCareへ戻る操作はiOS／Android両方で本人PASS。最新両版AI各1件も完了済みで、RAG／動画確認は再実施しない。Release DeviceCheckも上記2のサーバー計測でPASS。個体SDK callbackの直接未観測を新AI送信で補おうとしない。
6. `REL-02`：旧Apple Case22954972は10/27に代替配信／決済担当から当該窓口のscope外との回答を受領。これはStripe導線の可否回答ではない。本人承認の指定文面で、公式 https://developer.apple.com/contact/app-store/ から実窓口「App Review → App Review に関するその他のお問い合わせ → Eメール（公式フォーム）」を選び、2026-10-27 11:46:34 JSTにApp Review宛て新問い合わせを送信。受付結果公式完了画面と11:48:45 JST受信の受付メールで番号一致を確認、新Case ID103009817213。回答は未受領で、A／B導線・Stripe維持条件の判断は回答待ち。 独断でIAP／Billing実装・購入導線変更・同文問い合わせ再送・App Store審査提出を行わない。
7. `DES-01`：対象3項目の初版範囲は確定。既存RAGを採用し、AI-02反復検索・BETA-01専用権限を初版へ追加しない。旧要求・未実装差分は履歴／将来検討として残すが、今回の公開阻害条件に戻さない。通常体験の期限・利用履歴・有限予算を変更しない。
8. `AVT-06`：標準88枚統合・新16限定12件PASS、候補生成と両OSテスト配信まで完了。Alpha code3は公開済み、TestFlight build3は本人1名Testing。iPhoneの削除なし更新・再ログイン不要／データ保持・Pied再表示・white_face代替表示は本人PASS。Android専用AVDではConsole署名code2の直接初回導入と、後続の正式Play2→3配送を分離し、署名／導入元・データ領域継続・native／88PNG一致を確認。現code3で通常利用・既存データ閲覧とPied再表示が本人PASS。更新前ログイン基準の時系列未確定につきcross-update再ログイン不要は未確認。元72枚／署名／権限／履歴と既存成功試験を維持し、今回これ以上の本人操作や全8状態強制試験は求めない。white_face未制作は代替表示で非阻害、analysis_preparing／円形枠は対象外。

## 検証済みの状態

### アプリとバックエンド

以下は各記録日の確認範囲。10/25後続ではGoogle実認証・承認済みストア保存／Privacy1path公開に加え、最新工程で通常文字AI同意だけを局所実装し、限定26件と対応AAB／IPAを確認。通常権限・分析・課金は変更していない。過去テストと今回の限定テストを現行版全体の再検証と扱わない。

- Flutter静的解析: エラーなし（2026-09-15再確認）
- Flutter自動テスト: 30件成功（2026-09-15再確認）
- Functions単体テスト: 30件成功（2026-09-15再確認）
- Firestore / Storageルールテスト: 46件成功（2026-09-15再確認）
- 星の獲得Functions: TypeScriptビルド、重複防止・開始日・記録の存在確認・50個達成の単体テスト成功（2026-09-17）。4 FunctionsとFirestoreルールを本番Firebaseへ反映済み
- Android修正版（2026-10-25）: 通常 `lib/main.dart` の1.0.1+2 Debug APKを作成。現行署名・ID・要求権限一致後に削除なしで上書きし、起動・Home／ログイン／既存記録保持を本人確認済み。元環境と依存lockは保持し、互換調整は作業コピーだけ。追加実AI各1件は後続の本人報告により最新両版とも完了。
- Android過去検証（2026-09-15の履歴）: debugビルド成功。エミュレーターへの更新時に容量不足で`INSTALL_FAILED_INSUFFICIENT_STORAGE`が発生し、開発ツールが旧デバッグ版をアンインストールしてから新版を再インストール。エミュレーター内のアプリデータは失われた可能性があり、画面の実機確認は未完了
- 健康スコアv2実データdry-run: 60日分を読み取り専用で再計算。個体ベースライン導入後、活動量評価可能日は2日から9日、完全な参考点表示日は1日から7日へ増加。53日は入力不足のため点数非表示（2026-09-14）
- 通知v2実データdry-run: 評価履歴59件に対し、旧方式36候補から新方式14通知へ約61%削減（2026-09-13）
- 通知v2バックエンド: 健康関連6 FunctionsとFirestoreルールを `hamster-breeding-app` へ反映済み（2026-09-13）
- Android正式パッケージID: `com.gotainu.hamster`
- iOS Bundle ID: `com.gotainu.hamster`
- 初回iOS配布対象: iPhoneのみ
- Android実機でPlay Integrityトークン取得を確認済み
- iOS実機で明示的App IDによるRelease署名を確認済み。10/24に新環境で元workspaceの⌘Rと通常版Release AOTの実機導入・ホーム起動・ログイン保持までPASS。
- iOS認証: メール／パスワードでHome到達、Appleサインインは通常版で本人確認済み。Googleは現Releaseで本人OAuth・アプリ復帰・Homeを確認し、終了／再起動後のログイン保持も本人PASS。auth.dart:167〜177のFirebase credential交換とmain.dart:469のAuthGate経由でのHome到達であり、SDK初期化だけの旧結果と区別する。
- 通常体験と文字AI: 21日・最大20回・個人1,000,000microsを維持し、検証UID限定入口と共有枠到達の拒否を修正。旧iOS Debug／旧Androidの回答表示は本人PASS。10/25の既検証UID照合はiOS1/20回・Android3/20回、開始／終了日時・使用metadata・Android飼育関連6collection件数が更新前後不変。現行iOS Release／Android更新版のAI各1件は後続本人報告で完了。新しい使用量・時刻の個別照合記録は今回未取得だが、それを理由に再送しない。
- Stripeの月額500円プラン、Checkout、Customer Portal、Webhook、Firestore契約状態反映を確認済み
- 解約予定の有効契約を、期限まで有料として扱う複数サブスクリプション優先処理を反映済み
- プライバシーポリシー、利用規約、特定商取引法表記、サポート、アカウント削除案内を公開済み
- Firebase Analyticsの収集内容に合わせたプライバシーポリシーを2026-09-07にHostingへ反映済み。10/25には承認済みUser-ID／限定分析／AI送信経路2段落だけを1path限定公開し、実URL200・HTML SHA一致／他path保持PASS。証拠 `/private/tmp/hamcare-privacy-hosting-20261025/deployment-state.json`
- アカウントを維持したままAI相談履歴またはプロフィール画像だけを削除する手順を、アカウント削除案内ページへ追記して2026-09-12にHostingへ反映済み

### Android提出物

- **現在の提出対象（同意対応後）**：`/Users/gota/hamcare-deploy-staging/android-ordinary-update-20261025/artifacts/hamcare-1.0.1-code2-consent-signed.aab`。1.0.1／code2、160,904,769bytes、SHA256 `9ac74bc4e15497728c77c5736344964fb07d268aefdb972d0006e3d3e860b237`、min24／target36・非Debug。既存upload証明書SHA256 `7e9bf2b197902c7fca90bb79eb5a1cd699f9cc83a9f8ad1c6ba32f1546f23410`一致、JAR署名／ZIP／Bundletool PASS。同意実装ソースからの3 ABI AOTを確認。audit/release-aab-consent-signed-result-20261025.json等に証拠。10/26に指定AABをuploadし既存本人1名の内部配布PASS。Alpha release2へ同code2を差替え保存し10/27差分後は14変更審査未送信。ローカル同署名更新・本人Home／ログイン／記録と設定項目はPASS、独立VMでも実Play code1→code2更新／保持はPASS。元52ab端末へのPlay署名移行とは分離する。以下の旧AABは証拠として保持する。

- Google Play個人デベロッパーアカウント: 作成済み（2026-09-06）
- Google Play本人確認: 完了（2026-09-06）
- Android実機アクセス確認: 完了済み
- 連絡先電話番号確認: 完了（2026-09-07）
- Google Playアプリ: 作成済み（2026-09-07）
- Google Play内部テスト: 現在は同意対応`1.0.1`（versionCode `2`）を既存本人1名へ内部公開済み（2026-10-26 9:19）。旧`1.0.0`／code1の公開は2026-09-07の履歴
- Google Play内部テスト配布版: 登録済み実機へPlayストアからインストールし、正常起動・基本画面表示を確認済み（2026-09-07）
- Google Playプライバシーポリシー: 公開URLを登録・保存済み（2026-09-07、審査送信前）
- Google Play公開済みAAB記録: `1.0.0`（versionCode `1`）、119,725,501 bytes、SHA-256 `3c1f8eb2933ef6391c20e1c7b1382aec2d18fe26da81c1b715745637b34fe337`（2026-09-06生成、署名・Bundletool検証成功）
- 通知v2内部テスト候補AAB: `build/app/outputs/bundle/release/app-release.aab`
- 候補生成日時: 2026-09-14 10:30:59 JST
- 候補サイズ: 119,825,645 bytes
- 候補SHA-256: `4ea6a144a0a5f5857d6d0d3d87880bc62a41f114df9f6ef6e4d24cf6d91ffbbe`
- 候補versionName / versionCode: `1.0.1` / `2`
- 候補minSdk / targetSdk: `23` / `36`
- 候補署名・ZIP整合性検証: 成功
- 候補のGoogle Playアップロード: 未実施（9/14候補の記録）。
- 10/25の同署名更新APKは開発確認用。後続で下記最新署名済みAABを別途生成・検証済み。当時のcode使用状況・最低OS差・upload後検証は後続で完了。Android7.0／API24以降は本人確定、10/26にcode2をPlayが受理・内部公開。端末の署名差による更新不可は別残件。
- 後続10/25工程：最新sourceのRelease AAB（1.0.1／code2・min24／target36・非Debug）を新規作成、Bundletool／ZIP検証PASS。9/14の旧候補とは別。SHA256 `cd1f2f791fba3a7c490ffd94e4acb55e81c6f15109c6cfa21416e01b35c866ca`、未署名で提出不可。当時の未署名状態は次行で解消済み。当該候補生成時はアップロード／端末更新なし。使用済みcode・最低OS差は後続で確定し、現在の指定成果物のupload結果は本節先頭を参照。
- 同工程の署名完了：`/Users/gota/hamcare-deploy-staging/android-ordinary-update-20261025/artifacts/hamcare-1.0.1-code2-signed.aab`、160,854,886bytes、SHA256 `b3d496a67ae1631dd9ce03e8e35943e1521113ef126555ac60173b5a19f57615`。upload証明書SHA256 `7e9bf2b197902c7fca90bb79eb5a1cd699f9cc83a9f8ad1c6ba32f1546f23410`がConsole公開証明書と一致、JAR／ZIP／Bundletool／manifest PASS。未署名版との非署名entry同一、元鍵・設定・Dart／native／lock／SDK保持。署名後の証拠は既存audit/release-aab-signed-result-20261025.json。旧候補の未署名状態は経緯で、現在の署名は完了。後続でAndroid7.0以降を本人確定、code2の未登録もConsole確認済み。最低OS理由の再ビルドは不要。その後のAI同意対応候補は本節先頭で再生成PASS。元成果物は同意対応前の履歴として保持し、提出対象はconsent-signed版。アップロード・審査は未実施。

### iOS提出環境

- **現在の提出対象（同意対応後）**：`/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/hamcare-1.0.1-build2-consent-appstore-20261025.ipa`。1.0.1／build2、107,026,058bytes、SHA256 `67a7305d7934adfa0565e1ca6375bd101a16b80dbb274019e4c268483ad8695e`。新Release Archiveから既存Distribution／App Store Profileでexportし、codesign strict／ZIP／get-task-allow=false／Apple Default／APNs production／Archiveとのコード・資産一致PASS。Archive ZIP：`/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/Runner-consent-development-archive-20261025.zip`、157,948,889bytes、SHA256 `90ced1a78a539f204e22d29c613ffb60f61a001f8e988d7d90c52c24c529c202`。App Store Connect ID6826783734へ10/26 9:50に指定IPAをデリバリ済み。本人承認後の輸出申告保存、本人1名の内部グループで1.0.1(2) TestingまでPASS。本人のTestFlight経由更新・Home／ログイン／既存記録保持はPASS。同意Dialogの説明表示・取消・入力保持と設定の撤回項目表示も本人PASS。実同意承諾／保存済同意の実撤回は行わない。以下の同意前IPA／Archiveは履歴として保持し、提出対象から外す。

- 使用環境: macOS27.0.1への更新は本人報告（今回再照会なし）。Xcode `/Applications/Xcode_27.1.app`（27.1／SDK27.1）、恒久Flutter `/Users/gota/tools/flutter-3.47.7-hamcare-ios`（3.47.7／Dart3.13.5）。旧Flutter3.32.8は保持。
- 元の `ios/Runner.xcworkspace`、Runner／`lib/main.dart` でGUI⌘Rの署名Debugビルド・導入・実機起動を確認済み。現在のiPhone17e／iOS26.5.1には同署名Release AOTを維持し、ホーム起動・Home表示・ログイン保持は本人PASS。普段使いのReleaseをDebugで上書きしない。
- 通常版のAppleサインインは本人確認済み。最新両版の追加AI各1件は本人完了報告を受領。Google実認証・再起動保持も本人PASS。Release DeviceCheck実attestation・削除時token取消等の残証拠とは分け、AIを再実施しない。
- Apple Development署名・Profile／Bundle／Team／Apple entitlement整合と既存Release ArchiveはPASS。後続のDistribution exportもPASS。成果物 `/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/hamcare-1.0.1-build2-appstore-20261025.ipa`、107,016,841bytes、SHA256 `3f2b61b017e93c451b5c96e10447cea82feaea987445cb23665f2c447c2cfd48`。Apple Distribution leaf SHA1 `A892CCD8653B90330232F787AEE7EA4E7A7A7FE5`、App Store Profile／get-task-allow=false／Apple Default／APNs production／codesign・ZIP PASS。元Archiveのコード／資産と同一。証拠は同既存audit/appstore-ipa-result-20261025.json。upload・TestFlight・審査は未実施。これは同意対応前のIPA。現在の最終候補は本節先頭のconsent-appstore版。
- App Store Connect ID6826783734を作成し、1.0.1／手動公開／日本1国／無料（JPY0）・説明／キーワード／プロモーション文／support URL／Privacy URL保存を再読取で確認。App Privacy10typeは本人確約承認後Published。審査用アクセス・画像・カテゴリ／年齢等の必要欄・iPhoneのみ互換配信設定は提出前残件。
- 旧macOS14.8.9／Xcode16.2と新SDK不足は9/6〜10/18の履歴に残すが、現在の環境準備を再び未完了にしない。詳しい経緯は[iOS第2工程](docs/release/ios_runtime_preparation_stage2_20261018.md)、[署名・実機結果](docs/release/ios_signing_physical_auth_20261018.md)を参照。

### ブランド・ストア素材

- 最終ロゴ: 黒背景、生成り色の鉛筆線による下膨れのハムスター顔、開いた下部輪郭、頬と交差する左右3本のひげ、口なし、下部に心拍波形
- iOS/Androidの全アプリアイコンへ反映済み
- App Store 1024pxアイコン、Google Play 512pxアイコン、Google Playフィーチャー画像を作成済み
- Google Play用Androidスマートフォン画像4枚（1080×1920、JPEG）を作成・検証済み
- App Store用6.9インチiPhone画像4枚（1320×2868、JPEG）を作成・検証済み
- ストア掲載文、審査メモ、プライバシー申告チェックリストを作成済み
- ストア原稿の文字数、全画像の寸法・形式・非透過、AABのSHA-256を2026-09-06に再検証済み

## タスク一覧

| ID | 状態 | 内容 | 次の確認・作業 |
|---|---|---|---|
| `WEB-01` | Apple Safari主要E2E・Test契約後始末完了／本番公開前残件あり | Webファースト戦略C・公式LPから独自申込画面へ | 4892d48450fe承認、コード変更なし。本人Safari Apple再login／古いエラーなし、550円Test決済→同UID Webhook active反映→Portal支払方法変更・期間末解約・Web復帰を確認。最終canceled／有効0／未完0／Preview失効、業務4文書不変。VoiceOver8対象・戻る再読込logout再loginは本人PASS、pendingと有効契約時management読上げは未確認。実機画像はMac映像接続の制約で未保存。Relay配送・法務整合等を残し、本番切替準備のみ可。指定docs2件の独立commitのみ、merge／pushしない。詳細は先頭E2E節。 |
| `SEC-04` | 完了 | Stripe契約状態の競合・再同期修正 | 運用監視 |
| `SEC-03` | 完了 | iOS App Check用の明示的署名設定 | Development／Distribution署名整合とRelease DeviceCheckサーバー計測はPASS。個体callback/tokenの直接未観測は限界として保持し、設定や認証を作り直さない |
| `SEC-02` | 完了 | Android Play Integrity / App Check確認 | 公開後の強制適用は監視して判断 |
| `OPS-05` | 完了 | Android正式IDとアップロード署名 | 鍵とパスワードの安全なバックアップを維持 |
| `ANL-01` | 完了 | Firebase Analytics整備 | 既存の計測・運営ダッシュボード／IAP確認を維持。一般イベントの公開後確認は残し、UID分析の公開ポリシーは10/25限定公開PASS、App Privacy確定／Play Data Safety差分保存も10/25完了。一般イベント確認は公開後の別工程 |
| `DES-01` | 進行中（初版3項目確定） | 品質改善版の要件・アーキテクチャ再設計 | 本人決定で既存RAG初版採用・AI-02反復／BETA-01専用権限は初版追加なし。原要求と照合証拠は品質計画に保持し、初版判断待ちへ戻さない |
| `NTF-01` | 開発環境反映済み・一旦保留 | 通知のイベント駆動化と頻度制御 | 実データ59件で旧36候補から新14通知へ削減を確認。健康関連6 FunctionsとFirestoreルールを反映済み。再開時に実通知・タップ・確認済み・休止・解消通知を最終確認 |
| `HLT-01` | 実装中・一部本番反映済み | 健康スコアリングv2 | 第3段階ローカル完了を維持。9/13の健康関連Functions／Rulesと10/11の個体別分析UI・Insightには個別の反映実績あり。これだけで後続改訂を含むHLT全体の本番適用を断定しない。残る適用範囲・実機・閾値レビューは未確認 |
| `RAG-02` | 初版採用確定・既存実装／評価済み | 記事・YouTube統合RAG v2 | 既存検索・32問承認／配備証拠を再利用。最新両版AI各1件、保存回答の動画タイトル／画像・外部動画からの復帰は両端末で本人PASS。旧追加契約の開発は初版へ追加しない |
| `AI-02` | 初版対象外・反復検索未実装 | エージェント検索 | 既存の固定検索・補助根拠照合を初版で使用する本人決定。反復検索は初版に追加しない。未実装の事実と旧要求を保存するが、初版公開ゲートから外す |
| `BETA-01` | 初版対象外（専用機能未実装） | テスター向け期限付き無料権限 | 本人決定で専用権限を初版追加しない。旧クローズド再開前の専用beta条件は初版条件から解除。通常21日・20件・有限共有枠でテストし、期限・履歴・利用枠をリセットしない |
| `UX-01` | 本番反映済み・E2E最終確認待ち | UI/UX改善 | 10/12のケア・たくわえ／カレンダー反映、10/17のA1→A2→A3・統合レポートfixture／実機部分PASSを維持。10/25更新版のHome・ログイン・記録保持PASS。初回状態別の実操作は未確認 |
| `ONB-01` | 実装中・E2E確認待ち | 実操作型オリエンテーション | 導入・初回記録・統合レポートの実装と10/17 fixture完走、実機の確認可能導線はPASS。10/24に通常体験開始・文字AI回答も本人確認。最新両成果物のAI各1件は本人完了報告を受領。新規状態からの全導線実機通過は別途未確認 |
| `TRL-01` | 本番反映・通常アカウント実機確認済み | 主要機能の無料体験 | 通常21日・最大20件・個人費用枠と承認済み有限共有枠を維持。正規開始・旧版回答、最新iOS Release／Android更新版の本人AI各1件も完了。記録未反映を修正したもので追加AIなし、新使用量の実値照合は別で再送条件にしない |
| `GAM-01` | 本番反映済み・E2E最終確認待ち | 星の累計と50個達成 | サーバー管理の獲得台帳・現在の保有数・生涯獲得数・50個解放、祝福画面、累計が存在する時だけ出るドロワー項目を実装。開始日は2026-09-17（日本時間）、既存記録は遡及付与しない。将来の失効は保有数だけを変え、生涯獲得数と解放済みコンテンツは保持できる構造。4 FunctionsとFirestoreルールを本番Firebaseへ反映。累計有効版をエミュレーターへ再導入済みで、ログイン後に今日の起動星・ドロワー導線のE2E確認が残る。特別コンテンツは未制作 |
| `REL-02` | 進行中・code5送信受付未確認／build5内部Testing・Apple回答待ち | 日本限定・Stripe決済のままストア初回提出 | 同意実装・最終成果物・既存配布／更新・通常権限と審査アクセス準備PASSを維持。本人承認の既存Alpha 1.0.1／code2・日本のみ・既存internal-testers本人1名と共通掲載／申告の14変更を2026-10-27 11:09 JSTに審査送信（送信ID1、10/27確認時点の未送信0件）。送信ID1は同日11:19 JST「公開」と本人確認済み（今回Console読取照合）、クローズドテスト参加者確保・必要な12人／14日期間は未完了、正式な製品版公開も未完了。旧Case22954972は担当範囲外との回答を受領。本人承認のApp Review新問い合わせを2026-10-27 11:46:34 JSTに送信し、受付公式完了画面と11:48:45 JST受信の受付メールで番号一致を確認／新Case103009817213、決済導線の可否回答待ち。今回のAndroid1.0.1/code3・iOS1.0.1/build3は11/1生成前に未登録確認、88画像統合後の署名済AAB／配布IPA生成・格納検証PASS。本人承認後11/1 18:19 JSTにAlpha code3の1変更を送信（送信ID2・18:47 JST Alpha公開確認済み）、TestFlight build3は本人1名でTesting。製品版変更なし。通常21日体験をテスターへ利用し、今回の新テスト配信はbuild3とcode3を確認済み、Alpha code3も18:47 JST公開済み 11/2現在のAlpha code3有効・日本のみ、許可登録1／実opt-in0・製品版申請無効を確認。募集目標20〜30名、X先行／不足時YouTubeの未投稿原稿と各6問の実フォームを準備。本人追加承認後11/2 13:32 JSTに公開・回答受付PASS、回答用URL差込済み・現0回答。本人がX投稿すれば受付可能。内部code2共用リストへ追加せず、将来Alpha専用リストを別途承認後に設定する案。実投稿／招待／tester追加なし。 11/8本人限定RC4：AAB/IPA生成・署名/88画像一致PASS、Alpha code4の1変更を21:31 JST送信ID3、22:39 JST公開を11/9公式詳細で再読確認。日本のみ・本人1名、build4は本人Internal Testingを維持。11/9本人許可でSamsungローカル版を削除後、Play code4を新規導入し正常ログイン・記録・動作は本人PASS。新規導入と更新保持は区別。旧code3/build3以前の互換は本人決定でリリース対象外、P1は非ブロッキングで閉じ、部分保存をcode4/build4以降の正規仕様とする。外部案内対象code4のみ・約15名未招待・製品版0。表示名/アバター拡大は既存ブランチのソース修正・限定確認まで完了、配信済み4は変更せず新build/upload/main操作なし。 11/9微修正RC5：1.0.1/code5・build5を4027370から生成・署名／88画像／Caveat整合PASS。既存Alpha code5と掲載名Ham Careはupload／保存済み、日本／本人1名を維持。本人の確定操作回答後も、読込完了後のConsoleは未送信2変更・履歴ID1〜3で受付未確認、原因未特定。残る操作はConsole受付再確認と承認済み2変更の送信のみ。build5は11/9 11:09 JST Delivery完了・ASC処理完了、本人承認後の輸出申告保存済み、既存本人実機確認1Tester/4Buildsで1.0.1(5) Testing・90日。両Console名Ham Care保存確認。製品版0・tester拡大／連絡0、Apple回答待ち。 |
| `REL-03` | 微修正の限定確認完了・両OS4→5更新確認待ち | 提出候補版のE2E確認とクラッシュ監視 | 既存AI各1件・認証保持・動画PASSと同意限定26件は再実施しない。両ストア内部配布済み。iOSの本人TestFlight更新・Home／ログイン／記録保持はPASS、同意Dialog表示・取消・入力保持と設定の撤回項目表示も本人PASS。実同意承諾／実AI再送は未実施。Androidの同一署名ローカルRelease上書き／起動はPASS、本人のHome・ログイン・記録保持と設定項目表示もPASS。独立VMのPlay code1→code2更新・導入元／署名／UID保持と本人Home・ログイン／記録保持もPASS。普段使い52ab端末の移行は未実施。DeviceCheckは更新時刻の交換成功＋対象AppID VALID等を照合したサーバー計測でPASS（個体callback直接未観測）。既存アプリ・通常権限・履歴保持。上記の必要確認は完了として維持し、未確認の残範囲だけを別管理する。既存PASSは再試験しない。新2色ローカル12件PASS、build3はTestFlight Testing、code3はAlpha公開済み。iOS2→3再ログイン不要／データ保持・Pied保存再表示・white_face代替表示は本人PASS。Android専用AVDは正式Play2→3配送、DA77／導入元、UID・初回導入日時・dataDir継続、固定AABとnative3件／88PNG一致PASS。現code3で通常ログイン・既存データ閲覧・Pied再表示が本人PASS。更新前ログイン基準の時系列不明のためcross-update再ログイン不要は未確認。全8状態の新端末切替とAndroid white_faceは未確認、追加強制試験はしない。普段使い実Androidと専用AVDを区別し、既存成功E2Eは再実行しない 11/8本人限定RC4：旧両版完全入力と新writer互換PASS。iPhone正式3→4更新/既存データ保持・task1/2/3表示・nickname保存/再起動保持は本人PASS。追加nickname変更/解除は本人不要指定で未実施。Alpha code4は11/8 22:39 JST公開済み。11/9本人許可によるSamsungローカル版削除後、Play code4新規導入・正常ログイン/記録/動作は本人PASS。AVD正式3→4更新保持と部分8ケースは未確認のまま区別。本人決定で旧版互換は対象外、P1は非ブロッキングで閉じ、追加互換実装/一斉切替確認は不要。表示名/アバター拡大は関連66件・実Widget描画4件PASS、新規解析指摘0。配信済み4は変更していない。 11/9微修正RC5：関連114PASS／既存ListTile診断2FAIL・新規失敗0、ぼかし17PASS、analyze57／新規0、掲載名identity6PASS。新AAB／IPA生成検証済み、Playは本人操作後も未送信2変更・受付未確認／原因未特定。build5はDelivery／ASC処理・本人承認の輸出申告保存完了、内部Testing確認。正式4→5更新・再ログイン不要／データ保持の実機確認は未実施。AI／認証等の完了済み確認は再実施しない。 |
| `VAL-01` | 未着手 | 有料ベータで継続利用を検証 | ストア配布経路の準備後 |
| `AVT-06` | 88枚統合済み・新16限定12件PASS | 残りのアバター素材 | 元72枚不変、black／白黒pied stable2は本人目視承認、残14は未制作を照合し本人の制作統合承認後に生成・自動検査PASS。最終16PNGを配置し2leaf登録、通常Repo保存再読込・8状態・white_face fallbackを限定確認。新14の個別本人目視／全8状態の実機切替は未実施と区別。white_face8とanalysisは別保留。code3/build3候補生成／署名／88PNG格納検証PASS、指定AAB／IPA upload済み。code3はAlpha公開済み、build3は本人TestFlight Testing。iOSとAndroid専用AVDで白黒パイド保存再表示が本人PASS。iOS white_face代替表示も本人PASS。両OS全8状態の新端末切替とAndroid white_faceは未確認、既存ローカル12PASSを維持し追加強制試験なし。 |
| `OPS-03` | 未着手・非阻害 | 依存パッケージ監査 | リリースを止めない読み取り確認から開始 |
| `OPS-04` | 未着手・非阻害 | Cloud Functionsビルドイメージ整理 | 2026-09-17のFunctions反映後、不要なビルドイメージの自動削除で警告あり。課金状況を確認後に安全に削除 |

## 確定した方針

### 初回ストア提出

- 初回公開地域は日本のみとする。
- 初回iOS公開はiPhone専用とし、iPad対応はレスポンシブUI整備後に再検討する。
- 現行のStripe Checkout / Stripe Customer Portalの維持を第一希望とし、適用条件・購入導線・審査説明を確定してから提出する。現行導線の適合を判断済みとはしない。
- App Store／Google Playの同時公開を目標とする。旧Case22954972のscope外回答を受け、本人承認のApp Review新問い合わせを2026-10-27 11:46:34 JSTに送信。新Case103009817213の回答待ちで、アプリのApp Store審査提出・公開は未実施。
- AppleのApp内課金とGoogle Play Billingは、却下前には追加実装しない。
- 決済方法を理由に却下された場合は、規約番号、審査文面、対象画面、日時を保存し、指摘内容に限定して対応を判断する。
- 履歴：2026-09-12には品質改善で審査送信を保留した。現在は10/27 11:09に送信ID1を送信済み、同11:19にAlpha公開を本人確認済み。製品版一般公開へは進めていない。
- 2026-10-31本人決定：クローズドテスターは既存21日無料体験を利用する。カード不要・自動課金なし、通常の有料ゲート・AI20件と個人／共有の有限費用枠を維持する。開始済み体験や更新前データをリセットしない。
- 2026-10-25本人決定：既存RAGを初版に使用し、AI-02反復検索・BETA-01専用権限は初版に追加しない。旧「専用beta実装後にクローズド再開」の条件は初版条件から解除する。通常体験・契約の権限、期限・使用履歴・有限予算を維持し、審査／テストに必要な期間・残枠は正規権限の範囲で確認する。

### 品質改善版

- 通知は定時配信ではなく、意味のある状態変化を中心にする。
- 健康スコアは断定的な診断値として扱わず、観測データに基づく参考指標、領域別評価、データ信頼度、主因を併記する。
- AI回答には関連する過去のYouTube動画を表示する。ただし、動画を回答根拠として使った場合と、補助的な関連動画として提示する場合をUI上で区別する。
- エージェント検索はRAG v2の検索品質、評価セット、費用上限、最大反復回数を確定した後に導入する。既存Hierarchical v1の初回実用承認は維持するが、反復検索の完成とはしない。初版は既存Hierarchical v1を採用する本人決定済み。旧追加契約・反復検索は初版に追加しない。

### 情報管理

- 進捗・優先順位・判断はこのファイルを正本とする。
- 実装や検証で状態が変わったときだけ、日付と根拠を添えて更新する。
- パスワード、APIキー、署名鍵などの秘密情報は記載しない。
- 完了していない作業を完了扱いにしない。
- 最優先タスクは原則1件に絞る。
- Excel管理表は過去情報の参照用とし、二重更新しない。

## 関連資料

- [ストア掲載情報](docs/release/store_listing_ja.md)
- [審査メモ](docs/release/store_review_notes_ja.md)
- [プライバシー申告チェックリスト](docs/release/privacy_disclosure_checklist_ja.md)
- [Google Play登録手順](docs/release/google_play_submission_runbook_ja.md)
- [Google Playクローズドテスト計画](docs/release/google_play_closed_test_plan_ja.md)
- [日本限定決済・Apple問い合わせとiOS準備](docs/release/japan_store_payment_and_ios_readiness_20261018.md)
- [iOS第2工程・現在の到達点と履歴](docs/release/ios_runtime_preparation_stage2_20261018.md)
- [iOS署名・実機認証と履歴](docs/release/ios_signing_physical_auth_20261018.md)
- [アーキテクチャ](docs/architecture.md)
- [Firestore設計](docs/firestore.md)
- [SwitchBot連携](docs/switchbot.md)
- [RAG構成](docs/rag.md)
- [品質改善・RAG v2再設計計画](docs/product_quality_rework_plan.md)
- [通知v2設計](docs/notification_v2_design.md)
- [健康スコアリングv2設計](docs/health_scoring_v2_design.md)

## 公開ページ

- プライバシーポリシー: https://hamster-breeding-app.web.app/privacy/
- 利用規約: https://hamster-breeding-app.web.app/terms/
- 特定商取引法に基づく表記: https://hamster-breeding-app.web.app/commercial-transactions/
- サポート: https://hamster-breeding-app.web.app/support/
- アカウント削除案内: https://hamster-breeding-app.web.app/account-deletion/

## 更新記録

| 日付 | 内容 | 根拠 |
|---|---|---|
| 2026-10-04 | AI相談500エラーを修正し、限定検証用Cloud Run revisionへ反映 | 原因はFirestore transactionの`transaction.get()`が返すgeneratorをDocumentSnapshotとして扱い、`.to_dict()`を呼んでいたこと。RAGのtransaction読み取りをgenerator対応にし、空応答はfail-closedとした。Python 3.11のCloud Buildで全96テスト成功。`hamster-rag-api-00017-ceg`へ反映し100%配信、`GET /` 200・未認証および無効tokenの`POST /chat` 401を確認。実AI相談は未実施。UID Aは有料契約activeで無料体験記録なしのため、表示後消えた体験CTAは開始成功ではない。`daily_checkins/2026-10-04`の保存完了をFirestoreでread-only確認（12:41:19 JST）。修正済みFlutter sourceのDebug APKはGradleのFlutter plugin loaderで`flutterSdkPath` null例外となり未生成。エミュレーター未接続、クラッシュ有無・修正版APKの実機確認は未完了。詳細と復元情報は`docs/release/predeployment_snapshot_2026-10-04-rag-fix.md`。GitHub push、ストア配布、ユーザーデータ変更なし。 |
| 2026-10-04 | 分岐していた既存UI・機能差分を現行オンボーディングへ統合 | 旧ローカル作業コピーの追跡差分37ファイルと未追跡追加14件を機能別に照合。認証画面、飼育環境2.5Dプレビュー、日本地図、飼い主・ペットプロフィール、AI相談の音声入力・Markdown・根拠表示・評価・履歴、ランタン調フィードバック、記録報酬・コレクション、健康トレンド表示等を統合。21日無料体験・AI requestId冪等性・オンボーディング導線は現行側の実装を維持。`flutter analyze`問題なし、Flutter全42テスト成功、Android debug APK生成成功。APKの端末導入・画面目視、Google/Apple認証プロバイダーのFirebase Console設定は未確認。本番反映・push・端末データ変更なし。 |
| 2026-09-20 | 導入画面の背景と主ボタンの可読性を仕上げ | 導入スライドのアプリ側減光グラデーションを外し、生成画像の文字用スペースと星空表現をそのまま活かす構成に変更。導入画面の背景は真っ黒寄りの夜色へ変更。主操作ボタンは落ち着いた青 `#315DAF` と白文字・白アイコンに統一し、淡い黄色は星・達成など報酬表現用に分離した。`flutter analyze`問題なし、全Flutterテスト34件成功、103MBのarm64 release APK生成・エミュレーターへの上書き導入・前面起動を確認済み。 |
| 2026-09-20 | 導入画像の縦長カード最適化・登録前カード余白・スポットライト色を修正 | 横長画像による重要要素の見切れを解消するため、下部42%を文字用の暗い余白として確保した縦長グラフィック4枚へ作り替えた。登録前カードはコンテナ余白を画像へ継承しない構造へ修正し、端まで画像を表示。スポットライトは対象ごとの鮮やかな青い影を廃止し、`#080D19`・不透明度0.76のミッドナイトネイビー暗幕と自然な抜き出しへ変更。小さい画面高の導入カードもレスポンシブに調整。`flutter analyze`問題なし、対象・全Flutterテスト34件成功、108.4MBのarm64 release APK生成成功。別署名のエミュレーター旧版を削除して最新版を新規導入・起動（初回通知権限画面まで）確認済み。 |
| 2026-09-19 | オリエンテーション画像を全面背景へ改訂 | 導入3スライドと登録前カードで、生成グラフィックを部分画像ではなくカード全体の背景へ拡張。タイトル・本文が始まる少し手前からカード面へ溶ける濃いグラデーションを重ね、文字の可読性を確保した。重ねていた汎用アイコンはすべて削除。`flutter analyze`問題なし、Flutterテスト34件成功、arm64 release APKをエミュレーターへ更新し起動確認済み。 |
| 2026-09-19 | オリエンテーションと登録前カードの専用グラフィックを実装 | 生成画像4枚を追加。「小さな変化の検知」は温度・湿度・回し車・体重の傾向をつないだデータ表現、「個別見守り」はペットと飼育環境の基準化、「AI相談」は質問から確認事項を整理する表現、飼い主プロフィールは地域・天気・経験を示す表現にした。導入スライドは大きな横長ビジュアルへ、3つの登録前カードも意味に対応した画像ヘッダーへ更新。`flutter analyze`問題なし、Flutterテスト34件成功、arm64 release APK生成・エミュレーター導入・起動確認済み。 |
| 2026-09-19 | AI相談の回答本文が消える表示不具合を修正 | オリエンテーション用の入力欄識別子が回答吹き出しにも重複して付与され、画面内で同一のGlobalKeyが競合していた。識別子を実際の入力欄だけへ移し、回答本文を通常どおり描画できるよう修正。`flutter analyze`問題なし、Flutterテスト34件成功、arm64 release APK生成成功。既存エミュレーター版は署名が異なるため上書き不可であり、新規導入には旧版削除（端末内データ消去）の明示許可が必要。 |
| 2026-09-19 | 初回体験に価値スライドと負担軽減導線を追加 | 3枚の価値スライドを先行表示し、その後に「はじめる準備」へ遷移するよう変更。ペット・飼育環境の未登録時は、入力前に登録後の価値を示すプレビューを表示。`tutorial_coach_mark` で最初の登録カードを一度だけ案内する。`flutter analyze`問題なし、Flutterテスト34件成功、arm64 release APK生成成功。実機目視確認は未完了 |
| 2026-09-19 | オリエンテーションの段階案内と無料体験を実装 | 準備項目をペット・飼育環境・飼い主プロフィールへ再編。現在未完了の次項目をCoach Markで順に案内し、準備完了時はHomeからAI相談・質問欄へ誘導する。`activateFeatureTrial` と `consumeAiTrial` を `asia-northeast1` に反映し、Firestoreルールで体験状態をFunctions専用に制限。Flutter解析・全34テスト成功、arm64 release APKをエミュレーターへ導入。初期スポットライトと飼い主プロフィール表示を目視確認。全ステップ通過・AI送信・5日経過のE2Eは未完了。 |
| 2026-09-19 | 準備カウンターとAI案内位置を修正 | 登録済みドキュメントだけでなく各フォームの保存成功を完了イベントとして保存し、補助項目の欠損で 0/3 に戻らないよう変更。Homeの案内対象を見出しから下部の「相談」タブへ変更し、AI画面の質問文の事前入力を廃止して入力欄に質問例だけを案内する。Flutter解析・全34テスト成功、release APK生成済み。更新直前にエミュレーターが切断されたため、再接続後の導入とE2E確認が必要。 |
| 2026-09-18 | 実操作型オリエンテーションをローカル実装 | 新規ユーザーの導線を、ペットプロフィール、飼育環境、AI相談の3ステップへ統合。AIは実際に回答が成功した時だけ完了として保存し、初期設定に不要なSwitchBot連携・日次記録・表示設定は除外。`flutter analyze`問題なし、Flutterテスト31件成功。実機目視確認は未完了 |
| 2026-09-17 | 今日開始の星プログラムを本番Firebaseへ反映 | Firestoreルール公開と、`claimDailyOpenStar`、`acknowledgeFiftyStarMilestone`、`starDistanceRecordWritten`、`starDailyCheckinWritten`の4 Functions作成成功。Functions一覧で全4件がnodejs22／asia-northeast1で稼働中であることを確認。累計有効版のarm64 release APKをエミュレーターへ再導入済み。再インストールにより端末内ログインは消えたため、ログイン後のE2E確認が残る |
| 2026-09-17 | 星プログラムの開始日と将来の失効に備えたデータ構造を確定 | 開始日は2026-09-17（日本時間）で、過去の記録は遡及加算しない。`balance`（現在保有）と`lifetimeEarned`（生涯獲得）を分離し、50個解放は生涯獲得数で判定する。3日連続ゼロ時の将来の失効は現在保有だけを対象にできる。Functionsビルド、星の単体試験、Flutter静的解析・関連テスト成功。本番反映は明示承認待ち |
| 2026-09-16 | Homeの星3枠を横幅のある主役表示へ改訂 | 3つの星を大きくしたガラス調パネルとして配置。`flutter analyze`問題なし、日次星と50個到達画面のFlutterテスト6件成功。エミュレーターは容量不足のためdebug版を導入できず、93.4MBのarm64 release版を導入して初回ログイン画面まで確認。再インストールで端末内ログインが消えたため、Homeの改訂表示の最終目視はログイン後に行う |
| 2026-09-16 | 記録報酬UIのHome表示をエミュレーターで再確認 | debug版のHam Careを起動中のエミュレーターで確認。「総合コンディション」直下に「今日の記録」と星3枠が表示されることを確認。累計APIはビルド設定で既定OFFのため、星累計・50個達成のE2Eは未確認 |
| 2026-09-15 | 健康スコアリングv2第3段階と簡易健康チェックUIをローカル実装 | 今日の様子を3段階・8観察項目へ構造化し、呼吸変化と明確な懸念を直接警戒へ反映。入力UIは3択から必要時だけ詳細を開く構成とし、補足文を削減、正式ハムスターマークとガラス調表示へ統一。Flutter静的解析問題なし・テスト21件成功、Functionsビルド成功・単体テスト30件成功。未デプロイ、改訂UIの目視確認は未完了 |
| 2026-09-14 | 健康スコアリングv2第2段階と実データdry-runを完了 | 読み取り専用CLIで60日分を再計算。対象日を除く直前90日・最新14件、最低7件かつ14日、中央値/MAD、EWMA係数0.3の個体ベースラインを活動量と体重へ導入。活動量評価可能日は2日から9日、完全な参考点表示日は1日から7日へ増加。Functionsビルド成功・単体テスト28件成功、Flutter静的解析問題なし・テスト17件成功。未デプロイ |
| 2026-09-14 | 健康スコアリングv2第1段階をローカル実装 | NEWS2、PROMIS、Oura、EWMA、FDA透明性原則とハムスター健康情報を調査。欠測領域の100点再正規化を廃止し、`scoreCoverage`、算出可能範囲、主因最大3件、警戒優先を導入。活動量の対象日を比較平均から除外し、最低3件の過去記録を要求。Functionsビルド成功・単体テスト23件成功、Flutter静的解析問題なし・テスト15件成功。未デプロイ、実データdry-run未実施 |
| 2026-09-14 | 通知v2のGoogle Play内部テスト候補AABを生成 | `1.0.1`（versionCode `2`）へ更新し、`flutter analyze`問題なし、Flutterテスト13件成功、release AABビルド成功。AABは119,825,645 bytes、SHA-256 `4ea6a144a0a5f5857d6d0d3d87880bc62a41f114df9f6ef6e4d24cf6d91ffbbe`、署名・ZIP整合性を確認。Google Playへのアップロードは未実施 |
| 2026-09-13 | 通知v2をFirebaseへ反映 | `test_20260308@example.com` の評価履歴59件を読み取り専用で再生し、旧方式36候補から新方式14通知へ約61%削減を確認。Functionsビルド成功、Functions単体テスト20件、ルールテスト39件成功後、健康関連6 FunctionsとFirestoreルールのデプロイ成功。ストア公開・審査送信は未実施 |
| 2026-09-13 | 通知v2の頻度制御仕上げをローカルで完了 | 注意・変化通知の週2件上限、配信失敗時の枠返却、24時間期限付き解消通知、5カテゴリ設定、履歴dry-runエンジンとCLIを実装。代表履歴では同一注意4候補を1通知へ抑制。Functionsビルド成功、Functions単体テスト20件、Flutterテスト13件、ルールテスト39件成功、`flutter analyze`問題なし。実データdry-runはローカルのGoogle資格情報未設定のため未完了。未デプロイ |
| 2026-09-12 | 通知v2の第2段階をローカルで完了 | インシデントのactive/resolved/recurrence管理、詳細画面の確認済み・24時間休止、警戒通知・注意頻度・21時〜8時の夜間停止設定を実装。注意通知の初期値は「状態変化時のみ」。Functionsビルド成功、Functions単体テスト15件、Flutterテスト11件、ルールテスト37件成功、`flutter analyze`問題なし。未デプロイ |
| 2026-09-12 | 通知v2の実機検証完了を前提として次段階へ移行 | ユーザー判断による進行前提。本更新では追加の実測ログや配信証跡は記録していないため、開発環境反映後の最終確認は残す |
| 2026-09-12 | 通知v2の初期実装をローカルで完了 | 日付を含まないインシデントID、同義フラグ正規化、注意72時間・警戒12時間の再通知抑制、悪化時の即時通知、簡潔な事象別文面、Android通知置換、通知タップから状態詳細への遷移を実装。Functions TypeScriptビルド成功、Nodeテスト10件成功、Flutterテスト10件成功、`flutter analyze`問題なし。未デプロイ・Android実機未確認 |
| 2026-09-12 | 通知v2の現状分析と具体設計を開始 | 同じ湿度注意が連日、同日にも複数表示された実機通知履歴を確認。時間単位の再評価、日付を含む重複防止キー、汎用文面、通知タップ経路の不一致をコードで確認 |
| 2026-09-12 | Google Play公開準備をPendingへ変更し、品質改善版の設計を最優先化 | クローズドテスト用リリースと13件の申告変更を審査送信する直前で停止。通知、健康スコア、RAG、YouTube連携、エージェント検索、テスター権限の再設計方針を決定 |
| 2026-09-12 | アカウントを維持した一部データ削除の案内を公開 | AI相談履歴とプロフィール画像の個別削除手順を実装と照合し、Hosting反映後の公開URLで表示を確認 |
| 2026-09-07 | Google PlayへプライバシーポリシーURLを登録 | Play Consoleの保存完了表示と「公開の概要」の未送信変更を確認 |
| 2026-09-07 | Google Play内部テスト配布版を実機へインストールし、正常起動・基本画面表示を確認 | Playストアからのダウンロード、ホーム画面の配布版アイコン、アプリの「今日」画面を確認 |
| 2026-09-07 | Google Play内部テスト版 `1.0.0`（versionCode `1`）を公開 | Play Consoleで「内部テスターに公開」と公開日時を確認 |
| 2026-09-07 | Google Play ConsoleでHamster Careアプリを作成 | アプリ固有ダッシュボードとクローズドテスト要件の表示を確認 |
| 2026-09-07 | Firebase Analyticsの収集内容を追記したプライバシーポリシーを公開 | Hosting反映後の公開URLで更新日と記載内容を確認 |
| 2026-09-07 | Google Play提出用の入力手順とクローズドテスト計画を作成 | 新規個人アカウントの12名・14日要件に対応 |
| 2026-09-07 | データセーフティ申告とプライバシー表示を実装に合わせて更新 | Firebase Analytics、AI相談、FCM、App Check、外部委託先を再確認 |
| 2026-09-07 | 変更後の解析・テストを再実行 | `flutter analyze`成功、自動テスト7件成功 |
| 2026-09-07 | Google Playの連絡先電話番号確認を完了 | Play Consoleの「電話番号を確認しました」表示 |
| 2026-09-06 | Google Play本人確認を完了 | Google Play Consoleからの本人確認完了メール |
| 2026-09-06 | Google Play本人確認書類を提出し、Android実機アクセス確認を完了 | Googleお支払いプロフィールの確認完了画面、実機のPlay Consoleアプリで確認 |
| 2026-09-06 | 提出候補の解析・テスト・ストア素材を再検証 | `flutter analyze`成功、テスト7件成功、画像寸法・形式・AABハッシュ一致 |
| 2026-09-06 | iOS配布環境の未完了条件を確認 | macOS 14.8.9、Xcode 16.2、有効なコード署名IDなし、IPA未生成 |
| 2026-09-06 | Google Play個人デベロッパーアカウントを作成 | Play Consoleの作成完了画面と登録料領収書送信を確認 |
| 2026-09-06 | Androidと6.9インチiPhoneの掲載画像を各4枚作成 | ストア公式サイズ・非透過JPEGを確認 |
| 2026-09-06 | 初回iOS公開をiPhone専用に決定 | 現行iPad表示はスマートフォン幅の中央配置となるため |
| 2026-09-06 | 進捗管理の正本をExcelからMarkdownへ移行 | Gitで差分・履歴を管理する方針に変更 |
| 2026-09-06 | 最終ブランドをアプリとストア素材へ反映 | `f972be0` |
| 2026-09-06 | 最終アイコン入りAndroid AABを生成・検証 | SHA-256およびBundletool検証結果 |


## 2026-10-10 個性レポート v3 UI（ローカル実装・検証PASS、本番未反映）

- 不変Goldの詳細表示のみ変更。既存AppTheme/StatusCard/MetricComparisonBar/ExpansionTileを再利用し、装飾ヘッダーと分析カードアイコンを撤去。大きな数値、短い発見、体重の研究IQR比較、活動量の共通ゼロ起点2本バー、展開する統計・出典を実装。
- 型付きGold Model/Repositoryを維持し、表示用ViewModelへ丸め・単位・差分・日時を分離。日別中央値を全日平均とせず、MAD由来の範囲や健康/順位判断を作らない。研究比較不可では比較を省略。旧v1/日次とも生成時snapshotを表示。
- Widget21、Golden9（日本語font/viewport/theme/fixture/SHA固定、全画像目視）、関連152 PASS。Flutter analyzeはNo issues（exit0）。全Flutter273件完走：272PASS・旧装飾ヘッダー期待1件失敗。指標カード構成へ期待を修正後、該当を含む関連152を再実行して全PASS。未修正のテスト失敗なし。全体コマンドの再実行はしていない。
- 240px/文字3倍のGoldenで数字の縦分断を検出し、数値だけ必要時に幅へ収める修正と1行/カード内収容の回帰テストを追加。説明文・単位は通常の文字拡大と折返しを維持。SafeAreaで下端を保護。
- Screenのowner/read/post-frame閲覧通知と既存ThemeDataはbyte同一。保護対象176ファイル（Model/Repo/Home/onboarding/課金/Functions/Rules/依存等）のSHA不変を確認。最終全298再hashはbilling_status.dart読み取り待ちのため今回専用readerのみ停止。対象外へのwrite操作なし、削除なし、既存dirty変更・Known Good/Gitは操作なし。
- 本番deploy・Firestore/Cloud/AI・実機/APK更新は実施なし。仕様はdocs/personality_report_v3_design.md。承認モックアップ画像は利用可能資料で見つからず、依頼文の仕様を再現、pixel一致は未確認。GoldenのHiragino W3/MaterialIconsはSHA固定でfont本体は非同梱、他環境は同一byteのfont指定が必要。
- 実機反映は別承認タスクでv3候補を隔離→APK build→現端末署名比較→install-r→表示/未読/履歴/再起動確認。サーバー変更不要。証跡：/private/tmp/hamcare-personality-v3-20261010/。
