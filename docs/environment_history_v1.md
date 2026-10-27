# HamCare 飼育環境変更履歴 v1

策定日: 2026-10-12。ローンチ前・一般ユーザー0人。今回の対象はローカル契約・実装・検証のみ。本番、APK、全ユーザー移行、旧版専用配信、予測モデルは対象外。
進捗は[PROJECT_STATUS](../PROJECT_STATUS.md)、研究目標は[ロードマップ](predictive_analytics_roadmap.md)と[研究仕様](predictive_analytics_research_spec_v1.md)を参照する。承認済みケア入力・報酬・記録カレンダーのUXを変更しない。

## 1. 実在する環境設定と境界

既存 `BreedingEnvironment`／編集画面／保存Repositoryで扱う設定だけを履歴化する。

| 既存main_envキー | 現在値の保存形式 | 履歴・読み取りの意味 |
|---|---|---|
| cageWidth / cageDepth / cageHeight | cmの文字列（旧数値の読み取り互換あり） | 有限の正数cm。欠落・空欄・不正は数値0にしない |
| beddingThickness | cmの文字列 | 床材の深さ。ケアの床材交換量とは別 |
| wheelDiameter | cmの文字列 | その時点の設定直径。保存済みdistanceの直径を変更しない |
| accessoryTags | 既存タグの文字列配列 | 設備の種類。個数や量を推定しない |
| temperatureControl | 既存の日本語文字列 | 温度管理方式。温度実測値・温湿度履歴とは別 |
| accessoryNote / accessories | 任意メモ／旧形式の文字列 | 既存main_envの編集・読み取り互換を維持。研究用snapshotへ自由記述をコピーしない |

底面積は有効な幅×奥行きからcm²で導出し、正規化処理へ集約する。高さが不明な旧データへ35cm等の初期表示値を事実として補完しない。UIの温度管理初期値と確認済み設定も混同しない。
設備タグは現行の「隠れ家・砂場・給水器・トンネル・かじり木・登り台・温湿度計」。温度管理候補は「エアコン・ヒーター・保温球・冷却グッズ・その他」。旧値は勝手に別設定へ分類しない。
センサー認証情報、ペット名、診療、性別、多頭、設備数、研究用一括抽出は追加しない。

## 2. 保存先と所有権

- 現在値: `users/{uid}/breeding_environments/main_env`。既存キー・形式を維持し、履歴管理metadataを追加する。
- 不変revision: `.../main_env/revisions/{revisionId}`。変更前後と正規化値を独立documentへ追記する。
- mutation receipt: `.../main_env/mutations/{mutationId}`。同じリクエストの再送結果を保存する。
- 所有者はFirebase AuthのUID、個体参照は既存方式の `main_pet`。入力UID／受理日時を信用しない。
- 本人だけread。current／revision／receiptのクライアントcreate/update/deleteは禁止し、認証済み保存callableが管理する。現在値の旧client直接writeは新版リリース後に閉じる。
- アカウント削除の既存 `deleteMyAccountAndData → deleteDocumentDeep` はサブコレクションを再帰削除するため、history／receiptも通常の削除対象になる。不変性は通常の更新に対する契約であり、本人による正規削除を妨げない。

## 3. 有効時期と知識時点

環境が変わった時期とサーバー受理 `acceptedAt` を分離する。

- `unknown`: 実際の変更時期は不明。受理日時を変更日時へ置換しない。
- `date_only`: JSTの日付だけが確認済み。日内の時刻は不明で、0時を実施時刻として返さない。
- `instant`: タイムゾーンを含む実施時刻が確認済み。
- 初回snapshot: 最初の明示保存時点で確認できる現在設定の基点。これ以前の全期間を埋めない。画面表示・readでは作成しない。
- 未来の環境変更予約は拒否する。

A. retrospective: 現在までに受理したrevisionを使い、指定観測日時の環境を振り返る。
B. knowledge cutoff: 指定締切までに受理したrevisionだけを使う。10/10変更を10/12に入力しても、10/11時点の予測再現へ混ぜない。締切後の訂正・取消も除外する。

返り値は環境値に加え、根拠revision IDと不明／曖昧さの理由を持つ。対応する不変revisionに受理日時と時期精度を保存する。根拠のない過去期間には現在値を適用しない。既知の変更後は後続変更まで継続と扱うが、変更時期不明や重なる根拠がある区間は品質を落とす。

日付のみの実施区間はJSTのその日から翌日開始までとし、同日中に受理済みなら受理時刻で上限を狭める。その区間内の観測は曖昧、上限後は変更済みと判定する。時期不明の変更も受理前の期間は曖昧さを残し、受理後の確認値として扱う。`occurredAt`を午前0時や受理日時で作らない。

既存画面用currentは、実施時刻／日付区間の上限／時期不明時の受理順による運用上の投影を維持する。これは不明な変更の真の前後関係を確定する規則ではない。予測用はmain_envの投影を直接流用せず、時点APIの品質を使う。

## 4. 初回・変更・訂正・取消

初回saveで一度だけ現在確認snapshotを作る。既存main_envの以前の実環境開始日を推測しない。
実環境の変更は確認されたフィールドのpatch。入力ミス訂正は元のchange revisionを参照する新revision、取消も元のchangeを参照する新revision。過去documentを直接改変せず、初回確認snapshotは訂正・取消対象にしない。
最初の既存設定保存で値が変わる場合は、現在確認snapshotと変更patchを同じtransactionで作る。main_envがなかった場合は現在確認snapshotだけを作り、指定した日付を過去の環境開始日の根拠にしない。変更前の実環境が確認できなければ差分の前値は「不明」。日付のみの場合の前値は前日までの確認値であり、同日の直前値ではない。入力訂正の差分は以前に入力した値との比較として区別する。
時期不明または同じ有効時期への訂正は元変更の受理上限を維持し、訂正したというだけで後続の実変更を追い越さない。確認済み有効時期そのものを訂正した場合は、その訂正の受理時点で実施区間を評価する。知識締切ではいずれも締切後の訂正を除外する。
後入力や過去の訂正では、後続の有効な変更を保持する。古い全snapshotをcurrentへ丸ごと戻さない。currentと意味が同じ再保存はreceiptだけで履歴を増殖させない。確認済みの過去の同一実施時刻・同一patchの重複入力も追加しない。一方、時期不明／日付のみの20→28→20の戻し変更を、過去に20が存在しただけで重複と扱わない。任意メモが実際に変わった場合は受理revisionを保つが、履歴へメモ本文はコピーせず補助項目の変更有無だけを記録する。

## 5. 原子的保存と再送

既存ケア保存のexpectedRevision・mutation fingerprint・receipt・サーバー受理パターンを再利用する。環境とケアのModelは分ける。
current／history／receiptは同じFirestore transactionで確定。受理済み同一mutationは同じ結果を返し、異なる内容でIDを再使用すると拒否する。競合は明示し、他端末の変更を黙って上書きしない。
クライアントの保留Draftは所有UIDへ分離し、応答不明時は同じmutationを再送する。オンラインのサーバー受理結果がない状態を保存完了と表示しない。画面を開閉するだけでは保存・初回snapshot・報酬を発生させない。

## 6. 入力・履歴UI

既存飼育環境編集フォームを再利用する。短い「環境の変更／入力の訂正」、日付指定／不明、確認済みの選択状態を追加する。初期表示日付だけでは確認済みと扱わない。
同じ画面の「変更履歴」からpageを読み、日付と変わった項目だけを中心に表示する。時期不明、入力訂正、初回確認、取消を短く区別し、revision／受理時刻などは詳細へ収納する。既存AppTheme・StatusCard・入力部品を使い、文字拡大、狭幅、昼夜themeへ対応する。
Homeカード、報酬、通知は追加しない。

## 7. 分析への将来接続

将来のSilverには時点整合APIのenvironment snapshot／根拠revision／unknown reasonsを渡せる。今回Silver／Goldの計算、健康評価、readiness、Insight、不変レポート、予測モデルへ接続しない。
ケアの掃除や床材交換は環境の深さの更新ではない。関連する出来事の参照IDを将来付ける場合も別回答を自動生成しない。
過去 `distance_records` は保存済み `wheelDiameterCm` と距離を維持する。設定変更を契機に再換算・再生成しない。

## 8. 実装APIと品質

- `saveBreedingEnvironment`（認証callable）: `expectedRevision`、`mutationId`、`operation=change/correction/cancel`、環境の`values` patch、`effective={precision,dateKey?,occurredAt?}`、訂正／取消の`targetRevision`。受理結果は`revision`／`mutationId`／`changed`／`replayed`／`acceptedAt`。クライアントからUID・受理時刻・派生底面積を入力できない。
- `readBreedingEnvironmentAt`（本人の認証callable）とサーバーの`readEnvironmentAt`／純粋関数`resolveEnvironmentHistory`: `observedAt`、任意`knowledgeCutoff`。指定がなければretrospective。
- レスポンス: `values`（value/unit/quality）、`evidenceRevisionIds`、`observedAt`／`knowledgeCutoff`、`quality={unknownFields,ambiguousFields,reasons}`。`known/unknown/invalid`を区別し、数値不正を0にしない。曖昧な幅／奥行きから面積を生成しない。
- main_envの追加metadata: `environmentHistorySchemaVersion=1`、`ownerUid`、`petId`、`revision`、server `acceptedAt/updatedAt`。既存の独自キーはmergeで保持する。user rootの既存`has_subcollections` markerも維持する。
- revision: `schemaVersion=1`、所有者／個体、`revision/previousRevision`、`kind`、`targetRevision`、`effective`、`acceptedAt`、`mutationId`、ホワイトリストのraw／normalized values、per-field `changes`、前値の意味を示す`beforeValueMeaning`。任意memo・センサー認証情報は複製しない。タグは既存の日本語文字列を保持し、未登録の旧値を既知タグへ推定分類しない。新しい設備Catalogや数量schemaは追加しない。
- receipt: `schemaVersion`／所有者／個体／`requestFingerprint`／server `acceptedAt`／受理結果。receiptのfingerprintとsemanticな環境値比較は別責務。
- 一度に保存判定する履歴は最大2,000revision。超過は切り捨てて誤投影せず、原子的に停止する。時点APIは250件pageを上限revisionまで読み、20,000件超は停止。UIもpageで読み、documentへ巨大配列は保存しない。将来この運用量に近づく場合はcheckpoint契約を別途設計する。

## 9. ローカル検証とリリース前作業

- 新Backend unit: 19/19 PASS、既存Functions回帰: 49/49 PASS、Functions TypeScript `--noEmit`: PASS。
- Emulator: 環境22、環境Rules30、既存ケア／Rules48、継続貯蓄20、合計120ケースPASS。原子的保存・再送・同時編集・失敗・後入力・訂正・取消・不正旧値・503履歴のページング・本人限定権限・アカウント削除を確認。
- 保護fixtureのfirst／v1／日次reportは内容とupdateTimeが不変。新保存・時点APIから既存health／readiness／距離／AI・trial／ケア・報酬／onboardingへの直接書き込みなしを確認。current更新時の既存環境triggerは従来どおり対象となり、計算式は変更しない。Flutterの受理成功後のプロフィール完了更新も既存どおり。
- Flutter新規29件（契約6、Repository7、Widget11、Golden5）、既存関連50件PASS。対象12DartファイルのAnalyzeはNo issues。393px昼夜と320px文字1.5倍で入力・履歴を描画し、スクロール時AppBarとの重なり、訂正、保存確認待ち、履歴pagingを検証。
- 既存継続貯蓄の並行テストは混合Emulator実行でtransaction closedとなったが、独立した最終実行では20/20 PASS。関連productionコードは変更しない。
- 本番の実データ、server設定、Known Good、APK・端末は未変更。本番運用と実機UXは未確認。予測モデル・Silver接続・ユーザー横断抽出は未実装。

ローカルPASSを本番運用・実機UXの確認と扱わない。
本番適用は新保存／時点読取りcallable → 現行Rulesへ限定差分統合 → 対応Flutterの順で別途承認する。既存Functionsの一括deploy、Scheduler変更、全移行、既存historyの補完は不要。
保存callableの入口IAMはリリース時に既存の認証callable運用と合わせる。処理はFirebase本人認証を必須とし、他人のUIDを入力で選択できない。


## 10. 2026-10-12 承認済み本番・Samsung反映

- 本番project/region: hamster-breeding-app / asia-northeast1。新2callableのみ: saveBreedingEnvironment=savebreedingenvironment-00001-faz、readBreedingEnvironmentAt=readbreedingenvironmentat-00001-xel、ACTIVE100%。認証本人限定・匿名拒否・実配備9files一致を確認。既存Functions38件とScheduler2件は不変。
- 現行Rulesの環境blockだけを統合して235権限テストPASS後に反映。ruleset de6dca67-b4c2-47d4-92e5-2228f91f2bfc。clientのcurrent/history/receipt write不可、本人readを維持。新規定義のstandard callable設定はNode22/256Mi/CPU1/60秒/concurrency80/Run service max20、App Check追加強制なしで既存方針に合わせる。これらを他Functionsへ一律適用しない。
- 本番business write・初期snapshot作成・全移行なし。Bの55docが内容/updateTime不変、履歴/receiptは0件。実保存が初期snapshotの唯一の導入契機。保存上限2,000の拒否を独立したメモリ境界2ケースでwrite0確認。削除は既存再帰実装と合格済みEmulatorの削除ケースを再利用、本番削除はしない。
- 検証済みソースからAPK build・fresh署名一致・install-r・起動PASS。データ領域を保持。端末ロックによりログイン画面と正規save→再読込→履歴の実機確認は未完了。メニュー→ペットのプロフィール→飼育環境を編集→変更履歴で開く。複雑な後入力/競合/上限は既存Emulator証跡を利用し、本番へ架空記録を作らない。
- 復元情報: `/Users/gota/hamcare-deploy-staging/environment-history-v1-20261012-194309/audit/rollback.md`。受理済みhistory/receiptを削除しない。旧APKへ戻す場合も、環境直接writeを無条件再開せず、環境編集停止または同じ履歴契約を保つcallableを使う。旧Rulesetの丸ごと復元は履歴迂回を再開するため避ける。
