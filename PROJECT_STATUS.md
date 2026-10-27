# Hamster Care プロジェクト状況

最終更新: 2026-10-27

このファイルを、開発進捗・優先順位・重要判断の**正本**とします。日常の更新はこのファイルへ記録し、変更履歴はGitで管理します。従来のExcel管理表は2026-09-06時点の履歴スナップショットとして保存し、今後は原則更新しません。

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

- フェーズ: 日本限定・iOS／Android同時公開準備。`REL-02`のPlay Alphaは本人承認の既存14変更を2026-10-27 11:09 JSTに審査送信。審査結果未確定（審査中・審査通過は未確認）／Alpha配信未確認（審査通過後の配信待ち）と分ける。通常登録・カードなし0円契約・通常権限同期・Android有料gate・審査アクセス保存PASS、`REL-03`の既存実機／Play更新／DeviceCheck PASSは維持し再実施しない。旧Case22954972のscope外回答を受け、本人承認のApp Review新問い合わせを2026-10-27 11:46:34 JSTに送信。受付公式完了画面と11:48:45 JST受信の受付メールで番号一致を確認／新Case103009817213、決済判断は回答待ち。
- 最優先タスク: `REL-02`。本人承認のAlpha code2・日本・既存本人1名と共通掲載／申告の14変更は審査送信済み。Consoleの審査結果・Alpha配信状態と、本人承認で送信したApple App Review新問い合わせの回答を待ち、実際の指摘／回答に限定して対応する。12人／14日や一般公開へ自動的に昇格したとは扱わず、新招待・実AI・再build・既存成功テストの再実施は行わない。通常権限・有限AI枠・履歴と普段使い52ab端末を保持する。
- ブランチ: `main`
- ブランド基準コミット: `f972be0 feat: refresh hamster brand mark`
- 完了範囲: iOSの恒久ビルド環境・元workspaceの手動⌘R・実機起動・Releaseホーム起動／ログイン保持、通常版のAppleサインインとGoogle実認証・再起動保持、通常権限での21日体験開始と旧版・最新両版の文字AI回答（本人報告）、Android同署名上書き／Home・ログイン・既存記録保持。
- 公開状況: 同意対応AAB1.0.1／code2はPlay upload・既存本人1名の内部配布PASS、Alpha code2差替えと10/27差分保存後、本人承認の既存14変更を2026-10-27 11:09 JSTに審査送信。審査結果未確定（審査中・審査通過は未確認）／Alpha配信未確認（審査通過後の配信待ち）。指定iOS IPAも10/26 9:50デリバリ・本人承認の輸出回答保存・本人1名のTestFlight内部TestingまでPASS。iOSのTestFlight更新・Home／ログイン／既存記録保持は本人PASS。同意Dialog表示・取消・入力保持と設定の撤回項目表示は本人PASS。Androidは既存52ab証明書のローカルReleaseへ削除なし上書き・起動PASS、本人のHome・ログイン・記録保持と設定項目表示もPASS。独立VMでPlay署名code1→code2更新と本人のHome・ログイン／記録保持はPASS。普段使い52ab端末の署名移行は未実施で、削除や鍵変更で回避しない。Release DeviceCheckはサーバー計測PASS。App Store基本設定・App Privacy確定・Play申告保存も維持。App Store一般審査・Production一般公開は未実施。
- 文書の扱い: 日付別節は当時の経緯・証拠として保持し、後続で解消した旧OS待ち・旧AI拒否・旧APK未導入を現在の残件へ戻さない。MATOMEは全体図、進捗の正本は本書。

## 次に着手する作業

1. `REL-02`：既存Alpha code2・日本・本人1名、掲載素材／申告、カードなし0円通常契約・通常権限同期・Android有料gate・Console審査アクセス準備は完了。本人承認を受け、既存14変更を2026-10-27 11:09 JSTに審査送信。次の依存は審査結果未確定（審査中・審査通過は未確認）／Alpha配信未確認（審査通過後の配信待ち）の確認。12人／14日の製品版条件は別途未達で、既存内部配布・参加状態をやり直さない。Apple決済判断保留と既存通常権限を維持する。
2. `REL-03`／`SEC-03`：Google本人OAuth→HamCare復帰→Home→再起動保持は現Releaseで本人PASS。DeviceCheckは登録・Release指定に加え、TestFlight更新時刻の交換HTTP200と対象iOS AppIDのVALID検証を組み合わせたサーバー計測で実動作PASS。個体SDK callback・token・expiryの直接観測は行っていない。既存AI／Apple／Google認証の再実行は不要。残る公開対象操作は既存回答・履歴で確認しAIを再送しない。
3. `REL-02`／`ANL-01`：App Privacy10typeのPublished、Play掲載／Data Safety差分保存、公開Privacyの1path改訂に加え、通常文字AI同意の局所実装・限定26件は完了。未確認を理由に再開発・実AI再送しない。Playのアイコン／feature graphic／4枚の画像と掲載・Privacyは10/27に保存済みを確認。審査用アクセスも保存・再読取PASS。本人承認後11:09 JSTに14変更を送信し、現在は送信ID1が審査中。iOSの必要素材は今回の対象外。
4. `REL-02`：同意対応最終AAB／IPAの生成・署名検証、両ストアupload／本人内部配布、Alpha code2保存は完了。Play14変更は2026-10-27 11:09 JSTに送信済みで、送信ID1は審査中。iOS TestFlight更新・Home／ログイン／記録保持と同意説明／取消／設定項目は本人PASS。Androidローカル更新の本人PASSに加え、独立VMの実Play code1→code2更新・署名／導入元／UID保持・本人Home／ログイン／記録保持もPASS。普段使い52ab端末は維持。Release DeviceCheckサーバー計測PASSも再実施せず、実同意承諾／撤回・AI再送は追加しない。
5. `RAG-02`／`REL-03`：既存回答の動画タイトル／画像表示、外部動画を開いてHamCareへ戻る操作はiOS／Android両方で本人PASS。最新両版AI各1件も完了済みで、RAG／動画確認は再実施しない。Release DeviceCheckも上記2のサーバー計測でPASS。個体SDK callbackの直接未観測を新AI送信で補おうとしない。
6. `REL-02`：旧Apple Case22954972は10/27に代替配信／決済担当から当該窓口のscope外との回答を受領。これはStripe導線の可否回答ではない。本人承認の指定文面で、公式 https://developer.apple.com/contact/app-store/ から実窓口「App Review → App Review に関するその他のお問い合わせ → Eメール（公式フォーム）」を選び、2026-10-27 11:46:34 JSTにApp Review宛て新問い合わせを送信。受付結果公式完了画面と11:48:45 JST受信の受付メールで番号一致を確認、新Case ID103009817213。回答は未受領で、A／B導線・Stripe維持条件の判断は回答待ち。 独断でIAP／Billing実装・購入導線変更・同文問い合わせ再送・App Store審査提出を行わない。
7. `DES-01`：対象3項目の初版範囲は確定。既存RAGを採用し、AI-02反復検索・BETA-01専用権限を初版へ追加しない。旧要求・未実装差分は履歴／将来検討として残すが、今回の公開阻害条件に戻さない。通常体験の期限・利用履歴・有限予算を変更しない。
8. 公開後対応の `AVT-06`・`ANL-01`一般イベント確認、非阻害 `OPS-03`／`OPS-04`、iPadは別工程。その他の既存公開対象確認は[提出直前の実機確認](docs/release/privacy_disclosure_checklist_ja.md#提出直前の実機確認)の未確認範囲だけとし、全体再監査・全テスト再実行へ広げない。

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
| `REL-02` | 進行中・Play Alpha審査結果／決済導線回答待ち | 日本限定・Stripe決済のままストア初回提出 | 同意実装・最終成果物・既存配布／更新・通常権限と審査アクセス準備PASSを維持。本人承認のAlpha code2／日本／本人1名と共通掲載／申告の14変更を2026-10-27 11:09 JSTに審査送信。審査結果未確定（審査中・審査通過は未確認）／Alpha配信未確認（審査通過後の配信待ち）、製品版12人／14日は別判定。旧Case22954972はscope外回答。本人承認のApp Review新問い合わせを2026-10-27 11:46:34 JSTに送信し、受付公式完了画面と11:48:45 JST受信の受付メールで番号一致を確認／新Case103009817213、決済導線の可否回答待ち |
| `REL-03` | 進行中・E2E最終確認待ち | 提出候補版のE2E確認とクラッシュ監視 | 既存AI各1件・認証保持・動画PASSと同意限定26件は再実施しない。両ストア内部配布済み。iOSの本人TestFlight更新・Home／ログイン／記録保持はPASS、同意Dialog表示・取消・入力保持と設定の撤回項目表示も本人PASS。実同意承諾／実AI再送は未実施。Androidの同一署名ローカルRelease上書き／起動はPASS、本人のHome・ログイン・記録保持と設定項目表示もPASS。独立VMのPlay code1→code2更新・導入元／署名／UID保持と本人Home・ログイン／記録保持もPASS。普段使い52ab端末の移行は未実施。DeviceCheckは更新時刻の交換成功＋対象AppID VALID等を照合したサーバー計測でPASS（個体callback直接未観測）。既存アプリ・通常権限・履歴保持 |
| `VAL-01` | 未着手 | 有料ベータで継続利用を検証 | ストア配布経路の準備後 |
| `AVT-06` | 進行中・非阻害 | 残りのアバター素材 | 初回公開後でも可 |
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
- 2026-09-12時点で、Google Playの掲載情報、コンテンツ申告、クローズドテスト用リリース作成まで完了しているが、品質改善を優先して審査送信を保留する。
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
