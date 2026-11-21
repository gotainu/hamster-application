# Flutter戦略C：購入CTA監査・撤去記録（2026-11-21）

> **後続承認による更新**：以下は前工程の監査・実装履歴。最新の[Flutter Portal撤去記録](flutter_customer_portal_removal_20261121.md)により、Fの保持例外は撤回し、アプリ内Portal導線を完全撤去した。WebのPortalは維持する。本人の訂正では現在の有料契約者は0人、利用中は無料テスターであり、旧500円Priceの存在から有料契約の存在を推定しない。アカウント削除は最小の暫定拒否ガードを追加し、Stripe継続請求停止を含むサーバー側安全処理は独立次タスクに残す。

開始点は承認済み`eb731dbee423`、`feature/web-first-stripe-checkout`の専用worktree。以下の分類は**Flutter実装変更前の読み取り監査**として記録した。行番号は開始点のsourceを指す。今回の対象はアプリの購入導線と関連表示・ローカル検証だけであり、Functions/Web/Stripe/Hosting/Firestore/ストア/配信版は変更しない。

## 実装前の導線分類

| 区分 | 開始点のsourceと動作 | 今回の扱い |
|---|---|---|
| A/B 新規購入/外部決済 | `lib/screens/subscription_plan_screen.dart:93–145`。`createStripeCheckoutSession`→`checkoutUrl`→外部ブラウザ | 呼出・処理・ボタンを撤去。バックエンドFunctionは保持 |
| A 価格/購入説明 | 同画面`464–543`、特に`488`の月額500円、`517`の登録ボタン。`602–679`のStripe決済/再申込案内 | 価格と新規申込訴求を撤去、中立の利用状況表示へ |
| A 間接購入誘導 | `paid_feature_gate.dart:181–195,332–334,541–543,573–624`。locked画面からプラン画面へ | 中立表示・利用状況の読取再確認へ。体験開始動作は保持 |
| A 間接購入誘導 | `services/paid_feature_guard_service.dart:34–89`、`screens/settings.dart:541–587` | 購入画面遷移を外し、機能利用不可の案内へ |
| A レポート購入誘導 | `widgets/report_continuation_link.dart:9–16`。`legacy_first_report_body.dart:195`、`personality_report_screen.dart:436`から使用 | CTA/widgetを撤去。レポート内容・生成・analyticsは維持 |
| A locked呼出元の訴求 | `tabs.dart:294,329–330`、`quick_record_sheet.dart:179–181`、`switchbot_setup.dart:68–70`、`search_function.dart:2473–2474` | 購入を勧める文言を中立化。機能・ガード条件は維持 |
| A/G 設定内蔵規約 | `settings.dart:1462–1465`に旧500円・Stripe申込説明 | 価格/購入促進説明だけを外し、契約状態・解約の法務説明は維持 |
| C 利用状況 | `settings.dart:1019–1025,608–613`、`SubscriptionPlanScreen`、`models/billing_status.dart` | 「利用状況」へ名称/表示を整え、同一UIDの状態読取りを維持 |
| D 21日無料体験 | `paid_feature_gate.dart:215–550`、`InitialTrialRepo`、`initial_trial_access.dart`、`initial_trial_gate_state.dart` | 期間・開始条件・枠・明示開始・無料機能の権限を変更しない |
| E 権限読取 | `billing_status_repo.dart:37–75`。server確認済みsnapshot/UID切替、既存起動・復帰処理 | 維持。再確認は読取りだけで体験開始・購入を行わない |
| F 既存契約管理 | `subscription_plan_screen.dart:147–195,438–464`。`createStripeCustomerPortalSession`→外部ブラウザ | **安全例外として保持**。下記アカウント削除依存を先に解消する必要あり |
| F 削除前の管理 | `settings.dart:80–143`の警告→`124–131`のプラン管理遷移 | この処理は今回変更せず残し、独立した必須後続タスクとして記録 |
| G 非購入外部リンク | 下表のPrivacy/Terms/Support/YouTube/研究出典 | 維持。戦略Cを理由に削除しない |

全`lib`とpubspecに含まれるasset一覧/テキストを検索し、直接のCheckout実装は1箇所、Portal実装は1箇所。固定のWeb購入URL、QR購入生成/asset名は見つからなかった。画像全件のOCR・実機全画像目視までは実施していない。`AppAnalytics.logCheckout*`は既存の計測定義として残し、UIからのCheckout呼出だけを外す。イラストの`stripePaint`、avatar説明の`striped`、プロフィールの「登録する」は購入ではない。

## 非購入リンク一覧（維持対象）

| 用途 | source / 呼出 |
|---|---|
| ログインのTerms/Privacy | `screens/auth.dart:23–27,187` |
| AI同意のPrivacy | `widgets/ai_text_consent_dialog.dart:41` |
| 設定のPrivacy | `screens/settings.dart:299` |
| サポートmailto | `screens/settings.dart:515–523` |
| 利用状況画面のTerms/Privacy | `screens/subscription_plan_screen.dart:197–211` |
| 研究DOI | `screens/personality_report_screen.dart:372`、`widgets/weight_research_comparison_card.dart:77` |
| YouTube参照動画 | `screens/search_function.dart:1472` |

開始点の`launchUrl`呼出は計10箇所（購入1、Portal1、非購入8）。HTTPによるAI等のバックエンド通信は購入ページへのナビゲーションと区別する。動的な動画/研究URLのhost制限等は既存仕様であり、今回の撤去へ混ぜない。

## アカウント削除：既存の重大ブロッカー

削除前のPortalを消すだけでは、継続課金のままアカウントがなくなる危険を増やす。今回Portalを残すのは、この既存依存を維持するための例外であり、「戦略Cとしてアプリ内Portalを正式採用した」という判断ではない。

既存の`canManageSubscription`は支払未解決や`incomplete`も含む。現在配備済みPortalの実設定/実遷移は今回照会・操作しておらず、未完了の申込がPortalで完了できないことまでは保証しない。新規CheckoutのFlutter呼出0と、Portal経由の全操作が初回正式版として安全であることを混同しない。Portal例外全体を後続で解消するまで提出NO-GOであり、今回安全性未確認の状態だけを機械的に管理不能へ変更しない。

| 状態 | 現行削除処理 |
|---|---|
| active/trialingで期限内・解約予約なし | 警告を出すが「削除へ進む」で回避できる |
| cancel_at_period_endで期限内 | 警告対象外で削除確認へ進む |
| past_due/unpaid/incomplete/未知状態 | 警告対象外 |
| activeでも表示上の期限切れ | 警告対象外 |
| canceled/未契約/billing欠損 | 削除確認へ進む。Stripe正本照合なし |
| billing取得失敗 | catch後に削除確認へ進む |

`settings.dart:92`は`canUsePaidFeatures && !isCancellationScheduled`だけで警告する。`109–112,135`は削除への迂回を認め、`139–143`は取得失敗時に続行する。`BillingStatusRepo.fetchBillingStatus`は通常の`get()`で、server確認を強制していない。

`functions/src/index.ts:1526–1577`の`deleteMyAccountAndData`は認証UIDと確認文字列で削除を実行し、Stripe状態確認/解約をせず`users/{uid}`配下（billing含む）とAuthを削除する。Subscriptionは残り得る。billing正本消失で旧500円の対応確認やWebhook同期が阻害され、トップレベルのCustomer対応・連絡先・outboxは削除対象外。Auth削除後は通知先の解決も止まる。

**必須の独立次タスク**：「契約中ユーザーのアカウント削除」。サーバー正本による削除前確認、trialing/支払未解決/解約予約中の扱い、解約と削除の順序、Webhook/Customer対応/通知/保持削除を設計する。UIだけの禁止やPortalの単純削除で解決した扱いにはしない。この解消まで、アプリ内Portal完全撤去・戦略C版のストア提出/配信はNO-GO。今回はバックエンド・削除処理を再設計せず、該当導線を残す。

## 実装・検証の結果

上記を先に記録してからA/Bを撤去し、C/D/E/GとF例外を維持した。`SubscriptionPlanScreen`のclass名/既存routeは互換のため保持し、画面名を「利用状況」へ変更。購入処理・価格・訴求カードを外し、同一UID/server確認済みの契約状態と21日体験の状態/期限だけを表示する。既存Portalは管理可能な契約にだけ表示し、trial読取り失敗だけで既存管理を失わせない。

機能ガードの再確認は、確認済みのbilling/体験streamを改めて読むだけ。明示的な無料体験開始とは別のcallbackにし、開始中のbuttonを購入遷移へfallbackさせない。起動・UID切替の監視を維持。開始点では復帰時の明示再取得が存在せず、Tabsのresumeは日次記録/スター更新だけだったため、利用状況と機能ガードへread-onlyなresume再購読を追加した。既存のそれ以外のresume処理は変更していない。再取得中やキャッシュだけでは利用を解放せず、期限到達でも閉じる。

### iOS/Android共通の最終文字列分類

185 Dart source、pubspecの27 asset指定、重複を除いた137 asset（4テキストasset）を確認。`createStripeCheckoutSession`、Checkout/purchase URL、新規購入ボタン、500/550円表示、Web購入比較、QR実装は0。プラットフォーム別に購入を残す分岐はない。raster画像のOCR全件確認をしたとは扱わない。

| 残った一致 | 分類/判断 |
|---|---|
| `subscription_plan_screen.dart:115–143`のPortal処理・管理button | F、削除安全性の例外。正式提出ブロッカーとして保持 |
| `settings.dart:99–102`の月額/Stripe・管理案内 | F、削除前の既存警告。価格なし、原文を維持 |
| `settings.dart:1401,1406–1407`のStripe説明 | G、Privacyのデータ処理説明として維持 |
| `billing_status.dart:86`の有料プラン | C、契約状態のlabel。価格/購入CTAではない |
| `app_analytics.dart:186–201`のcheckout名 | 未呼出の既存計測定義、変更しない。新規購入を起動しない |
| `collectible_glyph.dart`のstripePaint/stripes、avatar説明のstriped | 装飾語、課金とは無関係 |
| setup/Home/monitoringの登録する | 飼い主/ペット/飼育環境の通常登録、購入ではない |

`launchUrl`は撤去後9箇所（F Portal1、G非購入8）。新規購入のスキャンはiOS/Android共通でPASSだが、F例外があるため「アプリからPortalを一切開かない戦略Cへ完全適合」とは報告しない。

### ローカル検証の範囲と制約

開始点と同一のpubspec/lock、既存キャッシュ済みFlutter3.47.7/Dart3.13.5で`--no-pub`を使用。Firestore/Auth/Functions/HTTPは合成adapterだけで、既存利用者へ接続していない。実iPhone/Androidへのinstallや実契約管理操作、ストア審査の承認は今回の根拠に含めない。

利用状況画面の25件はactive/trialing/past_due/unpaid/canceled/none、期限内解約予約・正確な期限境界、体験未開始/有効/終了/不明、UID切替・repo交換・再確認・復帰、360px・文字2倍、法務リンク、F Portalの条件を確認した。機能ガードは無料体験未開始を終了と誤表示せず、明示開始条件を保ち、再確認では開始/延長/リセットを行わない。

既存の`record_calendar_navigation_test.dart`はGolden用の日本語font固定SHAが現在Macのfontと一致せず、setUpAllで停止（その後のtearDownAllも未初期化エラー）。`PROJECT_STATUS.md`の過去記録にも同じ既存環境制約がある。font helper/固定SHA/期待画像は変更せず、この系列のGoldenを検証済みとしない。Home/Drawer/Settingsの今回の導線は、別の非Golden操作試験で確認する。

静的解析は変更によるerror/warningなし。Settingsの既存`activeColor`非推奨info6件は開始点と同じ6箇所であり、この撤去と無関係なSDK対応を混ぜず保持する。

最終確認は以下の23ファイル、**271/271件PASS**。個別の実行結果を重複加算していない。元のカレンダーGolden系列の準備/終了2エラーはこのPASS数へ含めず、上記制約として残す。

- 今回の契約/体験/UI：`entitlement_race_test.dart`、`subscription_usage_screen_test.dart`、`strategy_c_deletion_boundary_test.dart`、`strategy_c_navigation_test.dart`、`app_purchase_cta_scan_test.dart`、`initial_trial_gate_state_test.dart`、`billing_subscription_access_test.dart`、`ai_access_failure_test.dart`。
- レポート：`personality_report_screen_test.dart`、`unified_child_report_test.dart`、`personalized_report_actual_view_test.dart`。
- 認証/ペット/AI/Home：`first_ai_monitoring_cta_test.dart`、`ai_text_consent_gate_test.dart`、`ai_text_consent_store_test.dart`、`ai_text_consent_dialog_test.dart`、`onboarding_state_test.dart`、`app_analytics_journey_test.dart`。
- 通知/記録：`notification_settings_service_test.dart`、`notification_payload_test.dart`、`care_action_repo_test.dart`、`care_action_input_test.dart`、`observation_identity_repo_test.dart`、`breeding_environment_model_test.dart`。

非Goldenナビゲーション5件は、実TabsのHome→Drawer→Settings→利用状況を明暗両方、AI期限切れの中立表示/読取再確認、未開始AIの明示開始1回/枠20維持、Drawer→期限切れ記録を確認。外部HTTPと購入/Portal/削除の予期しないFunction呼出を禁止した。Settingsの既知ListTile背景/ink診断だけを既存`owner_nickname_test.dart`と同じ条件で限定記録し、その他の例外はすべてテストへ送る。診断を直した/視覚品質を実機保証したとは扱わない。

変更Dart17ファイルの`flutter analyze --no-pub --no-fatal-infos`はexit0、既存info6件以外の指摘なし。削除本体、billingモデル/Repo、trial Repo、削除Service、バックエンド、pubspec/lock/native設定が開始点と同じことを確認。今回21ファイル（Flutter12・テスト6・文書3）を指定の1コミットへ保存し、配備/実機install/提出/merge/pushせず停止する。
