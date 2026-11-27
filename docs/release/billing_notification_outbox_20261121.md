# 契約通知outboxとGmail Worker（2026-11-27・本番停止配備済み）

開始点は承認済み`81ac23933fda`。11/21の設計/Preview配送と11/27の停止本番配備を区別する。最新の実行範囲・状態は本節と[既存Runbook](web_billing_live_cutover_runbook_ja.md)を正本とし、旧「本番未配備/変更しない」は当時の記録。**一般送信/実Live通知は未開始**、Preview5通/本番連絡先確認の受信をLive通知配送の根拠へ転用しない。

## 2026-11-27 停止配備と本人向けLive通知1件の準備

本人が、必要なFunctions/Secret/IAM/Schedulerの**停止状態での本番反映**を承認した。一般送信と実メール送信は未承認のまま。旧節の「今回の承認外」は当時の範囲であり、今回の停止配備承認で更新する。12月3日の本人限定Live決済に合わせた配送確認は、この後の別承認で行う。Preview5通の配送を繰り返さず、Liveの確認済み配送実績へ読み替えない。

- **新しい通知scope**：`HAMCARE_BILLING_NOTIFICATIONS_SCOPE=closed|limited|general`を明示。未設定/closedとoverall enabled=falseはSecret値/Auth/outbox/予算/Gmailの前で停止。generalは既存の固定`HAMCARE_BILLING_NOTIFICATIONS_NOT_BEFORE_MILLIS`を必須とし、limited用の5値が残る場合は拒否する。
- **本人1通知だけ**：limitedは`HAMCARE_BILLING_NOTIFICATIONS_LIMITED_NOT_BEFORE_MILLIS`/`...LIMITED_EXPIRES_AT_MILLIS`（UTC秒境界・最大6時間）、`...LIMITED_UID_SHA256`/`...LIMITED_RECIPIENT_SHA256`各1件、`...LIMITED_NOTIFICATION_ID`（正規outboxの既存64hex ID1件）を必須化。通知種別は`contract_registered`固定、日次枠1、batch1。一般cutoffを読まず・消費せず、期限切れ/欠損/不正からgeneralへfallbackしない。
- **queueと送信境界**：limitedは対象1文書だけをGETし、他UID/他ID/別通知種別/Preview/古い・不明event/期限外をclaimせず変更しない。transaction内とsend intent後、OAuth後の不可逆Gmail HTTP直前も同じUID/確認済み現在宛先/選択doc/期限を再照合する。既存予算・lease・送信済み/uncertainによる再送抑止をそのまま使う。一般queueのscan/移行/削除/新Indexは不要。
- **本人が支払う日の手順**：本人の決済開始前に専用開始時刻Bを記録する。実決済→署名Webhook→同UID active同期後、正規producerが作った契約開始通知1件をread-only照合し、本人UID/確認済み宛先/IDを非公開固定する。実送信の明示承認後にだけ、通常はScheduler PAUSEDを維持した認証付き直接呼出しで、limited・有限window・日次1の手動実行1回を行い、受信/ブランド/本文550円/スマホ表示を本人確認する。Gmail受付だけで配送完了としない。終了/失敗/不明時はenabledfalse/scopeclosedへ戻し、未知結果を安易に再送しない。現在は日時/hash/ID未設定で、実送信0。
- **一般開始とは分ける**：本人の契約開始通知1件のsent記録は維持する。本人決済/期間末解約等の他の通知を一般開始時に一括後送せず、一般用Tを本人の最終eventより厳密に後へ固定する既存手順を維持する。一般開始はexplicit general＋limited5値除去＋固定T＋別承認が必要で、limitedの期限が来ても開始しない。
- **停止配備の固定値**：worker enabled=false/scope=closed、一般T/limited5値未設定、日次50、Secret固定v4を使用する。contactは既存送信false/statusfalse/v3/日次1を維持し、一般連絡先開始時にv4/共通50へ合わせる。v4は既存Live送信専用資格情報を再利用した正規schemaで、旧本人限定contact markerだけを除去。旧Secret/Preview/認可/履歴を消さない。Secretのenabled=trueは独立flagの送信許可ではない。

変更したDispatcher15件＋新limited40件＝55件PASS。加えて変更箇所に直結する既存Runtime3ケースだけを選びPASS（他46件は未実行）。これはMock/ローカルの結果で、Live配送のPASSではない。隔離strict型検査/配備compileもPASS。以下の実停止callbackとは根拠を分ける。

### 停止本番反映の実績（11月27日）

- **正規Live mail v4**を15:44:58 JSTに既存Live v3の資格情報をメモリ内再利用して登録。Secret値/認可は変更せず、Previewと旧版を保持、既存Secret単体Accessorのまま。contactはv3/日次1/sendfalse/statusfalseを維持。
- producer `stripeWebhook`を`3cd9469`から**`stripewebhook-00014-zop`**へ限定更新（15:47:04〜15:48:02 JST）。既存正常同期/署名・API版/3Secret参照/主要同期7source/IAM/resources不変、ACTIVE/Ready・170hash一致。不正署名400だけ確認し、実event再処理は行わない。
- worker `processBillingNotificationOutbox`を**`6d88f870ecf4430b972e31a7582cc628e12e8bf9`**から**`processbillingnotificationoutbox-00001-gab`**へprivate配備（15:54:47〜15:56:21 JST）。170file実archive一致、ACTIVE/Ready、日次50/UTC日、false/closed/一般cutoff・limited5値なし、Secret固定v4。同compute SAへworker単体Invokerだけ追加し、project/Secret IAM差分0。
- Schedulerは`firebase-schedule-processBillingNotificationOutbox-asia-northeast1`、15分/Asia/Tokyo/retry0/OIDC、最終**PAUSED**。無認証403と別に、認証済みcallback **1回HTTP200/state=disabled（16:02:12.955 JST）**を確認。PAUSED RunJobは400で未実行だったため、アプリfalse/closedのまま未来cron→短時間resume/強制1回→finally pause/15分復帰で検証した。通常cronの自動実行はなし。後のPATCHでlastAttemptが消えたためCloud Loggingを実行根拠とする。
- callback前後でoutbox **0件**、既存送信枠 **6件**の選択field digest不変。claim/予算消費/Gmail呼出し/実メール0。16:09 JST最終照合で購入/contact/Hosting不変・全送信停止を再確認。配備後非request warningは意図的不正署名probe1件、予期しないwarning/error0。Secret/Function/IAM/Schedulerは実変更済みなので本番構成変更0とは記録しない。

上限/監視/復旧はRunbook最新⑤節へ集約。Goが一般開始時の初回2batch・初日毎時・以後毎営業日にqueue状態/最古pending/count/cooldown/起動・OAuth・Scheduler失敗とGmail不達を手動確認する。自動alert/自動pause/バウンス読取りは未実装。停止はScheduler PAUSED＋workerfalse/closed、履歴/uncertain/counterを維持。本人1通知のScheduler操作が必要なら、PAUSED RunJobの拒否を前提に未来cron/強制1回/再pauseを当日の範囲へ含める。実送信と12月3日以降の本人決済・配送は別承認待ちで、現在の日時/hash/IDは未設定のまま。

## 前工程の記録：2026-11-27 本番稼働前の追加安全制御（当時は配備未実行）

既存のPreview本人5通の実配送確認は再実行しない。対象worker/対応Schedulerの未作成と本番outbox0件は、前回の追加安全制御実装時点に限定read-onlyで確認した結果である。今回の本人550円確認に向けた手順追記では本番の再読取りを行っておらず、新しい現在値の確認とはしない。本番準備/一般稼働の具体的な承認対象は[既存Runbook](web_billing_live_cutover_runbook_ja.md)の最新④⑤節を正本とする。旧日付の未実装/Secret未登録の記述は当時の履歴であり、現在のLive contact実配送・mail v3の存在と区別する。

- 独立`HAMCARE_BILLING_NOTIFICATIONS_ENABLED`の未設定/falseはアプリcallbackのSecret値/Auth/DB/Gmail参照前で停止。trueには固定`HAMCARE_BILLING_NOTIFICATIONS_NOT_BEFORE_MILLIS`（UTC秒境界epoch millis・末尾000・未来不可）が必要。再配備やretryごとに現在時刻へ動かさない。platformのSecret mount/権限は別途必要。
- Live workerへ本人限定contact用`limitedContactTest`入りの設定を渡さない。正規Live Secretの新versionを用意する計画で、既存資格情報・Preview認可・旧v3・送信枠/履歴は保持する。contactと通知は共通の有限枠（初期50/UTC日案）を使う。
- 新しいproducerは正規billingの`sourceEventCreatedSeconds`から`eventCreatedAtMillis`を保存する。workerの切替には`stripeWebhook`のproducer限定更新が直接依存。旧producer/旧jobの欠落を手書きで埋めず、enqueue時刻/正規event時刻のどちらかがcutoff前又は不明なら`held_before_dispatch_start`へ保留する。attempts/以前のエラー理由/再試行時刻/snapshotを保ち、holdReason/heldAtを記録、dispatch/leaseの派生状態だけを除く。sent偽装・削除・自動再投入は行わない。
- expired sendingは従来どおりuncertainを優先。通常retry/重複抑止/Preview・現在Auth/連絡先解決を維持。新worker独自の削除要求フェンスを追加したものではなく、既存のproducer transactionフェンスと、削除済みAuthの宛先拒否を区別する。
- 停止時はScheduler PAUSED＋通知flagfalse。これは次回実行を止める制御で、実行中/予約済み/受付済み送信の取消保証ではない。停止後のclaimed/sending/uncertainを照合し、結果不明の再送やcounter resetを行わない。gmail.sendのみのためバウンス受信箱の自動監視/自動宛先抑止は未実装。運営の不達通知確認・停止・個別連絡先確認を必要とする。

追加安全制御実装時の限定Mockは149/149 PASS、依存/SDK更新・本番配備/設定/実メール変更0。今回の手順追記では、既存試験の再実行、本番再読取り、Secret参照、配備・設定変更・実送信はすべて0。最終の統合型検査結果はPROJECT_STATUSとRunbookの既存記録を再利用する。

### 本人の実550円確認Bから一般通知開始Cまで（未実行）

- **本人確認B**：別承認後の本人購入・アプリ権限確認中も、通知workerとメールのrequest/confirmは停止を維持する。連絡先のstatusだけを独立flagで読めるようにする場合も、送信許可にはしない。正規Webhookで生成される支払成功・解約予約等のoutboxは保持し、本人購入の成功を本番通知の実配送PASSに読み替えない。
- **cutoffの確定**：Bの対象実操作が完了した後、その最新の正規Stripe event時刻を照合し、それより**厳密に後**のUTC秒境界を固定Tとして予約する。同じ秒への切捨てやB開始時刻を使って、Bの通知を送信対象へ含めない。Tの値は`HAMCARE_BILLING_NOTIFICATIONS_NOT_BEFORE_MILLIS`へ設定するepoch millis（末尾000）。worker=falseのまま準備し、別承認されたCでT到達後に限りtrueとScheduler resumeへ進む。その後の再配備・通常再試行でTを動かさない。
- **Bの通知を後送しない**：Cの初回稼働前に対象outboxの件数・状態を読み、稼働後の初回scanではB以前のjob/eventが`held_before_dispatch_start`へ保留されたことを件数で確認する。既存の二つの時刻判定により、C後に遅れてenqueueされた古いeventも対象外になる。pending/failed/held/uncertainの削除、sentへの偽装、時刻の手書き補完、cutoffを下げた一括後送を行わない。必要な個別後送は対象と理由を照合し、別承認で扱う。
- **C後の新しい出来事**：同じ本人契約であっても、C後に実際に生じる更新・解約等は新しい正規通知である。B以前の通知の誤後送とは区別し、本人UIDだけを理由に将来の正規通知を一括抑止しない。
- **上限と障害時**：一般用メール設定と共通日次50通案は未承認・未適用のまま。失敗・不達を確認したら既存手順でScheduler PAUSED＋通知flagfalse、必要ならcontactの送信も停止する。受付済み送信を取消せるとせず、claimed/sending/uncertain・共通枠・不達通知を照合する。共有OAuthの取消や過去カウンタのresetで停止・復旧を代替しない。

### 通知の後続配備に向けた運用チェック（今回の承認外・未実行）

最新の停止反映承認は`0ca4810`のCheckout/contactの2関数と必要3assetsに限る。通知producer、worker、メールSecret、IAM、Schedulerの本番変更・通知送信は含まれない。以下は既存実装を配備する前の手順整理であり、新しいコードの追加や再試験を必要とする判断ではない。

1. **producerと設定を先に固定**：別承認後、`stripeWebhook`だけを正規event時刻付きproducerへ更新する。既存のendpoint/API版/署名Secretと正常なbilling同期を維持し、過去イベントの一括再処理はしない。一般用メールは既存の本人送信専用資格情報を再利用する正規Live新versionを固定参照し、本人限定contact試験設定・Previewとの取り違えを防ぐ。旧version/認可/送信履歴は保持する。
2. **送信停止のまま接続**：別承認後、`processBillingNotificationOutbox`を`HAMCARE_BILLING_NOTIFICATIONS_ENABLED=false`・cutoff未設定で限定配備する。既存サービスアカウントとSecret単体権限を優先し、privateのまま対応Scheduler `firebase-schedule-processBillingNotificationOutbox-asia-northeast1`（15分・Asia/Tokyo・OIDC）へ接続してPAUSEDにする。送信枠はcontactと同じ承認済みの有限値へ揃える。正常起動/Secret mountと意図したdisabled応答を分けて確認し、起動失敗を停止制御の成功とは扱わない。
3. **初回稼働と停止の判定**：一般通知の別承認前に、最新outboxの件数・状態・最古時刻と共通counter/`_sender`停止期限を非公開で確認する。本人購入Bの最終eventより後の固定Tを使い、T到達後の有効化だけを次の承認対象とする。稼働後はheld/failed/uncertain等の件数と結果を確認し、障害時はScheduler PAUSED＋通知flagfalseへ戻す。過去通知の再投入、カウンタreset、共有OAuth取消で復旧を代替しない。今回、これらの本番確認・変更・送信は実行していない。

## データと実行の境界

| 処理 | 実装と責務 |
| --- | --- |
| 意味のある通知への変換 | `functions/src/billingNotificationEvents.ts`。信頼済みの正規化billingとhookから通知を作る。メール本文・宛先・OAuth情報は持たない |
| billingとenqueue | 既存`webBillingWebhookStore.ts`のtransaction。billing・event receiptと通知を同時に保存し、Gmailを呼ばない |
| Worker | `billingNotificationWorker.ts`・`billingNotificationStore.ts`。送信可能な通知だけを取得し、lease/attemptを照合して処理する。billingやStripeを変更する依存を持たない |
| 宛先・本文 | `billingNotificationRecipient.ts`・`billingNotificationTemplates.ts`。現在のUID所有情報から宛先を解決し、イベント時点の不変snapshotからHTML/plaintextを生成する |
| 送信・予算 | `billingNotificationGmail.ts`・`billingNotificationBudget.ts`。本人OAuthのGmail API送信と、環境ごとのtransactionalな送信予約上限 |
| 接続・定期処理 | `billingNotificationRuntime.ts`・`billingNotifications.ts`。設定を先に検査し、依存を接続。将来の本番exportは`processBillingNotificationOutbox` |

メール障害でbilling同期や権限反映を失敗にしない。メール本文・宛先・Gmail送信は、Stripe Webhookの処理成功条件に含めない。通知enqueue自体のtransactionはbilling/receiptと整合させ、配送だけを別処理とする。

## Outboxと重複抑止

本番は`billing_notification_outbox/{notificationId}`、Previewは`preview_billing_notification_outbox/{notificationId}`。他環境のcollectionへ代替しない。ブラウザから任意送信を依頼できる公開APIは追加しない。

| 主な保存field | 用途 |
| --- | --- |
| `id`・`idempotencyKey` | 環境・意味のある遷移・template versionから作る安定したSHA-256識別子 |
| `schemaVersion:1`・`templateVersion:'billing-v1'` | 旧hookとの取り違えを防ぐschema識別 |
| `environment`・`trustedSource` | `live/preview`と信頼済みproducer。Liveは`stripe_webhook`だけ。Previewは明示した本人用fixtureも使用可能 |
| `type`・`transitionKey`・`billingEventKey`・`eventHash` | 通知種別、意味のある遷移と署名済みeventの内部参照 |
| `firebaseUid`・`uidHash`・契約/Invoice参照 | 契約主体をUIDで解決するための非公開内部情報。メール本文やログへ出さない |
| `snapshot` | 月額・状態・支払確認・対象期間・次回日・元の体験終了日・解約予約など、enqueue時点の限定した不変field。メール、UID、Customer ID、本文、任意URLを含めない |
| `eventCreatedAtMillis` | 正規Stripe event作成時刻。Live稼働cutoff判定用、処理/保存時刻で代用しない |
| `status`・`attempts`・時刻・lease/attempt | 配送状態、有限再試行、同時実行の所有確認。時刻は`*AtMillis`、`leaseUntilMillis`等 |
| `recipientSource`・`recipientReference` | 送信時に使った宛先種別と内部hash参照。メールアドレス全文は保存しない |
| `sentAtMillis`・`messageIdHash`・`lastErrorCategory` | API受付確認時刻、Gmail Message IDのhash、安全な失敗分類。raw responseは保存しない |

登録開始とtrial開始は同じ`contract_registered`へ、初回課金と更新はInvoice単位の`payment_success`へ統合する。支払失敗も同じInvoiceにつき1通知とし、Webhook再送や同じInvoiceの再試行ごとには増やさない。`invoice.paid`と`invoice.payment_succeeded`の両方が来ても同じ通知になる。解約予約・取消・終了は元の意味のある遷移に結び付ける。metadataだけの変更、内部同期、処理済み再送、状態変化のない古いevent、Customer更新だけではenqueueしない。

Workerは後から最新billingを読み直して過去メールの金額・日付を作り直さない。以前のhookにschema/version/不変snapshotがない場合、現在のbillingで補って自動送信・自動移行しない。通常のdue queryは`dispatchAtMillis`のある文書だけを対象とし、明示的に渡された不正schemaも送信前に`blocked_invalid_notification`へ止める。

## 配送状態と結果不明時

通常は`pending → claimed → sending → sent`。宛先解決・本文生成・予算予約を行ってから、Firestoreに送信開始意図を保存し、その後だけGmailを呼ぶ。所有者はlease tokenとattempt IDで固定し、別Workerが並行送信しない。

| 状態 | 挙動 |
| --- | --- |
| `failed_retryable` | 未送信が明確な一時失敗だけ。次回可能日時以降に有限再試行 |
| `failed_permanent` | 認可取消・不正宛先/要求・最大回数到達。自動再試行しない |
| `blocked_no_verified_contact` | 確認済み宛先なし。billingは成功し、メールは自動再試行せず運用確認対象 |
| `blocked_recipient_not_allowed` | Previewの本人UID/宛先allowlist不一致。送信しない |
| `blocked_invalid_notification` | schema・template・環境等が不正。送信しない |
| `uncertain` | Gmailが既に受け付けた可能性がある。自動再送しない |
| `held_before_dispatch_start` | Live稼働前又はevent時刻不明。既存履歴を保ち、自動送信/自動再投入しない |

送信前の`claimed`だけが期限切れなら再取得できる。`sending`の期限切れは新Workerへ引き継いで再送せず、`uncertain`へ隔離する。送信後のFirestore更新失敗も、既に保存した送信意図を残す。元の同じattemptに遅れて確かな成功応答が返った場合は、照合したうえで`sent`を記録できる。

Gmail `messages.send`の公開APIには、任意の冪等keyで重複送信を保証なく排除する契約は記載されていない。安定したRFC Message-IDは照合用であり、Gmailの重複排除を保証しない。そのため本実装は、送信APIの5xx・timeout等を無条件に再送するより、結果不明を運用確認へ止める。これは重複防止を優先する本実装の判断である。[Google messages.send](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/send)

`uncertain`は、ご本人がGmailの送信済みと安定Message-IDを照合して結果を確認する。送信専用OAuthにメール閲覧権限を追加して自動検索しない。送信済みなら内部状態を照合済みにし、未送信と確定できなければ新IDの作成やstatusリセットで再送しない。今回、そのような本番再投入・補正操作は行わない。

## 宛先とメール内容

契約主体はFirebase UIDのまま。現在のAdmin AuthをUIDで取得し、①確認済み通常メール、②確認済みApple Relay、③同じUIDの確認済み補完連絡先の順で解決する。メールでUID/Customerを検索・統合しない。Authアカウントの削除・無効化、UID不一致を無視して送らない。

Relayは`privaterelay.appleid.com`と`private.icloud.com`を許可する。Auth上のRelayは確認済みメールと適切なApple provider identityを照合し、文字列の形式だけを証明にしない。独立補完連絡先は、同じUIDの確認済みchallenge結果と環境別purposeを使う。本番は`billing_contacts/{uid}`、Previewは`preview_billing_contacts/{uid}`であり、相互fallbackしない。

| 通知 | 内容 |
| --- | --- |
| `contract_registered` | 体験中はカード登録時0円、元の初回請求日と550円。即時の場合は支払確認、月次更新、契約管理 |
| `payment_success` | 初回/更新の実支払額、対象期間、次回日又は更新停止 |
| `payment_failed` | 支払未確認、管理画面での支払方法確認、カード情報を返信しない旨、サポート |
| `cancel_reserved` | 契約期間終了予定、利用条件、次回更新停止、日割りなし。支払未解決時に利用可能と断定しない |
| `resumed` | 解約予約取消、月次自動更新と次回予定 |
| `canceled` | 契約終了と以後の更新停止。Stripeの`canceled_at`を実際の利用終了日時と取り違えて表示しない |

新規正式価格は月額550円。旧500円契約は明示されたlegacy snapshotから実際の旧価格・実支払額を表示し、550円へ変更したようなメールを作らない。日付は日本時間で表示し、遅延配送でも誤解しないよう「変更を受け付けた時点」の内容と明示する。

From表示は`HamCare`、送信元/Reply-Toは既存の公開サポートGmail。HTMLとplaintextのmultipart、UTF-8、現行の黒地・白線ハムスターアイコン、柔らかい青緑を使用。複雑なCSS/JavaScriptなし。リンクは環境ごとの固定`/account/`だけを契約管理入口に使う。Stripe Portal bearer URL、カード番号、UID、Customer ID、tokenを本文へ含めない。

## 個人Gmail OAuthとSecret

個人Gmailの本人OAuth認可・client ID/client secret/refresh tokenを使う。Google WorkspaceのDomain-Wide Delegationやservice accountによる個人Gmail impersonationを前提にしない。権限は既存の送信専用認可を利用し、受信・削除・メール閲覧権限を追加しない。[Google Gmail scopes](https://developers.google.com/workspace/gmail/api/auth/scopes)

Preview限定送信は既存の`HAMCARE_PREVIEW_CONTACT_MAIL_CONFIG`に保管された本人OAuthをメモリ上で利用する。新Workerの環境/allowlist schemaへ明示して接続するだけで、既存Secretの値や認可設定を無断変更しない。将来の本番用は`HAMCARE_LIVE_BILLING_MAIL_CONFIG`を宣言するが、今回作成・値登録・本番権限付与は行わない。

新schemaは`enabled:true`、`environment`、固定`from`、`clientId`、`clientSecret`、`refreshToken`。Previewでは非空の`allowedSubjectHashes`と`allowedRecipientHashes`も必須で、両方一致した本人用UID/宛先だけを許可する。本番はPreview allowlistを受け付けない。未設定・無効・不正・環境違いは、Auth/DB/送信へ進む前にfail closed。Secret値、Bearer/ID token、宛先全文、MIME、raw Google errorはGit/Firestore/logへ保存しない。WorkerへStripe Secretを渡さない。

## 有限再試行と個人Gmailの上限

固定の初期値は、**初回を含む最大5 attempt、基本1分、指数backoff最大1時間、lease120秒、1batch最大5件**。定期処理の宣言は15分ごと、同時instance1、timeout120秒、Scheduler自体のretry0で、outboxが再試行を管理する。1分は再取得可能になる最短時間であり、15分周期なら実行は次のtick以降になる。

5回はGoogleの推奨回数ではない。既存Previewの本人1日5通という有限運用と今回の5通smokeに合わせ、原因不明を長期間自動反復させない初期値である。1分からのbackoffと小batchで短時間の集中を避け、上限到達後は運用確認へ回す。欠損設定や認可取消を回数だけ繰り返さない。

| 失敗 | 処理 |
| --- | --- |
| OAuth token取得の429/5xx・送信前の一時障害 | 未送信なので有限指数backoff |
| Gmailの明確な429/rate limit拒否 | `Retry-After`があれば通常backoffより長い方を尊重 |
| `quota_exceeded`・`sending_limit` | 少なくとも24時間と`Retry-After`/backoffの長い方。UTC日付が変わっただけでは送信可能と仮定しない |
| invalid recipient・認可取消/401・malformed request | 恒久停止、有人確認 |
| Gmail送信APIの5xx・408・network timeout | 受付済みの可能性があるため`uncertain`、自動再送なし |

Googleは一時エラーに指数backoffを案内している。上表の「送信受付が不明なら隔離」は、送信専用権限と重複抑止を守るために本実装が追加した保守的判断である。[Google Gmail errors](https://developers.google.com/workspace/gmail/api/guides/handle-errors)

Previewは本人UIDごと5枠/日、確認メールと共用する全体10枠/日。予算は送信意図の前にtransactionで予約し、事故時に余分な枠を消費しても上限を超えない側へ倒す。本番は`HAMCARE_BILLING_MAIL_DAILY_LIMIT`の明示設定が必須、1〜100で制約しdefaultを作らない。個人Gmailの公示500通/日を満額使わず、有人返信等に余裕を残す設計値である。Gmail側の利用可能枠を保証する値ではなく、他の送信client・手動利用も同じアカウント枠を消費する。[個人Gmail上限](https://support.google.com/mail/answer/22839?hl=en)、[APIの共通送信制限](https://developers.google.com/workspace/gmail/api/guides/handle-errors)

制限はjob単位の延期だけでなく、各環境の送信枠collectionの`_sender`へ`untilMillis`/`category`だけを保存し、Worker全体の停止期限として使う。quota/sending limitは最低24時間、明確なrate limitは最低1分とproviderの長いRetry-Afterを尊重。後続jobは予約transactionでこの期限を読み、Gmailを呼ばず延期する。既存の長い停止期限は短縮しない。Preview確認メールの既存実装や手動Gmail全体を停止する設定変更ではなく、今回の通知Worker間で共有する保護である。

`sent`はGmail APIが受付応答を返し、その応答をoutboxへ保存できた状態であり、最終配送・受信・迷惑メール回避の保証ではない。バウンスは別の運用確認対象。送信専用権限のため自動バウンス読取りは未実装で、本人が送信元の受信通知を確認する。連続した不達や再認可の必要が判明した場合は運用停止して原因確認し、billing同期は継続する。[Gmail APIの受付と送信制限](https://developers.google.com/workspace/gmail/api/guides/handle-errors)

## 公開前に残す確認（11月27日更新）

- 本番Worker/Secret/IAM/Schedulerは上記の停止状態で反映・確認済み。一般連絡先もv4/共通50へ揃える反映、一般cutoff固定/有効化は別承認待ち。本人限定のLive通知実配送は未実施。
- OAuthは既存の「外部・本番/送信専用認可あり」の確認を再利用し、今回再同意/スコープ変更/認可取消をしない。将来の認可失効や長期無人運用の実績は今回の停止callbackで確認できない。[Google refresh token expiration](https://developers.google.com/identity/protocols/oauth2/#expiration)
- 本番の独立連絡先確認は実配送・確認済み保存・復帰まで完了済み。新しい契約通知のLive実配送は未確認。既存Preview連絡先を本番へ暗黙移行しない。
- 本人Relayアドレスを確保した後の配送確認。登録済み送信元と両Relayドメイン対応は維持し、実配送未確認を成功扱いしない。
- result unknown/バウンス/認可取消/恒久失敗の有人確認手順、通知の送信後/失敗後の保持削除、退会連携。保持期間/TTLは今回勝手に追加しない。
- 本番新550円と既存500円の実データ互換性、公開管理ページ/アイコン配信、Live契約・同期・通知の実E2E。今回の合成試験と本人PreviewメールをLiveの証明に使わない。

## 最終検証・本人限定配送記録

2026-11-21、既存の本人UID/宛先許可リストと同一UIDのプロフィール/補完連絡先を読み取りで確認。固定runner `functions/scripts/billing_notification_preview.cjs --send-owner-preview`から、本人だけのPreview fixture5種類を各1通送った。Secret値・宛先・UID・確認tokenは報告/ログへ出さず、Preview outboxと送信枠だけを書き、本番billing/Stripeへ接続していない。

| 種類 | Gmail API/outbox | 本人の受信・表示確認 |
|---|---|---|
| 契約登録（体験中のカード登録0円、初回550円予定） | sent、attempt1 | PASS |
| 支払成功 | sent、attempt1 | PASS |
| 支払失敗 | sent、attempt1 | PASS |
| 解約予約 | sent、attempt1 | PASS |
| 契約終了 | sent、attempt1 | PASS |

本人回答は「5通とも届き、記載内容・迷惑メール判定・スマホ表示に問題なし」。件名、FromのHamCare表示、Reply-To、本文、550円、JST日付、固定管理リンク、日本語、迷惑メール判定、Gmailスマホ表示を確認済みとして記録する。予約取消は合成検証のみで余分な実メールを送らない。実Relay配送は未確認のまま残す。API受付と本人の受信確認は別の根拠として扱う。

同じrunnerの再実行では、送信済み5件を保持して`providerSendCalls:0`、`processed:0`を確認。再実行時刻でcanceled fixtureのkeyが変わる問題を修正し、本人runの未送信・未dispatch・予算拒否の余剰1件だけを削除した。送信済み/送信中/uncertainは削除・resetせず、runの不変時刻をtransactionで保持する。実メールは合計5通のまま。runner回帰試験6件は、日時の変わる再実行、未送信余剰だけの後始末、sent/sending/uncertain保護、別UID/任意引数の拒否を確認した。

最終検証はNode22と既存依存のみ。Functions/Preview build PASS、通知/本番API関連21ファイル984件、Preview既存11ファイル514件、現行Rulesの専用demo Emulator2件で**1500件PASS**。Rulesは228のclientアクセス操作を確認し、終了後8297/50372閉鎖を確認。通知新規8ファイル400件はWorker62、Gmail95、宛先/本文110、Runtime/送信枠116、通知変換11、runner6。実Gmailの障害を故意に発生させず、429/5xx/401/timeout、送信記録失敗、並行lease/期限切れ、global停止期限を合成依存で確認した。実IAM/本番構成/長期配送の検証と混同しない。
