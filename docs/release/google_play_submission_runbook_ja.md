# Hamster Care Google Play登録手順

2026-10-27最新：既存Alpha release2「2 (1.0.1) consent Alpha draft」・同意対応code2だけ、日本・既存本人1名と共通掲載／申告の14変更を、本人の明示承認後2026-10-27 11:09 JSTに審査送信。送信後Consoleは「審査中の変更（送信ID1：審査中）」、審査中14件／未送信0件。審査結果未確定（審査中・審査通過は未確認）／Alpha配信未確認（審査通過後の配信待ち）と分ける。カードなし0円通常契約・通常paid／active同期・Android有料gate・Console審査アクセス保存／再読取PASSを維持。管理対象公開オフなので承認後はAlpha対象への配信を伴うがProduction自動昇格ではない。再upload・再build・新招待・一般公開・実AI0。

更新日: 2026-10-27

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

## 6. テスターと14日間要件

本書では製品版アクセス申請前に12名以上が14日間連続でクローズドテストへオプトインする条件を管理します。途中離脱に備え、15名以上を招待します。直近10/25のConsole表示は12名・14日、オプトイン0人で本番アクセス申請ボタン無効。10/26に同意対応code2を内部公開・Alpha差替え保存したが、12名／14日達成は確認していない。Alphaの既存14変更は本人承認後2026-10-27 11:09 JSTに審査送信したが、12人／14日の開始・達成を意味しない。実機の開発者確認を14日間要件の達成へ読み替えません。進行管理は[クローズドテスト計画](google_play_closed_test_plan_ja.md)を使用します。

## 7. 製品版アクセス申請前

- 12名以上の連続オプトインが14日を満たしている
- 実際のテスト内容、フィードバック、修正内容を説明できる
- 致命的な不具合がない
- ストア掲載情報、データセーフティ、プライバシーポリシーが実装と一致する
- Alphaの日本のみターゲット設定は10/25Console読取りで確認済み。製品版／iOSの最終公開地域と同期状態は別途照合する
- 決済導線と審査説明を確定し、iOS側の準備状況と同時公開の操作を調整する
- 提出候補AABのハッシュとバージョンを`PROJECT_STATUS.md`へ記録する
