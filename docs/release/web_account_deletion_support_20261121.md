# Webアカウント削除申請・本人確認の運用（2026-11-27本番接続更新）

## 2026-11-27 本番後段の接続・無害限定確認完了

- 現在はメール受付→既存Web認証/同UIDの本人確認・削除意思→専用private operator dry-run→既存Stripe停止/削除へ接続済み。confirm **confirmsupportaccountdeletion-00003-der**/operator **supportaccountdeletionoperator-00003-zun**のsupport flag true、確認URLは`https://hamster-breeding-app.web.app/account-deletion/confirm/`。公開申請と後段のログインを区別し、メール未設定/Relay/プロフィールなしも対象。ログインできない人には下段の復旧・個別対応を使い、未確認の削除経路を作らない。
- CLIへ **`hamcare-deletion-operator@hamster-breeding-app.iam.gserviceaccount.com`**を指定する。権限はoperator単体Invoker、運営者のそのSA単体Token Creatorのみ。リンク/入力/reviewは非公開0600・新規exclusive、既定review。申請対象と既存Auth作成時刻を運営の非公開画面で照合し、メール本文/UID入力を実行対象へ差し替えない。
- 追加1回だけのmanual_review再開は既存アプリ削除/worker/新operatorに反映済み。累積attempt/排他/Stripe停止確認/フェンスを維持し、fresh5分review＋別ack、MAX12後なら13まで、追加失敗後はmanual_review。通常のretry Schedulerは元のENABLED/15分/JST/OIDCを維持。実在ユーザーの要求を試験用に作成/再開していない。
- 最初の本文なしGET500を発見しconfirmを一時privateへ閉じ、**faccdfc**のwrapper2行だけの修正/実wrapper回帰2件/strict compile/実archive170file一致後に公開復帰。修正後の無害probe17件PASS、前後support0/既存削除completed2/outbox0/枠6不変、旧500記録は保持。実申請create/有効execute/resume/実削除/メール/Apple操作なし。実運営の削除完了・Apple失効の新E2Eは未実施として残す。
- Hosting **178ff2689650346f**の4path追加・既存51hash保全、確認route限定CSPを実HTTP照合。Live派生JSのenable1定数はtrue、repo既定falseは維持。停止/退避/Revision/根拠は[Runbook最新実行記録](web_billing_live_cutover_runbook_ja.md)へ集約。担当Go・返信/途中連絡・週初営業日の対象限定90日/30日手動整理は下段を再利用し、TTL/履歴整理を実施済みとしない。

以下の同日準備節は**反映前の履歴**。「2API未配備」「ローカルまで」は上段の実反映で更新済みであり、実申請/実削除は今回行っていない。

## 2026-11-27 公開後の入口・再試行・手動完了の現在地

- **使える入口と担当**：公開`/account-deletion/`のメール受付とコピー操作は11/27に反映済み。主担当Goが毎営業日に新着・返信期限・未完了/遅延案件を既存受付番号で確認する。申請時のログイン/再インストールは不要で、メール未設定Apple/Relay利用者も受け付ける。受付だけで本人確認済み・削除済みとせず、原則3営業日/本人確認と削除意思確認後7暦日/遅延7日ごとの既存方針を適用する。毎週最初の営業日に行う90日/30日対象の整理は後段の手動手順を再利用し、自動TTLが稼働済みとはしない。
- **アプリ内の既存経路**：`deleteMyAccountAndData`と`retryAccountDeletions`は11/23に限定配備済み。再試行Schedulerの15分/Asia/Tokyo接続は既存配備記録を再利用し、今回再配備・実削除・新しい状態の照会は行わない。Goは公開後、毎営業日に`account_deletion_requests`の古いrunning、期限超過retryable、manual_reviewとScheduler/Function失敗を非公開で確認する。エラー文字列は`Account deletion needs operator review`、`Account deletion worker failed`。自動監視通知の設定・受信試験は確認済みと扱わず、最初はGoの手動確認を前提にする。
- **メール申請の手動完了経路は未稼働**：既存`confirmSupportAccountDeletion`/`supportAccountDeletionOperator`、限定運営IAMと確認Web画面はコード・Mockまでで、本番未配備。現状のメール受付だけでは、アプリを使えない申請者を同UIDで確認し、既存Stripe停止付き削除まで安全に完了させる運営経路が足りない。新しい申請を運営の推測、メール一致、Auth直接削除、アプリ再インストールの要求で処理しない。公開後の実稼働前に、下段の既存2API/private IAM/Web接続を別の具体的承認範囲で配備・限定確認する必要がある。通知workerの本番配備と混ぜない。
- **完了条件**：Goが同じ確認済み申請のdry-runで対象・削除範囲・契約snapshotを確認し、既存処理がStripe最新状態/停止を確認した後にcleanupを行う。`completed`フェンスとAuth不存在の再読取がそろって初めて削除完了。API受付、Apple失効、通知メールだけでは完了にしない。Auth削除後のcleanup再開では、利用者へ再ログインを要求せず永続要求を正本とする。実ユーザーのデータ/会計記録を運用文書の整備のために削除しない。

### manual_reviewの明示再開（ローカル最小追加、本番未配備）

従来の`manual_review`は通常のアプリ削除再操作/worker/既存operator executeでも再開せず、既存CLIにも安全な解除actionがなかった。この不足に対し、既存private operatorとCLI、本人確認済み申請、削除フェンスをそのまま使う明示再開をローカルで追加した。新しい公開削除APIや任意UIDの直接削除経路は作らない。

1. Goが原因と現在状態を非公開で調査してから、通常の`--request=... --output=<非公開review>`でfresh dry-runを取得する。reviewは既存の5分期限・申請/UID/Auth作成時刻/契約/fence全体にboundで、停止理由、累積attempt、追加再開の使用有無、`manualResumeAllowed`も確認する。本人未確認/同意なし、不正・別UID・新規Auth再作成、古いreviewでは進めない。
2. `manualResumeAllowed:true`の場合だけ、同じ申請IDで`--resume-manual --review-file=<直前review> --ack=RESUME_VERIFIED_DELETION`を明示する。通常`--execute`やそのackでは再開しない。CLIは専用運営SAの既存private endpointだけへ接続し、UIDを入力/差替えさせず、Admin SDKでDB/Authを直接消さない。実施前の対象/理由/権限確認はGoが行う。
3. サーバーtransactionで同じmanual_review fence/UID/version/attempt/updatedAt/lease/digestを再照合して、**累積attemptをresetせず追加1回だけ**claimする。通常MAX12後なら13回目が上限。既存課金停止同意を検証済み申請から引き継ぎ、`billingStopped`を運営入力でtrueにせず、既存Stripe最新照合・停止確認と既存cleanupへ合流する。停止済みの正規証跡は維持し、新しいCustomer/契約/請求を作らず、停止済みの契約へキャンセルを無用に繰り返さない。
4. 追加1回で失敗した場合は直ちにmanual_reviewを保持し、Goが原因調査と途中連絡に回す。途中中断後もworker/通常アプリから予算を復活させない。同じreview再使用、二重実行、別申請への流用、未知fenceは拒否する。追加再開を使い切った要求を無制限resetしたり、停止証跡/フェンスを消したりしない。完了を確認できないまま完了メールを送らない。

これはローカルコード/選択した直接Mock検証までである。新しい再開actionも含め、Web本人確認/運営実行APIの本番配備、private IAMの許可/拒否、実ユーザーの再開は未確認。実Apple失効後のStripe停止失敗→同UID再ログイン/削除再開は引き続き実機未確認で、Mock成功と分ける。

今回の直接検証は新manual resume12件と、変更に関係する通常の無料削除1件/Stripe一時失敗再開1件の**14/14 PASS**。既存28件は選択外とし、既存削除/課金/認証の全E2Eを繰り返さない。既存Node20とlock一致dependenciesを再利用し、SDK/依存追加、本番配備、実メール、実削除、Stripe Live操作は0。通知変更とこの削除再開を合わせた隔離strict TypeScript型検査もPASS。

以下の2026-11-22接続実装・2026-11-21前工程は当時の記録であり、アプリ内2関数の配備済み実績や本節のローカル再開追加と区別する。

## 今回つながった経路

承認済み`fcdd64465613`から継続。メール受付→運営が既存Authレコードを選択→申請専用リンク→既存Firebase Web認証/再認証→サーバーでUID/作成日時/Apple subjectを検証→同じ申請に削除と継続課金停止への同意を記録→運営dry-run→明示実行→既存`runAccountDeletion`→完了証跡照合、という最小接続を追加した。実行は`e1fe0524dbb9`のStripe停止・排他・再試行・削除フェンス・既存tree walkを使い、直接Auth/Firestoreを消す別経路は作らない。現在有料契約者0人という前提を維持する。

**コード/Mock・隔離検証の準備であり、本番運用開始ではない。** Functionsは未配備、サーバーenable switchは未設定なら停止、Webのenable定数もfalse。PreviewからFirebase認証/Apple失効/本人確認APIへ進ませない。メール送信、実アカウント削除、本番Firestore/Stripe/Auth/Storage操作は行わない。

### 本人確認と期限

- `support_account_deletion_requests/{random192bit}`に、運営がAdminで選択した既存UIDとAuth作成時刻、個人情報を含まない受付番号を固定。メール/本文UID/写真は候補特定の補助に限り、本人確認の証拠にはしない。選択が誤っていれば確認を拒否し、運営が元の申請を照合してリンクを再発行する。メール一致による統合はしない。
- リンク秘密値は256bit、`sha256(requestId:proof)`のみ保存。URL fragmentから読み取って即座にURLを消去、メモリだけで保持。ID Token、UID、メールはURLに載せない。リンクの転送・公開・追跡クリックサービスを使わない。
- リンクは24時間、Firebase再認証は5分以内かつ申請発行後、運営reviewは5分。未着手の確認済み申請も確認から24時間を過ぎれば再確認が必要。処理開始済みは既存の永続削除要求を正本にし、期限を理由に中途放棄しない。これはセキュリティ上の有効期限であり、保存データが自動削除される期間ではない。
- Admin `verifyIdToken(token,true)`と現在の`getUser`、既存`authorizeWebBillingManagementIdentity`を再利用。署名・失効・同一UID・当初Auth作成時刻を検証し、Appleセッションはprovider subjectも照合。別UID、後から作成/再作成したUID、新規登録、期限切れ、他申請proof、再利用を拒否。本人が明示した削除/課金停止意思を同じ申請にtransactionで1回記録する。
- 購入用のメール確認、飼い主/ペット存在、体験/購入ガードは使用しない。既存のプロフィール未登録・未確認メール・Appleメールなし/Relayも同じ既存UIDの認証ができれば対象。実メール登録・購入・アプリ再インストールは要求しない。

### 運営手順（配備/権限確認後だけ使用、今回実行しない）

1. 公開ページからのメールに受付番号を付ける。返信の送付先は連絡先であり本人認証ではない。既存Authで候補を確認し、対象UIDと`creationTime`を非公開管理画面で照合する。申請者へパスワード・認証コード・ID Tokenを送らせない。
2. 運営端末の非公開ファイル（0600、Git外）に`{"targetUid":"対象の既存UID","intakeRef":"CASE_001"}`を置く。UIDをチャット/コマンド引数/公開記録へ転載しない。
3. `tools/support_account_deletion.cjs`を既存Node22で実行する。`--service-account=<承認済み運営SA> --create --input=<非公開ファイル> --output=<新規非公開リンクファイル>`。固定private endpointだけへ、専用SAをimpersonateしたaudience指定OIDCで接続する。リンクはファイルへだけ保存（0600/exclusive、既存ファイルは上書きしない）。今回この操作はMockのみ。
4. リンクを申請メールの返信で案内する。本人が既存のログイン方式でサインイン/再認証し、対象・削除範囲・課金停止条件を確認して同意する。サーバーでUID一致を確認できない限り削除へ進まない。
5. `--service-account=... --request=<申請ID> --output=<新規reviewファイル>`が既定dry-run。削除対象UIDハッシュ、受付番号、削除範囲、**Firestore上の契約snapshot（Stripe最新状態ではない）**、停止/処理状態、Apple対応、Auth有無を非公開reviewで確認する。dry-runはStripe API/削除フェンス/データ変更0。判断に必要な実UID照合は運営の非公開Auth画面と行い、対外文面に載せない。
6. 対象/意思/範囲に相違がない場合だけ`--service-account=... --request=... --execute --review-file=<直前review> --ack=EXECUTE_VERIFIED_DELETION`。実行にUID引数はなく、確認済み申請のUIDだけを使う。申請/契約snapshotが変化したり5分を過ぎればreviewをやり直す。
7. Stripe最新状態・UID/Customer/Subscription/Price/Invoiceを既存処理で照合。停止未確認ならAuth/データ削除を止め、同じ申請からreview/再開する。停止済みなら既存cleanupへ。新規Checkout排他、11分lease、有限backoff/15分worker/最大12回、manual_review、遅延Webhook抑止を維持する。停止証跡やフェンスを手動で消したり成功に書き換えない。
8. `completed`フェンス **かつ** Auth不存在をサーバーで照合してから完了とする。worker完了後も同じ申請をreviewして照合可能。API応答だけ/メール受付だけ/Apple失効だけでは完了にしない。未完了は毎営業日確認し、manual_review、期限超過、worker障害を既存の監視手順へ接続する。
9. 照合後だけ下記完了案を人が返信する。自動メール送信機能は追加していない。

権限境界：`supportAccountDeletionOperator`は`invoker:'private'`。Hosting rewrite、公開callable、public/allUsers/allAuthenticatedUsers権限を付けない。専用運営SAのCloud Run Invokerはこの1サービスだけ、操作者のToken CreatorはそのSAだけへ限定し、操作者へFirestore/Auth削除権限やプロジェクトOwnerを与えない。runtimeの既存削除用権限/Secretは別途最小化する。IAMの実機拒否/許可テストは配備前提の残件。

### ログインできない場合

メール/パスワードは既存Firebaseパスワード再設定、Google/Appleは元と同じプロバイダとアカウントの復旧を案内する。既存Web認証で同UIDへ復帰できれば申請リンクを再発行する。Appleの非公開アドレスやメールなしを理由に別IDへ付け替えない。購入・プロフィール登録は不要。認証が復旧できない場合は個別サポートで調査/連絡を続け、本人確認成立前の削除経路・メール一致移行・運営によるAuth直接削除は用意しない。処理開始後のAuth削除済み/データ削除途中は、再ログインを要求せず既存要求のworker/運営照合で再開する。

### Web/運営経路のApple対応

既存Firebase JS 12.17.1の`reauthenticateWithPopup`と`revokeAccessToken(auth, accessToken)`を使用でき、SDK/Service ID/Key更新は不要。[Firebase Web Apple公式](https://firebase.google.com/docs/auth/web/apple#token_revocation)。Flutter helperをWebから呼んだり、Firebaseセッション失効をApple OAuth失効と記録したりしない。

Web認証→申請との同UID preflight→連携Appleで再認証→元/返却/現在UIDと既知Apple subjectを照合→再preflight→取得直後のaccessTokenを失効→同じ申請へ意思確認、の順。Appleトークン/codeはメモリ限りで、Firestore/URL/ログ/運営APIへ送らない。Stripe待機やworkerへ持ち越さない。サーバーに残す`revoked_client_reported`は**client申告**であり、Apple側成功の独立証明ではない。

tokenが得られない/失効失敗時は[Apple設定からの手動解除](https://support.apple.com/102571)を明示し、本人が継続を明示した`manual_acknowledged`を記録する。[TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple)どおりトークンがないだけで削除を永久拒否しない。一方UID不一致・本人認証未成立はmanualで迂回しない。Apple以外の未連携アカウントは失効要求なし。

実Apple失効は今回0件。失効後にStripe停止が失敗した場合の同UID再ログイン/再開は引き続き**実機未確認**。今回Mockの再試行成功を実機PASSに置き換えない。

### 対応目安と窓口履歴の保持方針（2026-11-22確定、本番運用未開始）

運営者が次の方針を承認した。公開予定の削除申請ページと返信文案にも反映する。これは方針・手動運用手順の確定であり、TTLや自動整理処理を実装・有効化した記録ではない。今回、本番配備・履歴削除・実メール送信は行わない。

- **初回返信**：受付から原則3営業日以内。営業日は日本時間（Asia/Tokyo）で土曜・日曜・日本の祝日を除く。担当者が受付日時と当該年の祝日を確認して返信期限を管理する。
- **削除完了**：本人確認と、その申請での削除意思確認の両方が完了した後、原則7暦日以内を目安とする。メール受信だけを起点に削除済みとせず、Stripe停止や既存cleanupの安全条件を省略しない。
- **遅延時**：理由と完了見通しを案内し、その後7日ごとに進捗連絡する。見通しが未確定の場合も、その事実と次の確認予定を案内する。未完了を完了扱いにしない。
- **完了した申請の窓口履歴**：確認済み削除完了日から90日を保存期間の基準とする。
- **期限切れの未確認申請の窓口履歴**：その確認リンクの失効日から30日を保存期間の基準とする。確認リンク24時間、再認証5分、review5分は延長しない。

90日・30日の対象は、該当申請の受付/対応メールと添付、本人確認・削除意思の窓口記録である。具体的には`support_account_deletion_requests/{requestId}`の受付番号・対象UID/Auth作成時刻・確認proof hash・同意/確認時刻・Apple対応の申告・完了結果、および窓口用に保存したCLIの受付/リンク/reviewファイルを含む。確認トークンを含む不要なコピーを新たに作らない。メールに別の未解決申請や紛争資料が混在する場合はスレッド全体を一括削除せず、対象部分の整理又は理由付き保留を選ぶ。

**一括適用しないもの**：処理中/確認済み未完了の申請、`account_deletion_requests/{sha256(uid)}`の再試行/課金停止証跡と完了フェンス、データ復活防止の記録、会計記録、課金対応/Session調整・Webhook receipt・通知outbox。その目的別の保存方針を先に確認し、窓口履歴の90日・30日だけを根拠に削除しない。

#### 手動整理の担当・手順・頻度（本番運用開始後に実施）

担当はHamCare運営者（Go）。代理担当を置く場合は、この窓口履歴を扱う範囲の権限だけを承認し、アカウントや課金を直接削除できる権限を付けない。専用の新管理表は作らず、既存サポート記録の受付番号・予定日・対応記録を使う。

1. **毎営業日**、新着メール、返信期限、本人確認後7暦日目安、遅延時の次回7日連絡日を確認する。削除要求のrunning/retryable/manual_reviewとworker障害は既存の確認手順を続ける。
2. **週1回、最初の営業日**に、完了日+90日又は未確認の失効日+30日を経過した窓口履歴を受付番号単位で抽出する。日時はJSTで確認し、基準日と対象の状態を照合する。自動で消えると扱わない。
3. 完了対象は既存completedフェンスとAuth不存在を再確認する。未確認対象は`status:pending`のまま期限切れで、確認済み/処理中の要求や別の未解決案件に必要な資料でないことを確認する。再試行・異議申立て・紛争/法令上の保持が必要な場合は、理由と次回確認日を記録して保留する。
4. 該当する窓口メール/添付・申請記録・非公開ローカルファイルを、保存先ごとの通常の手順で削除又は目的に必要な最小情報へ整理する。復旧不能な最終削除はその操作の権限・承認を確認する。Gmailのゴミ箱等への移動だけで完全消去済みと記録せず、残存時はその状態を記録する。`account_deletion_requests`、billing/会計、ユーザー本体をこの作業で操作しない。
5. 既存サポート記録へ実施日・担当・受付番号・整理した情報の種類・結果又は保留理由/次回確認日を残す。UID、メール本文、proof/tokenの値を実施記録へ転記しない。抽出・整理処理を稼働済みと記録するのは、実施した範囲だけとする。

本番運用の開始と保存先ごとの権限確認は後続の本番反映工程で行う。今回、対象の抽出や履歴整理は実行していない。期限経過と削除処理中の安全な再試行を混同しない。

| 情報 | 現在の実装/理由 | 期間・期限後の扱い |
|---|---|---|
| Auth/users全階層・switchbot・独立連絡先・固定ペット画像 | Stripe停止確認後、既存cleanupで削除 | 完了工程で削除。すべての外部コピー即時消去とは表示しない |
| 申請の窓口履歴（受付/対応メール・添付、support申請UID/作成時刻/受付番号/proof hash/同意/Apple対応、窓口用CLIファイル） | 本人確認・対象固定・完了照合。処理中は保持 | 完了日から90日、未確認の期限切れ申請は失効日から30日を基準に、上記週1回の手動手順で整理する方針が確定。TTL/自動purgeなし、本番整理は未開始。処理中・紛争等の保留は除外 |
| 削除中要求 | UID、同意、試行/失敗/停止確認 | 解決まで保持。途中で消さない |
| 完了フェンス | UIDハッシュ、version/status/completedAt。復活/二重課金防止 | 現在は無期限/TTLなし。ハッシュは匿名化保証ではない。遅延イベント/再作成リスクを評価後、必要最小化を別承認。先に削除しない |
| 課金Customer/Session対応・Webhook receipt・通知outbox | 会計/重複処理/障害照合 | 現在TTL/purgeなし。目的別の保存期間・手動/自動整理を本番前に承認し、法定記録と分離。年数を推測しない |
| Stripe請求書/支払い等 | 会計・法令上の保持が必要な場合 | 適用する記録ごとの法定期間を運営/会計担当が確認。今回削除・返金・voidなし |
| Preview連絡先/challenge・外部ログ/メール/分析/バックアップ | 既存cleanupの対象外がある | challenge15分はリンク期限で自動消去期限ではない。pendingは自然消去されず、使用済みhashは上限10。各保存先の保持/削除作業を別途確定。未実装の自動削除を約束しない |

### 返信文案（今回送信しない）

受付/本人確認案：
> HamCareのアカウント削除申請を受け付けました。初回返信は受付から原則3営業日以内（土日祝日を除く日本時間）とし、ご本人確認と削除意思の確認後、原則7暦日以内を削除完了の目安としています。削除を安全に進めるため、別途ご案内する本人確認リンクから、これまでHamCareでお使いの方法でログインし、削除内容をご確認ください。アプリの再インストールや購入、個人の実メール登録は不要です。パスワード・認証コード等を返信する必要はありません。ログインできない場合はその旨をお知らせください。

途中案：
> HamCareの削除申請について、現在、［遅延理由］のため処理を確認しています。削除完了はまだ確認できておらず、現在の見通しは［完了見通し、又は未確定である旨と次の確認予定］です。以後7日ごとに進捗をご連絡します。追加の購入や新しいアカウント作成は不要です。

完了案（completedフェンス+Auth不存在の照合後だけ）：
> ご本人確認をいただいたHamCareアカウントの削除処理が完了したことを確認しました。対象の登録情報・飼育記録等は削除され、該当する有料契約がある場合の今後の自動請求も停止しています。法令上保存が必要な請求記録や、不正利用・二重処理を防ぐための最小限の情報は保持する場合があります。Apple連携の手動解除をご案内していた場合は、Appleアカウント設定で解除状況をご確認ください。ご利用ありがとうございました。

### 今回の検証記録

結果・Preview幅360/390・安全境界・Gitは`PROJECT_STATUS.md`の2026-11-22節を正本とする。実環境で未確認なのは運営IAM/本番配備/実アカウント削除/実Apple失効とその後の同UID再ログイン。実メールは送らない。現在の公開版へつながったと扱わず、承認後に本番反映手順を実施する。

変更ファイル（今回分18件）：

- 接続：`functions/src/supportAccountDeletion.ts`、`functions/src/supportAccountDeletionHttp.ts`、`functions/src/index.ts`。
- Web：`public/account-deletion/index.html`、`public/account-deletion/confirm/index.html`、`public/assets/support-deletion-service.mjs`、`public/assets/support-deletion.mjs`、`public/assets/support-deletion.css`。
- 運営：`tools/support_account_deletion.cjs`。
- 限定試験：`functions/test/support_account_deletion.test.cjs`、`functions/test/support_account_deletion_http.test.cjs`、`functions/test/support_account_deletion_emulator.test.cjs`、`tools/test_support_account_deletion_operator.cjs`、`tools/test_web_support_deletion.mjs`。
- 既存文書：`PROJECT_STATUS.md`、本書、`docs/release/account_deletion_billing_safety_20261121.md`、`docs/release/web_billing_live_cutover_runbook_ja.md`。

---

## 前工程の記録（2026-11-21時点。以下の「未実装」は当時の状態）

開始点は承認済み `6940aec7ca6d`。今回のページは、ログイン不要の申請窓口を提供するもの。メール送信だけで削除完了にならず、新しい削除APIや運営用実行ツールを実装・配備したものでもない。本番公開・実ユーザー削除・Play Console設定変更は行わない。

## Google Playとの対応

[Google公式のアカウント削除要件](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en) は、アプリ外からの申請経路としてカスタマーサービスメールも認める。削除申請経路が目立ち、ストアと同じアプリ/運営者名が分かり、アプリの再インストールへ戻さず申請できることが条件。申請ページが存在するだけで、関連データ削除・本人確認・処理完了まで運用済みと判断しない。

本番公開後に登録する候補URLは `https://hamster-breeding-app.web.app/account-deletion/`。期限付きPreview URLは登録しない。本番URLの公開・匿名閲覧・メール/コピー・リンク・削除運用の確認後、Play Consoleの対象HamCare→ポリシー/プログラム→アプリのコンテンツ→データセーフティ→データの削除に進み、実装と整合する回答および削除申請URLを登録・保存して確認する。Consoleの名称は変更され得るため、実施時に対象の「データの削除」を確認する。今回この操作はしない。

## 現行機能の監査結果

- `public/assets/account-service.mjs` はFirebase SDKの既存メール/Google/Appleログインを提供し、fresh token claimsと同じUIDのprovider情報を `account-identity.mjs` で確認する。Appleはメールの有無だけで本人と認定せず、Apple provider identityを照合する。画面はマスク済み連絡先・状態を表示し、生のtokenをサポートへ送る設計ではない。
- このログインは、サポートメールの申請者と認証UIDを結び付ける受付票・本人確認確認画面・運営向け検証記録を作らない。申請メールとブラウザのログインが同一人物であることを、運営が安全に確認できる機能は未実装。
- `functions/src/index.ts` の `deleteMyAccountAndData` はFirebase Callableの `req.auth.uid` だけを対象にする。メール本文や任意のclient UIDを指定して運営が他人を削除するAPIではない。署名済みID Tokenを本人からメールで受け取って代行する運用は禁止する。
- `functions/src/accountDeletion.ts` の `runAccountDeletion` はUIDごとの要求・排他・Stripe停止確認・既存削除の再利用を行う内部処理である。安全版はコード/Mock/Emulatorまでの承認記録で、運営者用の受付・承認・実行ツールや本番配備は未完了。
- Firebase ConsoleでAuthだけを削除したり、billingを消したり、停止確認フラグを手入力して通したりすると安全設計を迂回する。サポート削除の方法として採用しない。

## メール受付と本人確認案

### 今回公開する申請方法

窓口は `gotainu@gmail.com`、件名は `【HamCare】アカウント削除申請`。ログイン、アプリ再インストール、登録メールからの送信、個人の実メールの提出を申請条件にしない。Apple非公開リレーアドレスや、Authメール未設定の利用者も、本人が受信できる連絡先から申し出られる。

初回メールでは削除を希望する旨と、必要に応じて普段のログイン方法だけで受け付ける。パスワード・Apple/Google等の確認コード・Firebase ID Token・authorization codeは要求しない。氏名/住所/カード情報等の不要な個人情報も集めない。メール本文を受け取っただけで削除・解約済みと返信しない。

### 確認できたことにしてはいけない資料

送信元メール、署名、ニックネーム、ペット名、画面のスクリーンショット、申告されたFirebase UID、利用履歴に関する回答だけでは、認証済み所有者であることの証明にならない。UIDは対象識別子であって秘密の認証情報ではない。メール文字列で別UIDを統合したり、特定したUIDへデータ移行したりしない。

### 必要な最小追加対応（今回は未実装）

1. 運営が受付番号を作り、返信用の本人確認リンクを送る。リンクは短期限・1回限りのopaqueな申請参照だけを含み、UID・メール・ID TokenをURLへ入れない。
2. 利用者が既存のHamCare Web認証を行い、ログイン済みの同一UIDで、その申請の削除意思と、有料契約があれば停止・残期間利用終了の条件を明示確認する。認証情報や確認コードをメールに貼らせない。
3. サーバー側で認証UIDと申請番号を結び付けた確認記録を作り、運営がそれを読めるようにする。任意UIDを本文/フォームから信用しない。確認リンクの盗用・使い回し・他UIDへの利用を拒否する。
4. 運営者のアクセス制限・操作記録・対象確認を備えた最小の実行経路で、既存 `runAccountDeletion` を再利用する。前工程のStripe停止・再試行・削除フェンス・データ/Auth削除を迂回せず、`ok:true`だけを完了とする。今回新規実行API/runnerは作成しない。

メール/Google/Appleの全方式で同じFirebase UID正本の確認を使う。AuthメールがないApple利用者にもApple認証で対応し、連絡用メールとFirebase契約UIDを同一視しない。Appleリレーへの実配送は既存残件で、届かなければ本人の希望する受信可能な連絡先を案内するが、個人実メールの提出を必須にしない。

元の認証手段へアクセスできない場合の回復・例外本人確認は、現行機能だけでは安全に完結できると確認していない。必要最小限の証拠・目的・保持を別途定め、確認できるまで破壊的操作を行わない。アプリ再インストールを本人確認の必須条件にしない。

## 削除・保持の説明と実装根拠

| 区分 | 現行コードでの扱い | 公開表示上の注意 |
|---|---|---|
| Auth、プロフィール、ペット、飼育/温湿度/AI/通知/体験等のユーザー配下データ | `deleteDocumentDeep(users/{uid})` とAuth削除を再利用 | 本人確認・安全な処理完了後の対象として説明する |
| SwitchBotの既存保存領域 | `switchbot_users/{uid}` 配下を再帰削除 | 外部SwitchBotアカウント自体の削除とは言わない |
| 補完連絡先 | 本人 `billing_contacts/{uid}` を削除 | Stripeの会計記録と区別する |
| ペット画像 | 固定 `hamster_images/{uid}-main_pet.jpg` を削除、404許容 | Storageの全bucket/全バックアップを消すとは言わない |
| Stripe Customer/Subscription/Invoice/支払履歴 | 会計記録を一括削除しない。継続請求停止を照合してからAuthを削除 | 保存が必要な取引情報を保持する場合と理由を記載する |
| 削除フェンス、課金対応/Session情報、Webhook receipt、通知outbox | トップレベル情報を一括削除しない | 不正利用・復活防止・請求照合・障害/紛争対応用記録として保持の可能性を説明 |
| Preview独立連絡先/challenge・外部メール/ログ/分析/バックアップ | 既存再帰削除だけで全て消えると確認していない | 全件・即時・完全削除、固定期間後の自動削除を保証しない |

根拠は `public/privacy/index.html` §6、`functions/src/index.ts` の `deleteData`、`accountDeletion.ts`、`webBillingWebhookStore.ts`、`billingNotificationStore.ts`。内部管理情報や会計記録の具体的な保存期間、外部委託先への削除要求、Preview残存情報の手順は公開前に運営方針と法務表示を整合する。未確定の保存日数を作らない。

## Apple失効成功後にStripe停止が失敗した場合

現行の承認済み処理は、削除確認→同一UID Apple再認証→code即時失効→既存CallableのStripe停止→データ/Auth削除。Apple OAuth失効そのものをFirebase Auth削除・アカウント削除完了とは扱わない。

- Callable受信前に中断した場合、削除要求はまだサーバーへ保存されていない。同じFirebaseセッションがあれば本人が再試行する。再ログインが必要な場合は、元と同じAppleアカウント/連携を使い同じFirebase UIDであることを確認する。違うUIDを自動統合/移行しない。
- Callable受信後、Stripe停止未確認ならAuthを削除せず、永続要求がretryable/manual_review等に残る。worker/運営確認で既存要求を再開する。Apple codeを保存・再利用せず、必要なら新たな再認証か手動解除案内を用いる。
- `billingStopped=true`後のFirebase削除失敗は、停止済みの証跡を保持して既存cleanupを再試行する。新規課金・再キャンセル・UID変更で回避しない。
- **実機E2Eは未確認**。失効直後もFirebaseセッションが維持されるか、同じAppleアカウントの再ログインで同じFirebase UIDへ復帰するか、未完了要求へ再開できるかは専用アカウントの事前承認後に検証する。既存Mockの合格を実Appleでの確認としない。今回は削除コードを変更しない。
- Webメール経由でApple tokenを取得できない場合も削除を不当に拒否せず、本人確認後のデータ削除とApple設定からの手動解除を案内する。[Apple TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple)

## 公開前の残件

ページ実装・Preview確認と、本人確認/削除実行を運用できる状態を分ける。正式な受付返信・処理状況/完了通知・合理的な対応目安、上記ticketと認証UIDの結合、運営用の安全な実行経路、本番安全版の配備、手動確認案件の監視、保存/削除方針の整合、専用Apple失効失敗E2Eが未完了。これらを運用済みと表示しない。

Google Playへは、本人確認・処理運用と本番公開の準備後に正式URLを登録する。今回はPreviewの申請窓口と説明を準備する段階であり、Google Play審査への適合承認を保証しない。

## 今回の実装・Preview確認

- 既存 `/account-deletion/` の古い「登録メールから申請」「先にPortalで解約」を更新。現行outlineロゴ、星空、すりガラス、既存のbrand/landing tokensを使用する。新規API/認証/保存を追加しない。
- 公開窓口、件名入りmailto、コピーbutton、aria-liveの成功/失敗表示、メールアプリが開かない場合の手動コピーを用意。本文へアカウント情報を自動埋込みせず、メールを送信していない。Apple Relay/Authメール未設定でも受信可能な連絡先から申請可能。新規購入/Portal/価格CTAはページ内にない。
- LPフッターに削除リンクを追加。Privacyの保存/削除節とfooter、Supportの削除案内からも同じパスへ到達するようsourceを更新した。Privacy/Supportの改定案をPreviewへ広く公開せず、新ページは既存canonical live法務ページへリンクする。これらのsource改定は今回live未反映。
- 既存 `firebase.preview.json` とAuth CSPを不変とし、Hostingだけの `firebase.account-deletion-preview.json` で同じchannelへ削除ページだけ追加。Functions・rewrites・Auth許可ドメイン変更なし。ページCSPはself script/css、connect/form/frame禁止、no-referrer/noindex。
- Preview：[削除申請ページ](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account-deletion/)。channel `web-first-task1`、version `037676ed8b90b69f`、期限 **2026-11-28 21:48 JST**。本番liveは開始前後とも `2365135bf558c278` でreleaseも同一。
- 配信10リソースHTTP200・ローカルSHA一致。Previewの対象外Privacy/Support/Terms/非公開provenanceは404を維持し、ページ内のcanonical live Privacy/Support/Terms3URLはHTTP200。新ページのCSP/no-referrer/noindexを実HTTPで確認。
- CUAの新規IABでログインなしの実Previewを確認。CSS viewport 360/390px、本文16px、横スクロールなし、copy操作の成功status、44px以上のcopy/mail領域、LPフッター→新ページを確認。console error/warnなし。メールソフト起動・実メール送信・実ユーザー認証・削除は行わない。Viewport overrideを戻し、ローカルHTTP serverも停止した。
- 確認画像は今回作成のartifact `artifacts/web-account-deletion-20261121/preview-mobile.jpg` に保存（worktree外、個人データなし）。物理iPhone/Androidの実機確認とは区別する。

## 試験結果と差分境界

- NodeのWeb pure試験14ファイル **454/454件PASS**。今回のページ/コピー8件とPreview/導線3件を含む。メール件名、JSなしのmailto/表示アドレス、clipboard拒否/非対応、二重クリック、非認証・非保存、秘密情報なし、購入誘導なしを確認。
- LP静的 **86/86 PASS**、brand静的 **178/178 PASS**。既存のbrand構造固定試験には今回必要なfooterリンク1個だけを厳密例外として加え、それ以外の構造・ロゴ・背景・機能要素の保護を維持した。
- 旧 `check_web_account.py` は **168/171**。3件は既承認のサーバーApple policyの共通モジュール化・`functions/src/index.ts`変更と古い固定文字列/旧commit比較が整合しない既存監査条件。今回変更していない `preview-functions/src/auth-policy.ts`、`functions/src/index.ts`、監査scriptが対象であることを開始HEADとの比較で確認。認証/削除処理やこの旧監査を、本タスクで書き換えて合格扱いにしない。旧監査の更新は別途残件。
- Flutter/Functions/Stripe/既存Auth/Firestore Rules/Storage Rules/SDK/lock/mainを変更しない。本番Firestore・Stripe・契約・Auth/Storage書込み0、ユーザー削除0、Play Console/Apple設定変更0、live Hosting公開0。Previewだけを1回配備。専用branchの今回差分だけを指定の1コミットへ保存する。
