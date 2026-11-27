# Hamster Care Google Play登録手順

## 2026-11-27 Android候補の限定確認・公開削除案内の差分反映

以下は、同日12:11までの読み取り記録に続く実施結果である。Apple承認版build6の固定元`54970b2802f8fcc483b336186149bea32baae42d`と同じ共通Flutter改修を再利用し、完了済みの認証・課金・iOS削除E2Eは繰り返していない。**製品版トラックへの正式提出・一般公開は未実施**。AAB/Alpha・製品版アクセス申請の進捗は、既存PROJECT_STATUSとクローズドテスト計画の後続実績に従う。

### Android 1.0.1/code6のビルド・Alpha送信

- 既存code1〜5の使用をConsoleで確認し、未使用code6を採番。Apple承認build6の固定ソース`54970b2802f8`を使用し、`lib/assets/icons`324入力と`pubspec.lock`はbyte一致。Flutter3.47.7/Dart3.13.5、既存Android Studio JBR、Gradle8.14/AGP8.11.1/Kotlin2.2.20/NDK27.0.12077973。既存のcode5成功recipeを隔離stagingで再現した。ネイティブ差分は`android/settings.gradle.kts`（AGP/Kotlin）、`android/gradle/wrapper/gradle-wrapper.properties`（Gradle）、`android/app/build.gradle.kts`（既存Alpha同様min24・隔離unsigned後に既存upload署名）、`android/gradle.properties`（メモリ/worker制限・既存Flutter互換）の4件だけ。repoのアプリコード・lock・署名/Firebase設定は変更していない。
- 正式AABはGit外`/Users/gota/hamcare-deploy-staging/android-strategy-c-20261127/artifacts/hamcare-1.0.1-code6-strategy-c-signed.aab`、172,403,352 bytes、SHA256 `d0e3f3f84a5141168cffb2c8fbd574225fbec7b546416091e3c6eedf14c217f7`。既存upload証明書、manifest（package/1.0.1/6/min24/target36/nonDebug）、JAR署名、Bundletool1.18、ZIP CRC、署名前後の全非署名entry不変、標準88PNG＋既存分析用1PNG、Caveat、旧code5と権限一致を確認。
- Consoleがcode6を解析し、コード/target/API/ABIを表示。リリース名`6 (1.0.1) Strategy C Alpha`、日本語ノート、既存Alpha内100%で保存。既存code5を併記追加せず新code6だけを使用。対応端末の減少/追加は全フォームファクタ0。
- **13:25 JSTに既存Alphaの更新1件だけを送信**。実表示は「審査中の変更」およびクイックチェック残り約14分。送信操作完了と配信完了を分け、code6はまだ選択テスターへ公開済みとしない。管理対象の公開は既存オフを維持し、承認後は既存Alphaへ配信する。製品版トラック・テスター登録/参加・国/地域は変更しない。
- 署名AABと同一内容のupload署名APKも隔離用に生成したが、Play署名と異なるので既存Play code5への上書き・更新保持検証には使用しない。実Android確認は公式Play更新後に行う。元AABの検証記録はGit外stagingの`audit/`、Console送信記録は`/private/tmp/hamcare-android-release-20261127/alpha-code6-submission.txt`/`.jpg`。

### 実インストール版の取り違えと、カレンダー／レポートの限定照合

本人がMacのエミュレータで記録カレンダー・うちの子レポートが見当たらないと指摘したため、他の大規模試験へ広げず、表示中の版と固定ソースを照合した。既存`HamCare_Prelaunch_A_20261004`は**versionName1.0.1／versionCode2、debuggable=true、installSourceなし、署名prefix52ab9f417a100880**。この起動環境へ今回code6をインストールしていない。debug/code2の画面をcode6の画面として扱わず、既存アプリ・データを削除/上書きしない。

| 固定code6の根拠 | 限定結果 |
|---|---|
| `lib/widgets/main_drawer.dart` 131–145、`tabs.dart` 382–410/462–463 | 「記録カレンダー」「うちの子レポート」のDrawer入口、Calendar→DailyStarsScreenとReport遷移、HomeヘッダCalendarが存在 |
| Home/MainDrawer/record_calendar_action/daily_stars/personality_report_entry/child_report_navigation/personality_report_history/personality_reports_repo/analysis_progress_cardの9ファイル | code5 `402737`／code6 `54970`／今回ソースの全byte一致 |
| `personality_report_screen.dart`のcode5→code6差分 | 末尾の購入プランCTAを削除。レポート本体・履歴・入口の撤去ではない |
| 既存表示条件 | Home新着レポート/進捗カードはread errorやデータ状態で非表示になり得る。Drawerの両機能入口には当該条件なし |

今回4コミット・15lib変更から両機能を削除した差分は見つからない。ただし、このソース比較を実配信code6の表示・更新保持PASSに読み替えない。公式Alphaはcode6「審査中。」、code5「選択したテスターに公開されました」の表示を保存した。実更新/認証/保持/削除説明の限定確認はcode6配信後に行い、その前の製品版アクセス最終適用は保留する。本人の「古いかもしれない」という回答を確認成功にしない。

根拠はGit外`/private/tmp/hamcare-android-submission-scope-20261127/calendar-report-source-comparison-safe.json`、staging auditの読み取り端末照合、`/private/tmp/hamcare-android-release-20261127/alpha-code6-under-review.txt`/`.jpg`と`alpha-and-listing-submission.txt`。実アカウント削除・課金・AI送信・体験変更なし。

### 共通Flutterの限定Widget／Mock検証

既存の`strategy_c_navigation_test.dart`、`subscription_usage_screen_test.dart`、`settings_account_deletion_test.dart`から、今回のAndroid差分に直接関係する**7件を実行し、7/7 PASS**。テストや期待値の変更、SDK更新、実アカウントの認証・AI送信・課金・削除は行っていない。

| 確認した条件 | 結果 |
|---|---|
| Home→Drawer→Settings→利用状況が到達可能（light/dark） | 2/2 PASS |
| billing読取エラー時に古い状態を隠し、読取専用で再確認 | 1/1 PASS |
| 復帰時に契約・体験の両streamを再取得し、体験を書き換えない | 1/1 PASS |
| 狭い画面とキーボード表示下でも有料削除説明・確認が操作でき、課金停止同意を送る | 1/1 PASS |
| 削除ボタンの連打で確認・呼出しを重複させない | 1/1 PASS |
| サーバーで契約が判明した場合は追加の有料削除確認を経て再試行 | 1/1 PASS |

これはWidget host／Mockでの限定検証であり、**実Android端末のcode5からの更新保持・起動・認証・実削除E2EのPASSではない**。Android実機での必要な限定確認は別に記録する。既存ListTile debug診断の扱いは既存harnessのままで、検査の無効化や既存失敗のPASSへの読み替えは行っていない。実行ログはGit外`/private/tmp/hamcare-android-submission-scope-20261127/flutter-limited-tests.log`。

### 公開アカウント削除URL：承認済み3ファイルを反映済み

公開URLは`https://hamster-breeding-app.web.app/account-deletion/`を維持。反映前は旧2026-09-12文面で、「登録メールアドレスから」の申請や、撤去済みのアプリ内Portalによる事前解約案内が残っていた。本人の「この3ファイルの公開反映を承認する」という明示承認後、**2026-11-27 13:15:21.190 JST**に次の3ファイルだけをHostingへ反映した。

| 対象 | 操作・固定ソース |
|---|---|
| `/account-deletion/index.html` | 既存1件差替え。`54970b2802f8`の承認済みHTMLをbyte不変で使用 |
| `/assets/account-deletion.css` | 新規1件追加。同じ固定ソースを使用 |
| `/assets/account-deletion.mjs` | 新規1件追加。同じ固定ソースを使用。公開窓口メールのコピーだけを実行 |

- Hostingは`58e5ed12aaa990f6`（49ファイル）→`a2d4e7fbc0e3426a`（51ファイル）。実行前に現version・全map・ServingConfigと既存10重要URLを退避。mergeのMock6/6と直前dry-runを通し、finalize前後・release後に全51mapを照合した。**承認3path以外の既存48hash、ServingConfig/CSP、予約`/__/firebase/init.js`と`init.json`を維持**。共有CSS・正本outline画像・背景・fontは本番と固定ソースが一致しており再配備しない。
- 公開後は新3URLと既存10重要URLがすべてHTTP200、本文hash/CSP一致。復旧は不要だった。問題時は退避元versionへのreleaseで戻せるが、今回は実行していない。source全体の一括Hosting deployは行わない。
- 最新ページは、ログイン・再インストール不要のメール受付、メール未設定Apple/Relayからの申請、後段の本人確認、削除対象と保持情報、継続請求停止確認後の削除を説明する。メール送信だけでは本人確認・削除完了としない。ページとcopy moduleにAuth/API呼出し・新削除フォームはなく、未配備のWeb本人確認APIに依存せず静的受付が成立する。**運営Web本人確認・削除実行経路の本番配備や、その実完了を確認済みとはしない**。
- 今回の本番変更はHostingの公開versionと3ファイル。Functions・Rules/Index・Secret/IAM・Stripe・購入/メールflagの変更0件、実メール・実削除0件、本番Firestore等の業務データ書込み0件。一般購入・一般メール停止、既存契約の正規同期、テスター・体験・利用権限を維持した。実行記録はGit外`/private/tmp/hamcare-deletion-page-overlay-20261127/execution/`。

### 正式提出向けのConsole差分（保存・公開は別承認）

11/27、管理Consoleの日本語デフォルト掲載を読み取り確認。掲載名`Ham Care`、簡単な説明49文字、詳しい説明691文字、既存アイコン/feature graphic、スマートフォン4画像（01_today、03_changes、02_record、04_consultation）は登録済み。画像の撮り直しや変更は行わない。

詳しい説明には旧仕様の「購入前にアプリ内で料金と条件を表示し、解約後も支払済み期間の終了まで利用できます。」が残っており、code6の購入導線撤去と一致しない。この1か所だけを「アプリ内には新規購入・契約管理への案内はありません。契約済みの方は、同じHamCareアカウントで利用できます。解約手続き後も、契約期間が終了するまでは利用できます。」へ置換する733文字の最小原稿をGit外に用意した。公開掲載の修正は当初の「未反映差分の整理」を越えるため、本人へこの1か所のみの保存/反映を確認し、「この掲載文1か所の修正・反映を承認する」と回答を得た。承認後、この733文字を保存・送信した。既存のアプリ名・簡単な説明・4画像・アイコン・feature graphic・既存AIラベル申告は保持。Googleから進行中審査のやり直しが必要と案内されたため、承認済み掲載修正をAlpha更新と合わせて1回送信し直した。公開の概要にはAlpha更新と日本語「詳しい説明を変更」の2変更だけが表示される。審査の再開始は閉鎖テストの終了や新AAB再作成ではない。公開反映完了はまだ未確認。

既存のrepo掲載原稿は月額550円の確定方針へ税抜表現だけを整理済みだが、その戦略C原稿全体をConsoleへ上書きしたとは扱わない。新規のWeb購入CTAやURLを今回追加しない。製品版アクセス承認後に正式提出へ使用するAABは、code6の確認結果と同じ固定成果物を使用する案で、新codeを理由なく再作成しない。

### Data Safety・掲載情報の限定差分

既存の[プライバシー申告チェックリスト](privacy_disclosure_checklist_ja.md)にあるPlay12type保存済み・診断必須への10/27修正を再利用。音声は既に「収集・任意・ephemeral No」に含まれており、現在音声ONのため旧「OFF」説明を現状の根拠にしない。今回の共通Flutter改修は購入導線撤去と安全な削除等で、新SDK/新しい収集typeを追加しない。契約状態・Stripe識別子を引き続き扱うため、購入導線撤去だけを理由にPurchase history/User IDsを削除しない。Appleの音声非収集判断をGoogleへ流用しない。[GoogleのData Safety定義](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)では端末外への一時転送もフォーム上の開示対象となる。

その後、担当rootがConsoleを再読取りし、保存12type、音声=収集yes/共有no/一時的no/任意/アプリ機能yes、購入履歴等の継続を確認した。Privacy/削除URLは現行公開URL、審査用ログイン詳細は登録済み、App content要注意0。**変更・保存は行っていない**。UIの要注意0を実装全体の適合保証や新セッションでのログイン成功へ読み替えない。証跡はGit外`/private/tmp/hamcare-android-release-20261127/data-safety-preview.txt`。

同じ再読取りで、任意申告「アカウント全体を削除せず特定データの削除をリクエストできる=はい」も同じ`/account-deletion/`を使用していることを確認。限定調査では次のように整理した。

- **部分削除機能は存在する**：Settingsの「AI相談履歴を削除」から`AiChatHistoryRepo.deleteAllHistory()`へ進み、認証中の同じUIDのmain messages/archive messages/archives/feedbackを実削除する。Auth/プロフィール/飼育記録/契約は削除しない。`firestore.rules`の当該AI collectionはowner deleteを許可する。相談一覧の「削除」は非表示処理なので、この根拠に混用しない。今回の実操作・本番Rules再配備・実データ削除は0件。
- **公開Privacyにも根拠がある**：6節はAI相談履歴のみの削除、8節は窓口への訂正・削除等の請求を案内している。このため既存の「はい」を直ちに架空申告と判断する根拠はなく、この項目単独でAlpha更新・製品版アクセス準備を止める実装不具合は確認していない。
- **正式提出前の案内差分**：退避済み旧9/12 HTMLにあった「アカウントを残して一部のデータを削除する」（AI履歴・画像の手順）が、今回の承認済み新HTMLには含まれていない。アカウント削除のメール受付は機能するが、同じURLを部分削除入口として使う説明が不十分。最小案はこのページにAI相談履歴のみを削除する既存操作と、アプリを利用できない場合の削除対象を明記したサポート相談を追記すること。アカウント全体の削除と混同させず、未確認の部分削除自動処理や会計記録等の全消去は約束しない。これは**未反映の文面改善案**であり、今回の承認3ファイル反映に追加して公開したとは記録しない。Consoleの回答を無根拠に「いいえ」へ変えたり、新しい削除APIを作ったりしない。

公開Privacy/Support/TermsはHTTP200かつ現行repoと完全一致。メール受付を外部削除導線とする構成と、再インストールを申請条件にしない説明は[Google公式削除要件](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)に基づく。購入導線のない利用形態は[Google公式Payments FAQ](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en)のconsumption-only説明を参照し、アプリ内購入/Portal/Web購入CTAを再導入しない。掲載原稿に残っていた「税込/税抜500円」は正式な「月額550円」への未反映差分として担当へ引き継ぎ、Consoleへの実保存は別に記録する。

## 2026-11-27 現在のAlpha・製品版アクセス・iOS build6との差分（読み取りのみ）

対象`com.gotainu.hamster`。12:11 JSTまでに既存Dashboard/Alpha/テスター数/製品版/Bundle Explorerを読み取った。この読み取り時点では申請・保存・新リリース・AAB作成/配信・一般公開を実行していない。以下は当該確認時点の状態であり、同日後続の実施記録と区別する。旧11/9のAlpha未送信・旧11/21の実装待ちは当時の記録として保持する。

| 確認項目 | 現在確認できた状態 |
|---|---|
| 実opt-in | 少なくとも12人。Dashboardの12人以上opt-inタスク完了。今回確認した画面に正確な現在人数は非表示であり、正確な人数は未確認 |
| 12人以上・14日以上 | 両タスク完了（Console判定）。各人の継続日数や達成日を推定しない |
| 製品版アクセス申請可否 | 「本番環境へのアクセスを申請」ボタン有効。今回は押さない |
| 申請・承認 | 製品版画面は「製品版へのアクセスがまだありません」。申請中/承認済み表示なし、アクセス未付与。過去の申請履歴全体を調査済みとはしない |
| 現Alpha | 有効、日本1か国、`5 (1.0.1) UI polish Alpha`、選択テスターに公開。Alpha画面の公開時刻は11/9 20:10 |
| 配信バンドル | `5.aab (1.0.1)`、versionCode5、versionName1.0.1、artifactId`4860249410283073647`、minSdk24/targetSdk36 |
| Android固定元 | `402737048c36b0e592475c764fe05a25abf0454b` |
| iOS承認版固定元 | `54970b2802f8fcc483b336186149bea32baae42d`、1.0.1(6)。11/24 16:19 JST承認メール受領は本人報告。手動公開/一般公開保留 |

Alpha用許可リスト27人、internal-testers1人は配信対象リストの登録数であり、実opt-in28人とは扱わない。重複除外済みの総数でもない。招待・メール送信済み人数やインストール数を実opt-inへ代用しない。

Android AABの既存記録は`hamcare-1.0.1-code5-ui-polish-signed.aab`、172,392,335 bytes、SHA256 `49d8019de8d3cf44bdd09c72515cc95d9908d5cc5bb58aeb276042617f651171`。既存固定入力manifest/署名/88PNG/lock一致の結果を再利用し、今回再build・再署名・再テストは行わない。11/9内部track code5公開と、当時のAlpha未送信は別の履歴で、本日のAlpha公開実読を現在値とする。

### iOS build6までの共通Flutter改修の反映状況

`4027370`→`54970b2`の共通Flutter差分は15ファイル、次の4コミット。`android/`・`ios/`・assets/icons・pubspec/lock差分は0であり、今回の共通差分を取り込むためのSDK更新は不要。

| 機能 | 既存の導入コミット・主な対象 | 現Alpha code5 |
|---|---|---|
| 購入CTA/価格/Checkout/Web誘導撤去 | `d23820c42c4b`。利用状況画面、PaidFeatureGate/Guard、Settings/Tabs/レポート/クイック記録等 | 未反映 |
| Customer Portal入口撤去 | `6e85a3c25640`。Settings/利用状況画面 | 未反映 |
| 復帰時の契約状態再取得・再確認 | `d23820c42c4b`。同UIDのstream再購読、利用状況の読取専用UI/再確認 | 追加改善は未反映。元のBillingStatusRepo/model・21日体験読取は両版で同一 |
| Stripe停止を含む有料削除の画面接続 | `e1fe0524dbb9`。settings/account_delete_service/account_deletion_guard | clientの課金停止説明/同意flag/長時間処理・再試行表示は未反映 |
| Apple連携ユーザーの削除処理 | `6940aec7ca6d`。apple_account_deletion_service/settings | 未反映。自動失効APIはiOS/macOS限定、AndroidのApple連携ユーザーは手動解除案内。非Appleユーザーに再認証を要求しない |

共有本番の`deleteMyAccountAndData`/`retryAccountDeletions`は11/23に`54970b2`から配備済み。旧Androidも同じCallableを呼ぶので、サーバーのStripe照合・停止確認・排他・fence/retryは適用される。ただし旧clientは`stopBillingConfirmed`を送らず、該当有料契約では`paid_confirmation_required`で削除を安全停止する。したがって「backend済み＝Android有料削除フロー済み」とせず、無料ユーザーの既存処理と区別する。今回有料契約・削除・権限・テスターを変更していない。

### Android正式候補へ残る作業（今回未実行）

1. 上記実装済み共通改修を含むソースを固定し、Playの使用済みversionCodeを照合して新番号を決定する。6を未使用と決めつけない。
2. 既存署名/Bundle ID/lockを再利用してAABを作成し、source/署名/manifestを照合する。共通コードの再実装や既存全E2Eのやり直しは不要。
3. 後続のテスト配信でAndroidに関係する更新保持、購入/価格/Portal/Web誘導なし、復帰時状態再取得、削除説明・同意・再試行表示を限定確認する。実削除が必要なら破棄承認済みの専用UIDに限定する。iOSのApple失効失敗後再開はMock-onlyという残件を実機PASSへ変えない。
4. 掲載/画像/Data safety/公開Web削除URL/審査用情報・戦略C説明を候補AABの差分に合わせて確認する。現code5のConsoleにedge-to-edge注意表示があるため後続Android表示確認へ含めるが、今回新たな不具合確定/修正/SDK更新はしない。
5. 条件達成と製品版アクセス付与を分離し、テスト内容/フィードバック/公開準備の申請回答を用意する。本人承認後にアクセス申請し、承認後に正式提出・一般公開を別判断で進める。Appleの今回build承認をGoogleの承認へ代用しない。

証拠はGit外`/private/tmp/hamcare-release-state-20261127/`のsafe JSONと4画面。確認URL：[Dashboard](https://play.google.com/console/u/0/developers/7040110575286467511/app/4976014731630589144/app-dashboard)、[Alpha](https://play.google.com/console/u/0/developers/7040110575286467511/app/4976014731630589144/tracks/4700032976627342279)、[製品版](https://play.google.com/console/u/0/developers/7040110575286467511/app/4976014731630589144/tracks/production)。今回は読み取りと既存文書の更新だけで、一般購入/一般メール停止、既存の正規同期・無料体験・テスター権限を維持する。

## 2026-11-21 残存方針の確定（未提出・未配備）

価格は月額550円、返金は「利用者都合による支払済み料金の返金は原則として行いません。ただし、重複課金、当方のシステムによる誤請求、その他法令上返金が必要となる場合は個別に対応します。」に確定。期間末解約・期限まで利用・次回請求停止・日割りなしを返金と分離する。特商法は請求開示方式、窓口は既存Gmail、VOは不要。認証はFirebase、重要な契約/サポート通知はGmail APIを初回採用するが、本番通知は未実装。Relay実配送未確認は非ブロッキング。旧Live500円と既存契約は保持、新550円Priceは別承認後の新規申込だけへ。

今回、公開前Web文面/表示文字列と文書を整合した。掲載用txt、配信中アプリ、ストア設定、Live Stripe/Hostingは未変更。戦略C版は未提出で、既存Play Alphaの提出配信履歴とは区別する。現在の状態と次の工程は [本番切替Runbook](web_billing_live_cutover_runbook_ja.md) を正本とし、下記の旧候補・税務待ち・メール未選定・Relay待ちの条件は現在の判断にしない。


<!-- hamcare-pricing-play-gate-20261119:start -->
## 2026-11-21時点の提出ゲート（履歴）：戦略C草案・提出不可

本手順書の以下の節は作業当時の記録を含みます。今回の変更は公開前文面の整合だけで、Google Play Consoleへの保存・審査送信・既存Alpha更新・一般公開を行いません。

- 正式商品名は**HamCare プレミアム**、**月額550円**。1か月ごとの自動更新で、実際の契約の請求周期に従います。年額・割引・クーポンは追加しません。
- 将来版草案は、ユーザーが**アプリ外のHamCare公式Webで申込を開始し、アプリは同じアカウントの既存利用権限を利用する**構成です。現在配信中のFlutterには旧500円表示・有料登録ボタン・外部Checkoutへの購入CTAが現存します。**購入CTA撤去待ちのため、現時点でこの草案を提出できません。**
- 無料体験21日・AI相談最大20回、テスター権限、既存Customer／Subscription、本番500円Price参照は保持します。アプリ単独の体験終了だけで自動課金しません。Web申込は既存体験の終了日時を使い、未開始／終了済みは即時550円とする方針です。体験の追加・延長・リセットをしません。
- 解約は公式Webの契約管理から期間末に行う構成です。解約手続き後も、現在の契約期間が終了するまではHamCareプレミアムをご利用いただけます。根拠のない解約期限を作らず、返金条件は法務文言の本人確認後に確定します。
- 提出前に、購入CTA撤去後の配布候補・スクリーンショット・掲載原稿・審査説明・Google Playの適用要件を再照合します。原稿は未提出であり、要件適合・審査承認・ストア反映を確認済みとはしません。公開、Live価格切替、アプリ更新、提出は別承認です。
- Apple Case22954972は旧窓口のscope外回答。Case103009817213は**回答済み：事前承認なし。実提出後に審査判断**。Appleの回答をGoogle Playの許可や両ストアの審査合格へ読み替えません。

現在の公開用原稿と未提出状態は `store_assets/metadata/README.md`、Apple向け将来草案は `store_review_notes_ja.md` を参照します。以下の旧500円、Apple回答待ち、アプリ内購入導線の記載は履歴として保持します。

**11月21日の方針更新**：正式表示はPreview／本番Web／Stripe Test／Stripe Live／利用規約／特商法で「月額550円」に統一し、Stripeの最終請求額550円を正本とします。旧Live500円Priceと既存契約は保持し、別途承認後の本番切替で新Live550円Priceを作成して新規申込だけを接続します。Test Price550円は維持します。申告・納税上の扱いは別のバックオフィス事項で、料金表示やリリースの判断条件にしません。

今回は文書上の方針だけを更新し、HTML/JavaScriptや掲載用txtは変更していません。手元の画面・txtに残る旧税込/税抜表記は、後続の表示反映でこの新方針へ揃える必要があります。原稿へ反映済み・ストアへ提出可能とは記録しません。
<!-- hamcare-pricing-play-gate-20261119:end -->

## 旧手順・実施履歴（以下の状態は各記録時点のものです）

<!-- hamcare-billing-contact-20261119:start -->
## 2026-11-19 Preview連絡先確認：公開前の確認項目

- 確認済み通常メール(A)／確認済みApple Relay両ドメイン(B)は追加入力なし。Auth/provider双方にメールがない(C)だけ独立連絡先を確認し、新規Preview申込前にverified必須。未確認／不正メールをCに読み替えない。個人の実メールは必須にしない。
- 正本はFirebase UID。`preview_billing_contacts/{uid}` と専用送信枠だけを使用し、Auth・本番billing・契約・体験を更新しない。原本の直接clientアクセスは現Rulesで拒否、状態は認証済み本人向けHTTP投影。別Rulesファイルは未配備の候補。
- Preview限定の管理Gmail送信を本人承認。新送信専用OAuth/`gmail.send`のみ、UID/宛先各1件許可リスト、5回/日/人・全体10回/日。個人Gmailを本番自動送信へ採用しない。15分・一度限り・ハッシュ保存・固定fragment URL・別UID拒否・CSRF・再送抑止を検証。
- 新規Customerへ確認済み連絡先は渡せるが、既存Customerメールの自動置換なし。UID所有者と既存Portal管理は維持。未確認Cを新規購入させず、既存契約の管理を閉鎖しない。
- 自動backend514/frontend443/Emulator68、静的LP84/account171/brand177 PASS。本人Appleメールなし→管理Gmailへ確認メール1通→本人確認→サーバーverified/used hash1→月額550円の契約確認→戻るを実ChromeでPASS。本番4文書/Auth email/provider不変、Stripe書込み0。本人Relay宛先なしのためRelay実配送は未確認。2026-11-19の本人回答「両方とも表示・入力に問題なし」により、iPhone Safari／Android Chromeでの連絡先画面の文字切れ・横はみ出し・キーボードによる隠れは本人確認PASS。実機寸法・OS版・画像は未採取で、追加の決済／Portal検証とは区別する。詳細は戦略Cリリース記録の同日節へ。
- 公開前に本番送信基盤・Relay配送・法務料金550円整合を確認。VoiceOver専用追加開発は初回公開非ブロッキング、Apple Caseは「回答済み：事前承認なし。実提出後に審査判断」を維持する。公開・本番課金切替は別承認。
<!-- hamcare-billing-contact-20261119:end -->

<!-- hamcare-private-relay-audit-20261116:start -->
## 2026-11-16 Apple Private Email Relay：送信元2件登録済み／配送は本人用宛先待ち

- **方針の保存**：`0d761c3f1876`（`docs(release): record contact email and accessibility policy`）で、指定4文書だけを保存。旧一時worktreeが存在しなかったため、コミット済み `f66f019052ad` と同じ専用ブランチから `/private/tmp/hamcare-web-relay-20261116` を復元し、失われた未コミット差分そのものを回収済みとはせず、本人の確定指示から方針を反映した。元アプリのdirty／未追跡素材は作業対象外。
- **Apple登録の実結果**：本人の確定直前承認後、個別送信元 `noreply@hamster-breeding-app.firebaseapp.com` と `gotainu@gmail.com` の2件を登録。`Email Source Registration Complete` の2アドレス／0ドメインと、その後の一覧で両方の緑SPFチェックを確認。初回はセッション期限切れで未登録、再読込後に同じ承認済み2件だけを登録した。`gmail.com`／`stripe.com`等の第三者ドメイン全体、未使用ドメインは登録せず、既存登録の削除・App ID／Service ID／Key・DNS変更0。
- **配送を止めた理由**：本人から「今はない」と回答があり、本人所有のAppleリレー配送先がない。前回のApple E2EはAuthメール未設定であり、Relayありのユーザーと混同しない。Firebase／サポート／Stripeの今回メール送信は0通、転送・迷惑メール・返信・バウンスは未検証で、配送PASS・バウンスなしとは記録しない。他ユーザー、新規本番アカウント、架空のRelay宛先、Appleへのパスワード方式追加で代替しない。
- **コード・限定検証**：両Relayドメインは現行の表示／認証設計で受理可能。`account-model.mjs:maskEmail`／`checkout-model.mjs:projectCheckoutReview` に旧ドメインだけのallowlistはなく、`account-identity.mjs:projectAccountIdentity`／`auth-policy.ts:authorizePreviewIdentity` は署名検証済みFirebase UIDと現在Apple provider subject一致を正本にする。`privaterelay.appleid.com`／`private.icloud.com`各4項目（表示・review、正規Apple、別UID拒否、binding欠損拒否）の合成8チェックPASS。既存account-model／account-identity／checkout-model計82件PASS。既存Node22を使用しSDK・依存更新0、コード差分0。ドメインだけでメール確認済み・認証済みとは判定しない。
- **保護・Preview**：既存Preview `/account/` HTTP200／no-storeを確認し、デプロイ0。今回本番Stripe／Customer／Subscription／Firestore billing／既存契約／Authユーザー／体験／テスター権限の変更0、Stripe Test書込み0、Flutter／live Hosting／購入CTA／main merge・push・ストア操作0。Apple送信元登録だけが外部設定変更。メール未設定の本人Preview購入ガード・UID正本は保持。
- **判断・次工程**：送信元登録は完了、実配送は未完了で本番公開前の残件。連絡用メール補完フローの設計・独立Preview実装へは別承認で進められるが、今回実装しない。VoiceOver追加対応は非ブロッキングのまま。実配送を未確認のまま本番切替準備完了／公開可とは判断しない。詳細な送信元・代替設計・根拠は[戦略Cリリース記録](japan_store_payment_and_ios_readiness_20261018.md#relay-sender-inventory-20261116)を参照。
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

<!-- hamcare-ui-polish-release5-20261109:start -->
## 2026-11-09 1.0.1／code5 UI polish Alpha（本人操作後も受付未確認・未送信2変更）

- **対象と保護**：固定ソースは `402737048c36b0e592475c764fe05a25abf0454b`。既存専用ブランチと成功済みFlutter／Xcode／署名手順を再利用し、dirty／未追跡素材はビルドへ混入させない。アプリID・Bundle ID・署名鍵・依存lock・88アバターを維持。旧code3／build3以前の互換P1は本人の要件変更による非ブロッキングで閉じたまま、部分保存はcode4／build4以降の正規仕様。新たな旧版互換実装、サーバー配備、main merge／push、外部テスター追加・招待・連絡、製品版公開は行わない。Apple Case103009817213の回答待ち／決済判断保留を維持する。
- **修正・限定証拠**：「Ham Care」表記とログイン同様の手書き書体、Home／クイック記録のアバター拡大・背景統一、選択中ペットのhappy完了アバターと黄色いぼかし、体重時期未選択→不明、レポート準備中の選択中ペットアバターを含む。直接関連114件PASS／既存ListTile診断2件FAIL、新規失敗0、ぼかし描画17件PASS、analyze既存57件・新規0を引き継ぐ。今回のストア名原稿の完全一致を含むrelease identity追加確認は6件PASS。完了済みAI／認証／課金／DeviceCheck等の再試験、実AI送信・体験リセットは0。
- **Android成果物とAlpha最終送信待ち**：`1.0.1／code5`、`hamcare-1.0.1-code5-ui-polish-signed.aab`（172,392,335bytes、SHA-256 `49d8019de8d3cf44bdd09c72515cc95d9908d5cc5bb58aeb276042617f651171`）を生成・既存upload署名検証済み。88PNG／Caveatの含有と整合PASS。既存Alphaの `5 (1.0.1) UI polish Alpha` へ同AABをアップロードして保存済み、日本のみ・既存internal-testers本人1名を再読確認。掲載名を含む最終2変更について、自動操作での最終確認に加え、本人から「押した」との回答を受領。その後、公開の概要と送信履歴を読込み完了後に再読したが、Consoleは **未送信2変更**、送信履歴はID1〜3だけのまま。新しい送信ID・送信受付日時・送信成功は未確認。エラー表示はなく、**本人操作後も受付未確認・原因未特定** と記録する。残る操作はConsole受付の再確認と、承認済み2変更の送信のみ。**審査送信済み・審査中・code5のAlpha公開・端末更新PASSとは扱わない。**
- **ストア表示名**：本人の追加指定により両ストアの掲載名原稿を正確に `Ham Care` へ同期し、既存のtitle／name txtと掲載情報文書を更新。App Store ConnectとGoogle Playの日本語名はいずれも `Ham Care` で保存した表示を確認済み。Playは本人操作後も掲載名を含む2変更が未送信で、送信受付は未確認・原因未特定。保存と審査送信・公開反映を区別する。iOS build5の内部Testingは、App Store製品版の公開を意味しない。説明本文・画像・課金方式・IDは変更しない。
- **残る操作**：Consoleの送信受付を再確認し、未受付であれば承認済み2変更を送信する。本人の確定操作は既に受領しており、追加の本人クリック待ちとは扱わない。現在は未送信2件・履歴ID1〜3、新送信ID／受付日時は未確認・原因未特定。送信成功・審査中・Alpha公開は実際の受付と表示が確認できてから記録する。
- **保存先と状態の区別**：成果物と非公開監査は `/Users/gota/hamcare-deploy-staging/pre-optin-release5-20261109/`。AAB／IPAの生成、アップロード、審査送信、テスト配信可能、端末更新・ログイン／データ保持の本人確認を分ける。以下のRC4およびローカルDebug確認は前版・各確認時点の履歴であり、release5の配信済みや実機PASSへ転記しない。
<!-- hamcare-ui-polish-release5-20261109:end -->

<!-- hamcare-rc4-owner-cutover-20261108:start -->
## 2026-11-09 本人限定code4 Alpha公開・Android新規導入後の利用確認PASS

本節はRC4工程の現時点記録。以下のcode3以前の配信・確認結果は履歴として維持し、code4の成果物・アップロード・審査・配信・端末更新とは区別する。 旧版互換のリリース要件は11/9の本人決定へ更新し、過去の一斉切替条件を現在のブロッカーへ転用しない。

- **番号・完成成果物**：Play登録履歴で次の `1.0.1／code4` が未使用と確認後、固定RC・既存署名／Application ID・lockを維持して署名済みAABを生成。成果物は `/Users/gota/hamcare-deploy-staging/pre-optin-rc4-20261108/artifacts/hamcare-1.0.1-code4-pre-optin-signed.aab`（172,244,527 bytes、SHA-256 `f3344659dee8cbcbae51702d0f8d12d2a1c343c59b19ca5376525a7aad675ace`）。署名、88枚PNG、manifest、固定RCコード／lockとの整合を確認しPASS。不要な再ビルド・再署名は行わない。
- **アップロード・審査・Alpha公開**：本人承認の対象範囲を送信直前に照合し、既存Alphaのrelease4／code4だけ1変更を2026-11-08 21:31 JSTに審査送信（送信ID3）。21:47 JST頃は審査中だったが、同日22:39 JSTに「公開」となったことを11/9の公式送信詳細で1変更・日時とともに再読確認し、審査待ちは終了。日本のみ・既存本人1名・管理対象公開off、他トラック差分0。Alpha公開と実端末の導入・更新は区別する。SamsungのPlay新規導入後のログイン・記録・動作は11/9本人PASS、AVDの正式3→4更新保持は未確認。
- **正式更新の確認経路**：既存の `HamCare_Play_20261101` は保存userdataを保持したPlay配布署名1.0.1／code3（installer／initiating=com.android.vending）のまま。Chrome初回利用条件へ本人が同意した後、公式Alpha URLでBecome a tester→You are a testerを確認し、Webアカウントの本人一致を真偽値で確認。internal URLはAccept invite表示で未受諾、Store表示はInternal Early Access→Early Accessへ変化した。内部テスト退出操作そのものは実行しておらず、退出完了とは断定しない。code4は送信ID3で11/8 22:39 JSTにAlpha公開済みだが、AVDの正式更新は未実施。Samsungは署名非互換ローカルcode2削除後のPlay版新規導入・通常ログイン・記録・動作が11/9本人PASSで、AVDのcode3→code4更新保持とは分ける。旧版更新の未確認を、P1の追加リリース条件にはしない。
- **候補の固定と作業環境**：承認済みタスク1〜5・日付跨ぎ修正・UIテスト更新を維持し、P1の計画的一斉切替条件だけを独立コミットしたリリース候補は `f5f09c2b65536022f0d75e140de757610b691ef2`。`/private/tmp/hamcare-pre-optin-rc-20261108` をこのSHAから作成し、開始時clean・HEAD一致を確認。元のdirty作業ツリーはビルド／デプロイ元にせず、固定SDK・既存署名・ID・lockと安全なローカル設定注入を再利用する。既存フォーム文書差分・iOSローカル設定・未追跡素材は保持する。
- **サーバー反映済み範囲**：対象consumer7件（healthWeightRecordWritten／healthDistanceRecordWritten／healthDailyCheckinWritten／healthEnvironmentHistoryWritten／healthEnvironmentLatestWritten／rebuildMyHealthArchitecture／personalityDailyReports）を先に反映。旧iPhone build3と既存Play専用AVD code3の通常完全入力について、保存・再読込・Silver／Gold・Home・既存AI文脈・関連ログを確認しPASS。その後、入力受付saveDailyCheckinを旧 `savedailycheckin-00001-zuv` から新 `savedailycheckin-00002-gim` へ限定反映し、traffic100%を確認。writer反映後も旧Play専用AVDの完全入力で互換ゲートPASS。全Functionsの一括反映、数値専用経路等の追加、実AI送信は行わない。
- **部分保存の仕様と確認範囲**：code4／build4以降の部分保存を正規仕様とする。本番の新部分記録0件は11/8 22:04:56 JSTのmetadata照合時点の結果で、現在件数の再照会は行わない。個別の部分保存8ケース・新部分に対するRaw／Silver／Gold／AI文脈／通知の実測は未実施のまま区別する。本人の正常ログイン・記録・動作確認を受領したことを、これら全ケースのPASSへ読み替えない。旧版の全環境切替や完全後方互換を追加のリリース条件にはしない。
- **旧環境と新規導入方針**：Samsung SM-S911Nの削除前アプリはローカル署名1.0.1／code2でPlay配布署名と非互換。11/8は本人終了・主process0で維持していたが、11/9に本人がこのローカル版1件の削除を追加許可した。未同期の端末内データ・ログイン状態を失い再ログインが必要になることを説明済みで、08:37 JSTにモデル／installedProfiles[0]を確認しcom.gotainu.hamsterだけをADB公式uninstall、Success／pm path消失を確認。従来の削除禁止はこの1件に限り解除し、クラウドの飼育記録・体験・利用権限の削除／リセット、新APK生成・署名変更は0。Play版code4の新規導入後、正常ログイン・記録・動作に問題なしと11/9本人確認PASS。新規導入を上書き更新・ログイン保持PASSとは扱わない。他の保存AVD2台は非稼働、保存Simulatorは全Shutdown、Play専用AVDの正式3→4更新保持は未確認。iPhoneはTestFlight build4へ正式更新・保持確認PASS。旧版互換をリリース要件から外す本人決定により、全旧環境の一斉更新確認はP1のブロッカーではない。
- **本人限定・公開境界**：Play Alphaは日本のみ・既存リスト本人1名、TestFlightは既存の本人向け内部1名を維持。外部応募者約15名は未登録・未招待・参加案内／メール未送信。本人決定により外部案内対象はcode4のみとするが、今回招待・メール送信・対象拡大は実施しない。製品版変更・一般公開・App Store製品版審査は0。Apple Case103009817213の回答待ち／決済判断保留を維持する。
- **証拠と確認範囲**：既存の非公開staging `pre-optin-rc4-20261108/audit/` のserver/deploy-results、server/test-user-metadata、device-inventory-before-code4.json、old-readers-closed-readonly-check.jsonを参照。メール・UID・資格情報・私的本文は本書へ転記しない。SamsungのPlay新規導入後の利用は11/9本人PASSとして記録し、AVDの旧版更新保持や部分8ケースをPASSへ読み替えない。本人の成功判断と旧版互換を要件外にする決定を引き継ぎ、P1を理由に追加実装・手動確認を要求しない。mainへのmerge／pushや新build／uploadは今回行わない。

送信ID3のAlpha公開・Samsungでの新規導入後の正常ログイン／記録／動作は本人確認済み。新規導入と旧版更新保持、本人の利用確認と未実施の個別8ケースは区別する。旧code3／build3以前の互換は今回のリリース要件外とし、P1旧クライアント誤読は非ブロッキングとして閉じる。外部案内対象はcode4のみだが、実招待・送信・新たな配信操作は行わない。
- **審査待ち間の旧AVD停止**：11/8 22:09 JSTに専用AVDの旧HamCare code3だけをforce-stopし、主process0／package stopped=trueを確認。userdata・既存ログイン／記録・Playアプリは削除／変更せず保持。配信後の正式更新確認まで旧アプリを起動しない。Samsungの本人終了・他AVD／Simulator停止と区別して記録し、正式Android更新や部分保存PASSを意味しない。
- **停止前の入力版照合**：11/8 22:04:56 JST開始の承認済みmetadata再照合で、新partial／未回答marker／condition:nullは全対象0、全走査件数一致。本文・UID・メール保存0、データ変更0。
- **11/9の導入状況・本人確認**：Samsungローカル版は本人の追加許可で08:37 JSTに削除済み。公式Play Webの遠隔導入はGoogle再本人確認前で未成立のため中止し、本人スマホの公式Playページからの導入を案内した。その後、本人から正常ログイン・記録・動作に問題なしとの報告を受領し、Play code4の新規導入後の利用を本人確認PASSとする。これは旧code3→code4の上書き更新・ログイン保持試験ではない。AVDは公式PlayのUpdateを1回選択したが、最終読取の08:49 JST時点はcode3であり、正式3→4更新保持は未確認のまま。追加の手動確認や再テストは要求しない。
- **2026-11-09の確定方針・P1クローズ**：本人は旧code3／build3以前を実運用しておらず重要なユーザーデータもないとして、旧版後方互換性を今回のリリース要件から外した。新しい部分保存をcode4／build4以降の正規仕様とし、P1の旧クライアント誤読は要件変更に基づく非ブロッキングとして閉じる。コード上の完全後方互換を実装・検証した意味ではない。旧版互換の追加実装・二段階配布・強制更新機構は不要。外部テスターへの案内対象はcode4のみで、今回の方針決定自体では招待・メール送信・対象拡大を実施しない。以下の過去の一斉切替ゲートより本決定を優先する。
- **表示調整完了（ソースのみ）**：端末のAndroid／iOSアプリ表示名・Flutter title・ドロワー名を「Ham Care」へ統一。Home本体のアバターを190→224px、分析準備を108→128px（compact88→104px）、クイック記録3画像を44→58pxに拡大した。クイック記録は既存52px枠で軽微な見切れを許容し、Resolver／状態対応／fallback／タップ動作は維持。既存関連テスト66件PASS、実Widget合成描画4件（320／390px・明暗）PASS、Drawerとクイック記録の実Widget描画も目視確認。端末でこの表示変更を確認したという意味ではない。flutter analyzeはmain基準と同じ既存57件（新規0）、git diff --check・iOS plist形式PASS。過去の固定fontによるGolden全体再実行・期待画像更新は行わない。描画・ログは `/private/tmp/hamcare-display-polish-20261109/` と同名接頭辞のログへ保存。配信済みcode4／build4・署名・成果物・版番号は変更せず、新ビルド／upload／配信、main merge／pushは行っていない。次回配布で表示修正を取り込む場合は、新しい未使用build番号を使用し、配信済み4を差し替えない。
<!-- hamcare-rc4-owner-cutover-20261108:end -->

## 2026-11-02 クローズド募集準備・フォーム公開と現行人数（Console設定変更なし）

既存Alphaの1.0.1／code3は有効、11/1 18:47 JST公開、日本のみ1国、internal-testers登録1名を確認。11/2のダッシュボードは「現在、0人のテスターがオプトイン」「12人以上／14日」と表示し、製品版アクセス申請ボタンは無効だった。登録1名と実opt-in0名は別値。過去10/25の値を現在値へ転用したものではない。正式Alpha参加URLと同packageのStore詳細を実画面で確認し、参加URLは従来の個別案内管理を維持する。

内部track code2も同じinternal-testers1名を選択している。募集者を共用リストへ追加して内部テストまで広げず、将来は既存Alphaだけへ新募集用専用メールリストを追加する案を推奨する。現本人1名と既存内部配信を保持し、本人の募集内容確認と別途承認後に実施する未設定の案である。今回Console設定の変更・保存・送信・tester追加・招待は0。

既存クローズドテスト計画に、X先行／不足時YouTubeの未投稿原稿、採用後案内、正式参加手順、数回利用と短いアンケート、非公開段階管理を保存。応募／フィードバックは各6問の実フォーム下書きを保存済み（応募5必須・1任意、feedback3必須・3任意）。Drive保存名は「HamCare Androidクローズドテスト｜応募受付」「HamCare Androidクローズドテスト｜参加報告・アンケート」で、本人のみ編集／回答閲覧・結果概要非公開・Googleログイン強制なし。Play用メールは応募の専用設問で目的を明記して手入力、フィードバックは参加ID方式でメール再収集なし。保存設問・必須markerをpreviewで照合し、応募メール形式検証UIも確認。preview送信は無効のため送信試験未実施・架空回答0。実体はDrive保存名と既存非公開staging監査closed-recruitment-20261102/preparation-result.json／3確認画像で管理し、編集リンク・監査・応募者情報は本書／公開Gitへ入れない。当初の公開操作は自動承認レビューが下書き許可とは別として拒否したが、その後の本人追加明示承認後、11/2 13:32 JSTに2フォームを実公開。公開UIと作成者以外の回答画面で入力可能・Submit表示を確認。応募回答用URLは https://forms.gle/d3G4JSmycuZgPpBy8（一般募集用）、feedbackは https://forms.gle/5H5xNQYg3cYWJNcp6（採用後個別案内用）。回答者はリンクを知る全員、編集／回答閲覧は本人のみ、概要共有OFF・Googleログイン強制なし。送信テスト0・現在両フォーム0回答で、実回答URLを既存募集原稿と採用後案内へ差し込み済み。本人がX募集投稿を出せば応募受付できる状態。公開結果は同じ非公開監査領域publication-result.jsonへ保持し、前段の下書き保存commit65959d7は履歴として残す。X／YouTube投稿、個別連絡、Playリスト追加は今回実行しない。

通常21日体験・最大20件と既承認の有限共有枠を維持し、毎日起動／AI送信／購入を必須にしない。体験の延長・reset・新beta権限を設けない。個別回答・連絡情報・参加ID対応表はテストと製品版アクセス申請の対応終了後90日以内に削除し、匿名化改善メモだけを保持する。既存のPrivacy／サポート公開ページとフォーム記載は照合済み。既存code3／build3と端末確認・限定12件PASSは維持し、追加開発・再ビルド・認証／課金／AIテストは行わない。計画・素材の正本は[既存クローズドテスト計画](google_play_closed_test_plan_ja.md#2026-11-02-募集準備の現在地rel-02)。

## 2026-11-01 Alpha code3審査送信・18:47 JST公開（送信ID2・1変更）

指定のhamcare-1.0.1-code3-avatar-signed.aab（前回SHA d541d07f…b54f37、再生成／再署名なし）を既存Alphaへupload・release3「3 (1.0.1) avatars88 Alpha」で保存。登録code3／1.0.1／min24／target36・署名エラー0、日本のみ・既存internal-testers1名・管理対象公開オフを確認。追加する1変更だけを2026-11-01 18:19 JSTに審査送信し、送信ID2・当初審査中を確認後、同日18:47 JSTに「公開」と公式送信詳細で確認した。製品版／内部トラック／テスター範囲／署名鍵は変更しない。今回code3は既存Alphaへテスト配信可能と確認済み。送信受付・審査通過／Alpha公開・実端末更新を区別し、製品版一般公開とは扱わない。

リリースノート：プロフィールなどで表示するアバターを88枚に拡充しました。ロボロフスキーのパイドに対応し、種類・毛色・状態に応じた画像を追加しました。

### 11/1 Android新専用AVDの正式Play更新・現code3本人確認

旧Play署名専用VMの一時userdataは現存せず、普段使いローカル52abアプリと既存2AVDは削除・変更しない。本人の実AndroidにもPlay版未導入であり、今回の結果を普段使い実端末の更新保持PASSへ読み替えない。既存API34 Google Play ARM64を再利用し、新しい永続専用AVD HamCare_Play_20261101を準備（追加SDK0、既存AVD114ファイル不変）。基準code2はConsole取得のPlay署名Universal APKを新規直接導入したもので、Playクライアントからの新規取得・旧VM復元ではない。

本人のPlayサインイン後、最小観測では既にcode3だった。installer／initiatingともcom.android.vending、導入4APK全てDA77署名、code2基準とLinux UID／firstInstallTime／dataDir一致。固定code3 AABとarm64 AOTを含むnative3件・標準88PNGのSHA全一致、mismatch0を確認。正式Play配送による2→3更新とデータ領域継続はPASS。手動／自動の操作主体は未確定で、agentによるcode3直接APK導入・downgrade・アンインストール・データ消去は行っていない。

本人は現code3で通常ログイン・Home／既存プロフィール／飼育記録表示、変更許可のある検証用プロフィールのロボロフスキー／パイド保存→再表示、白黒アバターと毛色保持をPASS確認。code2ログイン済み基準と更新時刻の前後が未確定のため、更新をまたぐ再ログイン不要や実データ保持の厳密PASSとは区別し、現code3の通常利用・既存データ閲覧PASSとして記録する。全8状態切替とAndroid white_faceは新端末未確認、既存ローカル12PASSは維持し、追加の強制状態試験・本人操作は今回は不要。AI／課金／Auth方式／DeviceCheckの再試験なし。証拠は既存staging/android-play-verification-20261101/audit/code3-play-runtime-verification-20261101.json（20:15 JST）と本人回答。旧code1→code2 PASSは当時の別結果として保持する。以下の未upload記載は候補作成時点の履歴。

## 2026-11-01 Android code3アバター更新候補（配信前の履歴）

標準88枚を統合し、新2色16画像の限定12件・112表示セルと保存再読込・既存プロフィール／white_face欠損fallbackをPASS確認。既存72枚・通常権限・履歴・SDK／署名／固定lockは維持。11/1 15:46 JSTの現在のStore全履歴で番号3が未登録と確認し、pubspecは1.0.1+3へ更新済み。既存成功手順の隔離コピーでローカル候補の生成・署名・整合検証PASS。提出候補は `/Users/gota/hamcare-deploy-staging/android-ordinary-update-20261025/artifacts/hamcare-1.0.1-code3-avatar-signed.aab`。既存Upload署名7e9b…／code2一致、Bundletool／jarsigner／ZIP CRC、min24／target36、非Debug、権限差分0と、元88PNG＝成果物内88PNGの全SHA一致を確認。実際の端末2→3更新は未実施。

今回はupload・審査送信・新配信・端末更新を実施しない。既存Alpha code2／TestFlight build2と完了済み確認は維持。次のupload直前に番号3の競合を再確認し、対象成果物・既存トラック／本人グループ・配信範囲の承認を受ける。画像版2→3の実機保持確認はその後に限定実施し、旧code1→code2 PASSをやり直さない。Apple Case103009817213の回答待ち・決済方針保留も維持する。

2026-10-31時点の履歴：送信ID1・14変更は2026-10-27 11:09 JSTに送信し、同日11:19 JSTに「公開」と本人確認済み。今回も既存送信詳細／リリース一覧でAlpha1.0.1／code2の公開を読取確認した。日本のみ・既存internal-testersを維持し、Production一般公開・必要人数／期間の達成とは区別する。既存の審査アクセス・通常権限・実機／署名更新／DeviceCheck PASSは維持。次期アバター更新は画像制作待ちで、登録2版（code1／code2）を全App Bundle一覧で確認し、次番号を1.0.1／code3とする。今回upload・build・配信0。

更新日: 2026-11-02（募集準備・現行人数の読取、Console設定変更なし）

Google Play Consoleで初回登録するときの入力原本です。画面の文言が変わった場合は、同じ意味の項目を選びます。パスワード、確認コード、秘密鍵はこのファイルへ記録しません。

2026-10-26時点：日本限定・App Store / Google Play同時公開を目標とします。Stripe維持を第一希望とし、Apple IAP / Google Play Billingは未実装です。決済導線の適用条件は[審査メモ](store_review_notes_ja.md)に従い確定します。地域日本のみの既存設定を維持し、同意対応code2の内部公開とAlpha差替え保存まで完了しました。内部公開は審査PASS・一般公開・12人14日のクローズド条件達成とは区別します。

## 1. アプリを作成

| 項目 | 入力・選択 |
|---|---|
| デフォルトの言語 | 日本語（日本）`ja-JP` |
| アプリ名 | `Hamster Care｜ハムスター健康管理` |
| アプリまたはゲーム | アプリ |
| 無料または有料 | 無料 |

アプリは無料でインストールでき、一部機能に月額プランがあるため、アプリ本体は「無料」を選びます。表示される必須のポリシー同意と輸出関連の確認を、内容を確認して選択してから作成します。

## 2. ストア設定

| 項目 | 入力・選択 |
|---|---|
| アプリのカテゴリ | ライフスタイル |
| タグ候補 | ペット、健康管理、ライフスタイルから実際に表示されるものを選ぶ |
| 連絡先メール | 公開用サポートメールアドレス |
| ウェブサイト | `https://hamster-breeding-app.web.app/` |
| プライバシーポリシー | `https://hamster-breeding-app.web.app/privacy/` |
| アカウント削除 | `https://hamster-breeding-app.web.app/account-deletion/` |
| 公開地域 | 日本のみ |

掲載文は[ストア掲載情報](store_listing_ja.md)、画像は`store_assets/`を使用します。

## 3. アプリのコンテンツ

| 項目 | 回答方針 |
|---|---|
| アプリへのアクセス | 一部または全部の機能が制限されている。審査用ログイン情報と、有料機能を確認できる手順を入力 |
| 広告 | いいえ |
| コンテンツのレーティング | 実装に沿って回答。暴力、性的表現、賭博、薬物などは該当なし |
| ターゲットユーザー | Console保存済みの対象年齢は18歳以上（10/25読取り）。子ども向けではなく、今回変更しない |
| ニュースアプリ | いいえ |
| 政府関連アプリ | いいえ |
| 金融機能 | 金融商品・融資・送金等には該当しない。月額利用料の決済のみ |
| 健康関連 | 人の診断・治療・健康管理ではない。ペットの飼育記録と参考情報であることを説明 |
| データセーフティ | [プライバシー申告チェックリスト](privacy_disclosure_checklist_ja.md)を転記 |

## 4. 審査用アクセス

- 審査用アカウントのメールアドレスとパスワードはPlay Consoleへ直接入力する
- 二要素認証、SMS、ワンタイムパスワードを審査時に要求しない状態にする
- 一般テスターの21日／20件体験と、Google審査担当者のアクセス要件は分ける。審査員自身によるアカウント作成・無料試用・購入を前提にせず、提供済み資格情報で有料部分を含む全機能へ入れる状態が必要。今回は本人がカードなし0円の正規Stripe契約を作成し、通常paid／activeの既存Webhook同期を確認。Android有料gateは本人PASS。Console資格情報・456文字手順と正確なアクセス申告は保存・再読取PASS。特別beta・DBでの手動有料付与を代用せず、既存AI共有予算・費用枠・履歴は維持する
- 「今日」「記録」「変化」「相談」「設定→利用プラン」の確認経路を記載する
- SwitchBot実機がないと確認できない機能は、必要機器と確認可能な代替画面を説明する

10/27の現状：カードなし0円の通常契約とFirebase paid／active同期、Android有料gate本人確認はPASS。本人が新登録HamCareのパスワードをConsoleへ直接入力し、456文字の英語手順・全機能アクセス確認を「追加」→親画面「保存」で保存PASS。別画面へ移動後の再読取でも、対象username・456文字・確認項目の一致を確認した。パスワードはチャット・文書・証拠へ転記していない。 公開の概要の未送信は14件のまま（増減0）。ログインの詳細の手順更新は既存の「お送りいただいた変更」欄に別表示され、14件へ重複加算しない。この保存時点では14件未送信。その後、本人承認の同14変更を2026-10-27 11:09 JSTに審査送信。審査結果未確定（審査中・審査通過は未確認）／Alpha配信未確認（審査通過後の配信待ち）を分け、Production公開0を維持。 初回同期障害・通常metadata補記と自動復旧は下記証拠へ記録。初期の未登録・455文字案の保存拒否・Checkoutのカード要求は履歴として保持。特別beta・DB直接付与・trial reset・追加AIなし。[審査メモ](store_review_notes_ja.md#google-play審査アクセスの現状と保存待ち文案2026-10-27)、既存audit/review-account-preparation-20261027/を参照。

## 5. クローズドテスト版

履歴（10/25）：[ダッシュボード](https://play.google.com/console/u/0/developers/7040110575286467511/app/4976014731630589144/app-dashboard)、[Alpha](https://play.google.com/console/u/0/developers/7040110575286467511/app/4976014731630589144/tracks/4700032976627342279)、[公開の概要](https://play.google.com/console/u/0/developers/7040110575286467511/app/4976014731630589144/publishing)を読取り確認した。既存準備は4/5・日本のみ、13件は未送信、管理対象の公開はオフ。今回審査送信・公開設定変更は行っていない。

- アプリ署名はGoogle Play App Signingを使用する
- パッケージ名は`com.gotainu.hamster`
- 10/26のアップロード実体は正本「Android提出物」の同意対応後 `/Users/gota/hamcare-deploy-staging/android-ordinary-update-20261025/artifacts/hamcare-1.0.1-code2-consent-signed.aab`。SHA256 `9ac74bc4e15497728c77c5736344964fb07d268aefdb972d0006e3d3e860b237`、1.0.1／code2・min24／target36・非Debug。既存upload証明書一致を確認した同一AABで、内部テストへアップロード後、Alphaではライブラリのcode2を再利用した。同意前のcode2-signed版、旧9/14版、unsigned版は提出対象にしない
- versionName／versionCodeの確定値は`1.0.1`／`2`。code2は10/26にConsoleへ登録済みで、同じAABを複数トラックへ使う場合はライブラリから再利用する。`1.0.0`／`1`は過去版。ローカルDebug APKのcode2とPlay配布版は、同番号でも署名・同意実装の有無が異なる
- リリース名は確定したversionName / versionCodeに合わせる
- 現code2の保存済みリリースノートは「AI相談の送信前に、送信先と対象データを説明する同意画面を追加しました。設定から同意を取り消せます。」（10/27リリース詳細で一致確認）。初回旧code1向けの原稿は履歴として保持し、現リリースへ戻さない
- AABアップロード後、Play Consoleが表示する署名・権限・target API・警告を保存する
- 10/25工程の最新source Release AAB build／Bundletool検証はPASS（1.0.1／code2、min24／target36、非Debug）。元native min23は保持し、提出OSは本人がAPI24以降で確定。原因は固定Flutter3.47.7の標準migrationで、最低OSだけの再ビルドは不要。後続の本人明示許可で既存署名設定をRAM参照し、指定JKS同一性・Console登録upload証明書一致・署名／ZIP／Bundletool検証までPASS。署名済み候補は既存stagingへ保存済み。10/25時点ではアップロード／審査送信は未実施で、10/26に下記内部公開とAlpha差替え保存を実施した。新鍵／Debug鍵で代用しない。詳細hash／成果物は正本「Android提出物」を参照。

### 2026-10-26 内部テスト公開・Alpha差替え保存

- 9:19 JST、既存[内部テストトラック](https://play.google.com/console/u/0/developers/7040110575286467511/app/4976014731630589144/tracks/4700142116971858603)へリリース`2 (1.0.1) consent internal test`を保存・公開し、「内部テスターに公開」「10月26日9:19」「未審査」を確認した。既存`internal-testers`の本人1名を維持し、新規招待は0。メールアドレスは本書へ記録しない。
- [Alpha](https://play.google.com/console/u/0/developers/7040110575286467511/app/4976014731630589144/tracks/4700032976627342279)では、同じAABをライブラリから再利用して`2 (1.0.1) consent Alpha draft`を未公開保存し、プレビュー保存で公開の概要へ反映した。最終画面で「審査にまだ送信されていない変更」「13件の変更を審査に送信」と、Alpha行の`2 (1.0.1) consent Alpha draft 完全公開を開始`を確認。13件の送信ボタンは押しておらず、一般審査送信・クローズド配布は0。画面の自動クイックチェックを審査送信とは数えない。
- ConsoleのAPI／ABI差分に関する1,079非対応デバイスの警告は、内部リリースを妨げるエラーではなかった。承認済みAndroid7.0／API24以降の方針を維持し、これを理由としたSDK／native変更や再ビルドは行っていない。
- 同意の限定26件、実AI、実認証、動画の既存成功試験は再実行していない。今回の内部公開を、同意対応候補の端末起動・UI確認済みへ読み替えない。

### 現行開発端末との更新互換性と鍵履歴

10/26更新前のSM-S911N（Android16／API36）の`com.gotainu.hamster`は1.0.1／code2のDebug APKで、10/25上書き版とAPK SHAが一致した。これを、通常のPlay上書きと同署名のローカル更新に分けて判断した。

| 署名の役割 | 公開証明書SHA256 | 照合結果 |
|---|---|---|
| 現端末と既存ローカル署名 | `52ab9f417a1008800a5e3eefc55ce1a2539bdedfeebba10855cf79f85208b62e` | 旧Debug APKと今回のローカルRelease APKで同一 |
| Play現在のアプリ署名 | `da777b3e65d587ff9808d5b87e08725b6368bd5f2ec1217d3169433c2c6f6115` | Play配布用。現端末の52ab署名とは別 |
| Play履歴・公開ZIPの従来方式成分 | `ac1983e25b9646e82cf3a6da33e1bbf22f79e0d79f853207f70ee10bc8731dd0` | 現端末の52ab署名とは別 |
| Play履歴・公開ZIPの耐量子成分 | `92a933c5ab2505642eec42ffc276a7f0c42ec2b852d1672786f4f693e7f906af` | 現端末の52ab署名とは別 |
| AABアップロード署名 | `7e9bf2b197902c7fca90bb79eb5a1cd699f9cc83a9f8ad1c6ba32f1546f23410` | 指定既存JKS・保存済み公開DER・最終AABで一致。端末更新の署名ではない |

Play Consoleには「7 9月2026,01:04／量子対応beta」の以前のアプリ署名行があるため、鍵履歴そのものがないとはしない。現在の公開証明書ZIPの`deployment_cert.der`／`hybrid_classical_cert.der`／`hybrid_pqc_cert.der`を独立照合し、上記DA77／AC19／92A9と一致、すべてDebug52abと不一致と確認した。現Debug APKの検証はv2=true／v3・v3.1=falseで、直接のGradle設定にもlineage指定はない。Debug52abをPlay署名系統へ接続する正当な更新履歴は取得できていない。前工程の自動操作ではChromeの`ERR_BLOCKED_BY_CLIENT`で取得できなかったが、今回は通常のnative ChromeのConsole「署名付きUniversal APK」Downloadからcode1／code2を取得でき、両方の公開証明書がDA77で一致することを確認した。新設定・保護解除・回避操作は0で、前回のブロックは履歴として保持する。内部アプリ共有の別署名APKは使用せず、今回の取得をPlay Storeクライアント経由の取得とは数えない。[Android署名](https://developer.android.com/studio/publish/app-signing)、[署名更新の証明](https://source.android.com/docs/security/features/apksigning/v3)。

通常のPlay上書きは署名不一致のままであり、同code2という点も新版更新の制約になる。番号を増やすだけで署名差は解消しない。Play鍵の変更・データ消去・元アプリの別package化で回避しない。

### 固定AABからの同署名ローカル更新（2026-10-26）

- 指定consent AAB（SHA256 `9ac74bc4e15497728c77c5736344964fb07d268aefdb972d0006e3d3e860b237`）から既存bundletool1.18.1でAPKを生成し、現端末と同じ既存52ab証明書で署名した。Dart／nativeのソース再コンパイル、新鍵、鍵ローテーション、元AABの変更は0。[bundletoolの公式手順](https://developer.android.com/tools/bundletool)。
- ローカルAPKの永続版は`/Users/gota/hamcare-deploy-staging/android-ordinary-update-20261025/artifacts/hamcare-1.0.1-code2-consent-local-existing-key-20261026.apk`、162,940,042bytes、SHA256 `514c000cb00e61c692685654d41f1a652c78cbc558ad720e7e9e68518c78db84`。同package／1.0.1／code2・min24／target36・非Debug manifest、2 DEXと81 native・AOT・資産ファイルのAAB一致、ZIP／16KiB zipalign／apksignerを確認PASS。署名証明書がDebug用でもアプリのビルド種別はReleaseのまま。
- `adb install -r`による削除なし上書きはSuccess、導入後APK SHAは上記と一致し、通常起動PASS。Android app UID10405、初回導入日時2026-10-03 16:38:47を保持し、最終更新は2026-10-26 10:45:26。更新前データ領域inode1298948は基準記録として保持する。本人への「再ログイン不要でHome・既存記録と、設定の同意撤回項目が表示されるか」という依頼に「表示されました」と一括回答があり、依頼範囲の本人表示確認をPASSとした。保持の根拠はこの本人回答とmetadataを分けて記録し、metadataだけで記録内容を断定しない。同意の確定・保存済同意の実撤回・新しい実AI送信は未実施。本人結果の保存先は既存stagingの`audit/android-local-consent-owner-confirmed-20261026.json`。
- ローカルAPK更新はPlayからの導入やPlay署名への移行のPASSではない。ReleaseコードのAndroid App CheckはPlay Integrityを維持し、サーバー受付も署名一致だけではPASSにしない。通常権限・trial日時／使用量・課金・履歴・App Check設定を変更せず、実AI・認証・動画・既存26件の再試行は0。自動送信や特別な権限付与で通さない。

### 正式Play署名APKの取得・独立環境での旧版更新確認（2026-10-26）

既存の内部track `4700142116971858603`／release2「2 (1.0.1) consent internal test」は9:19の公開状態を維持。登録済みcode2 artifact IDは`4860244546361357551`で、再upload・再build・新しい配信開始・招待・審査送信は0。Alphaの13変更は未送信のまま。

| 正式署名付きUniversal APK | artifact ID | bytes／SHA256 | 現在の結果 |
|---|---|---|---|
| 1.0.0／code1 | `4860227627581920827` | 131,071,588／`31492d4673feeb9e83b854e440963d3fc2b2dd78958abfed065be0cbc879a438` | DA77署名・apksigner PASS。専用VMへ直接新規導入・起動PASS |
| 1.0.1／code2（同意対応） | `4860244546361357551` | 162,989,257／`511e1f21bbe8a3049b5fc6f815435f0aa4009cc8e2ade30819a6552dd46c8f31` | DA77署名・apksigner PASS。最終AAB9ac74…と81 native／AOT／資産一致。このUniversal APK自体の直接導入は未実施。対象code2は別途Playクライアントからsplit APKとして旧版更新PASS |

永続版は既存stagingの`artifacts/hamcare-1.0.0-code1-play-signed-universal-20261026.apk`と`hamcare-1.0.1-code2-consent-play-signed-universal-20261026.apk`。取得・公開証明書・manifestの証拠は`audit/play-signed-apk-acquisition-20261026.json`。両APKの署名は上表の現Play証明書DA77と一致し、普段使いのローカル52ab署名APKやupload7e9b署名AABと区別する。

既存AVD2台は52ab系列のHamCareがあったため、そのデータを消さずに維持した。既存Pixel7／API34のSDK・system image・configを再利用し、専用の一時userdata diskを使う独立VM `emulator-5554`をread-only／no-snapshotで起動。元AVD30ファイルのSHAとstatは一致し、元端末・元AVDへの変更は0。これは同一Android OS内の別ユーザーやWork Profileとは異なる独立した検証環境である。

新環境は最初にHamCare packageなし／Googleアカウント0を確認し、正式code1 APKを直接`NEW_INSTALL`。1.0.0／code1・非Debug、UID10190・初回導入2026-10-26 20:05:49、APK SHA一致と通常起動を確認PASS。この初手はConsole code1 APKの直接新規導入であり、Play Store経由の新規配送ではない。その後のcode1→code2 Play更新と保持は下記で別にPASS確認した。初手の証拠は既存stagingの`audit/play-code1-isolated-before-update-20261026.json`（元観測`/private/tmp/hamcare-play-delivery-20261026/isolated-code1-new-install.json`）へ保持。

本人が専用VMのGoogle Playへのサインインを完了。Googleアカウント1件と現Console内部テスターの正規化hash一致を読取確認し、アカウント値・tokenは記録しない。その後、正式Play署名の旧HamCareを開き、本人の「通常ログインした」報告を受領。更新直前20:17:02 JSTは1.0.0／code1、UID10190、初回導入20:05:49・installer=nullを維持しており、旧版ログイン後に勝手なcode2更新が済んだとはしない。アカウント追加は専用一時userdataだけで、普段使い端末／既存AVDには追加しない。完了済みGoogle実認証の再回帰試験とは区別する。

同アカウントのGoogle Play掲載画面から既存内部配信のcode2へ本人が更新・通常起動し、「再ログインせずHome・既存記録が表示される」と回答。20:57:21 JSTにversionCode=2／versionName=1.0.1へ更新され、installerPackageName／initiatingPackageNameはcom.android.vending。UID10190・初回導入20:05:49を保持した。導入base＋3split全4APKを読み取り、apksigner検証とDA77公開証明書一致を確認し、arm64 libapp.soを含む75 native／AOT／資産が固定同意AABと一致した。Console取得Universal APKの直接上書きや内部アプリ共有ではなく、実際のPlayクライアント配送としてPASS。参加URL・メール・tokenは本書へ転記しない。証拠は既存stagingのaudit/Play-store-code1-code2-update-final-20261026.json、runtime照合はPlay-store-installed-runtime-matches-20261026.json。新code3／再配信は不要で実施0。今回分の追加本人操作は不要。

| 操作の分類 | 完了条件／現在の状態 |
|---|---|
| 空環境→code1 | 直接新規導入・起動PASS（今回の結果） |
| code1→code2 | Play Storeクライアント経由の旧版更新PASS。1.0.1/code2・署名DA77・全4APK検証、UID10190／初回日時保持。起動・再ログイン不要のHome／既存記録は本人PASS |
| code2→同じcode2 | 同版再導入。旧版更新として数えず、今回未実施 |
| Google Playからcode2を取得／更新 | 既存内部配信のPlayクライアント経由code2取得／更新PASS。installer・initiatingともcom.android.vending。Consoleダウンロード／ADB新規code1導入と区別 |

UID・初回導入日時の保持は端末metadata、既存アカウントのログイン／飼育記録保持は本人回答を根拠として、それぞれPASS確認した。metadataだけで記録本文保持を断定しない。元52ab系列の普段使い端末はそのまま残し、別署名のPlay版へローカルデータを自動移管できるとはしない。同一端末の別Androidユーザー／Work Profileを署名差の回避策として推奨せず、ユーザー作成や追加installも行っていない。本人の別Android実機を使う案も未実施の代替案として残す。実AI・同意確定・実撤回・trial再開始・権限付与は行わない。

以前の52abローカル上書きと本人保持PASSの証拠は、既存stagingの`audit/android-local-consent-replace-20261026.json`／`local-consent-apk-from-final-aab-20261026.json`／`local-consent-apk-integrity-20261026.json`／`android-local-consent-owner-confirmed-20261026.json`へ保持する。新しいPlay署名経路の結果で、以前の成功を未完了へ戻さない。

## 未送信14変更の送信範囲（2026-10-27）

この見出しと以下14行は、送信前に保存・承認・最終照合した範囲の履歴。既存リンクを維持するため見出しを残す。13→14の追加はfeedback URL、診断必須化は既存Data Safety行内。本人承認後2026-10-27 11:09 JSTにこの14変更を審査送信し、送信後表示「審査中の変更（送信ID1：審査中）」を確認。審査結果未確定（審査中・審査通過は未確認）／Alpha配信未確認（審査通過後の配信待ち）は、送信済みという事実と区別する。

| # | 現在保存されている変更 | 今回の結果／提出対象 |
|---|---|---|
| 1 | Alpha `2 (1.0.1) consent Alpha draft`の完全公開開始 | 同意対応code2だけ。保持bundleなし、code1は無効化済みの履歴。再upload・再buildなし |
| 2 | 日本1か国追加 | 日本のみの保存済み設定を維持 |
| 3 | 地域の製品版同期を解除 | Alphaの日本設定を維持 |
| 4 | トラック再開 | 保存された変更であり、新しい配信開始は今回は未実施 |
| 5 | internal-testersメーリングリスト | 既存本人1名を維持。招待・リスト追加0 |
| 6 | フィードバックチャネル | **今回保存**：空欄→既存support URL。後続の再読取で確認 |
| 7 | 日本語デフォルト掲載情報 | 名称・短文・本文一致。アイコン1／feature graphic1／電話スクリーンショット4を確認し維持 |
| 8 | コンテンツレーティング質問票 | 保存済み回答を維持 |
| 9 | 対象年齢18歳以上 | 保存済みを維持 |
| 10 | Privacy URL | 公開済みprivacy URLを維持。HTTP200・public原稿bytes一致 |
| 11 | 広告の宣言 | 広告なしの既存申告を維持 |
| 12 | Data Safety | **今回保存**：診断情報の任意→必須。既存12type・共有なし・用途は維持 |
| 13 | 健康アプリの申告 | 人の健康情報を扱わない既存保存内容を維持 |
| 14 | ライフスタイルカテゴリ | 保存済みを維持 |

「お送りいただいた変更」として別表示される、ログインの詳細・広告ID・行政アプリ・金融取引機能の4申告は、上表14件へ二重加算しない。今回、審査用アクセスの資格情報と456文字手順を保存・再読取PASS。ログインの詳細は同欄に手順更新として表示され、審査アクセス保存時点ではアプリ全体の14件送信ボタンは未押下。その後、本人承認の14変更を2026-10-27 11:09 JSTに審査送信した。

- **Consoleの状態**：送信前は14件送信ボタン有効・送信阻害エラーなし。本人承認後2026-10-27 11:09 JSTに送信し、送信後は「審査中の変更（送信ID1：審査中）」、審査中14件／未送信0件を確認。審査通過や実配信を送信成功から推測しない。既存の未審査一時アプリ名／API・ABI互換警告を新しい拒否理由へ読み替えず、SDK／native／鍵変更・再buildは行わない。
- **審査アクセス準備完了**：通常登録・メール確認・Home保持、カードなし0円通常契約・Firebase paid／active同期、Android有料gate本人確認、Console資格情報と456文字手順・全機能アクセス申告の保存／再読取はPASS。無料体験開始・審査員の購入不要。新AI回答は再確認しておらず、共有AI予算・個人上限・履歴を維持する。その後、本人が審査後のAlpha配信を含む14件の範囲を明示承認し、2026-10-27 11:09 JSTに送信。準備PASSは維持し、審査結果未確定（審査中・審査通過は未確認）／Alpha配信未確認（審査通過後の配信待ち）は別に確認する。
- **既存方針の保留**：現code2のStripe Checkout／Customer Portalを変更せず、適合済みとは記載しない。旧Case22954972は10/27にscope外回答を受領。本人承認のApp Review新問い合わせを2026-10-27 11:46:34 JSTに送信し、受付公式完了画面と11:48:45 JST受信の受付メールで番号一致を確認／新Case103009817213、決済判断は回答待ち。今回の作業をiOS・決済実装へ広げない。
- **本人承認に基づく審査送信**：送信直前にAlpha1.0.1／code2・同一AAB・日本・既存internal-testers本人1名と共通掲載／申告の14行を再照合し、2026-10-27 11:09 JSTに公開の概要から送信した。本人承認は管理対象公開オフによる審査後のAlpha配信も含む。審査結果未確定（審査中・審査通過は未確認）／Alpha実配信未確認（審査通過後の配信待ち）。承認後は対象リスト＋opt-in等の条件へ配信され、Productionへ自動昇格しない。新しいテスター招待・参加変更・製品版一般公開は行わない。[公開管理の公式説明](https://support.google.com/googleplay/android-developer/answer/9859654?hl=en)。
- **テスターの依存**：現リストは本人1名で、12人／14日の製品版条件は未達のまま。内部テストにopt-in中の人は、そのままではクローズド版を取得できないため、将来Alphaを検証する段階で本人のinternal opt-out／Alpha opt-inが必要。今回は既存内部テストを維持し、参加状態を変更していない。[テストの公式説明](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en)。

証拠は既存Android staging/audit/play-alpha-preparation-20261027/、同audit/review-account-preparation-20261027/と、今回の既存Android staging/audit/play-alpha-submission-20261027/。審査アクセス準備PASS・送信前14件の承認／最終照合・送信操作／送信後Console状態を分離して保持。14変更送信済みを、審査合格・Alpha実配信・12人／14日達成・Production公開とは混同しない。Apple決済判断保留は維持。新しい管理Markdownは作らない。

送信ID1の実受付：Google Play Consoleの送信アクティビティと送信詳細で、2026-10-27 11:09・14件・既存Alpha1.0.1/code2・ステータス「審査中」を確認。操作記録は11:09:09 JST。未送信の欄は消え、承認対象で送信できなかった項目は0。初回の公開の概要にはGoogleのクイックチェック案内も表示されたが、審査合格とは扱わない。

## 次期アバター更新版code3：既存成功手順と今後の配布操作

11/1は上記のcode3ローカルAAB生成まで完了。以下の画像受領前手順中の旧版数＋2／未生成という記述は当時の準備経緯で、現在は＋3・候補完成を正とする。upload以降は未実施。

以下は画像受領前に確定した手順を保存したもの。11/1の実行結果は先頭節を正とし、まだ行っていないupload／配信の操作とは区別する。

- 番号：`1.0.1／code3`。10/31にConsole「すべての App Bundle」で全2件（1.0.0/code1、1.0.1/code2）・次ページ無効を読取確認し、code3は未登録。既存`pubspec.yaml`は`1.0.1+2`のまま保持し、画像統合時に`1.0.1+3`へ1回だけ更新する。未使用確認は確認時点のものであり、実upload直前にも未使用を確認する。
- ソース：GitHub mainの今回の受入準備に、本人提供PNG・必要な実在assets登録・manifest・番号だけを追加。既存のAI同意・権限・記録・課金・lockを保持する。画像仕様／限定確認は[既存assets README](../../assets/avatars/README.md)に従う。
- ビルド環境：恒久Flutter`/Users/gota/tools/flutter-3.47.7-hamcare-ios`と既存JDK17。前回成功の隔離workspaceのGradle8.14／AGP8.11.1／Kotlin2.2.20／min24を再利用する。元projectのGradle8.12／AGP8.10.1／Kotlin2.1.0／min23を今回更新せず、元へそのまま直接buildできるとの保証に置き換えない。固定lock・依存を既存手順で揃えた隔離workspaceでのみ次の番号指定へ変更する。

```sh
/Users/gota/tools/flutter-3.47.7-hamcare-ios/bin/flutter build appbundle --release --no-pub --target=lib/main.dart --build-name=1.0.1 --build-number=3
```

前回の正確な環境・追加native条件・署名工程は既存stagingの`android-ordinary-update-20261025/audit/build-consent/build-command.json`と署名／整合性記録を基準とする。鍵やパスワードをコード・文書へ移さない。既存Upload鍵の署名（7e9b…）とPlay配信署名（da77…）の役割を維持し、新鍵・Debug署名を提出用へ代用しない。

1. 受領画像の検査／fixture表示だけを限定確認して新AABを生成。com.gotainu.hamster、1.0.1/code3、min24／target36、非Debug、署名・Bundletool・ZIP整合と差分PNGの格納を確認し、code2成果物を上書きしない。
2. 実配信を実行する段階で、対象AABと既存Alpha／日本／既存テスター／実リリースノートの範囲について本人承認を得る。同じAABを1回だけuploadし、必要な内部確認にも同じ登録bundleをライブラリ再利用する。掲載・Data Safety等の無関係な変更を一括送信しない。
3. 現Alpha code2を消さず更新リリースの下書きへcode3を選択し、追加した種類・毛色だけをリリースノートへ記載・保存する。審査送信前に公開の概要の差分・日本・既存tester範囲を確認する。管理対象公開オフでは審査後にAlphaへ配信されるため、下書き保存／upload／審査送信／公開を別記録する。Productionへ昇格しない。
4. 既存Play署名の独立検証環境でStore経由code2→code3を上書きし、版／導入元／署名とHome・ログイン・既存記録保持、追加アバターの表示だけ確認する。普段使い52ab署名ローカル版をアンインストール／消去して移行しない。今回までのcode1→code2 PASSを再試行せず、次回の2→3とは区別する。追加AI送信・体験再開始・利用枠リセット・実同意／撤回は含めない。

## 6. テスターと14日間要件

製品版アクセス申請前に、少なくとも12名が直前14日間連続でクローズドテストへopt-inしている条件を管理する。11/2のConsole実読は必要12人以上／14日、許可登録1名・実opt-in0名、申請ボタン無効。現Alphaはcode3・日本のみ、内部code2と共用のinternal-testersは本人1名を維持。募集目標は20〜30名で、将来はAlphaだけへの専用リスト追加を別途承認後に行う案を推奨する。現在は本人承認後に実フォーム公開・回答受付確認と回答用URL差込まで完了。募集投稿・採用／リスト追加・opt-in・14日達成は別状態で、まだ実績へ加えない。Googleの申請直前の人数／連続期間と実利用・フィードバックを区別し、既存の開発者端末PASSを参加人数へ読み替えない。[現行公式要件](https://support.google.com/googleplay/android-developer/answer/14151465?hl=ja)と[既存計画](google_play_closed_test_plan_ja.md)を参照。10/25〜11/1の旧人数・内部公開・Alpha送信は前節の履歴として保持する。

## 7. 製品版アクセス申請前

- 12名以上の連続オプトインが14日を満たしている
- 実際のテスト内容、フィードバック、修正内容を説明できる
- 致命的な不具合がない
- ストア掲載情報、データセーフティ、プライバシーポリシーが実装と一致する
- Alphaの日本のみターゲット設定は10/25Console読取りで確認済み。製品版／iOSの最終公開地域と同期状態は別途照合する
- 決済導線と審査説明を確定し、iOS側の準備状況と同時公開の操作を調整する
- 提出候補AABのハッシュとバージョンを`PROJECT_STATUS.md`へ記録する
