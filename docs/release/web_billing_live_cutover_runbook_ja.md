# HamCare：本番切替Runbook（停止準備配備済・購入公開未実行）

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
| Gmail API | 初回リリース採用・本番送信停止 | Preview配送済。本番contactは停止配備済、通知Worker未配備。scope宣言/資格情報/実配送は残件 |
| Apple Relay送信元登録 | GO（過去の登録証拠） | 2送信元登録・SPF確認済み。今回設定再確認/変更なし |
| Relay実配送 | 未確認・非ブロッキング | 本人所有の宛先確保時に確認、成功したとは記録しない |
| 連絡先補完 | Preview GO | 既存の実配送1件と確認済み連絡先・UIDガードの証拠を維持 |
| 本番連絡先確認 | 停止状態で配備済 | false/資格情報なしSecret、正規JSON停止応答確認。実配送/Relay/確認後復帰は未実施、Preview fallbackなし |
| Stripe Test | GO（既存検証） | 550円、体験/即時、Webhook、Portalの既存証拠。今回追加決済なし |
| Safari E2E | GO（既存Test E2E） | 既存Apple購入・同期・Portal・期間末解約PASS。今回の本番検証ではない |
| Android Chrome表示 | GO（既存表示検証） | 連絡先ページの実機表示/入力PASS。Androidの購入E2E全体とは区別 |
| Live Stripe | 未実施 | 新550円Price・新規申込接続は未実行 |
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

## 本番連絡用メール確認の有効化手順（停止準備配備済・有効化/実配送は未実行）

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
