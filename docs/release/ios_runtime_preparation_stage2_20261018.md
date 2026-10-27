# HamCare iOS公開準備・第2工程（2026-10-18）

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

後続確認：App ID／Sign in with Apple／Profile整合の確認に加え、通常版iPhoneのメール・Appleサインインは本人確認済み。Xcode27.1／恒久Flutter3.47.7で元ワークスペースの⌘Rと同署名Releaseの導入が成功し、ReleaseのHome起動・ログイン保持もPASS。旧hardware support不足は解消済み。[署名・実機結果](ios_signing_physical_auth_20261018.md)を参照。Google実認証・アプリ復帰・Home・終了／再起動後の保持は現Releaseで本人PASS。最新iOS Release／Android更新版の通常AI各1件は本人完了報告を受領し、再送しない。

## 結果と変更範囲

現在：iOS環境統一・実機起動・Release通常起動は完了。同意対応版のTestFlight内部配布と、本人のTestFlight更新後のHome・ログイン・記録保持は10/26にPASS。実機の同意説明表示・キャンセル後の入力保持は本人確認PASS。設定の撤回項目表示も本人確認PASS。確認ダイアログ開閉・取消は未確認、実同意承諾・保存済み同意の実撤回は未実施。Appleサインインの成功とReleaseでのログイン保持は確認範囲を分ける。10/25のAndroid更新・本人記録保持PASSは履歴として保持。10/26は固定AAB由来の同既存署名APKをローカル上書きして起動PASS後、再ログインなしのHome・既存記録保持と設定撤回項目の表示も本人確認PASS。Play署名配布版への移行は未解決で、別Android実機での確認が残る。過去の最新版両端末のAI各1件は本人完了報告を維持し、再送しない。Release DeviceCheckはサーバー計測による実動作PASSで、個体SDK callback／token／期限の直接観測とは分ける。以下のSimulator結果は10/18時点の履歴であり、最新実機の未達条件ではない。

既存Xcode 16.2／iOS 18.3 Simulatorで、メール新規登録・再ログイン、Home、クイック記録、記録画面、保存済み架空レポートと画面遷移を確認し、終了コード0でPASS。GoogleのネイティブSDK初期化もPASS。新XcodeでのビルドはmacOS更新待ち、Google／Appleの実プロバイダ認証は未確認として分離する。

Stripe、課金権限、Paywall、購入導線、Apple IAP／Google Play Billing、本番Functions／Firestore／Stripe設定は変更しない。決済方式に関するApple問い合わせはユーザーが進め、本工程では送信しない。

## XcodeとMac

現在の使用環境：macOS27.0.1は本人報告（今回再照会なし）、Xcode27.1／SDK27.1、恒久Flutter3.47.7／Dart3.13.5。旧SDKを上書きせずに統一済み。以下は10/18の旧環境・当時の更新案で、OS更新やXcode導入を再び残件にしない。

- MacはApple M1 Pro搭載のMacBook Pro 14-inch（2021、MacBookPro18,3）、メモリ16GB。macOSは14.8.9、既存Xcodeは16.2、iOS SDKは18.2。
- このモデルはmacOS Sequoia／Tahoe対応。Mac本体の非対応が原因ではなく、現在のOSがXcode 26の要件を満たさない。[Appleのモデル識別](https://support.apple.com/en-us/108052)、[Sequoia互換性](https://support.apple.com/en-us/120282)、[Tahoe互換性](https://support.apple.com/en-us/122867)
- Xcode 26.0〜26.3はmacOS 15.6以降、26.4.1〜26.6はmacOS 26.2以降が必要。macOSを更新せずにXcode 26環境で検証することはできないため、OS／Xcodeの導入は行っていない。グローバルのXcode選択も変更しない。[Xcode要件](https://developer.apple.com/xcode/system-requirements)
- 前工程で未署名iOS Debug／ReleaseはPASS。本工程の新Xcodeでのビルドは**OS更新待ち・未確認**。既存XcodeでのSimulator結果と混同しない。
- 既存Flutter 3.32.8／Dart 3.8.1をXcode 26対応済みとはしない。公式の全面対応表明はFlutter 3.38にあり、更新後は候補Flutterを隔離して既存依存との組合せを検証する。今回Flutterや通常プロジェクトのDart依存を更新しない。[Flutter 3.38](https://flutter.dev/blog/whats-new-in-flutter-3-38)
- UIScene対応はFlutter 3.38から追加、3.41で標準化されている。Xcode 26への切替だけで直ちに必須とは記録しない。将来移行する場合はAppDelegate、プラグイン登録、認証URL復帰、通知等へ影響を絞って検証する。[UIScene移行ガイド](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate)

ユーザーが必要とする操作：バックアップと十分な空き容量を確保し、「システム設定 → 一般 → ソフトウェアアップデート」で対応macOSへ更新する。その後、公式配布元からOSに対応するXcode 26以降を導入する。今回の検証開始時の空きは約20GiBで、大きな追加ダウンロードはしていない。新環境ではまず隔離コピーでビルドする。

## Firebase／iOS認証

現在：メール／パスワードとAppleの通常版実機ログインは本人確認済み。Googleは現Releaseで本人実OAuth→復帰→Home→再起動後保持までPASS。下表は10/18の到達点を保存したもので、Apple全体を未確認へ戻さない。Apple削除時のtoken取消は別確認。Release DeviceCheckはサーバー計測による実動作PASSで、個体SDK callback等の直接未観測は別の限界として保持する。

既存プロジェクト`hamster-breeding-app`を読み取り、Bundle ID `com.gotainu.hamster`、FirebaseのiOS App ID、Google SDK設定の対応を照合した。初回API参照は割当先ヘッダー不足で403だったが、既存プロジェクトをリクエストの割当先へ指定して参照できた。権限、認証情報、プロバイダ設定は変更していない。

| 項目 | 設定・準備 | 動作判定 |
| --- | --- | --- |
| メール／パスワード | Firebase側で有効、passwordRequired=true。既存UI／Auth SDKを使用する。 | ローカルEmulatorで新規登録／再ログイン・同一UID復帰PASS。実メール配信／本番の認証完了は未確認。 |
| Google | Firebase側で有効。最新の既存iOS SDK設定にはCLIENT_ID／REVERSED_CLIENT_IDが存在し、旧ローカルplistだけが不足していた。正規の既存IDを同期し、Info.plistへGIDClientIDと対応URL Schemeを追加した。新しいOAuth clientやsecretを作成しない。 | ネイティブSDK初期化PASS。実アカウントでのGoogle OAuthとURL復帰は未実施。 |
| Apple | Firebase側で有効。既存Runner.entitlementsのSign in with Appleと全ビルド構成のCODE_SIGN_ENTITLEMENTSを確認。ネイティブAppleAuthProviderの既存実装を維持する。 | Developer側App ID／profileと実プロバイダ認証は未確認。 |

Googleの変更は`ios/Runner/GoogleService-Info.plist`と`ios/Runner/Info.plist`だけ。既存APIキー、Firebase App ID、Bundle ID、通知設定、権限文言等を変更しない。[Google Sign-In iOSプラグイン設定](https://pub.dev/packages/google_sign_in_ios)

AppleのService ID／Team ID／秘密鍵等がAPI応答にないことだけで、通常のAppleネイティブログインを設定不良と断定しない。Appleプラットフォーム限定のネイティブ認証には空欄でよい構成がある。[FirebaseのApple認証](https://firebase.google.com/docs/auth/cpp/apple)、[FlutterのApple provider](https://firebase.google.com/docs/auth/flutter/federated-auth#apple)

通常ログインとは別に、アカウント削除時のAppleトークン取消は公開前の確認項目。Web／Android用Service IDや秘密鍵を、今回のログイン検証だけのために新設していない。[Firebaseのトークン取消](https://firebase.google.com/docs/auth/ios/apple#token_revocation)

## Simulator検証条件

- 既存端末を使用・消去せず、専用のiPhone 16／iOS 18.3 Simulator「HamCare-iOS-stage2」を作成した。
- 本番の通常main()は直接起動せず、隔離したFlutter Integration Testから既存MyApp／AuthGate／画面を起動する。通常ソースには検証専用の起動変更を反映しない。
- SimulatorのネイティブplistとDart設定も含め、Firebase Appは`demo-hamcare-ios-stage2`だけ。Auth 127.0.0.1:19099、Firestore :18080、Storage :19199、Functionsの既定／東京instanceは:15001へ固定する。Functionsサーバーは起動せず、保存・AI・Stripe操作を実行しない。RAG_API_BASE_URLも未起動の127.0.0.1:15002へ固定し、実AIへ到達できないようにした。
- Firebase Analyticsのネイティブ収集を無効化し、Dart側でも停止する。FCM自動初期化／登録を止め、App Checkは起動しない。これらはSimulatorコピーだけの設定で、通常アプリの保護を緩和しない。
- メール登録／ログインは実Firebase Auth SDKとローカルAuth Emulatorを通す。新規の架空アカウントだけを使用する。確認メールはローカルEmulatorの処理であり、実メール配信の確認とは区別する。
- Home以降は新しい架空UIDだけにプロフィール、体験権限、既存の完全架空・保存済みレポート等をseedする。画面の表示・遷移検証であり、本番課金権限やAI生成成功を示すものではない。
- ローカルの表示用Rulesを使用しており、本番Rulesの再検証ではない。測定保存やレポート生成の新しいE2Eも行わない。
- ハーネス3ファイルの限定静的解析はNo issues。既存の全テストや前工程の検証は繰り返さない。

| 確認項目 | 結果・対象 |
| --- | --- |
| 起動・認証方法画面 | PASS。実AuthScreenのメール／Google／Apple選択UIを表示。 |
| 新規登録 | PASS。架空メール／パスワードを実UIから入力し、ローカルAuth SDKで作成、初期案内へ遷移。 |
| Home | PASS。既存Tabs／Homeを表示。空データ・初期読込みを含む表示確認で、全サーバー計算結果の検証ではない。 |
| 記録画面 | PASS。「＋」からクイック記録、Drawerから日々の記録画面へ遷移。測定保存はしていない。 |
| うちの子レポート | PASS。既存完全架空fixtureをローカルFirestoreから読み、保存済みレポートを表示。AI生成はしていない。 |
| 戻る・再ログイン | PASS。日本語の実戻るボタンで復帰し、SDK signOut後に実メールログインUIから同UIDでHomeへ戻る。 |

最終実行はビルド43.5秒、シナリオ約21秒でAll tests passed、プロセス終了コード0。7枚のPNGとintegration-results.jsonを保存し、認証方法／記録／レポート等を目視した。

失敗も保持した。初回はiOSがネイティブplistから本番projectを自動初期化し、最初のガードがAuth操作／runAppより前で停止した。Simulator用のネイティブ設定と未使用のDart背景処理設定もdemoへ固定した。次の起動停止は、架空APIキーがiOS SDKの文字数・形式要件を満たさなかったためで、正規の形式の架空値へ修正した。3回目は記録画面まで成功したが、テスト標準の英語Back検索が日本語UIに一致しなかった。検証操作をMaterialLocalizationsの実戻るボタンへ合わせ、アプリのUIやassertを弱めず最終成功した。これらの停止をOS／本番認証の互換性不良とは扱わない。

## 実機で分けて確認する項目

現在の残件は正本の `REL-03` に集約する。指定IPAのデリバリ・暗号回答・内部配布と、本人のTestFlight更新後のHome・ログイン・記録保持は完了として再実施せず、実機の同意説明表示・キャンセル後の入力保持と設定撤回項目の表示も本人確認PASSとして再実施しない。確認ダイアログ開閉・取消は未確認、実同意承諾・保存済み同意の実撤回は未実施と区別し、追加AI送信は行わない。Google認証と、サーバー計測によるRelease DeviceCheck実動作PASSは完了として再実施せず、個体SDK callback等の直接未観測は別扱いとする。公開対象の通知／権限／削除は必要範囲で確認する。Apple通常ログインと署名・起動は完了済み。以下は10/18時点の確認計画（履歴）であり、すべてを未完了として再実行しない。

- 正しいTeam／App ID／provisioning profileを使った署名・起動。
- Googleの実アカウント認証とSafari／認証画面からアプリへの復帰、Firebaseユーザーへの対応。
- Appleアカウントの2FA／iCloud設定を伴う実認証、メール非公開、再ログイン／再認証、削除時のトークン取消。
- リリースのDeviceCheckと本番App Check、APNs／FCM通知、バックグラウンド復帰。Simulatorのローカル表示成功をこれらのPASSへ昇格しない。[Firebase App Check](https://firebase.google.com/docs/app-check/ios/devicecheck-provider)
- 必要に応じてカメラ・録音・写真選択等の権限と端末操作。今回、実AI／Stripe決済は対象外。

## 管理画面操作の確認結果（後続工程反映）

Apple Developerの既存App ID、Sign in with Apple、Primary App ID、新規約同意はユーザー確認済み。追加変更は不要。後続工程でMac内の既存署名証明書・対応Profile・接続iPhone登録も確認した。Firebaseプロバイダの再作成、Profile・秘密鍵の再発行、別Bundle ID作成は不要。

10/18時点では新しいXcode環境での再開待ちだったが、現在は実機起動・Apple通常ログインまで完了済み。当時の実エラーは[署名・実機結果](ios_signing_physical_auth_20261018.md)に記録した。

## 変更・保護・証拠

以下は10/18工程の変更・保護記録。後続の同意実装・成果物生成・内部TestFlight配布は本書先頭と正本の最新記録を参照する。

- 通常プロジェクトのアプリ側変更はiOSのplist 2ファイルだけ。Dart、pubspec.yaml／lock、Podfile／lock、AppDelegate／entitlement、課金画面・ロジックは不変。文書は本書、前工程文書への参照追記、PROJECT_STATUSの追記だけ。
- Simulatorのdemo設定、Analytics／FCM停止、test-only main分岐、SDK integration_test依存、架空fixtureは通常アプリへ反映しない。通常候補には収集停止フラグやATS例外が混入していないことを独立レビューした。
- 開始時299ファイルのhashで既存dirtyを保護し、変更前バイトを保存。Known Goodは触らず、git reset／clean／stashなし。ストア申請・本番配備・実AI・Stripe決済なし。
- 設定の読み取り結果、変更前ファイル、通常ソース候補、隔離ハーネス、失敗を含む実行ログ、7画面PNGと結果は`/Users/gota/hamcare-deploy-staging/ios-runtime-preparation-20261018/`へ保存。トークンや秘密鍵は保存・出力しない。
