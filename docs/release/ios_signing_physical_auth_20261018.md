# HamCare iOS署名・実機認証準備（2026-10-18）

<!-- hamcare-apple-submit-build6-20261123:start -->
## 2026-11-23 build6内部配信・提出情報保存（実機確認と主要画面取得は本人操作待ち）

- **配信の正本**：`61e1569`で①〜④の実績を記録済み。iOS `1.0.1 (6)`は固定source `54970b2802f8`、既存Bundle/Distribution/Profile/依存lockを使用。Transporter 10:05 JST Delivered/処理完了、既存「本人実機確認」1 Tester/5 Buildsで6 Testing/90日を15:30 JSTに確認。外部配信/新規招待/審査送信なし。本人のiPhone TestFlight更新・ログイン/プロフィール/記録保持・購入/価格/Portal/Web誘導撤去・体験/契約権限の限定確認は依頼中で、配信完了を端末PASSにはしない。
- **現在画面の取得準備**：古いXcode16.2のSimulator GUIはcrashしたため使用せず、Xcode27.1 Device Hubで隔離iPhone16 Pro/iOS18.3.1「HamCare Screenshots Build6」を新規作成。同固定sourceのDebug appを導入してログイン画面へ到達した。既存端末/Simulatorのデータを消去せず、まだログインしていない。審査用情報の本人入力を依頼中。旧ストア画像は現行画面との相違があるため流用せず、現在Screenshot0のまま主要画面の取得を待つ。Simulator結果をiPhone実機/Apple認可失効のPASSへ置き換えない。
- **ASC保存**：1.0.1にbuild6を選択し、Save後6表示/Save disabled/Manual公開を確認。Description/Review Notes/Support/copyright保存済み、電話番号・審査用passwordは本人保存済み。以前のAuth REST検査はブラウザの伏字値を使った無効な検査で、保存済みpassword不正の根拠ではない。実ログインは端末で確認し、追加のpassword REST試行なし。UID/受信先/passwordを本書へ記録しない。
- **ストア申告の到達点**：Primary Lifestyle/Secondaryなしを保存。親制御/年齢確認/自由Web閲覧/UGC/social/chat/位置共有/広告はNo、成熟/性的/暴力/賭博None、Medical Infrequent/Wellness YesでApple算出13+・overrideなしをSaved確認。既存App Privacy10types/Privacy URL Publishedを維持し、音声endpoint非保持の限定再評価根拠は既存Privacyチェックリストを参照。App AccessibilityはGet StartedのままでVoiceOver等の保証未申告。配信地域はJapan Available on App Release/他174地域Notの読取確認だけで変更0。Content Rightsは本人の権利確認依頼中で未保存。
- **境界と残件**：⑤本人実機は本人操作待ち、⑥提出情報は進行中。破棄可能な専用Appleアカウントは「ない」の回答を維持し、既存本人/審査/テスターを削除しない。実Apple失効/失効後の同UID再ログイン・削除再開は未確認。一般購入/一般メールの停止を維持し、この確認工程でコード/Cloud変更なし。Apple Case103009817213は回答済み・事前承認なし・実提出後に審査判断。下段の旧Case回答待ち/旧版状態は履歴であり、この現在地へ戻さない。
<!-- hamcare-apple-submit-build6-20261123:end -->

<!-- hamcare-ui-polish-release5-20261109:start -->
## 2026-11-09 1.0.1／build5（既存本人内部グループTesting・90日）

- **対象と保護**：固定ソースは `402737048c36b0e592475c764fe05a25abf0454b`。既存専用ブランチと成功済みFlutter／Xcode／署名手順を再利用し、dirty／未追跡素材はビルドへ混入させない。アプリID・Bundle ID・署名鍵・依存lock・88アバターを維持。旧code3／build3以前の互換P1は本人の要件変更による非ブロッキングで閉じたまま、部分保存はcode4／build4以降の正規仕様。新たな旧版互換実装、サーバー配備、main merge／push、外部テスター追加・招待・連絡、製品版公開は行わない。Apple Case103009817213の回答待ち／決済判断保留を維持する。
- **修正・限定証拠**：「Ham Care」表記とログイン同様の手書き書体、Home／クイック記録のアバター拡大・背景統一、選択中ペットのhappy完了アバターと黄色いぼかし、体重時期未選択→不明、レポート準備中の選択中ペットアバターを含む。直接関連114件PASS／既存ListTile診断2件FAIL、新規失敗0、ぼかし描画17件PASS、analyze既存57件・新規0を引き継ぐ。今回のストア名原稿の完全一致を含むrelease identity追加確認は6件PASS。完了済みAI／認証／課金／DeviceCheck等の再試験、実AI送信・体験リセットは0。
- **iOS成果物と内部配信**：`1.0.1／build5`、`hamcare-1.0.1-build5-ui-polish-appstore.ipa`（135,534,552bytes、SHA-256 `9e00e9a12c7f706e3b9199367dc9c0a4ef831527d528189c4065cebe1e019cd8`）を既存Distribution署名／App Store Profileで生成・検証PASS。codesign strict／ZIP、get-task-allow=false、88PNG／Caveatの含有・整合を確認済み。同IPAはTransporterで **2026-11-09 11:09 JSTにDelivery完了**、ASC処理完了後のMissing Complianceを確認。本人が従来同値の「Apple OS以外にも標準暗号を使用／独自暗号なし／フランス配布なし」の最終保存を明示承認した後にSaveし、既存 **本人実機確認グループの1 Tester／4 Buildsで1.0.1(5) Testing・90日** を確認した。外部テスター追加・App Store製品版審査提出は0。**端末4→5更新・ログイン／既存データ保持の本人確認は未実施**。
- **表示名と次の操作**：App Store ConnectとGoogle Playの日本語名はいずれも本人指定の `Ham Care` で保存表示を確認済み。既存本人1名向けTestFlightグループのbuild5 Testingを確認したため、iPhoneはTestFlightから削除なしの4→5更新が可能。実際の端末更新・再ログイン不要・既存プロフィール／記録保持は本人報告を受領してから記録する。一般App Store審査・外部テスター追加は行わない。
- **保存先と状態の区別**：成果物と非公開監査は `/Users/gota/hamcare-deploy-staging/pre-optin-release5-20261109/`。AAB／IPAの生成、アップロード、審査送信、テスト配信可能、端末更新・ログイン／データ保持の本人確認を分ける。以下のRC4およびローカルDebug確認は前版・各確認時点の履歴であり、release5の配信済みや実機PASSへ転記しない。
<!-- hamcare-ui-polish-release5-20261109:end -->

<!-- hamcare-rc4-owner-cutover-20261108:start -->
## 2026-11-09 build4内部Testing・iPhone正式更新PASS／旧版互換P1非ブロッキング

本節はRC4工程の現時点記録。以下のbuild3以前の署名・配信・認証・DeviceCheck確認は履歴として維持し、build4の新しい完了証拠へ読み替えない。 旧版互換のリリース要件は11/9の本人決定へ更新し、過去の一斉切替条件を現在のブロッカーへ転用しない。

- **番号・完成成果物**：App Store ConnectのVersion1.0.1／Build Uploadsでbuild4未使用を確認後、恒久Flutter3.47.7／Xcode27.1・通常lib/main.dart・既存Team／Bundle ID／Distribution／Profile・固定lockでArchiveとApp Store配布署名IPAを生成。成果物は `/Users/gota/hamcare-deploy-staging/pre-optin-rc4-20261108/artifacts/hamcare-1.0.1-build4-pre-optin-appstore.ipa`（135,394,372 bytes、SHA-256 `0fd38f47cca2db05db924130d22d33c2aa6198eeb4708f098192a7fbec5711e0`）。署名、88枚PNG、manifest、固定RCコード／lockとの整合を確認しPASS。旧成果物を保持する。
- **アップロード・内部テスト**：指定IPAをTransporterで送信し、2026-11-08 21:28 JSTにDelivery Completeを確認。App Store Connectの処理完了後、本人の追加承認に従って従来と同値の輸出申告を保存し、既存の本人向けInternalグループへbuild4と確認メモを保存。Internal1名／3 Buildsの一覧で `1.0.1（4）Testing` を目視確認（非公開証拠 `/private/tmp/hamcare-build4-internal-testing.jpg`）。外部テスター0を維持し、App Store製品版審査には未提出。本人がTestFlightから1.0.1（4）へ正式更新し、再ログインなしのHome表示・既存プロフィール・飼育記録保持を確認しPASS。今回の限定UI結果は次項と区別し、新部分保存の実機確認は未実施として残す。
- **iPhone正式更新・保持**：iPhone17eのTestFlight build3→build4更新は本人操作・回答でPASS。再ログインなしのHome・既存プロフィール・記録保持を確認した。Debug／ローカル署名版による上書き・削除・データ消去は行わない。consumer反映後の旧版通常完全入力PASSと、新版更新保持PASSを区別する。
- **iPhone限定UI結果**：本人がbuild4のタスク1ドロワー名・タスク2分析準備カード・タスク3クイック記録について「3点問題なし」と回答し、表示確認PASS。タスク4は前後空白を付けた「RC4確認」を保存し、設定内表示とアプリ終了後の再起動保持を本人確認しPASS。追加のニックネーム変更・解除は本人が不要と指定し未実施。Firestore格納値のtrimは直接実測しておらず、既存unit／UIテストの証拠と区別する。タスク5の部分保存8ケースは未実施。
- **候補の固定と作業環境**：承認済みタスク1〜5・日付跨ぎ修正・UIテスト更新を維持し、P1の計画的一斉切替条件だけを独立コミットしたリリース候補は `f5f09c2b65536022f0d75e140de757610b691ef2`。`/private/tmp/hamcare-pre-optin-rc-20261108` をこのSHAから作成し、開始時clean・HEAD一致を確認。元のdirty作業ツリーはビルド／デプロイ元にせず、固定SDK・既存署名・ID・lockと安全なローカル設定注入を再利用する。既存フォーム文書差分・iOSローカル設定・未追跡素材は保持する。
- **サーバー反映済み範囲**：対象consumer7件（healthWeightRecordWritten／healthDistanceRecordWritten／healthDailyCheckinWritten／healthEnvironmentHistoryWritten／healthEnvironmentLatestWritten／rebuildMyHealthArchitecture／personalityDailyReports）を先に反映。旧iPhone build3と既存Play専用AVD code3の通常完全入力について、保存・再読込・Silver／Gold・Home・既存AI文脈・関連ログを確認しPASS。その後、入力受付saveDailyCheckinを旧 `savedailycheckin-00001-zuv` から新 `savedailycheckin-00002-gim` へ限定反映し、traffic100%を確認。writer反映後も旧Play専用AVDの完全入力で互換ゲートPASS。全Functionsの一括反映、数値専用経路等の追加、実AI送信は行わない。
- **部分保存の仕様と確認範囲**：code4／build4以降の部分保存を正規仕様とする。本番の新部分記録0件は11/8 22:04:56 JSTのmetadata照合時点の結果で、現在件数の再照会は行わない。個別の部分保存8ケース・新部分に対するRaw／Silver／Gold／AI文脈／通知の実測は未実施のまま区別する。本人の正常ログイン・記録・動作確認を受領したことを、これら全ケースのPASSへ読み替えない。旧版の全環境切替や完全後方互換を追加のリリース条件にはしない。
- **旧環境と新規導入方針**：Samsung SM-S911Nの削除前アプリはローカル署名1.0.1／code2でPlay配布署名と非互換。11/8は本人終了・主process0で維持していたが、11/9に本人がこのローカル版1件の削除を追加許可した。未同期の端末内データ・ログイン状態を失い再ログインが必要になることを説明済みで、08:37 JSTにモデル／installedProfiles[0]を確認しcom.gotainu.hamsterだけをADB公式uninstall、Success／pm path消失を確認。従来の削除禁止はこの1件に限り解除し、クラウドの飼育記録・体験・利用権限の削除／リセット、新APK生成・署名変更は0。Play版code4の新規導入後、正常ログイン・記録・動作に問題なしと11/9本人確認PASS。新規導入を上書き更新・ログイン保持PASSとは扱わない。他の保存AVD2台は非稼働、保存Simulatorは全Shutdown、Play専用AVDの正式3→4更新保持は未確認。iPhoneはTestFlight build4へ正式更新・保持確認PASS。旧版互換をリリース要件から外す本人決定により、全旧環境の一斉更新確認はP1のブロッカーではない。
- **本人限定・公開境界**：Play Alphaは日本のみ・既存リスト本人1名、TestFlightは既存の本人向け内部1名を維持。外部応募者約15名は未登録・未招待・参加案内／メール未送信。本人決定により外部案内対象はcode4のみとするが、今回招待・メール送信・対象拡大は実施しない。製品版変更・一般公開・App Store製品版審査は0。Apple Case103009817213の回答待ち／決済判断保留を維持する。
- **証拠と確認範囲**：既存の非公開staging `pre-optin-rc4-20261108/audit/` のserver/deploy-results、server/test-user-metadata、device-inventory-before-code4.json、old-readers-closed-readonly-check.jsonを参照。メール・UID・資格情報・私的本文は本書へ転記しない。SamsungのPlay新規導入後の利用は11/9本人PASSとして記録し、AVDの旧版更新保持や部分8ケースをPASSへ読み替えない。本人の成功判断と旧版互換を要件外にする決定を引き継ぎ、P1を理由に追加実装・手動確認を要求しない。mainへのmerge／pushや新build／uploadは今回行わない。

本人が不要と指定した追加手動確認は依頼しない。iPhoneの正式build4更新・データ保持と限定UI、AndroidのPlay code4新規導入後の正常ログイン・記録・動作は本人確認済み。個別の部分保存8ケース等を全実機PASSへ読み替えず、旧code3／build3以前の互換は今回のリリース要件外としてP1を非ブロッキングで閉じる。App Store製品版審査・外部テスターへの拡大・mainへのmerge／pushは今回行わない。
- **審査待ち間の旧AVD停止**：11/8 22:09 JSTに専用AVDの旧HamCare code3だけをforce-stopし、主process0／package stopped=trueを確認。userdata・既存ログイン／記録・Playアプリは削除／変更せず保持。配信後の正式更新確認まで旧アプリを起動しない。Samsungの本人終了・他AVD／Simulator停止と区別して記録し、正式Android更新や部分保存PASSを意味しない。
- **停止前の入力版照合**：11/8 22:04:56 JST開始の承認済みmetadata再照合で、新partial／未回答marker／condition:nullは全対象0、全走査件数一致。本文・UID・メール保存0、データ変更0。
- **11/9の導入状況・本人確認**：Samsungローカル版は本人の追加許可で08:37 JSTに削除済み。公式Play Webの遠隔導入はGoogle再本人確認前で未成立のため中止し、本人スマホの公式Playページからの導入を案内した。その後、本人から正常ログイン・記録・動作に問題なしとの報告を受領し、Play code4の新規導入後の利用を本人確認PASSとする。これは旧code3→code4の上書き更新・ログイン保持試験ではない。AVDは公式PlayのUpdateを1回選択したが、最終読取の08:49 JST時点はcode3であり、正式3→4更新保持は未確認のまま。追加の手動確認や再テストは要求しない。
- **2026-11-09の確定方針・P1クローズ**：本人は旧code3／build3以前を実運用しておらず重要なユーザーデータもないとして、旧版後方互換性を今回のリリース要件から外した。新しい部分保存をcode4／build4以降の正規仕様とし、P1の旧クライアント誤読は要件変更に基づく非ブロッキングとして閉じる。コード上の完全後方互換を実装・検証した意味ではない。旧版互換の追加実装・二段階配布・強制更新機構は不要。外部テスターへの案内対象はcode4のみで、今回の方針決定自体では招待・メール送信・対象拡大を実施しない。以下の過去の一斉切替ゲートより本決定を優先する。
- **表示調整完了（ソースのみ）**：端末のAndroid／iOSアプリ表示名・Flutter title・ドロワー名を「Ham Care」へ統一。Home本体のアバターを190→224px、分析準備を108→128px（compact88→104px）、クイック記録3画像を44→58pxに拡大した。クイック記録は既存52px枠で軽微な見切れを許容し、Resolver／状態対応／fallback／タップ動作は維持。既存関連テスト66件PASS、実Widget合成描画4件（320／390px・明暗）PASS、Drawerとクイック記録の実Widget描画も目視確認。端末でこの表示変更を確認したという意味ではない。flutter analyzeはmain基準と同じ既存57件（新規0）、git diff --check・iOS plist形式PASS。過去の固定fontによるGolden全体再実行・期待画像更新は行わない。描画・ログは `/private/tmp/hamcare-display-polish-20261109/` と同名接頭辞のログへ保存。配信済みcode4／build4・署名・成果物・版番号は変更せず、新ビルド／upload／配信、main merge／pushは行っていない。次回配布で表示修正を取り込む場合は、新しい未使用build番号を使用し、配信済み4を差し替えない。
<!-- hamcare-rc4-owner-cutover-20261108:end -->

## 2026-11-01 TestFlight build3内部配信（本人1名・Testing）

指定のhamcare-1.0.1-build3-avatars88-appstore-20261101.ipa（前回SHA841aeee9…2076f、再生成／再署名なし）を既存Transporterから送信。Transporter表示11/1 17:44デリバリ成功、ASC既存App6826783734で1.0.1(3)処理完了を確認した。前版と同じ標準暗号（OS外TLSを含む）・独自暗号なし・フランス配布なしを保存し、Missing Complianceを解消。新契約・署名・権限変更なし。

既存「本人実機確認」Internal Groupは1Tester、設定Manual for Xcode Builds。外部テスターや別グループの追加なしでbuild3を追加し、1Tester／2Builds、build3と旧build2の両方Testingを確認。App Store製品版審査へ送信しない。Apple Case103009817213の回答待ち／決済判断保留も維持。

本人がiPhoneをTestFlightから1.0.1(3)へ削除なし更新し、再ログインなしのHome・既存プロフィール・飼育記録保持をPASS報告。検証用プロフィールでロボロフスキー／パイドを保存→再表示し、白黒アバターと毛色の保持も本人PASS。同じ検証用プロフィールの編集でwhite_faceの代替表示も正常と本人PASS（保存せず元パイド維持）。全8状態の強制切替は未実施としてローカル12PASSと区別。AI／Auth／DeviceCheckを再実施しない。証拠は既存staging/audit/avatar-build3-distribution-20261101/。以下の未upload記載は候補作成時点の履歴。

## 2026-11-01 iOS build3アバター更新候補（配信前の履歴）

標準88枚を統合し、新2色16画像の限定12件・112表示セルと保存再読込・既存プロフィール／white_face欠損fallbackをPASS確認。既存72枚・通常権限・履歴・SDK／署名／固定lockは維持。11/1 15:46 JSTの現在のStore全履歴で番号3が未登録と確認し、pubspecは1.0.1+3へ更新済み。既存成功手順の隔離コピーでローカル候補の生成・署名・整合検証PASS。提出候補は `/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/hamcare-1.0.1-build3-avatars88-appstore-20261101.ipa`。既存Distribution／App Store Profile／Bundle／Team、codesign deep strict／ZIP CRC、get-task-allow=false、Archiveとのコード／資産一致と、元88PNG＝成果物内88PNGの全SHA一致を確認。実際の端末2→3更新は未実施。

今回はupload・審査送信・新配信・端末更新を実施しない。既存Alpha code2／TestFlight build2と完了済み確認は維持。次のupload直前に番号3の競合を再確認し、対象成果物・既存トラック／本人グループ・配信範囲の承認を受ける。画像版2→3の実機保持確認はその後に限定実施し、旧code1→code2 PASSをやり直さない。Apple Case103009817213の回答待ち・決済方針保留も維持する。

2026-10-26時点の履歴：下記10/25生成の指定同意対応IPAを再生成せず使用し、Transporterで9:50のデリバリ成功、App Store Connectで処理後のTestFlight内部配布PASS。輸出申告は本人承認後に「標準暗号（OS外TLSを含む）／独自暗号なし／フランス配布なし」で保存済み。本人のみの内部グループ1テスター／1ビルドがTesting。本人がTestFlightからインストールし、Home表示・ログイン・既存飼育記録の保持をPASS確認。同意説明表示・「送信しない」取消後の入力保持・設定の同意撤回項目表示は本人PASS。設定確認ダイアログの開閉／取消は未確認、実同意承諾・保存済同意の実撤回・同意対応版での新実AIは未実施。Release DeviceCheckはTestFlight更新時刻に対応する交換HTTP200×1・対象iOS AppIDのFirestore VALID412・現登録true／旧falseを照合し、サーバー計測による実動作PASS。端末SDK callback／token／個別有効期限は直接未観測。根拠は正本と既存auditの `asc-owner-internal-build2-testing.png`。以下の生成工程・当時未実施事項は履歴として保持する。

2026-10-25同意対応候補の生成工程（履歴）：通常文字AI同意を局所実装し限定26件PASS後、通常lib/main.dartをXcode27.1／恒久Flutter3.47.7・固定lockで新Release Archiveへビルドし、既存Distribution証明書／App Store ProfileでIPA export PASS。同工程で生成した提出対象は`/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/hamcare-1.0.1-build2-consent-appstore-20261025.ipa`（107,026,058bytes、SHA256 `67a7305d7934adfa0565e1ca6375bd101a16b80dbb274019e4c268483ad8695e`）。Archive ZIPは`/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/Runner-consent-development-archive-20261025.zip`（SHA256 `90ced1a78a539f204e22d29c613ffb60f61a001f8e988d7d90c52c24c529c202`）。codesign strict／ZIP／get-task-allow=false／Apple Default／APNs production／Archiveとのコード・資産一致を確認。前回の同意前IPA／Archiveは以下に履歴として保持する。この生成工程での新資格発行、端末上書き、upload・審査送信・実AIは0。10/25のDeviceCheck限定確認は既存ログ0件、SDK呼出し前のSIGSTOPで中断・resume指定detach済み。10/26の段階別再開結果は下記の診断履歴に記録し、その時点では実attestation未確認だった。後続のTestFlight版サーバー計測によるPASSは下記の限定結果を参照する。App Check強制設定・認証系を変更していない。

2026-10-25同意実装前の配布準備（履歴）：本人作成のApple Distribution証明書と、明示承認した同一Team／App IDのApp Store Profileで、既存Release ArchiveからIPA export PASS（再ビルドなし）。`/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/hamcare-1.0.1-build2-appstore-20261025.ipa`、SHA256 3f2b61b017e93c451b5c96e10447cea82feaea987445cb23665f2c447c2cfd48。get-task-allow=false、Apple／APNs権限、codesign strict／ZIP／元コード・資産一致PASS。証拠は既存audit/appstore-ipa-result-20261025.json。端末上書き／upload／審査送信なし。以下のDevelopment Archiveまでの記載は前段の履歴であり、現在の配布署名待ちへ戻さない。当時の通常AI同意不足は、本書先頭の最新工程で局所実装・限定検証と最終候補再生成まで完了。この配布準備段階ではDeviceCheck実attestationは未確認だった。後続のサーバー計測結果とは分離する。

10/25後続の公開準備（履歴）：既存成功Xcode27.1／恒久Flutter3.47.7・固定lockを隔離再利用し、通常lib/main.dartのRelease Archive PASS。Development署名（get-task-allow=true）であり、この段階ではDistribution export／IPA／uploadは未実施。既存staging `ios-device-runtime-20261019/artifacts/Runner-development-archive-20261025.zip`（157,930,706bytes、SHA256 2c0931038ef0649ec137fd94c32cbd1443336a4389d283c4eac3dec0a1e770ae）、同audit/release-archive-result-20261025.jsonに保存。source／native／locks／SDKは保護し、既存iPhone Releaseを上書きしていない。App Store Connect ID6826783734／1.0.1手動公開・日本のみ・無料・掲載原稿／Privacy URL保存PASS。配布署名・審査は別残件。

2026-10-25文書照合：進捗の正本は[PROJECT_STATUS.md](../../PROJECT_STATUS.md)の「検証済みの状態」「タスク一覧」。本書の10/18実行ログ・当時の判断は履歴として残す。この文書照合段階では環境の再照会・ビルド・実機操作・テスト再実行・本番変更は行っていない。同日後続の限定実行結果は次段落と正本へ追記する。

10/18時点の最小環境の訂正（履歴）：当時の再確認でもMacはmacOS14.8.9／23J631、iPhoneはiOS26.5.1／23F81。Xcode26.3はmacOS Sequoia15.6以降に対応するため、macOS26.2は必須ではない。最低候補はmacOS15.6＋Xcode26.3で、現在のOSでは導入できない。OS更新は承認待ち。26.3で当該iPhoneのvariantをmountできるかは導入後の実検証事項とする。

## 結果

現在：Xcode27.1／恒久Flutter3.47.7で元 `ios/Runner.xcworkspace` のGUI⌘Rによる通常版Debug導入・起動PASS。その後同Bundle／Team／Profile・Apple entitlement・キーチェーン整合のRelease AOTを削除なしで上書きし、本人がHome起動・ログイン保持をPASS確認。メールとAppleサインインは通常版で本人確認済み。Googleの実OAuth・復帰・Homeと終了／再起動保持は現Releaseで本人PASS。以下は10/18当時の署名・接続結果。

Apple Developer側のApp ID `com.gotainu.hamster`、Sign in with Apple有効、Primary App ID、新規約同意はユーザー確認済み。Developer管理画面の追加変更やProfile再発行は実施していない。

Macの既存開発証明書・Appleログイン対応Profile・接続iPhoneの登録は整合する。Xcode表示用のCapability metadataだけを通常候補へ追加する。通常版と隔離probeの署名付きReleaseビルドは終了0、成果物の署名／Apple entitlement／実Profile照合もPASS。

実機のApple／Google承認とFirebase最終ログインは**未実施**。開発者モードを有効にしても、Xcode16.2の実機サポートにiPhone17eのvariantがなく、実機操作が停止した。公式の実機サポート部品更新を1回実施し成功したが、再確認でも同じエラーが残った。macOS・Xcode本体の更新、非公式DDI差し替えは行っていない。

## 署名・Entitlements・Profile

| 項目 | 確認結果 |
| --- | --- |
| Bundle ID | Debug／Release／Profileともcom.gotainu.hamster。Firebase iOS設定とも一致。 |
| Team／署名 | 既存Team 3SA77V3SM7、Automatic。Macに有効なApple Development署名IDが1件あり、Profile内の公開証明書と一致。秘密鍵の書き出しなし。 |
| Entitlements | 全構成がRunner/Runner.entitlementsを参照。applesignin=[Default]、APNs development、App AttestはDebug development／Release・Profile production。既存値不変。 |
| 使用可能Profile | iOS Team Provisioning Profile: com.gotainu.hamster。2027-09-24まで有効、Team/App ID一致、Appleログイン権限あり、今回iPhone登録あり。App Attestの両環境を許可。 |
| 古いProfile | Hamster Breeding App DevelopmentにはApple権限なし。同じBundle IDでも、この古いProfileを選ばない。削除や再発行はしない。 |
| Xcode表示 | SystemCapabilitiesにSign in with Appleの表示metadataがなかったため、com.apple.SignInWithApple enabled=1の3行だけ追加。entitlement自体は既存。metadata欠落だけを署名不良の原因とは断定しない。 |

Development Profileによる署名とApp Store配布用署名は別。今回の結果をストア提出・配布Profileの確認完了とは扱わない。

## 接続済みiPhoneとXcode

現在はiPhone17e／iOS26.5.1で実機接続・導入・起動済み。以下のCoreDeviceError12040／MissingVariantとOS更新待ちは10/18の履歴であり、現在の停止理由ではない。macOS27.0.1への更新は本人報告、今回のOS実測はしていない。

- iPhone 17e、iOS26.5.1。Macと有線pairing済み。ユーザーがDeveloper Modeを有効にし、実APIでもenabledを確認した。
- 実機アプリ一覧の取得でCoreDeviceError12040、DDI mountの`kAMDMobileImageMounterPersonalizedBundleMissingVariantError`が発生した。iPhone用variantがないことが具体的な停止理由。
- Apple公式の`xcodebuild -runFirstLaunch -checkForNewerComponents`を選択Xcode16.2に限定して1回実行。Install Succeeded／終了0、DDI更新を確認。以後の接続確認1回も同じMissingVariantだったため、繰返し更新や手動差替えへ広げない。
- SDK18.2という番号だけから新しいiOS実機が使えないと推測していない。Apple資料のdevice supportとSDKの区別、および上記実エラーに基づく。[Xcode16.2公式資料](https://developer.apple.com/documentation/xcode-release-notes/xcode-16_2-release-notes)、[公式実機サポート更新](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components#Download-and-install-new-hardware-support-in-between-Xcode-releases)
- 限定再確認でも現MacはmacOS14.8.9／23J631。最小更新候補のXcode26.3はmacOS Sequoia15.6以降に対応し、同梱SDK26.2と実機Device Support iOS15以降は別の条件。iPhoneのiOS26.5.1だけを理由にSDK26.5／macOS26.2を必須とした前回答は訂正する。現在OSでは26.3を導入できないため、ユーザー承認後のOS更新まで止める。新hardwareの実接続成功は未検証。[Appleの要件表](https://developer.apple.com/xcode/system-requirements)、[Xcode26.3公式資料](https://developer.apple.com/documentation/xcode-release-notes/xcode-26_3-release-notes)

## 本番を書き換えない認証確認

通常のAuthScreenは、新規ユーザーなら同意内容をFirestoreへ保存する。通常MyAppはログイン後に通知トークンを保存し、Homeのcallableが起動する。また新規Firebase Authユーザーは既存登録triggerを発火し得る。したがって今回は通常アプリからの本番ログインを実行しない。

隔離コピーに、本番Firebaseへ接続しない認証専用画面を用意した。Googleは既存GoogleSignInのinitialize／authenticateまで、AppleはAuthenticationServicesのネイティブ承認まで。Firebase credential交換、Firestore、Functions、AI、Stripeは呼び出さない。Google Client ID／URL Scheme、Bundle ID、署名・entitlementは対象アプリと同じ。Firebase接続用plist値はprobeから取り除き、Analytics／FCM自動初期化もprobeだけ無効にした。認証情報の中身・個人情報を独自ログへ出さず、状態／存在booleanだけを画面へ返す。SDK固有の端末内セッション保持とは区別する。

この確認で将来PASSにできる範囲は各プロバイダの承認・アプリ復帰まで。Firebase最終ログインは、通常アプリの自動書込みをどう扱うか決めて別途確認する。今回probeは端末へ入っておらず、各OAuthは未実施。Face ID／パスコード／二段階認証の本人操作が必要になった際だけユーザーへ引き継ぐ。

## 2026-10-26 TestFlight版DeviceCheck：サーバー計測による実動作PASS

現在のTestFlight版 `com.gotainu.hamster`／1.0.1（2）について、本人更新確認10:09:51 JSTと、以下の既存サーバー計測をread-onlyで照合した。SDK前のデバッガ停止をDeviceCheck失敗と扱わず、今回の**最小実動作はサーバー計測に基づくPASS**とする。端末のSDK callback・token・個別有効期限を直接読み取ったPASSとは区別する。

| 根拠 | 実値／確認範囲 |
| --- | --- |
| DeviceCheck交換 | `serviceruntime.googleapis.com/api/request_count`、`google.firebase.appcheck.v1.TokenExchangeService.ExchangeDeviceCheckToken`、HTTP200／grpc0が1件。10:09:07.001〜10:10:07 JSTの区間で、本人TestFlight更新確認と同じ分。照会した同期間にExchangeDebugToken seriesなし |
| 対象アプリの実検証 | `firebaseappcheck.googleapis.com/services/verification_count` を現iOS AppID `1:797691641198:ios:8742688c983e31766b557f` へ限定。Firestoreのsecurity=VALID／result=ALLOWが10:09〜10:31 JSTの12区間、計412件。これはAI利用回数ではない |
| 現iOS登録 | DeviceCheckConfig GETが200、対象name一致、TTL3600s、`privateKeySet=true` |
| 旧iOS登録の切分け | 旧 `com.example.hamsterProject` のConfig GETも200、TTL3600s、`privateKeySet=false`（protobufのfalse既定でfield省略）。旧AppIDの同期間verification seriesは0。旧登録・アプリは削除／変更していない |

交換methodの計測はproject単位でAppID／端末ラベルを持たず、AppID別VALIDはprovider／端末を直接識別しない。そのため、現在TestFlight版の更新分、現アプリの検証成功、現登録true／旧登録falseを組み合わせてRelease経路の実成功を評価した。個体を識別するSDK callback、raw token、token単体のexpiryは未観測のままで、設定TTL3600sを取得tokenの実有効期限とは扱わない。API method計測には最大1800秒の取込遅延があり、412件は照会時点で観測できた件数。監査／RAGログの該当0件を実失敗としたり、過去Debug版のVALIDだけを根拠にしたりしていない。[公式のApp Check計測](https://firebase.google.com/docs/app-check/monitor-metrics)、[計測ラベル](https://docs.cloud.google.com/monitoring/api/metrics_gcp_d_h#firebaseappcheck)、[登録booleanの定義](https://firebase.google.com/docs/reference/appcheck/rest/v1/projects.apps.deviceCheckConfig)。

今回の確認は既存計測・既存登録metadataの読み取りだけ。新しいattach／SDK getToken／forceRefresh／AI／Auth／trial／同意grant・revokeは0。現TestFlight版の上書き・再署名・診断版導入、App Check強制設定・本番ログ設定・認証方式の変更も0。管理API初回403は既存の割当先ヘッダ指定で200へ解消し、登録boolean取得時の一時DNSエラーも同じread-only GETの再試行で解消した。これらをDeviceCheckの失敗とはしない。十分な正の証拠を得た後の追加計測は行わない。

永続証拠は既存 `/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/audit/` の `devicecheck-testflight-readonly-final-20261026.json`（判定・限界・根拠一覧）、`devicecheck-testflight-monitoring-initial-20261026.json`（現AppIDのVALID412）、`devicecheck-testflight-provider-metrics-20261026.json`（DeviceCheck200×1）、`devicecheck-testflight-private-key-set-booleans-20261026.json`（現true／旧false）、`devicecheck-testflight-app-config-quota-header-20261026.json`、`devicecheck-testflight-legacy-app-exclusion-20261026.json`。既存ログ0件・管理API初回403の安全記録も同auditへ保存し、App Checkの生token・秘密鍵・相談本文は取得／保存／表示していない。

## 2026-10-26 Release DeviceCheckの最小実機確認（TestFlight更新前の診断履歴）

既存Development署名Release（通常 `com.gotainu.hamster`、1.0.1／build2）だけを通常起動し、同一アプリの停止metadataとSDK前のデバッガ式を段階別に確認した。再ビルド・再署名・インストール・元コード／認証方式／App Check強制設定の変更は0。端末のRelease・ログイン・データを維持し、診断によるAI／Auth／trialの明示呼出しとApp Check SDK強制取得はすべて0。通常起動に伴う既存バックグラウンド通信まで0とは断定しない。

| 保存時刻（UTC、JSTは＋9時間） | SDK前の確認結果 | 終了状態 |
| --- | --- | --- |
| 10/26 00:18:41 | ObjC++／AllowJIT=falseの純定数 `1+1` とmodule importがPASS。続くAllowJIT=trueのBundle一致booleanも1でPASS。通常StopIDは1のまま、式評価を含むStopIDは1→2 | runningへresume後、後続SDK入力は実行前に止まり、resume指定detach・セッション終了0を確認。SDK取得0 |
| 10/26 00:22:01 | 純定数・module importは再びPASS。同じBundle一致booleanのJIT式が `Expression execution was interrupted: signal SIGSTOP` で中断し、評価前の状態へ巻き戻った。通常StopIDは1のまま、式評価を含むStopIDは1→3 | detach成功・detached。provider読取り／App Check SDK取得へ到達せず0 |

attach直後は両方ともthread 1のSIGSTOP（signal 17）、StopID 1で、既存のsignal policyはstop／notify／suppressがtrue。公開イベントを排出後もpending eventは空で、policyは変更していない。前回10/25のimportとBundleをまとめた式での中断から、今回は純定数・import・Bundleを分け、**確定した停止箇所をApp Check SDK前のデバッガ式実行へ切り分けた**。同じ非SDK JIT式が一度は成功したため、ReleaseのJITが常に禁止される、DeviceCheckが失敗した、未実装である、という結論にはしない。SIGSTOPの発生元・前回中断の根本理由は一意に特定していない。途中の診断scriptの未対応 `SetExecutionPolicy` によるAttributeErrorは端末／SDK失敗と分離し、利用可能APIだけに直してから上表を実行した。

00:55:44 UTC開始の最終限定確認では、本人が既存HamCareを開き、USB・ロック解除・画面点灯を維持した状態で、公式read-onlyのlockStateが `passcodeRequired=false`／`unlockedSinceBoot=true`、既存Release実体と一致するRunnerが1件・PID9221であることを直前照合した。attachコマンド1回はOS側で `Not allowed to attach to process`（consoleのdebugserver理由を参照する案内）と拒否され、安定したstopped状態へ到達しなかった。従って予定したresume→explicit Stop・定数／import／Bundle・provider判定は一切未実行（stagesは空）、SDK取得試行0・callback未作成。LLDB session13616はquit後終了0。接続が確立していないため、この最終試行をdetach成功とは記録しない。**このnative診断の停止点はOSのデバッグ接続許可の拒否であり、先のSIGSTOP式評価中断やCodex自動承認レビュー拒否とは別要因**。拒否の下位原因を未取得のまま端末設定／署名／DeviceCheckの不良へ断定しない。

00:57:08 UTCに追加read-onlyを1回だけ行い、同じ既存Runner実体1件・同PID9221の存続を確認した。公式processesの返却項目は実行ファイルとPIDだけでforeground／background／suspendedは確認できず、displaysの点灯情報からもアプリ前景は断定しない。00:18／00:22当時のlock／foreground記録がないため、過去のSIGSTOPが端末ロックや背景suspendと一致したとは証明できない。最終試行後の追加attach／SDK取得／起動／AI／Authは0。当時の既存Release・データ・設定を維持し、このnative診断の範囲では実attestation未確認だった。後続の既存サーバー計測による判定は前節を参照する。

固定SDK sourceでprovider参照経路は `FIRAppCheck.appCheckCore → GACAppCheck.appCheckProvider → FIRInternalAppCheckProvider.appCheckProvider` と確認したが、実機でのprovider判定・Firebase AppID照合・token取得／有効期限はSDK前の中断により未確認。FirebaseへのDeviceCheck登録とReleaseのDeviceCheck指定は既存確認済みのままで、診断版への上書きやDebug providerへの変更はしていない。

既存ログのread-only照合は10/26 00:12:00 UTC以降を対象に1回、同00:23:23 UTCに実施した。対象は既知のiOS Firebase AppIDと、①Cloud Run `hamster-rag-api` の `Firebase App Check token verified` 行、②`firebaseappcheck.googleapis.com` のDeviceCheck／ExchangeDeviceCheckToken監査行の組合せ。該当0件・権限拒否なし。10/24以降および前回後の既存照合も0件だった。監査ログが記録されない場合を含むため、0件を交換失敗や未実行の証明にはしない。ログ設定は変更していない。

今回の照会にはFunctions callableの検証行を含めていない。限定source照合ではFunctions SDK標準のcallable検証ログは `verifications.app/auth` の状態だけでAppID／providerを出さず、直接関係するFunctions sourceに対象AppIDを追加記録する処理も確認できなかった。従来のDebug版で得たVALIDを現Releaseへ転記しない。通常起動後のHome／Firestore表示成功はmonitor-only運用やcache利用と両立し、翌日であることだけでは実tokenの有効期限切れも証明できない。既存AI成功とReleaseのprovider指定だけから実attestation PASSを推定せず、**このnative診断時点ではRelease DeviceCheck実attestation未確認**だった。後続のサーバー計測PASSは前節の別証拠による。追加AI／認証／強制refreshで証拠を作る試行は行っていない。

証拠は既存staging `ios-device-runtime-20261019/audit/` の `devicecheck-native-staged-20261026-result.json`、`devicecheck-sdk-stage-blocked-20261026.json`、`devicecheck-root-staged-20261026-result.json`、`devicecheck-existing-logs-after-launch-20261026.json`、`devicecheck-sdk-before-jit-comparison-20261026.json`。数値・boolean・停止理由・照合件数だけを保存し、生token・秘密鍵・相談本文は保存／出力していない。00:18の保存JSONはfollowup前のrunning状態であり、その後の安全detachはblocked記録、00:22の安全detachはroot-staged記録を参照する。 最終attach拒否は `devicecheck-final-foreground-20261026-result.json`、親が確認したLLDB拒否・終了状態の安全要約は `devicecheck-final-attach-denial-summary-20261026.json`、その後の同PID存続は `devicecheck-after-attach-denial-process-20261026.json`、00:49のlock／画面点灯・process参考情報は `devicecheck-lock-process-readonly-20261026.json` を参照する。

## 次期アバター更新版build3：既存成功手順と今後の配布操作

11/1は上記のbuild3 Archive／IPA生成まで完了。以下の画像受領前手順中の旧版数＋2／未生成という記述は当時の準備経緯で、現在は＋3・候補完成を正とする。upload以降は未実施。

- 既存1.0.1／build2のTestFlight更新・同意表示／取消・保持・Release DeviceCheckのPASSを維持。次期は`1.0.1／build3`。画像受領前の今は元`pubspec.yaml`の`1.0.1+2`、workspace／署名／iPhoneのReleaseを保持する。画像統合時だけ`1.0.1+3`へ更新し、生成物のCFBundleShortVersionString=1.0.1／CFBundleVersion=3を確認する。
- 本人サインイン後の10/31 TestFlight一覧とAll StatusesのBuild Uploadsを読み取り、Version1.0.1のbuild2のみ（Upload Complete／10/26 9:50）で、build3は未登録・処理中表示なしと確認した。次番号はbuild3と確定。番号は他作業によって消費され得るため、アップロード直前もBuild Uploads／同versionを確認する。
- `assets/avatars/README.md`の受入確認後、恒久Flutter3.47.7・Xcode`/Applications/Xcode_27.1.app`・通常`lib/main.dart`・既存lockを再利用する。`DEVELOPER_DIR=/Applications/Xcode_27.1.app/Contents/Developer`を工程単位で指定し、既存SDKやxcode-selectを変更しない。
- 前回の既存staging `ios-device-runtime-20261019/audit/consent-ios-generation-result-20261025.json`／`consent-ios-archive-command-20261025.json`の環境・引数を再利用する。画像と番号の差分を同期した隔離workspaceで、固定依存の生成／Podsを準備し、Runner／Release／generic iOS・独立DerivedData／SourcePackages・依存の自動更新なしで新Archiveを作る。番号指定だけ3へ変更し、検証用entrypointへ切り替えない。Archive前に隔離workspaceの`ios/Flutter/Generated.xcconfig`を再生成し、`FLUTTER_BUILD_NAME=1.0.1`／`FLUTTER_BUILD_NUMBER=3`／`FLUTTER_TARGET=lib/main.dart`を照合する（生成設定へbuild2を残したままArchiveしない）。
- 新Archiveは必要（旧build2 IPAへ画像を後入れしない）。同Team3SA77V3SM7／com.gotainu.hamsterと既存Apple Distribution／App Store Profileを維持し、前回成功のautomatic exportを使用する。Xcode-managed Profileに不適合だったmanual exportへ戻さず、不要なallowProvisioningUpdates／資格発行・権限変更を行わない。codesign strict、get-task-allow=false、production App Check／APNs、ZIPと追加PNG格納、Archiveとのコード・資産一致を限定確認する。
- 成果物はbuild3と画像更新を示す別名で保存し、build2／既存Archive／監査を上書きしない。ローカル生成後は、対象IPA／既存TestFlight本人向け配布の承認を得てからTransporterへ1回だけ送る。現コードの暗号利用が変わらなければ前回の輸出回答を参照し、確約・新規申告が必要な最終操作はその時点の承認条件に従う。
- ASC App ID6826783734の既存内部グループ「本人実機確認」・本人1名・手動配布を維持し、処理済みbuild3を追加する。外部beta／新招待／App Store一般審査へ広げない。TestFlightから2→3を削除なし更新し、Home・ログイン／既存記録保持と追加アバターのプレビュー／表示のみ確認する。AI・認証・DeviceCheckを再試験せず、体験期限／履歴・残枠を保持する。普段使いReleaseをDebug版で上書きしない。
- Apple Case103009817213は回答待ち。アバター更新準備をIAP適合確定や購入導線変更の根拠にしない。画像受領前の準備時点では新Archive／IPA生成・upload・配布は未実行だった。11/1にローカルArchive／IPA生成だけ完了し、upload・配布は未実施。

## 次の最小作業

現在の次作業は正本 `REL-03` の残件だけとする。指定IPAのTransporterデリバリは10/26 9:50成功、App Store Connect処理後の輸出申告は本人承認を得て「標準暗号（OS外TLSを含む）／独自暗号なし／フランス配布なし」で保存済み。TestFlightは本人のみの内部グループ1テスター／1ビルドがTestingで、upload・内部配布待ちへ戻さない。証拠は `/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/audit/asc-owner-internal-build2-testing.png`。一般公開の審査送信・公開は今回の内部配布と区別する。

本人がTestFlightからインストールし、Home表示・ログイン・既存飼育記録の保持をPASS確認した。端末metadataのBundle `com.gotainu.hamster`／1.0.1（2）は一致。`builtByDeveloper` は更新前後ともtrueのため、そのflagを署名／配布方式の移行証明には使わない。アプリ実体パスの変化と、本人によるデータ・ログイン保持の確認も別の根拠として扱う。同意説明の表示、「送信しない」による取消後の入力保持、正しい設定ルート再案内後の同意撤回項目の表示は本人PASS。設定の確認ダイアログの開閉／キャンセルまでは本人の明言がないため未確認。実同意承諾・保存済同意の実撤回・同意対応版での新実AIは未実施。本人確認の記録は `/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/audit/testflight-consent-owner-ui-final-20261026.json` を参照する。Androidは固定同意AAB由来・同じ既存52ab証明書のローカルRelease APKを削除なし上書きして起動PASS。本人も再ログインなしのHome・既存記録と設定の撤回項目表示を確認PASS。これはPlay署名配布版への移行とは区別し、iOSの説明Dialog／取消の結果をAndroidへ転記しない。本人証拠は既存Android staging/audit/android-local-consent-owner-confirmed-20261026.json。更新後の現アプリ・既存データ・ログインを維持し、従来のGoogle実OAuth・復帰・Home・再起動保持と、同意対応版の配布前に本人確認した両端末の文字AI各1件のPASSを再実施しない。同意対応版で新たにAI送信済みとは扱わない。Release DeviceCheckの最小実動作は、後続のTestFlight版の既存サーバー計測でPASS。前段のOS attach拒否・SDK取得0は診断履歴として残し、端末SDK callback／token／個別有効期限の直接観測とは区別する。今回の根拠を得るための追加attach／SDK取得／AI送信は行わず、同じ確認を再実行する必要はない。必要な削除時token取消の残確認も正本で管理する。

Apple Distribution export・署名検証は生成履歴、実機のDevelopment署名PASSは従来の端末履歴として区別する。SchemeのArchiveActionは既にReleaseで変更不要。App Store Connect規約本人同意、レコード作成・1.0.1手動公開／日本のみ／無料・掲載原稿／Privacy URL保存はPASS済み。以下の1〜4は10/18時点の計画を保存した履歴であり、OS更新・初回導入を再び行う指示ではない。

1. ユーザー承認後、最小候補のmacOS Sequoia15.6以降の対応15.xへ更新する。現在14.8.9はXcode26.3の動作要件を満たさないため。今回OSのdownload／installは行わない。
2. 既存Xcode16.2を保持し、公式配布元のXcode26.3を別名で並行導入する。既存Flutterは置き換えず、隔離コピーとコマンド単位DEVELOPER_DIRで互換性を確認する。このiPhoneのDDI variant取得・mountが通るかは導入後に実測する。
3. 接続iPhoneのDDI mount、アプリ一覧取得が通ることを確認。既存アプリの有無を確認してから検証版を導入し、Apple／Google承認・URL復帰を実施する。通常アプリを無断アンインストール／消去しない。
4. 本番Firebaseまでのログインは、自動データ保存を避ける条件を明確にして実施する。実AI・Stripe決済は不要。

Apple DeveloperでのCapability再設定・証明書再発行・別Bundle ID作成は、現証拠からは不要。既存Profileで足りている。

## 保護と証拠

通常候補はpbxprojの表示metadata 3行＋本書／既存文書・PROJECT_STATUSの追記だけ。probeのmain／AppDelegate／telemetry設定は通常repoへ反映しない。既存dirty、Known Good、課金導線、Stripe権限、本番Functions／Firestore／Stripe設定は維持する。git reset／clean／stash、ストア申請・本番配備・実機インストールは未実施。

最初のsandbox内証明書参照は0件／profile decode不可だったが、読み取り権限を明示した実環境参照で有効1件・Profile一致を確認した。最初のEntitlements読取りで空hashが返った事象も保持し、再読446byte／既存archiveと同hash／cmp／plist lintの一致で解消してから保護対象のbaselineを確定した。

## 署名付きビルドの確定結果

現在の署名付きRelease AOTと実機Home起動は10/24の記録を正とする。下表は10/18の旧Xcode／当時のProfileの証拠であり、配布用署名やGoogle実認証のPASSを示すものではない。

| 対象 | 結果 |
| --- | --- |
| 通常HamCare | Xcode16.2／SDK18.2、Release、Automatic、終了0／BUILD SUCCEEDED。1.0.1+2、arm64、最小iOS15.0。 |
| 隔離認証probe | 同じTeam／App ID／entitlement／AutomaticでRelease終了0／BUILD SUCCEEDED。Dart限定解析もNo issues。 |
| 成果物照合 | 両方codesign deep／strict検証PASS。署名済みapplication-identifier／team／applesignin=[Default]、embedded profile UUID、Apple権限、対象iPhone登録が一致。 |
| 実使用Profile | iOS Team Provisioning Profile: com.gotainu.hamster、UUID 4f2a909f-f3ed-483f-b686-eae8786e50b0、期限2027-09-24。古いProfileではない。 |
| 通常版への混入 | 元main／AppDelegate／通常plistでビルド。Google Client ID／URL Scheme一致、probe用収集停止フラグ・確認画面は含まない。Podfile.lock／Dart lock／既存entitlement不変。 |
| 署名環境 | 開発証明書とDevelopment Profileの署名。APNs development、App Attest entitlement production。実通知／App Check動作やApp Store配布署名のPASSとはしない。 |
| 実機・認証 | アプリ導入・起動・Apple／Google承認は未実施。上記DDI errorによる停止を維持。 |

初回のFlutter build iosはProfile／Teamに関する汎用エラーで停止した。設定を再発行せず、同じAutomatic設定・既存Profileでgeneric iOS destinationのXcodeビルドを実行し、probe／通常版とも成功した。初回の失敗ログは保持し、CLI初回失敗の原因を未確定のまま隠さない。既存Podsの最小OS警告、CocoaPods推奨版警告は残るが、今回の署名ビルドは両方終了0。

証拠・署名済み成果物・実際にコンパイルしたprobe source・変更前ファイル・公式更新前のDDIは`/Users/gota/hamcare-deploy-staging/ios-signing-physical-auth-20261018/`へ保存する。Known Goodの旧成果物は上書きしない。
