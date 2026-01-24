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
  subgraph Flutter[Flutter app]
    App[Flutter UI]
    Tabs[tabs.dart]
    Graph[graph_function.dart]
    SwitchSetup[switchbot_setup.dart]
    RAG[search_function.dart]
    Svc[services/*]
    Model[models/*]
  end

  subgraph Firebase[Firebase]
    Auth[Firebase Auth]
    FS[Firestore]
    CF[Cloud Functions v2]
  end

  subgraph External[External]
    SB[SwitchBot API]
    OAI[OpenAI API]
  end

  Tabs --> Graph
  Graph --> SwitchSetup
  Graph --> Svc
  RAG --> Svc
  App --> Auth

  Svc --> FS
  Svc --> CF
  CF --> FS
  CF --> SB
  Svc --> OAI
```

---

## SwitchBot data flow

![System overview](./diagrams/switchBot_data_flow.png)

```mermaid
sequenceDiagram
  participant U as User
  participant App as Flutter
  participant CF as Functions
  participant SB as SwitchBot API
  participant FS as Firestore

  U->>App: Token/Secret入力
  App->>CF: registerSwitchbotSecrets()
  CF->>SB: verify (devices or status)
  SB-->>CF: ok / error
  CF->>FS: users/{uid}/integrations/switchbot_secrets
  CF->>FS: switchbot_users/{uid} hasSwitchbot=true
  CF-->>App: ok

  U->>App: device選択
  App->>CF: listSwitchbotDevices()
  CF->>SB: GET /devices
  SB-->>CF: deviceList
  CF-->>App: deviceList
  App->>FS: integrations/switchbot meterDeviceId...

  CF->>FS: (scheduler) poll users
  CF->>SB: GET /devices/{id}/status
  SB-->>CF: temp/hum
  CF->>FS: users/{uid}/switchbot_readings/{ts}
```

