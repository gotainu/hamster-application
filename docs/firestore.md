# Firestore schema (current)

このドキュメントは、Flutterアプリ + Cloud Functions が使用している Firestore のコレクション構造とフィールド仕様をまとめる。

> 設計意図
> - ユーザー単位のデータは `users/{uid}` を起点にサブコレクションで管理する。
> - SwitchBot の全ユーザーを定期ポーリングするため、横断参照用に `switchbot_users` をトップレベルに持つ。

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

- `cageWidth` (string|null) 例: "60" (cm)
- `cageDepth` (string|null) 例: "45" (cm)
- `beddingThickness` (string|null) 例: "10" (cm)
- `wheelDiameter` (string|null) 例: "28" (cm)
- `temperatureControl` (string) default: "エアコン"
- `accessories` (string|null)
- `updatedAt` (timestamp, serverTimestamp)
  - `PetProfile.toMapForSave()` 内で常にセットされる想定

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

- `name` (string) 例: "マロ"
- `birthday` (timestamp|null)  
  - 保存は Timestamp
  - 読み取りは `Timestamp -> DateTime` / `String -> DateTime.tryParse` の両対応（互換）
- `species` (string) default: "シリアン"
- `color` (string|null)
- `imageUrl` (string|null)
- `updatedAt` (timestamp, serverTimestamp) ※ toMapForSave()側で入れている想定

> 重要: `saveMainPet` は「named params版」ではなく **PetProfileを受け取る版**に統一されている。

---

## Health Records (wheel running)

### Path
- `users/{uid}/health_records/{autoId}`

### Purpose
- 回し車の記録（回転数・距離）を蓄積し、グラフ表示や日次集計に使う。

### Write patterns

#### 推奨: 回転数→距離→保存
- `HealthRecordsRepo.addWheelRotationRecord({rotations, date?, source})`
  - `wheelDiameterCm` を breeding_environment から取得できない場合は例外:
    - `MissingWheelDiameterException`
  - `date` は **UTCで保存** (`Timestamp.fromDate((date ?? DateTime.now()).toUtc())`)

**Fields**
- `date` (timestamp) ※ UTC
- `distance` (number) meter
- `rotations` (number) 回転数
- `wheelDiameterCm` (number) 計算に使った直径(cm)
- `source` (string) default: `"wheel_manual"`
- `createdAt` (timestamp, serverTimestamp)

#### 互換: 距離を直接保存（残置）
- `HealthRecordsRepo.addDistanceRecord({date, distance, source})`

**Fields**
- `date` (timestamp) ※ UTC
- `distance` (number)
- `source` (string)
- `createdAt` (timestamp, serverTimestamp)

### Read patterns / aggregation rules

#### グラフ表示（時系列）
- `watchDistanceSeries()`
  - `orderBy('date')`
  - `HealthRecord.fromDoc` で model 化

#### 指定日の距離合計（ローカル日付基準）
- `fetchDailyTotalDistance(dayLocal)`
  - ローカル日付の `[startLocal, endLocal)` を作り、UTCに変換してクエリ:
    - `where('date' >= startUtc)`
    - `where('date' < endUtc)`
  - 対象期間の `distance` を合計して返す

#### 直近N日平均（ローカル日付基準）
- `fetchRollingDailyAverage(days=7, todayLocal?)`
  - 期間クエリ自体は UTC 範囲で取得
  - 取得後、`date` を `toLocal()` して **ローカル日付キー**で日別バケツ集計
  - 「存在しない日は0」として days 分で割る（ユーザー体感に合わせた仕様）

---

## Design notes / pitfalls

- `health_records.date` は **UTC保存**、集計は **ローカル日付**で切り出す（`_dayRangeUtc` の考え方）。
- `fetchRollingDailyAverage` は「記録ゼロの日も平均に含める」仕様（データがない日を除外しない）。
- `wheelDiameterCm` が未設定のとき、保存処理は例外で止める（UI側で「飼育環境を設定してね」の導線が必要）。

---

## SwitchBot integration

SwitchBot は以下の2系統でデータを持つ:
1) `users/{uid}/integrations/*` : 連携設定（token/secret、デバイスIDなど）
2) `users/{uid}/switchbot_readings/*` : 収集された温湿度ログ
+ 3) `switchbot_users/{uid}` : ポーリング対象ユーザーを列挙するトップレベル

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
- `v1` (map|null) ※ legacy fallback（暗号化ラップを想定した復号関数あり）
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
- `enabled` (bool|null)  ※ 解除時に `false` をセット

- `disabledAt` (timestamp|null) ※ 解除時にセット

> 注意: 現状の functions 側は meterDeviceId のみ参照している。UI側が name/type/enabled を持っていても、必須ではない。
> 実質的な必須フィールドは `meterDeviceId` のみ。

---

### 3) SwitchBot readings (temperature/humidity logs)

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
- `source` (string) 例: "status"
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

- SwitchBot secrets は Cloud Functions 側で SwitchBot /devices を叩いて **保存前に検証**している。
- SwitchBot 読み取りは scheduler が top-level `switchbot_users` を走査し、ユーザーごとに
  - `users/{uid}/integrations/switchbot_secrets`
  - `users/{uid}/integrations/switchbot`
  を参照して `meterDeviceId` が揃っている場合のみ `switchbot_readings` に保存する。
- `users/{uid}` 親docを明示的に作る運用を入れている（`has_subcollections`）。