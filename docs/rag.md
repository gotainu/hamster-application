# RAG Architecture

## Overview

2026-10-25に、既存仕様・直接実装・保存済み評価／配備証拠だけを照合した。コード・本番設定・索引・テストは変更／再実行していない。進捗の正本は[PROJECT_STATUS.md](../PROJECT_STATUS.md)の`RAG-02`／`AI-02`／`BETA-01`、要求差分とユーザー判断は[品質改善計画の各10/25照合欄](product_quality_rework_plan.md)に集約する。

実装は3層（オフライン構築、検索・生成API、Flutter）で、旧Dense v1と、後発のHierarchical v1＋BM25補助経路を持つ。旧「約627チャンクのDense検索のみ」は従来v1の説明であり、現在の全構成ではない。

## Data Source

- 従来v1：ハムスター飼育記事／YouTube制作台本のテキスト。既存namespaceをfallbackとして保持する。
- 階層v1：承認済み動画台帳、原文台本、YouTubeカタログ。タイトル・URL・サムネイル等を統合する。元台本を保持し、時間付き字幕を自動で30〜90秒へ分割する旧案とは異なる。
- RAGサーバー実体：`/Users/gota/docker/hamster_rag_server`。同所の`docs/hierarchical_rag.md`・`docs/cloud_rag_pipeline.md`と、[後発仕様](rag_hierarchical_spec_v1.md)を参照する。各文書の「まだ切り替えない」は当時段階の説明として読む。

## Indexing Pipeline

- 従来v1：Notebookで文／行単位に分割し、`text-embedding-3-small`の1536次元ベクトルをPineconeへ格納していた。
- 階層v1：`app/hierarchical_rag.py`、`app/scripts/build_hierarchical_corpus.py`、`app/scripts/index_hierarchical_corpus.py`に、原文／SHA保持、章・STEP等の構造化、親Section／子Chunk、安定ID、子Embedding、親fetch専用レコードとdefault namespace保護がある。同じ子コーパスから日本語BM25も構築する。
- 保存済み`artifacts/hierarchical_v1_corpus/build_report.json`：214文書・607親・2,351子・失敗0。動画mappingには未確定／未対応も含み、全回答に動画が付く証拠ではない。

## Vector Database

- Pinecone／`hamster-embeddings`／1536次元／cosineを使用する既存構成。
- 従来namespaceと、階層v1の不変release namespaceを分離する。627件は従来記録で、今回DB件数を再照会していない。
- 10/24保存済み配備資料では、階層フラグ有効、`hierarchical-v1-2026-09-30-initial`と同releaseのBM25コーパス設定を保持して`hamster-rag-api-00021-pob`へ100%切替した実績がある。現在の本番状態を新たに照会した意味ではない。

## Retrieval & Generation

- `app/rag_logic.py:1609〜1682`：会話履歴から検索クエリを補完し、フラグ有効時は階層検索。子Dense検索、日本語BM25による候補救済、RRF、決定論的な再順位付け、親重複排除／展開、根拠選択、動画候補を経て生成する。階層検索失敗時は旧v1へfallbackする。
- `generate_answer`は安全・環境・緊急の一部回答を生成後に同じ取得根拠で再照合する。これは2回目のLLM呼出しであり、不足論点を探し直すエージェント検索ではない。
- `AI-02`の複数調査項目計画・不足論点判定・最大2回再検索の制御は、確認した通常相談経路に未実装。固定検索と補助根拠照合は既存実装として再利用する。
- APIは`answer / chunks / related_videos / namespace / rag_build`等の互換応答。旧9/12案の主張別Citation・時間指定動画・direct／supporting／general・毎回答1動画保証の全契約とは異なり、後発v1ではCitation・高度Cross Encoderは必須外である。

## Frontend Integration

- [search_function.dart](../lib/screens/search_function.dart):93〜108、1144〜1162がchunkと関連動画メタを受領する。:1544〜1620の「参照された内容」ダイアログ内に、サムネイル・タイトル・YouTubeリンクと根拠抜粋を表示する。:2279〜2294が回答から開く導線。
- URL／画像が不足すればプレビューを隠す。独立した関連動画カードを毎回答に最低1件表示する保証、開始秒や関連度区分・理由を使う表示は、この経路には未実装。
- 最新両版のAI各1件は本人確認済みで、再送しない。10/25本人の既存回答操作により、iOS Release／Android更新版の両方で動画タイトル・画像表示、外部動画URLの起動、HamCareへの復帰をPASS確認。追加AI・再操作は不要。保存済み32/32回答・87動画のtitle/url/thumbnail契約証拠も再利用する。関連動画を根拠と誤認させない意味上の区別・毎回答の動画保証を、この結果だけで完了にはしない。
- 会話・RAGメタデータはFirestoreの履歴へ保存する。履歴自体をPineconeの知識検索対象にはしない。

## Existing Evidence and Scope

RAG側`docs/cloud_rag_pipeline.md`「初回リリースの回答レビューと次回評価の必須項目」に32問・親子文脈・生成回答を人手確認し初回実用リリースを承認した記録がある。`artifacts/rag_answer_review_hybrid_final/answer_review.json`は32問・Child10／Parent5／BM25の比較成果物。別runの検索指標や設定を混ぜず、最新実機のUI検証済みとは読み替えない。会話型・主張単位・安全評価等の拡張は「次のRAG変更／評価拡張時」の条件として保持する。

保存配備証拠は `/Users/gota/hamcare-deploy-staging/ordinary-trial-access-20261024/audit/` の `rag-rollout-before-safe.json`、`rag-activation-result.json`、`deployed-rag-source-parity.json`。現行sourceと当時配備元の階層／検索／語彙／根拠／API関連sourceの一致を確認した。個々の最新リクエストが階層検索を通りfallbackしなかったかは未確認。

本人決定により初版は既存Hierarchical v1を使用する。AI-02反復検索・BETA-01専用権限は初版に追加しない。旧契約差分は保存し、RAGを作り直さない。

## Role of Firestore

- 認証済みUIDの有効契約／通常体験、有限のAI使用予約・再送管理。
- 質問・会話履歴、明示的な回答評価、運用・改善の記録。
- 専用beta権限は確認した現行経路に未実装。通常trial、分析上のテスター分類、有料権限付与を区別する。
