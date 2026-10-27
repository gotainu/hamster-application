# 個体別分析UI共有 Phase 2

## 表示と責務

- サマリー詳細は既存の総合健康スコア・領域ゲージを主役として維持する。体重が評価可能で整合するSilverがある場合だけ、普段の体重と任意の研究中央値を示すコンパクトな入口を追加する。
- 既存のサマリー → 統合評価の内訳を維持し、内訳の体重から「体重の詳細」へ進める。詳細は健康評価、個体内の普段／直近、研究比較を別々に表示する。研究比較の大きなカードは詳細だけに配置する。
- 活動量の内訳では「個体別の基準」「評価対象日D-1の記録」「健康評価」を分ける。基準readyでも記録がなければ、既存のscore null／記録待ちを維持する。記録の0mは欠測へ変換しない。
- `HealthAnalysisViewModel`が所有者、評価日、Silver日、生成時刻、品質・適用条件を確認し、表示値・短い文言を整える。Screenは配置・遷移のみ。スコアやbaseline統計を計算しない。
- `HealthWeightAnalysisEntry`、`HealthWeightIndividualAnalysis`、`HealthActivityAnalysisStatus`は共通UI。既存AppTheme、StatusCard、WeightResearchComparisonCard、MetricComparisonBarを再利用する。既存ゲージ・時系列グラフはそのまま。

## 読み取りと整合性

1. `HealthAssessmentRepo.fetchLatestFromServer()`で `users/{uid}/health_assessments/latest` をSource.serverで読む。失敗時は既存の健康評価読取へfallbackするが、追加分析にはserverConfirmed=falseとして使わない。
2. Phase 1の `CurrentWeightAnalysisRepo` から当日JSTの `daily_health_features/{dateKey}`、`pet_profiles/main_pet`、公開研究root/current versionを読む。Silver/profileはserver確認必須。研究のcache／pending／error時には研究参照を破棄する。
3. Phase 2だけ `includeIndividualAnalysisWithoutReference: true` を使用し、研究権限不足でも確認済み個体内分析を保持する。Phase 1の既定falseは維持する。
4. 所有者、Health.dateKey、featureDateKey、Silver.dateKey、当日evaluationDateKeyの一致に加え、Health.evaluatedAtとSilver.generatedAtの同一瞬間を要求する。既存pipelineがこの2値を同一トランザクションで保存するため、同日の別世代データも混ぜない。
5. 当日Silverなし、キャッシュだけ、不整合なら追加分析を省略し、健康評価を残す。過去Silver、不変個性レポート、readiness docから当日評価を補完しない。
6. サマリーが1つの分析購読を所有し、開いた内訳・体重詳細へ同じ値を渡す。owner／研究版／日変更／エラーで旧比較を除去する。健康評価は画面を開いた時点のスナップショットであり、その後Silverだけ更新されれば不整合な補助分析は省略される。再度画面を開くと評価も読み直す。

## リリース時のRules差分（今回は未反映）

Phase 2で追加のRules変更は不要。Phase 1の以下の権限だけを、リリース時の最新本番Rulesへ追加する。

- `reference_cohorts/{cohortId}` と `versions/{versionId}`：認証済みのdocument getだけ許可。
- sourceType=published_research、metric=weight、unit=g、data.cohortIdとpathの一致を要求する。
- rootは非空currentReferenceVersion、versionはreferenceVersionとversionIdの一致を要求する。
- collection list、全write、未認証、未公開・不整合データ、その他の下位pathは拒否。
- 既存の本人Silver・プロフィール・健康評価読取、paid/trial記録保存、期限後レポート閲覧の権限は変更しない。
- 本番へは最新Rulesとの追加差分を確認 → 統合Rules Emulator検証 → 追加Rules → Flutterの順。Functions、研究seed、統計計算、Gold変更は不要。

## 変更ファイル

Production/UI:
- lib/screens/daily_status_detail.dart
- lib/services/current_weight_analysis_repo.dart
- lib/services/health_assessment_repo.dart
- lib/viewmodels/health_analysis_view_model.dart
- lib/widgets/health_individual_analysis.dart

Tests:
- test/current_weight_analysis_repo_test.dart
- test/health_assessment_repo_test.dart
- test/health_analysis_view_model_test.dart
- test/health_analysis_test_support.dart
- test/health_individual_analysis_screen_test.dart
- test/health_individual_analysis_ui_support.dart
- test/health_individual_analysis_golden_test.dart
- test/goldens/health_analysis/ の6画像

Documentation:
- docs/individual_analysis_phase2.md
- PROJECT_STATUS.md

## ローカル検証（2026-10-11）

- 初回対象のModel/Repo/Widget/遷移66件PASS。初回の狭幅2ケースはテスト側が画面外の詳細ボタンをタップして失敗したため、該当ボタンまでスクロールし描画完了を待つ操作へ修正して全PASSを確認した。プロダクトの表示をテストのために緩めていない。
- 新規Golden4ケース6画像を生成・目視確認。393×852、JST、固定日本語font、dark/light、合成fixture、固定背景で比較する。既存v3とPhase 1画像は更新しない。
- Rules Emulator94件PASS。専用demo project／localhostのみ。実onSnapshot、get/list/write、既存paid/trial保存・期限後閲覧を含む。専用Emulatorは停止済み。
- Flutter analyze：No issues、exit0、最終8.6秒。証跡analyze-final.log。
- 全Flutter413件PASS、exit0、7分17秒。その後の活動量fallback4ケース追加と詳細リンクの視認性調整も含む最終関連312件PASS、exit0、14秒。最終関連には新規Model/Repo/Widget/遷移70件と新規Golden4件、および変化画面、既存v3、既読・履歴・課金・オンボーディング状態が含まれる。新旧Golden17ケース22画像は全一致。既存画像は更新なし。
- 保護対象のtracked 89ファイル（Functions src、Gold Models、Theme、個性レポートScreen/Repo、Home、課金・trial・onboarding等）にHEADとの差分なし。Phase 1のgraph/個性レポートVM/Rulesは今回開始時とbyte同一。既存incident・overall/domain gauge・chart・評価widgetもbyte同一で保持。
- 活動量のSilverが未確認／日付不整合の場合は、既存Gold健康評価を表示し続ける旨のfallbackを表示する。追加分析の不明状態を既存健康評価の不明状態と混同させない。
- 証跡：/private/tmp/hamcare-health-phase2-20261011/、/private/tmp/hamcare-health-analysis-phase2-rules-20261011/rules-emulator.log。
- 本番・Firestore本番書込・Functions・Rules・Scheduler・AI・APK・実機・Known Good・Gitの変更操作は実施しない。
- Phase 1で把握した既存の変化グラフの単位m表記・狭幅status row課題は今回も対象外。新設した健康詳細と補助分析は320幅／文字1.5倍を検証済み。
