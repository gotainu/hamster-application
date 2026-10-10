# Hamster App Hierarchical RAG 改修仕様書

**Document ID:** RAG-HIERARCHICAL-SPEC  
**Version:** 1.0  
**Status:** Draft for implementation planning  
**Target:** Hamster App Backend / RAG System  
**Primary implementer:** Codex  
**Last updated:** 2026-09-27

---

## 1. 目的

現在のハムスターアプリでは、YouTube動画用に作成された大量のシナリオ `.txt` ファイルをRAGの知識源として利用している。

現行システムでは、これらのテキストをチャンク化・Embeddingし、ユーザーからハムスター飼育について相談された際に関連情報を検索し、LLM回答のContextとして利用している。

今回の改修では、このRAGを単純な固定長Chunking中心の構造から、以下を保持した **Hierarchical RAG（Parent / Child RAG）** へ変更する。

- YouTubeシナリオ内の意味構造
- 見出し
- ランキング
- STEP
- 基本編 / 応用編
- 各項目の親子関係
- 動画単位のMetadata

最終的には、ユーザーへのAI回答に加えて、以下を提示し、ユーザーがアプリ内の相談から関連動画を直接視聴できるUXを実現する。

- 関連するYouTube動画
- 動画タイトル
- サムネイル
- YouTube URL

---

## 2. 最終的に実現したいUX

ユーザーがハムスターアプリで相談する。

例：

> 最近ハムスターが部屋散歩したがるのですが、毎日出した方がいいですか？

RAGはシナリオ群から関連情報を検索し、AIが回答を生成する。

回答画面には通常の回答に加え、関連する動画を表示する。

```text
AI回答
────────────────

ハムスターが外に出たがる頻度だけでなく、
普段の飼育環境や個体ごとの探索行動なども
考慮して判断するとよいです。

────────────────

関連動画

[ Thumbnail ]

部屋散歩の基本と応用

YouTubeで見る >
```

サムネイルをタップするとYouTube動画を開く。

---

## 3. Scope

### 3.1 対象

本仕様の対象は以下とする。

- YouTubeシナリオ `.txt` の読み込み
- 原文保存
- テキストの最小限の正規化
- 文書構造解析
- Section生成
- Parent / Child Chunk生成
- Embedding
- Vector DB格納
- Retrieval
- Parent Context Expansion
- Video Metadata管理
- ScenarioとThumbnailの対応付け
- YouTube URLとの対応付け
- AI回答に関連動画情報を返すBackend設計
- 既存RAGから新RAGへのMigration
- 新旧RAGの評価

### 3.2 将来的な拡張対象

以下は将来的に追加可能な設計とするが、v1の必須実装とはしない。

- 論文
- 飼育本
- 獣医資料
- Web資料
- `knowledge_type` 分類
- `evidence_type` 分類
- Citation表示
- Cross Encoder等による高度なReranking
- Image Embedding
- Thumbnail画像自体のSemantic Search
- Graph RAG

---

## 4. Non-Goals

v1では以下を目的としない。

- YouTube台本そのものの文章改善
- 文体変更
- 誤字修正
- 内容の要約
- 内容の書き換え
- 事実関係の自動修正
- LLMによる知識の追加
- Scenario内の主張が正しいかどうかの検証
- Thumbnail画像の内容解析
- YouTube Recommendation Algorithmの構築

今回のRAG前処理の目的は、**元のシナリオ内容を可能な限り保持したまま、検索に適した構造へ変換すること**である。

---

## 5. Source Data

現在、YouTube制作に利用したScenarioファイル群が以下のようなディレクトリに保存されている。

```text
final_cut_pro/
└── movie_material/
    ├── scenario/
    │   ├── video_a.txt
    │   ├── video_b.txt
    │   └── ...
    │
    ├── sumbnail/
    │   ├── video_a.jpg
    │   ├── video_b.png
    │   └── ...
    │
    └── ...
```

※ 現在のディレクトリ名 `sumbnail` 等については、既存資産との互換性を優先し、本改修のみを理由にrenameしない。

ScenarioファイルにはYouTube動画用の台本が保存されている。

---

## 6. Scenarioファイルの特徴

Scenarioは一般的な文章データではない。

YouTube動画制作のために、以下の特徴がある。

- 一文の途中で改行されている
- 句読点が省略されている
- 見出しが独立した行になっている
- ランキング形式が存在する
- STEP形式が存在する
- 基本編 / 応用編等の章構造が存在する
- 「その1」「その2」形式が存在する
- 導入 / 解説 / 結論等の論理構造が存在する

例：

```text
ハムは本来野生下では
一晩で５km以上も移動する
と言われてますよね？
それに対して飼育下では
自由に移動できる範囲が狭いです
```

RAG用には以下程度まで正規化する。

```text
ハムは本来野生下では一晩で５km以上も移動すると言われてますよね？
それに対して飼育下では、自由に移動できる範囲が狭いです。
```

文章の意味・語彙・ニュアンスは変更しない。

---

## 7. Target Architecture

最終的な知識構造は以下とする。

```text
Video
│
├── Metadata
├── Thumbnail
├── YouTube URL
└── Document
     │
     ├── Metadata
     └── Section
          │
          ├── Section
          │    └── ...
          └── Child Chunk
```

論理的には以下の4レイヤーを中心とする。

```text
Video
↓
Document
↓
Section
↓
Chunk
```

---

## 8. Processing Pipeline

基本Pipelineは以下とする。

```text
Scenario.txt
    │
    ▼
1. Raw Loader
    │
    ▼
2. Mechanical Cleaner
    │
    ▼
3. Structure Analyzer
    │
    ▼
4. Section Builder
    │
    ▼
5. Minimal Text Normalizer
    │
    ▼
6. Parent / Child Chunk Builder
    │
    ▼
7. Embedding Builder
    │
    ▼
8. Vector DB
```

重要：

**Minimal Text NormalizerよりStructure Analyzerを先に実行する。**

理由は、以下のような改行や表現自体がDocument Structureを判定する重要な情報だからである。

```text
【基本編】

STEP1：専用スペースを決める

第5位　人影を見ても逃げない

その１
```

---

## 9. Raw Loader

Scenarioファイルを読み込む。

最低限以下を取得する。

```text
source_file_path
source_file_name
raw_text
file_hash
loaded_at
```

原文は必ず保持する。

原則として既存Scenarioファイルそのものを書き換えない。

---

## 10. Mechanical Cleaner

Mechanical Cleanerは可能な限りLLMを使用せず、決定論的処理とする。

対象：

- Encoding統一
- 改行コード統一
- BOM処理
- 不可視制御文字除去
- 行末空白除去
- 異常に大量な空行の整理
- Unicode正規化
- URL検出

ただし、次のような文字列はDocument Structure解析に使用する可能性があるため削除しない。

```text
【○○】
◆○○
■○○
STEP1
STEP2
第1位
第5位
その1
その２
ーーー
-----
```

Mechanical Cleanerでは文章そのものの改行結合を行わない。

---

## 11. Structure Analyzer

### 11.1 目的

Scenario全文からDocument Structureを解析する。

例えば、

```text
【基本編】
部屋散歩はこうやります

STEP1：専用スペースを決める

STEP2：照明は暗めにする

STEP3：タイミングはハムに合わす
```

の場合、

```text
Document
└── 基本編
    ├── STEP1
    ├── STEP2
    └── STEP3
```

という構造を抽出する。

### 11.2 基本方針

可能であれば、

1. Rule / Heuristic
2. LLM

を組み合わせる。

明示的な見出しは機械的に検出可能である。

例：

```text
STEP[0-9]+
第[0-9一二三四五六七八九十]+位
その[0-9一二三四五六七八九十]+
【...】
◆...
```

一方で、明示的な記号が存在しない意味構造についてはLLMを利用する。

LLMに完全にStructure Detectionを依存する必要はない。

### 11.3 Structure Analyzer Input

LLMへ渡す場合は、原文にLine Numberを付与する。

例：

```text
001: 皆さんこんにちは
002: Goです
003:
004: 【基本編】
005: 部屋散歩はこうやります
006:
007: STEP1：専用スペースを決める
...
```

LLMには本文を書き換えさせず、**Section BoundaryだけをStructured Outputとして返させる。**

---

## 12. document_type

Document単位で大まかな形式を保持できるようにする。

v1候補：

```text
ranking
list
guide
how_to
comparison
product_review
experiment
retrospective
explanation
qa
news_or_opinion
other
```

この分類はRAG検索に必須ではないため、分類精度が不十分でもPipeline全体が失敗しない構造とする。

---

## 13. Section Schema

Sectionの概念Schemaは以下とする。

```json
{
  "section_id": "sec_xxx",
  "document_id": "doc_xxx",
  "video_id": "vid_xxx",
  "title": "STEP2：照明は暗めにする",
  "section_type": "step",
  "level": 2,
  "parent_section_id": "sec_parent",
  "order": 2,
  "rank": null,
  "step_number": 2,
  "item_number": null,
  "source_start_line": 160,
  "source_end_line": 179,
  "raw_text": "...",
  "normalized_text": "..."
}
```

以下はNullableとする。

```text
rank
step_number
item_number
parent_section_id
```

---

## 14. section_type

v1では以下程度を想定する。

```text
introduction
chapter
topic
ranking_item
list_item
step
comparison_item
product
experiment
conclusion
other
```

過度に細かい分類は避ける。

---

## 15. Structure Integrity

Structure AnalyzerのOutputについて以下を検証する。

必須条件：

- `source_start_line <= source_end_line`
- Section同士の異常なOverlapがない
- Section BoundaryがSource Text上に存在する
- Source Textが理由なく欠落しない
- Parent IDが存在する
- Parent / Childで循環参照しない
- `level` が親より深くなる

LLM Outputが不正な場合はRetryまたはFallbackを行う。

---

## 16. Minimal Text Normalizer

### 16.1 目的

YouTube台本特有の不要な改行と句読点不足のみを修正する。

文章のRewriteは行わない。

### 16.2 許可する変更

- 不要な改行の削除
- 意味のある段落改行の維持
- 句点「。」追加
- 読点「、」追加
- 既存の「？」「！」等の維持
- 空白整理

### 16.3 禁止する変更

- 言い換え
- 要約
- 単語追加
- 単語削除
- 語順変更
- 文体変更
- 敬語修正
- 誤字修正
- 表記ゆれ修正
- 主張の修正
- 数値修正
- 新しい知識の追加
- 情報補足
- Fact Check結果の反映

入力が誤っているように見えても変更しない。

---

## 17. Normalizer Prompt Requirement

LLMを利用する場合、最低限以下の制約をSystem Promptへ含める。

```text
あなたの仕事は文章を書き換えることではありません。

入力された日本語について、

1. 動画台本用の不要な改行を結合する
2. 不足している句読点を補う
3. 意味のある段落境界を維持する

だけを行ってください。

元の単語、語順、意味、ニュアンスを変更してはいけません。

単語を追加、削除、言い換えしてはいけません。

誤字と思われる表現も勝手に修正してはいけません。
```

---

## 18. Normalizer Validation

LLM指示だけに依存しない。

Normalizer前後でCanonical Textを比較する。

概念：

```python
canonical(raw_text)
canonical(normalized_text)
```

`canonical()` では少なくとも、以下のうちNormalizerによる変更を許可した文字だけを除去する。

```text
改行
Whitespace
、
。
！
？
```

理想条件：

```python
canonical(raw_text) == canonical(normalized_text)
```

一致しない場合、LLMが語彙変更等を行った可能性があるためNormalization Errorとして扱う。

---

## 19. Normalizer Failure Policy

Normalizationに失敗してもRAG Ingestion全体を停止しない。

Fallback候補：

```text
normalized_text = raw_text
```

または、決定論的な最小改行結合処理のみ実行する。

Normalization品質よりも、**原文を破壊しないこと**を優先する。

---

## 20. Document Schema

概念Schema：

```json
{
  "document_id": "doc_xxx",
  "video_id": "vid_xxx",
  "title": "...",
  "document_type": "guide",
  "source_file_path": "...",
  "source_file_name": "...",
  "source_hash": "...",
  "raw_text": "...",
  "created_at": "...",
  "processed_at": "...",
  "pipeline_version": "1.0"
}
```

---

## 21. Hierarchical Chunking

基本構造：

```text
Document
   │
   └── Section Parent
          │
          ├── Child Chunk
          ├── Child Chunk
          └── Child Chunk
```

検索対象は主としてChild Chunk。

回答Context生成時にはParent Sectionまで展開する。

---

## 22. Section First Policy

Chunkは必ずSection内で生成する。

禁止例：

```text
第5位の末尾
+
第4位の冒頭
```

のようなChunk。

Chunk BoundaryがSection Boundaryを跨いではならない。

---

## 23. Short Section

Sectionが十分短い場合、

```text
Section = Child Chunk
```

としてよい。

無意味に短いSectionをさらに分割しない。

---

## 24. Long Section

長いSectionのみChild Chunkへ分割する。

初期候補値：

```text
target:
約350 tokens

max:
約500 tokens

overlap:
約40〜60 tokens
```

ただし、この値は現行Embedding Model・LLM Context・既存実装を調査後に確定する。

現段階では固定仕様ではない。

---

## 25. Chunk Boundary

可能な限り以下を優先してBoundaryを決める。

1. 意味段落
2. 文
3. Token上限

単純な文字数切断を第一選択にしない。

---

## 26. Chunk Schema

概念Schema：

```json
{
  "chunk_id": "chunk_xxx",
  "video_id": "vid_xxx",
  "document_id": "doc_xxx",
  "section_id": "sec_xxx",
  "parent_section_id": "sec_parent",
  "document_type": "guide",
  "section_type": "step",
  "section_title": "STEP2：照明は暗めにする",
  "breadcrumb": "基本編 > STEP2：照明は暗めにする",
  "raw_text": "...",
  "normalized_text": "...",
  "embedding_text": "...",
  "source_start_line": 160,
  "source_end_line": 179,
  "chunk_index": 0,
  "pipeline_version": "1.0"
}
```

---

## 27. Embedding Text

Embedding対象には本文だけではなく、最低限Title / Breadcrumb情報を付加する。

例：

```text
動画: 部屋散歩の基本と応用
セクション: 基本編 > STEP2：照明は暗めにする

ハムは夜行性です。明るい環境での部屋散歩は……
```

目的：

同じ単語を使用する複数動画・複数SectionのSemantic Distinctionを改善する。

---

## 28. Embedding Source

基本的には、

```text
normalized_text
```

を利用する。

`raw_text` は原文保存・Source Verification用途に利用する。

Normalizerに失敗した場合は `raw_text` を使用可能とする。

---

## 29. Vector DB

Vector DBには主としてChild Chunkを保存する。

Thumbnail画像そのものはVector DBへ保存する必要はない。

Vector DBは、**Semantic Searchを担当する。**

Video Asset管理とは責務を分離する。

---

## 30. Video Registry

動画単位のMetadataを管理するEntityを作成する。

概念Schema：

```json
{
  "video_id": "vid_xxx",
  "title": "【100発100中】ハムスターが夢中になるオモチャ",
  "scenario_path": "...",
  "thumbnail_path": "...",
  "thumbnail_url": null,
  "youtube_url": null,
  "published_at": null,
  "created_at": "...",
  "updated_at": "..."
}
```

---

## 31. video_id

`video_id` は恒久的なPrimary Identifierとする。

Scenario File NameをPrimary Keyにしない。

理由：

- タイトル変更
- ファイルRename
- 全角半角差
- 空白
- Unicode差
- 絵文字
- `.jpg` / `.png`
- `_b`
- 修正版

等によって対応関係が壊れる可能性があるため。

---

## 32. Scenario / Thumbnail Matching

初回Migration時のみFilenameを利用したMatchingを行ってよい。

Pipeline：

```text
scenario filename
↓
normalize filename
↓
thumbnail filename candidate
↓
match
```

ただし、曖昧な候補を自動確定しない。

---

## 33. Asset Match Status

最低限以下のStatusを出力可能にする。

```text
MATCHED
AMBIGUOUS
MISSING_THUMBNAIL
ORPHAN_THUMBNAIL
```

Migration時にはReportを生成する。

例：

```text
asset_match_report.csv
```

---

## 34. YouTube URL

YouTube URLはVideo Registryで管理する。

Scenario本文に含まれるAmazon URL、過去動画URL等とは区別する。

```text
video.youtube_url
```

は、**そのScenarioに対応する動画自身のCanonical YouTube URL** とする。

---

## 35. YouTube Metadata Import

YouTube URLとの対応表は後からImport可能な設計とする。

例：

```csv
video_id,title,youtube_url,published_at
vid_001,...,https://youtu.be/...,2026-01-01
```

Import方式については既存Infrastructureを確認後に確定する。

---

## 36. Retrieval Architecture

基本Retrieval Flow：

```text
User Query
    │
    ▼
Query Embedding
    │
    ▼
Child Chunk Vector Search
    │
    ▼
Candidate Chunks
    │
    ▼
Optional Rerank
    │
    ▼
Relevant Child Chunks
    │
    ▼
Parent Section Expansion
    │
    ▼
Context Builder
    │
    ▼
LLM
```

---

## 37. Child Search

Semantic Searchは原則としてChild Chunk単位で行う。

理由：

Parent Section全体をEmbeddingすると内容が広すぎ、QueryとのSemantic Similarityが薄まる可能性があるため。

---

## 38. Parent Expansion

Child ChunkがHitした後、そのChunkが所属するParent SectionのContextを取得可能にする。

例：

```text
検索Hit

「照明は暗めにする」

↓

Parent

「基本編 > STEP2：照明は暗めにする」

↓

Section全体または必要範囲をLLM Contextへ投入
```

---

## 39. Duplicate Parent Handling

同じParent Sectionに属する複数ChildがHitした場合、Parent本文を重複してContextへ挿入しない。

Deduplicationする。

---

## 40. Context Budget

Parent ExpansionによってContextが過大にならないようToken Budgetを設定する。

具体値は既存LLM ModelおよびContext Window確認後に決定する。

**TBD**

---

## 41. Reranking

v1でRerankingを必須とするかは現行システム調査後に判断する。

現行で存在しない場合、Phase 1では以下まででもよい。

```text
Vector Search
+
Parent Expansion
```

Rerankerは独立して後から追加できる構造とする。

---

## 42. Related Video Retrieval

検索されたChunkは必ず `video_id` を保持する。

したがって、

```text
Retrieved Chunks
↓
video_id grouping
↓
Related Video Candidates
```

を生成する。

初期Ranking候補：

- Best Chunk Similarity
- Hit Count
- Rerank Score

複雑なRecommendation Systemはv1では不要。

---

## 43. Backend Response

将来的にFlutterへ以下のようなResponseを返せる構造にする。

概念Schema：

```json
{
  "answer": "...",
  "sources": [
    {
      "video_id": "vid_xxx",
      "document_id": "doc_xxx",
      "section_id": "sec_xxx",
      "section_title": "STEP2：照明は暗めにする"
    }
  ],
  "recommended_videos": [
    {
      "video_id": "vid_xxx",
      "title": "部屋散歩の基本と応用",
      "thumbnail_url": "https://...",
      "youtube_url": "https://youtu.be/...",
      "reason": "部屋散歩について詳しく解説しています"
    }
  ]
}
```

既存APIとのBackward Compatibilityを考慮する。

---

## 44. Flutter

v1 RAG Backend改修完了後、Flutter側でRelated Video Cardを追加可能にする。

概念UI：

```text
AI Answer

────────────────

関連動画

┌──────────────────┐
│    Thumbnail     │
│                  │
│ 部屋散歩の基本と応用 │
│                  │
│ YouTubeで見る >   │
└──────────────────┘
```

BackendのRAG構築とFlutter UI構築は可能であれば分離して進める。

---

## 45. Knowledge Type

以下のMetadataは有用である。

```text
research_based
book_based
personal_experience
personal_observation
hypothesis
opinion
product_review
external_source
```

ただし、v1では必須実装としない。

Schema拡張が容易な構造としておく。

---

## 46. Versioning

Knowledge PipelineにはVersionを持たせる。

例：

```text
pipeline_version = "1.0"
```

将来的にParser / Chunking / Embedding方式を変更した際に識別可能にする。

---

## 47. Idempotency

同じSource Fileを複数回処理しても無制限にDocumentやChunkが重複しない設計とする。

File Hash等を利用することを検討する。

変更がないScenarioは再Embeddingしない設計が望ましい。

具体方式は既存Infrastructure調査後に決定する。

---

## 48. Logging

最低限以下を確認可能にする。

```text
processed files
failed files
structure analysis failures
normalization failures
generated sections
generated chunks
asset matching status
embedding failures
DB write failures
```

---

## 49. Error Isolation

1ファイルの処理失敗によって全Scenario Ingestionが停止しない設計を優先する。

例：

```text
Scenario A → SUCCESS
Scenario B → NORMALIZATION_WARNING
Scenario C → STRUCTURE_ERROR
Scenario D → SUCCESS
```

Batch完了後にReportを確認できることが望ましい。

---

## 50. Migration Strategy

既存RAGを即座に削除しない。

一時的に、

```text
RAG v1
現在のProduction RAG

RAG v2
新Hierarchical RAG
```

を共存可能にする。

---

## 51. Migration Sequence

推奨：

```text
1. 現行RAG調査
2. 新Pipeline実装
3. 新Index作成
4. Scenario Corpus投入
5. Retrieval Test
6. Evaluation
7. v1 / v2比較
8. Production切替
9. 旧Index削除判断
```

---

## 52. Evaluation Dataset

Golden Question Datasetを作成する。

最低30問程度を目標とする。

カテゴリ例：

```text
部屋散歩
ケージ
床材
車輪
温度
湿度
水
食事
懐き
オモチャ
高齢
健康観察
```

---

## 53. Retrieval Evaluation

少なくとも以下を評価する。

```text
Recall@K
Relevant Section Hit
Relevant Video Hit
Irrelevant Context Rate
```

厳密な自動評価が難しい場合はHuman Evaluationでもよい。

---

## 54. Answer Evaluation

同一質問を、

```text
Existing RAG

vs

Hierarchical RAG
```

へ入力し比較する。

評価項目：

- 質問への関連性
- 必要な情報を取得できているか
- 不要情報が混ざっていないか
- Source Scenarioの意味を保持しているか
- 関連動画が適切か
- Hallucinationが増えていないか

---

## 55. Acceptance Criteria — Normalization

必須：

- `raw_text` を100%保持する
- Normalizerが内容を書き換えない
- 語彙追加を検出できる
- 語彙削除を検出できる
- Normalizer失敗時にFallbackできる
- Normalizer失敗で全Batchが停止しない

---

## 56. Acceptance Criteria — Structure

必須：

- 明示されたRankingをSection化できる
- STEP構造をSection化できる
- 「その○」形式をSection化できる
- Chapter > Sectionの親子関係を保持できる
- Source Line Rangeを保持できる
- Parent / Child関係に循環がない
- Source本文が理由なく欠落しない

---

## 57. Acceptance Criteria — Chunking

必須：

- ChunkがSection Boundaryを跨がない
- 全Chunkに `section_id` が存在する
- 全Chunkに `document_id` が存在する
- 全Chunkに `video_id` が存在する
- Breadcrumbを生成できる
- 短いSectionを不必要に分割しない

---

## 58. Acceptance Criteria — Assets

必須：

- ScenarioとThumbnailのMatching Reportを作成できる
- Ambiguous Matchを自動確定しない
- Missing Thumbnailを検出できる
- Orphan Thumbnailを検出できる
- `video_id` でAssetを管理できる

---

## 59. Acceptance Criteria — Retrieval

必須：

- Child Chunk Searchができる
- ChunkからParent Sectionを取得できる
- ChunkからVideoを取得できる
- Parent Contextを重複排除できる
- Related Video候補を取得できる

---

## 60. Acceptance Criteria — Compatibility

必須：

- 現行Production RAGを即座に破壊しない
- 新旧RAG比較が可能
- Flutter既存Chat機能を壊さないMigration Planを作成する
- Rollback可能な設計を優先する

---

## 61. Security

現行BackendのAuthentication / Authorization設計を維持する。

RAG改修を理由に、以下を緩和しない。

- Firebase Authentication
- API Authentication
- Cloud Run / Cloud Functions security

具体構成はrepository調査後に確認する。

---

## 62. Cost Consideration

LLMによるStructure Analysis / NormalizationはIngestion時のみ実施し、通常Query時には実行しないことを基本とする。

```text
Offline / Batch

Structure Analysis
Normalization
Embedding

Online

Query
Retrieval
Answer Generation
```

毎回のChatでScenario全文をLLM解析しない。

---

## 63. Cache / Incremental Processing

Scenarioが変更されていない場合、以下を再実行しなくてよい設計を検討する。

- Structure Analysis
- Normalization
- Embedding

Source Hashを利用可能。

---

## 64. Testing

最低限以下のUnit / Integration Testを用意する。

### 64.1 Normalizer

- 改行のみの変更
- 句読点追加
- 語彙変更検出
- 数字変更検出
- 原文保持

### 64.2 Structure Analyzer

- Ranking
- STEP
- List
- Nested Chapter
- Headingなし
- 不完全Heading

### 64.3 Chunker

- Short Section
- Long Section
- Section Boundary
- Overlap
- Breadcrumb

### 64.4 Asset Matcher

- Exact Match
- Extension違い
- Unicode差
- Ambiguous
- Missing
- Orphan

### 64.5 Retrieval

- Child Search
- Parent Expansion
- Parent Deduplication
- Video Lookup

---

## 65. Implementation Principle

既存システムを全面Rewriteすることを目的としない。

まず現行コードを理解し、再利用可能な処理は残す。

例：

- Embedding Client
- Vector DB Client
- Authentication
- Chat API
- Firebase Client
- Cloud Run Configuration

等。

変更は必要最小限かつ段階的に行う。

---

## 66. Codexが最初に行うタスク

重要：

**この仕様書を読んだ直後にコード変更を開始してはいけない。**

まずrepositoryの現行RAGを調査する。

---

## 67. Initial Repository Investigation

以下を調査して報告する。

### 67.1 Files

- RAG関連ファイル一覧
- Ingestion Script
- Backend Chat Handler
- Retrieval関連コード
- Embedding関連コード
- Vector DB関連コード
- Firebase / Firestore関連コード

### 67.2 Current Ingestion

- Scenario FileのInput元
- File Loader
- Preprocessing
- Chunking
- Embedding
- DB Write

### 67.3 Current Chunking

確認：

```text
chunk size
overlap
separator
token / character basis
```

### 67.4 Embedding

確認：

```text
embedding provider
embedding model
embedding dimension
batch size
```

### 67.5 Vector Database

確認：

```text
DB technology
index
namespace / collection
metadata
similarity metric
```

### 67.6 Retrieval

確認：

```text
top-k
threshold
metadata filter
reranking
query rewriting
```

### 67.7 Context Builder

確認：

```text
retrieved chunks
↓
prompt context
↓
LLM
```

の処理。

### 67.8 API

確認：

```text
Flutter
↓
Backend
↓
RAG
↓
LLM
↓
Backend Response
↓
Flutter
```

### 67.9 Data Model

現在のChunk Metadata Schemaを確認する。

---

## 68. Impact Analysis

現行調査後、新Hierarchical RAGへ変更するために影響するコードを一覧化する。

形式例：

```text
backend/rag/loader.py
変更必要
理由: Section解析を追加するため

backend/rag/chunker.py
Replace / Extend
理由: Section-aware Chunkingへ変更

backend/rag/retriever.py
変更必要
理由: Parent Expansion追加

backend/chat.py
小変更
理由: Related Video metadata返却

lib/...
現時点では変更不要
```

実際のPathはrepository確認後に記載する。

---

## 69. Current vs Target Flow

Codexは調査後、以下の形式でFlow比較を作成する。

```text
CURRENT

Scenario
↓
???
↓
Chunk
↓
Embedding
↓
Vector DB
↓
Search
↓
LLM


TARGET

Scenario
↓
Raw Loader
↓
Mechanical Cleaner
↓
Structure Analyzer
↓
Section
↓
Minimal Normalizer
↓
Child Chunk
↓
Embedding
↓
Vector DB
↓
Child Search
↓
Parent Expansion
↓
Context Builder
↓
LLM
↓
Related Video
```

---

## 70. Implementation Plan

現行調査後にCodexは実装Planを提示する。

まだ実装はしない。

Planには以下を含める。

```text
Phase
Files affected
New files
DB migration
Tests
Rollback
Risks
```

ユーザー承認後に実装へ進む。

---

## 71. 未確定事項

以下はrepository調査後に決定する。

```text
Vector DB technology
Embedding Model
Embedding Dimension

Final Child Chunk Size
Final Overlap

Top-K

Reranking採用有無

Parent Context上限

Video Registry保存先

Thumbnail Hosting先

YouTube Metadata保存先

Migration Index Name

Evaluation方式
```

Codexは既存実装を無視して勝手に決定してはいけない。

---

## 72. Design Priority

本改修で優先する順序は以下。

```text
1. 原文を壊さない
2. 文書構造を保持する
3. Section Boundaryを保持する
4. Retrieval精度を改善する
5. 既存RAGとの互換性を維持する
6. 動画AssetとRAGを接続する
7. 高度なRerankingや分類を追加する
```

---

## 73. 最終目標

このシステムは単にYouTube Scenarioを検索するものではない。

長期間蓄積されたハムスター飼育コンテンツを、

```text
Unstructured YouTube Scripts
```

から、

```text
Structured Hamster Husbandry Knowledge Base
```

へ変換する基盤とする。

将来的には、

```text
YouTube Scenario
+
Scientific Papers
+
Books
+
Veterinary Sources
+
Personal Observations
```

等を統合可能なRAG Architectureへ成長できる構造を目指す。

ただしv1ではYouTube Scenarioを高品質に構造化・検索できることを最優先とする。

---

## 74. Codexへの最初の実行指示

この仕様書を確認後、以下を実行すること。

```text
この仕様書に基づき、現在のrepositoryに存在するRAGシステムを調査してください。

重要：
まだコード変更は行わないでください。

以下を報告してください。

1. RAG関連ファイル一覧
2. 現行Ingestion Flow
3. 現行Chunking方式
4. Chunk Size / Overlap
5. Embedding Model
6. Vector Database
7. 現在のMetadata Schema
8. Retrieval方式
9. Top-K
10. Rerank有無
11. Context Builder
12. Chat APIまでの処理
13. FlutterへのResponse
14. 新方式で影響を受けるファイル
15. Migration Risk
16. 再利用可能な既存Component

最後に、

CURRENT RAG
↓
TARGET HIERARCHICAL RAG

のArchitecture差分を整理してください。

その後、実装Phaseを提案してください。

ユーザーの承認を得るまではコードを変更しないでください。
```

---

# End of Specification
