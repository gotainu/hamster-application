# 個体別分析UI共有 Phase 1

## データ経路と責務

- `CurrentWeightAnalysisRepo`：認証ownerごとに当日JSTの `users/{uid}/daily_health_features/{dateKey}` と `pet_profiles/main_pet` を読み取る。当日のSilverがない場合、過去のSilverへfallbackせず比較を省略する。読込失敗やキャッシュだけの値、owner切替も省略する。書込みAPIなし。
- `reference_cohorts/{speciesCode}_adult_weight` の `currentReferenceVersion` から `versions/{versionId}` を読む。公開研究の型・単位・種・version・出典・適用条件を検証する。固定の研究数値を画面へ埋め込まない。
- `CurrentWeightProfile` / `CurrentWeightAnalysis`：種類未設定をシリアンへ補完しない。既存Silverのbaseline値をそのまま保持し、当日・ready・品質・観測期間・最新値・年齢を表示適用のために検証する。年齢は評価日とbaseline観察開始日に3暦月を厳密に超える必要がある。統計、健康評価、スコアを再計算しない。
- `ReferenceWeightCohort`：公開研究の契約と限界を保持する。研究総個体数は体重測定の標本数と区別する。未知の研究定義は安全に省略し、後日明示的に対応する。
- `WeightResearchComparison`：個体中央値と研究の中央値・p25・p75を持つ、画面から独立した共通モデル。
- `WeightResearchComparisonViewModel`：差分、丸め、短い比較文言を共有する。`fromCurrent` は現在の適用条件を確認し、`fromSnapshot` は不変Goldの保存済み適用判定を尊重する。両者の取得経路を混ぜない。
- `WeightResearchComparisonCard`：既存 `StatusCard` / `MetricComparisonBar` / `AppTheme` / `ExpansionTile` を使う補助カード。任意の画面へ配置でき、Screenは数値差や研究の適用判定を実装しない。
- `GraphFunctionScreen`：既存グラフの後にカードを配置。期間選択はグラフだけへ適用し、当日分析の評価日や比較値は変えない。

## 保護されるもの

`personalized_reports/first` と個性レポートの保存・日次発行・pointer・履歴・既読・A3・課金・trial・オンボーディング・Silver/Gold生成処理は変更しない。個性レポートの比較表示だけが同じViewModelへ委譲し、保存された過去の値を表示し続ける。

## 表示上の限界

研究IQRは研究集団の中央50%であり、健康上の正常範囲ではない。percentile・診断・健康スコアを作らない。未準備／研究なし／種類不明／誕生日不明／年齢不適合／古い・不正な分析ではカードを省略する。既存グラフは維持する。

## ローカルRulesと今後の反映

従来の本番Rulesでは研究collectionをクライアントから読めない。今回のローカルRulesは認証済みクライアントの公開体重研究documentの `get` のみ許可し、listと作成・更新・削除は禁止する。ユーザーの既存権限は維持する。

本番Rulesへ今回は反映しない。そのため現行本番Rulesのままでは権限不足で比較カードを安全に省略する。後のリリース時に、現行本番Rulesと差分確認した追加読取権限、Flutterの順で適用する。新しいFunction、統計再計算、研究seed更新、Gold書換えは不要。

## Phase 2への接続

総合コンディション詳細・内訳から `WeightAnalysisSource` を購読し、同じ `WeightResearchComparisonCard` または共通比較Model/ViewModel + `MetricComparisonBar` を利用する。各Screenに研究数値・年齢判定・差分文言をコピーしない。

## 今回の対象外で確認された既存表示

既存の体重chart footerに単位 `m` が残る点と、狭幅・大きな文字倍率で既存status rowがoverflowする点は今回変更しない。共有比較カード単体は320幅・文字1.5倍で確認する。研究バーの数値ラベルは既存Widgetの狭幅用折返しを使う。

## 検証結果（2026-10-11）

- 関連Flutter 140 / 全Flutter 349：PASS。研究あり・なし、未知種、年齢、learning、範囲外、owner/版/日切替、期間切替、購読lifecycle、既存課金・trial・オンボーディング・レポート履歴/既読を含む。
- Golden：新規2ケース4画像（393×852、dark/light）と既存v3の11ケース12画像を照合。既存v3画像は変更なし。ローカル目視も実施。
- Rules Emulator 94：PASS。公開研究の実onSnapshot、未認証拒否、list/write拒否、既存record entitlement/pointer/read markerを検証。専用demo project/loopbackのみ。
- Flutter analyze：No issues。最終実行6.1秒。初回の書式指摘は動作を変えないblock追加で解消。
- 実機・本番反映は未実施。Functions production、Gold保存処理、既存統計計算、個性レポート読み込み/閲覧lifecycle、ThemeDataは未変更。
