# ストア掲載用スクリーンショット

更新日: 2026-11-23

日本向け初回提出で使用するアプリ画面素材です。パスワードやメールアドレスは画像に含めません。実機撮影と、以下の現行Widgetによるオフライン描画を区別します。

## 2026-11-23 iOS build6向けの更新素材

- **今回採用する3枚**：[今日](ios_iphone_6_3/01_today.png)、[クイック記録](ios_iphone_6_3/02_record.png)、[相談](ios_iphone_6_3/04_consultation.png)。`54970b2802f8fcc483b336186149bea32baae42d`（1.0.1/build6と同一）の実際の共有Flutter Widget（MyApp/Tabs/Home/QuickRecordSheet/相談）を、既存の合成fixtureでオフライン描画した。lib/UIコードの変更や新しい画面の創作はしていない。本人・審査用アカウントの認証、Native Simulator又はiPhone実機撮影の証拠ではない。
- **形式**：1206×2622px、縦向き、PNG RGB、alphaチャンネルなし。論理402×874px/DPR3、iOSテーマと安全領域を使用し、OSの時刻・電池等のステータス表示は創作していない。元の不透明RGBA描画からRGBへ機械的に書き出し、全RGB画素が一致することを確認した。追加の合成文字、端末枠、レタッチはない。
- **表示内容**：今日については設定・記録不足時の現行表示であり、未取得の件数や評価を埋めていない。記録は現在の3項目選択、相談は現在の入力欄・マイクを含む未送信状態。サンプルは既存の合成プロフィールで、個人情報・実ユーザーの履歴・未搭載機能を含めない。既存の実機確認画像との照合・目視を経て掲載素材として採用した。
- **分離・検証**：既存`test/first_ai_monitoring_cta_test.dart`のCore/Auth/Firestore/Functions/AppCheckメモリadapterと`strategy_c_navigation_test.dart`の実MyApp/Tabs構成を再利用。Widget hostでは製品mainのNative Firebase/FCM起動を行わず、HTTPを拒否するguardの自己試験PASS、描画中の外部HTTP試行0、実AI・メール送信0。固定ソース327ファイルのbyte一致と限定描画テスト1/1 PASS、例外・Overflowなしを確認した。
- **フォント**：Ahemを使わず、Macの実Hiragino角ゴシックW3/W6を現在のNotoSans fallback名へロードし、既存MaterialIconsと同梱Caveatを使用した。文字・アイコンを目視確認したが、Native iPhoneと完全に同一のフォント計測結果とは扱わない。システムフォントのファイル自体はGitへコピーしていない。
- **旧素材の保持**：`ios_iphone_6_9/`の旧4枚は上書きしない。特に`03_changes.jpg`はGit HEADとSHA一致のまま保全し、新しい空データの変化画面へ置換していない。下段の2026-09-06の内容・枚数は旧素材の記録であり、build6の再撮影又は今回の登録済み枚数へ読み替えない。ASC 1.0.1の必要なDynamic Island medium枠へ上記3枚を登録し、3 of 10・処理完了・再読込後の保持を確認済み。旧03は今回のmedium掲載には使用していない。登録結果は既存提出手順書にも記録する。
- **制作証跡**：Git外`/private/tmp/hamcare-widget-store-capture-20261123/`に最小capture test、元PNG、`audit/source-copy.json`、`audit/capture-result.json`、`audit/ready-manifest.json`、`audit/flutter-test.log`を保存した。

採用RGBファイルのSHA-256：

- `01_today.png`: `308f01f3becc312909eac26ee16d066dee6667947550c82aad52e0671bb9390c`
- `02_record.png`: `498d400da1822f69928056dfd171dcb6d2bcd54fe4c1d7b3947712eefa910822`
- `04_consultation.png`: `ffbf9cd2d96b8d1edba62a58b94c30e6e724e2fb8c04970e67c1a62dd4f94e17`

## 2026-09-06素材の掲載順（保持）

| 順番 | ファイル名 | 内容 | Google Play代替テキスト案 |
|---|---|---|---|
| 1 | `01_today.jpg` | 今日の総合コンディション | ハムスターの総合コンディションと直近7日間の推移を表示する今日画面 |
| 2 | `02_record.jpg` | クイック記録 | 走行距離、今日の様子、体重を選べるクイック記録画面 |
| 3 | `03_changes.jpg` | 活動量の変化 | 活動量の平均、評価、走行距離グラフを表示する変化画面 |
| 4 | `04_consultation.jpg` | AI相談 | 飼育記録を踏まえたハムスターの暑さと温度管理に関するAI相談画面 |

## Google Play

- 保存先: `android_phone/`
- 形式: JPEG（アルファチャンネルなし）
- サイズ: 1080×1920（9:16）
- 枚数: 4枚

公式要件: https://support.google.com/googleplay/android-developer/answer/9866151

## App Store（2026-09-06の旧素材、保持）

- 保存先: `ios_iphone_6_9/`
- 形式: JPEG（アルファチャンネルなし）
- サイズ: 1320×2868（6.9インチiPhoneとして受理される縦向きサイズ）
- 枚数: 4枚
- 初回配布対象: iPhoneのみ

公式要件: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

## 更新ルール

- 公開版と画面内容が変わった場合のみ撮り直す。
- Debug帯、通知ダイアログ、キーボード、メールアドレス、パスワードを写さない。
- 追加テキストや端末フレームを合成する場合も、元画像を置き換えず別ファイルとして保存する。
