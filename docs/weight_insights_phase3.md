# Phase 3: 共通Insight基盤・体重Insight v1

## 範囲

サーバー計算の「採用記録の観測幅」「30日内の実測期間差」だけを追加する。
既存の中央値・MAD・EWMA、健康スコア、Bronze、readiness計算は変更しない。
健康診断・継続的な増減・欠測日の推測には使用しない。

## データ契約

### Silver

既存 `users/{uid}/daily_health_features/{dateKey}`（schemaVersion 5）に
optional `weightInsightEvidence` を追加する。

- schemaVersion = 1、calculationSpecVersion = weight_insights_v1
- evaluationDateKey、periodWindowDays = 30
- baselineObservations、periodObservations: [{dateKey, value}]（g）

既存 `selectWeightAnalysisObservations` / `selectPersonalBaselineObservations`
を共有し、健康評価と同一の正規化・日付単位重複排除・採用上限を使う。
memo・プロフィール本文などは含めない。既存Silverフィールドを削除しない。

### Current Gold

`users/{uid}/individual_insights/{dateKey}` に `CurrentInsightSet` を保存する。

- schemaVersion = 1、kind = current、calculationSpecVersion = weight_insights_v1
- evaluationDateKey、generatedAt
- source: silverDateKey、silverSchemaVersion、silverGeneratedAt、evidenceHash
- contentHash（生成時刻を含むcanonical SHA-256）
- insights（サーバーの掲載順、最大2種）

各Insightはid、kind、metric = body、unit = g、評価日、観測開始/終了日、
全採用実測records、有効記録数、evidence、dataQuality、interpretationCode、
eligible、priority、calculationSpecVersion、sourceGeneratedAt、limitationsを持つ。
rangeのevidenceはminimumGrams / maximumGrams / allEqual。
periodのevidenceはstartWeightGrams / endWeightGrams / differenceGrams（符号付き）/
absoluteDifferenceGrams / startDateKey / endDateKey / windowDays。
dataQualityはbaselineStatus / latestDateKey / daysSinceMeasurement /
missingDaysNotImputedを保持する。掲載不可の場合はinsightsが空になる。

既存healthPipelineのSilver/health transactionに同じgenerationのGoldを追加する。
固定日付documentなので再試行で件数を増やさず、同generation・同contentHashはwriteしない。
古いGold計算による新しいGoldの上書きを防ぐ。

### Report snapshot

今後新規作成する `users/{uid}/personality_reports/daily_{dateKey}` にだけ
optional `insightSnapshot`（kind = report_snapshot）を追加する。
同日のcurrent Goldをコピーせず、既存daily publisherのfresh cutoff特徴量から作る。
評価日D、cutoff D-1に従い、D以後の実測は含まない。
既存tx.create / immutable既存report早期return / queue仕様を維持する。
first・v1・生成済みdailyへ後付け・更新・再生成しない。

## 掲載条件

- 実測体重は既存仕様の有限値 0 < g <= 1000。有効日付のみ、同日は最後の値を1回採用。
- 観測幅: 既存baselineのlatest測定日を除外した90日window、直近最大14件。
  baseline ready（7件・14日以上）かつ最新測定の鮮度14日未満。
  全採用実測のmin/maxが一致するときだけ「すべて同値」。MAD=0は使わない。
- 期間差: 評価日DのD-29〜Dにある異なる実測日が2件以上、最新測定の鮮度14日未満。
  最初と最後の実測だけを比較し、baseline learningでも独立した事実として掲載可能。
  レポートではさらにcutoffまでに絞る。活動量だけreadyのdailyでも有効な期間差は掲載可能。
- 非ゼロ期間差(priority 10) → 観測幅(20) → 同値両端差(30)。
  全同値の観測幅と同義のゼロ期間差は重複掲載しない。

## Flutter責務と取得

- Model: WeightInsight / CurrentInsightSet / ReportInsightSnapshotを別型で保持。
  contract、実測境界、単位、品質、generationを検証。Screenへ統計計算を置かない。
- Repository: CurrentWeightAnalysisRepoのincludeInsights=trueで当日Goldを購読。
  owner・当日・server確認・pending writesなし・Silverのschema/day/generation完全一致が必須。
  Goldなし/旧Silver/読み取りエラー/cacheのみではInsightだけを省略する。
- ViewModel: WeightInsightsViewModelが保存済みevidenceを短文・実測期間・件数へ整形。
  非ゼロの微小差を0gと表示しない。サーバーの掲載順を維持。
- Widget: WeightInsightsCardが既存AppTheme / StatusCardを使用。装飾アイコンなし。
- Screen: 変化の体重グラフに補助表示。グラフの7/30/全期間切替ではInsightを再計算しない。
  分析日・採用した実測期間を別表示し、グラフ選択期間の分析と誤認させない。
  健康詳細は既存HealthAnalysisViewModel.alignedの場合だけ1件表示。
  個性レポートは自身のsnapshotの主要1件、旧reportは従来の短文へfallback。

## ローカルRules

individual_insightsの日付documentは本人のgetだけ許可し、list/writeを拒否。
既存record・trial・billing・report・referenceルールは維持。
本番Rulesの現行内容へ最小追加を統合してEmulatorで確認してから反映すること。

## 検証と本番適用

新規Functions unit / 専用demo localhost Emulator / Flutter Model・Repo・VM・Widget・Goldenで
同値、幅、外れ値、少数記録、欠測、更新/削除、境界、learning、日付/世代不一致、
再試行/並行実行、旧report互換、first/v1/dailyのhashとupdateTime不変を検証する。
backend実計算JSONをDartで読むcontract fixtureも使用する。

本番適用は今回未実施。将来は隔離した検証済みsourceで、現行Rulesに上記getを追加後、
healthPipelineを実行する5health triggers / rebuildMyHealthArchitectureと
personalityDailyReportsの依存を確認して必要なFunctionsだけ反映し、Flutterを更新する。
新規index・研究seed・SQL・新しいtriggerは不要。旧reportの移行は行わない。
Current Goldは次の通常health再計算から、snapshotは次の通常daily発行から利用される。
既存reportをInsight付きへ作り替えるbackfillは実施しない。

## 既存の既知課題

既存health並行処理で遅いSilverが新Goldとgeneration不一致になる場合は、
新UIは誤ったInsightを表示せず次の通常再計算まで省略する。健康pipelineの並行制御は対象外。
過去日rebuild途中の一時的なreadiness遷移は今回未修正。日付固定Goldとcurrent-day照合で
過去日Insightを当日値として表示せず、日次レポートの既存cutoff/発行制御を維持する。
