# Ham Care 認証プロバイダー設定

このアプリはメールアドレス／パスワードに加え、AndroidではGoogle、iOS・macOSではAppleによるログインを表示します。公開前に、各ストア用のFirebaseプロジェクトで次を一度だけ設定します。秘密鍵、クライアントシークレット、審査用アカウントはこのリポジトリへ保存しません。

## Firebase Authentication

1. Firebase Console の **Authentication > Sign-in method** で、Email/Password と Google を有効にする。
2. iOSを配布する場合は Apple も有効にし、Apple Developer の Service ID・Team ID・Key ID・秘密鍵を Firebase Console に登録する。
3. Google Play App Signing の本番署名証明書と、開発用署名証明書の SHA-1 を Firebase の Android アプリへ登録する。
4. Firebase Console から最新の `google-services.json`（Android）と `GoogleService-Info.plist`（iOS）を取得し、各プラットフォームの設定を更新する。現在のローカル設定にGoogle OAuthクライアントが存在するかは、Console側で確認する。

## 動作確認

1. Android実機で「Google で続ける」を選び、新規アカウントと既存メールアドレスの両方を確認する。
2. iPhone実機で「Apple で続ける」を選び、メールアドレスを非公開にした場合も登録・再ログインできることを確認する。
3. メール新規登録で確認メールが届くこと、パスワード再設定メールが届くことを確認する。
4. 既に存在するアカウントへ別の認証方法を連携する場合は、Firebase Authの同一UID維持を確認してから導線を公開する。

## 運用上の注意

- アプリは通知許可を起動・ログイン時には求めず、設定の「健康状態の通知」をONにする操作でのみ求める。
- Google／Appleログインで作成されたアカウントも、メール登録と同じ利用規約・プライバシーポリシーへの同意記録をFirestoreへ保存する。
- Firebase Consoleの有効化・Apple Developer設定・署名証明書登録は外部サービスの操作であり、ソースコードだけでは完了しない。
