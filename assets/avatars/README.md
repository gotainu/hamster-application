# Hamster avatar PNG assets

## 受け入れ仕様（2026-10-31）

新画像は本人制作中。画像生成・仮画像配置・既存画像の置換は行わず、完成後に下記の既存キーへ追加する。進捗の正本は[PROJECT_STATUS.md](../../PROJECT_STATUS.md)の`AVT-06`／`REL-02`／`REL-03`。

- 推奨形式：透過PNG（RGBA、sRGB）。透明に見える市松模様・白背景を画像へ焼き込まない。
- 推奨配信用キャンバス：512×512px。1024×1024pxの高解像度原稿でも受領可能。1毛色の8状態で顔・胴体・足元・余白を揃え、耳や足を切らない。既存PNGには1024〜1402px・非正方形もあり、今回一括リサイズしない。
- ファイル名は下表の英字キーと状態名をそのまま使用。小文字・半角アンダースコア、拡張子`.png`。日本語名、連番、空白、`@2x`の独自追加は使わない。
- 配置パス：`assets/avatars/{body_type}/{color_variant}/{condition}.png`。1毛色につき8状態を推奨。`stable.png`のみ先行追加する場合は、他の状態が同じ毛色のstableに代替されることを明記して採用判断する。
- デザイン原稿（PSD等）はアプリassetsへ入れず、配信用PNGと「種類・毛色・状態／差替えか新規か」の対応を渡す。既存の同名PNGを置換する場合は、対象を本人が明示する。

### 種類・毛色と既存キー

| プロフィールの種類 | 毛色の選択肢 | body_type/color_variant |
|---|---|---|
| シリアン | ゴールデン・茶系（通常色） | `syrian/golden` |
| シリアン | クリーム・淡色系 | `syrian/cream` |
| シリアン | ホワイト系 | `syrian/white` |
| シリアン | ブラック・濃色系 | `syrian/dark` |
| シリアン | 白黒・ダルメシアン系 | `syrian/dalmatian` |
| ジャンガリアン | ノーマルグレー系 | `djungarian/normal` |
| ジャンガリアン | ブルーサファイア系 | `djungarian/sapphire` |
| ジャンガリアン | パールホワイト系 | `djungarian/pearl` |
| ジャンガリアン | プディング・クリーム系 | `djungarian/cream` |
| ロボロフスキー | ノーマルブラウン系 | `roborovski/normal` |
| ロボロフスキー | ホワイトフェイス・淡色系 | `roborovski/white_face` |

シリアンの通常色は`golden`で、`syrian/normal`へ改名しない。キャンベルは既存仕様でジャンガリアンのnormal／sapphire／cream／pearlを共有する。チャイニーズや旧表記・未知値には既存の互換変換がある。新しい実在PNGを増やすだけのために、保存済みの種類・毛色やenum／assetKeyを改名しない。表にない新しい独立種類・毛色は、画像受領後に既存resolverの対応が必要かを限定確認する（PNG配置だけで新しい選択肢は増えない）。

### 状態名（8種類）

`happy.png`、`stable.png`、`worried.png`、`alert.png`、`insufficient_data.png`、`environment_discomfort.png`、`activity_high.png`、`condition_concerned.png`

一般80行は`avatar_asset_manifest.csv`、追加ダルメシアン8行は`dalmatian_asset_manifest.csv`に保持する。CSVは制作・配置の照合用で、実行時の選択ロジックではない。2026-10-31実在確認は通常色7状態・ダルメシアン8状態。通常色`alert.png`は未制作で既存fallbackを使用する。説明用`analysis_preparing_v1.png`を8状態へ数えない。「配置済み」は存在確認で、新画像のデザイン承認や端末確認完了の意味ではない。

## 実装と保存データの互換性

- 作成・編集は`lib/screens/pet_profile_edit_screen.dart`の同じ種類／毛色選択とstableプレビューを使用する。プロフィール詳細は既存の`imageUrl`写真を優先するため、写真を保存済みのプロフィールはアバター追加だけでは置換されない。
- `users/{uid}/pet_profiles/main_pet`に日本語の`species`・`color`、任意の`imageUrl`を保存する。独立した`avatarId`やPNGパスは保存しない。`subjectId`・記録・revision・ログインを変更する必要はない。
- `hamster_avatar_appearance_resolver.dart`が種類／毛色を英字キーへ変換し、`hamster_avatar_asset_resolver.dart`が状態別パスを組み立てる。状態は既存の状態判定から決まり、画像を増やしても健康判定を変えない。
- フォールバックは「対象状態PNG → 同じ種類・同じ毛色のstable.png → petsアイコン」。他種・他毛色・`assets/images/roi.png`への代替は行わない。種類・毛色未設定の詳細画面にも既存のアイコン表示がある。

## 画像受領後の最小統合手順

1. 上記構造のPNGフォルダ（または同構造ZIP）と、種類・毛色・置換指定を受領し、背景の実透過と8状態の余白・顔位置を目視確認する。
2. 実在PNGだけを該当ディレクトリへ追加。新しい末端ディレクトリを`pubspec.yaml`の`flutter.assets`へ明示登録する。`assets/avatars/`だけでは子階層は再帰登録されない。画像未提供の今は、存在しないディレクトリやPNGの登録を追加しない。
3. 既存CSVの該当statusを実物に合わせる。既存11組合せならresolver・Firestore変更は不要。次の読み取り専用検査で命名・PNG構造・登録漏れを確認する。

```sh
python3 tool/check_avatar_assets.py
# 例：追加した毛色の8状態を必須確認する場合（受領後）
python3 tool/check_avatar_assets.py --require syrian/cream
```

通常検査は未制作予定をpendingとして許容し、`--require`指定は8状態と末端ディレクトリ登録を必須にする。PNGのCRC・寸法・alpha対応を確認するが、画像全体のデコード成功・実際の透明画素・美観までを保証しない。今回の既存検査は15実在／73pendingでPASS、ダルメシアン必須PASS、通常色必須はalert未制作1件で想定どおりFAIL。新アセットの受け入れPASSとは区別する。

4. 新規画像だけのプロフィール作成／編集プレビュー、Homeと既存プロフィール表示、8状態のfixture表示・欠損時fallbackを限定確認する。保存確認が必要ならローカルfixtureを使い、実飼育プロフィールを書き換えない。完了済みのAI／認証／DeviceCheck E2Eは再実施しない。
5. 次期版は画像統合後に`1.0.1+3`へ更新する。Androidは[既存Play手順](../../docs/release/google_play_submission_runbook_ja.md#次期アバター更新版code3画像完成後の手順)、iOSは[既存署名手順](../../docs/release/ios_signing_physical_auth_20261018.md#次期アバター更新版build3画像完成後の手順)を再利用する。今回はビルド・アップロード・配信しない。

## 分析準備カード用イラスト（2026-10-17）

- 頬袋調整：ユーザー提供写真を形状参考に、既存 `analysis_preparing_v1.png` の頬袋だけを膨らませた画像へ更新。built-in image_genの編集を使用。写真の背景・手・食べ物は取り込まず、キャラクター、種を持つポーズ、透過、表示サイズは維持。旧版は今回の作業退避に保存。
- 頬袋調整の採用プロンプト（以下の初回生成promptに優先）：

> Use case: precise-object-edit.
> Asset type: transparent PNG mascot for HamCare's small analysis-preparation UI card.
> Input image 1 is the edit target: the existing warm golden-and-cream HamCare illustration, holding a small striped seed near its mouth. Input image 2 is ONLY a cheek-pouch shape reference, not a subject or scene to copy.
> Primary request: make BOTH cheek pouches noticeably fuller and more rounded than in image 1, like a hamster that has packed food into its cheek pouches. Follow the reference photograph's broad, outward-bulging pouches on the sides of the lower face. Increase the side silhouette of the cheeks by roughly 25–35%, with a natural soft sag toward the shoulders, so the filled pouches are clearly readable even when the asset is displayed about 100 pixels tall. Keep the body size unchanged; the fuller lower face should be the only visible change.
> Preserve the exact same mascot identity, golden and cream fur colors, illustration texture, gentle expression, large dark eyes, ears, nose, mouth, striped seed, paws, pose, full-body framing, feet, lighting, and transparent margins. Preserve the existing illustration style and existing canvas/composition as closely as possible. The enlarged cheeks should look naturally full of food, cute and calm, not sick or distressed.
> Do not copy the photograph's potato chip, hand, surroundings, real hamster color, or photographic style. No extra food, icons, text, effects, background, or new objects. Keep a genuinely transparent background and alpha channel. Edit the target illustration only.


- `syrian/golden/analysis_preparing_v1.png`: 種を頬袋へ運ぶ説明用マスコット。実際のペットの写真・健康状態・育成段階を表す素材ではありません。既存avatarの状態resolver／manifestには追加しません。
- 初回生成では既存 `syrian/golden/stable.png` をキャラクターと描画の参照としてbuilt-in image_genを使用。透過PNGを保持し、参照元のstable素材は置換していません。
- 採用プロンプト：

> Use case: identity-preserve. Asset type: a small transparent PNG illustration for HamCare's analysis-preparation card. The input is the existing HamCare mascot and is the character/style reference. Create a new calm pose of this same golden Syrian hamster gently tucking one small seed into its cheek pouch with a front paw, cheeks softly rounded as if gathering a little food. Keep the existing warm golden-and-cream fur, round body, dark glossy eyes, fine soft illustration texture and friendly proportions. Premium, understated, clean readable silhouette at small mobile-card size; not a photograph and not the user's actual pet. Front three-quarter or near-front view; full body visible with generous transparent margins. No badges, question marks, hearts, sparkles, charts, text, clothing, extra animals, scenery, frame or background. A genuinely transparent background; no white backdrop. Keep the pose natural and the expression quietly content. Do not enlarge the cheeks to comic extremes. No animation or game UI.
