# Webアカウント削除申請・本人確認の運用案（2026-11-21）

開始点は承認済み `6940aec7ca6d`。今回のページは、ログイン不要の申請窓口を提供するもの。メール送信だけで削除完了にならず、新しい削除APIや運営用実行ツールを実装・配備したものでもない。本番公開・実ユーザー削除・Play Console設定変更は行わない。

## Google Playとの対応

[Google公式のアカウント削除要件](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en) は、アプリ外からの申請経路としてカスタマーサービスメールも認める。削除申請経路が目立ち、ストアと同じアプリ/運営者名が分かり、アプリの再インストールへ戻さず申請できることが条件。申請ページが存在するだけで、関連データ削除・本人確認・処理完了まで運用済みと判断しない。

本番公開後に登録する候補URLは `https://hamster-breeding-app.web.app/account-deletion/`。期限付きPreview URLは登録しない。本番URLの公開・匿名閲覧・メール/コピー・リンク・削除運用の確認後、Play Consoleの対象HamCare→ポリシー/プログラム→アプリのコンテンツ→データセーフティ→データの削除に進み、実装と整合する回答および削除申請URLを登録・保存して確認する。Consoleの名称は変更され得るため、実施時に対象の「データの削除」を確認する。今回この操作はしない。

## 現行機能の監査結果

- `public/assets/account-service.mjs` はFirebase SDKの既存メール/Google/Appleログインを提供し、fresh token claimsと同じUIDのprovider情報を `account-identity.mjs` で確認する。Appleはメールの有無だけで本人と認定せず、Apple provider identityを照合する。画面はマスク済み連絡先・状態を表示し、生のtokenをサポートへ送る設計ではない。
- このログインは、サポートメールの申請者と認証UIDを結び付ける受付票・本人確認確認画面・運営向け検証記録を作らない。申請メールとブラウザのログインが同一人物であることを、運営が安全に確認できる機能は未実装。
- `functions/src/index.ts` の `deleteMyAccountAndData` はFirebase Callableの `req.auth.uid` だけを対象にする。メール本文や任意のclient UIDを指定して運営が他人を削除するAPIではない。署名済みID Tokenを本人からメールで受け取って代行する運用は禁止する。
- `functions/src/accountDeletion.ts` の `runAccountDeletion` はUIDごとの要求・排他・Stripe停止確認・既存削除の再利用を行う内部処理である。安全版はコード/Mock/Emulatorまでの承認記録で、運営者用の受付・承認・実行ツールや本番配備は未完了。
- Firebase ConsoleでAuthだけを削除したり、billingを消したり、停止確認フラグを手入力して通したりすると安全設計を迂回する。サポート削除の方法として採用しない。

## メール受付と本人確認案

### 今回公開する申請方法

窓口は `gotainu@gmail.com`、件名は `【HamCare】アカウント削除申請`。ログイン、アプリ再インストール、登録メールからの送信、個人の実メールの提出を申請条件にしない。Apple非公開リレーアドレスや、Authメール未設定の利用者も、本人が受信できる連絡先から申し出られる。

初回メールでは削除を希望する旨と、必要に応じて普段のログイン方法だけで受け付ける。パスワード・Apple/Google等の確認コード・Firebase ID Token・authorization codeは要求しない。氏名/住所/カード情報等の不要な個人情報も集めない。メール本文を受け取っただけで削除・解約済みと返信しない。

### 確認できたことにしてはいけない資料

送信元メール、署名、ニックネーム、ペット名、画面のスクリーンショット、申告されたFirebase UID、利用履歴に関する回答だけでは、認証済み所有者であることの証明にならない。UIDは対象識別子であって秘密の認証情報ではない。メール文字列で別UIDを統合したり、特定したUIDへデータ移行したりしない。

### 必要な最小追加対応（今回は未実装）

1. 運営が受付番号を作り、返信用の本人確認リンクを送る。リンクは短期限・1回限りのopaqueな申請参照だけを含み、UID・メール・ID TokenをURLへ入れない。
2. 利用者が既存のHamCare Web認証を行い、ログイン済みの同一UIDで、その申請の削除意思と、有料契約があれば停止・残期間利用終了の条件を明示確認する。認証情報や確認コードをメールに貼らせない。
3. サーバー側で認証UIDと申請番号を結び付けた確認記録を作り、運営がそれを読めるようにする。任意UIDを本文/フォームから信用しない。確認リンクの盗用・使い回し・他UIDへの利用を拒否する。
4. 運営者のアクセス制限・操作記録・対象確認を備えた最小の実行経路で、既存 `runAccountDeletion` を再利用する。前工程のStripe停止・再試行・削除フェンス・データ/Auth削除を迂回せず、`ok:true`だけを完了とする。今回新規実行API/runnerは作成しない。

メール/Google/Appleの全方式で同じFirebase UID正本の確認を使う。AuthメールがないApple利用者にもApple認証で対応し、連絡用メールとFirebase契約UIDを同一視しない。Appleリレーへの実配送は既存残件で、届かなければ本人の希望する受信可能な連絡先を案内するが、個人実メールの提出を必須にしない。

元の認証手段へアクセスできない場合の回復・例外本人確認は、現行機能だけでは安全に完結できると確認していない。必要最小限の証拠・目的・保持を別途定め、確認できるまで破壊的操作を行わない。アプリ再インストールを本人確認の必須条件にしない。

## 削除・保持の説明と実装根拠

| 区分 | 現行コードでの扱い | 公開表示上の注意 |
|---|---|---|
| Auth、プロフィール、ペット、飼育/温湿度/AI/通知/体験等のユーザー配下データ | `deleteDocumentDeep(users/{uid})` とAuth削除を再利用 | 本人確認・安全な処理完了後の対象として説明する |
| SwitchBotの既存保存領域 | `switchbot_users/{uid}` 配下を再帰削除 | 外部SwitchBotアカウント自体の削除とは言わない |
| 補完連絡先 | 本人 `billing_contacts/{uid}` を削除 | Stripeの会計記録と区別する |
| ペット画像 | 固定 `hamster_images/{uid}-main_pet.jpg` を削除、404許容 | Storageの全bucket/全バックアップを消すとは言わない |
| Stripe Customer/Subscription/Invoice/支払履歴 | 会計記録を一括削除しない。継続請求停止を照合してからAuthを削除 | 保存が必要な取引情報を保持する場合と理由を記載する |
| 削除フェンス、課金対応/Session情報、Webhook receipt、通知outbox | トップレベル情報を一括削除しない | 不正利用・復活防止・請求照合・障害/紛争対応用記録として保持の可能性を説明 |
| Preview独立連絡先/challenge・外部メール/ログ/分析/バックアップ | 既存再帰削除だけで全て消えると確認していない | 全件・即時・完全削除、固定期間後の自動削除を保証しない |

根拠は `public/privacy/index.html` §6、`functions/src/index.ts` の `deleteData`、`accountDeletion.ts`、`webBillingWebhookStore.ts`、`billingNotificationStore.ts`。内部管理情報や会計記録の具体的な保存期間、外部委託先への削除要求、Preview残存情報の手順は公開前に運営方針と法務表示を整合する。未確定の保存日数を作らない。

## Apple失効成功後にStripe停止が失敗した場合

現行の承認済み処理は、削除確認→同一UID Apple再認証→code即時失効→既存CallableのStripe停止→データ/Auth削除。Apple OAuth失効そのものをFirebase Auth削除・アカウント削除完了とは扱わない。

- Callable受信前に中断した場合、削除要求はまだサーバーへ保存されていない。同じFirebaseセッションがあれば本人が再試行する。再ログインが必要な場合は、元と同じAppleアカウント/連携を使い同じFirebase UIDであることを確認する。違うUIDを自動統合/移行しない。
- Callable受信後、Stripe停止未確認ならAuthを削除せず、永続要求がretryable/manual_review等に残る。worker/運営確認で既存要求を再開する。Apple codeを保存・再利用せず、必要なら新たな再認証か手動解除案内を用いる。
- `billingStopped=true`後のFirebase削除失敗は、停止済みの証跡を保持して既存cleanupを再試行する。新規課金・再キャンセル・UID変更で回避しない。
- **実機E2Eは未確認**。失効直後もFirebaseセッションが維持されるか、同じAppleアカウントの再ログインで同じFirebase UIDへ復帰するか、未完了要求へ再開できるかは専用アカウントの事前承認後に検証する。既存Mockの合格を実Appleでの確認としない。今回は削除コードを変更しない。
- Webメール経由でApple tokenを取得できない場合も削除を不当に拒否せず、本人確認後のデータ削除とApple設定からの手動解除を案内する。[Apple TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple)

## 公開前の残件

ページ実装・Preview確認と、本人確認/削除実行を運用できる状態を分ける。正式な受付返信・処理状況/完了通知・合理的な対応目安、上記ticketと認証UIDの結合、運営用の安全な実行経路、本番安全版の配備、手動確認案件の監視、保存/削除方針の整合、専用Apple失効失敗E2Eが未完了。これらを運用済みと表示しない。

Google Playへは、本人確認・処理運用と本番公開の準備後に正式URLを登録する。今回はPreviewの申請窓口と説明を準備する段階であり、Google Play審査への適合承認を保証しない。

## 今回の実装・Preview確認

- 既存 `/account-deletion/` の古い「登録メールから申請」「先にPortalで解約」を更新。現行outlineロゴ、星空、すりガラス、既存のbrand/landing tokensを使用する。新規API/認証/保存を追加しない。
- 公開窓口、件名入りmailto、コピーbutton、aria-liveの成功/失敗表示、メールアプリが開かない場合の手動コピーを用意。本文へアカウント情報を自動埋込みせず、メールを送信していない。Apple Relay/Authメール未設定でも受信可能な連絡先から申請可能。新規購入/Portal/価格CTAはページ内にない。
- LPフッターに削除リンクを追加。Privacyの保存/削除節とfooter、Supportの削除案内からも同じパスへ到達するようsourceを更新した。Privacy/Supportの改定案をPreviewへ広く公開せず、新ページは既存canonical live法務ページへリンクする。これらのsource改定は今回live未反映。
- 既存 `firebase.preview.json` とAuth CSPを不変とし、Hostingだけの `firebase.account-deletion-preview.json` で同じchannelへ削除ページだけ追加。Functions・rewrites・Auth許可ドメイン変更なし。ページCSPはself script/css、connect/form/frame禁止、no-referrer/noindex。
- Preview：[削除申請ページ](https://hamster-breeding-app--web-first-task1-lco08m60.web.app/account-deletion/)。channel `web-first-task1`、version `037676ed8b90b69f`、期限 **2026-11-28 21:48 JST**。本番liveは開始前後とも `2365135bf558c278` でreleaseも同一。
- 配信10リソースHTTP200・ローカルSHA一致。Previewの対象外Privacy/Support/Terms/非公開provenanceは404を維持し、ページ内のcanonical live Privacy/Support/Terms3URLはHTTP200。新ページのCSP/no-referrer/noindexを実HTTPで確認。
- CUAの新規IABでログインなしの実Previewを確認。CSS viewport 360/390px、本文16px、横スクロールなし、copy操作の成功status、44px以上のcopy/mail領域、LPフッター→新ページを確認。console error/warnなし。メールソフト起動・実メール送信・実ユーザー認証・削除は行わない。Viewport overrideを戻し、ローカルHTTP serverも停止した。
- 確認画像は今回作成のartifact `artifacts/web-account-deletion-20261121/preview-mobile.jpg` に保存（worktree外、個人データなし）。物理iPhone/Androidの実機確認とは区別する。

## 試験結果と差分境界

- NodeのWeb pure試験14ファイル **454/454件PASS**。今回のページ/コピー8件とPreview/導線3件を含む。メール件名、JSなしのmailto/表示アドレス、clipboard拒否/非対応、二重クリック、非認証・非保存、秘密情報なし、購入誘導なしを確認。
- LP静的 **86/86 PASS**、brand静的 **178/178 PASS**。既存のbrand構造固定試験には今回必要なfooterリンク1個だけを厳密例外として加え、それ以外の構造・ロゴ・背景・機能要素の保護を維持した。
- 旧 `check_web_account.py` は **168/171**。3件は既承認のサーバーApple policyの共通モジュール化・`functions/src/index.ts`変更と古い固定文字列/旧commit比較が整合しない既存監査条件。今回変更していない `preview-functions/src/auth-policy.ts`、`functions/src/index.ts`、監査scriptが対象であることを開始HEADとの比較で確認。認証/削除処理やこの旧監査を、本タスクで書き換えて合格扱いにしない。旧監査の更新は別途残件。
- Flutter/Functions/Stripe/既存Auth/Firestore Rules/Storage Rules/SDK/lock/mainを変更しない。本番Firestore・Stripe・契約・Auth/Storage書込み0、ユーザー削除0、Play Console/Apple設定変更0、live Hosting公開0。Previewだけを1回配備。専用branchの今回差分だけを指定の1コミットへ保存する。
