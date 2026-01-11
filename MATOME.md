# Hamster Project — MATOME（設計・構造・運用まとめ）

このドキュメントは **アプリ全体を体系的に把握し、将来の改修で壊さないための「唯一の正本」**。
- 新機能の追加前に読む
- バグ調査時に読む
- リファクタ時に必ず更新する

---

## 0. TL;DR（最重要だけ）
- UIは `lib/screens/` が入口。画面の責務は「表示とユーザー操作」まで。
- データ取得/保存や外部連携は `lib/services/` に寄せる。
- SwitchBot連携は **FunctionsがSwitchBot APIを呼ぶ**（Token/Secretはクライアントに残さない）。
- Firestoreは「ユーザー配下 + integrations + readings」の構造を基準に拡張する。
- 変更すると壊れやすいポイント：Firestore Rules / Functions署名・認証 / tabs/drawer のルーティング。

---

## 1. リポジトリ構造（要点）
### 1.1 俯瞰
- `/functions` : Firebase Functions (TypeScript, v2)
- `/lib` : Flutterアプリ本体
- `firestore.rules` : Firestoreルール
- `firebase.json` : Firebase設定

### 1.2 現在の tree（抜粋）
- `functions/`
  - `src/index.ts`
  - `src/switchbot.ts`
- `lib/`
  - `screens/`
  - `services/`
  - `models/`
  - `theme/`
  - `widgets/`

---

## 2. アプリの機能一覧（俯瞰）
### 2.1 コア機能
- 飼育記録（走行距離・回転数・メモ等）
- プロフィール/飼育環境編集

### 2.2 オプション機能（ユーザーによって使わない）
- SwitchBot連携（温湿度ポーリング・表示）
    - 詳細仕様・実装メモ：docs/switchbot.md
- LLM + RAG（ハムスター飼育知識をチャットで質問）

### 2.3 基盤機能
- ログイン（Firebase Auth）
- テーマ（ライト/ダーク）
- Tabs / Drawer / ナビゲーション

---

## 3. 画面一覧と責務（Screens）
> ここが最重要。画面を増やしたら必ず追記する。

### 3.1 画面一覧（ファイル → 役割）
- `lib/screens/splash.dart`  
  起動直後。ログイン状態や初期化待ちの切替。

- `lib/screens/auth.dart`  
  ログインUI。Firebase Auth。

- `lib/screens/tabs.dart`  
  Tab構成のルート（Home/Graph/Search/Mypage/Settings 等の入口）。

- `lib/screens/home.dart`  
  ホーム画面（概要・導線）。

- `lib/screens/graph_function.dart`  
  走行距離入力 + グラフ表示。  
  SwitchBot未連携ユーザーでも冗長にならないUIを維持する。

- `lib/screens/switchbot_setup.dart`  
  SwitchBot連携設定（Token/SecretをFunctionsへ登録→デバイス選択→DeviceID保存）。

- `lib/screens/func_b.dart`  
  Debug/検証用（SwitchBotのポーリングやデバッグ表示などを置きやすい場所）。  
  本番UXに不要なら「開発者メニュー」扱いへ寄せる検討。

- `lib/screens/search_function.dart`  
  LLM + RAG 検索・質問UI。

- `lib/screens/mypage_function.dart`  
  マイページ入口。

- `lib/screens/settings.dart`  
  テーマ切替など設定。

- `lib/screens/pet_profile_screen.dart` / `pet_profile_edit_screen.dart`  
  ペット情報の表示/編集。

- `lib/screens/breeding_environment_edit_screen.dart`  
  飼育環境の編集（例：回し車の直径など）。

### 3.2 画面遷移（ざっくり）
- `splash` → (未ログイン) `auth` → `tabs`
- `tabs` → `graph_function`
  - SwitchBot未連携: 走行距離機能のみ
  - SwitchBot連携したい: 「SwitchBot連携」→ `switchbot_setup`
  - 連携済み: 「SwitchBot連携を編集」 + 温湿度グラフが表示される

---

## 4. データ設計（Firestore）
> 破壊変更しやすいので、変更時は必ずここも更新。

### 4.1 コレクション概略
- `users/{uid}`  
  ユーザーのルート

- `users/{uid}/health_records/*`  
  走行距離やメモ（手入力）

- `users/{uid}/breeding_environments/main_env`  
  飼育環境（回し車直径など）

- `users/{uid}/integrations/switchbot_secrets`  
  SwitchBotのToken/Secret（Functionsが扱う。アプリから参照しない）

- `users/{uid}/integrations/switchbot`  
  SwitchBot選択デバイス（meterDeviceId等）

- `users/{uid}/switchbot_readings/{ts}`  
  SwitchBot読み取り（温度/湿度/電池など）

- `switchbot_users/{uid}`  
  ポーリング対象ユーザーのインデックス（hasSwitchbot=true 等）

### 4.2 SwitchBot関連ドキュメント仕様
#### `users/{uid}/integrations/switchbot_secrets`
- `v1_plain.token` : string
- `v1_plain.secret` : string
- `updatedAt` : timestamp

NOTE: クライアントに返さない。Functionsが読み出して外部APIコールに使う。

#### `users/{uid}/integrations/switchbot`
- `meterDeviceId` : string
- `meterDeviceName` : string
- `meterDeviceType` : string
- `updatedAt` : timestamp
- `enabled` : bool（使うなら）

#### `users/{uid}/switchbot_readings/{ts}`
- `ts` : string（ISO8601）
- `temperature` : number|null
- `humidity` : number|null
- `battery` : number|null
- `source` : string（例: status）
- `createdAt` : timestamp

---

## 5. Firebase Functions（外部連携の中枢）
パス：`functions/src/index.ts`

### 5.1 Callable Functions（Flutterから呼ぶ）
- `registerSwitchbotSecrets`  
  Token/Secretを **検証してから** 保存する（/devices を叩いて認証確認）。

- `listSwitchbotDevices`  
  保存済みToken/Secretで `/devices` を取得して返す。

- `pollMySwitchbotNow`  
  自分の meterDeviceId を1回ポーリングして `switchbot_readings` に保存。

- `disableSwitchbotIntegration`  
  連携解除（secrets削除、index off、deviceId削除）

- `switchbotDebugEcho`  
  token/secret の head/tail など（デバッグ用）

### 5.2 HTTP / Scheduler
- `switchbotPollNow`（HTTP）  
  全ユーザーを1回ポーリング（手動実行）

- `switchbotPoller`（Scheduler）  
  `every 15 minutes` で全ユーザーをポーリング

---

## 6. Services 層（Flutter側）
> 「画面が肥大化しない」ためのルール。原則としてAPI/Firestoreの処理はここへ。

- `lib/services/fetch_and_store.dart`  
  Functions呼び出し・デバッグ表示補助

- `lib/services/switchbot_service.dart` / `lib/services/switchbot_repo.dart`  
  SwitchBot関連の抽象化（今後ここに寄せていく）

- `lib/services/openai_service.dart`  
  LLM/RAG（OpenAI API or 自前バックエンド）

---

## 7. UI/UX 方針（特に SwitchBot）
### 7.1 Graph画面のUX要件
- 初期状態：走行距離の入力＋走行距離グラフ
- SwitchBot未連携ユーザーに冗長な要素を押し付けない
- 連携導線：ボタン1つで `switchbot_setup` へ
- 連携後：ボタン文言を「編集」に変更し、温湿度グラフを表示

### 7.2 SwitchBot連携のUX要件
- 「検証して保存」時点で認証成功/失敗を返す（誤入力でも保存成功と見せない）
- デバイス一覧は温湿度計をフィルタして選択し、選んだらDeviceIDを保存

---

## 8. Firestore Rules（超重要）
ファイル：`firestore.rules`

- 期限切れやルール誤設定で「突然全機能が死ぬ」ので、変更したら必ずテストする。
- `integrations/switchbot_secrets` はクライアント read 禁止が基本（書き込みもFunctions経由が理想）。

TODO:
- 現在の rules をここに貼る（更新時は差分理由も書く）

---

## 9. 開発・デプロイ手順（迷ったらここ）
### 9.1 Functions
手順:
1. `cd functions`
2. `npm run build`
3. `firebase deploy --only functions`

### 9.2 Flutter
手順:
1. `flutter clean`
2. `flutter pub get`
3. `flutter run`

---

## 10. トラブルシュート集（頻出）
### 10.1 SwitchBotの認証が通らない
- Token/Secret を両方更新したか（Secretだけ更新してTokenが古い事故が起きやすい）
- Functions側で `/devices` 検証しているか
- 保存先UIDが違う（実機とエミュでログインアカウントが違う等）

### 10.2 Firestoreが読めない/書けない
- Firestore Rules の期限切れ
- ログイン状態（uid null）
- コレクションパスのtypo

### 10.3 “No AppCheckProvider installed”
- AppCheck未導入なら基本は警告。
- AppCheck強制をONにしていると通信に影響するので方針を決めて明記する。

---

## 11. リファクタ方針（今後の構造整理ルール）
- Screenは「UI + 入力/状態管理」まで
- Firestore/Functions/APIは `services/` に集約
- Modelは `models/` へ（Map直書きを減らす）
- 画面追加時は `tabs.dart`/drawer/route の変更点をここに記載
- “開発者用画面(FuncBなど)” はリリースビルドで隠す方針も検討

---

## 12. リファクタTODO（chore/structure-refactorでやる）
- [ ] 画面遷移図（最低限の1枚）を作る（draw.io or Mermaid）
- [ ] Firestore Rules を安全な形へ（期限依存をやめる）
- [ ] SwitchBot関連の責務を services/repo に寄せる
- [ ] Graph画面のwidget分割（入力フォーム/距離グラフ/SwitchBotブロック）
- [ ] RAG機能のデータフロー整理（フロント直叩き or backend経由）
- [ ] Debug機能(FuncB)を「開発者メニュー」に統合するか決める