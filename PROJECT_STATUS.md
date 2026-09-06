# Hamster Care プロジェクト状況

最終更新: 2026-09-06

このファイルを、開発進捗・優先順位・重要判断の**正本**とします。日常の更新はこのファイルへ記録し、変更履歴はGitで管理します。従来のExcel管理表は2026-09-06時点の履歴スナップショットとして保存し、今後は原則更新しません。

## 現在地

- フェーズ: リリース準備（Release Hardening）
- 最優先タスク: `REL-02` 日本限定・Stripe決済のまま両ストアへ初回提出
- ブランチ: `main`
- ブランド基準コミット: `f972be0 feat: refresh hamster brand mark`
- 公開状況: 未公開

## 次に着手する作業

1. 審査用アカウントでログインと有料機能を再確認し、パスワードは各ストアの審査欄へ直接入力する。
2. Google Play Consoleへ掲載情報・データセーフティ・AABを登録し、日本限定で審査提出する。
3. Xcode 26以降とApple Distribution/App Store用プロファイルを準備し、iOS配布ビルドを作成する。
4. App Store Connectへ掲載情報・App Privacy・配布ビルドを登録し、日本限定で審査提出する。
5. 提出後は`REL-03`のE2E確認とクラッシュ監視、続いて`VAL-01`の有料ベータ検証へ進む。

## 検証済みの状態

### アプリとバックエンド

- Flutter静的解析: エラーなし
- 自動テスト: 7件成功
- Android正式パッケージID: `com.gotainu.hamster`
- iOS Bundle ID: `com.gotainu.hamster`
- 初回iOS配布対象: iPhoneのみ
- Android実機でPlay Integrityトークン取得を確認済み
- iOS実機で明示的App IDによるRelease署名を確認済み
- Stripeの月額500円プラン、Checkout、Customer Portal、Webhook、Firestore契約状態反映を確認済み
- 解約予定の有効契約を、期限まで有料として扱う複数サブスクリプション優先処理を反映済み
- プライバシーポリシー、利用規約、特定商取引法表記、サポート、アカウント削除案内を公開済み

### Android提出物

- AAB: `build/app/outputs/bundle/release/app-release.aab`
- 生成日時: 2026-09-06 10:09:12 JST
- サイズ: 119,725,501 bytes
- SHA-256: `3c1f8eb2933ef6391c20e1c7b1382aec2d18fe26da81c1b715745637b34fe337`
- versionName / versionCode: `1.0.0` / `1`
- minSdk / targetSdk: `23` / `36`
- 署名検証: 成功
- Bundletool検証: 成功

### ブランド・ストア素材

- 最終ロゴ: 黒背景、生成り色の鉛筆線による下膨れのハムスター顔、開いた下部輪郭、頬と交差する左右3本のひげ、口なし、下部に心拍波形
- iOS/Androidの全アプリアイコンへ反映済み
- App Store 1024pxアイコン、Google Play 512pxアイコン、Google Playフィーチャー画像を作成済み
- Google Play用Androidスマートフォン画像4枚（1080×1920、JPEG）を作成・検証済み
- App Store用6.9インチiPhone画像4枚（1320×2868、JPEG）を作成・検証済み
- ストア掲載文、審査メモ、プライバシー申告チェックリストを作成済み

## タスク一覧

| ID | 状態 | 内容 | 次の確認・作業 |
|---|---|---|---|
| `SEC-04` | 完了 | Stripe契約状態の競合・再同期修正 | 運用監視 |
| `SEC-03` | 完了 | iOS App Check用の明示的署名設定 | 配布署名後に再確認 |
| `SEC-02` | 完了 | Android Play Integrity / App Check確認 | 公開後の強制適用は監視して判断 |
| `OPS-05` | 完了 | Android正式IDとアップロード署名 | 鍵とパスワードの安全なバックアップを維持 |
| `ANL-01` | 完了 | Firebase Analytics整備 | 公開後にイベントを確認 |
| `REL-02` | 進行中 | 日本限定・Stripe決済のままストア初回提出 | 審査情報、AAB/IPA登録 |
| `REL-03` | 未着手 | 提出候補版のE2E確認とクラッシュ監視 | `REL-02`の提出準備後 |
| `VAL-01` | 未着手 | 有料ベータで継続利用を検証 | ストア配布経路の準備後 |
| `AVT-06` | 進行中・非阻害 | 残りのアバター素材 | 初回公開後でも可 |
| `OPS-03` | 未着手・非阻害 | 依存パッケージ監査 | リリースを止めない読み取り確認から開始 |
| `OPS-04` | 未着手・非阻害 | Cloud Functionsビルドイメージ整理 | 課金状況を確認後に安全に削除 |

## 確定した方針

### 初回ストア提出

- 初回公開地域は日本のみとする。
- 初回iOS公開はiPhone専用とし、iPad対応はレスポンシブUI整備後に再検討する。
- 現行のStripe Checkout / Stripe Customer Portalを維持して提出する。
- AppleのApp内課金とGoogle Play Billingは、却下前には追加実装しない。
- 決済方法を理由に却下された場合は、規約番号、審査文面、対象画面、日時を保存し、指摘内容に限定して対応を判断する。

### 情報管理

- 進捗・優先順位・判断はこのファイルを正本とする。
- 実装や検証で状態が変わったときだけ、日付と根拠を添えて更新する。
- パスワード、APIキー、署名鍵などの秘密情報は記載しない。
- 完了していない作業を完了扱いにしない。
- 最優先タスクは原則1件に絞る。
- Excel管理表は過去情報の参照用とし、二重更新しない。

## 関連資料

- [ストア掲載情報](docs/release/store_listing_ja.md)
- [審査メモ](docs/release/store_review_notes_ja.md)
- [プライバシー申告チェックリスト](docs/release/privacy_disclosure_checklist_ja.md)
- [アーキテクチャ](docs/architecture.md)
- [Firestore設計](docs/firestore.md)
- [SwitchBot連携](docs/switchbot.md)
- [RAG構成](docs/rag.md)

## 公開ページ

- プライバシーポリシー: https://hamster-breeding-app.web.app/privacy/
- 利用規約: https://hamster-breeding-app.web.app/terms/
- 特定商取引法に基づく表記: https://hamster-breeding-app.web.app/commercial-transactions/
- サポート: https://hamster-breeding-app.web.app/support/
- アカウント削除案内: https://hamster-breeding-app.web.app/account-deletion/

## 更新記録

| 日付 | 内容 | 根拠 |
|---|---|---|
| 2026-09-06 | Androidと6.9インチiPhoneの掲載画像を各4枚作成 | ストア公式サイズ・非透過JPEGを確認 |
| 2026-09-06 | 初回iOS公開をiPhone専用に決定 | 現行iPad表示はスマートフォン幅の中央配置となるため |
| 2026-09-06 | 進捗管理の正本をExcelからMarkdownへ移行 | Gitで差分・履歴を管理する方針に変更 |
| 2026-09-06 | 最終ブランドをアプリとストア素材へ反映 | `f972be0` |
| 2026-09-06 | 最終アイコン入りAndroid AABを生成・検証 | SHA-256およびBundletool検証結果 |
