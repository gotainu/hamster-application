# Hamster Care プライバシー申告チェックリスト

更新日: 2026-09-07

この一覧はApp StoreのApp PrivacyとGoogle Playのデータ セーフティ入力用です。ストア画面の質問文は変更されることがあるため、提出時の最新表示に合わせて最終確認します。

## 基本方針

- データの販売: しない
- 広告目的の利用: しない
- 他社アプリやWebサイトをまたぐトラッキング: しない
- 通信時の暗号化: HTTPS/TLSを使用
- アカウント削除: アプリ内とWebの両方から申請可能
- 公開ポリシー: https://hamster-breeding-app.web.app/privacy/
- 削除案内: https://hamster-breeding-app.web.app/account-deletion/

## 収集・処理するデータ

| データ | 例 | 目的 | 主な処理先 | アカウントとの関連 |
|---|---|---|---|---|
| 連絡先情報 | メールアドレス | 認証、連絡、アカウント管理 | Firebase Authentication | あり |
| ユーザーID | Firebase UID、Stripe Customer ID | アカウント、契約状態の管理 | Firebase、Stripe | あり |

> 公開前の改訂要否（未反映）: 現在のアプリ実装ではFirebase Authentication
> UIDをFirebase Analyticsの標準User-IDとしても設定します。これは完全匿名の
> 解析ではなく、契約・分析の結合に使う識別子です。メールアドレス、氏名、
> ペット名、質問・回答本文、市区町村、認証トークンはAnalyticsへ送信しません。
> 公開中のプライバシーポリシーに「UIDをAnalyticsへ送信しない」等の記載が
> ある場合は、次の文案へ差し替える承認が必要です。
>
> 「ログイン中は、Firebase Authenticationのユーザー識別子をFirebase
> Analyticsの標準User-IDとして設定し、利用導線・無料体験・レポート表示の
> 集計に用います。質問本文、自由記述、氏名、メールアドレス、ペット名、
> 市区町村および認証情報はAnalyticsへ送信しません。」
>
> 実装・BigQuery取り込み時のデータ最小化とストア申告の見直し案は
> [`../analytics/server_event_ingestion_and_privacy_ja.md`](../analytics/server_event_ingestion_and_privacy_ja.md)
> に整理しています。これは公開ポリシーの変更そのものではありません。
| ユーザーコンテンツ | ハムスターの名前、種類、毛色、誕生日、写真、飼育環境、メモ | アプリ機能の提供 | Firestore、Firebase Storage | あり |
| 飼育記録 | 今日の様子、体重、走行距離、温湿度 | 記録、グラフ、評価、通知 | Firestore | あり |
| 購入情報 | プラン、契約状態、更新・解約予定日、決済結果 | 有料機能の提供 | Stripe、Firestore | あり |
| AI相談内容 | 質問、会話履歴、関連する飼育情報 | AI相談の生成、履歴表示 | OpenAI、Pinecone、Firestore | あり |
| 外部サービス情報 | SwitchBot TOKEN/SECRET、機器ID、温湿度 | SwitchBot連携 | SwitchBot、Firebase Functions / Firestore | あり |
| デバイス識別子 | FCMトークン、App Check情報 | 通知、不正利用防止 | Firebase | あり |
| 利用状況 | 画面利用や操作イベント | 品質改善、利用状況分析 | Firebase Analytics | 状況により関連 |
| 診断情報 | エラーコード、サーバーログ | 障害調査、セキュリティ | Firebase / Google Cloud | 状況により関連 |

## Apple App Privacy入力候補（v1.0.0）

- Location > Coarse Location: 収集する、Analytics
- Contact Info > Email Address: 収集する、App Functionality
- Identifiers > User ID: 収集する、App Functionality
- Identifiers > Device ID: 収集する、App Functionality / Analytics
- Purchases > Purchase History: 収集する、App Functionality
- User Content > Photos or Videos: 収集する、App Functionality
- User Content > Other User Content: 収集する、App Functionality
- Usage Data > Product Interaction: 収集する、Analytics
- Diagnostics > Other Diagnostic Data: 収集する、App Functionality / Analytics
- Tracking: いいえ

## Google Play データ セーフティ入力候補（v1.0.0）

### 全体回答

- アプリがユーザーデータを収集または共有するか: **はい（収集する）**
- データの共有: **いいえ**。Firebase、Stripe、OpenAI、Pinecone、SwitchBotは、契約上サービス提供のために処理する委託先として扱う前提。委託先が独自目的で利用する設定を追加した場合は再確認する
- 転送中の暗号化: **はい**
- データ削除をリクエストできるか: **はい**
- 削除リクエストURL: https://hamster-breeding-app.web.app/account-deletion/
- 独立したセキュリティ審査: 実施証明がないため **いいえ**

### データ種別

| Google Playの分類 | 収集 | 必須/任意 | 目的 | 主な根拠 |
|---|---|---|---|---|
| Location > Approximate location | はい | 必須 | Analytics | Firebase Analyticsがマスク済みIPアドレスからおおよその地域を導出 |
| Personal info > Email address | はい | 必須 | App functionality / Account management | Firebase Authentication |
| Personal info > User IDs | はい | 必須 | App functionality / Account management | Firebase UID、Stripe Customer ID |
| Financial info > Purchase history | はい | 任意 | App functionality / Account management | Stripeのプラン・契約状態。カード番号等はアプリ側で取得・保存しない |
| Messages > Other in-app messages | はい | 任意 | App functionality | AI相談の質問、直近会話、回答 |
| Photos and videos > Photos | はい | 任意 | App functionality | 利用者が選択したペット画像 |
| App activity > App interactions | はい | 必須 | Analytics | Firebase Analyticsの自動イベントと明示的な操作イベント |
| App activity > Other user-generated content | はい | 任意 | App functionality | ペットプロフィール、飼育記録、メモ、自由記述 |
| App info and performance > Diagnostics | はい | 必須 | App functionality / Analytics | API・Functionsの障害調査用ステータス、エラー、技術ログ |
| Device or other IDs | はい | 必須 | App functionality / Analytics / Fraud prevention, security and compliance | Firebase app-instance ID、FCMトークン、App Check情報 |

### 選択しないもの

- Location > Precise location: 選択しない
- Financial info > User payment info: カード番号等はStripeのWeb画面が直接処理し、アプリや運営者のデータベースへ保存しないため選択しない
- Health and fitness: 人の健康・運動情報を対象とするため、ハムスターの飼育記録だけを理由に選択しない
- Advertising or marketing目的: 広告機能を使用せず、Analyticsイベントを広告目的に利用しないため選択しない

### 実装確認メモ

- Androidマニフェストでは`AD_ID`とAdvertising Services関連権限を明示的に除外済み。ただしFirebase Analyticsのapp-instance IDは収集されるため、`Device or other IDs`は申告する
- AI相談は認証付きRAG APIへ質問と直近12件までの会話を送信し、回答をFirestoreへ保存するため、`Other in-app messages`を申告する
- Firebase Crashlytics / Performance Monitoring SDKは現在未導入。`Diagnostics`は主にAPI・Cloud Functions側の障害調査ログを根拠とする
- SDK追加、広告連携、Google Signals、BigQuery連携、ログ仕様の変更時は再確認する

## 提出直前の実機確認

- [ ] 新規登録、ログイン、ログアウト
- [ ] 今日の様子、体重、走行距離の保存
- [ ] 写真の登録と削除
- [ ] SwitchBot連携と解除
- [ ] AI相談履歴の削除
- [ ] Stripe Checkoutの料金・自動更新条件表示
- [ ] Stripe Customer Portalの契約確認・解約導線
- [ ] アカウント削除前の契約案内と、削除を続行できること
- [ ] アカウント削除後に再ログインできないこと
- [ ] 公開URLがすべてHTTPSで開けること
