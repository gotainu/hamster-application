# Hamster Project - MATOME（全体像）

このドキュメントは「プロジェクト全体の地図」です。  
詳細仕様は docs/ 配下に分離します。

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
  - 詳細仕様・実装メモ：docs/rag.md（予定）

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
- func_b.dart：検証用 / デバッグ（扱い方を明記）

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
- docs/firestore.md（予定）
- docs/switchbot.md（SwitchBot分）

---

## 5. バックエンド（functions）

- functions/src/index.ts：Cloud Functions v2（Node.js 20）
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
  - flutter clean && flutter pub get
  - flutter run
- Functions:
  - cd functions && npm run build
  - firebase deploy --only functions

### 7.2 事故りやすいポイント
- Firestore ルール期限・権限
- エミュレータと実機でのログインUID差
- SwitchBot Token/Secret は両方更新が必要（片方だけ更新すると壊れる）

---

## 8. TODO（構造整備ロードマップ）
- [ ] docs/architecture.md を作る（全体設計）
- [ ] docs/firestore.md を作る（コレクション設計）
- [ ] docs/functions.md を作る（Functions一覧）
- [ ] docs/rag.md を作る（RAG仕様）
- [ ] func_b.dart の位置づけを決める（debug専用なら明記 or 移動）