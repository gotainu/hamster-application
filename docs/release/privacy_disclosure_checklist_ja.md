# Hamster Care プライバシー申告チェックリスト

2026-10-27最新：通常文字AI同意の実装・26件／iPhone TestFlight同意UI／Androidローカル更新と本人保持／独立VMの実Play code1→code2更新・保持／Release DeviceCheckサーバー計測PASSを維持。今回は既存Play申告を限定照合し、診断情報の任意→必須1点だけを保存。利用者向け停止設定がなくサーバーで選択によらず技術ログを記録する実装と既存表へ整合した。12type・用途・共有なしは維持し、実収集処理や公開Privacyは変更しない。その後、審査用ログインの通常契約・権限同期とConsoleアクセス申告の保存・再読取が完了。本人承認のfeedback追加を含む14変更を2026-10-27 11:09 JSTに送信し、送信ID1は審査中。審査通過・Alpha実配信は未確認、Production一般公開とApp Store審査送信は未実施。

2026-10-25実装・成果物生成（履歴）：通常文字AIの事前同意を既存最小案の範囲で実装し、通信モック限定26件PASS。対応する署名AAB／Distribution IPAを新規生成し、同意前成果物と区別した（正本の提出物欄）。App Privacy10typeのPublished／Play掲載・Data Safety12type保存は完了を維持。端末更新、実AI追加送信、本番変更、ストアupload／審査送信は行っていない。

更新日: 2026-10-27

この一覧はApp StoreのApp PrivacyとGoogle Playのデータ セーフティ入力用です。ストア画面の質問文は変更されることがあるため、提出時の最新表示に合わせて最終確認します。2026-10-25再開工程では、Play Consoleの既存申告質問票完了・Privacy URL保存等を読取り確認。後続の本人①②③承認で、App Store Connectに説明／キーワード／support・Privacy URLを下書き保存し、Privacy HTMLの説明2段落をHostingのprivacy1pathだけ公開しました（version97be910a4b4a9079、実URL200・承認HTML SHA一致、他12path/config保持）。この段階では未実施だったApp Privacy質問票のPublishとGoogle Play掲載／申告差分保存は、その後上記のとおり完了。この10/25工程ではアプリの審査送信は行っていません（後続のPlay送信は冒頭を参照）。以下は申告候補であり、実機の一部PASSだけで提出前チェックを一括完了にしません。

## 基本方針

- データの販売: しない
- 広告目的の利用: しない
- 他社アプリやWebサイトをまたぐトラッキング: しない
- 通信時の暗号化: HTTPS/TLSを使用
- アカウント削除: アプリ内とWebの両方から申請可能
- 公開ポリシー: https://hamster-breeding-app.web.app/privacy/
- 削除案内: https://hamster-breeding-app.web.app/account-deletion/

## 収集・処理するデータ

| データ | 例 | 目的 | 主な処理先 | アカウントとの関連 |
|---|---|---|---|---|
| 連絡先情報 | メールアドレス、Google認証で取得されるプロフィール名 | 認証、連絡、アカウント管理 | Firebase Authentication | あり |
| ユーザーID | Firebase UID、Stripe Customer ID | アカウント、契約状態の管理、利用導線の分析 | Firebase、Stripe、Google Cloud上の限定アクセス分析基盤 | あり。Firebase UIDをAnalyticsの標準User-IDにも使用 |
| ユーザーコンテンツ | ハムスターの名前、種類、毛色、誕生日、写真、飼育環境、メモ | アプリ機能の提供 | Firestore、Firebase Storage | あり |
| 飼育記録 | 今日の様子、体重、走行距離、温湿度 | 記録、グラフ、評価、通知 | Firestore | あり |
| 購入情報 | プラン、契約状態、更新・解約予定日、決済結果 | 有料機能の提供 | Stripe、Firestore | あり |
| AI相談内容 | 質問、会話履歴、関連する飼育情報 | AI相談の生成、履歴表示 | OpenAI、Pinecone、Firestore | あり |
| 外部サービス情報 | SwitchBot TOKEN/SECRET、機器ID、温湿度 | SwitchBot連携 | SwitchBot、Firebase Functions / Firestore | あり |
| デバイス識別子 | FCMトークン、App Check情報 | 通知、不正利用防止 | Firebase | あり |
| 利用状況 | 画面利用や操作イベント | 品質改善、利用状況分析 | Firebase Analytics、Google Cloud上の限定アクセス分析基盤 | ログイン中の標準User-IDを通じてアカウントに関連 |
| 診断情報 | エラーコード、サーバーログ | 障害調査、セキュリティ | Firebase / Google Cloud | 状況により関連 |

> 10/25の承認済み改訂：`public/privacy/index.html`の標準User-ID／Google Cloud限定分析とOpenAIへの相談情報・Pineconeへの検索用ベクトル送信の説明2段落を公開PASS。新version97be910a4b4a9079、復元用068a716a25e478c5。監査 `/private/tmp/hamcare-privacy-hosting-20261025/deployment-state.json`。App Store ConnectのPrivacy URLも保存済み。既存一般説明・Play既存申告を保持し、後続でApp Privacy確定／Play Data Safety差分保存まで完了し、アプリの審査送信とは分ける。
>
> User-IDはログインアカウントに結び付く。質問・回答本文、自由記述、氏名、メール、ペット名、市区町村、認証情報はAnalyticsへ送信しない。実装・取込の既存証拠は[`../analytics/server_event_ingestion_and_privacy_ja.md`](../analytics/server_event_ingestion_and_privacy_ja.md)を再利用する。
>
> 通常文字AIの明示許可は音声同意・一般legalConsentと分離し、今回の最終候補へ実装済み。送信先・現行データを表示して事前に同意を得る。既に公開済みのPrivacy説明と照合し、公開Privacy自体や申告回答は今回変更していない。既存実AI成功を同意対応候補の実機PASSに読み替えない。

## Apple App Privacy入力候補（提出候補版で要確認）

- Location > Coarse Location: 収集する、Analytics
- Contact Info > Name: 収集する、App Functionality（Google認証の基本プロフィール。Analyticsへ氏名を送らない）
- Contact Info > Email Address: 収集する、App Functionality
- Identifiers > User ID: 収集する、App Functionality / Analytics（UIDと分析の関連を含め、提出時の質問文で要確認）
- Identifiers > Device ID: 収集する、App Functionality / Analytics
- Purchases > Purchase History: 収集する、App Functionality / Analytics（確定契約の成立／終了・課金率の既存分析）
- User Content > Photos or Videos: 収集する、App Functionality
- User Content > Other User Content: 収集する、App Functionality
- Usage Data > Product Interaction: 収集する、Analytics
- Diagnostics > Other Diagnostic Data: 収集する、App Functionality / Analytics
- Tracking: いいえ

## Google Play データ セーフティ入力候補（提出候補版で要確認）

### 全体回答

- アプリがユーザーデータを収集または共有するか: **はい（収集する）**
- データの共有: **いいえ**。Firebase、Stripe、OpenAI、Pinecone、SwitchBotは、契約上サービス提供のために処理する委託先として扱う前提。委託先が独自目的で利用する設定を追加した場合は再確認する
- 転送中の暗号化: **はい**
- データ削除をリクエストできるか: **はい**
- 削除リクエストURL: https://hamster-breeding-app.web.app/account-deletion/
- 独立したセキュリティ審査: 実施証明がないため **いいえ**

### データ種別

| Google Playの分類 | 収集 | 必須/任意 | 目的 | 主な根拠 |
|---|---|---|---|---|
| Location > Approximate location | はい | 必須 | Analytics | Firebase Analyticsがマスク済みIPアドレスからおおよその地域を導出 |
| Personal info > Name | はい | 任意 | App functionality / Account management | Google認証の基本プロフィール。メール認証を選択可能 |
| Personal info > Email address | はい | 必須 | App functionality / Account management | Firebase Authentication |
| Personal info > User IDs | はい | 必須 | App functionality / Account management / Analytics | Firebase UID、Stripe Customer ID。Firebase UIDをAnalytics標準User-IDと分析の結合にも使用 |
| Financial info > Purchase history | はい | 任意 | App functionality / Account management / Analytics | Stripeのプラン・契約状態。カード番号等はアプリ側で取得・保存しない |
| Messages > Other in-app messages | はい | 任意 | App functionality | AI相談の質問、直近会話、回答 |
| Audio files > Voice or sound recordings | はい | 任意 | App functionality | 音声OFFでも端末からRAGへmultipartを転送。処理後の長期保持を示す根拠なし。メモリ限定を保証できずephemeralはNo |
| Photos and videos > Photos | はい | 任意 | App functionality | 利用者が選択したペット画像 |
| App activity > App interactions | はい | 必須 | Analytics | Firebase Analyticsの自動イベントと明示的な操作イベント |
| App activity > Other user-generated content | はい | 必須（現Consoleの分類単位。プロフィール等を含み、各記録の入力を強制する意味ではない） | App functionality | ペットプロフィール、飼育記録、メモ、自由記述 |
| App info and performance > Diagnostics | はい | 必須 | App functionality / Analytics | API・Functionsの障害調査用ステータス、エラー、技術ログ |
| Device or other IDs | はい | 必須 | App functionality / Analytics / Fraud prevention, security and compliance | Firebase app-instance ID、FCMトークン、App Check情報 |

### 選択しないもの

- Location > Precise location: 選択しない
- Financial info > User payment info: カード番号等はStripeのWeb画面が直接処理し、アプリや運営者のデータベースへ保存しないため選択しない
- Health and fitness: 人の健康・運動情報を対象とするため、ハムスターの飼育記録だけを理由に選択しない
- Advertising or marketing目的: 広告機能を使用せず、Analyticsイベントを広告目的に利用しないため選択しない

### 今回保存した申告差分と定義の区別

- 10/27の限定修正：Consoleの診断情報が「オプション」だった点だけを「必須（利用者はオフにできない）」へ保存。Settingsに診断停止選択がなく、Functions／RAGの状態・障害ログは利用者の診断選択に分岐しない。表の必須分類を維持し、アプリ機能・分析の2用途、他11type、OAuth・暗号化・削除URL等の既存回答は維持。最終previewからSave完了を確認。AI同意の追加だけを理由とするデータ種別追加はしない。
- 公開privacyとsupportはHTTP200、既存public原稿とbytes一致。Privacy URLはConsole最終previewにも一致。送信・保存先説明に矛盾はなく、同意文の追補だけのために今回はHostingを再配備しない。

- Apple：10typeすべてアカウントに関連、trackingなし。NameはGoogle認証のプロフィール取得に基づく。Purchase Historyは機能とAnalytics。App Privacy Publishedを本人承認後に確認。
- Play：OAuth追加、Name／音声録音追加、User IDs／Purchase HistoryのAnalytics、診断のApp functionalityを補完。Other user-generated contentはApp functionalityへ整合（本文をAnalyticsへ送らず、操作metadataはApp interactionsで申告）。一般Files/Documentsアップロード機能がなく、写真／音声／Firestore documentを一般文書ファイルと混同していた旧選択は解除。12typeを保存済み。
- 音声：現100%配備revision hamster-rag-api-00021-pobのAI_TRANSCRIPTION_ENABLED=0を18:02:54 JSTにread-only確認。Appleのrequest処理後非保持の例外では初版は非収集。Googleは端末外への一時転送もフォーム開示が必要なので収集に含める。FastAPIがflag判定前にmultipartをparseし、UploadFileのファイル退避があり得るため、Googleのメモリ限定ephemeralは保証しない。長期保存の確認と取り違えない。音声ON時は両申告を再評価する。
- Search Historyは独立した検索履歴機能の根拠がなく、内部RAG検索だけを理由に追加しない。自由記述のAI会話はApple Other User Content／Play Other in-app messages。
- 公式：[Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/)、[Google Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)、[FastAPI UploadFile](https://fastapi.tiangolo.com/tutorial/request-files/#file-parameters-with-uploadfile)。

### 実装確認メモ

- Androidマニフェストでは`AD_ID`とAdvertising Services関連権限を明示的に除外済み。ただしFirebase Analyticsのapp-instance IDは収集されるため、`Device or other IDs`は申告する
- AI相談は認証付きRAG APIへ質問と直近12件までの会話を送信し、回答をFirestoreへ保存するため、`Other in-app messages`を申告する
- Firebase Crashlytics / Performance Monitoring SDKは現在未導入。`Diagnostics`は主にAPI・Cloud Functions側の障害調査ログを根拠とする
- SDK追加、広告連携、Google Signals、BigQuery連携、ログ仕様の変更時は再確認する

## 通常文字AIの事前同意：確認結果と最小修正案

### 同意対応版の実機UI確認（2026-10-26）

- 後続10/26完了：専用の独立VMで、Play署名code1をConsole APKから直接新規導入後、既存Play内部配信からcode2へ実際に更新。全4APKの署名DA77と導入元com.android.vending、UID／初回日時保持を照合し、再ログイン不要のHome／既存記録は本人PASS。普段使い52ab端末の署名移行とは別。現在はPlay導入経路未確定を残件へ戻さず、同意承諾／撤回やAI送信を追加しない。

- 指定IPAをApp Store Connectへデリバリし、本人1名の内部TestFlightで1.0.1(2)を配布。本人がTestFlightからインストールし、Home・ログイン状態・既存飼育記録の保持を確認PASS。同Bundle／1.0.1(2)の端末metadataは一致したが、builtByDeveloperはtrue→trueのため、そのflagだけで配布経路の移行を証明したとはしない。
- 更新後のiPhoneで、送信ボタンから「AI相談の情報送信について」の説明が表示され、「送信しない」の取消後も入力が残ることを本人確認PASS。承諾後の実AI送信は行わず、既存26件のモック結果と区別する。設定の同意撤回項目の表示も本人PASS。入口はHamCare左上≡→「アプリの設定」で、下へスクロールしたSwitchBot連携の下にある見出し。初回案内では見出しを見つけられなかったが、正確な位置の再案内後に本人が「あった」と確認。表示の確認であり、確認画面の開閉・同意承諾／保存済同意の実撤回は今回未確認／未実施。コード修正は不要。
- Androidの指定同意対応AABはPlay upload・本人内部配布までPASS。現端末の52ab証明書とPlay署名は異なるが、同じ固定AABから既存52abで署名したローカルRelease APKを生成し、削除なし上書き・通常起動PASS。2DEX／81native/AOT資産一致、UID／初回導入日時保持を確認。本人が再ログインなしのHome・ログイン・既存記録保持と設定の同意撤回項目表示を確認PASS。Play配布版とは区別し、Androidの説明Dialog／取消や実承諾・実撤回は今回未実施。本人証拠は既存Android staging/audit/android-local-consent-owner-confirmed-20261026.json。詳細は正本と既存Play登録手順を参照。
- 実機証拠は既存iOS staging/audit/testflight-consent-owner-ui-final-20261026.json。従来版のAI各1件／認証／動画PASSと、同意対応版の限定実機UIを分ける。AI追加送信・trial再開始・利用枠reset・特別権限付与・既存26件の再実行は0。

### 実装・限定検証結果（2026-10-25、後続実機結果は上記）

- 通常文字AIの送信前に「AI相談の情報送信について」を表示。OpenAIへは相談文・直近会話・登録済みペット情報・関連する飼育環境／記録／センサー評価を運営サーバー経由で送ること、Pineconeへは質問由来の検索用数値ベクトルを送ることを明示する。公開Privacyを外部で開ける。「送信しない」／戻るでは送信せず、明示的な「同意して送信」でのみ既存処理へ進む。
- `AiTextConsentStore`は既存FlutterSecureStorageへUID・説明版2026-10-25-v1別に保存。schemaVersion／ownerUid／disclosureVersion／accepted／providers／purposes／acceptedAtDeviceUtcだけを持ち、相談本文やtokenは保存しない。版不一致・別UID・未同意・読書き失敗を許可済みとしない。別端末では改めて提示する。
- `AiTextConsentGate`と相談画面は、同意の読取・Dialog・保存後とHTTP直前でowner／撤回世代を確認。同意中から既存送信完了まで再入を抑止する。設定「データとプライバシー」には本人の同意だけを取り消す項目と公開Privacyリンクを追加。退会成功後も該当UIDの同意keyだけを削除する。撤回は保存済み飼育記録・会話履歴・権限を消去しない。
- 限定26件PASS（Store6、Gate7、Dialog4、実相談画面の同意5＋既存再送4）。未同意の取消／戻るではHTTP0・履歴追加0・入力保持。同意後のHTTP1、二重押下抑止、保存失敗、別UID／版不一致、再読取、撤回後の再同意、token待機中撤回のPOST0、request ID・payload固定再送を確認。全外部通信はモックで、実AI／Auth／trial開始0。静的解析はerrors／warnings0・新規指摘0（Settings既存info6は保持）。同意対応候補への実機導入や新しい実AI確認は未実施で、過去の本人PASSを転記しない。
- 同意対応の最終署名AAB／Distribution IPAは`PROJECT_STATUS.md`「Android提出物」「iOS提出環境」のconsent版。旧成果物は削除せず同意前の履歴へ分離。Functions／Rules／通常trial21日・最大20件／個人・共有予算／分析／決済・認証設定／native／locks／SDKの変更はない。
- 証拠は既存iOS stagingのaudit/text-consent-20261025-*と、Android stagingのaudit/release-aab-consent-signed-result-20261025.json等。限定テストの再実行や実AI送信を公開準備の名目で重複しない。

### 実装前の不足と、採用した最小修正案（経緯）

実装前の通常経路は専用同意分岐／記録がなく、音声同意と包括legalConsentを代用できなかった。一般同意記録は現Rulesと例外捕捉により成功を推定できない。今回、新しいサーバー同意台帳を追加せず、既存の最小案である「送信前modal／UID＋説明版別SecureStorage／設定で撤回／各await後のowner確認／固定payload再送」を採用して上記へ実装した。現server contextと送信先を照合して文言を確定し、既存の利用権限や費用枠とは分離した。一般同意・音声同意の未確認／別仕様まで修正を広げていない。

## 提出直前の実機確認

2026-10-25時点では、Appleサインイン、iOS Releaseのホーム起動・ログイン保持、更新Android APKのHome・ログイン・既存記録表示を本人確認済みです。通常体験開始と文字AI回答の本人確認は旧iOS Debug版／旧Android版の結果で、後続の本人報告により現行iOS Release／Android更新APKのAI各1件も完了済みで、再送しません。新規登録・ログアウト・削除などを含む以下の複合項目全体は、この結果だけで完了にしません。ストア申告・公開ポリシーとの一致確認も引き続き必要です。

- [ ] 新規登録、ログイン、ログアウト
- [ ] 今日の様子、体重、走行距離の保存
- [ ] 写真の登録と削除
- [ ] SwitchBot連携と解除
- [ ] AI相談履歴の削除
- [ ] Stripe Checkoutの料金・自動更新条件表示
- [ ] Stripe Customer Portalの契約確認・解約導線
- [ ] アカウント削除前の契約案内と、削除を続行できること
- [ ] アカウント削除後に再ログインできないこと
- [x] 通常文字AIの送信先・対象データの明示と事前同意、設定での撤回を最終候補へ実装し、限定26件PASS（音声同意とは別）。iPhoneのTestFlight更新・説明表示／取消／入力保持・設定の撤回項目表示は本人PASS。Androidローカル更新版の設定の撤回項目表示も本人PASS。保存済同意の実撤回は未実施。承諾後の実AI送信は今回行わない
- [ ] 公開URLがすべてHTTPSで開けること
