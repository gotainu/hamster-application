# Hamster Care プロジェクト状況

最終更新: 2026-10-10

このファイルを、開発進捗・優先順位・重要判断の**正本**とします。日常の更新はこのファイルへ記録し、変更履歴はGitで管理します。従来のExcel管理表は2026-09-06時点の履歴スナップショットとして保存し、今後は原則更新しません。

## 2026-10-10 実機確認版のGit保存チェックポイント

- 個性レポートv1/v2基盤、v3視覚修正、関連するオンボーディング・trial/課金gate等、これまでの未コミットのソース・テスト・設計文書を現在地のチェックポイント対象としてまとめる。既存dirty変更を破棄・巻き戻さない。
- v3の検証結果は関連99／全Flutter307／Golden11ケース12画像／analyze指摘なし。Samsungへの署名一致・install-r・ログイン済みHome起動はPASS。詳細画面の最終デザイン評価は未確認。
- コミット候補532ファイル中テキスト412を秘密鍵・管理用tokenの値を出力せず検査し、該当なし。ローカル認証情報、APK/build出力、キャッシュ、隔離deploy auditはGit対象外。新たな本番deploy・Firestore write・機能修正なし。

## 2026-10-10 個性レポート v3 視覚修正 Samsung反映（PASS）

- 検証済みv3視覚修正7ファイルだけを前回成功ソースへoverlayし、隔離 `personality-v3-visual-device-20261010-222215` からdebug APKを1回build。Flutter/JBR/Gradle cacheとlib/main.dart・既存オプション・依存を維持、exit0（66.647秒）。新APKの生成時刻、package `com.gotainu.hamster`、新Widgetのcompiled markerを確認。
- 接続中Samsung `R3CW20C3WLF` の既存base APKをfresh取得して新APKと署名一致を確認。`adb install -r` はexit0/Success、実機APKのSHAは候補と一致。userId・初回install日時・CE/DE data identity・起動前shared_prefs metadata不変。uninstall/data clearなし。
- 起動exit0/Status: ok、前景Activityと画面を確認。既存ログイン済み「今日」Homeを表示。個性レポート詳細の実機デザイン最終評価はユーザー確認待ち（自動タップなし）。
- 保護対象51ファイルと検証済みUI SHA不変。通常working treeは本進捗記録以外変更なし。Firestore/Functions/Rules/Scheduler/AI/記録保存/Known Good/Git操作なし。
- APK: `/Users/gota/hamcare-deploy-staging/personality-v3-visual-device-20261010-222215/flutter/build/app/outputs/flutter-apk/app-debug.apk`。SHA-256: `39f6950f69845987438c86cacf5c06c24cff2e5fd359cbe8746e12cd4713aea7`。証跡: `/Users/gota/hamcare-deploy-staging/personality-v3-visual-device-20261010-222215/audit/result.json`。

## 2026-10-10 個性レポート v3 承認画像への視覚差分修正（ローカルPASS・APK未更新）

- 追加添付の承認済み画像の右側compact構成に合わせ、冒頭を補助文1行、カードを深い夜色と薄い暖色境界へ変更。主値52sp/w600、数値差を横配置し、体重の実値IQR／活動量のバー右数値を主役にした。長い凡例・最新日・研究注意は展開詳細へ集約し、統計はラベル／値を整列。
- Model／Repo／Home未読／履歴／A3保存仕様は維持。旧v1／日次／partial／研究なし／同値／範囲外／240幅・文字3倍／light-dark／Samsung360×780を確認。数値やペット写真のハードコードなし、健康・安定の断定なし。
- 関連99、Golden11ケース12画像、全Flutter307：全PASS。Flutter analyze：指摘なし。全体には既存課金と初回AI→monitoring CTAも含む。Golden後に人手相当の目視・独立レビューを行い、Golden PASSだけをデザイン承認にはしない。
- 保護対象51ファイルSHA、既読／読込のScreen lifecycle、全ThemeDataは作業前と一致。Functions／Rules／Firestore／AI／APK／端末／Known Good／Git操作なし。通常dirty treeの対象外変更を破棄・整理していない。
- 残る視覚差は既存の青色・目盛り実線・数字の太さ・狭幅の注釈折り返し。写真と大見出しを省きAndroid AppBarを維持。ローカル描画は固定fixture/Hiragino、実機最終評価とAPK反映は未実施。
- 再現仕様：docs/personality_report_v3_design.md。証跡：/private/tmp/hamcare-v3-visual-refine-20261010、スクリーンショットは同ディレクトリscreenshots/。

## 2026-10-10 個性レポート v2 本番リリース（サーバー反映済み・APK失敗、全体PARTIAL）

- 明示承認に従い隔離ソース `personality-v2-20261010-173114` から反映。現在のv1稼働sourceを基準に、個性関連だけ追加。最新distance today修正・first freezeを保持。実デプロイZIP全74productionファイルと候補SHAが一致。無関係な31 Functions・33 Cloud Runサービス、既存Scheduler1件、project IAMは不変。
- 3 Functionsは `asia-northeast1` / Node22 / ACTIVE / 100%：`personalityHealthFeaturesWritten` → `personalityhealthfeatureswritten-00002-lip`、`personalityDistanceRecordWritten` → `personalitydistancerecordwritten-00001-ven`、`personalityDailyReports` → `personalitydailyreports-00001-gep`。Firestore Eventarcの地域は既存databaseと同じnam5。初回CLIはretry policyの非対話確認でsource upload前に停止し、本番未変更を再確認して同じ3対象を確認付きで反映（exit0）。依存更新なし。
- 現行Rulesの全byteを保持した追加ルールだけ反映、実Rules SHA `2163e9377f9b77065dd1fcdd0f6943907271357d88c8dd4a1237ddbfe0ae05f7` 一致。統合Rules Emulator133件PASS。履歴とqueueを含む本番index依存queryは全200、既存indexで対応、index追加なし。研究seed/version・SQLは変更不要、実行なし。
- Scheduler `firebase-schedule-personalityDailyReports-asia-northeast1` は `0 9 * * *` / Asia/Tokyo / ENABLED、次回10/11 09:00 JST。OIDC主体・audience・private Run invoker・Scheduler service-agent roleの設定29項目PASS。認証付き実invokeは未実施。attemptDeadline180秒、Function timeout540秒のため長時間処理時は再試行し得る。queue transactionの冪等性を維持、通常100件超は翌朝以降へ持越し（消失なし）。
- Test B read-only smoke PASS：v1 `personality_v1_body_activity` 1件、100g/628.3185307179587m、v1 pointerと全report/updateTime、Bronze/readiness/オンボーディング/trial/billing/使用量は反映前と完全一致。first SHA `1c2233ef5f1db2f49bd8891688ea49bd2fc516b4b932e4fc07ebc4184667fb3f` とupdateTimeも不変。daily pointer不存在・queue0、dry-run `not_queued`。新記録がないため強制発行せず、実日次発行は未確認。
- 公式Functions deployによる設定表現差分を記録：既存個性health triggerのmaxはCF/revisionにも20が明示化、service-level20は維持。現在の実効上限は同じ20だが、将来service-levelだけ上げてもrevision20が残る。service function-id annotationも追加。他のruntime/権限/ユーザーenvは維持。旧startInitialTrialの0% revisionやRAGは不変。
- 隔離Flutter analyzeはNo issues、関連115件PASS。Samsung `R3CW20C3WLF` は接続を確認し既存APK/署名をread-only取得、v1 APK SHAと一致。v2 debug APK buildは1回・exit1（162秒）：既存Gradle cacheの `kotlin-dsl/scripts/3f26cbb0a9a420934702731ad434ba50/metadata.bin` 欠落。新APKなし、新署名比較/install/起動/実機UI確認は未実施。cache修復・削除・再build・uninstall・data clearなし、既存v1を保持。
- 通常working tree開始時568ファイルは本進捗記録以外567byte不変、削除/対象外変更なし。Known Good/Git/AI/RAG/Auth/課金/本番Bronzeを操作せず。隔離release検証はFunctions unit61/compile/discovery、Rules133、Flutter関連115/analyze PASS。全テストの過去結果を今回再実行した件数として扱わない。
- 証跡・復元資材：`/Users/gota/hamcare-deploy-staging/personality-v2-20261010-173114/audit/release-result.json` と `rollback-plan.json`。異常時はSchedulerを停止、退避したv1 managed Function sourceへ対象限定で復元、必要なら新queue bridgeを停止。追加read保護Rulesを保ち、first/v1/daily/研究version/既読markerは削除・書換しない。復元は未実施。残りはAPK環境復旧/更新後のグラフィック・未読Home・詳細既読・履歴・再起動確認と自然な日次発行。

## 2026-10-10 個性レポート v2 リリース前最終調整（ローカルPASS）

- 3項目PASS。v1の `report_pointers/personality` と日次 `personality_daily` を分離し、旧v1 ready構成別発行も継続。v2はserver確認済みdaily不存在時だけv1へfallback。既存Gold/firstは不変。実staging v1 reader/model＋現backend Emulator Goldの互換replay2件もPASS。
- Home描画write0、詳細画面表示成功後だけreport単位既読、既読後完全非表示、次report再表示、過去閲覧と最新未読の分離を確認。既読/Home/history productionは追加変更なし。
- queue103件で100件上限・overflow保持・部分失敗延期・別呼出/翌朝処理・retry/parallelを確認。古いfailure workerが新queueを延期する競合だけ最小修正。通常schedulerは1日1回なので100件超は翌朝以降の待機となる（消失なし、同日自動drainなし）。
- 検証：Functions関連108、Rules88、Flutter関連60、実旧v1 reader2件PASS。Functions全src TypeScript noEmit、Flutter全体analyze exit0/No issues。今回全Flutter再実行なし（前工程199件PASSは別結果）。
- 開始時568ファイル中12のみ更新、556byte不変、削除/対象外変更0。既存dirty変更、Known Good、統計/health/readiness/first freeze/課金/trial/AI/onboarding/依存は保護。本番deploy/Firestore書込み/APK/実機/Git操作なし。
- 適用順：現行と比較した隔離候補 → 追加Rules → 個性関連3 Functions → 分離pointer/旧版互換smoke → v2 Flutter。研究seed/SQL追加不要。index/Scheduler/IAMと100件上限の待機量は本番適用時確認。詳細・変更一覧・rollback：`docs/personality_report_v2.md`。証跡：`/private/tmp/hamcare-personality-v2-release-adjust-20261010/`。

## 2026-10-10 個性レポート v2（ローカルPhase1–3完了、本番未反映）

- JST翌朝09時、前日cutoff・新しい有効記録日のユーザーだけをqueueから処理し、immutable `daily_YYYY-MM-DD` とlatest pointerをtransaction発行。既存reader/builderを再利用し、欠けた当日Silverだけcreate、既存Silverとfirstは上書きしない。today distanceの既存early returnを保持するためqueue-only bridgeを新設。最大100件/起動、失敗はmetadataだけ保存して翌朝へ延期。
- `MetricComparisonBar`、AppTheme/StatusCard/ExpansionTileを使い、100g・628m/日、適用可能な研究中央値/IQR、個体内活動量比較を描画。健康スコア、正常範囲、推定percentileを作らない。cutoffとSilver分析日を区別し、旧v1 Goldも表示可能。
- Homeは健康hero/重要異常を優先し、最新server確認済み未読だけ表示。実描画後にreportごとのimmutable markerをcreateしてカードを消す。Drawer履歴は20件ページング・exact ID detail・旧first入口を維持。owner切替を分離し、旧firstも描画後に最初のA3日時だけ保存、既存Analyticsイベントの誤owner計測を防止。
- 検証: Functions関連137件（単体97＋Emulator40）、Firestore Rules127件、全Flutter199件PASS（exit0、416秒）。Flutter全体analyzeはNo issues、Functions全source strict TypeScript noEmit PASS。通常repo依存の読取り待ちは同version既存staging依存lookupだけで回避し、package/lock/tsconfig/compiled libは維持。Storage7ケースは今回対象外。
- 元dirty tree553ファイルは削除0・対象外変更0、対象23更新＋新規15。既存baseline/health/readiness/first freeze/trial/課金/AI/記録/onboarding sourceを保護。Known Good、Git、本番Firestore、deploy、SQL、AI API、APK build、実機は操作なし。専用loopback Firestore Emulatorのみ使用し終了済み。
- 本番前: 現行source/Rulesと比較した隔離候補、Rules、対応Flutter更新、個性関連3 Functionsの対象deploy、index/Scheduler/IAM/100件上限の運用確認が必要。既存v1 pointer readerはdaily ID非対応なので、旧版混在のまま日次pointerへ切り替えない。研究seed/version・SQL変更は不要。詳細/変更一覧/rollback: `docs/personality_report_v2.md`。

## 2026-10-09 個性レポート v1 Samsung上書き更新・起動確認

- ユーザー接続済みSamsung `R3CW20C3WLF`（SM_S911N）に限定。実機から読み取った既存APKと隔離debug APKの署名SHA-256が一致し、指定APKの検証済みSHA `38b443671ffdd807e5498561b24153c055dd7adf2efb025ca6cfe5c61cedaae7`も一致。
- `adb -s R3CW20C3WLF install -r <指定APK>` はexit0／Success。実機base APKのSHAが指定APKと一致。初回install日時とCE/DE data inode不変、アンインストール・data clearなし。
- `am start -W -n com.gotainu.hamster/com.gotainu.hamster.MainActivity` はexit0／Status: ok。前景Activityと実画面を確認し、ログインを保持した「今日」Home、新「うちの子の個性レポート」入口を確認。レポートは操作して開いておらず、内容閲覧・A3実イベントは未確認。
- ソース変更・再ビルド・クラウド設定変更・AI呼び出しはなし。既存dirty変更とKnown Goodは保護。実機証跡: `/Users/gota/hamcare-deploy-staging/personality-v1-20261008-185441/audit/device-update-20261009-120939/result.json`。

## 2026-10-08 個性レポート v1 本番反映（サーバーPASS・実機更新待ち）

- 明示承認された本番リリースを隔離ソース `personality-v1-20261008-185441` から実施。最新本番distance source generation `1791365993364287` を基準とし、既存全ファイルはindexの新export以外byte一致、新4moduleのみ追加。実デプロイZIPとの全SHA照合PASS。既存first freeze／distance today再計算／Flutterオンボーディング修正を保持。
- `personalityHealthFeaturesWritten` のみ新規deploy、`asia-northeast1`／Node22、revision `personalityhealthfeatureswritten-00001-jod` ACTIVE／100%。現在日のSilver written trigger・retry設定を確認。UID allowlist gateなし。既存31 FunctionsとRun servicesの設定・revision・trafficは不変。自然なSilver更新による新triggerの実処理は今後の確認項目。
- VetCompass 4種pointer＋immutable version計8docをcreate-only seed、read-back一致、再実行write0。現本番Rulesへreport/pointer/reference保護の3ブロックだけを追加し反映。旧Rules全byte保持、Rules Emulator103件PASS、実Rules SHA一致。旧Rules releaseと全設定を隔離auditへ退避済み。
- Test B本番smoke PASS。`personality_v1_body_activity` 1件、100g／628.3185307179587m、実profileのsyrian／成体条件を確認し研究IQR100–160g比較を適用。pointer正当、再実行write0／重複なし。既存Bronze/Silver/readiness/health/onboarding/trial/billingと使用量のhash/updateTimeは不変。
- 既存first SHA `1c2233ef5f1db2f49bd8891688ea49bd2fc516b4b932e4fc07ebc4184667fb3f`、updateTime `2026-10-07T02:52:30.807773Z` は完全不変。AI使用1／50000micros、validation使用5／250000micros、billing未作成も現在値で確認。
- bounded補完: 全30 UID、ready候補Bのみ1件、追加発行0／no-op1／失敗0。max100・batch5・ユーザー処理直列。無関係なユーザーへの書込みなし。
- A3 SQL: server viewの生成条件4箇所更新＋不足していたstrict JOIN view新規作成、実read-back/query PASS。APIの空privacyPolicy表示で監査チェックが一度停止したが、01の再PATCHはせず02のみcreate-onlyで完了。dataset/ACL/raw/normalized/previewを保持、任意dashboard未作成。生成eventのBigQuery到着1件を確認。既存test-only ingest境界は維持し、一般UIDのBigQuery集計完了とは扱わない。実閲覧／GA4受信は未確認。
- 隔離Samsung向けdebug APKは1回のbuildでPASS（exit0）、`lib/main.dart`・既存SDK/JBR17/Gradle cacheを維持、pub get/cleanなし。APK SHA `38b443671ffdd807e5498561b24153c055dd7adf2efb025ca6cfe5c61cedaae7`。署名は既存ローカルAPKと一致したが、対象Samsung `R3CW20C3WLF` はADB未接続のため実機署名比較・install-r・画面目視は未実施。アンインストールなし。
- release隔離検証: Functions95件、Rules103件、operator14件、bulk12件、SQL safety12＋resume8件PASS。前工程のFlutter128件／analyze／TypeScript noEmitは検証済み実装を保持。通常working tree553ファイルの完全一致を確認し、今回の通常repo変更は本進捗記録追加のみ。Known Good／Git／RAG／AI API／Auth／課金設定は操作なし。
- 証跡・復元資材: `/Users/gota/hamcare-deploy-staging/personality-v1-20261008-185441/audit/release-result.json`。異常時は新発行停止、退避Rules／SQL定義の復元を対象別にレビューして実施し、既存first・発行済みimmutable report・研究versionは削除しない。実機更新とHome新旧report閲覧／A3到着確認が残るため全体判定PARTIAL。

## 2026-10-08 個性レポート・リリース候補補完（本番未反映）

- 当日Silverがない既存ユーザーのbackfillを修正。既存 `fetchHealthSourceData` / `buildDailyHealthFeatures` を再利用して当日Silverだけをcreateし、確定Silverから新個性レポートを発行する。既存Silver、過去Silver、legacy first/readiness/健康評価/通知は書き換えない。dry-runは再計算previewのみで書込み0。
- テスト先行後に実装。Functions関連95件、Bronze→Silver→Gold Emulator受け入れ10件、既存Gold Emulator回帰9件、Rules58件、実Home導線のWidget E2E6件がPASS。exact B UIDも専用demoの合成データだけで100g／628.3185307179585m、両指標readyを検証し、firstのcanonical SHA/updateTime不変とretry書込み0を確認。
- TypeScript全体noEmit、Flutter全体analyzeは終了コード0。全Flutter回帰128件が成功（終了コード0、5分44秒）。
- 本番deploy、Firestore本番書込み、SQL実行、AI/RAG、実機、APK buildは未実施。既存dirty変更とKnown Goodは保護。現seed/backfill CLIはdemo＋loopbackのみで、本番投入/補完には別途承認されたAdmin運用経路が必要。
- Functions／Rules／研究seed／SQL／Flutterの適用順序とrollback: `docs/personality_report_release.md`。

## 2026-10-08 個性レポート（ローカル完了・本番未反映）

- 既存当日Silverの個体ベースラインを利用し、体重のみ／活動量のみ／両方のimmutable個性レポートと最新ポインタを実装。既存Bronze/Silver計算・健康評価・readiness・initial trial・凍結済みfirstは変更しない。
- 4種のVetCompass成人体重比較基準、誕生日／最古観測日の適用判定、metadata-only生成／閲覧イベント、Home導線／部分レポート画面、owner read／client write拒否Rulesを追加。
- 検証: Functions現行source89件、実Firestore transaction統合9件、新Rules58件＋既存Firestore Rules45件、Flutter全122件が成功。Flutter analyze／TypeScript noEmitは問題なし。Storageの既存7ケースは対象外。
- 本番deploy・Firestore本番書込み・SQL実行・AI/RAG・実機・APK buildは未実施。seed/backfillは専用local emulator＋demo projectのみ。比較基準の投入を新レポート発行より先に行う必要がある。当日Silver欠落の補完は上記リリース候補修正で対応。
- 契約、全変更ファイル、検証範囲、本番適用前事項: `docs/personality_report_v1.md`。

## 現在地

- フェーズ: 品質改善・次期設計（公開準備 Pending）
- 最優先タスク: `HLT-01` 健康スコアリングv2
- ブランチ: `main`
- ブランド基準コミット: `f972be0 feat: refresh hamster brand mark`
- 公開状況: Google Play内部テスト版 `1.0.0`（versionCode `1`）を公開済み。クローズドテスト版の作成とストア申告は完了しているが、品質改善を優先するため審査送信を保留中

## 次に着手する作業

1. 健康詳細UIで点数より状態、算出可能範囲、充足率、不足項目、個体ベースライン学習状況を優先表示する。
2. 個体ベースラインから警戒中・明らかな環境異常中の値を除外する条件を設計し、固定閾値は獣医師レビュー用に整理する。
3. 簡易健康チェックのガラス調UIをエミュレーターで再確認し、文字量・視認性・操作感を最終調整する。
4. 通知v2は現時点の実装で一旦保留し、再開時に `1.0.1`（versionCode `2`）の内部テスト実機確認を行う。
5. RAGを記事とYouTube動画の時間付き文字起こしを横断するハイブリッド検索へ刷新し、回答に関連動画カードを必ず返せるAPI契約を整備する。
6. RAG v2の検索品質を評価した後、複数回の検索・再検索を行うエージェント検索を追加する。
7. サーバー管理・期限付きのベータテスター権限を設け、有料プランを実課金なしで検証できるようにする。
8. 改善版のE2E確認後にGoogle Playの審査送信を再開し、12名以上・14日間のクローズドテストを実施する。
9. macOS/XcodeとApp Store提出環境の整備は、改善版の仕様が固まった段階で再開する。

## 検証済みの状態

### アプリとバックエンド

- Flutter静的解析: エラーなし（2026-09-15再確認）
- Flutter自動テスト: 30件成功（2026-09-15再確認）
- Functions単体テスト: 30件成功（2026-09-15再確認）
- Firestore / Storageルールテスト: 46件成功（2026-09-15再確認）
- 星の獲得Functions: TypeScriptビルド、重複防止・開始日・記録の存在確認・50個達成の単体テスト成功（2026-09-17）。4 FunctionsとFirestoreルールを本番Firebaseへ反映済み
- Android debugビルド: 成功（2026-09-15）。エミュレーターへの更新時に容量不足で`INSTALL_FAILED_INSUFFICIENT_STORAGE`が発生し、開発ツールが旧デバッグ版をアンインストールしてから新版を再インストール。エミュレーター内のアプリデータは失われた可能性があり、画面の実機確認は未完了
- 健康スコアv2実データdry-run: 60日分を読み取り専用で再計算。個体ベースライン導入後、活動量評価可能日は2日から9日、完全な参考点表示日は1日から7日へ増加。53日は入力不足のため点数非表示（2026-09-14）
- 通知v2実データdry-run: 評価履歴59件に対し、旧方式36候補から新方式14通知へ約61%削減（2026-09-13）
- 通知v2バックエンド: 健康関連6 FunctionsとFirestoreルールを `hamster-breeding-app` へ反映済み（2026-09-13）
- Android正式パッケージID: `com.gotainu.hamster`
- iOS Bundle ID: `com.gotainu.hamster`
- 初回iOS配布対象: iPhoneのみ
- Android実機でPlay Integrityトークン取得を確認済み
- iOS実機で明示的App IDによるRelease署名を確認済み
- Stripeの月額500円プラン、Checkout、Customer Portal、Webhook、Firestore契約状態反映を確認済み
- 解約予定の有効契約を、期限まで有料として扱う複数サブスクリプション優先処理を反映済み
- プライバシーポリシー、利用規約、特定商取引法表記、サポート、アカウント削除案内を公開済み
- Firebase Analyticsの収集内容に合わせたプライバシーポリシーを2026-09-07にHostingへ反映済み
- アカウントを維持したままAI相談履歴またはプロフィール画像だけを削除する手順を、アカウント削除案内ページへ追記して2026-09-12にHostingへ反映済み

### Android提出物

- Google Play個人デベロッパーアカウント: 作成済み（2026-09-06）
- Google Play本人確認: 完了（2026-09-06）
- Android実機アクセス確認: 完了済み
- 連絡先電話番号確認: 完了（2026-09-07）
- Google Playアプリ: 作成済み（2026-09-07）
- Google Play内部テスト: `1.0.0`（versionCode `1`）を1名のテスター向けに公開済み（2026-09-07）
- Google Play内部テスト配布版: 登録済み実機へPlayストアからインストールし、正常起動・基本画面表示を確認済み（2026-09-07）
- Google Playプライバシーポリシー: 公開URLを登録・保存済み（2026-09-07、審査送信前）
- Google Play公開済みAAB記録: `1.0.0`（versionCode `1`）、119,725,501 bytes、SHA-256 `3c1f8eb2933ef6391c20e1c7b1382aec2d18fe26da81c1b715745637b34fe337`（2026-09-06生成、署名・Bundletool検証成功）
- 通知v2内部テスト候補AAB: `build/app/outputs/bundle/release/app-release.aab`
- 候補生成日時: 2026-09-14 10:30:59 JST
- 候補サイズ: 119,825,645 bytes
- 候補SHA-256: `4ea6a144a0a5f5857d6d0d3d87880bc62a41f114df9f6ef6e4d24cf6d91ffbbe`
- 候補versionName / versionCode: `1.0.1` / `2`
- 候補minSdk / targetSdk: `23` / `36`
- 候補署名・ZIP整合性検証: 成功
- 候補のGoogle Playアップロード: 未実施

### iOS提出環境

- 現在のMac: macOS 14.8.9、Xcode 16.2
- 2026-04-28以降のApp Store提出要件: Xcode 26以降・iOS 26 SDK以降
- Xcode 26の実行要件: macOS Sequoia 15.6以降
- Apple Distribution署名: 有効な署名IDを未確認
- iOS配布ビルド（IPA）: 未生成

### ブランド・ストア素材

- 最終ロゴ: 黒背景、生成り色の鉛筆線による下膨れのハムスター顔、開いた下部輪郭、頬と交差する左右3本のひげ、口なし、下部に心拍波形
- iOS/Androidの全アプリアイコンへ反映済み
- App Store 1024pxアイコン、Google Play 512pxアイコン、Google Playフィーチャー画像を作成済み
- Google Play用Androidスマートフォン画像4枚（1080×1920、JPEG）を作成・検証済み
- App Store用6.9インチiPhone画像4枚（1320×2868、JPEG）を作成・検証済み
- ストア掲載文、審査メモ、プライバシー申告チェックリストを作成済み
- ストア原稿の文字数、全画像の寸法・形式・非透過、AABのSHA-256を2026-09-06に再検証済み

## タスク一覧

| ID | 状態 | 内容 | 次の確認・作業 |
|---|---|---|---|
| `SEC-04` | 完了 | Stripe契約状態の競合・再同期修正 | 運用監視 |
| `SEC-03` | 完了 | iOS App Check用の明示的署名設定 | 配布署名後に再確認 |
| `SEC-02` | 完了 | Android Play Integrity / App Check確認 | 公開後の強制適用は監視して判断 |
| `OPS-05` | 完了 | Android正式IDとアップロード署名 | 鍵とパスワードの安全なバックアップを維持 |
| `ANL-01` | 完了 | Firebase Analytics整備 | 公開後にイベントを確認 |
| `DES-01` | 進行中 | 品質改善版の要件・アーキテクチャ再設計 | `docs/product_quality_rework_plan.md`を基準に仕様と受け入れ条件を確定 |
| `NTF-01` | 開発環境反映済み・一旦保留 | 通知のイベント駆動化と頻度制御 | 実データ59件で旧36候補から新14通知へ削減を確認。健康関連6 FunctionsとFirestoreルールを反映済み。再開時に実通知・タップ・確認済み・休止・解消通知を最終確認 |
| `HLT-01` | 実装中・第3段階ローカル完了 | 健康スコアリングv2 | 飼い主観察を3段階・8項目へ構造化し、呼吸変化と明確な懸念の直接警戒、適応型の簡易健康チェックを実装。次は健康詳細UI。未デプロイ |
| `RAG-02` | 未着手 | 記事・YouTube統合RAG v2 | 動画メタデータと時間付き文字起こしを索引化し、検索・再ランキングを刷新 |
| `AI-02` | 未着手 | エージェント検索 | RAG v2評価後に、検索計画・再検索・根拠検証を追加 |
| `BETA-01` | 未着手 | テスター向け期限付き無料権限 | サーバー管理・クライアント書込不可・期限付きの権限モデルを実装 |
| `UX-01` | 進行中・記録報酬UIローカル実装 | UI/UX改善 | クイック記録のガラス調UI、保存後のアニメーション、Homeの「総合コンディション」直下の「今日の記録」と横幅を活かした大きな星3枠を実装。星をタップして条件を確認する。静的解析と関連テスト成功。次は入力後の個別洞察を追加し、各記録による星獲得をE2E確認 |
| `ONB-01` | 実装中・E2E確認待ち | 実操作型オリエンテーション | 価値を先に伝える3枚の導入スライドの後、ペット登録 → 飼育環境登録 → 飼い主プロフィール登録へ進む。未完了の次ステップを順にCoach Markで案内する。準備完了後のHomeでAI相談へ誘導し、質問欄まで操作案内する。初期スポットライトと飼い主プロフィール表示はエミュレーターで確認済み。 |
| `TRL-01` | 本番反映済み・E2E確認待ち | 主要機能の無料体験 | AI相談は3回、変化の確認は開始から5日間を無料にする。開始日時とAI利用回数はFunctionsだけが更新し、再インストールで復活しない。RAG API側の厳密なサーバー前段カウントはRAG v2時に統合する。 |
| `GAM-01` | 本番反映済み・E2E最終確認待ち | 星の累計と50個達成 | サーバー管理の獲得台帳・現在の保有数・生涯獲得数・50個解放、祝福画面、累計が存在する時だけ出るドロワー項目を実装。開始日は2026-09-17（日本時間）、既存記録は遡及付与しない。将来の失効は保有数だけを変え、生涯獲得数と解放済みコンテンツは保持できる構造。4 FunctionsとFirestoreルールを本番Firebaseへ反映。累計有効版をエミュレーターへ再導入済みで、ログイン後に今日の起動星・ドロワー導線のE2E確認が残る。特別コンテンツは未制作 |
| `REL-02` | 保留 | 日本限定・Stripe決済のままストア初回提出 | Google Playの審査送信直前で停止。改善版E2E完了後に再開 |
| `REL-03` | 未着手 | 提出候補版のE2E確認とクラッシュ監視 | `REL-02`の提出準備後 |
| `VAL-01` | 未着手 | 有料ベータで継続利用を検証 | ストア配布経路の準備後 |
| `AVT-06` | 進行中・非阻害 | 残りのアバター素材 | 初回公開後でも可 |
| `OPS-03` | 未着手・非阻害 | 依存パッケージ監査 | リリースを止めない読み取り確認から開始 |
| `OPS-04` | 未着手・非阻害 | Cloud Functionsビルドイメージ整理 | 2026-09-17のFunctions反映後、不要なビルドイメージの自動削除で警告あり。課金状況を確認後に安全に削除 |

## 確定した方針

### 初回ストア提出

- 初回公開地域は日本のみとする。
- 初回iOS公開はiPhone専用とし、iPad対応はレスポンシブUI整備後に再検討する。
- 現行のStripe Checkout / Stripe Customer Portalを維持して提出する。
- AppleのApp内課金とGoogle Play Billingは、却下前には追加実装しない。
- 決済方法を理由に却下された場合は、規約番号、審査文面、対象画面、日時を保存し、指摘内容に限定して対応を判断する。
- 2026-09-12時点で、Google Playの掲載情報、コンテンツ申告、クローズドテスト用リリース作成まで完了しているが、品質改善を優先して審査送信を保留する。
- クローズドテスト再開前に、指定テスターへ実課金なしで有料機能を提供できる期限付きベータ権限を実装する。

### 品質改善版

- 通知は定時配信ではなく、意味のある状態変化を中心にする。
- 健康スコアは断定的な診断値として扱わず、観測データに基づく参考指標、領域別評価、データ信頼度、主因を併記する。
- AI回答には関連する過去のYouTube動画を表示する。ただし、動画を回答根拠として使った場合と、補助的な関連動画として提示する場合をUI上で区別する。
- エージェント検索はRAG v2の検索品質、評価セット、費用上限、最大反復回数を確定した後に導入する。

### 情報管理

- 進捗・優先順位・判断はこのファイルを正本とする。
- 実装や検証で状態が変わったときだけ、日付と根拠を添えて更新する。
- パスワード、APIキー、署名鍵などの秘密情報は記載しない。
- 完了していない作業を完了扱いにしない。
- 最優先タスクは原則1件に絞る。
- Excel管理表は過去情報の参照用とし、二重更新しない。

## 関連資料

- [ストア掲載情報](docs/release/store_listing_ja.md)
- [審査メモ](docs/release/store_review_notes_ja.md)
- [プライバシー申告チェックリスト](docs/release/privacy_disclosure_checklist_ja.md)
- [Google Play登録手順](docs/release/google_play_submission_runbook_ja.md)
- [Google Playクローズドテスト計画](docs/release/google_play_closed_test_plan_ja.md)
- [アーキテクチャ](docs/architecture.md)
- [Firestore設計](docs/firestore.md)
- [SwitchBot連携](docs/switchbot.md)
- [RAG構成](docs/rag.md)
- [品質改善・RAG v2再設計計画](docs/product_quality_rework_plan.md)
- [通知v2設計](docs/notification_v2_design.md)
- [健康スコアリングv2設計](docs/health_scoring_v2_design.md)

## 公開ページ

- プライバシーポリシー: https://hamster-breeding-app.web.app/privacy/
- 利用規約: https://hamster-breeding-app.web.app/terms/
- 特定商取引法に基づく表記: https://hamster-breeding-app.web.app/commercial-transactions/
- サポート: https://hamster-breeding-app.web.app/support/
- アカウント削除案内: https://hamster-breeding-app.web.app/account-deletion/

## 更新記録

| 日付 | 内容 | 根拠 |
|---|---|---|
| 2026-10-04 | AI相談500エラーを修正し、限定検証用Cloud Run revisionへ反映 | 原因はFirestore transactionの`transaction.get()`が返すgeneratorをDocumentSnapshotとして扱い、`.to_dict()`を呼んでいたこと。RAGのtransaction読み取りをgenerator対応にし、空応答はfail-closedとした。Python 3.11のCloud Buildで全96テスト成功。`hamster-rag-api-00017-ceg`へ反映し100%配信、`GET /` 200・未認証および無効tokenの`POST /chat` 401を確認。実AI相談は未実施。UID Aは有料契約activeで無料体験記録なしのため、表示後消えた体験CTAは開始成功ではない。`daily_checkins/2026-10-04`の保存完了をFirestoreでread-only確認（12:41:19 JST）。修正済みFlutter sourceのDebug APKはGradleのFlutter plugin loaderで`flutterSdkPath` null例外となり未生成。エミュレーター未接続、クラッシュ有無・修正版APKの実機確認は未完了。詳細と復元情報は`docs/release/predeployment_snapshot_2026-10-04-rag-fix.md`。GitHub push、ストア配布、ユーザーデータ変更なし。 |
| 2026-10-04 | 分岐していた既存UI・機能差分を現行オンボーディングへ統合 | 旧ローカル作業コピーの追跡差分37ファイルと未追跡追加14件を機能別に照合。認証画面、飼育環境2.5Dプレビュー、日本地図、飼い主・ペットプロフィール、AI相談の音声入力・Markdown・根拠表示・評価・履歴、ランタン調フィードバック、記録報酬・コレクション、健康トレンド表示等を統合。21日無料体験・AI requestId冪等性・オンボーディング導線は現行側の実装を維持。`flutter analyze`問題なし、Flutter全42テスト成功、Android debug APK生成成功。APKの端末導入・画面目視、Google/Apple認証プロバイダーのFirebase Console設定は未確認。本番反映・push・端末データ変更なし。 |
| 2026-09-20 | 導入画面の背景と主ボタンの可読性を仕上げ | 導入スライドのアプリ側減光グラデーションを外し、生成画像の文字用スペースと星空表現をそのまま活かす構成に変更。導入画面の背景は真っ黒寄りの夜色へ変更。主操作ボタンは落ち着いた青 `#315DAF` と白文字・白アイコンに統一し、淡い黄色は星・達成など報酬表現用に分離した。`flutter analyze`問題なし、全Flutterテスト34件成功、103MBのarm64 release APK生成・エミュレーターへの上書き導入・前面起動を確認済み。 |
| 2026-09-20 | 導入画像の縦長カード最適化・登録前カード余白・スポットライト色を修正 | 横長画像による重要要素の見切れを解消するため、下部42%を文字用の暗い余白として確保した縦長グラフィック4枚へ作り替えた。登録前カードはコンテナ余白を画像へ継承しない構造へ修正し、端まで画像を表示。スポットライトは対象ごとの鮮やかな青い影を廃止し、`#080D19`・不透明度0.76のミッドナイトネイビー暗幕と自然な抜き出しへ変更。小さい画面高の導入カードもレスポンシブに調整。`flutter analyze`問題なし、対象・全Flutterテスト34件成功、108.4MBのarm64 release APK生成成功。別署名のエミュレーター旧版を削除して最新版を新規導入・起動（初回通知権限画面まで）確認済み。 |
| 2026-09-19 | オリエンテーション画像を全面背景へ改訂 | 導入3スライドと登録前カードで、生成グラフィックを部分画像ではなくカード全体の背景へ拡張。タイトル・本文が始まる少し手前からカード面へ溶ける濃いグラデーションを重ね、文字の可読性を確保した。重ねていた汎用アイコンはすべて削除。`flutter analyze`問題なし、Flutterテスト34件成功、arm64 release APKをエミュレーターへ更新し起動確認済み。 |
| 2026-09-19 | オリエンテーションと登録前カードの専用グラフィックを実装 | 生成画像4枚を追加。「小さな変化の検知」は温度・湿度・回し車・体重の傾向をつないだデータ表現、「個別見守り」はペットと飼育環境の基準化、「AI相談」は質問から確認事項を整理する表現、飼い主プロフィールは地域・天気・経験を示す表現にした。導入スライドは大きな横長ビジュアルへ、3つの登録前カードも意味に対応した画像ヘッダーへ更新。`flutter analyze`問題なし、Flutterテスト34件成功、arm64 release APK生成・エミュレーター導入・起動確認済み。 |
| 2026-09-19 | AI相談の回答本文が消える表示不具合を修正 | オリエンテーション用の入力欄識別子が回答吹き出しにも重複して付与され、画面内で同一のGlobalKeyが競合していた。識別子を実際の入力欄だけへ移し、回答本文を通常どおり描画できるよう修正。`flutter analyze`問題なし、Flutterテスト34件成功、arm64 release APK生成成功。既存エミュレーター版は署名が異なるため上書き不可であり、新規導入には旧版削除（端末内データ消去）の明示許可が必要。 |
| 2026-09-19 | 初回体験に価値スライドと負担軽減導線を追加 | 3枚の価値スライドを先行表示し、その後に「はじめる準備」へ遷移するよう変更。ペット・飼育環境の未登録時は、入力前に登録後の価値を示すプレビューを表示。`tutorial_coach_mark` で最初の登録カードを一度だけ案内する。`flutter analyze`問題なし、Flutterテスト34件成功、arm64 release APK生成成功。実機目視確認は未完了 |
| 2026-09-19 | オリエンテーションの段階案内と無料体験を実装 | 準備項目をペット・飼育環境・飼い主プロフィールへ再編。現在未完了の次項目をCoach Markで順に案内し、準備完了時はHomeからAI相談・質問欄へ誘導する。`activateFeatureTrial` と `consumeAiTrial` を `asia-northeast1` に反映し、Firestoreルールで体験状態をFunctions専用に制限。Flutter解析・全34テスト成功、arm64 release APKをエミュレーターへ導入。初期スポットライトと飼い主プロフィール表示を目視確認。全ステップ通過・AI送信・5日経過のE2Eは未完了。 |
| 2026-09-19 | 準備カウンターとAI案内位置を修正 | 登録済みドキュメントだけでなく各フォームの保存成功を完了イベントとして保存し、補助項目の欠損で 0/3 に戻らないよう変更。Homeの案内対象を見出しから下部の「相談」タブへ変更し、AI画面の質問文の事前入力を廃止して入力欄に質問例だけを案内する。Flutter解析・全34テスト成功、release APK生成済み。更新直前にエミュレーターが切断されたため、再接続後の導入とE2E確認が必要。 |
| 2026-09-18 | 実操作型オリエンテーションをローカル実装 | 新規ユーザーの導線を、ペットプロフィール、飼育環境、AI相談の3ステップへ統合。AIは実際に回答が成功した時だけ完了として保存し、初期設定に不要なSwitchBot連携・日次記録・表示設定は除外。`flutter analyze`問題なし、Flutterテスト31件成功。実機目視確認は未完了 |
| 2026-09-17 | 今日開始の星プログラムを本番Firebaseへ反映 | Firestoreルール公開と、`claimDailyOpenStar`、`acknowledgeFiftyStarMilestone`、`starDistanceRecordWritten`、`starDailyCheckinWritten`の4 Functions作成成功。Functions一覧で全4件がnodejs22／asia-northeast1で稼働中であることを確認。累計有効版のarm64 release APKをエミュレーターへ再導入済み。再インストールにより端末内ログインは消えたため、ログイン後のE2E確認が残る |
| 2026-09-17 | 星プログラムの開始日と将来の失効に備えたデータ構造を確定 | 開始日は2026-09-17（日本時間）で、過去の記録は遡及加算しない。`balance`（現在保有）と`lifetimeEarned`（生涯獲得）を分離し、50個解放は生涯獲得数で判定する。3日連続ゼロ時の将来の失効は現在保有だけを対象にできる。Functionsビルド、星の単体試験、Flutter静的解析・関連テスト成功。本番反映は明示承認待ち |
| 2026-09-16 | Homeの星3枠を横幅のある主役表示へ改訂 | 3つの星を大きくしたガラス調パネルとして配置。`flutter analyze`問題なし、日次星と50個到達画面のFlutterテスト6件成功。エミュレーターは容量不足のためdebug版を導入できず、93.4MBのarm64 release版を導入して初回ログイン画面まで確認。再インストールで端末内ログインが消えたため、Homeの改訂表示の最終目視はログイン後に行う |
| 2026-09-16 | 記録報酬UIのHome表示をエミュレーターで再確認 | debug版のHam Careを起動中のエミュレーターで確認。「総合コンディション」直下に「今日の記録」と星3枠が表示されることを確認。累計APIはビルド設定で既定OFFのため、星累計・50個達成のE2Eは未確認 |
| 2026-09-15 | 健康スコアリングv2第3段階と簡易健康チェックUIをローカル実装 | 今日の様子を3段階・8観察項目へ構造化し、呼吸変化と明確な懸念を直接警戒へ反映。入力UIは3択から必要時だけ詳細を開く構成とし、補足文を削減、正式ハムスターマークとガラス調表示へ統一。Flutter静的解析問題なし・テスト21件成功、Functionsビルド成功・単体テスト30件成功。未デプロイ、改訂UIの目視確認は未完了 |
| 2026-09-14 | 健康スコアリングv2第2段階と実データdry-runを完了 | 読み取り専用CLIで60日分を再計算。対象日を除く直前90日・最新14件、最低7件かつ14日、中央値/MAD、EWMA係数0.3の個体ベースラインを活動量と体重へ導入。活動量評価可能日は2日から9日、完全な参考点表示日は1日から7日へ増加。Functionsビルド成功・単体テスト28件成功、Flutter静的解析問題なし・テスト17件成功。未デプロイ |
| 2026-09-14 | 健康スコアリングv2第1段階をローカル実装 | NEWS2、PROMIS、Oura、EWMA、FDA透明性原則とハムスター健康情報を調査。欠測領域の100点再正規化を廃止し、`scoreCoverage`、算出可能範囲、主因最大3件、警戒優先を導入。活動量の対象日を比較平均から除外し、最低3件の過去記録を要求。Functionsビルド成功・単体テスト23件成功、Flutter静的解析問題なし・テスト15件成功。未デプロイ、実データdry-run未実施 |
| 2026-09-14 | 通知v2のGoogle Play内部テスト候補AABを生成 | `1.0.1`（versionCode `2`）へ更新し、`flutter analyze`問題なし、Flutterテスト13件成功、release AABビルド成功。AABは119,825,645 bytes、SHA-256 `4ea6a144a0a5f5857d6d0d3d87880bc62a41f114df9f6ef6e4d24cf6d91ffbbe`、署名・ZIP整合性を確認。Google Playへのアップロードは未実施 |
| 2026-09-13 | 通知v2をFirebaseへ反映 | `test_20260308@example.com` の評価履歴59件を読み取り専用で再生し、旧方式36候補から新方式14通知へ約61%削減を確認。Functionsビルド成功、Functions単体テスト20件、ルールテスト39件成功後、健康関連6 FunctionsとFirestoreルールのデプロイ成功。ストア公開・審査送信は未実施 |
| 2026-09-13 | 通知v2の頻度制御仕上げをローカルで完了 | 注意・変化通知の週2件上限、配信失敗時の枠返却、24時間期限付き解消通知、5カテゴリ設定、履歴dry-runエンジンとCLIを実装。代表履歴では同一注意4候補を1通知へ抑制。Functionsビルド成功、Functions単体テスト20件、Flutterテスト13件、ルールテスト39件成功、`flutter analyze`問題なし。実データdry-runはローカルのGoogle資格情報未設定のため未完了。未デプロイ |
| 2026-09-12 | 通知v2の第2段階をローカルで完了 | インシデントのactive/resolved/recurrence管理、詳細画面の確認済み・24時間休止、警戒通知・注意頻度・21時〜8時の夜間停止設定を実装。注意通知の初期値は「状態変化時のみ」。Functionsビルド成功、Functions単体テスト15件、Flutterテスト11件、ルールテスト37件成功、`flutter analyze`問題なし。未デプロイ |
| 2026-09-12 | 通知v2の実機検証完了を前提として次段階へ移行 | ユーザー判断による進行前提。本更新では追加の実測ログや配信証跡は記録していないため、開発環境反映後の最終確認は残す |
| 2026-09-12 | 通知v2の初期実装をローカルで完了 | 日付を含まないインシデントID、同義フラグ正規化、注意72時間・警戒12時間の再通知抑制、悪化時の即時通知、簡潔な事象別文面、Android通知置換、通知タップから状態詳細への遷移を実装。Functions TypeScriptビルド成功、Nodeテスト10件成功、Flutterテスト10件成功、`flutter analyze`問題なし。未デプロイ・Android実機未確認 |
| 2026-09-12 | 通知v2の現状分析と具体設計を開始 | 同じ湿度注意が連日、同日にも複数表示された実機通知履歴を確認。時間単位の再評価、日付を含む重複防止キー、汎用文面、通知タップ経路の不一致をコードで確認 |
| 2026-09-12 | Google Play公開準備をPendingへ変更し、品質改善版の設計を最優先化 | クローズドテスト用リリースと13件の申告変更を審査送信する直前で停止。通知、健康スコア、RAG、YouTube連携、エージェント検索、テスター権限の再設計方針を決定 |
| 2026-09-12 | アカウントを維持した一部データ削除の案内を公開 | AI相談履歴とプロフィール画像の個別削除手順を実装と照合し、Hosting反映後の公開URLで表示を確認 |
| 2026-09-07 | Google PlayへプライバシーポリシーURLを登録 | Play Consoleの保存完了表示と「公開の概要」の未送信変更を確認 |
| 2026-09-07 | Google Play内部テスト配布版を実機へインストールし、正常起動・基本画面表示を確認 | Playストアからのダウンロード、ホーム画面の配布版アイコン、アプリの「今日」画面を確認 |
| 2026-09-07 | Google Play内部テスト版 `1.0.0`（versionCode `1`）を公開 | Play Consoleで「内部テスターに公開」と公開日時を確認 |
| 2026-09-07 | Google Play ConsoleでHamster Careアプリを作成 | アプリ固有ダッシュボードとクローズドテスト要件の表示を確認 |
| 2026-09-07 | Firebase Analyticsの収集内容を追記したプライバシーポリシーを公開 | Hosting反映後の公開URLで更新日と記載内容を確認 |
| 2026-09-07 | Google Play提出用の入力手順とクローズドテスト計画を作成 | 新規個人アカウントの12名・14日要件に対応 |
| 2026-09-07 | データセーフティ申告とプライバシー表示を実装に合わせて更新 | Firebase Analytics、AI相談、FCM、App Check、外部委託先を再確認 |
| 2026-09-07 | 変更後の解析・テストを再実行 | `flutter analyze`成功、自動テスト7件成功 |
| 2026-09-07 | Google Playの連絡先電話番号確認を完了 | Play Consoleの「電話番号を確認しました」表示 |
| 2026-09-06 | Google Play本人確認を完了 | Google Play Consoleからの本人確認完了メール |
| 2026-09-06 | Google Play本人確認書類を提出し、Android実機アクセス確認を完了 | Googleお支払いプロフィールの確認完了画面、実機のPlay Consoleアプリで確認 |
| 2026-09-06 | 提出候補の解析・テスト・ストア素材を再検証 | `flutter analyze`成功、テスト7件成功、画像寸法・形式・AABハッシュ一致 |
| 2026-09-06 | iOS配布環境の未完了条件を確認 | macOS 14.8.9、Xcode 16.2、有効なコード署名IDなし、IPA未生成 |
| 2026-09-06 | Google Play個人デベロッパーアカウントを作成 | Play Consoleの作成完了画面と登録料領収書送信を確認 |
| 2026-09-06 | Androidと6.9インチiPhoneの掲載画像を各4枚作成 | ストア公式サイズ・非透過JPEGを確認 |
| 2026-09-06 | 初回iOS公開をiPhone専用に決定 | 現行iPad表示はスマートフォン幅の中央配置となるため |
| 2026-09-06 | 進捗管理の正本をExcelからMarkdownへ移行 | Gitで差分・履歴を管理する方針に変更 |
| 2026-09-06 | 最終ブランドをアプリとストア素材へ反映 | `f972be0` |
| 2026-09-06 | 最終アイコン入りAndroid AABを生成・検証 | SHA-256およびBundletool検証結果 |


## 2026-10-10 個性レポート v3 UI（ローカル実装・検証PASS、本番未反映）

- 不変Goldの詳細表示のみ変更。既存AppTheme/StatusCard/MetricComparisonBar/ExpansionTileを再利用し、装飾ヘッダーと分析カードアイコンを撤去。大きな数値、短い発見、体重の研究IQR比較、活動量の共通ゼロ起点2本バー、展開する統計・出典を実装。
- 型付きGold Model/Repositoryを維持し、表示用ViewModelへ丸め・単位・差分・日時を分離。日別中央値を全日平均とせず、MAD由来の範囲や健康/順位判断を作らない。研究比較不可では比較を省略。旧v1/日次とも生成時snapshotを表示。
- Widget21、Golden9（日本語font/viewport/theme/fixture/SHA固定、全画像目視）、関連152 PASS。Flutter analyzeはNo issues（exit0）。全Flutter273件完走：272PASS・旧装飾ヘッダー期待1件失敗。指標カード構成へ期待を修正後、該当を含む関連152を再実行して全PASS。未修正のテスト失敗なし。全体コマンドの再実行はしていない。
- 240px/文字3倍のGoldenで数字の縦分断を検出し、数値だけ必要時に幅へ収める修正と1行/カード内収容の回帰テストを追加。説明文・単位は通常の文字拡大と折返しを維持。SafeAreaで下端を保護。
- Screenのowner/read/post-frame閲覧通知と既存ThemeDataはbyte同一。保護対象176ファイル（Model/Repo/Home/onboarding/課金/Functions/Rules/依存等）のSHA不変を確認。最終全298再hashはbilling_status.dart読み取り待ちのため今回専用readerのみ停止。対象外へのwrite操作なし、削除なし、既存dirty変更・Known Good/Gitは操作なし。
- 本番deploy・Firestore/Cloud/AI・実機/APK更新は実施なし。仕様はdocs/personality_report_v3_design.md。承認モックアップ画像は利用可能資料で見つからず、依頼文の仕様を再現、pixel一致は未確認。GoldenのHiragino W3/MaterialIconsはSHA固定でfont本体は非同梱、他環境は同一byteのfont指定が必要。
- 実機反映は別承認タスクでv3候補を隔離→APK build→現端末署名比較→install-r→表示/未読/履歴/再起動確認。サーバー変更不要。証跡：/private/tmp/hamcare-personality-v3-20261010/。
