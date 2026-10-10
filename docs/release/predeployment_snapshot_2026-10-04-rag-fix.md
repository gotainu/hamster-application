# 2026-10-04 Cloud Run RAG修正の反映前記録

記録時刻: 2026-10-04 13:20 JST。対象はローンチ前の限定接続検証。
一般公開・GitHub push・ストア配布・Functions／Firestoreルールの変更は行わない。

## 反映対象と復元点

- Firebase / Google Cloud project: `hamster-breeding-app` (`797691641198`)
- Cloud Run service: `hamster-rag-api`、`asia-northeast1`
- URL: `https://hamster-rag-api-laroc33gtq-an.a.run.app`
- 反映前はrevision `hamster-rag-api-00016-zb6`へ100%配信。
- 反映前image: `asia-northeast1-docker.pkg.dev/hamster-breeding-app/cloud-run-source-deploy/hamster-rag-api@sha256:475fb6eca61326558f71a7981893db425e3b4e1353baa7884d0c81e0d33630eb`
- 実行サービスアカウント: `hamster-rag-runner@hamster-breeding-app.iam.gserviceaccount.com`
- CPU `1000m`、memory `512Mi`、timeout `300s`、container concurrency `80`。
- revision 00016はCloud Run上に保持されており、image digestも復元点として記録済み。

## 反映前の権限・上限設定

- `AI_CHAT_ENABLED=1`
- `AI_ALLOWED_UIDS`は検証用2アカウント（値はここへ複製しない）。
- 検証全体の上限: 4相談、予約総額`200000` micros ($0.20)、1相談`50000` micros ($0.05)。
- `AI_RESERVATION_COST_MICROS`は未設定。実際には`AI_VALIDATION_COST_PER_REQUEST_MICROS=50000`を検証用予約額として使う。
- `APP_CHECK_ENFORCE=false`を維持。
- 音声文字起こしは停止状態。2026-10-04の`/transcribe` 503はこの制御によるもので、生成AI呼び出しではない。
- APIキー値、テストUID、ユーザートークンは記録しない。

## ローカル修正と復元

- 変更するRAGファイルは`/Users/gota/docker/hamster_rag_server/app/entitlement.py`と、同リポジトリの`tests/test_entitlement.py`だけ。
- 現行RAG作業コピーにはこの作業以前から未コミット差分と未追跡ファイルがある。それらを保持し、clean/reset/checkoutは行わない。
- 修正後ファイルSHA-256: `app/entitlement.py` = `5f7ff25871394bbf188dd26dd007b898260111326ab767bfeaef97069fedcc5e`; `tests/test_entitlement.py` = `4ac74d4eddce9023b9bb1474d3ef3381508d39a8b2521087953a9767bb1d5e81`。
- `cloudbuild.yaml`はCloud Run Job `hamster-rag-corpus-pipeline`と`hamster-rag-release-dispatcher`も更新するため、この修正の反映には使わない。RAG imageだけをbuildし、`hamster-rag-api`だけを段階反映する。
- 反映後に問題があれば、AI利用を再開する前にトラフィックをrevision 00016へ戻すか、`AI_CHAT_ENABLED=0`で停止する。revision 00016は認証・予約前に失敗する既知不具合を含むため、恒久復旧先として扱わない。

## 反映前テスト

- `python3 -m unittest discover -s tests -p 'test_entitlement*.py'`: 12件成功。
- フル96件: ローカルの既存Python環境でPinecone SDKの`__init__.py`が欠けていたため最初はimport失敗。`/private/tmp`の隔離ディレクトリに同じ`pinecone==6.0.2`だけを再配置し、`PYTHONPATH`を限定して再実行、96件成功。リポジトリやユーザー共通Python環境は変更していない。
- 実AI呼び出し、ユーザーデータ変更、クラウド設定変更はしていない。

## 反映後の記録

- Cloud Build `d7316836-caa5-4dc3-911a-03b59c783794`でRAG API imageのみをbuild。image digest: `sha256:7e6a0d3ab1fdedbb33e205f6325b45c2c4c600dc7f2a022e2fbbbc4e93c966e8`。
- Cloud Build `1553810b-3db5-4e59-ae04-c8942c7d6abc`でPython 3.11の依存関係を使い、全96テスト成功。Cloud Run Job／dispatcherは変更していない。
- 2026-10-04 13:32 JST、imageをrevision `hamster-rag-api-00017-ceg`へデプロイ。起動確認後に旧revision `00016`から100%を切り替え、検証用タグは削除。反映後もCPU、memory、timeout、concurrency、service account、AI allowlist、4相談/$0.20総予約上限、$0.05/相談、音声文字起こし停止を維持。
- 新revisionのタグURLと本番URLの両方で`GET /`が200、認証なし・無効Firebase ID tokenの`POST /chat`はともに401。認証拒否はモデル生成・予約前であることを確認。認証済みの実AI相談はこの反映検証では送信していない。
- 実機からのAI再試行はまだ未確認。テストUID Aのread-only確認では有料契約active、`initial_trial_v2`と開始イベントなし、AI usage/API-call記録なし。したがってAの一時表示された体験CTAは開始成功を意味せず、Aは無料体験開始の確認対象にならない。
- APK再ビルドは未完了。Gradle 8.12の隔離キャッシュで実行したAndroid settings構成がFlutter plugin loader内の`flutterSdkPath` null例外で失敗した。既存APKの上書き導入、アンインストール、アプリデータ消去はいずれも行っていない。
- emulatorは最終確認時に`adb devices`上で未接続。ネイティブクラッシュの証跡は取得できていないため、クラッシュの有無は未確認。
- 失敗した4回の`/chat`は修正前revisionでFirestore transaction取得時に失敗し、利用枠・API使用量記録とモデル呼び出しより前に終了したことをCloud Runログとread-only Firestore状態から確認。`/transcribe`の503は音声文字起こし無効設定によるもので、AI呼び出しではない。
- AのFirestore `users/{uid}/daily_checkins/2026-10-04`は存在し、`updateTime`は2026-10-04 12:41:19 JST。今日の様子1件はサーバー保存まで成功した。体験が存在しないため、現時点でtrial_idへの結合はできない。Analytics／BigQueryへの受信はこの検証では確認していない。
- GitHub push、ストア公開、本番Firestoreデータ変更、追加のFunctions／Firestoreルール変更は行っていない。
