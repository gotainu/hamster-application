# HamCare 予測用データセット契約 v1

策定日: 2026-10-12。文書版: v1.8（2026-10-16：研究初版の窓・L・主ラベルの採用済み決定を反映、§6）。**実データの抽出／dataset生成・研究実行・モデル実装／学習・シャドーは未実施。架空データの技術検証と、研究実行の承認を分ける。**
長期方針は[予測分析ロードマップ](predictive_analytics_roadmap.md)、研究手順・倫理・Gateは[研究仕様 v1](predictive_analytics_research_spec_v1.md)、適用状況は[PROJECT_STATUS](../PROJECT_STATUS.md)を参照する。

## 1. 決定状態と研究目的

**今回合意された方針**: 初期の主目的は、予測時点までの情報から、その後の飼い主の明示的な全体観察回答「いつも通り／少し違う／心配」を予測すること（T-O）。活動量の数値予測（T-A）は補助モデル候補として保持する。研究仕様のC-01／P-12にあった優先関係は、このユーザー指示で更新する。特定モデルの採用・研究実行の承認とは異なる。

- 回答は `condition=normal / slightlyConcerned / veryConcerned`。順序コード候補は0／1／2で、疾病診断・発症・健康の真値ではない。
- 獣医師確認済みの診断ラベルは独立した将来契約。`veryConcerned`を疾病あり、`normal`や未回答を疾病なしへ転用しない。
- 既存Medallion・健康評価式・中央値／MAD／EWMA・共通Insightを再利用し、不変のfirst／v1／発行済み日次レポートと予測snapshotを書き換えない。
- 以下の**論理フィールドは将来のデータセット契約案**。同名のFirestore保存先・APIが実装済みであることを意味しない。現行保存の事実は§4、推奨規則は§5〜9、実行前の未確定事項は§12へ分ける。
- **研究初版で採用済み**：T0=09:00 JST、T1=翌09:00 JST、窓=(T0,T1]、L=T1+24時間。主ラベルは選択した観察の初回回答、訂正版は比較／感度分析用。Lまでの取消は欠測とし、後続観察へ自動差替えしない。24時間は現時点の運用値で、将来の実データ評価に基づきpolicy versionを上げて変更できる。これは実データ抽出・研究実行の承認とは別。既存の09:00 JST日次レポートSchedulerは変更しない。

## 2. 1行の単位と3つの時刻

基本単位は **確認された個体 × 予測基準時刻 `T0`**。同じキー・仕様で1行を一意にする。

| 意味 | 論理フィールド／推奨定義 |
|---|---|
| 予測基準時刻 | 第一案はD 09:00 JSTの`predictionReferenceAt=T0`。UTC絶対時刻と`Asia/Tokyo`を保持。遅延実行の時刻は別metadata |
| 特徴量の情報締切 | `featureKnowledgeCutoffAt=T0`。サーバーで受理され利用可能だったrevisionのみ。別締切にするなら別仕様version |
| 予測対象期間 | 研究初版の採用済み規則では `targetWindow=(T0,T0+24h]`。左端を含まず右端を含む。JSTの翌暦日と同一ではない |
| 観測日時 | `observedAt`、または `observedInterval`／`observedDateKey` と精度。実際の測定・申告対象の時期 |
| 情報の受理／利用可能時刻 | `serverReceivedAt`／`availableAt`。既存の信頼できるserver commit timestampを根拠にする。端末時計と研究側取込時刻は代用不可 |
| ラベル確定時点 | `labelAdjudicationAsOf`。研究初版はL=T1+24時間。イベントの取込完了・取消等を判定する独立時点 |

`observedAt <= T0`だけでは入力適格にならない。後入力は受理前の知識には存在しない。期間集計を特徴量にする場合はその観測区間の上限もT0以下であること。継続中の申告は「締切までの申告」として分け、閉じた1日集計へ置換しない。

## 3. 行・特徴量・目的変数の論理契約

| 区分 | 必須の情報 |
|---|---|
| 行識別 | `rowId`、`ownerResearchKey`、`subjectResearchKey`、`subjectEpisodeId`、`identityMappingVersion`、`subjectIdentityStatus` |
| グループ分離 | `ownerGroupKey`、確認できる場合の `householdGroupKey`／確認状態。研究キーとAuth UIDの対応表はアクセス制限された別管理 |
| 時点 | T0、特徴量締切、対象期間の開始／終了・開閉、timezone、基準時刻の決定方法version |
| 特徴量 | `featureId`、値／単位、観測時期／精度、受理／利用可能時刻、source logical ID／revision／操作、入力仕様version |
| 根拠と品質 | 採用した実測ID一覧・日数／区間、根拠revision、情報の経過時間、鮮度基準version、欠測・不正・日内曖昧さ・履歴不完全の理由 |
| ラベル | 明示全体回答のenum、logical answer ID、original revision、対象日時／精度、original受理時刻、回答出所、訂正／取消参照、確定時点／状態 |
| 再現性 | `datasetSpecVersion`、`featureSpecVersion`、`labelSpecVersion`、Catalog／正規化／品質／split／同意／identityのversion、source manifest ID／digest |
| 採否 | `rowDisposition=include / exclude / hold`、`reasonCodes`、必須特徴量の適格性。任意特徴量は欠測を保った採用が可能だが、事前にfeature仕様で定める |
| 研究適格性 | 用途・同意scope／version／有効期間、撤回／削除制限、対象研究protocol、入力UI・gamification policyの根拠／不明状態 |

`revision`がない旧記録へ架空の連番を付けて受理済み履歴を装わない。抽出時digestは読み取った内容を識別できるが、過去の存在や訂正前の状態を証明しない。

### 3.1 現在の個体参照の限界

`users/{uid}/pet_profiles/main_pet` と、ケア／環境履歴の `petId=main_pet` は同じアカウント内の**保存スロット**を結び付ける。2026-10-13のローカル保存基盤で、新規明示保存にserver発行の `subjectId` と個体登録を追加した（§13）。属性の有効期間・全revisionは未対応。導入前の個体同一性は証明しない。

- `uid + main_pet`だけで全期間を同一個体と断定しない。名前・誕生日の類似だけで同一性を推定しない。
- 将来は飼い主が確認した個体ID／個体episode、有効期間、元記録との対応versionが必要。入れ替わりは新episodeへ分離し、曖昧な境界の記録は保留する。
- 旧記録は `subjectIdentityStatus=slot_only / ambiguous` 等を保持。個体同一性が必須の主解析には採用せず、確認できる区間だけを別途登録する。
- 個体名、email、画像、memo、認証情報は学習行へコピーしない。仮名化は匿名化完了を意味しない。世帯が不明なら「世帯独立に検証済み」と主張しない。

## 4. 現在のデータ源と利用制限（ローカル保存契約の事実）

**現在値が読めること、過去の知識締切を復元できること、研究同意があることは別条件。今回、本番データを読んだり抽出したりしていない。**
以下のpathは `users/{uid}/` 配下。型・時刻は保存側を根拠にし、UI fallbackを除外する。表の体重／活動／checkin／profileとセンサーの不足は旧保存契約・導入前の範囲を示し、追加保存契約と確認状況は§13〜15を優先する。旧記録の不足は履歴導入によって遡及解消しない。

| データ源 | 実在する主なフィールド／単位 | 時刻・履歴 | 過去のT0での利用可否／不足 |
|---|---|---|---|
| `weight_records/{dayKey}` | `weightGrams`数値g、`dayKey`、`date` | `date`は端末のローカル日付開始をUTC化。server `createdAt`初回／`updatedAt`、同日merge上書き | 実測時刻ではない。上書き／削除前の値、受理revision、timezoneなし。現在値だけで完全なPIT再現不可 |
| `distance_records/{dayKey}` | `distance`数値m、`source`。回転入力では `rotations`回、`wheelDiameterCm`cm | 日付開始の`date`、server `createdAt`／`updatedAt`を毎save設定。履歴なし | 初回受理や前版を復元不可。直接距離入力後に旧回転項目が残る可能性もありsource整合を検証。保存済み距離／直径を維持し現在直径で再換算しない |
| `switchbot_readings/{id}`（旧形式／根拠導入前） | `ts`、`temperature`℃、`humidity`%RH、`battery`、`source=status` | 現行writerの`ts`はAPI応答後・保存直前のプロセス時計ISO。server `createdAt`はcommit時刻。この旧形式では機器測定時刻、device／経路／予定枠・immutable receiptが不足 | 保存記録の分布と受理済み情報に利用を限定。独立実測・鮮度・予定取得成功率・過去の個体対応は保証しない。[取得品質契約 v1](sensor_coverage_contract_v1.md)で現行60分と追加根拠案を区別 |
| `daily_checkins/{dayKey}` | `condition`、`concernTags`、`observationLevels`、`schemaVersion=2`、`observationCatalogVersion`、`observationResponseMode=overall_with_selected_tags` | 日付開始の`date`、初回server `createdAt`／`updatedAt`、同日merge上書き | 全体conditionは明示回答。項目normalの自動生成は明示回答ではない。独立提出ID／訂正／取消／受理履歴・観察時刻がなく、最初の回答を現在docから復元不可 |
| `daily_care_actions/{dayKey}` | `actions`、`status`、`revision`、`previousRevision`、`mutationId`、`schemaVersion`、`catalogVersion`、`inputUiVersion`、`inputRoute`、`gamePolicyVersion` | server `acceptedAt`。不変 `revisions/{revisionId}`＋`mutations/{mutationId}` | 締切までの受理revisionを選べる。各actionの `occurredAt=null`、日付精度／出所／部分期間を保つ。個体同一性・実施時刻は別条件 |
| `breeding_environments/main_env`＋revisions／mutations | 幅／奥行き／高さ、`beddingThickness`、`wheelDiameter`は旧cm文字列と正規化値。`accessoryTags`、`temperatureControl` | `effective`のunknown／date_only／instantとserver `acceptedAt`を分離。追記訂正／取消 | knowledge cutoff APIで当時受理済みの根拠revisionを取得可能。初回snapshotを受理以前へ遡及適用しない。過去の各項目は別の受理済み変更根拠とqualityで判定。日内の曖昧さを消さない。タグは種類で数量ではない |
| `pet_profiles/main_pet` | `species`日本語、`birthday`Timestamp／旧文字列。`name/color/imageUrl`は原則入力対象外 | server `updatedAt`、現在値merge。属性revisionなし | 種・年齢は確認済みversionがT0までに存在する区間のみ。誕生日不明は年齢不明。sex／繁殖状態／個体入れ替わり履歴は未保存 |
| Silver／Gold | `daily_health_features/{dateKey}`、personalBaseline、体重／観察Evidence、`health_assessments`、`individual_insights/{dateKey}` | Silverは再計算merge、`generatedAt/updatedAt`。`environment_assessments_history`も日別merge。不変reportは生成時点だけ | 最新再計算版を過去T0の入力へ使わない。既存source readerは日付窓でありknowledge cutoff readerではない。不変reportを現在分析の代用にしない |

### 4.1 保存の意味をそのまま保持する

- 観察Catalogの現行IDは `appetite / water / elimination / breathing / movement / eyesNose / coatSkin / other`。`poop→elimination`、廃止項目、未知ID、Catalog versionを既存規則で扱う。今回のwriterは `answeredObservationIds`／`explicit_items_v1`を保存していないため、将来互換形式を現行の明示項目回答と誤認しない。
- ケアの `answerProvenance=item_selection / batch_confirmation / unanswered`、旧 `legacy_unspecified`を維持。未確認初期値や「様子だけ」のsaveをケア回答へ変換しない。
- `cageCleaning.cleaningType=spot_removal / partial_cleaning / deep_cleaning`、`beddingReplacement=none / partial / almost_all` は独立。旧 `scope=spot/full` を新区分へ推測分類しない。ケアの床材交換から環境の床材深さを更新しない。
- 散歩の `durationMinutes` は日合計の申告（正数1〜1440分）。0分は `not_performed`、実施したが時間不明は時間欠測。`nonPerformanceScope=up_to_acceptance` の朝の非実施回答は、その日終了までの0分ではない。正数も受理時点の申告であり、確定した全日計測coverageを保証しない。
- 環境は既存 `readBreedingEnvironmentAt`／`readEnvironmentAt`／`resolveEnvironmentHistory` の**knowledgeCutoff指定**を利用する。retrospectiveは研究時点再現の代用不可。既知の変更後を後続変更まで継続扱いにする既存規則とqualityを保持し、現在値を根拠のない過去区間へ延長しない。初回snapshot自体は受理以前の根拠にせず、別の受理済み変更がある場合は各項目をquality付きで判定する。底面積は既存正規化による幅×奥行きcm²を再利用する。
- センサーの `tempRatio/humRatio` は取得sample中の適合割合であり計測coverageではない。`sourceDocCount`を無条件に有効件数にせず、旧 `dangerMinutes`を実測暴露時間と呼ばない。予測入力には窓内・指標別の有効sample数、期待sample数／取得予定、停止・遅延、clock品質が必要。予定不明ならcoverageはnullと理由を保存する。
- UIの欠落condition→normal、値→0、species→シリアン、date→今日などを研究の事実へ使わない。初回受理analyticsや達成日の証拠は全実測revisionの代替にならない。

保存経路の根拠: [weight](../lib/services/weight_records_repo.dart)、[distance](../lib/services/distance_records_repo.dart)、[checkin](../lib/services/daily_checkin_repo.dart)、[回答出所](../functions/src/health/checkinInsights.ts)、[care](../functions/src/careActions/careActions.ts)、[環境時点API](../functions/src/environmentHistory/environmentHistory.ts)、[属性](../lib/models/pet_profile.dart)、[sensor writer](../functions/src/index.ts)、[現行entryから未参照の旧sensor helper](../functions/src/switchbot.ts)、[Silver保存](../functions/src/health/healthPipeline.ts)、[既存reader](../functions/src/health/firestoreReaders.ts)。保存の意味は[ケア設計](care_action_capture_and_continuity_v1.md)、[環境設計](environment_history_v1.md)、[観察設計](checkin_insights_phase3.md)を参照。

## 5. Point-in-time correctnessと欠測の規則（推奨）

1. sourceごとに `availableAt <= T0` の受理revisionを選び、同じlogical記録の再送・訂正を重複計上しない。削除／取消も締切以前の受理状態を反映する。締切後の訂正を当時の入力に混ぜない。
2. 日付だけはtimezone付きの**可能区間**として保持し、0時・正午・受理時刻を架空の実施時刻にしない。区間が締切をまたぐ場合、完全な観測窓が必要な特徴量には使わず曖昧さを返す。申告情報として使う場合も区間・部分期間を明示する。
3. raw実測IDを1回だけ数える。Silverの同じ日別値、EWMA、baseline、複製snapshotを新たな測定として加算しない。採用した実測一覧と重複排除キーを保持する。
4. 欠測、未回答、不正、取消、履歴不完全、鮮度不足、日内曖昧を理由別に保存する。0／normal／非実施へ補完しない。品質検証済みの実測0は欠測と区別する。
5. 情報の古さは実観測区間と受理時点を分けて測る。許容鮮度・必須特徴量・未知値の扱いはfeature仕様で登録し、今回一律の数値閾値を確定しない。
6. 目的変数と同じlogical観察回答から得た `concernTags`、`observationLevels`、健康スコア、Silver／Insight等は入力禁止。受理後に生成されたものも同じ回答の予測へ遡及利用しない。過去の別回答は時点と出所を検証できた場合だけ入力候補。
7. profile／環境は締切時点の確認済み根拠を使い、不明種・性別・年齢を推定しない。属性の後日訂正を過去へ投影しない。
8. 将来の周期長・位相・振幅はT0以前の有効観測だけから推定し、fit期間・asOf・誤差・基準epoch・推定仕様を保存する。4日周期や位相を自動付与しない。活動周期から発情周期を認定せず、対象種／性別／繁殖状態と独立確認は別根拠。
9. 活動量予測の残差を将来入力にするなら、その予測の作成時点・当時のモデル／学習cutoffと、T0までに受理済みの実測が必要。将来の対象期間の実測や全データfitによる残差は禁止。今回は残差／周期モデルを実装しない。

### 5.1 Silver再利用の2方式を区別する

- **実運用snapshot**: T0で利用可能だったSilver／Goldのversionと根拠を不変の入力snapshotへ保存する案。生成／利用可能時点もT0以下であること。
- **研究用causal replay**: 完全な受理revision履歴をT0で切り、既存Silver計算を固定仕様で再実行する将来案。実行時刻が後日でも `informationAsOf=T0` を根拠で検証できる必要がある。replay時刻と当時の実運用結果を区別する。過去の欠落revisionを現在値で補えない。
- 学習された正規化・欠測処理・周期推定パラメータ等は学習fold内でfitする。新しい医学的評価やbaseline式をこの契約だけで導入しない。

## 6. 予測窓・ラベル選択・確定（窓・L・ラベル値は研究初版で採用済み）

### 6.1 窓と遅延実行

研究初版の採用値は `T0=D 09:00 JST`、`T1=E=D+1 09:00 JST`、**`targetWindow=(T0,E]`**。T0ちょうどを含まず、Eちょうどを含む。連続する日窓で同じ境界観察を二重にラベル化せず、T0以前の既知情報と将来観察を分けられる。代替の`[T0,E)`も可能だが、T0回答を特徴量と目的変数の両方に使わない別規則・別versionが必要。研究初版ではこの窓を採用済みで、代替窓は採用していない。

特徴量は観測区間とserver受理／`availableAt`がT0以前のものだけ。遅延実行してもT0・E・feature cutoffを現在時刻へ動かさず、`executionStartedAt / generatedAt / informationAsOf`を分離する。T0後の情報を遮断して再現できれば**後日のcausal replay候補**、再現不能ならhold。後生成を「T0に実際に出した前向き予測」と呼ばない。将来の前向き試験ではon-time／late／missedを記録し、未承認の遅延許容値を設けない。これは研究の切り分け案で、既存Schedulerへ接続しない。

### 6.2 最初の適格回答をどう選ぶか

今回の第一案 `next_eligible_observed_response_24h` は、**窓内に観察されたことを確認でき、窓内にoriginalが受理された、新しい明示全体回答**を対象とする。確認済みの同一個体、有効な3値condition、logical observation ID、original受理revision／出所が必要。user_reportedの観察時刻は申告であり、独立時計で検証した実測時刻とは扱わない。日時の全可能区間が窓内と判断できないものは、主ラベルの適格性を推測しない。

**「最初」はoriginalのサーバー受理時刻順**を推奨する。観察時刻は窓内適格性に使い、順位には使わない。「次にアプリが知る適格回答」という課題と、信頼できる受理順の根拠に合わせるため。受理の同時刻で順序を証明できなければholdとし、ID辞書順で実際の順序を捏造しない。受理順が先の潜在候補に観察時期・個体対応等の未解消の曖昧さがあれば、後の確実な回答を黙って「最初」にしない。Lまでholdし、Lでも解消できなければ`missing_eligibility_ambiguous`として主ラベル欠測にする。

| 案／状態 | 意味・判断理由 |
|---|---|
| **候補選択の第一案（窓は採用済み）** | 観察・original受理の両方が`(T0,E]`、受理順で最初。予測前の観察の後入力を将来観察と呼ばない |
| 旧v1.4案を代替として保持 | 受理窓だけで選ぶsubmitted-answer。提出行動を予測する課題としては成立するが、08時観察→13時提出も候補になり、予測後の観察とは言えない |
| 観察時刻順の代替 | 最初に行われた観察を狙えるが、申告時計・後入力による順序逆転・時刻不明が影響する。別endpoint／labelSpecが必要 |

これは**旧案の厳密化という変更提案**であり、既存ラベル／保存記録を変更した事実ではない。推奨labelSpec識別子は`next-eligible-observed-response-24h-proposal-v2`。窓・L・主ラベル値の採用済み決定は§6.4を優先し、候補適格性・同率等の未決細則は引き続き別途記録・事前登録する。

### 6.3 ケース別決定表

以下は主案の選択規則。**主ラベルは採用済みのas-submitted（選択した観察の初回申告値）**とし、「最初のボタン入力」と「訂正後の観察回答」の目的を混ぜない。訂正版は比較／感度分析用に別labelSpecで保持する。暫定候補と確定後の学習採用を区別する。

| ケース | 第一案の処理 | 代替／注意 |
|---|---|---|
| 窓内の新しい観察1件 | 観察時期・original受理・同一個体・明示性を検証して候補。確定時点Lの有効性確認を待つ | 提出時刻だけでは観察がT0後と判断しない |
| 複数の新しい観察 | 適格originalの受理順で最初。後の観察は別履歴として保持 | 最後／最も心配な回答を自動選択しない |
| 同じ観察の訂正・再送 | logical IDを同一としてdedup。主値は初回値、訂正有無・revision・受理時刻・訂正後値をoutcome履歴へ参照。観察時期等の訂正で適格性が崩れればhold／無効化し、黙って別回答へ替えない | Lまでの最新有効訂正値は比較／感度分析用。初回回答の主ラベルを自動置換しない |
| 選択候補の取消 | Lまでの取消を確認したら`labelStatus=missing_withdrawn`、次の回答へ自動差替えしない。監督学習から除外、欠測理由を保持 | 次の未取消適格回答を再選択する案は「first surviving」へ課題変更。欠測は減るが回答頻度による選択偏りがある |
| E後の遅い提出 | 観察が窓内でも`late_submission`として主窓不採用。数日後の回答を翌日の代用にしない | 観察窓だけを固定し遅延受理を許す研究は、別の受理上限・labelSpecが必要 |
| 観察日だけ／時刻不明 | 可能区間が窓境界をまたぐなら`observation_time_ambiguous`。L前はhold、解消できなければ主ラベル欠測として除外 | 現行の9時区切りでは暦日だけの回答は通常境界をまたぐ。0時・正午・提出時刻を代入しない。通常記録としての有効性は維持 |
| 適格回答なし | E／取込完了・L判定前はhold。確定後は`label_missing`として監督学習から除外 | normal補完しない。欠測頻度・偏りの評価には残す |
| 研究側取込だけ遅延 | 信頼できるoriginal受理が窓内で観察も適格なら候補。source完了watermark未確認はhold | 後から発見した場合も旧outcomeを上書きせず新version |
| 09時境界／受理順同率 | T0ちょうどの観察は除外、Eちょうどは含む。真の受理順不明ならhold | 観察時計の誤差／精度で境界判定できなければ曖昧さを保持 |

### 6.4 採用済みのラベル確定Lと訂正受付

特徴量締切T0、観察／original受理窓の終端E、**ラベル審査の知識締切L**を別に持つ。Lを延ばしてもoriginalの提出期限Eは延ばさない。E後でもLまでに受理した訂正／取消は、同じ観察のoutcome審査材料にできるが、T0入力には絶対に戻さない。

| Lの案と採用状態 | 利点 | 制約／トレードオフ |
|---|---|---|
| E経過＋source取込完了watermark（代替・不採用） | 早く固定でき、追跡期間が短い | E直後の入力訂正・取消を取りこぼす。完了不明なら確定しない |
| **採用：L=T1（E）+24時間** | 入力ミス・取消を同じ追跡条件で審査できる | 24時間は研究初版の運用値。Lまでのsource取込完了を別途確認し、不足ならhold。将来の実データ評価でpolicy versionを上げて変更可能 |
| 研究datasetのfreeze時点（代替・不採用） | 長い追跡で訂正を把握しやすい | 行ごとの追跡期間差が大きく、再生成時にラベルが揺れやすい |

**採用済み：L=T1+24時間、主ラベルは初回回答、訂正版は比較／感度分析用**。初回回答を主ラベルとする場合も、Lまでの訂正を無視せず出所と有効性を審査する。選択候補の取消／適格性無効化は欠測化し、自動の次候補差替えはしない。L後の訂正／取消は`originalOutcomeId / supersedesOutcomeVersion / reason / acceptedAt / adjudicatedAt`付きの別outcome履歴とし、元ラベル・不変入力／予測snapshotは通常更新しない。原記録の初回・訂正・取消はそのまま保持する。

`labelSpecVersion`には窓・適格性・受理順・同率・訂正値・取消差替え・late・Lの全規則を結び付ける。採用済みの規則と実データ利用の承認を分け、研究利用が未承認の実ラベルは生成せず、仮想fixtureの技術的includeと研究採用許可を区別する。

## 7. 架空の1行（将来契約例、現行Firestoreデータではない）

架空の確認済み個体 `subject_demo_01 / episode_01`。T0は2026-11-10 09:00 JST、Eは翌09:00 JST。前日に観測・受理済みの体重とケアを入力候補にし、当日13:00観察・13:05提出の明示回答をラベル候補にする。採用済みのLは11/12 09:00 JST。この例は架空fixtureのみで研究利用を承認していないため、rowDispositionはholdのままとする。
以下の体重／回答revision、研究キー、同意、policy値は**説明用の将来fixture**で、保存済みデータや実装済み同意ではない。

```json
{
  "rowId": "subject_demo_01:episode_01:2026-11-10T00:00:00Z:contract-v1.5-draft",
  "ownerResearchKey": "owner_demo_01",
  "ownerGroupKey": "owner_demo_01",
  "subjectResearchKey": "subject_demo_01",
  "subjectEpisodeId": "episode_01",
  "subjectIdentityStatus": "confirmed_interval",
  "identityMappingVersion": "identity-fixture-v1",
  "predictionReferenceAt": "2026-11-10T00:00:00Z",
  "featureKnowledgeCutoffAt": "2026-11-10T00:00:00Z",
  "referenceTimezone": "Asia/Tokyo",
  "targetWindow": {
    "start": "2026-11-10T00:00:00Z",
    "startInclusive": false,
    "end": "2026-11-11T00:00:00Z",
    "endInclusive": true
  },
  "features": {
    "weight_last": {
      "value": 100,
      "unit": "g",
      "observedAt": "2026-11-09T11:00:00Z",
      "timePrecision": "instant",
      "serverReceivedAt": "2026-11-09T11:01:00Z",
      "sourceLogicalId": "weight_demo_09",
      "sourceRevision": "1",
      "quality": "verified",
      "observationAgeSeconds": 46800
    },
    "care_room_walk_declared": {
      "value": 30,
      "unit": "min",
      "observedDateKey": "2026-11-09",
      "timePrecision": "date_only",
      "serverReceivedAt": "2026-11-09T12:00:00Z",
      "sourceLogicalId": "care_demo_09",
      "sourceRevision": "2",
      "answerProvenance": "item_selection",
      "scope": "daily_total_declaration_as_of_acceptance",
      "quality": "declared_date_only"
    },
    "humidity_coverage": {
      "value": null,
      "unit": "ratio",
      "missingReason": "expected_schedule_unknown"
    }
  },
  "outcome": {
    "label": "slightlyConcerned",
    "logicalAnswerId": "answer_demo_10",
    "originalRevision": "1",
    "observedAt": "2026-11-10T04:00:00Z",
    "serverReceivedAt": "2026-11-10T04:05:00Z",
    "labelStatus": "candidate_as_submitted",
    "labelAdjudicationAsOf": "2026-11-12T00:00:00Z"
  },
  "datasetSpecVersion": "prediction_dataset_contract_v1.5_draft",
  "featureSpecVersion": "feature-fixture-v1",
  "labelSpecVersion": "next-eligible-observed-response-24h-proposal-v2",
  "sourceManifestId": "fixture-manifest-v1",
  "consentEligibility": "fixture_only",
  "inputUiVersion": "fixture-ui-v1",
  "gamePolicyVersion": "fixture-policy-v1",
  "rowDisposition": "hold",
  "reasonCodes": ["fixture_only", "research_use_not_authorized"]
}
```

旧v1.4例のE後1時間は採用せず、本例のLを研究初版の採用値E+24時間へ揃えた。実データで同意・個体確認・source履歴／watermarkが不足した場合、この例を実データのincludeへ流用しない。各sourceのCatalog／仕様versionはmanifestにも保持する。

## 8. 採用／除外／保留を検証する架空ケース

以下の時刻はJST、共通T0は11/10 09:00、Eは11/11 09:00。Lは採用済みのE+24時間とし、同意・個体確認等を仮に適切に満たしたとする説明用fixture。実データの研究採用ではない。実測／申告の区間と利用可能時刻を別々に確認する。

| ケース | 入力・ラベルへの扱い／行の判定 |
|---|---|
| 正常な対応 | 11/9 20:00体重100g、20:01受理。11/10 13:00観察、13:05明示回答受理。必要履歴と完了watermarkがあるので**採用** |
| 後入力の掃除／散歩 | 11/9実施を11/10 12:00受理。09:00の入力には**不採用**。他の必須情報があれば行は採用可。11/10朝の散歩なしはそのrevisionのacceptedAtまでの申告としてのみ利用しacceptedAt≤T0を確認。T0や日末まで非実施とは扱わない |
| 後日訂正の体重 | 11/9受理100gを11/12に103gへ訂正。T0はoriginal100gを採用。旧revisionがない現在103gだけならこの特徴量は `history_unavailable`、必須なら行を**保留／除外** |
| 観察回答の訂正 | 13:00観察・13:05受理のslightlyConcernedを14:00にnormalへ入力訂正。主案は初回値を保持し訂正を参照、**採用候補**。Lまでの訂正版normalを使う代替とは別version。L後なら別outcome追記。original不明なら保留 |
| 観察回答の取消 | 13:05の候補を14:00に取消（L以前）、18:00に別の観察回答。主案は**ラベル欠測で除外**し18:00へ差替えしない。原記録・独立したケア記録を消さない |
| 環境変更日だけ既知 | 11/10に深さ変更、08:30受理、実施時刻不明。既存resolverの受理までに変更済みという根拠と品質で09:00の確認値は使用可能だが、同日07:00観測との対応は曖昧。01:00等を捏造せず曖昧な特徴量を**保留** |
| 環境の後入力 | 11/9の変更を11/10 12:00受理。T0のknowledge cutoffから除外。現在知識による振り返り値は研究入力に使用しない |
| センサー欠測と0 | 08:00の応答なしは欠測。有限な温湿度0がAPI値として08:01に保存・受理された根拠があれば0として保持し、機器測定時刻の保証はしない。指標別品質を分離、予定取得分母不明はnull |
| 部分的なセンサー品質 | T0以前の根拠でobserved有効1件、全体はPARTIAL。日代表値・十分なcoverageには使わず、device／subject対応未確認なら個体センサーfeatureも保留。他の必須特徴量・ラベル等が適格なら行は**採用候補**、sensor必須の別実験ならhold／除外 |
| ラベル未回答 | Eまで適格回答なし。承認済みL到達とLまでのsource取込完了の確認前は**保留**、確定後は監督学習から**除外**（label_missing）。normalへ変換しない |
| 遅い回答 | 11/10の観察を11/11 12:00に初提出。主窓を超えるため**除外**。11/12の回答を11/11へ代入しない |
| 未来情報の混入 | 窓内の目的回答のタグ／健康スコア、または11/11に再計算されたlatest SilverをT0入力へjoin。特徴量を拒否。修復不能なら行を**除外**（future_information_leakage） |
| 復元不能な旧記録 | 初回createdAtは窓内でも同日回答が上書き済み。original回答や順序は不明。latest値を最初と呼ばず**保留**、復元不能確定なら主解析から除外 |
| 観察時刻不明 | date_only・受理13:05でも観察可能区間がT0をまたぐ。主案は**保留**し、Lで解消できなければ主ラベル欠測／除外。通常記録は有効。旧submitted-only案とは分離 |
| 観察の後入力 | 08:00観察を13:05受理。提出がT0後でも主案の将来観察としては**除外**。13:00観察→13:05受理なら他条件を満たして候補 |
| 遅延実行 | T0=09:00の行を09:20に作成。09:10受理の特徴量は除外。T0の根拠だけ再現できればreplay候補、前向き予測実績には不採用。復元不能なら**保留** |
| 個体入れ替わり不明 | 同UID/main_petに異なる個体がいた可能性、境界不明。source値が正しくても同一個体行としては**保留**。確認されたepisodeの範囲だけを使用 |

feature不採用と行不採用を区別する。任意欠測があるだけで常に行全体を除外せず、事前登録した必須条件によって判断する。保留を期限経過だけで真値へ変換しない。

## 9. 再生成・不変性・追加保存が必要な範囲

**将来必要な最小保存契約（未実装）**:

- 体重／距離／観察回答／profile: logical event ID、immutable受理revision、操作（作成／訂正／取消）、対象参照、観測日時／区間／timezone／精度、server受理・利用可能時刻。日別currentは別投影として維持する案。完全履歴のない旧期間は移行で捏造しない。
- 個体の確認済み有効期間とowner／subject／householdの制限付き対応表。確認した時点と対象期間を区別する。
- センサー: sample identity、poll／device測定／受理時刻の区別、取得予定／稼働区間、指標別valid／expected数、遅延・時計品質。不明coverageを0にしない。
- 研究入力snapshot: T0、選択済みsource versionと値／品質、既存Silver派生値、計算version／情報asOf／digest。予測出力snapshotと分けて不変保持する将来案。
- ラベルevent／outcome履歴: original answerと訂正／取消、window／判定仕様／adjudication時点。入力snapshotや旧レポートへ後付け保存しない。
- consent／input UI／gamification／将来の予測表示・割付の履歴と時点。未保存の旧policyを現行versionで埋めない。

**dataset manifest**は対象研究・仕様群・source freeze ID／version一覧／digest・対象期間・source完了watermark・同意／identity対応版・採否ルール・split割付を固定する。実行日時やマシン名は実行metadataへ分け、同じ入力なのにsemantic digestが変わる要因にしない。

正規化はUTC ISO時刻（元の精度・timezoneは別保持）、単位固定、nullと欠落の区別、有限数値、object key順を固定。実測一覧はlogical ID／受理revisionの決定的順、意味を持つ配列順は保持する。hashのbyte表現／数値精度／timestamp桁は正規化versionで指定する。同じ許可済み入力version・仕様・確定時点・splitから同じ行とdigestを得る。

source未完了・順序不明・訂正審査中はhold。再試行は同じsource／mutationを重複せず、後で追加された情報は新しいmanifest／outcome版として明示する。記録が訂正されても過去の予測・入力snapshot・first／v1／日次レポートを通常更新しない。

正当な削除・撤回は通常不変性より優先する。削除後の元dataset再生成ができない場合はその制約と新manifestを記録し、再現性のために削除対象を保持しない。

## 10. Medallion／Insight／責務の接続

- **Bronze**: 原記録と受理revisionが時点証拠。今回既存schemaは変更しない。
- **Silver**: 原記録選択、中央値／MAD／EWMA、体重／観察Evidenceを再利用。研究用PIT再現は根拠revisionとinformationAsOfを必要とする将来契約。
- **Gold**: 現在分析 `CurrentInsightSet` は現在の評価日の結果。不変 `ReportInsightSnapshot` はレポート生成時点の結果。研究の入力／予測snapshot／outcomeはこれらと別の時間契約を持つ。
- 観察CurrentのD-13〜D、日次ReportのD-14〜D-1、既存activity健康評価のD−1と、予測窓 `(T0,E]` を混同しない。生成時刻が近いことだけでjoinしない。
- 将来の共通研究Repository／Serviceがsource選択・PIT・品質を担当し、Modelが型付き契約、ViewModelが表示整形、Widget／Screenが配置を担当する。画面別に分析計算を複製しない。今回UI・計算・Repositoryを実装しない。

## 11. 同意・研究利用・評価への接続

- アプリ機能としての保存権限と、研究・飼い主横断学習の許可を分ける。研究目的scope／説明版／同意受理／有効開始終了／撤回時点・削除対象を行とmanifestへ参照させる。未同意・scope不一致は研究採用不可。現在データの存在やテストアカウントであることは同意の代用にならない。
- 未確認の同意は`researchEligibility=not_assessed`として採用不可。通常機能の保存・技術的PIT適格・研究利用許可は別Gate。撤回後の研究目的の新規収集／新規利用を止める手順と、既存成果物への対応を分ける。

| 研究利用開始前の決定事項 | 決定すべき範囲・代替・確認主体 |
|---|---|
| 研究対象・目的 | どの個体／期間／項目、個体内検証とユーザー横断学習、二次利用・共有先を許可するか。目的を限定する案を第一とし、研究責任者・説明／同意scopeを確定 |
| 撤回 | 有効時点・受付確認、新規利用停止、未配布／配布済みdataset・進行中学習への適用と責任者。既存同意を無期限の包括許可にしない |
| 原記録・派生物・モデル | 通常保存、研究copy／manifest／dataset／予測・outcome、集計物、モデル重み・配布物を区別し、利用停止・削除・再学習・使用停止等の選択肢と実現不能範囲を決定。重みから即時完全除去できると約束しない |
| 保持 | 運用詳細log、長期分析根拠、研究原記録、派生dataset、モデル、backupごとに目的・期間・起算点・見直し主体を設定。90日は未確定の運用案で、自動採用・TTL設定をしない |
| 正規削除・backup | 通常アカウント削除と研究copyの対象一覧・受付／完了証拠、backupからの復元時に削除／撤回を再適用する方法、配布先対応を決定。現行再帰削除だけで外部copyまで完了したと扱わない |
| 法務・倫理 | 運営主体・利用地域・目的・第三者提供等に応じて必要な法務／倫理・動物福祉・専門家確認と責任者を実施前に定める。本書だけで適法性・審査要否・特定の法定保持期間を断定しない |

根拠を正規に削除した後は、該当行の完全再生成や当時の品質検証ができなくなる範囲をmanifestへ記録する。再現性のために削除対象を保持し続けない。今回は同意UI・TTL・抽出・削除処理を実装しない。
- 時間順評価では学習行のtarget終了とlabel確定／利用可能時刻を学習締切以内にする。重なる窓や同じ回答／懸念episodeを独立sampleと誇張しない。window跨ぎは分離／除外し、gap方針を登録する。
- 「既知個体の将来」と「未見個体／飼い主への一般化」は別評価。ownerをまたぐ同じ個体、確認済み世帯をgroupで分離する。学習／検証／評価のfold割付、前処理fit期間、実測・ラベルの根拠を保持する。
- 観察回答予測は回答者の認識・入力頻度・動機付けの影響を受ける。記録回数と疾病発生頻度を混同しない。回答がある集団だけの性能と、回答欠測率／偏りを別途報告する。
- `inputUiVersion`、Observation／Care Catalog版、`gamePolicyVersion`、将来の実験assignment／表示policy／実際の表示時刻・予測versionを追跡する。割付と実際の曝露は別。T0後の表示・行動はその行の特徴量に混ぜず、介入の評価側へ保存する。未保存はunknown。
- Prediction Readyは基準baselineの7日／14日を流用しない。対応付け数、期間、欠測、変動、測定方式、時間順性能、calibration／interval coverageを評価する将来Gate。モデル・閾値・予測表示・RCT・疾患リスクは本書で採用／開始しない。

## 12. 採用済み条件と実装・研究実行前の残件

| 項目 | 採用済み条件と残件 |
|---|---|
| 基準時刻・timezone・窓（研究P-01／P-15） | 09:00 JST、`(T0,E]`は採用済み。残件は遅延実行の区分・受理／観察の品質細則と事前登録 |
| endpointと回答scope（P-02） | §6の観察・受理両窓＋original受理順を第一案、旧submitted-only／観察順は代替。取消欠測・後続観察への自動差替えなしは採用済み。時刻不明・同率等の細則は残件 |
| ラベル確定／感度分析（P-02） | 初回回答を主、訂正版を比較／感度分析用、L=T1+24時間は採用済み。残件はwatermarkの運用細則とL後のoutcome改訂。P-10（研究保存先）と混同しない |
| 個体対応／属性（P-13） | 確認済みepisode・属性有効期間／知識時点が必要。旧slot-only期間の範囲、研究キー管理を決定 |
| feature採用／品質／鮮度 | 必須・任意、date_only／部分日申告、source欠落、センサーcoverageを登録。閾値は今回決めない |
| 受理履歴／snapshot保存 | sourceごとのimmutable受付・訂正・削除、live snapshotとcausal replay、normalizer／manifest保存先と権限を別設計 |
| 同意・撤回・削除（P-09／P-14） | 対象scope、適用期間、二次利用、保存期限、copy／成果物／backup対応を実行前に確定 |
| 評価・モデル・Ready（P-05／P-06） | 時間／個体／飼い主split、baseline比較、順序モデル等の比較計画、Ready判定を別研究手順で決定 |
| 周期・補助活動量・表示試験（P-03／P-04／P-08） | 独立した発情確認、past-only派生値、shadow／RCTの適格性・安全性は別Gate。今回モデルを実装しない |

本書はデータセットの設計契約。§13の通常保存基盤が整っても、事前登録・同意・sourceごとの履歴整備・研究Gateを満たすまでは本番抽出や学習へ進まない。Known Good・本番サーバー・本番飼育記録・承認済み記録カレンダー／環境UXは本作業で変更しない。

## 13. 2026-10-13：永続個体ID・観察回答履歴の実装範囲

[永続個体ID・観察回答履歴 v1](observation_history_and_subject_identity_v1.md)が通常保存の詳細契約。今回のローカル実装は次の2点だけで、研究用dataset生成／ラベル選択処理は実装しない。

| 追加された保存基盤 | 研究契約への接続と限界 |
|---|---|
| `pet_profiles/main_pet.subjectId`／`pet_subjects/{subjectId}` | server発行・明示保存で導入。同一個体のプロフィール編集では不変。名前変更から入れ替えを推定しない。旧slot-only記録へ一括付与しない。既存UID単位の分析と混ざる入れ替えは拒否し、多頭／全sourceの個体分離は未対応 |
| `observation_days/{dayKey}` のevents／revisions／mutations | 新観察・訂正・取消を明示区別。初回のoriginalと当該締切で有効なrevisionを分離し、server commitのacceptedAt・revision順・receiptを保持。現在表示は従来schema2のdaily_checkinsへ投影 |
| 観察timing・回答出所 | instant／date_only／unknown、確認操作、user_reported clock、Catalog／UI versionを保存。自動normalは項目別の明示回答ではない。端末の申告時刻をserver観測時刻にしない |
| 知識締切付きread | 締切までに受理されたrevisionだけを返す。導入前のoriginal不明、日内時刻不明等を理由として保持。保存成功・研究同意・実験ラベル適格性を同一に扱わない |

`subjectResearchKey` は将来の許可済み対応表でsubjectIdと対応させる。生のUID／subjectIdをそのまま外部公開せず、研究同意は `not_assessed` のまま。過去を復元できない旧記録は現在値で埋めない。属性・体重・活動量のimmutable履歴、センサーcoverage／測定方式は次工程。ケア／環境履歴のpetIdも旧時点へ新subjectIdを根拠なく付けない。既存Silver／Gold計算・不変レポートは維持する。

### 13.1 提出時刻だけでは観察窓を決められない

架空のT0=09:00、受理=13:05、回答=slightlyConcerned。以下は§6の**今回の推奨案**であり、旧submitted-only案からの変更提案。

| 観察時期 | 通常記録 | 今回の主候補案 | 旧submitted-only代替 |
|---|---|---|---|
| 13:00観察→13:05提出 | user_reported instantとして有効 | 明示性・個体・履歴等を満たせば候補 | 候補 |
| 08:00観察→13:05後入力 | 有効な後入力 | T0前の観察なので不採用。提出を観察時刻にしない | 提出行動の予測では候補になり得る |
| 対象日だけ／時刻不明→13:05提出 | date_onlyとして有効 | 09時をまたぐ可能区間なら保留、未解消は主ラベル欠測 | 曖昧さ付き候補とする別課題 |

通常保存の有効性と実験ラベルの適格性は別。T0・窓・L・主ラベル／比較用訂正版・取消欠測／自動差替えなしは§6の採用済み決定を適用する。研究利用の承認とは別であり、保存済み実データへのラベル付与は開始しない。最大懸念の自動選択、欠測normal化は禁止。

## 14. 2026-10-13：体重・活動量・既存属性の履歴化

[体重・活動量・個体属性履歴 v1](measurement_and_profile_history_v1.md)を通常保存の詳細契約として追加した。§4の旧current保存の限界は過去記録に残り、今回の履歴から遡及的に解消しない。新規server受理後は体重／活動の数値・換算条件・観測時期・subjectId、不変revision／mutation receiptと知識締切readを持つ。既存saveMainPetProfileへ種類・生年月日の訂正履歴を接続し、年齢は評価日と締切までに知られていた生日から導出する。

旧記録は明示保存で確認できた現存値としてのみ導入する。導入前の受理・訂正履歴／個体同一性を推定しない。日付indexの0時を測定時刻とせず、活動の元直径を現在main_envへ置換しない。sensor coverage／独立時計・研究用replay／抽出、個体入れ替えUI・全件移行は次工程または対象外。ラベル確定規則は§6の採用済み決定を参照し、研究同意・Prediction Readyの閾値は未確定のまま。今回はローカル実装・検証のみ。

## 15. 2026-10-16：センサー工程の区切りと学習入力への接続

**確定した工程状態**：[取得品質契約§11.1](sensor_coverage_contract_v1.md)の初版実装、通常取得→attempt→reading・環境評価継続、v2期間クエリ、新しい不変品質snapshotの作成／readbackまで完了。設定は60分・UTCのまま。今回のsnapshotの全体品質は**PARTIAL**、確認済みobserved有効readingは**1件**。期間query completeは、旧形式を含む全データの意味の確認完了ではない。旧形式・device／subject対応・正規予定枠・機器測定鮮度は根拠に応じunknown。**研究利用可能性／Prediction Readyは未判定**。残る理由は`legacy_timestamp_population_unverified`、`device_membership_unknown`、`expected_schedule_unknown`等として維持する。この工程はここで区切り、追加再集計・取得・過去不明の補完開発を行わない。

### 15.1 特徴量ごとの採否と、行全体の適格性

参照仕様は`sensor_acquisition_quality_v2`／`sensor_quality_window_read_v2`。tsは取得時のプロセス時計、createdAt等はserver受理であり、機器測定時刻へ読み替えない。

| 入力の状態 | 学習入力の推奨扱い |
|---|---|
| 確定値 | 対象期間・指標・単位・受理cutoff・device／subject対応・完全性が当該feature仕様を満たした値だけ候補。値が確定しても十分なcoverage／日代表性があるとは限らない |
| `readings.observed` | 確認できた部分の値・件数として保持。1件を日平均／日代表値・十分なcoverageに変換しない。部分観測を許すfeatureは別の定義・欠測指標・根拠を事前登録 |
| 全体未確定 | `count/validValueCount`、期間全体の分布・空白・率のnull／unknownと理由を保持。0／0%へ変換しない。走査77件等のreadDiagnosticsを有効sample数にしない |
| device／subject対応不明 | 個体featureへの結合を保留／不採用。アカウントに現在接続されている機器を過去全期間・現在個体へ割り当てない |
| 知識締切後に受理・確定 | 観測／取得が過去でもT0入力から除外。terminalの後日成功を当時の成功として採用しない |
| T0後に生成された品質snapshot | snapshot自体を「T0で利用可能だった入力」にしない。将来承認するcausal replayで、T0以前に受理された根拠だけを固定して再計算した特徴量として別モードで検証する |

今回の品質snapshotは`informationAsOf=2026-10-16T03:20:15.594000000Z`（12:20 JST）、確認済みreadingの取得は12:14 JST。したがって、この1件や12:20時点の品質集計を同日09:00の研究行へ入力できない。将来の別T0で利用する場合も、当該T0までの根拠・個体対応を再審査する。生成日時だけを無視して既存snapshotを流用するreplayにはしない。

`featureEligibility`（値／PIT／単位／対応・品質）と`rowEligibility`（個体同一性・適格ラベル・研究同意・事前登録済み必須feature）を分ける。センサーが任意の実験なら、適格な体重・過去観察・ケアを残した行を候補にできる。センサー必須の別実験なら理由付きhold／excludeにする。研究同意未確認の現在は、技術的に候補でも研究採用しない。feature別採否・reasonCodesと、必須／任意を決めたfeatureSpecVersionをmanifestへ保持する。

### 15.2 架空fixtureのローカル実装（今回承認・§16）

今回、架空fixtureに限定した純粋関数・runner・テストを§16の条件で実装した。実DB読取り／実データ生成・抽出、同意UI、予測器・シャドー・学習、Scheduler／APK、過去センサー補完は含めない。窓・L・主ラベルは§6の採用済み決定を参照し、同意等の未承認状態は変えない。


## 16. 架空fixture専用データセット生成器 v1（ローカル検証のみ）

実装・実行方法・代表fixtureは[research/prediction_dataset](../research/prediction_dataset/README.md)。本番Functionsのexport／実行経路へ接続しない。既存の純粋な日付処理とObservation／Care Catalogを参照し、SDKやDB初期化はimportしない。fixtureは独立に作成した2030年・`synthetic_`識別子のデータであり、実UID・本番snapshot・Libraryのコピーではない。

### 16.1 今回だけ確定した技術検証ポリシー

- 行起点はfixtureの個体×基準日一覧。`T0=09:00 Asia/Tokyo`、`T1=翌09:00`、窓は`(T0,T1]`。UTC絶対時刻を小数9桁まで正規化し、端末timezoneを使わない。T0ちょうどは除外、T1ちょうどは採用する。
- 新しい明示観察の**観察時期とoriginal受理**がともに窓内で、同一個体と確認できる場合だけ候補。日付のみ／不明は、通常記録の有効性を否定せずラベル候補から理由付きで外す。訂正を別観察に増やさない。
- original受理順で最初の適格観察を選ぶ。同時刻は同一scopeの信頼できるsequenceが揃う場合に利用し、それ以外は安定ID順で固定する。後者は`stable_id_fallback_not_observed_order`を保持し、実際の前後を証明したとは扱わない。**§6の研究推奨に残る「同率hold／先行曖昧候補の審査」と異なり、今回のユーザー指定による架空検証では不適格候補を除外して決定的に選ぶ。実研究へ自動採用しない。**
- 同じ観察IDから初回値（`synthetic_initial_answer_v1`）とLまでの訂正版（`synthetic_same_observation_corrected_by_L_v1`）を1行に保持する。訂正の有無・除外理由も残す。Lまでの取消は両ラベル欠測とし、後続観察へ差し替えない。時期・個体対応の訂正で適格性が崩れた行は不適格。最も心配な値を選ばず、欠測・不正値をnormalにしない。
- `labelFinalizedAt=L`と`dataAvailableThrough`は必須引数、L≧T1。L未到達の行は`hold`。L後の訂正／取消は除外し、T1後のoriginalを猶予で救済しない。fixtureのL=T1は境界検証用の代替設定。研究初版の採用値はL=T1+24時間であり、テストの可変L API／既存fixtureは変更しない。

### 16.2 最小特徴量・品質と採否

型付き入力`FeatureRevision`は、事前に正規化した架空の根拠だけを受け取る。体重g、活動量m、過去の明示condition、掃除区分／床材交換／散歩分、環境の回し車直径cm、種類／生日、最後に受理した温湿度と期間品質の最小集合を扱う。年齢・日平均・周期・予測残差・新しい統計集計は生成しない。実Firestore文書の汎用取込器・全履歴replayではない。

同じlogical記録はT0までに受理**かつ利用可能**な最新revisionを確定してから、取消・subject・観測時期・単位・出所・品質を検証する。取消／無効な最新版から旧revisionを復活させず、現在値を過去へ補わない。閉じた観測の日付精度は可能区間の終端がT0以前の場合のみ候補とし、unknownは推測しない。例外として当日のケア`up_to_acceptance`は受理時点までの申告としてのみ保持し、全日観測へ変換しない。散歩0や掃除非実施は確認された申告範囲を保ち、朝の申告を全日0にしない。自動normal／未回答／旧出所は明示回答にしない。目的変数と同じ観察由来の特徴量は除外する。

PARTIALなセンサー根拠は`observedCount`と、未確定の全体件数／割合を分離し後者をnullとする。最後の受理値は日平均／機器測定時刻ではない。device／subject対応不明なら個体の数値入力へ結合しない。機器鮮度・予定件数不明は理由を保持する。架空のPARTIAL・observed1は既存工程と同等の品質状態を検証する例で、本番snapshot自体を流用・更新しない。

`auditRows`は全起点を残し、`candidate / hold / label_missing / ineligible`と理由を出力する。`candidateRows`は技術的な学習候補の部分集合で、任意センサーの不足だけで他の有効特徴量を破棄しない。`featureEligibility`で入力採否を明示し、PARTIALな値は`allowPartialFeatureIds`の指定がある場合のみ利用候補。根拠を監査出力に保持することと入力への採用を分ける。必須特徴量はpolicy引数で指定する。全行で`researchEligibility / predictionReady = not_assessed`。前処理の学習、欠測補完、標準化、特徴量選択は実装しない。

### 16.3 再現性と不変出力

`generateDataset`は時計・ファイル・接続を持たず入力を変更しない。file I/Oと今回の実行日時は薄いrunnerへ隔離する。manifestにdataset／feature／両label／windowのversion、timezone、L、完成基準時刻、Catalog version、正規化fixture hash、code identity、状態／理由件数を保存する。配列の受渡順に依存せず、順序は受理・revision・安定IDから決める。

正本は型付きJSONとmanifest。fixtureのraw file hash・実行日時等は監査metadataへ分離し、再現対象の内容hashへ含めない。同じ内容hashの既存artifactは上書きせずbyte一致を検証する。L／policy／入力／コードが変わった場合は別dataset ID・hashになり、旧結果は変更しない。初回値と訂正版で異なる行／観察IDを`labelDifferences`で確認できる。

窓・L・主ラベルは§6で採用済み。実データへ進む前に、曖昧候補／同時刻の扱い、研究対象と同意・撤回・保持／正規削除、入力sourceの正規化・完了watermark、モデル／Prediction Ready、シャドー／表示試験の承認が別途必要。今回のテスト成功を、その承認や実データの適格性に置換しない。


## 17. 学習用table materializer v1（架空sourceでローカル検証）

[実装・実行方法・table schema](../research/prediction_materializer/README.md)と[source型](../research/prediction_materializer/src/sourceTypes.ts)を追加した。履歴snapshot取得Repository→adapter正規化→**既存generatorの唯一の行生成core**→table writerに責務を分離する。新しい特徴量・label選択・統計処理をmaterializerに実装しない。旧synthetic generator wrapperと83件の契約は維持し、canonical入口で明示T0/T1/L／完成時点を受ける。

- 入力はsubject、観察／体重／活動／careの保存revision、profile／environmentの既存知識締切付きrepository解決結果＋全根拠revision、sensor quality／evidenceを持つJSON snapshot。既存domain resolverをコピーせず、SDK／本番APIをimport初期化しない。profile／environmentの解決時点は実測時刻ではない。旧currentだけからの過去復元は行わない。
- `sourceCompleteness`と内部sensor品質を分ける。未宣言／部分／復元不能なsourceを確定済み特徴量にしない。観察の原回答・訂正・取消走査がpartial／unknownなら共通generatorがhold、not_reconstructableならineligibleにし、未証明のラベルと選択IDをクリアする。完全走査で本当に0件ならlabel_missing。任意sensor不足で他sourceの有効値は捨てない。
- care／environmentの旧保存型にはsubjectIdがないため、独立した期間対応根拠がなければ個体へ結合しない。種類・生日／環境は要求評価時点・知識締切・根拠revisionの受理／利用可能時刻を検証し、現在値を過去へ延長しない。体重g／活動mは保存済み値を使い、現在の回し車直径で再換算しない。
- tableは個体×predictionAt。T0/T1/Lはconfigで明示し09時をmaterializer内へ固定しない。JSONL／型付きCSV、候補／除外JSONL、effective config、manifest、auditをrun_id別に作成。null／0／false／部分品質を区別し、source／config／code／Catalog／仕様versionと内容hashを保持。生成日時と実行IDは内容hash外。既存tableは上書きしない。
- 初版のCLI／materializerはsynthetic sourceのみ許可し、test／productionを拒否する。実データ用read-only test-account adapterは未追加。本番アクセス、研究抽出、学習・予測、同意自動付与、TTL、サーバー／APK変更は実施しない。source classificationは来歴宣言であって研究許可ではない。

本工程のPASSは**ローンチ前の予測分析データ保存・ローカル生成基盤の一区切り**とする。窓・L・主ラベルは§6の採用済み決定を参照する。研究対象・同意・撤回・保持／削除、実sourceの完全取得・個体対応の確認、研究抽出許可、モデル／Prediction Ready、shadow／RCTの未確定状態は変えない。
