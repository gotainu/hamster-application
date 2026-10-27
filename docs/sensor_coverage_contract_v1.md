# HamCare センサー取得品質・coverage契約 v1

策定日: 2026-10-16。状態: **Phase A／Bローカル実装（検証結果は§9）。本番未反映**。対象は既存SwitchBot温湿度計のstatusポーリング。予測用契約は[データセット契約](prediction_dataset_contract_v1.md)、長期方針は[ロードマップ](predictive_analytics_roadmap.md)を参照する。

「取得品質」はHamCareが取得・受理した情報の品質を指す。機器の連続計測時間・稼働率・医学的な環境適否を意味しない。取得頻度、既存の温湿度／健康評価式、UI、通知は変更しない。保存・品質集計コードの今回差分は§9へ集約する。研究同意、Prediction Ready閾値、医学的な正常範囲も決定しない。

§1〜4は実装前の調査時点の事実、§5〜8は当初設計。今回確定した差分・制約は§9を優先する。

## 1. 記憶・現行コード・本番設定の照合【実装前の事実】

| 根拠 | 確認結果 |
|---|---|
| ユーザーの記憶 | 「15分ごと」。探索の手がかりとして扱い、設定の正とはしない |
| 旧資料 | `switchbot.md`／`firestore.md`には15分表記、`notification_v2_design.md:58`には1時間表記がある。過去の設定履歴はこれだけでは確定しない |
| 現行コード | [`switchbotPoller`](../functions/src/index.ts#L2758)、`onSchedule`、`region: asia-northeast1`、`schedule: 'every 60 minutes'`。`timeZone`・retryオプションは省略。handlerはeventを受け取らず`pollAllUsersOnce()`を呼ぶ |
| 既存リリース記録 | [2026-10-03 snapshot](release/predeployment_snapshot_2026-10-03.md)と2026-10-15保存の本番metadataはrevision `switchbotpoller-00026-kec`、source generation `1790992428798739` |
| 今回の限定した本番read | 2026-10-16 **10:22:56 JST**。project `hamster-breeding-app`／`asia-northeast1`、GEN_2、nodejs22、ACTIVE、同revision／generation、Function updateTime `2026-10-03T01:53:56.719714862Z` |
| 紐づくScheduler | `firebase-schedule-switchbotPoller-asia-northeast1`、**every 60 minutes / UTC / ENABLED**。HTTP宛先は上記Function URIと一致。`attemptDeadline=180s` |
| 配備コードとの一致範囲 | 上記generationのsource ZIPをGETし、`getMeterStatus`／`saveReading`／`pollAllUsersOnce`／`switchbotPoller`の4ブロックが手元コードと一致。全Functions／全sourceの再監査はしていない |

Schedulerの`retryCount`は応答で省略（API既定0）、`maxRetryDuration=0s`、min/max backoffは5s／3600s、maxDoublings=5。[公式RetryConfig](https://docs.cloud.google.com/scheduler/docs/reference/rest/v1/projects.locations.jobs#RetryConfig)の規則では、この組合せは失敗時の設定上の再試行なし。次の通常実行は別機会であり、配送の完全な一回性は保証しない。

照合時の`lastAttemptTime=2026-10-16T01:14:04.854028Z`、`scheduleTime=2026-10-16T02:14:04.051689Z`は、それぞれ直近開始／次回予定という管理metadata。全期間の予定枠・各deviceの試行・成功を証明しない。正時や15分境界に丸めてはいけない。

本番readは上記Function、単一Scheduler、immutable source ZIPのGETのみ。Function起動、SwitchBot API呼出し、Firestore個人データの取得／抽出、設定変更は行っていない。現在の60分設定を15分へ変更しない。

## 2. 実行・保存・集計経路【事実】

| 段階 | 実装と意味 |
|---|---|
| 定期開始 | [`index.ts:2758`](../functions/src/index.ts#L2758) `switchbotPoller → pollAllUsersOnce` |
| 対象owner | [`index.ts:2345`](../functions/src/index.ts#L2345) `switchbot_users.where(hasSwitchbot==true)`を全件読み、逐次処理 |
| 利用資格 | [`index.ts:599`](../functions/src/index.ts#L599) `assertPaidFeatureAccess`。有効な有料契約または初期trialを許可。資格確認の例外も現在は`not_paid`としてskipされ、通信障害と真の資格不足をログだけで厳密に分離できない |
| 対象device | [`index.ts:1235`](../functions/src/index.ts#L1235) `loadUserConfig`。資格情報と単一`meterDeviceId`が必要。current設定を読み、`enabled`や機器オンライン状態を別途検査する処理ではない |
| API | [`index.ts:1289`](../functions/src/index.ts#L1289) `getMeterStatus`が`GET https://api.switch-bot.com/v1.1/devices/{deviceId}/status`。HTTP非2xx／JSON失敗は例外。明示的なfetch timeout／API再試行はない |
| 値の抽出 | 同関数は`body.temperature/humidity/battery`の`typeof number`だけを採用し他はnull。APIの`statusCode==100`、有限値、deviceの測定時刻・鮮度は検証していない。HTTP200だけで成功や新しい実測を保証しない |
| Bronze | [`index.ts:1308`](../functions/src/index.ts#L1308) `saveReading`。`users/{uid}/switchbot_readings/{tsIso}`へmerge保存 |
| 環境評価 | [`index.ts:2376`](../functions/src/index.ts#L2376) raw保存後に`saveEnvironmentAssessmentLatest`。`environment_assessments/latest`、当日の`environment_assessments_history/{dateKey}`へ保存（[2226](../functions/src/index.ts#L2226)、[2285](../functions/src/index.ts#L2285)） |
| Silver／Gold | [`healthTriggers.ts:136`](../functions/src/health/healthTriggers.ts#L136)のhistory／latest trigger → 既存health pipeline → [`firestoreReaders.ts:267`](../functions/src/health/firestoreReaders.ts#L267)の評価読取 → `daily_health_features`／既存健康評価。rawから直接coverageを作る経路はない |

手動の`pollMySwitchbotNow`は認証本人・資格を確認し、同じconfig取得／API／raw保存／環境評価を使用する（[`index.ts:2535`](../functions/src/index.ts#L2535)）。registry membershipは要求しない。管理HTTP `switchbotPollNow`は管理用認証後、定期と同じ全ユーザーhelperを使用する（[2725](../functions/src/index.ts#L2725)）。**3経路ともrawの`source='status'`で、保存済み文書から経路を判別できない。** 今回はいずれも呼び出さない。

ユーザーごとの例外は`failed++`して後続へ進み、handlerは通常returnする。環境評価だけが失敗してもrawは既に存在し得るため、ログの`failed`は取得失敗件数ではなく、`saved`も数値有効件数ではない。初期registry queryの例外は全体へ伝播する（[2345–2388](../functions/src/index.ts#L2345)）。Scheduler成功から全device成功を推定しない。

`functions/src/switchbot.ts`には`pollForUser/pollOnce`、`savedAt`、15秒timeout等の別helperが残る。ただし現行`functions/src`からのimport／re-export参照は見つからず、entryは`lib/index.js`。このhelperの仕様を本番定期経路の事実へ混ぜない（[`switchbot.ts:25`](../functions/src/switchbot.ts#L25)）。

## 3. raw保存と時刻の意味【事実】

| 現在の値 | 型・単位・生成元／限界 |
|---|---|
| document ID／`ts` | `saveReading`内の`new Date().toISOString()`。UTC ISO文字列、ミリ秒精度。API応答・JSON処理後、Firestore書込み直前の**Functionsプロセス時計**。要求時刻・受領の厳密な時刻・機器測定時刻ではない |
| `createdAt` | Firestore `serverTimestamp` → Timestamp（秒／nanosecond表現）。DB受理／commitの根拠。`ts`より後になり得る。現在はmerge時にも設定されるので、衝突／上書き前の初回受理を無条件に証明しない |
| temperature／humidity／battery | numberまたはnull。順に℃／%RH／機器のbattery値。0と欠測を分け、number型だけで品質合格としない |
| `source` | string `status`。API経路の種類であり、scheduled／manualの区別ではない |
| 未保存 | deviceId、hubId、subjectId、環境参照／revision、予定枠、試行ID、API応答code、取得方針version、時刻／値の品質 |

ISO時刻IDはproviderイベントIDでもmutation receiptでもない。同一再送か別取得かを確定できず、同一owner・同じミリ秒の保存が衝突すればmerge上書きもあり得る。同値の行も別の物理測定と確定しない。

| 時刻 | 現行経路での区分 | 扱い |
|---|---|---|
| 機器の測定時刻 | **取得不能（現行status契約で確認できる項目なし）** | この経路ではunknown。他の未使用APIや機器一般の能力まで取得不能とは断定しない |
| 提供元の更新／イベント送信時刻 | **取得不能（同上）** | statusはイベント履歴ではない。HTTP日時も測定日時ではない |
| HamCare要求時刻 | **取得可能・未保存** | 認証ヘッダー`t=Date.now()`はms epochの署名準備時刻（[1103](../functions/src/index.ts#L1103)）。測定／受理の証拠へ流用しない |
| レスポンス受領時刻 | **取得可能・未保存** | `fetch`／body読了境界で採取できる。現`ts`はその後の近傍値で、同一と断定しない |
| サーバー保存時刻 | **取得・保存済み** | current writerの`createdAt`。未接続helperの`savedAt`を必須としない |
| 集計処理の実行時刻 | **一部保存済み** | latest assessmentの`evaluatedAt`（[index.ts:2280](../functions/src/index.ts#L2280)）、日次historyの`lastEvaluatedAt/updatedAt`（[2331](../functions/src/index.ts#L2331)）。Silverの`generatedAt`はsource読取前の処理開始時計、`updatedAt`はcommit時刻（[healthPipeline.ts:50](../functions/src/health/healthPipeline.ts#L50)、[132](../functions/src/health/healthPipeline.ts#L132)）。各処理の日時で、個々の取得／測定の日時ではない |

公式[SwitchBot APIのGet device status／Get Meter status](https://github.com/OpenWonderLabs/SwitchBotAPI#get-device-status)は現在状態を返す形式で、Meter例に測定／更新時刻はない。応答を取得できても、直近の独立した実測・測定間隔・値の古さは証明しない。今回、接続中の個人device／型番は取得しておらず、特定機種の別経路から時刻を補完しない。

## 4. 現状だけで分かる品質と既存集計の限界【事実＋利用規則】

完全な対象期間を**読み取り専用で取得できた場合**、厳密なparseと有限値検査により、期間所属を確定できる行の指標別有効数値行数／値の欠損・不正行数、取得記録の最初／最後、`ts`間隔、窓端を含む最大空白、`createdAt−ts`の差（両方ある行）を計算できる。これはowner配下の**保存記録の分布**であり、予定枠成功率、通信失敗率、device稼働率、実測coverage、独立実測数ではない。今回はデータ抽出・計算はしていない。

`ts`の重複／document重複は調べられても、未保存の取得IDが必要な意味的dedupはできない。取得経路・device混在を分離できない期間には、その不明理由を付ける。取得間隔の長さは通信障害の原因証明にならず、同値継続も故障／キャッシュの証明にならない。

| 既存処理 | coverageへ流用できない理由 |
|---|---|
| current環境評価 | [`fetchRecentSwitchbotReadings`](../functions/src/index.ts#L1548)は最新1000件だけ（pageなし）を読み、7日窓／当日窓へ後からfilter。`sourceDocCount`はfilter前件数。手動取得等が多ければ必要な期間が切れる |
| 既存の評価数値 | [`buildEnvironmentAssessment`](../functions/src/index.ts#L1627)は存在する値から平均／適合割合を算出。`dangerMinutes`は外れた温度1行に固定10分を加算し、spikeは隣接値差。いずれも実測暴露時間／実取得間隔ではない。式は変更しない |
| 日別backfill | [`fetchAllSwitchbotReadings`](../functions/src/index.ts#L1574)には1000件ずつのpageがあるが、backfill自体は現行main_envを使って日別mergeする（[2616](../functions/src/index.ts#L2616)）。日別raw件数とcurrent版`sourceDocCount`は同義ではなく、過去の環境／知識締切も保証しない。今回は実行しない |
| Silver | [`firestoreReaders.ts:480`](../functions/src/health/firestoreReaders.ts#L480)は当日history不在時に窓内の別日へfallbackしながら要求日を`sourceDateKey`へ設定。`windowRecordCount`は採用daily評価文書数、source countの合計は独立raw件数ではない |
| 既存quality／scoreCoverage | [`dailyHealthFeatures.ts:164`](../functions/src/health/dailyHealthFeatures.ts#L164)のdomain availability／completeness、[`healthAssessment.ts:854`](../functions/src/health/healthAssessment.ts#L854)の健康領域の重み。センサーcoverageと別物 |
| Flutter | [`SwitchbotRepo`](../lib/services/switchbot_repo.dart#L55)は720件／latest200件／stream500件等の上限。グラフはlatest2000件（[`graph_function.dart:479`](../lib/screens/graph_function.dart#L479)）から期間選択。「全期間」も取得済み範囲。readerのepoch等fallbackを実測に数えない |

新しい品質readは期間`[start,end)`（集計日はJST、保存はUTC）と取得完了状態を返す。件数上限到達だけで「窓全体を取得済み」とせず、cursorで必要境界まで読む。複数page中の追加／訂正、混在するts型、permission／通信失敗も完全性を下げる。`complete / partial / unknown`、打切り理由／cursor／根拠集合とknowledge cutoffを保持し、partialは観測数の下限として扱い比率を確定しない。既存UIのbounded cacheを完全な証拠へしない。`ts`欠落／不正のlegacy文書は期間queryでは所属を判定できないため、`timestampedEvidenceComplete`と`unknownWindowMembership`を分ける。範囲queryの結果だけで窓全体の不正行数が正確に分かったとせず、ID／epoch fallbackで割り当てない。新規attemptのserver受理indexは受理窓の根拠になっても、未知の測定窓を作らない。

## 5. A〜Eの取得品質契約【提案・未実装】

単位は**owner × device binding × 方針version × 評価窓 × knowledge cutoff**。値の集計は℃／%RHごと。対象期間・device対応・取得完全性を示せない指標は不明として返す。個体との対応は独立したqualityであり、owner／deviceの取得状況が分かっても、設置先やsubject対応が未確認なら個体別学習は保留する。既知のdevice単位A/B/Cまで不明へ置換しない。

| 指標 | 定義／不足時 |
|---|---|
| A `expectedOpportunityCount` | 方針・pause／再開・有効target／device対応の履歴から、その窓で対象であり、予定時刻がT0以下と確認できる予定枠のdistinct数。失敗したから分母から除外しない。履歴／予定枠が不明ならnull＋理由 |
| B `attemptedOpportunityCount` | Aのうち、API呼出し境界に到達した根拠がある枠数。再試行は同枠1。API実行前のprepared記録だけでは確定せず、終了不明は`request_execution_unknown`として別数／範囲で返す |
| C `validOpportunityCountByMetric` | Aのうち、HTTP／API code／構造／有限値を検証し、締切までに受理した値がある枠数。temperature／humidity／両方を別に持つ。同枠の複数成功も各1 |
| D 取得分布 | scheduled slotの分布と、実際のresponse／server受理の分布を別々に保持。最初／最後、隣接間隔、窓の開始・終了端も含む最大空白。legacyは`timelineBasis=collection_process_clock`で区別 |
| E 実測／鮮度 | 使用するAPI・実機仕様から独立に証明できる場合だけ、測定時刻・観測区間・provider更新時刻・実測age等を追加。現在はnull。`T0−createdAt`は受理情報の古さであり測定値の古さではない |

`B/A`（試行把握率）、`C/A`（有効取得機会率）、`C/B`（確認済み試行の成功率）は、必要な分母・分子・期間が完全で対応する場合だけ返す。各率で分母が確定0ならnot_applicable、分母不明はunknownであり0%にしない。A=24／B=0／C=0が確定した場合、B/A・C/Aは0%、C/Bはnot_applicable。未確定試行があれば確定比率の代わりに上下限／unknownを返す。**センサー稼働率という名前にしない。**

評価窓が進行中なら、A/B/Cの分母・分子は窓内かつ予定時刻≤T0の到来済み枠に限定し、`evaluatedThrough=T0`を付ける。未到来枠は`futureOpportunityCount`として別に保持し、取得失敗へ数えない。Dの空白計算も観測右端を`min(windowEnd,T0)`にし、未来の時間を空白へ含めない。全日品質の確定は窓終了と必要な受理待ちの完了後。正午時点の到来済み12枠が全成功でも、全日24枠を完了したとは表示しない。

### 5.1 予定枠と対象期間

- 現行60分は安定して丸1日対象なら理論上24機会／日。仮に15分方針で同条件なら96機会／日。ただし、実際の位相・遅延・対象履歴を確認しないまま、24／96を任意の過去日へ分母として当てない。
- 接続開始は資格情報登録時だけでなく、device選択・有効な利用資格等が揃ったと確認できる時点から。解除・対象除外・pause・失効／再開・device変更・schedule変更で区間を分ける。境界は`[from,to)`。初回snapshotより前はunknown。
- 予定枠キー案は`jobName + verifiedScheduledFor + policyVersion + bindingRevision`。受理時刻やtsを15／60分で丸めて作らない。対象人数の逐次処理遅延と予定時刻も分離する。
- [Firebase ScheduledEvent](https://firebase.google.com/docs/reference/functions/2nd-gen/node/firebase-functions.scheduler.scheduledevent)は`jobName/scheduleTime`を渡せるが、scheduleTimeの公式説明はunix-cronの場合を明示し、手動時は実行時刻になる。現行はgroc式`every 60 minutes`でevent未保存。**この形式で予定時刻headerと再配送時の安定性を確認するまでは、event.scheduleTimeだけで正しい予定枠が得られたとしない。** 次の通常実行のmetadata確認／Emulator fixtureで検証し、追加pollやcronへの変更で回避しない。
- `verifiedScheduledFor`が得られない場合は`slotIdentityStatus=unverified`とし、Aや枠単位の率をnullにする。必要なanchor・方針の有効時期も推測しない。Schedulerの「次回予定」1件だけから過去の全枠を作らない。
- 本人手動・管理HTTP手動は独立の取得として記録し、scheduled A/B/Cへ混ぜない。manualの試行／成功数を別に示せるが、予定枠の穴埋めには使わない。
- 通信失敗が証明されたもの、完全な記録範囲で`no_attempt_evidence`となるもの、logging未導入／部分取得による`execution_unknown`を区別する。どれも機器停止へ自動変換しない。preparedのまま終了した処理を通信失敗と断定しない。

### 5.2 日時・重複・遅延

同じattemptの保存再送は同じ結果／reading参照を返し、別のAPI要求には別attemptIdを付ける。再試行・並行取得には共通logicalSlotIdを維持し、SilverのA/B/Cでdistinct集計する。複数成功の代表値を使う場合は「締切までの最初の有効受理」等を仕様化し、都合の良い値を選ばない。別取得でも物理測定が別とは主張しない。

遅延した結果は元の検証済み予定枠に対応付けても、**受理前の予測入力・成功数には入れない**。`informationAsOf=T0`では各段階のserver受理日時≤T0が必要。時計順の不整合はqualityへ残し、負の遅延を黙って0へ丸めない。許容遅延・窓の確定待ち時間は運用仕様として後で決め、本書でReady閾値を決定しない。

## 6. 必要最小限の追加保存【提案・未実装】

以下は既存ポーリングの中で根拠を残す案であり、独立した監視・通知システムや新しいユーザー入力ではない。collection／field名は実装前に既存契約と最終照合する。

| 保存先案 | 最小情報・理由 |
|---|---|
| 既存 `switchbot_readings` | 既存ts／値／source／createdAtを維持し、`acquisitionId`参照とschema versionだけを追加。作成済み結果は書換えない新規経路とし、`createdAt`を受理根拠に再利用。routeや時刻を重複コピーしない |
| `users/{uid}/sensor_acquisition_attempts/{attemptId}` | route=`scheduled/manual_owner/manual_operator_all`、logicalSlotId（未検証ならnullと理由）、job／policy／binding参照、deviceId、startのserver受理時刻。完了時にrequest／response時刻とclockSource、APIを試みたか、構造化結果／metric別validity、完了のserver受理時刻、reading参照を一度だけ確定 |
| `users/{uid}/sensor_polling_state/{revisionId}` | 対象・device対応・方針／pause等が変わるときだけ追記。既存current設定への参照、単一device、schedule／timezone／方針version、有効／受理時期・精度、資格判定の状態／理由、個体／環境対応の出所・品質。device取得可否と個体分析への適格性を別に保持する。無限配列は作らない |

startとterminalは一方向のserver管理ライフサイクル。start項目は固定し、terminalは一度だけ追加して以後不変。API再要求は別attemptId、要求を伴わない保存結果の訂正は元attemptIdを参照する別versionで追記し、試行数を増やさない。成功時は**reading作成とterminal確定を同一transaction**にし、評価処理の失敗は別のaggregation結果として扱う。start後の停止・response後の保存失敗はunknownで残し、partial rawだけを成功として捏造しない。

API要求とDB書込みを外部サービス間で原子的にはできない。prepared文書だけなら「処理開始」は分かっても実要求までは確定しない。terminalに要求境界到達が確認できる場合にBへ採用する。再送はattemptIDと既存receiptのパターンを再利用し、同ID別内容は拒否。欠けた結果を埋めるためだけの追加API取得はしない。

**個体対応**: 現在のrawにはdevice／subject／環境IDがない。今のmeterを過去全行へ割り当てない。将来snapshotにはcurrent subjectIdやmain_envへの参照を持てても、`associationEvidence=current_config/slot_only`等と実確認を区別する。物理的な設置先・過去の対応を証明しないsnapshotをconfirmed個体へ昇格させない。対応不明期間は個体別学習で保留する。環境の数値を使う場合は[既存環境履歴](environment_history_v1.md)の知識締切・根拠revisionを再利用する。

**実装対象へ含めないもの**: 新しい計測API／Webhook／センサー、頻度変更、測定時刻の推定、UI回答、故障判定、通知、研究抽出／モデル。provider時刻は実際の採用APIで根拠が得られるまでunknown。今回追跡したstatus取得は回転数を読まない。現行活動保存は`source=wheel_manual`だけを受理する（[measurementHistory.ts:100](../functions/src/measurementHistory/measurementHistory.ts#L100)）。手入力の回転数には本契約のcoverageを適用しない（[測定契約](measurement_and_profile_history_v1.md)の記録日・期間不明を維持）。

### 6.1 量・保持・権限・削除

- prepared開始P回、確認済みAPI試行R回、terminal確定T回、validityに関わらないraw保存件数V回なら、文書はP＋V、書込み目安はP＋T＋V（既存評価writeは別）。要求前の中断でもPとwriteは生じ、Rとは一致しない。通常完了しP=R=T、全件成功V=Rと仮定した現行24回なら48文書／72 writes・日（追加metadata48 writes）。15分という仮定なら192文書／288 writes・日。後者へ頻度を変更する提案ではない。再試行・manual・未完了startは別加算し、state履歴は変更時のみ。
- attemptはまず**90日保持を運用案**とする（現行24回で2160 attempt文書／device）。index・サイズ・費用、必要なreplay期間を実装前に確認し、既存rawの保持期間は勝手に短縮しない。対応／policy履歴は根拠となるrawを利用する期間と整合させる。研究用の長期保存期間は別の同意／削除設計が必要。
- 古い根拠を消した後は`evidence_expired`を返し、集計snapshotが残っても完全な再現が可能とは言わない。既存／過去レポートを書き換えず、新しいsnapshotへ根拠とasOfを固定する。
- 通常clientは本人readのみ・write禁止、serverが所有者と参照先を検証する案。資格情報、認証headers、API raw body、個体名、memoは複製しない。ログも識別に必要なIDと安全な結果codeへ絞る。
- 正規アカウント削除の既存user subtree再帰削除へ新collectionも含め、Emulatorで確認する（[`index.ts:2486`](../functions/src/index.ts#L2486)）。解除はinactive追記と既存契約を維持。現行の任意`deleteReadings`は最大500件1batchだけで完全削除ではない（[2438](../functions/src/index.ts#L2438)）。将来、利用者がセンサーデータ削除を選んだ場合は関連metadata・派生データの扱いとpage削除を確認する。履歴を理由に正規削除を拒まない。今回は削除しない。

## 7. Medallion・予測との接続【提案】

Bronzeに上記の取得根拠を保存し、Silver `daily_health_features/{D}.environment.acquisitionQuality`等へ**別名の品質**を追加する案。既存の平均／適合率／dangerMinutes／健康スコア・domain availabilityは変更しない。

品質はwindow、timezone、informationAsOf、readCompleteness／cutoff completeness、A/B/Cとmetric別不正／欠測数、manual／retry数、D、Eのunknown理由、policy／binding／source参照、qualitySpecVersion、集計実行日時を持つ。分母・対象対応が不明ならnullを保つ。件数不足を補間や0値で埋めず、補間期間を実測coverageへ加えない。

`daily_health_features/{D}`はmergeで再計算される現在版であり、asOfを持つだけでは古い品質版を保持できない。将来T0の証拠を利用するときは、[dataset契約§5.1](prediction_dataset_contract_v1.md#51-silver再利用の2方式を区別する)の不変な予測入力snapshotへ品質値・根拠manifest／digest・asOfを含める。保存先はその実装時に確定し、現在の日文書への参照だけを不変な証拠としない。snapshot導入前は過去品質versionの保存を保証しない。

現在のInsightとは別に、将来の予測入力は受理済み根拠をT0で固定する。再計算Silverや後着結果で当時の成功率を修正したことにせず、新しいasOf／versionで生成する。Gold／ReportInsightSnapshotへの利用は将来の新規発行時だけで、既存first／v1／日次レポートは不変。保存開始は研究利用の同意を意味しない。

## 8. 設計検証例と次工程【架空の例・未実行】

例の枠時刻は説明用で、本番の位相を示さない。比率を例示する行では、対象／予定／読取り／締切が完全という仮定を置く。

| ケース | 期待する解釈・検証 |
|---|---|
| 正常 | 60分方針で確認済み24枠、24試行・24有効 → A=B=C=24、取得機会率100%。連続計測／24独立測定とは呼ばない |
| 通信失敗 | 24枠中1つが記録済み通信error、他成功 → A=24/B=24/C=23。温度0を作らない。API200＋API error／全nullも有効成功にしない |
| 接続初日 | 12:20から対象、仮に次の予定が13:14なら以降の確認済み枠だけAへ。接続前の枠は欠測扱いしない。開始履歴がなければA不明 |
| 手動混在 | scheduled24成功＋manual10成功が34行でも、scheduled Cは24。旧sourceだけでmanual分離できない場合は枠比率不明 |
| 再試行／並行 | 1枠で2試行成功、同attempt保存ACK再送も発生 → A/B/Cは各1、試行数2、同attempt結果・rawの重複なし。値同一でも故障と判定しない |
| 遅延到着 | 09:14枠の結果を10:05受理、T0=10:00 → 当時の入力／Cには入らない。後日のasOfでは元枠の遅延成功。受理時刻を09:14へ戻さない |
| 同値継続 | 24件の温湿度が同じ → 有効性／経路の根拠に応じて取得成功を数えられるが、新鮮さ・独立実測・故障は不明 |
| 過去設定不明 | 現行60分と旧15分資料だけがある → 任意の過去日へ24／96を当てず、expected_schedule_unknown。device／個体対応も推定しない |
| 件数上限 | 必要窓に1200行あるのに最新1000件のみ → partial／limit_reached。欠けた200件を未計測と数えず、page完了まで比率を確定しない |
| 実行痕跡なし／不明 | logging導入済み・完全readでreceiptなしならno_attempt_evidence。loggingなし／読取partialならexecution_unknown。どちらもdevice停止とは呼ばない |
| 部分失敗 | raw取得・保存成功後に評価失敗 → 取得Cは成功、aggregationは失敗。DB保存前に停止したpreparedだけならresponse／request確定を捏造しない |
| 対応変更・境界 | device変更／解除／pause／資格／schedule変更を跨ぐ窓を区間別に扱う。旧bindingや旧policyの値を新subjectへ混合しない。JST日境界・同時刻・混在ts型を含める |

次の実装順序案は、(1) 現行grocの予定枠metadataと方針／対象／device対応の記録契約を確定、(2) 既存共通取得helperへ最小の試行・受理根拠と新coverage用のAPI code／値validity判定を接続、(3) 完全な期間readとSilver品質を追加、(4) 上記ケース・再送／競合・保存途中失敗・本人権限／正規削除をUnit／Emulatorで検証する。新validity判定を理由に既存raw保存／環境評価への入力をrejectする変更は今回の設計に含めず、必要なら影響を別途承認する。設定上の頻度・再試行を変更せず、既存環境評価・課金／trial・Insight／reportの回帰を確認する。

前回の設計作業では、上記テスト・実装・センサー追加取得・学習・deploy・APK反映は行っていない。予定枠のgroc固有の証拠、運用保持期間、遅延確定待ち、研究同意・Ready閾値は未確定事項として残す。


## 9. 2026-10-16 Phase A／Bのローカル実装

### 9.1 実装範囲と保存契約

- [`acquisition.ts`](../functions/src/sensorQuality/acquisition.ts)へ型・有限値／API品質判定・保存共通処理を集約。indexの定期／本人手動／管理HTTPは同じ`acquireSwitchbotForUser → runSensorAcquisition`へ接続した。60分、region、timezone既定、retry、利用資格・対象選択、既存環境／健康評価式は変更しない。追加API取得、設定修復用pollは行わない。
- `sensor_acquisition_attempts/{attemptId}`に不変start（`preparedAt`、route、device、policy、binding、scheduler）と一度だけ確定する`terminal`を保存。terminalに要求処理開始／body読了後の応答時計（厳密なsocket送受信時計ではない）、HTTP／provider code、metric別validity、request実行のtrue／unknown、reading参照、server `acceptedAt`、測定／更新時刻null・鮮度unknownを保持する。prepareだけで終了した場合は結果不明。未知のpreflight例外を通信失敗にしない。
- `switchbot_readings/acq_{attemptId}`は`ts`／温湿度／battery／`source=status`／server `createdAt`を維持し、`acquisitionId`、`acquisitionSchemaVersion`、`acquisitionFingerprint`、`acquisitionVerification`を追加。IDは保存再送に安定し、`ts`は従来どおり応答後・保存直前の時計。既存ISO IDもそのまま読める。数値が無効／API code不適合でも従来保存値を品質判定だけでrejectしない。
- APIはtransaction外で1回。正常時はreading作成とterminal確定を同transactionで行う。並行の同attemptは1つだけが要求へ進む。保存ACK喪失やfallback rawの再送は既存readingを参照し、追加poll／reading作成／受理時刻の遡及はしない。完了済みterminalを古い失敗で置換しない。成功readingの再送では既存評価のみを再試行できる。
- 根拠prepare／terminal保存が利用不能でも、通常のreading保存・既存評価を試みる。fallbackは`unverified`、一部だけの証拠を確認済み成功に昇格させない。reading保存自体を確認できなければ安全なエラー。未完了replayはpendingで、pollのsaved件数へ加えない。同ID別内容は明示拒否する。

### 9.2 予定枠・対象／対応履歴の確定範囲

- policy versionは単一const `switchbot_status_60m_utc_v1`。利用中SDKが渡すjobName／scheduleTime候補を保持する。jobName＋候補時刻は再配送候補のdedup IDにのみ使用し、正規予定枠ではない。metadataなしは新しい識別子で、同イベントだとは推定しない。Cloud Schedulerの手動RunNowもjobNameを持ち得るため、route=`scheduled`はScheduler経由という意味に限定する。
- 現行grocの予定時刻header・anchorが未検証なので、通常経路の`logicalSlotId/scheduledFor`はnull／unverified。SDK手動起動の時刻fallbackも正規枠へ加えない。予定分母を24、既存recordを定期成功24と推定しない。
- [`configuration.ts`](../functions/src/sensorQuality/configuration.ts)の新export `sensorPollingConfigurationWritten`は既存`integrations/switchbot`変更を追い、`sensor_polling_state/{sourceVersionHash}`へallowlistだけを追記する。既存のdevice選択、資格情報登録、解除で変わるconfigを捕捉。source updateTimeと履歴server受理を分け、再送・逆順配送・無変更へ対応。credential／個体名はコピーしない。解除は既存のdisabled更新を記録する。物理的なdocument削除では履歴を新設せず、アカウント再帰削除後に遅延triggerが子データを復活させない。記録できない直接削除の境界はunknown。
- stateは`continuity=transition_only / eligibility=unknown`。config変更前後の24時間や、registry・有料資格の連続状態、配備間の方針有効期間を証明しない。記録できない停止／除外・導入前はunknown。これらを確定させるための新しいUI、広いbilling監視、移行は追加しない。
- attempt時にmain_petのsubjectIdとmain_envのrevisionを読むが、アプリの現在登録snapshotであり機器の物理設置・過去の個体対応ではない。根拠のあるdevice取得件数と、個体別利用の適格性は別。現在個体を旧readingへ付与しない。

### 9.3 Silver品質API・保存

- [`quality.ts`](../functions/src/sensorQuality/quality.ts)の`aggregateSensorQuality`、`readSensorQualityEvidence`、`buildAndSaveSensorQuality`を共通内部APIとする。`jstSensorQualityWindow`でJST日のUTC絶対境界を作る。UI／callable／新Schedulerは追加しない。集計は明示呼出しのみで、各pollへの全履歴scanは接続しない。
- 原始根拠3collectionをdocument ID順でpage取得し、read-only transactionの同一snapshotを使う。既定100件/page・3,000件/collection、最大500件/page・5,000件/collection。上限到達、page失敗、consistent read不成立はpartialと理由／cursorを返す。上限到達を未計測としない。
- cutoffはTimestampのnanosecondまで比較し、prepared／terminal／readingの締切後受理を除外。未完了を後日の成功で過去へ埋めない。日窓は`[start,end)`、到来済み枠は予定時刻≤T0、空白の右端は`min(end,T0)`。0件／1件でも端の空白を返し、未来を欠測へ数えない。
- 出力は予定枠（根拠がある場合のみ）、確認済み試行／指標別成功枠のdistinct数、manual、確認失敗／結果不明、readingの有限値／不正数、取得／応答／受理／検証済み枠の分布、端／最大空白、完全性、根拠manifest digest・限定ID一覧、spec version・不明理由。有限値の件数とAPI品質／保存まで確認した成功は別。
- 完全なactive／inactive・方針／anchor・logging継続の根拠がある内部入力だけを分母／率に利用する。現在のtransition-only stateはその証拠にならない。部分取得・結果不明は下限とし、分母不明はunknown、確定0の分母はnot_applicable。再試行は枠1、manualは穴埋めしない。鮮度・測定coverage・稼働率はnull／unknown。
- `users/{uid}/sensor_quality_snapshots/{resultHash}`は**Silver付随の不変品質snapshot**。期間・asOf・可視根拠・品質のhashでcreate-only／再実行冪等。後着terminalを除外した同じT0の再集計は同じ内容へ戻る。既存daily_health_features／health_assessments／readiness／report／rewardへwriteしないため、品質保存だけで既存triggerを再発火しない。
- 旧rawは維持。旧mutable版はdocument updateTime等で存在確認できる範囲だけ利用し、受理不明は別分布／理由。不正tsの期間所属は不明とし、document ID／epochで補わない。device未保存の旧rawを特定deviceへ混ぜない。旧版の訂正前状態は復元不能のまま。

### 9.4 コスト・権限・保持

正常1回の現時点の見積もりは追加8 read（binding2、prepareのattempt／raw／現在設定3、completeのattempt／raw／現在設定3）、追加metadata write2（start／terminal）。既存raw write1は維持する。全24回成功という例で追加192 read＋48 write／日／device、総保存はattempt24＋raw24。transactionの再試行・ACK確認・失敗fallbackは別加算。stateは意味あるconfig変更時のread2＋write1（現在設定と既存state、再送はreadのみ）。削除開始barrierは存在する設定のread1＋write1（既にblocked／存在しない場合write0）。

明示集計1回は3collectionの実取得文書数（既定最大合計9,000／hard cap15,000）＋現在設定／snapshot存在確認read2、初回snapshot write1／同結果再実行write0。空queryやtransaction再試行分も別。snapshotの根拠IDは各種類100件までとdigest／件数で保持し、長大配列を作らない。自動の毎時scanはない。

attemptの運用保持は90日を案として維持し、TTL／定期削除は今回設定しない。運用の詳細ログと、長期分析に必要な根拠の保持は別途決定する。一般公開／研究利用を開始する前に、同意・正規削除・撤回時の派生データ／copyの範囲まで確定する。根拠削除後は該当期間の予定枠、試行／結果の知識締切別状態、採用値との対応を完全再現できないことを明示し、snapshotの数値が残っても根拠が残存するとは扱わない。stateはrawの必要な根拠期間に整合させる。snapshotは再現根拠の残存と別に保持され得るので、期限切れ根拠を完全再現可能とは言わない。既知の保持境界より前は`evidence_expired`。研究用長期保持・同意は別途未確定。

正規削除は既存`deleteMyAccountAndData`の再帰削除前に、現在設定のserver-only `sensorCaptureBlockedForDeletion=true`をtransactionで確定する。各新writerは同じ設定をtransactionで読み、missing／blockedならfail-openせず拒否。削除前に確定した追加writeは再帰削除対象となり、応答待ちの取得や古いconfigイベント・集計保存が後から子データを復活させない。削除失敗時も勝手にblockを解除せず、正規削除を再試行する。存在しない設定をbarrierのためだけに作らない。

3collectionは本人も含めclient read／write禁止。通常readingの本人readと既存device選択権限は維持する。サーバー経由のみで管理し、token／署名／認証header／raw response／例外本文を保存しない。既存のアカウント再帰削除は追加collectionと子階層も対象。本番TTL／削除は実行しない。

### 9.5 検証・適用条件

最終検証：新規単体／統合49件、専用Emulator24件、既存関連回帰77件（合計150件、skip0）PASS。Functions TypeScript compile／noEmit PASS。Phase Aを検証後にPhase Bを実装し、削除競合ガードを含む最終一式を再実行した。実APIを呼ばないmock・専用localhost/demo Firestore Emulatorを使用。UI変更がないためFlutter／Golden／APK作業は行わない。本番・Scheduler・Functions／Rulesの反映は別承認。

本番適用候補は既存`switchbotPoller`／`pollMySwitchbotNow`／`switchbotPollNow`の取得共通処理、既存`deleteMyAccountAndData`の削除開始barrier、新`sensorPollingConfigurationWritten`、3collectionの限定deny Rules。資格情報登録／解除のcallableはコードを変更せず、config triggerが受理後の変更を捕捉する。既存環境評価・健康関連Functionsを一括再deployしない。Phase B内部APIは自動実行されず、本番で品質集計を開始する際は対象期間・読取上限・実行量を明示して別途承認する。

検証時の環境問題：通常treeの依存読込み停滞は、package／lockがbyte一致する既存検証済み依存への**隔離stageだけの**参照切替で回避。依存version変更なし。Emulatorの初回ja_JP resource欠落は英語JVM localeで解消し、失敗logを保持して同じ権限assertを再実行PASS。通常コードの回避・assert削除・直列化で通していない。証跡と変更前fileは `/private/tmp/hamcare-sensor-quality-v1-ugllqh9g/`。


## 10. 2026-10-16 本番サーバー反映（PASS／自然取得E2E未確認）

Project `hamster-breeding-app`／Function region `asia-northeast1`。削除ガードを先にsource限定更新・実配備確認 → 現行Rulesへ13行deny追加 → poll3件をsource限定更新 → 新設定triggerのみ名前指定createの順で反映。既存のIAM／env／trigger／timeout／memory／concurrency／スケール設定は退避値と一致。新event Functionはprivate、256Mi／60秒、service実効上限20、Firestore source region nam5、retryなし。

| export | revision | 状態／traffic |
|---|---|---|
| `deleteMyAccountAndData` | `deletemyaccountanddata-00005-qep` | ACTIVE／100% |
| `switchbotPoller` | `switchbotpoller-00027-quv` | ACTIVE／100% |
| `pollMySwitchbotNow` | `pollmyswitchbotnow-00042-tid` | ACTIVE／100% |
| `switchbotPollNow` | `switchbotpollnow-00050-cuz` | ACTIVE／100% |
| `sensorPollingConfigurationWritten` | `sensorpollingconfigurationwritten-00001-vip` | ACTIVE／100% |

- 本番4件のsource ZIPは同一で、そのsourceを基準に承認済み5ブロック・import／export・sensor3moduleだけを移植。変更はsrc／lib合計8artifact、削除0、63fileすべてを各配備ZIPからbyte照合。本番のpaid-only判定を維持し、通常treeのtrial変更や未反映moduleは混入させない。通常treeそのものは整理・巻戻ししない。
- 現行RulesをGET退避し、sensor3collectionのserver-only deny13行のみ統合。ローカルのAI feedback／研究基準等の別差分を除外。新ruleset `5810e42e-8bd6-420f-bf0d-7ed3851b91c2`、SHA-256 `c0edc3982ca93233790e07b7629c104c8147b35a39ec0431083f29b5ac0300c1`をreadback照合。
- 既存150件PASSを再利用し、隔離した本番由来ソースの49件・fresh統合RulesのEmulator5件を変更なしでPASS。Node22.23.1のbuild／source discovery／CLI親子9processを確認。テスト・Golden期待値変更なし。
- Schedulerのschedule／timezone／HTTP target／認証／retry等の定義は反映前後一致。毎60分・UTC・ENABLEDを維持。照合時の次回は2026-10-16 12:14 JST予定。強制実行やmanual status API取得で代用しない。
- 現行registry・device設定・本番権限から既存の確認対象を選び、Test User Bの接続を仮定しない。11:40:53 JST時点で新しい定期取得根拠は未確認。自然取得の保存／環境評価継続E2Eは未確認とし、条件付きの明示品質集計も未実施（snapshot作成0）。実測鮮度／正規予定枠／連続対象分母はunknownのコード契約を維持するが、本番集計結果を確認済みとは扱わない。
- 事前に存在したfirst／v1／日次report4文書の内容hash／updateTimeは不変、追加の非存在1文書も作成なし。飼育記録・接続設定の試験write、初期履歴・移行、report再生成、本番account削除は行わない。通常の環境評価更新は正当な処理として区別し、完全不変を要求しない。
- TTL／自動削除は設定しない。90日案・運用詳細ログと長期根拠の保持・一般公開／研究利用前の同意／削除範囲は§9.4の未確定事項を維持。通常8 read／2 writeは見積もりであり、再試行・集計分を含めない。
- 復元は新writerを動かしたまま削除ガードだけを外さない。旧poll sourceはguard未対応のため無条件traffic切替を避け、削除保護を保持する互換sourceへのforward fixを優先。取得済み根拠を削除しない。直前source／revision／設定／IAM／Rulesと手順は `/Users/gota/hamcare-deploy-staging/sensor-quality-v1-20261016-112428/audit/rollback.md`、判定は同stageの`audit/release-result.json`。

今回Flutter／APK／Samsung操作、追加研究抽出／モデル・Prediction Ready判断、通常のdirty code・Known Good変更は行わない。


## 11. 2026-10-16 期間読取り・未確定総数の限定修正（ローカル）

### 原因と今回の範囲

前回の対象はB以外の有効な既存連携1件・同device。期間は2026-10-16 JST（UTC `[2026-10-15T15:00:00Z, 2026-10-16T15:00:00Z)`）、知識締切は記録された実引数の `2026-10-16T03:20:15.594Z`（12:20:15.594 JST）を維持する。pageSize100／各collection上限3,000で、旧readerはwindow/cutoffを読取条件に使わず、文書ID順に全期間を走査し、aggregate内で初めて期間を除外していた。古いreadingで上限を消費し、確認済みの新しい`acq_`文書が読取集合に入らなかった。ポーラー／保存根拠の欠落ではない。

共通の `functions/src/sensorQuality/quality.ts` だけを修正するため、今回の本番再集計・新snapshot作成は行わない。既存部分取得snapshot `e2942b968d256fcc2e546bd72e80d3a2a2cc79ba678ea0c023eb6704bf34af86` は変更・削除しない。取得API、poller、Scheduler、Rules／Index、reading・環境評価・不変report、TTL／APKは変更しない。

### 期間選択・上限・旧形式

- `buildAndSaveSensorQuality`が既存期間／cutoffをreaderへ渡し、string型UTC時刻とFirestore Timestamp型tsを別の期間queryで取得する。UTC文字列は秒の広い境界を索引条件にし、秒のみ／小数秒桁の違いを含め、既存のnanosecondパーサで `[start,end)`・`<=cutoff` を正確に絞る。受理時刻も従来どおりcutoffで判定し、取得時刻を機器測定時刻へ変更しない。
- `orderBy(ts) → orderBy(documentId)`と`startAfter(DocumentSnapshot)`を使い、同一時刻のページ境界を保護する。単純な時刻値だけのcursorや、端の文書の除外でページを進めない方式は使わない。
- tsなし／不正型／offset表記などは期間索引queryだけで不在を証明できない。最大64文書のallowlist field inventoryを**同じreading budget内**で行い、小規模ならその全範囲を検査する。読めたoffset時刻等は実際の時刻で採否を判定し、時刻不明は理由付きunknownとする。64件以上／budget枯渇等で全populationを検査できなければ `legacy_timestamp_population_unverified`。無制限の全履歴fallbackは行わない。
- `readDiagnostics.queryScope`のstring／Timestamp query範囲のcompleteと、旧形式を含む期間全体のcompleteを分ける。期間外3,001件があっても期間内readingを先に取得できるが、未検査旧形式まで完全とは宣言しない。
- reading→attempt参照を優先して確保し、残予算で既存のbounded attempt／stateを読む。期間前のprepare・状態を単純に切り落とさない。期間内の該当attemptが参照する翌日応答readingは残budget内のpoint readで検証し、当日の新しい測定として二重計上しない。deviceはattemptとの既存の対応だけで確定し、未対応旧readingを現在deviceへ付与しない。
- 既定3,000・hard cap5,000／collection、総上限はその3倍を維持。query・inventory・参照補完の返却文書／point readを同じbudgetに合算し、重複を再読した分も消費として数える。ページ例外・実際の期間内上限はpartial。ちょうど上限でも追加の無制限確認でcompleteとせず、保守的にpartialとする。Firestore課金の空query・transaction再試行は別であり、文書数を課金read総数と同一視しない。

### 集計出力・不変snapshot

- `qualitySpecVersion=sensor_acquisition_quality_v2`、`readSpecVersion=sensor_quality_window_read_v2`。旧snapshotはv1のまま保持する。
- 実走査文書数・選択文書数・queryScope・inventory状態は戻り値／保存文書rootの `readDiagnostics` へ保存する。実行時の走査コストと、知識締切時点で採用できた根拠を区別し、走査件数を意味内容のidentityへ混ぜない。
- `readings.observed`は走査できた範囲での件数・有限値件数。期間全体の `readings.count`／`validValueCount`／`invalidValueCount` は、partial・時刻／受理／device対応の不明があればnull、`countStatus=unknown`。完全な空集合だけ0。検出した品質問題数も下限である旨を保持する。attemptの全体件数も不完全ならnull、読めた根拠は`acquisitions.observed`へ分ける。
- 時間分布／最大・開始端・終了端の空白は、全体不明ならstatus unknownとnullにし、暫定分布を`observed`へ移す。legacy分布にも同じ規則を適用。右端は従来どおり`min(periodEnd, cutoff)`で、締切より未来を欠測・空白にしない。
- 正規予定枠／連続対象履歴／機器鮮度は引き続きunknownでよい。`expected_schedule_unknown`と、今回の読取り不完全性の理由を混同しない。
- 新しいoptional `supersedesSnapshotId`は、同じowner配下に存在する元snapshotだけを参照し、新しいcreate-only snapshotへ記録する。過去文書は書き換えない。新しい仕様／根拠／完全性で別identityとなる。
- 同一性の保証は同じ仕様・入力版・取得可能範囲が揃う場合。後から文書が増え、bounded inventory等の検証可能範囲が変われば、旧cutoffの値に未来情報を混ぜなくても完全性がunknownへ変わり得る。その場合も旧snapshotは不変であり、過去の完全再現や同一hashを無条件に保証しない。coverageの不確実性を当時の観察値と扱わない。

### 検証・次回適用

Unit30/30（既存23＋新規7）、専用demo Firestore Emulator16/16（既存6＋新規10）、TypeScript noEmitはすべてPASS／skip0。検証結果はPROJECT_STATUSの今回の項目と隔離stageへ記録する。実API・本番再集計は行わず、mock／専用demo Emulatorで期間外大量履歴、同一時刻、JST／締切境界、真の期間内上限、旧形式、遅延参照、snapshot不変を確認する。

次回の承認時には、検証済みquality moduleを使う**明示集計の実行コード**を更新し、同じ対象・期間・12:20:15.594 JST cutoff／元snapshot参照で1件だけ作成する。現在このmoduleを呼ぶ公開Function／定期jobはないため、この限定修正のためのpoller再deployやRules／Index追加は不要。将来の配備sourceへ含める場合も、無関係なFunctionsの再deployは行わない。


### 11.1 工程の区切り（2026-10-16の最新確認状態）

取得品質基盤の初版実装・本番経路確認（通常取得、attempt／reading対応、環境評価継続、期間query修正、新不変snapshot作成・readback）は**完了**。集計／読取仕様は`sensor_acquisition_quality_v2`／`sensor_quality_window_read_v2`。新snapshot `0914f4f3457697f3d3f2738a03373b00816926ccf15d3b6f633f38a0116a496b`の全体品質は**PARTIAL**、observed有効readingは**1件**。UTC string／Timestampの期間query完走・3,000件上限未達と、旧形式全populationの意味の確認は別である。

`legacy_timestamp_population_unverified`、`device_membership_unknown`が残り、全体件数／reading分布・空白はnull。予定枠／分母・割合・機器測定鮮度、未確認の個体対応は根拠に応じunknown。**研究利用可能性／Prediction Readyは未判定**。1件を日代表値・十分なcoverageとみなさない。§10／§11前半の未反映・未確認は当時の経緯で、この最新状態へ読み替える。

実行証跡は`/Users/gota/hamcare-deploy-staging/sensor-quality-reaggregate-v2-20261016-132757/audit/result.json`。ここで工程を区切り、追加の再集計・API取得・deploy・過去不明の補完を行わない。学習入力のfeature別採否、窓・ラベル・同意／保持／削除の推奨と未確定事項は[データセット契約§6・§11・§15](prediction_dataset_contract_v1.md)へ集約する。
