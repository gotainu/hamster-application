# Hamster Care プライバシー申告チェックリスト

更新日: 2026-09-05

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
| ユーザーコンテンツ | ハムスターの名前、種類、毛色、誕生日、写真、飼育環境、メモ | アプリ機能の提供 | Firestore、Firebase Storage | あり |
| 飼育記録 | 今日の様子、体重、走行距離、温湿度 | 記録、グラフ、評価、通知 | Firestore | あり |
| 購入情報 | プラン、契約状態、更新・解約予定日、決済結果 | 有料機能の提供 | Stripe、Firestore | あり |
| AI相談内容 | 質問、会話履歴、関連する飼育情報 | AI相談の生成、履歴表示 | OpenAI、Pinecone、Firestore | あり |
| 外部サービス情報 | SwitchBot TOKEN/SECRET、機器ID、温湿度 | SwitchBot連携 | SwitchBot、Firebase Functions / Firestore | あり |
| デバイス識別子 | FCMトークン、App Check情報 | 通知、不正利用防止 | Firebase | あり |
| 利用状況 | 画面利用や操作イベント | 品質改善、利用状況分析 | Firebase Analytics | 状況により関連 |
| 診断情報 | エラーコード、サーバーログ | 障害調査、セキュリティ | Firebase / Google Cloud | 状況により関連 |

## Apple App Privacy入力時の確認候補

- Contact Info > Email Address: 収集する、App Functionality
- Identifiers > User ID: 収集する、App Functionality
- Purchases > Purchase History: 収集する、App Functionality
- User Content > Photos or Videos: 収集する、App Functionality
- User Content > Other User Content: 収集する、App Functionality
- Usage Data > Product Interaction: 収集する、Analytics
- Diagnostics: 実際に収集しているログの内容に合わせて選択
- Tracking: いいえ

## Google Play データ セーフティ入力時の確認候補

- Personal info > Email address
- App activity > App interactions / Other user-generated content
- Photos and videos > Photos
- Financial info > Purchase history
- Device or other IDs
- Health and fitnessは人の健康情報を対象とするため、ハムスターの飼育記録だけを理由に選択しない
- Service providersへの処理委託がGoogleの「共有」の例外に該当するかは、提出画面の最新定義で確認
- 「データ削除をリクエストできる」: はい

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
