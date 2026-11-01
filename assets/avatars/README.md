# Hamster avatar PNG assets

<!-- hamcare-avatar-final-integration-20261101:start -->
## 現在：ブラック／白黒パイド統合・標準88枚（2026-11-01）

- **採用と制作の区別**：シリアン・ブラックと白黒パイドのstable2枚は本人が外見を目視承認済み。保存済み制作記録には残14状態が存在しなかったため、その事実を伝え、本人の「未制作14枚も制作して統合する」という明示許可に基づいて今回制作した。新14枚は形式・ポーズの自動目視確認PASS後に採用配置したが、画像ごとの本人目視を実施済みとは記録しない。
- **配置88枚**：既存72枚は内容不変。追加16枚は`syrian/dark`／`roborovski/pied`の各8状態で、最終reportの採用元ready PNGと本番コピーのSHAが一致する。ブラックstableは既存PNGをそのまま利用し、パイドstableは`ready/stable_bw_v2.png`を`assets/avatars/roborovski/pied/stable.png`へ配置した。旧茶色`ready/stable.png`・原画・旧候補・比較資料は保持し、本番へ混入させない。
- **生成・登録の範囲**：新14状態は毎回、当該の承認済みstableを外見A、採用済みダルメシアン同状態を姿勢B、承認済みジャンガリアンnormal同状態を品質Cとして、1枚ずつ内蔵画像生成・原画保全・512px透過化・検査した。`pubspec.yaml`には実在する`assets/avatars/syrian/dark/`と`assets/avatars/roborovski/pied/`の2末端だけを追加し、版を`1.0.1+3`へ更新。既存pied選択肢／モデル／Resolverを再利用し、今回の機能コード・プロフィール形式・円形アイコンは変更しない。
- **限定12件PASS**：16画像の実Flutter bundle登録・完全decode、48／72px白暗とHome190・詳細132・編集142の計112表示セルで、意図しないstable代替0・例外0。通常Repoモックで両色の保存・再読込、旧プロフィール互換、未制作white_faceの既存petsアイコンfallbackを確認した。実画像の白暗・小表示・既存Widget描画も目視確認。これはローカルfixture確認で、今回追加画像の実機表示確認・本番プロフィール書込とは区別する。既存の認証・AI相談・課金・DeviceCheck等の試験は再実施しない。
- **保全・別保留**：事前747ファイルの内容指紋はpubspec以外不変（既存72画像を含む）。台帳96予定のうち標準88配置、未制作はwhite_faceの8枚のみ。説明素材2件は完成数へ数えず、analysis_preparingは意味未確定の別保留。円形zoom／トリミングの調整は今回対象外。
- **リリース候補**：Android 1.0.1/code3の署名済AABとiOS 1.0.1/build3のDistribution署名IPAをローカル生成済み。両成果物の全88PNGが元PNGとSHA一致、既存署名・版・ZIP整合もPASS。最終パス・SHA・監査記録はPROJECT_STATUS.mdと既存リリース手順書を参照する。ストアアップロード・配信・審査送信・commit／pushは今回行わない。
- **証拠・一覧**：`../../output/hamcare-avatar/revisions/pose-v2-20261031/_tools/final_integration_20261101/limited-verification-summary.json`、同`checker-final.json`／`final-integrity.json`／`flutter-targeted-test.log`。画像の確認入口は同revisionの`index.html#final-two-looks`、各色`final_index.html`。canonical／最終試行reportとvisual_reviewへ限定確認PASS・実機未実施を反映した。以下の未承認・未配置・72枚の記載は当時の履歴として保持する。
<!-- hamcare-avatar-final-integration-20261101:end -->

<!-- hamcare-avatar-pied-bw:start -->
## ブラック正式採用・白黒パイドstable修正（2026-11-01・最終統合前の履歴）

- syrian/darkの既存ready/stable.pngは本人が顔・体型・毛色とも正式承認。本人承認済み・採用対象、本番未配置。画像の再生成・加工はせず、既存PNGのSHAを維持した。残7状態は今後の制作対象。
- roborovski/piedの旧茶色案は体型・顔・画風が本人合格。毛色のみ白地＋黒〜濃いチャコールへ内蔵imagegenで編集。旧raw／master／ready/stable.pngは保持し、同じpied内のraw・masters・ready/stable_bw_v2.pngへ新原画／1024／512px透過を保存した。新キーやappディレクトリは追加しない。
- 現行reportはreports/stable.json／stable_bw_v2.json、現在の候補はready/stable_bw_v2.png。旧茶色ready/stable.pngは履歴。旧案の判定はreports/stable_brown_v1.jsonに保存し、初回試行reportも保持。顔等の旧合格と、新白黒毛色の本人確認待ちを分離する。
- 新版はCRC／全decode／RGBA／512px／実透過PASS、原画と白暗背景の限定目視で茶系毛色残り・背景残りなし、黒部の毛の陰影・ピンクの耳鼻足・低いロボ体型を確認。新旧bbox端差最大1px、silhouette IoU約0.986。新白黒版は本人未承認・本番未配置。
- 既存index.html#two-stable-coat-reviewの白暗・通常／小表示比較を新旧パイドへ更新。ブラックの追加確認や既存72枚／承認済みポーズの再確認は不要。編集指示はroborovski/pied/prompts/stable_bw_v2.txt。
- 次はこの白黒v2 stableの本人採用後だけ、同じ採用原画を外見基準に残7状態を制作。ブラックの残7状態も今後対象、最終計16枚予定を維持。今回はstable1枚編集のみ。72枚・既存piedモデル／Resolver・円形枠・pubspec・署名環境・white_face／analysisの別保留を維持し、本番配置・ビルド・配信・commit／pushはしない。
<!-- hamcare-avatar-pied-bw:end -->

<!-- hamcare-avatar-two-stables:start -->
## ブラック／パイドのstable外見確認（2026-11-01・旧茶色案提示時点の履歴）

- 既存72枚・修正版50枚採用・配置検査／限定13件PASSは維持。今回確認するのはsyrian/darkとroborovski/piedのstable2枚の顔・毛色・模様のみで、既存72枚の再承認を求めない。
- darkは../../output/hamcare-avatar/revisions/pose-v2-20261031/syrian/dark/ready/stable.pngの既存候補を再利用（制作済み・本人毛色確認待ち）。goldenとの画風／体型比較を用意。新blackキー・選択肢追加・再生成なし。
- piedは既存normal stableを顔・低い体型・画風基準に、本人許可の白地＋砂茶／灰褐色斑の代表デザイン案stable1枚を内蔵imagegenで制作。原画・512px透過・技術検査・明暗目視・promptを同revision/roborovski/pied/へ保存。特定個体の資料はなく、斑位置・面積は本人未承認（design_proposal=true／coat_reference_verified=false）。white_face改名・ダルメシアン流用はしない。
- 既存index.html#two-stable-coat-reviewへ、Syrian golden／Robo normalとの白暗・通常／小表示比較を追加。ファイル名はstable.png、標準キーはdark／piedを維持。両候補とも未承認・未配置。
- 次は両stableの本人採用後だけ、同じstable＋採用ダルメシアン同状態＋承認済みDjun normal同状態を毎回参照して7状態ずつ展開。最終追加は各8状態、計16枚（現在stable候補2、残14は未制作）。未承認stableから量産しない。
- white_faceとanalysis_preparingは別保留。piedの既存選択肢／モデル／Resolver／12件PASS、既存fallback、円形枠、プロフィール、pubspec、配置72枚は変更しない。本番配置・ビルド・upload・配信・commit／pushなし。下記「資料待ち／未制作」は当時の履歴で、現在はこのstable2案の本人確認待ちが優先する。
<!-- hamcare-avatar-two-stables:end -->

<!-- hamcare-avatar-pose-expansion-progress:start -->
<!-- hamcare-avatar-approved-placement:start -->
## 修正版50枚の本人承認・アプリ配置（2026-11-01・72枚配置時点の履歴）

- 修正版50枚は本人採用承認済み・配置済み。今回43枚の承認を反映し、既承認Djun normal7枚も維持した。最終canonical report／同じ最終試行reportとvisual_reviewへowner_approved・production_placement・production_asset_path・production_sha256を記録。初回不採用や旧差戻し候補は履歴のまま残す。
- 最終512px透過PNGを既存比較一覧・SHAで選び、assets/avatars/<body>/<color>/<condition>.pngへ無加工コピー。原画・旧候補・比較画像は保持。robo environment_discomfortは再生成後のreadyを使用。今回画像の加工・再生成なし。
- 現在のstable7枚は既存候補領域のreport対応readyを、本人の「stable維持・既存PNG配置」指示に基づいて配置。元stable・原画の見た目とbyteを維持。既存シリアン15枚もbyte不変。
- 新規配置57枚、標準合計72枚（9外見×8状態）。pubspec.yamlへsyrian/cream・white、djungarian/normal・sapphire・pearl・cream、roborovski/normalの7フォルダを登録した。保留3外見や制作候補領域は登録しない。
- 既存checkerの9外見必須はPASS（96予定・72実在・24保留・errors0）。新57枚はSHA一致・CRC・512px・RGBA・実アルファPASS。恒久Flutter3.47.7で限定13件PASS。実PNG72枚・9色ラベル再読込・全8状態Resolver、既存Widget729セルの指定画像表示／fallback0／例外0を確認。48／72／150pxとHome190・詳細132・編集142枠154の全身contain表示は切れなし。実機確認は別。既存飼育プロフィール・写真優先・状態判定・欠損fallbackは変更しない。
- Drawer66内88＋Y5／相談70内96.6＋Y5の円形アイコンは既存の顔中心zoomで、足元やひげ端・補助線の一部はトリミングされる。実Widgetで確認し、全枠で全身切れなしとは記録しない。既存表示を維持し、PNGの描き直し・UIコード変更は行わない。
- dark／pied／white_faceは各8状態を未配置のまま保持し、別毛色で埋めない。analysis_preparing11案は意味未確定、既存説明素材2件は標準72へ含めない。独立pied実装と既存12件PASSは維持。
- 2026-11-01同内容の配置依頼を照合：修正版50・維持stable7の採用元＝配置先＝report SHAと既存CSV・末端登録が一致。既存15を含む標準72枚を維持し、再コピー／置換／追加登録修正は0。既存限定13件PASSを再利用し、生成・表示テストは繰り返さない。ブラックstableの直近正式承認、白黒パイドv2の本人毛色確認待ちは上の最新節どおり維持し、双方を資料待ちへ戻さない。
- 証拠は../../output/hamcare-avatar/revisions/pose-v2-20261031/_tools/integration/。下の未承認・未配置・15実在の記載は当時の履歴。次期code3/build3の生成・端末更新・ストア操作・commit／pushは今回行わない。
<!-- hamcare-avatar-approved-placement:end -->

## 本人承認7枚を基準にしたポーズ展開（2026-10-31・承認と配置前の履歴）

- 修正版Djun normalの非stable7枚は本人ポーズ承認済みで、原画・512px・reportを保持。本番配置は0。下の「本人確認待ち」「他外見へは確認後」は承認前の履歴として保存し、現状を未承認へ戻さない。
- 今回は既存台帳の43対象（Djun sapphire／pearl／cream各7、robo normal7、syrian cream／white各7、golden alert1）を内蔵imagegenで1枚ずつ制作する。生成43/43、技術PASS 43／ポーズ自動目視PASS 43／要確認0／目視待ち0／原画保存済み記録待ち0／未着手0。新候補の本人承認0、本番配置0。自動PASSは最終ポーズ承認ではない。
- 制作・比較は`../../output/hamcare-avatar/revisions/pose-v2-20261031/<body>/<color>/`のraw・ready・reports・prompts・明暗／小表示比較へ分離。既存採用15枚・stable原本・旧候補を上書きしない。実際の外見／ポーズ参照と生成promptを各reportに記録する。
- 未追跡ダルメシアン`analysis_preparing_v1.png`は実画像照合で説明用候補と分類した。RGB・アルファなし、未参照・未採用であり、標準状態や透過readyに昇格しない。checkerの正確な1パス分類追加後、台帳96件／15実在／81pendingはPASS、元SHA `f53e62434014a74cfb229911d47627c37a1d039626cd82678f32251dba5ca2a2`不変。下の台帳外FAILは分類前の経緯。新たなpiedテストは実行しない。
- dark stableは本人毛色確認待ち・差分未展開。piedは独立キーと12件PASSを維持するが画像資料待ち。white_faceは未制作、analysis_preparingの意味は保留。43対象と別扱いにする。
- 現在：43対象の候補制作工程終了・本人確認待ち。次：`新候補の本人確認・要確認箇所の判断`。既存管理表`AVT-06`を更新し、重複するタスク表は増やさない。アプリコード変更・本番assetsへの組込・ビルド・upload・配布・Git保存は行わない。
<!-- hamcare-avatar-pose-expansion-progress:end -->

## ダルメシアン実画像のポーズ読取と再制作（2026-10-31）

本人目視で前回のstable以外50候補はポーズ品質差戻し。技術検査履歴を消さず、原画・512pxと旧検査記録を保持する。stable・既存採用シリアンは変更しない。以下は採用済み`syrian/dalmatian`8ファイルをそれぞれ実画像で開いて読んだ記録で、状態名からの想像ではない。

| 状態 | 実画像から読んだ向き・姿勢・手足・表情・補助表現 |
|---|---|
| `stable` | 正面に重心を置く直立座り。胴体は縦長で後足2本を左右に接地し、前足は胸下に自然に下げる。黒い目を開き、穏やかな口。台座は旧素材の背景表現としてあり、新規へは転写しない。 |
| `happy` | 正面の直立座り、胴をやや起こし重心は後足。前足2本を顎下近くへ高く曲げる。目は弧状に閉じ、口を開く喜び。新規では同じ喜びの強さを保ち、歯は足さない。 |
| `worried` | 正面で少し肩と頭を縮める座り。後足は左右に接地、両前足を口元のすぐ下へ寄せる。目・口が下がり心配した表情、左上に汗3滴。happyより縮こまる。 |
| `alert` | 胴は起きた座り姿だが全身を左前方へ3/4向きにし、顔と耳を左の気配へ向ける。後足で支え、前足を胸に曲げる。目を大きく開く。左上に短い注意線3本。 |
| `insufficient_data` | 正面で頭を右へ軽く傾ける座り。前足は口元ではなく胸下に低く置き、後足2本を接地。中立〜困惑の表情、左上に疑問符1個。病状や伏せ姿ではない。 |
| `environment_discomfort` | 背中を大きく見せる左後方3/4の丸い座り、顔だけ左肩越しに振り返る。胴を丸め重心は低く後方。前足は隠れ、足は1本だけ一部見える。耳を寝かせ目を細め口を下げ、短い震え線。 |
| `activity_high` | 全身は左向き横長の跳躍／走り。胴体を低く前へ伸ばし、頭も左へ、前足2本を前へ出し後足は後方へ伸ばす。地面から離れる。後ろに小さな速度線・砂煙。健康良好の断定ではなく動き量の表現。 |
| `condition_concerned` | 左前方3/4向きで極めて低い伏せ。胴は丸いが頭を前下方に下げ、前足2本を顔の両脇に広げ接地、後足は腹の下に畳む。目・耳・口を控えめに下げる。上方に短い沈み線と小さな渦。 |

今回の範囲はジャンガリアンnormalの非stable7状態だけ。外見Aは毎回同じnormal stable、ポーズBは対応する上表の実画像。前足の微差という旧制限・全足元の高さを揃える整形は撤回し、全身方向／動作／重心を優先する。生成原画は`output/hamcare-avatar/revisions/pose-v2-20261031/djungarian/normal/raw/`、512pxは`ready/`へ旧版と分離。ポーズ品質は本人確認待ちで、形式PASSと区別する。他外見へは7枚の本人確認後に展開し、今回は本番配置・build・upload・commit／pushしない。

### ブラック補完・パイド独立追加と関連確認（2026-10-31）

- ブラックは現行`hamster_avatar_appearance_resolver.dart`の`ブラック／ダーク／濃色／black → dark`、`syrian/dark`を使用し、新しいblackキーは作らない。黒系stable候補は`../../output/hamcare-avatar/revisions/pose-v2-20261031/syrian/dark/ready/stable.png`（原画は同階層raw）。既存goldenの体型・顔立ち・画風を継承した全体黒／チャコール案。形式・目視確認済みだが具体的な毛色分布は未確認で、本人確認前に状態差分を作らない。
- パイドは`HamsterAvatarColorVariant.pied`／assetKey `pied`をenum末尾へ追加し、ロボの毛色選択肢に独立表示。`パイド／pied／piebald`は広いwhiteFace判定より先に解決する。明示パイド値はpied、曖昧な旧ホワイト／淡色／white_faceは従来のwhiteFaceのまま。旧プロフィールや他種類の色判定を一括変更しない。
- プロフィール作成・編集は既存共通Resolverから選択肢・表示ラベルを取得するため、画面の別管理表は増やさない。既存`PetProfile`／通常Repoのcolor文字列を保存・再読込する。新DB項目・サーバー毛色enum・本番データ移行は不要。画像欠損は「pied指定状態→pied stable→petsアイコン」で、white_faceへ代替しない。
- 画像は`roborovski/pied/`のstableから受け入れる予定だが、現在は対応する原画／写真なし。必要資料は白斑の位置・面積、地色、顔・耳周辺・背中の色がどこまで残るか分かる画像または本人の明示指定。normalやwhite_faceの名前変更で代用しない。候補未制作で、架空画像・存在しない末端アセット登録は追加しない。採用時だけ`pubspec.yaml`へ`assets/avatars/roborovski/pied/`を登録する。
- 関連検証：恒久Flutter3.47.7の`flutter test --no-pub test/hamster_avatar_pied_test.dart test/measurement_profile_quality_test.dart`は12件PASS。最終アサーションでpied新8件だけ再実行PASS。通常Repoモックの保存→再読込→表示ラベル／外見、whiteFace互換、実Widgetの欠損fallbackを確認し、実機・本番プロフィール書込とは区別する。
- 台帳検査はpied8行を含む96件を認識。不整合は作業前からの未追跡ダルメシアン`analysis_preparing_v1.png`1件（標準台帳外）のため全体FAILであり、pied追加の失敗ではない。今回このファイルを削除・状態追加・黙って除外しない。新規画像8候補の個別PNG検査はPASS。
- 修正版7枚の本人確認後の展開候補はDjun sapphire／pearl／cream各7、robo normal7、未採用syrian cream／white各7・golden alert1の計43状態。既存採用済みシリアン15枚は変更しない。darkはstable毛色確認、piedは参考資料とstable確認が先。white_face／analysis_preparingの制作は今回含めない。

<!-- hamcare-avatar-sequential-progress:start -->
## 逐次候補制作（2026-10-31・前回履歴）

本人提供のジャンガリアンnormal／ロボロフスキーnormal stableを原本保持して参照し、内蔵imagegenで1枚ずつ候補制作を進める依頼へ更新された。以前の「画像未提供・生成しない」は受け入れ準備時点の履歴で、今回の生成指示を禁止するものではない。

- 標準88件中、既存採用15件は再生成・置換しない。本人提供stableの再利用2件。今回生成55対象、自動・目視検査PASS 55／要確認0／目視待ち0、原画保存済み・記録待ち0、未着手16件（外見資料保留16／実行可能未着手0）。PASSも本人未承認の候補で、本番採用済みとは扱わない。
- 保存：`../../output/hamcare-avatar/<body>/<color>/raw/`（原画）、`masters/`（1024px）、`ready/`（512px透過）、`reports/<state>.json`、`visual_review.json`、`previews/`。各毛色の`index.html`から個別原画・PNG・検査記録をたどれる。白／暗背景の状態名付きコンタクトシートは目視用で、アプリPNGとは別。
- 全外見の確認入口は`../../output/hamcare-avatar/index.html`。`overview_white.png`／`overview_dark.png`からも確認できる。既存採用15件は過去素材を読取参照して表示し、今回の新仕様適合検査とは区別する。本人提供ジャンガリアンstableの原本台座も保持。
- 参照・プロンプト・出力先・SHA・再生成回数・検査・本人承認状態は既存report方式を使い、制作進捗は既存CSVの対応statusへ反映する。指定状態を前の生成状態から編集する連鎖は行わない。
- 標準88件のうち`syrian/dark`と`roborovski/white_face`の16状態は外見資料待ち。darkの具体的模様・白胸／白腹、white_faceの顔の白い範囲を推測で確定しない。これは制作済み候補の技術・目視不良ではなく参照不足による未着手保留。実行可能な他外見を先に制作する。
- 既存キットの`analysis_preparing`11件案は意味未確定で保留。ローカルruntime8状態／88件へ勝手に増設せず、既存説明用`analysis_preparing_v1`へ割り当てない。
- 前回終了時点：確定対象生成完了・外見資料待ち。その後、非stable50候補は本人がポーズ品質を差戻し。現在は上の再制作節とPROJECT_STATUS参照。次は`確定対象の生成は完了・dark／white_faceの外見資料待ち`。停止時は保存済みreportと原画から再開し、バックグラウンド継続とは説明しない。
- 候補は本番assetsへ配置しない。コード・プロフィール・識別子・ビルド・upload・配布・Git commit／pushは対象外。原本と既存採用PNGは変更しない。
<!-- hamcare-avatar-sequential-progress:end -->

## 受け入れ仕様（2026-10-31）

受け入れ準備時点の履歴：新画像は本人制作中で、当時は画像生成・仮画像配置・既存画像の置換を行わず、完成後に既存キーへ追加する方針だった。現在の候補制作は上記の本人指示に従い、本番配置とは分離する。進捗の正本は[PROJECT_STATUS.md](../../PROJECT_STATUS.md)の`AVT-06`／`REL-02`／`REL-03`。

- 推奨形式：透過PNG（RGBA、sRGB）。透明に見える市松模様・白背景を画像へ焼き込まない。
- 推奨配信用キャンバス：512×512px。1024×1024pxの高解像度原稿でも受領可能。同じ個体らしい比率・描画倍率・画風を保ち、耳や足を切らない。2026-10-31の本人指定により、状態表現に必要な全身方向・姿勢・四肢・シルエットの変更を許可し、全状態の輪郭や足元の高さを無理に同一にはしない。既存PNGには1024〜1402px・非正方形もあり、今回一括リサイズしない。
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
| ロボロフスキー | パイド（独立追加） | `roborovski/pied` |

シリアンの通常色は`golden`で、`syrian/normal`へ改名しない。キャンベルは既存仕様でジャンガリアンのnormal／sapphire／cream／pearlを共有する。チャイニーズや旧表記・未知値には既存の互換変換がある。新しい実在PNGを増やすだけのために、保存済みの種類・毛色やenum／assetKeyを改名しない。表にない新しい独立種類・毛色は、画像受領後に既存resolverの対応が必要かを限定確認する（PNG配置だけで新しい選択肢は増えない）。

### 状態名（8種類）

`happy.png`、`stable.png`、`worried.png`、`alert.png`、`insufficient_data.png`、`environment_discomfort.png`、`activity_high.png`、`condition_concerned.png`

一般88行（今回piedの8行を追加）は`avatar_asset_manifest.csv`、追加ダルメシアン8行は`dalmatian_asset_manifest.csv`に保持する。現在の制作台帳は12外見×8状態＝96件。既存8状態キーは変更しない。CSVは制作・配置の照合用で、実行時の選択ロジックではない。2026-11-01現在は11外見88枚を配置・登録済み（先頭の最終統合節を参照）。以下は2026-10-31時点の履歴：通常色7状態・ダルメシアン8状態。通常色`alert.png`は未制作で既存fallbackを使用する。説明用`analysis_preparing_v1.png`を8状態へ数えない。「配置済み」は存在確認で、新画像のデザイン承認や端末確認完了の意味ではない。

## 実装と保存データの互換性

- 作成・編集は`lib/screens/pet_profile_edit_screen.dart`の同じ種類／毛色選択とstableプレビューを使用する。プロフィール詳細は既存の`imageUrl`写真を優先するため、写真を保存済みのプロフィールはアバター追加だけでは置換されない。
- `users/{uid}/pet_profiles/main_pet`に日本語の`species`・`color`、任意の`imageUrl`を保存する。独立した`avatarId`やPNGパスは保存しない。`subjectId`・記録・revision・ログインを変更する必要はない。
- `hamster_avatar_appearance_resolver.dart`が種類／毛色を英字キーへ変換し、`hamster_avatar_asset_resolver.dart`が状態別パスを組み立てる。状態は既存の状態判定から決まり、画像を増やしても健康判定を変えない。
- フォールバックは「対象状態PNG → 同じ種類・同じ毛色のstable.png → petsアイコン」。他種・他毛色・`assets/images/roi.png`への代替は行わない。種類・毛色未設定の詳細画面にも既存のアイコン表示がある。

## 画像受領後の最小統合手順

1. 上記構造のPNGフォルダ（または同構造ZIP）と、種類・毛色・置換指定を受領し、背景の実透過と8状態の余白・顔位置を目視確認する。
2. 実在PNGだけを該当ディレクトリへ追加。新しい末端ディレクトリを`pubspec.yaml`の`flutter.assets`へ明示登録する。`assets/avatars/`だけでは子階層は再帰登録されない。画像未提供の今は、存在しないディレクトリやPNGの登録を追加しない。
3. 既存CSVの該当statusを実物に合わせる。既存キーのPNG追加ならresolver・Firestore変更は不要。今回追加したpiedは既存のcolor文字列保存を利用し、画像採用時だけ末端ディレクトリを登録する。次の読み取り専用検査で命名・PNG構造・登録漏れを確認する。

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
