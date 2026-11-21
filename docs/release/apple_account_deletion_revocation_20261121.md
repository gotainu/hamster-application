# Apple認可失効とアカウント削除（2026-11-21）

開始点は承認済み `e1fe0524dbb9`。同じ `feature/web-first-stripe-checkout` の専用worktreeで実施、開始時clean。有料契約者0人・無料テスターのみという運営者確認を維持。実アカウント削除・実Apple認可失効は行わない。

## 既存構成とAPI

Flutterの `lib/screens/auth.dart` は `FirebaseAuth.signInWithProvider(AppleAuthProvider())` でログインする。削除側にはApple再認証・認可失効がなかった。既存削除はSettingsの確認→`deleteMyAccountAndData`→サーバーのStripe停止確認→既存Firestore/Storage/Auth削除→ローカル同意消去・signOutで、サーバーの削除フェンス・再試行を含む。[前工程](account_deletion_billing_safety_20261121.md)を維持する。

lockの `firebase_auth 6.0.0`、platform interface `8.0.0`、Web `6.0.0` をそのまま使用。既存キャッシュ内の `FirebaseAuth.revokeTokenWithAuthorizationCode()`、`User.reauthenticateWithProvider()`、`AdditionalUserInfo.authorizationCode` とiOS実装を確認した。SDK/依存/native設定は更新しない。[Firebase公式の失効API説明](https://firebase.google.com/docs/auth/flutter/federated-auth#revoke_apple_auth_tokens)も照合。

既存SDKの自動失効APIはiOS/macOS向けで、Android/Webでは非対応。非対応環境で無意味な再認証を要求せず手動案内へ進む。複数provider連携は最新のログイン方式でなく `providerData` の `apple.com` の有無で判定し、メール/GoogleのみならApple処理を行わない。

Webは同じFirebase AuthのApple Providerを使用する。既存の設定記録はServices ID `com.gotainu.hamster.web` と既存Primary App IDの関連付け、固定 `https://hamster-breeding-app.firebaseapp.com/__/auth/handler` を示す。今回Service ID/Key/Provider/handler/公開Webは照会・変更していない。過去のWeb/native UID一致証拠は維持し、新しい実認証確認と混同しない。

## 採用した順序

1. 既存の削除内容・有料時だけの停止条件を表示し、`DELETE_MY_ACCOUNT` を確認。
2. 同一UIDの現在のserver billingを再確認。有料説明が未確認のまま状態が変わったら同意をやり直す。
3. Apple連携がある場合、既存Userの `reauthenticateWithProvider(AppleAuthProvider())` で再認証。`signIn`/`link`/メール統合は使わない。元UID、返却UserのUID、現在UserのUIDと、既知のApple subjectを照合し、不一致は必ず停止。
4. 新しいauthorization codeを直ちに `FirebaseAuth.revokeTokenWithAuthorizationCode()` へ渡す。30秒で完了確認を区切り、コードは操作中のメモリだけで扱い、返却・保存・ログ・削除Callable送信をしない。
5. 同じFirebase UIDのまま、変更していない既存削除Callableを呼ぶ。サーバーだけがStripe停止を確認し、その後にデータ/Authを削除する。
6. `ok:true` だけを完了扱いとし、既存のローカル同意消去・signOut・完了表示へ進む。Apple失効だけでは削除完了にしない。

**順序調整の根拠**：Apple codeは1回限り・5分有効で、既存Stripe削除はCheckout待機やworker再試行を伴い得る。codeを待機中に保管する方式は採用せず、取得直後に消費する。Apple OAuth失効APIはFirebase Auth削除の代わりではない。Stripe失敗ならアカウント削除は未完了のままで、再試行時は必要に応じて再認証して新しいcodeを得る。この順序は公式APIの性質と既存の待機仕様に基づく実装上の判断。[Appleのcode要件](https://developer.apple.com/documentation/SigninwithAppleRESTAPI/Generate-and-validate-tokens?changes=_3&language=objc)

Apple失効後からCallable受信前に端末が終了した場合、アカウント削除はまだ受け付けていない。完了と表示せず、本人が同じUIDで再試行する。Callable受信後の復旧は前工程の永続要求とworkerが担う。今回新しいApple用のサーバーphaseや平文トークン保存先を追加しない。

## 失敗と手動解除

Apple再認証キャンセル、code欠損、失効エラー/タイムアウト、非対応環境では「自動解除の完了を確認できない」と案内。「戻る」または「削除を続ける」を本人が選ぶ。自動で削除要求を送らず、削除の永久拒否にも使わない。初期のApple provider識別子が欠損している場合も、認証済みFirebase UIDを維持して手動案内へ回す。既知のApple subjectが途中で変わった場合はこの例外を適用しない。

`user-mismatch`、無効/期限切れ認証、disabled等の本人確認異常は手動fallbackと混同せず停止する。別UIDの再認証・自動統合・移行は行わない。

手動案内は、削除後にiPhone「設定」→自分の名前→「Appleでサインイン」→「Ham Care」が表示される場合に解除する方法と、Apple Accountの「サインインとセキュリティ」→「Appleでサインイン」を提示する。購入/Portalへのリンクは追加しない。

[Apple TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple)の、token/codeがなくても削除要求を履行し手動解除へ案内する条件と照合。[Appleの手動解除手順](https://support.apple.com/102571)

## 検証・保護

- 関連Flutter26ファイル **385/385件PASS**。新規service43件は再認証/失効成功、キャンセル、code欠損、失効失敗/30秒timeout、非対応環境、非Apple/複数provider、初期subject欠損、既知subject変更、別UID・無効認証の拒否、再試行の新しいcodeを検証。
- 実Settings＋既存Callable wrapperの回帰では、削除確認前にApple処理しないこと、失効確認→既存有料要求の順序、手動継続/戻る、別UID拒否、Stripe/Firebase失敗を表す未完了応答時の非signOut・非完了と再試行、無料/有料、二重押しを確認。既存21日体験・entitlement・購入/Portal導線0の試験も含む。
- 変更/追加4 Dartファイルのanalyzeは新規指摘0、既存Settings activeColor非推奨info6件のみ（exit0）。diff check PASS。既存カレンダーGoldenのfont SHA不一致は維持し、SDK/helper/期待画像を変えない。
- Functions・前工程のStripe停止/フェンス/worker/深い削除・Web/native設定・依存が開始HEADからbyte単位で不変であることを確認した。前工程のサーバーMock/Emulator試験は今回の385件へ加算しない。

実Apple認証や失効・実アカウント削除は行わない。専用アカウントの実Apple E2Eは事前承認後の残件。iOS/macOSの実SDKでの失効、Android手動案内、失効直後のFirebaseセッション維持とStripe失敗後の再認証は、Mockでの確認と実機確認を区別する。

Functions、Stripe停止処理、Invoice、削除フェンス、worker、Web購入/Portal、21日体験、billing評価、Auth Provider/Apple Developer/ストア設定、pubspec/lockを変更しない。本番Stripe/Firestore/Auth/Storage/Apple認可への実操作0、本番デプロイ・live Hosting・新ビルド配信・main merge/push0。Google Play Web削除導線は次の独立タスクとして実装に進めるが、このタスクでは作成しない。

変更ファイルは `lib/screens/settings.dart`、新規 `lib/services/apple_account_deletion_service.dart`、`test/settings_account_deletion_test.dart`、新規 `test/apple_account_deletion_service_test.dart`、`PROJECT_STATUS.md`、本書、`account_deletion_billing_safety_20261121.md`、`web_billing_live_cutover_runbook_ja.md` の8件のみ。
