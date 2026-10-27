# HamCare 体重・活動量・個体属性履歴 v1

策定日: 2026-10-13。ローンチ前・一般ユーザー0人。今回は通常保存基盤のローカル実装・検証のみ。本番deploy、移行、APK、研究抽出、モデル学習は未実施。

## 1. 範囲と共通規則

共通の個体識別・受理revision・再送・本人限定権限は[観察回答履歴／個体ID](observation_history_and_subject_identity_v1.md)、時点整合は[データセット契約](prediction_dataset_contract_v1.md)、変更と知識の時間軸は[環境履歴](environment_history_v1.md)、報酬と受理の境界は[ケア記録](care_action_capture_and_continuity_v1.md)を参照する。本書は体重／活動量と既存属性の差分を定義する。

- 新しい測定の保存、編集、取消はserver callableを経由し、現在値・不変履歴・receiptを同一transactionで確定する。
- `subjectId`は既存server登録を確認する。同一個体の編集では不変。別個体への取り違え、stale revision、同mutationで異なる内容は拒否する。
- 純粋な再送は同じreceiptを返す。同値保存はreceiptのみ追加し、測定履歴やcurrent write／分析triggerを増やさない。
- 履歴に新しい分析／報酬triggerを追加しない。従来currentの正規変更だけが既存health／Insight／報酬処理へ到達する。
- 順序はserver受理revisionであり実測の時刻順ではない。欠測を0へ補完しない。研究同意は`not_assessed`。

## 2. 保存先と整合単位

すべて`users/{uid}/`配下。`kind`は`weight`または`distance`。

| 保存先 | 役割 |
|---|---|
| `weight_records/{dayKey}` | 従来の同日1件current。weightGrams(g)、memo、dayKey、dateを維持 |
| `distance_records/{dayKey}` | 従来current。distance(m)、rotations(回)、wheelDiameterCm(cm)、source、dayKey、dateを維持 |
| `{kind}_record_history/{recordId}` | server発行logical測定ID、subjectId、record revision、現在の対象日・取消状態、導入時点 |
| 同上`/revisions/{revisionId}` | 不変の数値・実測時期・操作・受理時刻・個体参照。メモ本文を測定Evidenceへコピーしない |
| `{kind}_record_days/{dayKey}` | 日次currentとの対応、day revision、過去logical IDの有界一覧 |
| 同上`/revisions/{revisionId}` | 日付移動／取消／再作成前のday対応を復元する不変索引 |
| `{kind}_record_mutations/{mutationId}` | fingerprint、受理時刻、確定result／current projection。再送・別内容拒否 |
| `pet_profiles/main_pet` | 既存profile currentとsubjectId、profile revision、profileHistoryRevision |
| `pet_profiles/main_pet/mutations/{mutationId}` | 既存profile receiptを再利用 |
| `pet_subjects/{subjectId}/profile_history/main_profile` | 属性だけの履歴revision、導入時点。名前・画像の変更で属性履歴を増やさない |
| 同上`/revisions/{revisionId}` | species／birthdayの不変patch・snapshot、訂正／取消参照、受理時刻 |

測定currentには`subjectId / recordId / revision(day) / recordRevision / timing / acceptedAt`を追加する。日付移動の競合判定は**旧日のday revision**、logical履歴の連番はrecordRevision。連番は10桁ゼロ埋めdocument IDで、両者を同じ番号と仮定しない。履歴・day索引を1documentの無限配列へ詰め込まない。

`schemaVersion=1`、`inputUiVersion=measurement_history_v1`。測定revisionはownerUid、petId=main_pet、subjectId、recordId、dayKey／previousDayKey、dayRevisions、operation、origin、inputRoute、数値valuesとvalueUnits、timing、acceptedAt、mutationIdを持つ。単位はg／m／cm／countで明示。receiptには通常保存の確認用current projection（体重memoを含み得る）があり、研究用数値Evidence／抽出と区別する。inputRouteはweight_manual／wheel_rotations_manual／distance_manual／manual_cancelで今回の受理経路を示し、旧記録の元経路は推定しない。

## 3. 時期・入力経路・値

| 対象 | 保存する意味 |
|---|---|
| 体重 | weightGrams、日付、任意user申告測定時刻、入力UI version。従来の0より大きく1000g以下という入力検証を維持し、新医学基準を追加しない |
| 活動量 | mode=rotations/direct_distance、source=wheel_manual。距離／回転数／換算直径と由来を保存。実測0は有効、未記録はcurrentなし |
| 測定timing | `timePrecision=unknown/date_only/instant`、dateKey／observedAt、confirmation、clockSource、timeZone=Asia/Tokyo |
| 活動windowMeaning | selected_day／selected_night_to_next_morning／unknown。夜〜翌朝は開始終了が分からないためtimePrecision=unknownを維持 |
| 種類 | 現行日本語speciesをそのまま保持。不明や別種を勝手に推定しない |
| 生年月日 | dateKey、precision=date_only/approximate_date/unknown/legacy_unspecified、quality。年齢は保存せず評価日と知識締切付き生日から導出 |

従来`date`は日次表示・queryのためのindexで、測定時刻ではない。date_onlyを午前0時の実測に変換せず、保存時刻も実測に代入しない。時刻ありはuser_reportedでありserver時計の実測証明ではない。

活動dayKey=Sは既存pipelineで「S日の完了した活動」として扱い、健康評価DはS=D-1を使用する。既存「昨日」「昨晩〜今朝」表示から厳密なcoverageや開始終了時刻を捏造しない。手入力では記録日と実測期間を区別し、期間不明を許容する。測定期間の回答は要求しない。新規走行記録は既存のunknown契約で保存し、開始・終了時刻や暦日全体を推定しない。同日の編集では保存済みの期間を維持し、記録日を選び直した場合は当該日の記録を読み直す。別の日の具体的な期間を引き継がない。活動記録の日付移動は引き続き未対応。

回転→距離は既存式`回転数×π×直径cm÷100`をserverの一か所へ集約し、既存Repositoryの表示用previewを維持する。1000回転／20cmは628.3185307179587m。新規記録だけ現行main_envを参照し、編集は記録内の元直径を保持する。直径の訂正を明示した場合のみ再換算。旧直径が不明な回転記録は確認を求め、現在直径へ黙って置換しない。直接距離入力では回転数／直径はnullとし、旧回転値の残留を防ぐ。

現行の測定writerは2つのFlutter Repositoryで、別のsensor自動書込経路は今回の対象コードには存在しない。新センサー連携は追加しない。

## 4. 初回・訂正・取消・旧記録

- 旧currentにsubjectIdや履歴がない場合は表示を維持し、明示確認saveでのみ導入する。旧内容が同じならconfirmed_legacy_snapshot、内容を訂正したならlegacy_unknown_original。いずれも導入前の初回受理／旧訂正履歴を捏造しない。
- 旧個体対応が未確認のまま取消・日付移動はしない。短い確認保存で対象個体と現存値を確認した後に扱う。画面を開くだけでは書かない。
- 通常編集はcorrection。体重の日付訂正はdate_correctionとして旧日current削除、先日current作成、両日の履歴索引を同transactionで確定する。訂正先に有効記録があれば拒否し上書きしない。既存活動UIには日付移動導線がないため、その新機能は追加せずserverでも拒否する。
- 取消はrevisionを追記してcurrentを削除し、tombstoneとreceiptを残す。取消後readは前値を復活させない。その後の明示的な新規記録は新logical IDで扱い、以前の取消状態は知識締切で取得できる。
- 属性初回snapshotは保存時点で確認されたspecies／birthdayだけ。種類／生日の更新は生物学的変化ではなく入力訂正。`saveMainPetProfile`を拡張し、独立したwriterは作らない。
- 属性の訂正取消は対象history revisionを参照して追記する。初回snapshotは取消対象にせず、後続の有効patchを保つ。同個体の名前・画像編集でsubjectIdは変わらない。
- 既存生日に精度がなければlegacy_unspecified。不明生日はnull。画面で編集しないだけでは確定生日へ昇格させない。近似日はapproximate_dateの品質を残す。
- 個体入れ替えUI・全件移行・過去への一括ID付与は追加しない。取消でcurrentが消えても測定ledgerが残れば既存replace guardで混合を拒否する。

## 5. 知識締切付きread

`readMeasurementHistoryAt({kind,dayKey,knowledgeCutoff?})`と`readMainPetProfileHistoryAt({subjectId,evaluationDateKey,knowledgeCutoff?})`を追加する。caller UIDはAuthから取得し、本人の登録を確認する。cutoff未指定は現在の知識での振り返り、指定は受理済みrevisionだけの再現。ISO締切は小数9桁まで、または`knowledgeCutoffEpochNanoseconds`文字列を使い、Firestore受理Timestampをmillisecondへ丸めて早期採用しない。

| 架空の受理履歴 | 12:00締切 | 16:00締切 |
|---|---|---|
| 10:00に100g、15:00に入力ミスを105gへ訂正 | 100g／revision1 | 105g／revision2 |
| 10:00に生日を確認、15:00に訂正 | 旧生日から評価日の年齢 | 訂正生日から評価日の年齢 |
| 10:00保存、15:00取消 | 保存された値 | cancelled／値なし |
| 測定は昨日、受理は今日15:00 | 受理前は利用不可 | 実測時期と受理を分離して返す |

測定readはkind、dayKey、recordId、subjectId、recordStatus、current／revisions、根拠番号とacceptedAt、nanosecond、valueUnits、qualityを返す。属性readはvalues、age(days／monthsと精度)、evidenceRevisionIds、最新revision、qualityを返す。履歴導入前、時刻不明／日内曖昧、legacy_original_unrecoverable等を返し、currentで過去を埋めない。プロフィールの過去cutoffを現在プロフィールへfallbackしない。

日別Silverはcurrentからの既存計算を維持するが、その最新版は過去予測時点の入力証明ではない。source履歴とSilverを別々の実測として二重計上しない。研究用replay／予測snapshotは未実装。

## 6. UIと保存状態

既存WeightInputCard／WheelRotationInputCard、プロフィール編集画面を再利用する。体重の測定時期は日付のみ／不明／時刻を確認という短い部品で、時刻必須にしない。走行入力は「日付の確認→回転数入力→保存」とし、測定期間の選択・必須確認・代替ダイアログは設けない。活動量の元直径が不明な場合だけ短い訂正入力を使用する。大型の履歴画面やUI刷新を追加しない。

Modelがcurrentと履歴を型付け、共通MeasurementHistoryClientがcallable／owner別pendingと同mutation再送／receipt確認を管理、Repositoryが従来読み取りと保存APIを維持、共通MeasurementInputViewModelが体重のtiming選択と数値・失敗文言を整形、Widget／Screenは入力と配置を担当する。数値換算はRepository／serverで行いScreenに複製しない。

保存確定は正しいmutationId、対象日・個体、revision、acceptedAt、projectionを持つserver結果で判定。送信中／同期待ち／競合／拒否を区別し、失敗時は入力を保持する。pendingはownerとkindで分離し別内容を勝手に同mutationへ差し替えない。明示拒否はpendingを解除するが入力は消さない。

## 7. 権限・削除・上限

current／history／day索引／receiptは本人readのみ、client create/update/deleteは禁止。saveは既存trial／billingの記録利用権限をtransaction内で確認し、既存owner取消権限を維持する。プロフィールは従来本人限定保存を維持する。汎用の広範なallowを追加せず、履歴のnested revisionも明示保護する。

既存のアカウント削除はuser subtreeを再帰削除し、追加ledger／revision／receipt／profile subtreeも対象。Emulatorで別owner保持を検証し、追記型を理由に正規削除を拒まない。

1logical測定履歴／日索引／属性履歴の判定は最大2,000revision。超過はresource-exhaustedで原子的に停止し、current単独更新・履歴切捨てで回避しない。運用量が近づく場合のcheckpoint設計は別工程。

## 8. ローカル検証とリリース条件

詳細件数・失敗原因・描画結果は[PROJECT_STATUS](../PROJECT_STATUS.md)を参照。変更範囲のFunctions Unit／localhost demo Emulator／Rules／正規削除、Flutter Repository／Widget／Golden／Analyzeを検証する。同mutationの競合条件は維持し、意図的なabortedと部分保存を区別して確認する。

本番適用時は新callable `saveWeightRecord / saveDistanceRecord / readMeasurementHistoryAt / readMainPetProfileHistoryAt` と既存`saveMainPetProfile`の属性履歴拡張を隔離sourceから反映し、限定Rulesで旧直接writeを閉じて、対応Flutterへ揃える。既存health／Insight／reward Functionsのソース変更は不要。アカウント削除の既存再帰契約は維持。現行本番と設定／Rulesを照合して復元手順を用意し、受理済み履歴を削除したり旧直接writeを無条件に再開しない。今回は実行しない。

## 9. 次工程と未確定事項

sensor coverage、独立測定時計、センサー稼働／測定方式の完全履歴、属性以外の過去profile復元、ケア／環境旧記録のsubject対応は未対応。性別・繁殖／診療情報、多頭UI、個体入れ替えUIは新設しない。

研究同意／撤回運用、label確定締切と取消後選択、feature鮮度、Prediction Readyの数値、モデル採用・学習・shadow／RCTは未確定または未実施。通常記録の受理は研究利用の承認ではない。既存健康式、baseline、Insight、不変first／v1／日次レポート、課金／AI／オンボーディング、たくわえ／記録カレンダーを保護する。

## 10. 2026-10-15 本番リリース記録

本番サーバーPASS、端末工程を含む全体PARTIAL。

| export | ACTIVE revision（traffic100%） |
|---|---|
| saveWeightRecord | saveweightrecord-00001-mob |
| saveDistanceRecord | savedistancerecord-00001-muc |
| readMeasurementHistoryAt | readmeasurementhistoryat-00001-feb |
| readMainPetProfileHistoryAt | readmainpetprofilehistoryat-00001-hiq |
| saveMainPetProfile | savemainpetprofile-00002-nev |

- Project `hamster-breeding-app` / `asia-northeast1`。新callable4件と既存saveMainPetProfileのみ反映し、全5 ACTIVE・traffic100%、配備src/lib/package（30files）が隔離候補とbyte一致。対象外42 Functionsのresourceは不変。既存profileはsource限定updateでIAM2種・env・timeout・memory・concurrency等を維持し、Function/revision上限の未指定→20だけが既承認差分。Run serviceの実効上限20は不変、未設定復元作業なし。親・解析子Node22.23.1を確認。
- 現行配備ZIPを基準に検証済み4source差分のみ反映し、未反映の別35moduleを除外。package/lock/Catalog正本・生成物を保持。既存の観察／ケア／環境履歴、カレンダー・UIを取りこぼさない。新callableは既存Auth必須・App Check採用方針を維持し、匿名5入口の401 UNAUTHENTICATED拒否をDBアクセス前に確認。
- 現行本番Rulesのpet_subjects／weight／distanceの3blockのみ統合、他の権限byteを保持。限定Rules11＋既存再帰削除1の専用Emulator12/12 PASS。反映Ruleset `2f51e7b6-275e-4222-842b-666e81397f9f`、SHA256 `96eefd88361fdb67117e65630ae02bc0e889db2496356b7538721f71e2d829c5`一致。履歴・受理日時・receiptは本人read/server-only write、current直接writeの迂回を閉じた。新Index/Scheduler/既存triggerの変更なし。
- サーバー反映前後、Test User Bの既存88文書は内容hash・createTime・updateTime／collection件数不変。記録変更、subjectId強制初期化、履歴全件生成、報酬初期化、既存first/v1/日次report再生成なし。履歴は正規UIの明示保存時から開始し、初回以前を推定しない。正規削除は現行実装が追加17pathsを再帰削除し別owner17を保持することをlocalhost/demoで確認、本番削除なし。
- APK build `PASS`、署名 `not_connected`、install `not_attempted`、起動 `not_attempted`、login `not_inspected_not_connected`。APK `/Users/gota/hamcare-deploy-staging/measurement-profile-history-v1-20261015-194924/flutter/build/app/outputs/flutter-apk/app-debug.apk`。通常ソース／依存versionは未変更。既存Gradle cacheの欠落を切り分け、各中断・失敗ログを残し、必要な生成cacheを隔離して再生成した。詳細試行記録はaudit/apk-build-result.json／audit/device。アンインストール・data clearなし。人間による実際の測定保存・再読込は未実施。
- 今回APKは前回リリースAPKと署名一致。最終ADB確認は端末0件のため、現在インストール済みアプリとの新たな署名比較・上書き更新・起動・login確認は未実施。接続後は端末更新だけを再開し、成功済みサーバー作業は繰り返さない。
- 実機導線：Home下部＋→体重／走った記録。プロフィールは左上メニュー→ペットのプロフィール→必要ならプロフィールを編集。正しい種類／生日は閲覧だけでよく、保存確認は実際に追加／訂正する記録1件だけ。架空の値・取消・日付境界を本番で再現しない。
- 退避・復元: `/Users/gota/hamcare-deploy-staging/measurement-profile-history-v1-20261015-194924`（audit/rollback.md、baseline/backend/security/device/data）。旧profile revision/sourceは復元証跡だが属性履歴に未対応のため無条件にwriterを戻さず、編集停止または互換性のある修正と連携する。生成済み履歴を削除せず、旧Rules／旧APKの直接保存を無条件再開しない。dirty code・Known Goodを保護、Git操作なし。研究抽出／モデル／同意付与／ラベル確定／センサーcoverage／新属性UIは未実施。


## 11. 2026-10-15 手入力走行UXの簡素化

- 走行入力の「回転数を測った期間」プルダウン・必須確認・画面内timing stateを撤去。「日付の確認→回転数入力→保存」に戻し、代替dialog／別の期間入力は追加しない。距離preview・編集・取消・直径訂正、旧記録の個体確認と同期待ち再送は維持。
- DistanceRecordsRepoで新規／期間未保存を既存unknown契約に統一し、記録日から暦日coverage・夜間・午前0時・保存時刻を実測期間として作らない。同日の既存timingは保持。日付選択は対象日のcurrentを読み直し、別の日の期間は継承しない。従来どおり活動のlogical日付移動は未対応。最新の競合recordを確認した後も、古い画面のtimingを上書きしない。
- 関連Widget／Repository／quality／Golden計55件PASS（新規13、走行Golden2更新・体重Golden不変を含む）、変更2production＋関連5test Analyze No issues。初回44PASS/11FAILはテストのFilledButton.icon探索と入力後pump不足であり、検証helperだけを修正して同じ一式55件を再実行PASS。失敗ログをaudit/attempt1-related-tests.logへ保全。393px darkと320px文字1.5倍の描画を目視確認。
- 検証済み隔離sourceのproduction差分は走行Widget／Repositoryの2件のみ。APK build PASS（72.84秒）、端末現行署名 PASS、install-r PASS、起動 PASS、login PASS。APK `/Users/gota/hamcare-deploy-staging/distance-period-ui-20261015-212721/flutter/build/app/outputs/flutter-apk/app-debug.apk`。前回成功のFlutter/JDK／隔離Gradle cache・依存versionを維持。アンインストール・data clear・本番記録の試験保存なし。
- サーバー既存unknown契約で保存可能なためFunctions／Rules／Firestore／Scheduler変更・deployなし。履歴・受理時刻・subjectId・receipt・報酬、健康評価・Insight・課金・AI・onboardingは変更せず、Known Good未変更、Git操作なし。現在のdirty treeは対象fileの開始hash一致を確認して最小反映。設計はdocs/measurement_and_profile_history_v1.mdへ追記。証跡・今回変更前file退避: `/Users/gota/hamcare-deploy-staging/distance-period-ui-20261015-212721`。
