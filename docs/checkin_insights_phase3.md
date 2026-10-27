# 今日の様子Insight・Observation Catalog v1

## 範囲

開発前提（2026-10-11）：ローンチ前・一般ユーザー0人。旧版共存対応は実際の配布状況に応じて判断する。 アプリとサーバーをローンチ候補の同じデータ契約へ揃える。旧v2/v3の継続利用専用のpointer分離・保存先・二重配信・全旧履歴移行は今回追加しない。既存pointer構造と不変レポートは保護する。

構造化された今日の様子から、選択項目の繰り返し、気になる様子の記録頻度、記録状況だけを説明する。疾病、原因、健康状態、実際の発生頻度は推定しない。生成AIは使用しない。

## 観察カタログ

正本は `shared/observation_catalog.json`。Flutter/Functionsの定義は手動で別管理せず、`tool/generate_observation_catalog.py`で決定的に生成する。

項目は安定したid、label、order、active、legacyIds、legacyNames、insightEligible、defaultNormalを持つ。現在の入力は appetite / water / elimination / breathing / movement / eyesNose / coatSkin / other。poopはeliminationへの旧ID、chewingは読み取り専用の廃止項目。otherは具体的特徴を特定できないため反復Insight対象外。

変更手順:
1. JSONで項目追加・label/order変更・active切替・旧ID/旧名称を設定する。既存IDは変更・削除しない。
2. versionを更新する。統合時は旧IDをlegacyIdsへ残す。
3. `python3 tool/generate_observation_catalog.py`。
4. `python3 tool/generate_observation_catalog.py --check`とカタログ/入力/集計テストを実行する。

廃止項目は新規選択に表示せず、過去の入力・旧ID・生成済みsnapshotでは読める。研究・健康評価ルールをカタログへ混在させない。既存入力の意味的なアイコン選択は表示層に残し、新項目では既定の表示を使う。

## Bronzeの意味

正規docは `users/{uid}/daily_checkins/{dayKey}`。現行schemaVersion=2を維持し、新規保存にobservationCatalogVersionとobservationResponseMode=overall_with_selected_tagsを追加する。既存documentの一括移行は行わない。

conditionは明示的な全体回答で normal / slightlyConcerned / veryConcerned。未選択時の保存は不可、心配経路ではタグ選択が必要、画面表示だけで自動保存しない。

observationLevelsのnormalは標準項目へ保存時に自動生成される。個別回答済みを保証しない。選択したタグだけconditionからchanged/concerningへ導出する。InsightはUIモデルの欠落値normal/現在日fallbackを使用しない。

正規化Evidenceはselected_tag、automatic_normal、unanswered、invalid、legacy_level等の出所を区別する。将来のexplicit_items_v1とansweredObservationIdsを識別できるが、今回のUIは項目別回答方式へ変更しない。現行の項目別回答日数はunknown/nullであり、normalの存在数から補完しない。

## 14暦日の集計

Currentは評価日DのD-13〜D、reportは発行対象日DのD-14〜D-1。日時・更新日時と観察日を区別し、TimestampをUTC日付へ丸めてdayKeyを書き換えない。

有効全体回答日数、選択情報確認日数、項目の該当日数、欠測日、無効日を別々に保存する。同一日の更新は置換、同一項目のタグ/level/旧IDは1回だけ。矛盾した値は品質に記録して選択情報の採用から除外する。未知項目を架空の新項目として扱わない。memoや自由記述はEvidence/Insightへコピーしない。

掲載条件:
- A: 選択情報確認7日以上、対象項目を異なる3日以上で選択。最多→最新選択→カタログ順で最大1件。
- B: 有効全体回答7日以上、少し違う/心配を合計2日以上で記録。
- C: 有効記録7日以上。記録状況でありdiscovery=false。
- Aがあれば同義のBを重複掲載しない。CはA/Bがない場合の補助情報。

例: 「確認できた7日分の記録で、食欲が3日、気になる箇所として選ばれました」。0件から「問題なし」、欠測から「変化なし」、記録状況から「健康」とは表現しない。7/3/2は初版の製品上の掲載基準であり、医学的閾値ではない。

## Silver/Gold

Silver `daily_health_features/{D}`へoptional checkinInsightEvidenceを追加し、catalog/version、使用日・出所、期間、件数、品質、evidenceHashを保持する。既存schema5と中央値/MAD/EWMA、健康スコアは変更しない。

Gold `individual_insights/{D}`のCurrentInsightSetと新規日次reportのReportInsightSnapshotへoptional checkinInsightsを追加する。metric=condition、spec=checkin_insights_v1。既存weight_insights_v1の配列/APIを維持し、旧アプリへ未知kindを混在させない。

集計・掲載判定・semanticFingerprintはサーバーで一元化する。生成時刻の一致による世代整合と、意味が同じ根拠のfingerprintを区別する。生成日が進んだだけで新発見と強調しない。

変更日Sが影響するCurrent評価日はS〜min(S+13,today)。CurrentとSilverを同じtransactionで保存する。Bronze読み取り前にSilverの更新versionを取得し、generationとtransaction内のversionを照合する。同一ミリ秒に始まった計算も、競合時は最大3回までBronzeを再読取・再計算する。再読取結果が保存済みfeaturesと一致すればwriteを行わず、上限超過はエラーとして返す。遅れた旧処理による上書きと、旧処理が先に完了した際の新しい訂正の取り落としを両方防ぐ。過去の生成済みreportは再計算・訂正でも更新しない。

日次queue/frontierはbody/activityの既存仕様を維持する。観察の新しい掲載内容も同じqueueへ追加し、通常の翌朝09:00 JST処理で日次reportを発行する。数値指標が未readyならobservation_only、readyMetrics=[]、metrics={}とし、生成時点の有効な観察snapshotだけを保存する。first/v1/過去dailyを後からInsightで補完しない。

## 観察からの日次配信（checkin_publication_v1）

計算・掲載判定は既存checkin_insights_v1を再利用し、新しい医学的閾値や観察項目を追加しない。

- Evidence hash / semanticFingerprintは根拠の検証・現在分析の同一性に使う。配信のmateriality keyは掲載内容の意味と段階に使い、両者を混同しない。
- Aは安定した項目IDと該当日数帯3〜6 / 7〜10 / 11〜14、Bは心配記録日数帯2〜6 / 7〜10 / 11〜14。これらは通知頻度を抑える製品上の段階であり、実際の発生頻度や健康の程度ではない。
- Cは7有効記録日の初回節目だけ。日数が8、9…へ増えただけでは再配信しない。日付、正確な件数、項目の表示名、catalog version、生成時刻、Evidence hashだけの変化では新規発行しない。
- visible materiality keysを正規化してsemanticSignatureを生成。Aが含む同義のB段階はcoveredMaterialityKeysとして別に保持する。A/Bの配信はC節目も既配信とし、A→同義B/Cへの切替を新発見として配信しない。
- 日次pointerのcheckinPublicationState.seenMaterialityKeysを配信済み状態の正本とする。新規reportの発行成功と同じtransactionで累積保存し、同じ意味・段階が一度消えて再び現れても再配信しない。stateがない場合は未配信として正規発行を判定し、過去snapshotや全旧履歴から状態を推定・移行しない。既存テストレポート・配信済みstateへの手動変更や初期化は行わない。
- 現在日の確定Silverだけをenqueueし、Firestore TimestampをDateに復元してEvidence hashを検証する。transaction内で取得時のSilver updateTimeを再確認し、古い読み取りによる新queueの上書きを防ぐ。historical readinessの一時的な状態は入力にしない。
- CurrentはD-13〜D、日次はD-14〜D-1。今日の観察を朝9時より前に保存しても、その日の朝のcutoffへ混入させず翌朝へ送る。出版時に正規reader/builderでfresh Bronzeを再取得し、訂正・削除後に掲載条件を再検証する。
- 数値と観察の契機を同じqueueへ合流し、固定daily IDとtransaction createで同日最大1件。発行準備中に新しい観察・取消queueが現れた場合は古いsnapshotを発行せず、より新しいqueueを翌朝へ保持する。数値だけの既存watermarkは後退させない。
- 100件上限、残件、部分失敗の延期、重複イベント・並行処理の既存制御を再利用。09:00 JST Schedulerとv1 pointerは変更しない。

## Flutter

型付きModelはCurrentとsnapshotを分離する。現在分析はサーバー確認済みSilver/Gold、owner/評価日/生成世代/evidenceHashが一致する場合だけ表示する。cacheのみ、pending write、別ユーザー、世代不一致、読み取りエラーではInsightを省略する。体重baselineや種別研究データを観察Insightの前提にしない。

ViewModelは保存済み根拠から短文/件数/期間を整形、共通InsightsCardはAppTheme/StatusCardで表示、Screenは配置だけを担う。画面内で日数や掲載条件を計算しない。

個性レポートは生成時点の短い発見、変化は観察期間・記録日数・該当日数を補助カードで表示する。観察専用dailyは共通InsightsCardを主役にし、体重・活動量が未readyなら準備中と説明する。健康画面のスコア・警告を置換しない。Home、既読、履歴、課金、trial、オンボーディングは変更しない。

## 本番適用前

ローカルのみの変更。本番deploy・Firestore移行・APK更新は行っていない。

今回の配信追加はpersonalityHealthFeaturesWritten / personalityDistanceRecordWritten / personalityDailyReportsの共有sourceに含まれる。実稼働sourceと照合して必要な3 Functionsだけを隔離反映する。新規Function、Scheduler変更、Rules/Index追加、研究seed、既存レポート移行は不要。healthの既存計算Functionは今回再deployしない。

リリース方針：一般ユーザー0人のローンチ前環境では、observation_only対応の最新版Flutterと同じ契約の3 Functionsを組み合わせて検証する。旧v2/v3の共存は今回のリリース阻害条件にしない。前から存在するreport_pointers/personalityとpersonality_dailyは削除・統合せず、今回新たなpointer・専用保存先・二重配信を追加しない。既存first/v1/dailyは不変のまま最新版で読める。テスト用の過去レポートやstateを移行・削除・リセットしない。今回は本番反映・APK更新を実施しない。

## 自動テストと保護確認

カタログの追加・名称/順序変更・廃止・旧ID、生成物の一致、schema2の回答出所、欠測/不正値/同日重複、14日境界、A/B/C掲載条件、Current/report期間分離を検証する。Emulatorでは既存paid/trial保存権限、過去日訂正/削除、同一時刻の両完了順での並行計算、既存first/v1/dailyの内容とupdateTime不変、次回新規dailyのsnapshotを検証する。

TypeScriptの実builderから生成したfixtureをDartでdecodeする。観察だけの現在分析、server/cache/pending/owner/日付/世代の切替、旧weight APIと旧report、個性レポート/変化での表示を検証する。新規Goldenはdark/light/狭幅・文字拡大の3枚。既存Goldenの更新は行わない。検証結果と変更範囲はPROJECT_STATUS.mdに記録する。

## 将来の予測分析

開発順序と研究・データ取得の条件は[predictive_analytics_roadmap.md](predictive_analytics_roadmap.md)を正本とする。今回の配信改善はその第1段階であり、予測モデルや既存スキーマ変更は含まない。

## 配信改善のローカル検証結果（2026-10-11）

Functions関連142件、Emulator関連164件、Flutter関連505件PASS。TypeScript noEmit、Flutter analyze No issues。新Golden3枚を目視確認し既存31枚は不変。実backendのobservation_only payloadをFlutterでdecode・表示・閲覧callbackまで確認。全Flutter/全Functionsテストの完走を意味せず、対象外star_awardsの停滞ケースは変更せず除外した。この時点の旧v2/v3共存・既出履歴移行に関する保留は、一般ユーザー0人という前提訂正で今回の要件から除外した。訂正後の検証はPROJECT_STATUS.mdへ追記する。
