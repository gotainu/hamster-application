# AI無料相談の承認済み初期上限と費用見積もり

更新日: 2026-10-04  
状態: **初期ポリシー承認済み。実費精算ではない。**

## 承認済みポリシー

| 項目 | 初期値 |
| --- | ---: |
| 無料体験期間 | 21日。開始時にpolicy versionと終了日時を固定 |
| AI相談上限 | ユーザーが送る相談リクエスト20件。初回チュートリアル相談を含む |
| 予約額 | 1相談につき$0.05 |
| 合計予約枠 | 1ユーザーあたり$1.00 |
| 冪等性 | 同一UIDとrequest IDの再送は再消費しない。別UID/異なる内容とのID再利用は拒否 |
| timeout / unknown | 予約を戻さず、同じIDの状態を確認。無条件に再生成しない |
| AI上限後 | 新規AI回答だけ停止。期限内の記録・SwitchBot連携・分析・生成済み初回レポート閲覧は継続 |

予約額は見積もり用の台帳額で、OpenAI実請求を精算するものでも、実費の絶対上限を保証するものでもない。usageが得られない呼び出しの費用は0と推測せず`unknown`のまま残す。

## 現在のコード条件と呼び出し上限

RAG実装で確認した最大4つのAPI呼び出し/相談:

| API呼び出し | モデル | 最大入力 | 最大出力 |
| --- | --- | ---: | ---: |
| 会話制御/問い合わせ解釈 | `gpt-4o-mini` | 12,000 | 256 |
| 検索クエリEmbedding | `text-embedding-3-small` | 8,192 | — |
| 回答生成 | `gpt-4o-mini` | 32,000 | 700 |
| 任意の根拠確認 | `gpt-4o-mini` | 32,000 | 700 |

生成モデルの入力枠は128,000 tokens。上の生成パスは1回の相談につき最大2 pass、各passが32,000 input / 700 outputで制限されている。SDKの自動retryは0。すべて同時に最大境界へ達するという意図的に保守的な仮定で、実装された有限枠を単価へ掛けている。会話制御とembeddingの最大枠も別途加えた。実際の平均入力長やgrounding実行率を実測した数字ではない。

## 単価と推定額

OpenAI公式モデルページにある標準API単価（非Batch / 非Flex）を使用。GPT-4o miniはinput $0.15/M、cached input $0.075/M、output $0.60/M。`text-embedding-3-small`はinput $0.02/M。コード上はBatch/Flexの指定なしで通常APIを呼ぶ。

```text
controller:  (12,000 × $0.15 + 256 × $0.60) / 1,000,000 = $0.0019536
embedding:   ( 8,192 × $0.02) / 1,000,000              = $0.00016384
generation:  (32,000 × $0.15 + 700 × $0.60) / 1,000,000 = $0.00522
2-pass max:  controller + embedding + 2 × generation    = $0.01255744 / 相談
4相談合計:   4 × $0.01255744                            = $0.05022976
20相談合計: 20 × $0.01255744                            = $0.2511488
```

これは現行入力・出力上限とAPI list priceで算出した**推定最悪ケース**。inputのcached料金が適用される可能性はここでは費用を引き下げる前提に使わない。Provider側の請求遅延、実装変更、想定外のAPI経路、Firebase/Cloud Run/Pinecone等の別費用は含めず、$0.05の予約を実費上限と表示しない。4相談の実費見積り$0.05022976は承認された予約総額$0.20を下回るが、保証ではないため、実行中もserver側に4件/$0.20の検証上限を強制する。

## 計測実装と現在の実績

RAG server側では各provider呼び出し単位に、呼び出しrequest ID、相談request ID、requested/returned model、input/output/cached token count、成功/失敗/結果不明、予約額、推定実費を別々に記録する。質問本文・回答本文はBigQuery/Analyticsへ送らない。実AI呼び出しが未実行の場合、実使用量・実費は不明/該当なしであり、0円実績と報告しない。

2026-10-04の公開前検証時点: 実相談0件、内部provider呼び出し0件、usage receipt 0件、予約総額$0。**推定実費は使用実績がないため未発生/未計測**（台帳でusage不明の呼び出しは0円になっていない）。合成メタデータイベントはAI実行に含まれない。

## 参考（公式OpenAI資料）

- [GPT-4o mini model/pricing](https://developers.openai.com/api/docs/models/gpt-4o-mini) — standard input/output, 128k context, model limits.
- [text-embedding-3-small model/pricing](https://developers.openai.com/api/docs/models/text-embedding-3-small) — input pricing and 8,192-token maximum input.
- [Responses API response schema](https://developers.openai.com/api/reference/cli/resources/responses/methods/create) — response ID, status, model, usage input/output token fields.

単価や利用設定が変わった場合は、model/service tier、token ceiling、1相談あたりの呼び出し数を見直してから予約値を再評価する。変更後の条件を開始済み無料体験へ遡及適用しない。
