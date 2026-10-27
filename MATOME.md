# Hamster Project - MATOME（全体像）

このドキュメントは「プロジェクト全体の地図」です。  
詳細仕様は docs/ 配下に分離します。

開発前提の履歴（2026-10-11）：当時はローンチ前・一般ユーザー0人として計画した。この人数を現在値として扱わず、旧版共存対応も実際の配布状況に応じて判断する。最新の公開状況・確認結果・残作業は[PROJECT_STATUS.md](PROJECT_STATUS.md)を参照する。

近接開発の順序とデータ収集・継続UX契約は[飼育行動の記録と継続貯蓄 v1](docs/care_action_capture_and_continuity_v1.md)を参照してください。設計上の順序は飼育行動→継続UX→環境履歴／日時整合→観察予測／周期検証→表示試験です。[飼育環境の変更履歴 v1・予測用の時点整合](docs/environment_history_v1.md)を含め、ローカル実装・本番反映・端末確認を区別し、最新の適用状況は[PROJECT_STATUS.md](PROJECT_STATUS.md)で確認してください。予測モデルの研究・採用を完了した意味ではありません。

長期の分析開発方針は[予測分析ロードマップ](docs/predictive_analytics_roadmap.md)を参照してください。研究の詳細契約・周期推定・シャドー検証・未確定事項は[正式な予測分析研究仕様 v1](docs/predictive_analytics_research_spec_v1.md)を参照してください。今後の分析開発では両資料を確認し、初期予測対象の優先関係を無断で変更しないでください。

予測用の通常保存基盤は[永続個体ID・観察回答履歴 v1](docs/observation_history_and_subject_identity_v1.md)と[データセット契約](docs/prediction_dataset_contract_v1.md)を参照。2026-10-13のローカル実装範囲は個体IDと観察履歴のみで、全source履歴化・研究抽出・学習・本番反映は含みません。

---

## 1. 目的とユーザー像

### 1.1 アプリの目的（何を解決する？）
- （例）ハムスター飼育の記録・可視化・学習支援を一つのアプリに統合する

### 1.2 ユーザーの前提
- ログインして使う（Firebase Auth）
- 飼育記録だけ使うユーザーもいる
- オプション機能を使うユーザーもいる（SwitchBot / LLM+RAG など）

---

## 2. 機能一覧（俯瞰）

### 2.1 コア機能（全ユーザーが使う前提）
- ログイン/認証
- ペットプロフィール
- 飼育環境
- 走行距離（手入力）・記録・グラフ
- 設定（テーマ/その他）

### 2.2 オプション機能（ユーザーによって使わない）
- SwitchBot連携（温湿度ポーリング・表示）
  - 詳細仕様・実装メモ：docs/switchbot.md
- LLM + RAG（ハムスター飼育知識をチャットで質問）
  - 詳細仕様・実装メモ：docs/rag.md

---

## 3. 画面構成（導線）

### 3.1 画面一覧（lib/screens）
- splash.dart：起動導線
- auth.dart：ログイン/サインアップ
- tabs.dart：タブルート
- home.dart：ホーム
- graph_function.dart：走行距離 + （SwitchBot連携時のみ温湿度グラフ）
- switchbot_setup.dart：SwitchBot連携設定
- search_function.dart：LLM/RAG チャット
- mypage_function.dart：マイページ
- settings.dart：テーマ/設定
- pet_profile_screen.dart / pet_profile_edit_screen.dart：ペット
- breeding_environment_edit_screen.dart：環境編集

### 3.2 “SwitchBot連携しないユーザー” の体験
- graph_function.dart は走行距離機能が中心
- SwitchBotセクションは「連携する」ボタンだけ（連携しないなら触らずに済む）

### 3.3 “SwitchBot連携するユーザー” の体験
- graph_function.dart → 「SwitchBot連携を編集する」へ遷移
- 連携完了後に温湿度グラフが graph_function.dart 上に表示される

---

## 4. データ構造（Firestore / モデル）

- Firestore ルール：firestore.rules
- モデル（Dart）：lib/models/

参考：
- docs/firestore.md
- docs/switchbot.md（SwitchBot分）

---

## 5. バックエンド（functions）

- functions/src/index.ts：Cloud Functions v2（Node.js 22。配備対象ごとの実行環境・適用状況は PROJECT_STATUS.md を参照）
- SwitchBot関連：docs/switchbot.md に詳細
- 参考：docs/functions.md（予定）

---

## 6. ディレクトリ方針（責務）

- lib/screens：画面（UI + 画面内ロジック）
- lib/services：外部I/O・API・Firebaseアクセスの集約
- lib/models：データモデル
- lib/widgets：再利用UI
- functions：Cloud Functions
- docs：仕様・設計メモ

---

## 7. 運用・開発メモ

### 7.1 よく使うコマンド
- Flutter:
  - iOSの成功環境・元ワークスペースとAndroid APKの再現条件は、PROJECT_STATUS.mdの「検証済みの状態」を参照する
  - iPhoneの日常検証用Releaseを維持する。通常の⌘R／flutter runによるDebug上書きとは区別する
  - 依存lockを保持し、ビルドのための一括cleanや一括更新を前提にしない
- Functions:
  - cd functions && npm run build
  - firebase deploy --only functions

### 7.2 事故りやすいポイント
- Firestore ルール期限・権限
- エミュレータと実機でのログインUID差
- SwitchBot Token/Secret は両方更新が必要（片方だけ更新すると壊れる）

公開準備は日本限定・iOS／Android同時公開を目標とし、既存Stripe Checkout／Customer Portalの維持を第一希望とする。購入導線の適用条件は確認待ち。現在地・確認結果・残作業は[PROJECT_STATUS.md](PROJECT_STATUS.md)の「現在地」「次に着手する作業」「タスク一覧」に集約する。ストア提出は `REL-02`、提出候補版の端末別最終確認は `REL-03`、通常の無料体験・AI利用は `TRL-01` を参照し、本資料へ別の進捗チェックリストを作らない。研究・予測モデルの将来計画とは区別する。

---

## 8. TODO（構造整備ロードマップ）
- [x] docs/architecture.md を作る（全体設計）
- [x] docs/firestore.md を作る（コレクション設計）
- [ ] docs/functions.md を作る（Functions一覧）
- [x] docs/rag.md を作る（RAG仕様）

測定と既存属性の通常保存基盤は[体重・活動量・個体属性履歴 v1](docs/measurement_and_profile_history_v1.md)を参照。導入後の受理履歴だけを再現し、旧記録の一括個体付与や研究抽出は行わない。
