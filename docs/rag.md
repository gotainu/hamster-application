# RAG Architecture

## Overview
本プロジェクトでは、ハムスター飼育に関する8年分のテキスト記事を知識ベースとした
Retrieval-Augmented Generation（RAG）システムを採用している。

RAGは以下の3レイヤで構成される。

1. インデクシング（オフライン）
2. 検索・生成API（オンライン）
3. フロントエンド（Flutter）

---

## Data Source
- ハムスター飼育記事（約8年分）
- テキスト形式（.txt）
- 管理リポジトリ：
  - hamster_breeding_project
  - senarios/ ディレクトリ

---

## Indexing Pipeline
- Notebookベースで実行
- 文単位／行単位でチャンク化
- バイト長制限（80〜3500 bytes）
- OpenAI `text-embedding-3-small` により1536次元埋め込み生成
- Pineconeにupsert

---

## Vector Database
- Pinecone
- Index name: hamster-embeddings
- Dimension: 1536
- Metric: cosine
- Type: Dense
- Namespace: default
- Vector count: 627

---

## Retrieval & Generation
- FastAPIサーバー（hamster_rag_server）
- クエリをembedding化
- PineconeでTop-K検索
- 取得したチャンクをコンテキストとしてLLMに投入
- 回答を生成

---

## Frontend Integration
- FlutterアプリからFastAPIに質問を送信
- 回答を表示
- 会話履歴はFirestoreに保存（RAG検索対象ではない）

---

## Role of Firestore
FirestoreはRAGの検索対象ではなく、以下の用途で使用する。

- ユーザー質問ログ
- チャット履歴
- 将来的な分析・改善用途