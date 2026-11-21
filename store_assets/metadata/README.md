# ストア掲載メタデータ

## 2026-11-21 残存方針の確定（未提出・未配備）

価格は月額550円、返金は「利用者都合による支払済み料金の返金は原則として行いません。ただし、重複課金、当方のシステムによる誤請求、その他法令上返金が必要となる場合は個別に対応します。」に確定。期間末解約・期限まで利用・次回請求停止・日割りなしを返金と分離する。特商法は請求開示方式、窓口は既存Gmail、VOは不要。認証はFirebase、重要な契約/サポート通知はGmail APIを初回採用するが、本番通知は未実装。Relay実配送未確認は非ブロッキング。旧Live500円と既存契約は保持、新550円Priceは別承認後の新規申込だけへ。

今回、公開前Web文面/表示文字列と文書を整合した。掲載用txt、配信中アプリ、ストア設定、Live Stripe/Hostingは未変更。戦略C版は未提出で、既存Play Alphaの提出配信履歴とは区別する。現在の状態と次の工程は [本番切替Runbook](../../docs/release/web_billing_live_cutover_runbook_ja.md) を正本とし、下記の旧候補・税務待ち・メール未選定・Relay待ちの条件は現在の判断にしない。


<!-- hamcare-pricing-metadata-draft-20261119:start -->
## 2026-11-21 現在の原稿は未提出・ストア反映不可

11月19日に更新した次のtxtは、戦略Cの**将来版の公開前草案**です。11月21日は方針文書だけを更新し、txtの変更・Console保存・審査提出・一般公開は行っていません。

- `app_store/ja/description.txt`
- `app_store/ja/review_notes.txt`
- `google_play/ja-JP/full_description.txt`

正式商品名はHamCare プレミアム、月額550円、1か月ごとの自動更新です。アプリ外の公式Webで申込み、アプリは同じアカウントの既存利用状態を反映する構成を想定しています。

**現在配信中のFlutterには旧月額500円表示・有料登録ボタン・外部Stripe Checkoutへの購入CTAが残っています。購入CTA撤去待ちのため、この草案を提出できません。** 今回Flutter・既存Live価格・契約・テスター権限・ストア設定を変更していません。購入CTA撤去後の配布候補との照合、法務と料金の最終確認、適用要件の照合、本人の別承認が完了するまでストアへ貼り付けません。

公開用txtに内部の注意事項を混ぜず、本READMEと `docs/release/store_listing_ja.md`／`store_review_notes_ja.md`／`google_play_submission_runbook_ja.md` で未提出状態を管理します。以下の2026-10-25記録は当時の保存済み原稿の履歴であり、今回のtxtが既に保存・配信済みであることを示しません。

**11月21日の方針更新**：正式表示はPreview／本番Web／Stripe Test／Stripe Live／利用規約／特商法で「月額550円」に統一し、Stripeの最終請求額550円を正本とします。旧Live500円Priceと既存契約は保持し、別途承認後の本番切替で新Live550円Priceを作成して新規申込だけを接続します。Test Price550円は維持します。申告・納税上の扱いは別のバックオフィス事項で、料金表示やリリースの判断条件にしません。

今回は文書上の方針だけを更新し、HTML/JavaScriptや掲載用txtは変更していません。手元の画面・txtに残る旧税込/税抜表記は、後続の表示反映でこの新方針へ揃える必要があります。原稿へ反映済み・ストアへ提出可能とは記録しません。
<!-- hamcare-pricing-metadata-draft-20261119:end -->

## 旧原稿の保存履歴・共通メタデータ

原稿の内容は既存 `docs/release/store_listing_ja.md` を正とし、両ストアdescription.txtを保存済み説明へ同期した。21日・最大20件・体験終了後の有料範囲を含む。10/25にApp Store ConnectとGoogle Playの説明保存を確認。Android初版の最低OSは本人決定でAndroid7.0／API24以降（現AAB manifestと一致）。審査送信・アプリ公開は別工程。

更新日: 2026-10-25

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
