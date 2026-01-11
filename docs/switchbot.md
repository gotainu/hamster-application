
---

## 1. 今できあがっている「全体像」

目的：
SwitchBot の温湿度計からデータを**自動で定期取得して Firestore に貯めて、Flutter でグラフ表示**する。

ざっくり構成：

* **Flutter アプリ**

  * SwitchBot連携設定画面
  * グラフ表示画面
* **Cloud Functions v2 (Node.js 20)**

  * callable：`registerSwitchbotSecrets`, `listSwitchbotDevices`, `pollMySwitchbotNow`, `disableSwitchbotIntegration`, いくつか debug 系
  * HTTP：`switchbotPollNow`
  * scheduled：`switchbotPoller`（内部的には `switchbotPollNow` と同じ処理）
* **Firestore**

  * `users/{uid}/integrations/...`（設定）
  * `users/{uid}/switchbot_readings/...`（実データ）
  * `switchbot_users/{uid}`（SwitchBot連携ユーザーのインデックス）

---

## 2. Firestore モデル

### 2-1. ユーザー本体配下（users）

* `users/{uid}/integrations/switchbot_secrets`

  * `v1_plain.token` … SwitchBot TOKEN（平文）
  * `v1_plain.secret` … SwitchBot SECRET（平文）
  * `updatedAt`
* `users/{uid}/integrations/switchbot`

  * `meterDeviceId`
  * `meterDeviceName`
  * `meterDeviceType`
  * `enabled` / `disabledAt`（解除時に更新）
* `users/{uid}/switchbot_readings/{tsIso}`

  * `ts` … ISO 文字列（UTC）
  * `temperature`
  * `humidity`
  * `battery`
  * `source`（今は `"status"`）
  * `createdAt`（サーバータイムスタンプ）

### 2-2. 連携ユーザーインデックス（switchbot_users）

* `switchbot_users/{uid}`

  * `hasSwitchbot: true/false`
  * `updatedAt`
  * `disabledAt`（解除時につく）

👉 ここは「SwitchBot連携を有効にしているユーザー集合」を表す**インデックス**。
実データはあくまで `users/{uid}` の下にある。

---

## 3. Cloud Functions 構成と役割

### 3-1. 設定まわり

#### `registerSwitchbotSecrets`（callable）

* 入力：`token`, `secret`
* 動作：

  1. hex 文字列としてバリデーション
  2. `users/{uid}/integrations/switchbot_secrets.v1_plain` に平文で保存
  3. `switchbot_users/{uid}` を作成 / 更新（`hasSwitchbot: true`）

→ **「連携開始 or 再設定」ボタン**が叩くところ。

#### `listSwitchbotDevices`（callable）

* 認証ユーザーのみ
* `loadUserConfig(uid)` で TOKEN / SECRET を読み出し
* SwitchBot API `/devices` を叩く
* レスポンスの `body.deviceList` をそのまま返却

→ Flutter の「デバイス一覧から選ぶ」が叩いて、温湿度計だけフィルタして表示。

### 3-2. 実データ取得まわり

#### 共通：`loadUserConfig(uid)`

* `users/{uid}/integrations` 以下から

  * `switchbot_secrets.v1_plain`
  * （古いデータ用に `v1` もフォールバック）
  * `switchbot.meterDeviceId`
* を読み出して `{ token, secret, meterDeviceId }` を返す。

#### 共通：`getMeterStatus(deviceId, token, secret)`

* SwitchBot API `/devices/{deviceId}/status` を叩き、

  * `temperature`
  * `humidity`
  * `battery`
* を抜き出して返す。

#### 共通：`saveReading(uid, status)`

* `new Date().toISOString()` を docID & `ts` として
* `users/{uid}/switchbot_readings` に 1件保存。

#### `pollMySwitchbotNow`（callable）

* 現在ログイン中のユーザーについて：

  * `loadUserConfig(uid)` → `getMeterStatus` → `saveReading`
* レスポンス：`{ ok: true, saved: 1, status }`

→ Flutter の「sync（手動ポーリング）」ボタンが叩くところ。

#### `pollAllUsersOnce()`（内部関数）

* `switchbot_users` から `hasSwitchbot == true` の uid を全件取得
* 各 uid について：

  * `loadUserConfig`
  * 設定欠けてれば `skipped++` & ログ
  * OKなら `getMeterStatus` → `saveReading` → `saved++`
  * 例外が出たら `failed++` & エラーログ
* 最後に `{ total, saved, skipped, failed }` を返してログ出し。

#### `switchbotPollNow`（HTTP）

* `pollAllUsersOnce()` を呼び出して、その結果を JSON で返す。

→ 手動テストや一括ポーリング用。

#### `switchbotPoller`（scheduler）

* スケジュール：`every 1 minutes`（本番では 10〜30分くらいにする想定）
* `pollAllUsersOnce()` を呼ぶだけ。

→ **アプリが閉じていても動く自動ポーラー**。

### 3-3. 連携解除まわり

#### `disableSwitchbotIntegration`（callable）

やること 3つ＋α：

1. `users/{uid}/integrations/switchbot`

   * `meterDeviceId` / `meterDeviceName` / `meterDeviceType` を削除
   * `enabled=false`, `disabledAt` をセット
2. `users/{uid}/integrations/switchbot_secrets`

   * `v1_plain` / `v1` を削除
   * `disabledAt` をセット
3. `switchbot_users/{uid}`

   * `hasSwitchbot=false`, `disabledAt` 更新
4. （オプション）`deleteReadings: true` が来たら

   * `switchbot_readings` を最大500件削除（お掃除用）

→ Flutter の「SwitchBot連携を解除する」ボタンが叩く。

---

## 4. Flutter 側のざっくりフロー

### 4-1. 連携開始

1. ユーザーが TOKEN / SECRET を入力
2. 「検証して保存」ボタン：

   * `httpsCallable('registerSwitchbotSecrets')`
   * 成功したらステータス表示
3. 「デバイス一覧から選ぶ」ボタン：

   * `httpsCallable('listSwitchbotDevices')`
   * `deviceType == 'Meter'` だけフィルタ
   * BottomSheet で選択 → `users/{uid}/integrations/switchbot` に保存

### 4-2. データ取得 & 表示

* グラフ画面：

  * `users/{uid}/switchbot_readings` を Firestore からストリーム購読
  * `ts`（ISO文字列）を `DateTime.parse(...).toLocal()` にして X軸
  * `temperature` / `humidity` を Y軸

* 手動更新ボタン（sync）：

  * `httpsCallable('pollMySwitchbotNow')`
  * レスポンスを下に debug 表示しつつ、新しい doc が追加される → グラフ更新

* 自動ポーリング：

  * アプリとは関係なく、Cloud Functions の scheduler が `switchbotPoller` を回す
  * そのたびに `switchbot_readings` が増え続ける → アプリを開けばグラフが伸びている

### 4-3. 連携解除

* 「連携を解除」ボタン：

  * `httpsCallable('disableSwitchbotIntegration')`
  * 成功したら

    * デバイス選択ボタンを disabled に
    * 画面に「SwitchBot連携を解除しました」と表示
* 以降：

  * scheduler は `hasSwitchbot == false` のためその uid をスキップ
  * `pollMySwitchbotNow` も設定欠けで `missing config` を返す

---

## 5. 途中でハマったポイントと、どう解消したか

### 5-1. callable / HTTP の不一致

* 元々 `listSwitchbotDevices` を HTTP に変えたのに、
  Flutter が `httpsCallable('listSwitchbotDevices')` のまま → `NOT_FOUND`
* 解決：

  * SwitchBot連携系は全部 callable に統一
  * Flutter 側のコード変更を最小にした

### 5-2. uid の親ドキュメントが存在しない問題

* `users/{uid}` に「サブコレクションだけある」状態だと

  * `db.collection('users').get()` にその uid が出てこない
* その状態で scheduler を `users` ベースで回していたため

  * `pollOnce: users=3, saved=0, skipped=3` みたいな状況に
* 解決：

  * `switchbot_users/{uid}` コレクションを新設
  * 連携開始時 `registerSwitchbotSecrets` でここに `hasSwitchbot=true` を登録
  * `pollAllUsersOnce()` は `switchbot_users` を列挙するように変更

### 5-3. 連携解除時の「ゴミ問題」

* 連携解除したユーザーを scheduler が延々スキャンし続けるのは嫌 → コスト＆ログ汚染
* 解決：

  * `disableSwitchbotIntegration` callable を用意
  * 解除時に `hasSwitchbot=false` を立てて **インデックスから外す**
  * 加えて token / secret / meterDeviceId も消すので安全

---

## 6. ライフサイクルのイメージ（時系列）

1. **ユーザー登録**
2. **SwitchBot連携開始**

   * TOKEN/SECRET 入力 → `registerSwitchbotSecrets`
   * `switchbot_users/{uid}.hasSwitchbot=true`
   * デバイス選択 → `integrations/switchbot` に保存
3. **データ収集**

   * 手動 poll：`pollMySwitchbotNow`
   * 自動 poll：`switchbotPoller` → `pollAllUsersOnce` → `switchbot_readings` 蓄積
4. **閲覧**

   * Flutter が `switchbot_readings` を購読してグラフ表示
5. **連携解除**

   * `disableSwitchbotIntegration`
   * `hasSwitchbot=false` + secrets/deviceId クリア
   * scheduler の対象から外れる
6. **また使いたくなったら 2 に戻る**

---

## 7. 自分用チェックリスト（今後似たことやるとき用）

* [ ] Firestore の「親ドキュメントが存在しているか」を意識する
  → クエリで列挙したいコレクションは必ず doc を作る
* [ ] ユーザーごとの「機能 ON/OFF」の集合が欲しいときは
  → `feature_users/{uid}` みたいなインデックスコレクションを作る
* [ ] バックエンドから外部APIを叩くときは

  * [ ] 認証情報の保存場所（secrets）
  * [ ] ユーザー設定の保存場所（integrations）
  * [ ] 実データの保存場所（readings）
  * この3レイヤーを分けて考える
* [ ] callable と HTTP を混ぜる場合は

  * [ ] Flutter から叩くのは callable に統一
  * [ ] 内部バッチやテスト用に HTTP を使う
* [ ] 連携解除ストーリーを最初から考えておく

  * [ ] 設定の片付け
  * [ ] インデックスから外す
  * [ ] データ削除はオプション扱いにする（怖いので）

---


