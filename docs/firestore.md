# Firestore schema (current)

このドキュメントは、Flutterアプリ + Cloud Functions が使用している Firestore のコレクション構造とフィールド仕様をまとめる。

> 設計意図
> - ユーザー単位のデータは `users/{uid}` を起点にサブコレクションで管理する。
> - SwitchBot の全ユーザーを定期ポーリングするため、横断参照用に `switchbot_users` をトップレベルに持つ。
> - 回し車の走行距離は、日次で1ドキュメントに正規化して保持する。

---

## Top-level collections

- `users/{uid}` : アプリ利用ユーザーのルートドキュメント
- `switchbot_users/{uid}` : SwitchBot連携ユーザーを横断的に列挙するためのインデックス

---

## users/{uid}

### users/{uid} (root doc)

**Purpose**
- サブコレクション運用の “親” として必ず存在させるためのドキュメント。
- Firestore コンソール上で「空ユーザー」に見えないようにする意図もある。

**Fields**
- `has_subcollections: true` (bool)
  - `BreedingEnvironmentRepo.saveMainEnv()` が `merge: true` で設定する。

---

## Breeding Environment

### Path
- `users/{uid}/breeding_environments/main_env`

### Read/Write
- 読み: `BreedingEnvironmentRepo.fetchMainEnv()` / `watchMainEnv()`
- 書き: `BreedingEnvironmentRepo.saveMainEnv(env)`
  - 保存前に必ず `users/{uid}` に `has_subcollections: true` を `merge: true` でセットして親docを確実に作る

### Fields
`BreedingEnvironment.toMapForSave()` の内容 + `updatedAt`

- `cageWidth` (string|null) 例: `"60"` (cm)
- `cageDepth` (string|null) 例: `"45"` (cm)
- `beddingThickness` (string|null) 例: `"10"` (cm)
- `wheelDiameter` (string|null) 例: `"28"` (cm)
- `temperatureControl` (string) default: `"エアコン"`
- `accessories` (string|null)
- `updatedAt` (timestamp, serverTimestamp)

> メモ: フォーム入力の都合で数値も string として保存している。

---

## Pet Profile

### Path
- `users/{uid}/pet_profiles/main_pet`

### Read/Write
- 読み: `PetProfileRepo.fetchMainPet()` / `watchMainPet()`
- 書き: `PetProfileRepo.saveMainPet(PetProfile p)`（merge）
- 画像URLのみ削除: `PetProfileRepo.deleteImageUrl()`（`imageUrl` を FieldValue.delete）

### Fields (PetProfile)
`PetProfile.toMapForSave()` に準拠（モデル定義側で確定）

- `name` (string) 例: `"マロ"`
- `birthday` (timestamp|null)
  - 保存は Timestamp
  - 読み取りは `Timestamp -> DateTime` / `String -> DateTime.tryParse` の両対応（互換）
- `species` (string) default: `"シリアン"`
- `color` (string|null)
- `imageUrl` (string|null)
- `updatedAt` (timestamp, serverTimestamp)

> 重要: `saveMainPet` は「named params版」ではなく **PetProfileを受け取る版**に統一されている。

---

## Distance Records (wheel running)

### Path
- `users/{uid}/distance_records/{dayKey}`

### Purpose
- 回し車の走行記録を **日次単位で1ドキュメント** 保存する。
- 同じ日に再入力した場合は **上書き** し、入力ミスを後から修正できるようにする。
- グラフ表示、日次集計、直近平均の計算をシンプルにする。

### Document ID
- `{dayKey}` = `yyyy-MM-dd`
- 例:
  - `2026-04-04`
  - `2026-03-24`

### Source of truth
- 走行距離データの正規保存先は **`distance_records`**。
- 今後の読み書きはこのコレクションを基準とする。

---

### Write patterns

#### 推奨: 回転数 → 距離 → 日次レコードへ保存
- `DistanceRecordsRepo.addWheelRotationRecord({rotations, date?, source})`

動作:
- 指定日からローカル日付ベースで `dayKey` を生成
- `users/{uid}/distance_records/{dayKey}` に保存
- 既存ドキュメントがあれば **同日レコードを上書き**
- 存在しなければ新規作成

#### 互換: 距離を直接、日次レコードへ保存
- `DistanceRecordsRepo.addDistanceRecord({date, distance, source})`

動作:
- 指定日の `dayKey` ドキュメントへ直接保存
- 同日レコードが既に存在すれば上書き

---

### Stored fields

#### `addWheelRotationRecord()` で保存されるフィールド
- `dayKey` (string)
  - 例: `"2026-04-04"`
- `date` (timestamp)
  - その日のローカル 00:00 を UTC化して保存
- `distance` (number)
  - meter
- `rotations` (number)
  - 回転数
- `wheelDiameterCm` (number)
  - 距離計算に使った車輪直径(cm)
- `source` (string)
  - 例: `"wheel_manual"`
- `createdAt` (timestamp, serverTimestamp)
- `updatedAt` (timestamp, serverTimestamp)

#### `addDistanceRecord()` で保存されるフィールド
- `dayKey` (string)
- `date` (timestamp)
- `distance` (number)
- `source` (string)
- `createdAt` (timestamp, serverTimestamp)
- `updatedAt` (timestamp, serverTimestamp)

> 実装上は `set(..., SetOptions(merge: true))` を使っているため、`createdAt` も更新時に再セットされうる。
> そのため現状の `createdAt` は「厳密な初回作成日時」ではなく、「保存時に入る時刻フィールド」として扱うのが安全。
> 厳密な初回作成日時を保持したい場合は、将来 `create時のみcreatedAtを付与する実装` に改める余地がある。

---

### Read patterns

#### グラフ表示（時系列）
- `watchDistanceSeries()`
  - `orderBy('date')`
  - `users/{uid}/distance_records` をそのまま時系列として読む

#### 指定日の距離
- `fetchDailyTotalDistance(dayLocal)`
  - 対象 `dayKey` のドキュメントを直接読む
  - その日の記録が無ければ `0`

#### 全期間の日次系列
- `fetchAllDailyDistanceSeries()`
  - `orderBy('date')`
  - 各ドキュメントを `HealthRecord` に変換して返す

#### 直近N日平均
- `fetchRollingDailyAverage(days=7, todayLocal?)`
  - `distance_records` を日次データとして扱う
  - 存在しない日は `0` として平均に含める

#### 直近N日系列
- `fetchDailyDistanceSeries(days=7, todayLocal?)`
  - 直近N日を日付で埋める
  - 記録のない日は `distance = 0`

---

### Internal rules / normalization

- 日付の主キーは `dayKey`
- `dayKey` はローカル日付ベースで生成する
- `date` はそのローカル日付の 00:00 を UTC化した Timestamp を保存する
- 読み出し時は `dayKey` を優先し、必要に応じて `date` を補助的に使う
- 1日1ドキュメントを前提とするため、同日複数レコードの後段集約は不要

---

### Design notes / benefits

- 1日1ドキュメントなので、**入力ミスを後から修正しやすい**
- Firestore上でも日付単位で意味が明確
- autoId方式と違って、同日の複数レコードを後で集約する必要がない
- グラフや平均値の計算が単純になる
- ドキュメントIDを見るだけで保存日が分かる

---

### Operational considerations

- `distance_records` は **日次の確定値ストア**
- UI上で同じ日付に再保存した場合は **更新** とみなす
- `wheelDiameterCm` 未設定時は保存せず、`MissingWheelDiameterException` を投げる
- 直近平均は「記録ゼロの日も平均に含める」仕様
- 欠損日を0埋めすることで、ユーザー体感に合う推移表示を優先している

---

### Legacy

#### Old path
- `users/{uid}/health_records/{autoId}`

#### Old structure problems
- 1日に複数レコードが入りうる
- 同じ日の修正がしづらい
- 後段で日次集約が必要
- Firestoreコンソール上でも意味が読み取りにくい

#### Current policy
- 今後の正規運用は `distance_records` を基準とする
- `health_records` は legacy データとして扱う
- 旧データ移行を行う場合は、日付単位に集約した上で `distance_records/{dayKey}` に変換する

---

## Wheel Diameter (used for wheel distance calc)

### Source of truth
- `users/{uid}/breeding_environments/main_env`

### Read
- `WheelRepo.fetchWheelDiameter()`
  - reads `wheelDiameter` field from main_env
  - accepts both number and string (parses string)

### Field
- `wheelDiameter` (string|number|null)
  - unit: cm
  - stored as string in UI model (`BreedingEnvironment.wheelDiameter`), but may exist as number (legacy/other input)

---

## SwitchBot integration

SwitchBot は以下の3系統でデータを持つ:

1. `users/{uid}/integrations/*`
   - 連携設定（token/secret、デバイスIDなど）
2. `users/{uid}/switchbot_readings/*`
   - 収集された温湿度ログ
3. `switchbot_users/{uid}`
   - ポーリング対象ユーザーを列挙するトップレベル索引

---

### 1) Secrets

#### Path
- `users/{uid}/integrations/switchbot_secrets`

#### Written by
- Cloud Functions: `registerSwitchbotSecrets` (callable)
- Cloud Functions: `disableSwitchbotIntegration` (callable) で削除/無効化

#### Fields
- `v1_plain` (map|null)
  - `token` (string)
  - `secret` (string)
  - `updatedAt` (timestamp, serverTimestamp)
- `v1` (map|null)
  - legacy fallback（暗号化ラップを想定した復号関数あり）
  - `token` (string)
  - `secret` (string)
- `disabledAt` (timestamp|null)
  - 連携解除時にセット。連携中は削除される (`FieldValue.delete()`)

> 方針: 現在は `v1_plain` を優先して読み、無ければ legacy の `v1` を読む。

---

### 2) SwitchBot device config

#### Path
- `users/{uid}/integrations/switchbot`

#### Written by
- Flutter（デバイス選択後に保存）
- Cloud Functions: `disableSwitchbotIntegration` でフィールド削除/無効化

#### Fields (known)
- `meterDeviceId` (string|null)
- `meterDeviceName` (string|null)
- `meterDeviceType` (string|null)
- `enabled` (bool|null)
  - 解除時に `false` をセット
- `disabledAt` (timestamp|null)
  - 解除時にセット

> 注意: 現状の functions 側は `meterDeviceId` のみ参照している。  
> UI側が `name/type/enabled` を持っていても、必須ではない。  
> 実質的な必須フィールドは `meterDeviceId` のみ。

---

### 3) SwitchBot readings (temperature / humidity logs)

#### Path
- `users/{uid}/switchbot_readings/{tsIso}`

`{tsIso}` は `new Date().toISOString()` をそのまま docId に使用。

#### Written by
- Cloud Functions Scheduler: `switchbotPoller` (every 15 minutes)
- Cloud Functions callable: `pollMySwitchbotNow`
- Cloud Functions HTTP: `switchbotPollNow` (手動用)

#### Fields
- `ts` (string) ISO8601
- `temperature` (number|null)
- `humidity` (number|null)
- `battery` (number|null)
- `source` (string) 例: `"status"`
- `createdAt` (timestamp, serverTimestamp)

---

### 4) switchbot_users (polling target index)

#### Path
- `switchbot_users/{uid}`

#### Purpose
- Scheduler が `where('hasSwitchbot','==',true)` で対象ユーザーを列挙するためのトップレベル索引

#### Written by
- Cloud Functions: `registerSwitchbotSecrets`
- Cloud Functions: `disableSwitchbotIntegration`

#### Fields
- `hasSwitchbot` (bool)
- `updatedAt` (timestamp, serverTimestamp)
- `disabledAt` (timestamp|null)

---

## Notes / operational considerations

- SwitchBot secrets は Cloud Functions 側で SwitchBot `/devices` を叩いて **保存前に検証**している。
- SwitchBot 読み取りは scheduler が top-level `switchbot_users` を走査し、ユーザーごとに
  - `users/{uid}/integrations/switchbot_secrets`
  - `users/{uid}/integrations/switchbot`
  を参照して `meterDeviceId` が揃っている場合のみ `switchbot_readings` に保存する。
- `users/{uid}` 親docを明示的に作る運用を入れている（`has_subcollections`）。