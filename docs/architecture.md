# Architecture

## Dependency rules (must-follow)

このプロジェクトは「依存の向き」を固定して、改修で壊れないようにする。

### Allowed dependencies (OK)
- lib/screens/*  -> lib/services/*, lib/models/*, lib/widgets/*, lib/theme/*, lib/config/*
- lib/services/* -> lib/models/*, lib/config/*
- lib/widgets/*  -> lib/theme/*, lib/models/* (必要最小限)
- lib/models/*   -> (no dependency / pure data)
- functions/src/* -> Firestore, External APIs (SwitchBotなど)

### Forbidden dependencies (NG)
- lib/services/* -> lib/screens/*  (循環・密結合の原因)
- lib/widgets/*  -> lib/services/* (UI部品が肥大化する)
- lib/models/*   -> Firebase packages (モデルを純粋に保つ)

### Rules of thumb
- 画面(screens)は「表示とユーザー操作」まで。データ取得や保存は services に寄せる。
- Firebase/Firestore/Functions を screens から直叩きしない（移行中の例外はOKだが TODO を付けて消す）。

---

## System overview

![System overview](./diagrams/system_overview.png)

```mermaid
flowchart LR
  %% ===== Flutter =====
  subgraph App[Flutter app]
    subgraph Screens[lib/screens]
      Tabs[tabs.dart]
      PetScreen[pet_profile_screen.dart]
      PetEdit[pet_profile_edit_screen.dart]
      BreedEdit[breeding_environment_edit_screen.dart]
      Graph[graph_function.dart]
      SwitchSetup[switchbot_setup.dart]
      Search[search_function.dart]
    end

    subgraph Services[lib/services]
      PetRepo[PetProfileRepo]
      BreedRepo[BreedingEnvironmentRepo]
      HealthRepo[HealthRecordsRepo]
      WheelRepo[WheelRepo]
      SBRepo[SwitchbotRepo]
    end

    subgraph Models[lib/models]
      PetModel[PetProfile]
      BreedModel[BreedingEnvironment]
      HealthModel[HealthRecord]
      SBModel[SwitchbotReading]
    end
  end

  %% ===== Firebase / External =====
  subgraph Firebase[Firebase]
    Auth[Firebase Auth]
    FS[Firestore]
    CF[Cloud Functions v2]
  end

  subgraph External[External]
    SB[SwitchBot API]
    OAI[OpenAI API]
  end

  %% ===== Screen -> Repo =====
  Tabs --> PetScreen
  Tabs --> Graph

  PetScreen --> PetRepo
  PetScreen --> BreedEdit
  PetEdit --> PetRepo
  BreedEdit --> BreedRepo

  Graph --> HealthRepo
  HealthRepo --> WheelRepo
  Graph --> SBRepo
  Graph --> SwitchSetup

  Search --> CF

  %% ===== Repo -> Firebase =====
  PetRepo --> FS
  BreedRepo --> FS
  HealthRepo --> FS
  WheelRepo --> FS
  SBRepo --> FS

  PetRepo --> Auth
  BreedRepo --> Auth
  HealthRepo --> Auth
  WheelRepo --> Auth
  SBRepo --> Auth

  SBRepo --> CF
  CF --> FS
  CF --> SB
  CF --> OAI

  %% ===== Repo uses Model (dotted) =====
  PetRepo -.-> PetModel
  BreedRepo -.-> BreedModel
  HealthRepo -.-> HealthModel
  SBRepo -.-> SBModel
```

---

## SwitchBot data flow

![SwitchBot data flow](./diagrams/switchBot_data_flow.png)

```mermaid
sequenceDiagram
  participant U as User
  participant App as Flutter
  participant CF as Functions(callable/http/scheduler)
  participant SB as SwitchBot API
  participant FS as Firestore

  U->>App: Token/Secret入力
  App->>CF: registerSwitchbotSecrets() (callable)
  CF->>SB: verify
  SB-->>CF: ok/error
  CF->>FS: users/{uid}/integrations/switchbot_secrets (token/secret)
  CF->>FS: switchbot_users/{uid} (hasSwitchbot=true)
  CF-->>App: ok

  U->>App: デバイス選択
  App->>CF: listSwitchbotDevices() (callable)
  CF->>SB: GET /devices
  SB-->>CF: deviceList
  CF-->>App: deviceList
  App->>FS: users/{uid}/integrations/switchbot (meterDeviceId...)

  Note over CF,FS: 自動収集（アプリ不要）
  CF->>FS: (scheduler) switchbot_users where hasSwitchbot==true
  CF->>SB: GET /devices/{meterDeviceId}/status
  SB-->>CF: temp/hum/battery
  CF->>FS: users/{uid}/switchbot_readings/{tsIso}

  Note over App,FS: 表示（graph_function.dart）
  App->>FS: watchHasSecrets() / watchSwitchbotConfig()
  App->>FS: watchLatestReadings()
  FS-->>App: readings stream
```

