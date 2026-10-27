# 永続個体ID・観察回答履歴 v1

策定日: 2026-10-13。対象は通常の記録保存基盤のローカル実装。研究用抽出、同意の取得、予測・学習・シャドー・RCT、本番反映、APK更新は行わない。
[データセット契約](prediction_dataset_contract_v1.md)、[研究仕様](predictive_analytics_research_spec_v1.md)、[ロードマップ](predictive_analytics_roadmap.md)、[ケア契約](care_action_capture_and_continuity_v1.md)、[環境履歴](environment_history_v1.md)と接続する。適用状況は[PROJECT_STATUS](../PROJECT_STATUS.md)が正本。

## 1. 個体IDとスロット

- `petId=main_pet` は既存の単一個体スロット。新しい `subjectId` はサーバーが発行する永続個体ID。端末やScreenで個体IDを生成しない。
- `users/{uid}/pet_profiles/main_pet` の既存name／birthday／species／color／imageUrl読み取りを維持し、subjectId・revision・受理metadataを追加する。これは属性の全履歴化ではない。
- `users/{uid}/pet_subjects/{subjectId}` は所有者・スロット・登録時刻・有効状態を管理する。名前変更・プロフィール編集は同じID。明示的な入れ替えだけ別IDにする。
- IDがない旧main_petでは、明示プロフィール保存または観察保存のtransaction内で現在個体を登録する。画面表示だけでは書かず、以前の体重・活動・ケア・環境・観察へ現在IDを一括付与しない。
- 同じmutationの再送はreceiptを返す。異なる同時保存はexpected revision／subject境界で競合を返し、黙って新IDや別個体のcurrentを上書きしない。
- 現行UIに別個体への入れ替え導線はない。名前や誕生日の編集から入れ替えを推定しない。既存分析readerはUID単位のため、旧記録と混ざる条件での入れ替えは安全に拒否する。多頭UIや全データ源の個体分離は次工程であり、本機能だけで対応済みとはしない。

## 2. 保存構造とAPI

| path（users/{uid}配下） | 役割 |
|---|---|
| `pet_profiles/main_pet` | 既存プロフィールcurrent＋subjectId／revision |
| `pet_profiles/main_pet/mutations/{mutationId}` | プロフィール保存の再送receipt。属性内容の履歴ではない |
| `pet_subjects/{subjectId}` | server発行の個体登録。有効状態と登録／退役根拠 |
| `daily_checkins/{dayKey}` | 既存schemaVersion=2の日次current投影。condition／concernTags／observationLevels／memo等を維持 |
| `observation_days/{dayKey}` | 観察台帳の受理revision・対象個体・currentの根拠。current取消後も残る |
| `observation_days/{dayKey}/events/{eventId}` | 論理的な観察の識別と初回回答。新規と訂正を値の差だけで判別しない |
| `observation_days/{dayKey}/revisions/{revisionId}` | 初回回答／訂正／取消を追記。server受理順・根拠と対象revisionを保持 |
| `observation_days/{dayKey}/mutations/{mutationId}` | 内容fingerprintと確定結果。再送を新しい観察へ数えない |

authenticated callableは `saveMainPetProfile`、`saveDailyCheckin`、`readDailyCheckinHistoryAt`。既存callableと同じ本人検証・region方針を使い、入力UID／clientの受理時刻を信用しない。

- profile: expectedRevision／expectedSubjectId、mutationId、`operation=save|replace`、既存属性patch。IDはserver-only。UIからsaveする際は読み込んだ境界を渡す。
- observation: dayKey、subjectId（初回ID導入ではnull）、expectedRevision、mutationId、`operation=new_observation|correction|cancel`、targetEventId／targetRevision、timing、condition／concernTags／memo、Catalog／input UI version。
- current・台帳・新規event／revision・receipt、必要な初回個体登録を同じtransactionで確定する。途中失敗で一部だけ確定しない。mutation IDを別内容へ使い回すと拒否する。
- 異なる個体IDに紐づいた既存日次文書は上書き・混合しない。古いprofileやrecord画面のsubject／revision不一致は明確な競合にする。

## 3. 初回・訂正・新しい観察・取消

- 初回明示回答は新規eventのoriginal回答として保存する。`acceptedAt`はFirestore transactionのserver commit時刻。非同期health／reward処理の実行時刻と分ける。
- 同じ観察の訂正は元eventとrevisionを明示参照し、新しいrevisionへ追記する。original回答や以前の受理時刻を変更しない。
- 別時点の新しい観察は操作とtimingの確認で区別する。同じ値でも異なる確認済み観察は別eventになり得る。無変更・同じタイミングの再保存は新規観察を量産しない。
- currentは現在有効な観察から投影する。以前のeventの訂正・取消は後続の有効観察を巻き戻さない。最後の有効観察がなくなる場合は日次currentを取り除き、台帳・original・revision・receiptは保持する。
- 履歴導入前のdaily docでは旧currentの存在を `hadLegacyProjection` で保持する。旧値を初回回答の履歴にコピーせず、昔の初回回答時刻・当時の個体・訂正前値を捏造しない。旧記録の訂正は `origin=legacy_unknown_original`、original回答・originalRevisionはnullとし、予測ラベルへ無条件採用しない。
- 健康回答がないケアだけの保存は観察eventを作らない。自動生成normalは項目別の明示回答にならず、schema2の `overall_with_selected_tags` とCatalog規則を維持する。
- `answerProvenance.overall=explicit_submission` は明示的な健康保存で確認した全体回答を表す。個々のボタンを押したという操作証明ではない。選択タグの集合と、自動生成normalの出所は別に保持する。
- 台帳／event／revisionの `schemaVersion=1` と、`answer.schemaVersion=2`（originalAnswerも同じ）を分離する。履歴の保存形式versionを、観察回答の意味のversionと混同しない。

## 4. 観察タイミング

入力 `timing.precision=instant|date_only|unknown` を、保存時は `timing.timePrecision` に正規化する。dateKey／observedAt／confirmation／clockSource／timeZoneも保持する。受理時刻のISO表示とは別に、読取りAPIは `acceptedAtEpochNanoseconds` を文字列で返し、Firestore Timestampの精度を保持する。

| 精度 | 意味と出所 |
|---|---|
| instant／now_confirmed | ユーザーが「いまの様子」を選んだ申告時刻。端末が申告した時点であり、独立したserver観測時計ではない |
| instant／time_confirmed | 実際に観察した時刻を明示確認した場合。後入力でも元時刻と受理時刻を分ける |
| date_only／date_confirmed | 確認した対象日だけ既知。日付開始を日次表示に用いても実際の観察時刻とはしない |
| unknown／unknown | 実際のタイミングは不明。保存時刻を観察時刻へ代入しない |

初期表示された日付だけで確認済みにならない。UIの短い時期選択で確認し、訂正時に既存timingを保持する場合は元の確認出所を維持する。先の日付／未来の申告時刻・operationと異なる対象を保存側で検証する。

この版の `time_confirmed` UIは時・分の申告。ISOの秒0はその表現であり、秒単位の実測精度を意味しない。`inputUiVersion` と確認出所から分精度の申告として解釈し、T0との厳密な境界判断に必要なら可能区間を扱う。`now_confirmed` も端末時計の申告で、独立した観測証明ではない。

## 5. 知識締切付き読取り

`readDailyCheckinHistoryAt` はdayKeyとknowledgeCutoffを検証し、cutoffまでに受理されたrevisionだけを選ぶ。original回答とその時点で有効な訂正版／取消状態を区別して返す。実際の受理順は台帳revisionで保持する。

revisionの順序は当該dayKey内。異なる日をまたぐ順序は精度を保持したacceptedAtを根拠とし、同一時刻で先後が確定できなければ研究側で `first_response_order_ambiguous` と保留する。event IDの辞書順や日付順で実際の提出順を捏造しない。今回グローバルな連番・研究用の最初の回答選択は実装しない。

履歴導入前・未受理・日内不明・旧出所等を品質と理由で返す。後から受理した訂正を過去に混ぜず、現在値で復元不能な時点を補わない。日時精度と端末申告出所を品質判断へ渡す。

これは通常記録の読取りAPIであり、研究同意・ラベル適格性を判定する研究APIではない。個体IDの導入以前の記録はslot-only／不明のまま。

## 6. 最小入力と保存待ち

- 「今日の様子」「今日やったこと」の既存構成、通常save／様子だけsave、共有報酬、達成フィードバックを維持する。
- 新規観察は短い観察時期の選択だけを追加する。既存観察の編集では「入力の訂正／新しい観察」を短く区別し、取消は明示操作にする。毎回大型フォームや長いdialogを出さない。
- Repositoryがserver受理・receipt確認を担い、owner／day別のsecure pendingを保持する。応答が不明なら同じmutationで再送し、未送信・同期待ちを保存確定と表示しない。
- Modelはmutation／timing／受理結果、ViewModelは操作とDraft、Widgetは短い入力、Screenは既存配置。統計や報酬をWidgetで独自計算しない。
- 実アプリの保存は `DailyObservationStore` の明示operation付きAPIを使う。旧 `saveDailyCheckin` の曖昧なproduction呼出しは拒否し、現在docの有無や回答の変化から訂正／新観察を自動分類しない。既存テストStoreのinterfaceは維持する。

## 7. 予測ラベルへの接続と未確定事項

T0=09:00、13:05提出の例でも、**提出時刻だけでは09:00以降の観察を証明しない**。

| 記録 | 通常保存 | submitted-answerの推奨解析 | 観察が予測後だったことを要求する解析 |
|---|---|---|---|
| 13:00観察、13:05受理 | 明示時刻・申告出所で有効 | window内の最初の適格original候補 | 時刻の品質とscopeを満たす場合に候補 |
| 08:00観察、13:05後入力 | 後入力として有効 | 提出予測では候補になり得るが、後入力の採否は事前登録が必要 | 09:00前の観察なのでこのendpointには不適格 |
| 対象日だけ既知、13:05受理 | date_onlyとして有効 | scopeと不確実性を保った候補。時刻不明の採否は事前登録 | 可能区間がT0をまたぐ場合、予測後の観察と認定できない |

「予測後24h内の最初の適格な明示回答」を推奨案として維持する。基準時刻、label確定締切、訂正・取消後の選択規則は未確定。通常記録の有効性と実験labelの適格性は別で、最も心配な回答へ自動置換せず未回答をnormalへ補完しない。

今回整うのは新たに明示保存した観察の履歴と個体境界。体重・距離・属性の全revision、センサーcoverage、研究同意／撤回／削除運用、dataset生成・Prediction Ready・モデル採用は次工程／別Gate。ケア・環境の既存petIdを過去へsubjectId変換しない。

## 8. 権限・既存処理・リリース境界

- 本人だけcurrent／履歴／receipt／個体登録を読める。main_petとdaily_checkinsの直接client writeを閉じ、新APIを通す。受理時刻・revision・subjectId・originalの改ざんを禁止する。
- 既存分析／Insight／報酬triggerが見るのはdaily_checkinsのcurrentだけ。追加ledgerへ新triggerを登録せず、初回／訂正／取消の受理処理から既存計算を二重に直接呼ばない。無変更はcurrentを書かない。
- 取消によって前の有効観察がcurrentへ戻る投影は `projectionMutationOperation=cancel` と記録する。既存condition報酬処理は、このserver所有の投影を新たな達成と数えない。報酬額・共有枠・失効式は維持する。
- 既存報酬額・共有condition枠・二重付与防止・たくわえ・記録カレンダー、健康式・Silver／Gold・first／v1／日次report・課金・AI・onboardingを変更しない。
- 正規アカウント削除はusers配下を再帰削除する既存経路で、追加台帳・events／revisions／mutations・pet_subjectsも対象。不変性は通常更新の規則であり正規削除を拒まない。
- 本番適用は新callable3件と既存 `starDailyCheckinWritten` の取消投影guardを準備→現行Rulesへ限定差分を統合・Emulator確認→対応Flutterの順に別途実施する。本作業はlocalのみ。既存UI／ケア・環境の再調整、過去の一括移行・初期化、APK反映はしない。報酬guardの反映前に新しい取消投影を使わない。
- 1日台帳のtransaction読取り上限は2,000revision。上限時は明確に拒否し、currentだけ更新したり履歴を自動削除したりしない。大容量のcheckpointは別設計。

## 9. ローカル検証

テスト結果は実行完了後にPROJECT_STATUSへ記録する。対象は個体IDの不変性・並行発行・取り違え、original／訂正／新観察／取消、時期・cutoff・legacy、再送・競合・失敗、Rules・正規削除、ケアだけ保存、共有報酬、関連健康／Insight／report／UI回帰。Emulatorはlocalhostの専用demo projectだけを使用する。本番実行・研究適格性の確認と混同しない。

## 10. 2026-10-13 本番リリース記録

サーバー反映PASS、対応APK生成PASS、Samsung未接続のため全体PARTIAL。project `hamster-breeding-app` / region `asia-northeast1`。

| export | ACTIVE revision（traffic 100%） |
|---|---|
| saveMainPetProfile | savemainpetprofile-00001-ceb |
| saveDailyCheckin | savedailycheckin-00001-zuv |
| readDailyCheckinHistoryAt | readdailycheckinhistoryat-00001-cot |
| starDailyCheckinWritten | stardailycheckinwritten-00004-vov |

既存starはsource限定更新で上限20・IAM・trigger・env等を維持。新3件はregionのみの標準callable設定で、Function max未指定／Run service max20。配備ソースと隔離候補のbyte一致、匿名認証拒否、他39 Functionsの不変性を確認。現行Rulesのprofile／checkin blockだけ統合し44/44 Emulator PASS。稼働ruleset `98de9fe2-d884-4c53-97fc-394ccfc07da3`、SHA256 `340e6567c660df4ace56d9efcc9d8eda5fd80038a3a644f64c60dc5290e5706a`。

競合の元失敗はEmulatorのlock timeout後のtransaction invalid/closed。元の並行batch59/59 PASS、厳格stress初回4 PASS/2 FAILは保持する。SDKの再試行message判定との相違を切り分けた。一方のraw messageは未保存で同時刻logとの対応は推定。失敗状態と正規再送のassertでは整合した原子保存、部分保存0、同mutation再送の増殖0、別内容拒否／明示競合を確認。訂正の再送は明示競合拒否、報酬は元handlerの並行再送で回復し二重付与0を確認。直列化・例外無視・assert削除で通していない。詳細はrelease audit/concurrencyへ保存し、本番でこの環境エラーが無発生と保証しない。

Bの61既存文書・collection数・hash/createTime/updateTimeは反映前後不変。本番記録保存・IDの強制初期化・取消・履歴移行・既存report再生成は行わない。初回snapshot／subjectは正規UIの明示保存を待つ。研究適格性・ラベルの選択締切・他source履歴の未確定事項は変えない。

対応APKは隔離ソースから1回build PASS。旧release artifactとは署名一致したが、Samsung R3CW20C3WLF未接続のためfresh端末署名・install-r・起動・ログイン保持・通常save/readbackは未確認。確認導線はHome下部「＋」→「今日の様子」→観察時期、既存回答時は「入力の訂正／新しい観察」。実際の観察だけで確認する。

リリース／APK／復元情報は `/Users/gota/hamcare-deploy-staging/observation-history-v1-20261013-093740`。旧star revision/source・直前Rules・旧release参考APKを保持。端末接続後、fresh旧installed APKを退避し署名一致確認から更新する。復元時も生成済み履歴／receiptを削除せず、旧直接保存を無条件に再開しない。Known Good・既存dirty code・Scheduler／Index等は変更しない。
