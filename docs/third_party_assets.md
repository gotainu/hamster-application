# Third-party visual assets

## 2026-11-23 App Store Content Rightsの本人確認

App Store Connectの実際の質問は「Does your app contain, show, or access third-party content?」。選択肢は、Yes（第三者コンテンツを含む・表示又はアクセスし、必要な権利がある）とNo（第三者コンテンツを含まない・表示又はアクセスしない）。下記のCC0地図・Googleログイン用素材・Caveat等を利用するため、回答案はYesとする。保存結果は既存の提出手順書に記録する。

来歴・利用範囲の記録が不足していた次の3群について、本人へ実物と用途を示して確認し、2026-11-23に「記載の素材は利用可能と確認できる」との回答を受領した。これは本人による利用可能性の確認記録であり、全素材が自作であるとの推定、第三者からの個別許諾の取得代行、又は独立した法務監査の完了を意味しない。

1. **既存の写真・合成背景・ブランド画像**：[相談アイコン roi.png](../assets/images/roi.png)、[起動画面 roiroi.png](../assets/images/roiroi.png)、[提供済みの状態別背景](../assets/images/theme/)、[ログイン用画像](../assets/images/auth/)、[現行輪郭アイコンの正本](../store_assets/icons/hamster_pencil_mark_master.png)。アプリ内の配布・表示に利用可能であることを本人確認した。別途生成・採用記録があるアバターや導入画像を、来歴不明へ戻すものではない。
2. **SwitchBot説明画像6点**：[準備](../assets/images/switchbot_guide_01_prepare_hub_app.png)、[アプリを開く](../assets/images/switchbot_guide_02_open_app.png)、[プロフィール設定](../assets/images/switchbot_guide_03_profile_settings.png)、[バージョン操作](../assets/images/switchbot_guide_04_tap_version.png)、[Token／Secretの説明](../assets/images/switchbot_guide_05_token_secret.png)、[温湿度計の選択](../assets/images/switchbot_guide_06_select_meter.png)。含まれる製品写真・ロゴ・公式アプリ画面等を、HamCareの設定手順の説明に利用できることを本人確認した。
3. **本人のYouTube台本・サムネイル**：本人チャンネル`@gohamsterwell-being`に対応する、RAGの台本抜粋・動画タイトル・サムネイルのアプリ内表示。借用素材がある場合の利用範囲も含め、利用可能であることを本人確認した。現在の表示経路は[既存RAG文書](rag.md)を参照し、確認対象を研究論文全文の転載や、未搭載の配信機能まで広げない。

既存の個別根拠は以下を維持する。Caveatは[同梱OFL](../assets/fonts/OFL.txt)の条件で利用し、`assets/fonts/`をFlutter assetsへ登録済み。アバターの生成・参照・採用は[既存制作記録](../assets/avatars/README.md)、導入画像4点の生成記録は`PROJECT_STATUS.md`の2026-09-19／20の履歴を参照する。今回、素材の再制作・差替えや利用条件の変更は行わない。

## Japan prefecture map

- Asset: `assets/maps/deformed-japan-prefecture-map.svg`
- Creator: lalamalink
- Source: https://github.com/lalamalink/japan-map-svg
- License: CC0 1.0 Universal
- Imported version: 2026.06.30

The map is a stylized illustration used only to make a selected prefecture
visually recognizable. It is not a surveying or administrative reference map.

## Google Sign-In mark

- Asset: `assets/images/auth/google_g_logo.svg`
- Source: Google Identity branding guidelines
  (https://developers.google.com/identity/branding-guidelines)
- Use: the official multicolor `G` shown only beside the Google sign-in action.
