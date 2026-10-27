# 飼育行動の記録と連続期間のたくわえ v1

作成／更新: 2026-10-12。ローカル実装の契約。本番反映・APK更新は別承認で行う。
同日の達成UI・入力再設計を含む。ゲーム規則v1は維持し、入力Catalog/UIのversionだけを区別する。
ローンチ前・一般ユーザー0人。旧版専用保存先・二重配信・全履歴移行は追加しない。

## 1. 開発順序と範囲

1. 飼育行動の記録基盤。
2. 既存報酬を利用した継続貯蓄・記録UX。
3. 飼育環境の変更履歴と予測用の日時整合。
4. 観察回答予測・周期推定のオフライン／シャドー検証。
5. 検証後の表示試験。

今回実装するのは1・2のみ。Phase Aの保存・履歴・権限テスト成功後にPhase Bへ進む。
これは今回承認された近接開発順序である。研究仕様の活動量T-A／観察T-Oの比較設計・未確定事項C-01/P-12や長期疾患研究を削除・実装する承認ではない。
[予測ロードマップ](predictive_analytics_roadmap.md)・[研究仕様](predictive_analytics_research_spec_v1.md)を併せて参照する。

## 2. 正本カタログと入力

`shared/care_action_catalog.json`を唯一の項目定義とし、`tool/generate_care_action_catalog.py`からTS/Dartを生成する。
`--check`で正本・生成物の一致を検証する。項目ID、表示名、順序、有効状態、入力型、旧ID／名称、任意詳細の型・単位・意味、versionを管理する。

| 安定ID | 現在の入力 | 任意詳細 | 意味 |
|---|---|---|---|
| cageCleaning | なし／汚れだけ／一部掃除／大掃除 | cleaningType: spot_removal / partial_cleaning / deep_cleaning | 汚れの除去／ケージの一部・用品／広い範囲の清掃 |
| cageCleaning | 一部掃除・大掃除の追加選択 | beddingReplacement: none / partial / almost_all | 床材交換なし／一部／ほぼ全部。省略は不明 |
| roomWalk | 1日合計時間 | durationMinutes: 整数1〜1440 | 分。0はnot_performedで表し、performedで時間省略は不明 |

正本Catalog v2は複数詳細と適用条件を定義する。旧scope=full/spot（全体／一部）はlegacy詳細として保持し、cleaningTypeと意味を統合・推定しない。旧実施記録は新しい掃除区分不明のまま読む。新しい区分とlegacy scopeを同じ回答へ混在させない。
床材交換は掃除区分から推定しない。大掃除だけの保存でも床材交換量は不明であり、一部掃除／大掃除以外では追加選択を提示しない。

内部回答は引き続きperformed / not_performed / unanswered。画面は掃除なし・散歩0分から操作可能だが、Draftは未確認状態を別に持つ。
- 項目の選択・時間入力はitem_selection。入力中にFirestore／Callableへ即保存しない。
- 主操作「この内容で記録」は短い保存内容を提示し、未確認の初期値だけをbatch_confirmationとして明示確認する。
- 補助操作「様子だけ記録」は健康回答のみ。ケアの未確認初期値を保存しない。
- 明示的に回答を解除した項目はunanswered。通常保存で再び初期値へ埋め戻さない。
- 画面を開閉しただけでは回答済みにならない。過去のperformedで詳細不明、旧scope、散歩時間不明は新しい初期値へ変換しない。
- sliderは0〜120分を1分単位で操作し、現在値を即時表示する。バーのタップと数値直接入力も利用できる。操作範囲は推奨時間ではない。120分超は直接入力で保持し、勝手に120へ丸めない。サーバーの1日上限1440分は維持する。

名称変更は同じIDを維持する。意味・単位の変更は新しい安定ID／detail keyと明示したversion計画を用い、同じ旧キーの意味を黙って変えない。廃止項目は新規入力から除き、過去値・当時のrevisionは保持する。過剰な汎用フォーム／リモート設定は追加しない。
既存健康回答とケア回答は独立して保存する。ケアだけではdaily_checkins、自動normal、健康入力Analytics、初回モニタリング達成を作らない。片側成功時も再入力を要求しない。

## 3. Bronzeの保存契約

- current: `users/{uid}/daily_care_actions/{dayKey}`。
- immutable history: 同docの`revisions/{10桁revision}`。
- idempotency receipt: 同docの`mutations/{mutationId}`。
- ownerUidは認証UID、petIdは既存の`main_pet`。クライアント指定の所有者を受け付けない。
- schemaVersion=1、catalogVersion、dayKey、status=active/cancelled、revision、previousRevision、mutationId、actions、acceptedAt、createdAt、updatedAt、inputUiVersion、inputRoute、gamePolicyVersionを保持。
- performedはoccurredDateKeyのみ、occurredAt=null、timePrecision=date_only。未回答／非実施は時刻を捏造しない。
- 実際に入力したdetailsにはdetailUnits／detailMeaningsを当時のCatalogからsnapshot保存する。durationMinutesはminutes／daily_total。旧scopeはunit=null／cleaning_scopeを維持し、新cleaningTypeとbeddingReplacementは独立した意味を保持する。省略・非実施・未回答は3mapとも空で、架空の詳細は作らない。
- 各回答にanswerProvenanceを保存し、item_selection / batch_confirmation / unansweredを区別する。入力v2では回答済み項目の出所を必須とする。旧v1の出所欠落はlegacy_unspecifiedとして読み、新たな明示回答へ昇格させない。expectedRevisionの既存回答と完全一致する未変更legacy項目だけcarryでき、新規・変更した内容の出所欠落は拒否する。
- inputUiVersion=care_actions_input_v2。v1のdurable pendingとreceipt再送は維持する。既存schemaVersion=1、revision／受理日時／immutable history／raw mutation fingerprintは維持し、一括移行は行わない。
- not_performedのnonPerformanceScope=up_to_acceptance。朝の回答をその日全体の非実施と見なさない。履歴acceptedAtを上限とする申告。

`saveDailyCareActions`（asia-northeast1）は認証・有料／有効initial trialの記録権限を確認する。取消は本人の既存記録に対して期限後も許可する。
expectedRevision一致を要求し、current・revision・receiptを同一transactionで保存する。同じmutationId／同じpayloadは同じ結果、異なるpayloadは拒否。並行保存の片側は競合として再読取を要求する。
有効な明示ケア保存は`care_reward_receipts/{dayKey}_{mutationId}`へ未処理outboxも同一transactionで作る。報酬成功後だけoutboxを除去し、immutable revision／mutation receiptは保持する。
取消はtombstone revisionを追記し、履歴を削除しない。クライアントの直接writeはcurrent／history／receiptとも禁止、本人readのみ。

## 4. オフラインと受理時刻

Callableへ送る前にowner/day別のpending payloadを既存secure storageへ保存する。再起動・通信結果不明後も同じmutationIdで再送する。
オフラインは「同期待ち」。サーバー確定前に保存・報酬・達成を確定済みと表示しない。競合／validation失敗は最新記録の再読取が必要。
acceptedAtはserverTimestamp。後入力の対象日と受理日を分離し、過去の予測時点ではacceptedAtがcutoffを超えるrevisionを使わない。
端末時計やクライアントの保存時刻は報酬・失効の根拠にしない。

## 5. 既存通貨の再利用

星とひまわりの種は同じ保存通貨のテーマ別表示。既存はopen_app／wheel／condition、各mission日固定award IDにつき1個。換算・消費APIは未実装で、新率・新通貨は作らない。
`star_awards/{day}_{kind}`と`rewards/stars`の恒久残高・累計・50個milestoneを保護する。
ケアと健康観察はcondition枠を共有し、受理JST日×conditionの共通guardで同日二重付与を防ぐ。既存の額と固定award IDを維持し、open_app／wheelの他区分上限は変更しない。
過去ケア入力は当日の継続達成対象になれるが、新しい恒久condition通貨は付与しない。体重にも新しい通貨額を設けない。
たくわえの参照内訳は受理JST日×kindにつき最大1個とし、恒久台帳の各mission日上限は維持する。同じawardは期間をまたいで二重参照しない。たくわえは既存awardの現在期間分の内訳であり、恒久残高へ再加算・合算する別財布ではない。失効で恒久残高、累計、飼育記録、過去カレンダーを削除・減算しない。

### サーバー状態と再確認API

- `users/{uid}/rewards/continuity`: 現期間・最終達成・期間内獲得内訳・累計実達成日。
- `continuity_days/{受理JST日}`: 実達成だけのカレンダー。
- `continuity_credits/{受理日}_{kind}`: 既存awardの参照と非消費内訳。恒久通貨の再発行なし。
- `continuity_award_links/{awardId}`: 同じ恒久awardを異なる受理日／期間へ重複mirrorしない参照guard。
- `continuity_periods/{periodId}`: 失効した期間summary。
- `condition_award_days/{受理日}`: 健康観察／care共通の二重付与guard。
- `refreshCareContinuity`: 未処理outboxを受理日時順・最大100件で失効判定前に認定する。残件／失敗はconfirmationPending=trueで再確認待ち、次回続行。クライアント申告日は受け付けない。outboxはserver-only。
- `retryDailyCareActionReward({dayKey, mutationId})`: 保存済みimmutable receiptから報酬だけ再確認する。保存済み入力を再送・再入力しなくてよい。

記録／起動側の共通transactionもoutboxとimmutable revisionを照合し、受理日時順に認定してから失効・新期間を判定する。未解決の受理証拠がある間は確定表示しない。保存済み記録の再入力は要求しない。

open_appの既存通貨は維持するが、閲覧だけで達成・期間開始・期限延長はしない。既に始まった期間のaward内訳としてのみ扱う。最初の有効記録時はその日既存open awardも参照できる。

## 6. 達成・猶予・失効

有効な手動体重／活動量／全体健康回答／明示ケア記録のサーバー受理JST日が達成日。対象記録日とは別。
performedとnot_performed、健康回答3状態で報酬差なし。全未回答、閲覧、open_appだけ、自動センサー、同日再送では新達成なし。訂正・取消で既に認定された記録行動を罰しない。

| 最後の達成日Dから | 状態 |
|---|---|
| D | 達成済み |
| D+1 | たくわえ維持、今日の記録へ |
| D+2 | 猶予。この日末までの通常有効記録1回で維持 |
| D+3 00:00 JST | D+1/D+2未達なら前期間のたくわえ失効 |
| 失効後の有効記録 | 新期間開始。過去実績は保持 |

厳密48時間ではなく暦日判定。月曜→水曜復帰は保持、火・水未達なら木曜0時失効。猶予日に架空の飼育記録・実記録日数を加算しない。
失効はサーバーlazy transactionで次回読取／記録時に確定し、毎分全ユーザーSchedulerは作らない。期限後の後入力・再送で過去期間を復活させない。猶予内に実際に受理済みだった不変Evidenceの処理だけが遅れた場合は、同期間の維持を復元する。これを新しい過去達成の捏造と区別する。

## 7. UIと責務

DailyStarsScreen、StatusCard、AppTheme、既存の星／種表示を再利用。Home本文から常設の記録進捗を外し、総合コンディション・健康警告・未読レポート・AI導線の既存優先順位を維持する。

達成詳細は現在のたくわえを中央の大きな数値＋小さな単位で表示し、既存の種／星を象徴として使う。80〜96spを基準に桁数・幅・文字拡大に対応する。暖かいゴールドと余白を共通Theme tokenで管理し、内部仕様の説明を主画面に並べない。
現在値・月間カレンダー・過去実績は「記録カレンダー」へ集約し、Home本文に「今日の記録」・直近7日・たくわえ・今日の星／種の常設ブロックを置かない。既存3枠の星／種は今日の補助内訳として維持し、現在のたくわえとは合算・二重表示しない。
猶予は「今日の記録でキープ」等の短文、失効は明示状態として表示する。失効条件・恒久残高との違いはヘルプで確認できる。pending中は未確定残高・失効を確定表示しない。

カレンダーは月・曜日を表示し、達成日を横につながる帯で描く。週・月の端と連続区間の両端だけを丸め、休みをまたいで接続しない。未達成日は大きな枠タイルにしない。今日の輪郭と達成の帯は別表現とし、Semanticsへ日付・達成／未達・今日を渡す。
表示する日数はactualAchievementDays等のサーバーの実達成日数のみ。猶予日をstreakや達成日へ加算しない。Widgetは残高・報酬・失効を再計算しない。

Theme=外観、Catalog=項目・detail契約、Model=証拠／revision／状態、Service=保存と達成規則、Repository=通信と再試行、ViewModel=Draft確認・文言・配置用データ、Widget=入力／表示、Screen=配置。
共通Hero／連続カレンダー／掃除選択／数値sliderを再利用し、項目IDや見た目の値をScreenへ散在させない。
短い記録後フィードバックは強制全画面遷移を増やさず、動きを減らす設定に対応する。

### 再利用する表示部品とトークン

- `CareAchievementHero` / `CareAchievementCalendar`を既存の記録カレンダーで再利用する。残高と状態はサーバーから読み、`CareContinuityViewModel`は文言・帯の配置だけを整形する。
- `CareActionInputFields`内の`CareCompactChoiceSelector` / `CareDurationSlider`と`CareActionInputViewModel`のDraft確認を共有する。Catalogが項目ID、選択肢、独立した追加詳細を所有する。
- `AppTheme`に限定的なcare tokenを追加し、既存の`StatusCard` / `CollectibleGlyph`を利用する。詳細数値96sp（幅により80spへ）、Home40sp、時間48sp。幅・文字拡大・桁数はscaleDownで収め、完全な数値をSemanticsへ渡す。既存のダーク＝星／ライト＝ひまわりの種の区別は維持する。
- 月間カレンダーは月曜始まり。週・月の折返し、期間変更、未達成日で帯を切る。今日の輪郭、休みの小線、達成帯を形でも区別する。Homeから月間詳細へ遷移し、詳細から過去月を読み取れる。

### 記録カレンダーの導線統合（2026-10-12）

- 「今日」のAppBar右上に `RecordCalendarAction` を1つ置く。既存 `calendar_today_outlined`、最小48pxの操作領域、tooltip/アクセシビリティ名「記録カレンダー」。残高・期限・バッジなし、左上メニューと中央タイトル位置を維持する。
- ドロワーの星／ひまわりの種の累計専用入口を、報酬documentの有無によらない「記録カレンダー」1項目へ統合。右上と同じ `_TabsScreenState._openRecordCalendar()` が既存 `DailyStarsScreen` を開き、戻ると元の画面／タブへ戻る。画面タイトルも「記録カレンダー」。
- 既存Hero、連続帯、月切替、実達成／休み／今日、猶予・失効・再開、ヘルプと3枠の補助内訳は維持。「これまでの実績」に実達成日数・保存済み累計獲得数・恒久保有数をまとめ、期間のたくわえへ合算しない。旧累計画面へ遷移する入口は置かない。旧画面・Model・Repository・milestone/付与処理は他の利用を保護して残す。
- 下部ナビ・「＋」記録・飼育行動入力・通常保存／訂正・保存後フィードバックと各Repositoryの受理/revision契約は不変。報酬／失効・健康評価・Insight・課金・オンボーディング・サーバー／Rules／データ移行の変更なし。
- 次工程は引き続き「飼育環境の変更履歴と予測用の日時整合」。予測器・音声・avatar・新通知は今回追加しない。

### 将来の音声入力

音声の解釈結果も同じCare Action Draftへ渡し、項目別確認・一括確認・検証・通常保存・mutation receiptの同じ経路を通す。解釈だけで回答を確定／報酬付与せず、時間不明を0分へ変換しない。音声認識・LLM・avatarは今回実装しない。

## 8. 検証と保護

Phase A: 3回答・任意詳細・日時不明・後入力・訂正／取消・Catalog変更・atomic履歴・再試行・並行競合・本人限定を検証する。
Phase B: 暦日境界・復帰／失効・非起動・遅延イベント・二重付与・通貨の非二重発行・rewardだけのretryを検証する。
Flutter: offline pending、care-only、health-only、部分成功、狭幅／文字拡大／テーマ／Semantics／低減動作、Goldenを検証する。
既存健康評価・Insight・first/v1/daily不変・既読／履歴・trial・onboarding関連を回帰確認する。本番成功をローカル成功から推測しない。


### 2026-10-12 初版ローカル検証結果（今回再設計前）

- Phase Aの保存／履歴unit 11件・実Firestore Emulator 12件・権限28件PASS後にPhase Bを実装。
- 最終Functions保存／スター／継続unit32件、B統合Emulator20件＋A保存回帰12件（32件）PASS。関連Functions回帰142件PASS。
- 新規path権限31件、既存report／Insightを含む統合Rules回帰146件PASS（スイート間の重複あり、合計件数にはしない）。
- Flutter新規60件（unit27／Widget25／Golden8）PASS。入力統合66件＋fixture最終19件（重複あり）、関連回帰275件PASS。
- TypeScript noEmit、Flutter Analyze対象23ファイル、Care／Observation Catalog正本一致PASS。新Golden8枚をローカル描画・目視、開始前の既存Golden34枚はbyte不変。
- pending101件、空確認後の並行受理、保留trigger再試行、猶予内の受理と遅延報酬、旧awardの新期間復活防止を検証。
- care-only編集で既存健康write／onboarding callbackゼロ、memo変更時の健康保存、保存成功と報酬失敗の分離、Auth切替／不完全返信の安全性を確認。
- 証跡: `/private/tmp/hamcare-care-continuity-20261012-lu61o9ww/`、`/private/tmp/hamcare-care-flutter-20261012/`。Emulatorはlocalhostのdemo projectだけを使い、所有processを停止。
- 本番deploy／Firestore本番write／実機／APK／Git変更操作／Known Goodへのアクセスや変更はなし。実機UX、入力時間の目標5秒、本番運用は未確認。

### 2026-10-12 達成UI・入力再設計の最終ローカル検証

- 入力／Repository／旧健康保存49件PASS（新Draft17件を含む）。達成／カレンダーWidget36件PASS。関連回帰の結合実行334件PASS。これらは重複するため件数を合算しない。
- Goldenは入力4件＋達成10件の通常比較PASS。393px、280px・文字2倍、単日／複数週／週・月境界／休み／猶予復帰／失効後再開を決定的fixtureで描画・目視した。フィクスチャを本番へ投入していない。
- Functions保存19件＋報酬／継続回帰24件（新契約3件を含む）PASS。保存Emulator17件PASS。Emulatorは127.0.0.1:19956のdemo projectのみで、所有processを停止した。
- TypeScript noEmit、変更範囲のFlutter Analyze、Care Catalog生成物一致PASS。全掃除区分、床材独立、0分／正数／時間不明／120分超、初期値／項目別／一括確認／健康のみ、訂正／再読込／旧pending receipt再送／同日二重付与を確認した。
- 開始時の435ファイルと比較し、既存変更は今回の入力・達成UI・Catalog・保存検証・関連テスト・設計文書のみ。Home配置、報酬／continuityのサーバー計算、健康／Insight／レポート／課金／onboarding、Rules、依存設定は不変。既存の対象外Golden34枚もbyte不変。
- 証跡／描画画像: `/private/tmp/hamcare-achievement-care-redesign-20261012-gtqx6xio/`。実機の見た目・入力所要時間は未確認。本番deploy／本番write／APK／実機／Git操作／Known Goodへのアクセス・変更なし。

## 9. 将来接続と未実装

ケアEvidenceは将来Silverに回答・欠測・詳細・対象日・受理日・revision・入力UI／game policy／経路を渡せる契約。今回は予測用Silverやモデルを作らない。
ゲーム達成率は健康ラベルでも世話の真実性でもない。掃除／散歩は体調への対応として行われる可能性があり、因果を断定しない。
環境履歴は[飼育環境変更履歴 v1](environment_history_v1.md)の別契約でローカル実装・検証済み（本番未反映）。ケアの床材交換と設定の床材深さは区別し、自動更新しない。offline／shadow、将来RCTはロードマップ上の後続作業。
将来avatarの少量消費はゲーム上の演出とし、実ペットの食事・健康と連動させない。未記録による病気／苦痛／死亡演出なし。素材／給餌／ゲームエンジンは今回未実装。
付与・現在期間内訳・失効は分離する。将来消費と失効の併用は再設計し、二重ペナルティを無条件追加しない。

## 10. 本番適用前

今回の再設計を反映する場合、最小差分はまずsaveDailyCareActionsのCatalog／detail／provenance検証を更新し、その後Flutterを更新する。Rules、報酬・continuity計算、Schedulerの追加更新は不要。

今回の再設計は本番反映していない。Catalog生成物・care保存の新detail/provenance検証とFlutter更新が必要。すでに初版反映済みの環境があっても、今回のための自動rollback／過去データ移行／初期化は行わない。継続・報酬・Rulesの既存契約は変更しない。以下は初版全体の反映対象であり、今回すべてを再デプロイする指示ではない。

最新の本番source／Rulesを別途照合し、必要な新callable／triggerと変更star Functionsのみ隔離して反映する。
現行Rulesへ本人read／serverwriteの新pathだけ統合しEmulator検証する。Catalogの生成物チェック、最新版Flutterの関連検証を行う。
対象の新規FunctionsはsaveDailyCareActions／retryDailyCareActionReward／refreshCareContinuity／continuityWeightRecordWritten、変更FunctionsはclaimDailyOpenStar／starDistanceRecordWritten／starDailyCheckinWritten。既存health／report／AI／課金Functionsは対象外。遅延・残件時の達成取りこぼしを防ぐため、手動recordに接続するcontinuityWeightRecordWritten／starDistanceRecordWritten／starDailyCheckinWrittenはretry=trueを要求する。本番反映時にこの必要な実行設定を明示確認し、IAM・環境変数・他の設定は維持する。
一括移行・ledger初期化・恒久残高変更・新Scheduler・予測APIは不要。本番スモークと実機UX確認は未実施。5秒入力は目標であり、実測達成やSpeak参照画像との一致は確認していない。
