# 個性レポート v3 表示仕様

## 適用範囲

保存済みの不変Goldの詳細表示だけを更新する。既存のModel、Repository、
Home未読条件、report単位の既読保存、履歴、A3 callbackは変更しない。
サーバー統計・発行・Firestore構造・研究の適用判定は変更しない。
承認済み画像（2026-10-10追加添付）の右側のコンパクトな構成を基準にする。
Androidの既存AppBarを維持し、数値・差分・比例比較・薄い境界線を再現する。
画像の「小柄」「安定した活動量」は保存値だけで断定できないため採用しない。
写真は使用せず、任意個体の数値で成立するレイアウトとする。

## 構成と責務

1. 既存AppBar「うちの子の個性レポート」。
2. 小さな作成日時（保存済みgeneratedAtをJSTで表示）。
3. 保存された観察期間を添えた短い一文。カードの研究比較・直近比較の結論は冒頭で再掲しない。
4. 体重StatusCard（readyの場合）。
5. 活動量StatusCard（readyの場合）。
6. 未採用指標の簡潔な説明（生成時点の状態であり、現在の状態を推測しない）。
7. 「記録の詳細・研究の出典」ExpansionTile（初期は閉じる）。

縦スクロール1本。SafeAreaでAndroidの下端を避ける。
主要カードはneutralのStatusCardを再利用し、健康評価のgood/danger色や
shine効果を使わない。StatusCard.dataSurfaceを明示した箇所だけAppTheme.dataSurfaceDecorationを使い、背景は既存ネイビー色のAppTheme.dataPageDecoration。既存statusカードの既定表示は維持。

- Theme：既存色を使う汎用data表示トークンのみ追加。ThemeData変更なし。
- Model：既存PersonalityReport / PersonalityMetricSnapshot / PopulationContext。
- ViewModel：PersonalityReportViewModel、PersonalityMetricViewModel。
  保存数値の丸め・単位・差分文・DOIの検証・短い発見を整形。
  baseline、MAD、中央値、研究適用判定の再計算はしない。
- Widget：StatusCard、MetricComparisonBar、MetricPairComparisonBars、
  MetricValueDisplay、MetricValueComparison、ExpansionTile。Repository依存は持たない。
- Screen：配置、スクロール、状態表示、既存route/view callback。
- Repository：既存PersonalityReportsRepoのserver確認済みpointerとGold読み込み。

## 共通Theme token（AppTheme内）

| Token | 値／用途 |
|---|---|
| dataPagePadding | 左右18、上12、下20 |
| dataCardPadding / dataCardRadius | 18 / 22 |
| dataSectionGap / dataContentGap | 14 / 10 |
| dataSmallGap / dataValueGap | 6 / 4 |
| dataValueStyle | 52sp、w600、行高1.06、letterSpacing -1.5 |
| dataTitleStyle | 18sp、w600、行高1.3 |
| dataDiscoveryStyle | 14sp、w400、行高1.4 |
| dataBodyStyle | 16sp、行高1.4 |
| dataCaptionStyle | 13sp、行高1.4 |
| comparisonTrackHeight / Radius | 8 / 4 |
| comparisonValueColor | 既存accent |
| comparisonReferenceColor | primaryTextの70% |
| comparisonTrackColor | 既存chartGrid |

primaryText/secondaryText、既存darkBg/cardGradientEndとquickRecordの夜色・
暖色境界線・teal glowを再利用する。ページのteal光は2.5%、カードの暖色光は
2.8%の合成に抑える。既存カードの既定装飾とThemeDataは変更しない。
差分パネルはdataDifferencePadding(12/8)、Radius20、ValueStyle22sp、境界幅1。
文字幅測定には境界の左右幅も含める。体重の差数値と「軽め／重め」は同じ行、
活動量は差数値・短い結論の2行とし、不要な1文字の折り返しを避ける。
比較compact plotは42、IQR帯18、marker18、線1.5、label gap4/max幅104。
数値の線形位置は共通、IQRの色はThemeのteal→accent→neutral。
統計行はlabel幅96、行間4、拡大・狭幅時は上下に分ける。
詳細tileのpaddingは左右18/上下6、
childrenは左右18/上0/下18。Widgetに色コードを置かない。
新しいThemeDataや画面専用カラーパレットは追加しない。

## 体重比較

大きな値は保存baseline.median、単位gは18spで別表示。
研究適用可の場合だけ、保存cohortのmedian/p25/p75を使用する。
差分は主値の横の定量パネルへ「参考中央値より / 33g / 軽め」とまとめる。
比較が同値なら「参考中央値と / 0g / 同じ水準」。
主値・差分が横に収まらない場合は上下配置にし、数字や説明を切り捨てない。
健康判断や順位には変換しない。

MetricComparisonBarは個体値・参考中央値・IQRを含む共通線形スケール。
compactの個体は塗りつぶしmarker、研究中央値は縦線。同値でも両方を維持。
既定compact=falseの輪郭marker・軸・凡例は維持する。
IQRの帯はp25〜p75だけ。0や範囲外を含む値でも軸を必要に応じて拡張する。
v3はshowAxisLabels=falseで、描画上の端点を研究境界のように表示しない。
compact=trueだけ3段アイコン凡例を省略する。保存p25/研究中央値/p75の数値と
「中央50%の下限 / 参考中央値 / 中央50%の上限」を比例位置の下へ配置。
個体値がp25と異なる場合は個体値ラベルも追加。ラベル衝突・狭幅・文字拡大時は
Wrapへ退避し、プロット自体の位置は変更しない。偽の研究軸端点は表示しない。
参考値が同値の場合もmarker位置は同じ、偽の健康範囲は作らない。

体重の直近値・普段の基準との差・最終記録日は展開詳細で表示し、mainカードの高さを抑える。値は生成時点のlatestValueを維持する。
非適用／不明種／年齢不明の場合は比較バーと集団比較の発見を表示しない。
保存された省略理由を示す。少数集団の注意は残す。

## 活動量比較

大きな値は記録日のbaseline.median。m / 日と表示し、隣接して
「記録日の中央値」をタイトルと同じ行に示す。欠測日を含む全日平均という意味にはしない。

MetricPairComparisonBars.compactで「普段の基準」「直近の記録」の2本を表示。
ラベルはバー上、実値はバー右。両行で同じ数値欄幅を確保し、バーの比例を維持。
狭幅・文字拡大で不足すれば実値だけバー下へ回り込む。
両バーは0〜max(両値,1)の同一スケール。長さは実値に比例し、0は幅0。
同値は同じ長さ。差分は保存値の差だけを使い、MAD由来の帯は作らない。
日別記録だけから時間帯・夜型・長期傾向は推測しない。

比較の結論は主値横の1箇所のみ。同値は「±0m / 普段と同じ」、
差がある場合は「+Xm / 普段より長い」「−Xm / 普段より短い」。
カード内・冒頭へ同じ結論の文を再掲しない。
活動量は整数、体重は小数最大1桁。小さな実差は1m未満／0.1g未満とし、
丸めにより0差や同値を捏造しない。詳細では最大小数2桁を使用する。

## 発見と不足状態

研究比較不可の個体に集団比較の発見は出さない。
研究比較可の体重は参考中央値より軽め／重め／同じ水準。
活動量は生成時の直近値があれば普段より短め／長め／同じ水準。
発見がなければready指標の記録から見えてきた個性という中立文を表示。

latest欠測／比較値非有限の場合はグラフィックを出さず不足を説明。
レポートなしは既存learning、読み取り失敗は既存unavailable+再試行。
loading、別account、非current routeには閲覧通知を送らない。
旧v1も日次も、生成時点のsnapshotから同じUIを描画する。

## 展開詳細と出典

中央値、MAD、有効記録数、観測日の範囲／日数、評価日、採用最終日、
Silver基準日、研究名、DOI、対象年、公表年、種別総数、体重有効標本数、
適用条件、保存limitationsを表示。ViewModel.detailsLimitationsで既知の長い文章のみ意味を保って短縮し、健康正常範囲否定は1回へ集約。未知の注意・Campbellの固有注意は原文を保ち、Gold自体は変更しない。
技術的version IDは通常画面にも展開詳細にも出さない。
研究集団の中央50%は健康の正常範囲ではない。MAD=0は全記録同値を意味しない。
DOIは10.xxxx/...形式を検証しhttps://doi.orgへ外部起動。
不正DOIをURLにせず、外部リンク失敗でもレポート閲覧を維持する。

## アクセシビリティ

数値・単位・markerの役割・中央50%をSemanticsで読み上げる。
2本バーも値・単位・共通ゼロ起点を読み上げ、色だけに依存しない。
数字と単位はWrapで分離する。数字は一続きの1行として表示し、文字拡大や
狭幅で収まらない場合だけFittedBox.scaleDownで幅へ収める。単位・説明文は
文字拡大をそのまま反映し、必要に応じて改行する。数値Semanticsは省略しない。
固定高さの分析カード・テキストclipping・固定bottom CTAは使わない。
240px / 文字3倍 / dark+light / システム下端34pxをWidget testする。
既存AppBar、スクロール、ExpansionTile、リンクの操作領域を維持する。

## 再現テスト

Widget／VM：体重のみ・活動量のみ・両方、研究可否、範囲外、同値、
欠測、旧v1、日次、狭幅、大文字、dark/light、詳細、リンク、view callback。
Home既読消去と履歴の既存回帰テストも実行する。

Golden：Flutter3.32.8、DPR1、ja_JP、fixture固定、画面400×1100等。
日本語fontはtestだけHiragino W3をFontLoaderで明示しSHAで固定。
fontをrepositoryへコピーせず、productionのfont設定は変更しない。
標準パス：/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc
SHA-256：ce6d52b962d4f23acc6dae01eb59c2ddae1fd0b561a87240433623f5e76b8a92
代替環境はHAMCARE_GOLDEN_JAPANESE_FONTに同一byteの合法なfontを指定する。
MaterialIconsもSDKのhashで固定。利用不可／不一致はskipせずfail。
Goldensはこのfontの描画仕様を固定し、Android実機のfont完全一致を保証しない。

```sh
env CI=true FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true TZ=Asia/Tokyo \
  /Users/gota/tools/flutter/bin/flutter test --no-pub test/personality_report_v3_golden_test.dart
env CI=true FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true \
  /Users/gota/tools/flutter/bin/flutter analyze --no-pub
```

本番deploy、Firestore変更、AI呼び出し、APK更新は本作業では行わない。

## 2026-10-10 検証結果

専用Widget21、Golden9、ViewModel20、関連152：PASS。Flutter analyze：指摘なし。
Golden9画像を目視し、240px/文字3倍の数値分断を修正後に再比較。
全Flutter273件は272PASSと旧UI期待1件失敗、期待を修正後に関連152で全PASS。
全体コマンドは再実行せず、最終case網羅はこの再確認を含む。
Home未読消去・次報告再表示・履歴・旧first不変・owner切替・課金・
初回AI/monitoring CTAの回帰テストを確認。外部AI/APIは使用しない。
本番・実機のフォント/画面は未検証。

## 2026-10-10 Samsung視覚差分修正

添付5枚は現在のSamsung画面、追加添付は承認済み目標画像として確認。
右側のcompactなカードを基準に、指摘された背景・冒頭・カード高・説明重複を
修正し、実Flutter描画を目視比較する。写真・装飾アイコンは使用しない。
左側モックの写真・大きな発見文は採用せず、当初の短い冒頭1文条件を優先。

Samsungは既存端末監査に基づく360×780dp。添付画像から推定した上34/下48dp
のinsetと戻るボタン付きルートでGolden2枚を追加。日本語fontは既存のHiragino
固定で、Android Notoとの字形差・inset実値差は残る。Gold fixtureは本番を
書き換えず、既存backend再現データを使う。

Goldenの一致は回帰検知でありデザイン承認を意味しない。生成画像を目視で
比較し、実機反映・本番変更はこの作業で行わない。

## 2026-10-10 承認画像との最終目視比較・回帰確認

- 関連99ケースPASS。全Flutter307ケースPASS（Golden11ケース／12画像の通常照合を含む）。Flutter analyzeは指摘なし、全コマンドexit0。
- Samsung相当360×780dp、戻るAppBar、上34/下48dpの推定insetで、体重・活動量・折りたたみ入口を初期画面内に表示。240幅／文字3倍とlightも確認。
- 目視比較は承認画像の右側compactを基準とした。主要数値、定量差パネル、IQR実値、活動量2本バー、薄いカード境界、整列統計を確認。Goldenの一致だけをデザイン承認として扱わない。
- 残差：既存HamCareの青色、参照目盛りの実線、数字の太さ。狭幅では注釈衝突回避にWrapを使うため、captionの中心がmarkerと完全一致しない場合がある。markerの比例位置は維持。
- モックの別個体写真・大きな「小柄／安定」見出しは不採用。Android AppBarを維持し、保存Goldで確認できる意味だけを表示。
- ローカルGoldenは合法なHiragino W3の固定font。Android Notoの字形・実inset・実機見た目は別確認。画像の数値・期間・日時は決定的テストfixtureであり本番Bの再取得結果ではない。
- 重要51ファイルのSHA一致、Screenの読み込み／既読callback部分とThemeDataのbyte一致を確認。Home、履歴、A3、課金、trial、onboarding、Functions、Rules、依存定義は変更なし。
- ソース読み込み長が一時的に旧値になる現象はDart同期／非同期読込で切り分け、全対象の末尾を確認して再実行。ソース欠落・キャッシュ削除・環境変更なし。
- 実機APK更新、本番deploy、Firestore変更、AI呼び出し、Known Good変更なし。証跡：/private/tmp/hamcare-v3-visual-refine-20261010。

今回のproduction対象：AppTheme、PersonalityReportViewModel、PersonalityReportScreen、StatusCard、MetricComparisonBar、MetricPairComparisonBars、新MetricValueComparison。
関連テスト9ファイル、Golden12画像、本仕様とPROJECT_STATUSを更新。
