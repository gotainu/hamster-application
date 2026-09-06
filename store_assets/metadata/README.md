# ストア掲載メタデータ

更新日: 2026-09-06

日本向け初回提出でApp Store ConnectとGoogle Play Consoleへ入力する原稿です。審査用アカウントのパスワードは、このフォルダへ保存せず各ストアの審査欄へ直接入力します。

## ブランド画像

- 基準マーク: `store_assets/icons/hamster_pencil_mark_master.png`
- 表現: 純黒背景に、生成り色の太い鉛筆線で描いたハムスターの顔
- 構成: 下側を閉じない下膨れの顔輪郭、輪郭を横切る左右3本のひげ、顔下の手描き心拍線。目・鼻・口・体・文字は使用しない
- iOS / Androidの端末アイコンと両ストア用アイコンは、この基準マークから生成する

## Google Play

- アプリ名: 30文字以内
- 短い説明: 80文字以内
- 詳しい説明: 4,000文字以内
- アプリアイコン: `store_assets/icons/google_play_icon_512.png`
- フィーチャーグラフィック: `store_assets/google_play_feature_graphic_1024x500.png`
- スマートフォン画像: `store_assets/screenshots/android_phone/`（1080×1920、JPEG、4枚）
- 初回リリースノート: `google_play/ja-JP/release_notes_1.0.0.txt`

根拠: https://support.google.com/googleplay/android-developer/answer/9859152 / https://support.google.com/googleplay/android-developer/answer/9866151

## App Store

- 名前: 30文字以内
- サブタイトル: 30文字以内
- プロモーションテキスト: 170文字以内
- 説明: 4,000文字以内
- キーワード: UTF-8で100バイト以内
- アプリアイコン: `store_assets/icons/app_store_icon_1024.png`
- 6.9インチiPhone画像: `store_assets/screenshots/ios_iphone_6_9/`（1320×2868、JPEG、4枚）
- 初回配布対象はiPhoneのみ。iPadはレスポンシブUI整備後に再検討する

根拠: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information / https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information

## 公開範囲

初回公開地域は日本のみです。支払い方式は現行のStripe Checkout / Customer Portalを維持し、却下された場合に規約番号・審査文面・指摘画面を記録して対応を判断します。
