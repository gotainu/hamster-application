# Hamster avatar PNG assets

- 形式: 透過 PNG
- 推奨キャンバス: 512 x 512
- 同じ体型では、顔・胴体・足元の基準位置を統一してください。
- 初期構成は 10外見 x 8状態 = 80枚です。
- PNGが未配置でも、アプリは `assets/images/roi.png` へフォールバックします。

## 状態

- `happy`
- `stable`
- `worried`
- `alert`
- `insufficient_data`
- `environment_discomfort`
- `activity_high`
- `condition_concerned`

詳細なパスは `avatar_asset_manifest.csv` を参照してください。

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
