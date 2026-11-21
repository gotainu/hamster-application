# 契約通知outboxとGmail Worker（2026-11-21・本番未配備）

開始点は承認済み`81ac23933fda`。本書は今回の通知実装に限った設計・運用記録であり、[本番切替Runbook](web_billing_live_cutover_runbook_ja.md)の実行承認ではない。本番Functions、Live Stripe、live Hosting、Flutter、ストアは変更しない。外部テスターへ送信せず、Previewの実送信は本人所有UIDと宛先だけに限定する。最終テスト件数と5種類各1通の実送信結果は、確認後に本書末尾と`PROJECT_STATUS.md`へ記録する。

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

## 未実施・公開前に残す確認

- 本番Worker/Secret/IAM/Schedulerの配備と実値確認。本番通知とPreview連絡先確認の送信枠、有人Gmail利用を合わせた実運用予算決定。
- OAuth同意画面の実際の公開状態とrefresh tokenの長期利用可否。外部アプリのTesting状態では通常7日でrefresh tokenが失効する条件があるため、今回の送信成功だけで無人の長期運用GOとしない。現在の公開状態は今回照会・変更していない。[Google refresh token expiration](https://developers.google.com/identity/protocols/oauth2/#expiration)
- 本番の独立連絡先確認producerとGmail通知接続。既存Preview連絡先の本番への暗黙移行はしない。
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
