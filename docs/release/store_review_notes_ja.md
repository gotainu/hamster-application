# Hamster Care 審査メモ（日本向け初回提出）

更新日: 2026-09-05

この文書は提出内容の原本です。審査用アカウントのパスワードなどの秘密情報はリポジトリへ保存せず、App Store Connect / Google Play Consoleの審査欄へ直接入力します。

## 提出方針

- 初回公開地域は日本のみです。
- 現行のStripe Checkout / Stripe Customer Portalによる月額プランを維持して提出します。
- AppleのApp内課金およびGoogle Play Billingは、この初回提出では実装しません。
- 却下された場合は、指摘された規約番号、審査文面、画面、日時を保存し、指摘内容に限定した対応を判断します。

## 審査担当者への機能説明

Hamster Careは、ハムスターの毎日の様子、体重、回し車の走行距離、飼育環境を記録するアプリです。有料プランでは、SwitchBot温湿度計との連携、温湿度の自動記録と環境評価、異常検知通知、飼育記録を踏まえたAI相談を利用できます。

有料プランは「Hamster Care Premium Plan」、月額500円（税込）、1か月ごとの自動更新です。アプリ内の「利用プラン」画面に料金、更新条件、解約後の利用期限、利用規約、プライバシーポリシーを表示しています。登録操作は外部ブラウザのStripe Checkout、契約確認・支払方法変更・解約はStripe Customer Portalで行います。

## 審査用アカウント

- メールアドレス候補: `test_20260308@example.com`
- パスワード: App Store Connect / Google Play Consoleへ直接入力（このファイルには記載しない）
- 前提: 提出直前にログイン、有料機能、Stripe契約状態を再確認する

## 確認手順

1. アプリを起動し、審査用アカウントでログインします。
2. 下部の「今日」で現在の状態と記録を確認できます。
3. 「記録」で今日の様子、走行距離、体重を入力できます。
4. 「変化」で活動量、温度、湿度、体重の推移を確認できます。
5. 「相談」でAI相談を確認できます。
6. メニューから「設定」→「利用プラン」を開くと、料金と契約状態を確認できます。
7. 「プランを管理する」を選ぶと、外部ブラウザでStripe Customer Portalが開きます。

## 審査欄へ記載する支払い説明案

本アプリの初回配信地域は日本のみです。有料プランの料金と自動更新条件は購入操作の直前にアプリ内で表示されます。決済は外部ブラウザでStripe Checkoutを使用し、契約確認、支払方法変更、解約はStripe Customer Portalから行えます。解約後も支払済み期間の終了までは有料機能を利用できます。

## アカウント削除

- アプリ内: 「設定」→「アカウントを削除」
- Web: https://hamster-breeding-app.web.app/account-deletion/
- 有料プラン利用中でもアカウント削除を妨げません。削除前にStripe契約は自動解約されないことを案内し、契約管理画面への導線と、そのまま削除を続ける選択肢を表示します。

## 公開ポリシー

- プライバシーポリシー: https://hamster-breeding-app.web.app/privacy/
- 利用規約: https://hamster-breeding-app.web.app/terms/
- 特定商取引法に基づく表記: https://hamster-breeding-app.web.app/commercial-transactions/
- サポート: https://hamster-breeding-app.web.app/support/

## Stripe決済に関する根拠資料

- 公正取引委員会 スマホソフトウェア競争促進法: https://www.jftc.go.jp/smartphone_msca.html
- 公正取引委員会 よくある質問（アプリ事業者向け）: https://www.jftc.go.jp/msca/index_yokuarusitumon.html
- 公正取引委員会 運用ガイドライン: https://www.jftc.go.jp/houdou/pressrelease/2025/jul/250729_01-4_smartphone_shishin.pdf
- Stripe解説: https://stripe.com/jp/resources/more/what-are-app-fees-japan-smartphone-law

これらは審査担当者へ最初から長文で主張するためではなく、決済方法を理由に却下された場合に、具体的な指摘内容と照合するための内部資料として使用します。

## 却下記録テンプレート

- ストア:
- 提出日時:
- 回答日時:
- 規約番号:
- 審査文面（原文）:
- 指摘画面・操作経路:
- 添付画像:
- こちらの回答:
- 再提出内容:
