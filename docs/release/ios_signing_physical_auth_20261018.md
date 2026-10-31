# HamCare iOS署名・実機認証準備（2026-10-18）

2026-10-26現在：下記10/25生成の指定同意対応IPAを再生成せず使用し、Transporterで9:50のデリバリ成功、App Store Connectで処理後のTestFlight内部配布PASS。輸出申告は本人承認後に「標準暗号（OS外TLSを含む）／独自暗号なし／フランス配布なし」で保存済み。本人のみの内部グループ1テスター／1ビルドがTesting。本人がTestFlightからインストールし、Home表示・ログイン・既存飼育記録の保持をPASS確認。同意説明表示・「送信しない」取消後の入力保持・設定の同意撤回項目表示は本人PASS。設定確認ダイアログの開閉／取消は未確認、実同意承諾・保存済同意の実撤回・同意対応版での新実AIは未実施。Release DeviceCheckはTestFlight更新時刻に対応する交換HTTP200×1・対象iOS AppIDのFirestore VALID412・現登録true／旧falseを照合し、サーバー計測による実動作PASS。端末SDK callback／token／個別有効期限は直接未観測。根拠は正本と既存auditの `asc-owner-internal-build2-testing.png`。以下の生成工程・当時未実施事項は履歴として保持する。

2026-10-25同意対応候補の生成工程（履歴）：通常文字AI同意を局所実装し限定26件PASS後、通常lib/main.dartをXcode27.1／恒久Flutter3.47.7・固定lockで新Release Archiveへビルドし、既存Distribution証明書／App Store ProfileでIPA export PASS。同工程で生成した提出対象は`/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/hamcare-1.0.1-build2-consent-appstore-20261025.ipa`（107,026,058bytes、SHA256 `67a7305d7934adfa0565e1ca6375bd101a16b80dbb274019e4c268483ad8695e`）。Archive ZIPは`/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/Runner-consent-development-archive-20261025.zip`（SHA256 `90ced1a78a539f204e22d29c613ffb60f61a001f8e988d7d90c52c24c529c202`）。codesign strict／ZIP／get-task-allow=false／Apple Default／APNs production／Archiveとのコード・資産一致を確認。前回の同意前IPA／Archiveは以下に履歴として保持する。この生成工程での新資格発行、端末上書き、upload・審査送信・実AIは0。10/25のDeviceCheck限定確認は既存ログ0件、SDK呼出し前のSIGSTOPで中断・resume指定detach済み。10/26の段階別再開結果は下記の診断履歴に記録し、その時点では実attestation未確認だった。後続のTestFlight版サーバー計測によるPASSは下記の限定結果を参照する。App Check強制設定・認証系を変更していない。

2026-10-25同意実装前の配布準備（履歴）：本人作成のApple Distribution証明書と、明示承認した同一Team／App IDのApp Store Profileで、既存Release ArchiveからIPA export PASS（再ビルドなし）。`/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/artifacts/hamcare-1.0.1-build2-appstore-20261025.ipa`、SHA256 3f2b61b017e93c451b5c96e10447cea82feaea987445cb23665f2c447c2cfd48。get-task-allow=false、Apple／APNs権限、codesign strict／ZIP／元コード・資産一致PASS。証拠は既存audit/appstore-ipa-result-20261025.json。端末上書き／upload／審査送信なし。以下のDevelopment Archiveまでの記載は前段の履歴であり、現在の配布署名待ちへ戻さない。当時の通常AI同意不足は、本書先頭の最新工程で局所実装・限定検証と最終候補再生成まで完了。この配布準備段階ではDeviceCheck実attestationは未確認だった。後続のサーバー計測結果とは分離する。

10/25後続の公開準備（履歴）：既存成功Xcode27.1／恒久Flutter3.47.7・固定lockを隔離再利用し、通常lib/main.dartのRelease Archive PASS。Development署名（get-task-allow=true）であり、この段階ではDistribution export／IPA／uploadは未実施。既存staging `ios-device-runtime-20261019/artifacts/Runner-development-archive-20261025.zip`（157,930,706bytes、SHA256 2c0931038ef0649ec137fd94c32cbd1443336a4389d283c4eac3dec0a1e770ae）、同audit/release-archive-result-20261025.jsonに保存。source／native／locks／SDKは保護し、既存iPhone Releaseを上書きしていない。App Store Connect ID6826783734／1.0.1手動公開・日本のみ・無料・掲載原稿／Privacy URL保存PASS。配布署名・審査は別残件。

2026-10-25文書照合：進捗の正本は[PROJECT_STATUS.md](../../PROJECT_STATUS.md)の「検証済みの状態」「タスク一覧」。本書の10/18実行ログ・当時の判断は履歴として残す。この文書照合段階では環境の再照会・ビルド・実機操作・テスト再実行・本番変更は行っていない。同日後続の限定実行結果は次段落と正本へ追記する。

10/18時点の最小環境の訂正（履歴）：当時の再確認でもMacはmacOS14.8.9／23J631、iPhoneはiOS26.5.1／23F81。Xcode26.3はmacOS Sequoia15.6以降に対応するため、macOS26.2は必須ではない。最低候補はmacOS15.6＋Xcode26.3で、現在のOSでは導入できない。OS更新は承認待ち。26.3で当該iPhoneのvariantをmountできるかは導入後の実検証事項とする。

## 結果

現在：Xcode27.1／恒久Flutter3.47.7で元 `ios/Runner.xcworkspace` のGUI⌘Rによる通常版Debug導入・起動PASS。その後同Bundle／Team／Profile・Apple entitlement・キーチェーン整合のRelease AOTを削除なしで上書きし、本人がHome起動・ログイン保持をPASS確認。メールとAppleサインインは通常版で本人確認済み。Googleの実OAuth・復帰・Homeと終了／再起動保持は現Releaseで本人PASS。以下は10/18当時の署名・接続結果。

Apple Developer側のApp ID `com.gotainu.hamster`、Sign in with Apple有効、Primary App ID、新規約同意はユーザー確認済み。Developer管理画面の追加変更やProfile再発行は実施していない。

Macの既存開発証明書・Appleログイン対応Profile・接続iPhoneの登録は整合する。Xcode表示用のCapability metadataだけを通常候補へ追加する。通常版と隔離probeの署名付きReleaseビルドは終了0、成果物の署名／Apple entitlement／実Profile照合もPASS。

実機のApple／Google承認とFirebase最終ログインは**未実施**。開発者モードを有効にしても、Xcode16.2の実機サポートにiPhone17eのvariantがなく、実機操作が停止した。公式の実機サポート部品更新を1回実施し成功したが、再確認でも同じエラーが残った。macOS・Xcode本体の更新、非公式DDI差し替えは行っていない。

## 署名・Entitlements・Profile

| 項目 | 確認結果 |
| --- | --- |
| Bundle ID | Debug／Release／Profileともcom.gotainu.hamster。Firebase iOS設定とも一致。 |
| Team／署名 | 既存Team 3SA77V3SM7、Automatic。Macに有効なApple Development署名IDが1件あり、Profile内の公開証明書と一致。秘密鍵の書き出しなし。 |
| Entitlements | 全構成がRunner/Runner.entitlementsを参照。applesignin=[Default]、APNs development、App AttestはDebug development／Release・Profile production。既存値不変。 |
| 使用可能Profile | iOS Team Provisioning Profile: com.gotainu.hamster。2027-09-24まで有効、Team/App ID一致、Appleログイン権限あり、今回iPhone登録あり。App Attestの両環境を許可。 |
| 古いProfile | Hamster Breeding App DevelopmentにはApple権限なし。同じBundle IDでも、この古いProfileを選ばない。削除や再発行はしない。 |
| Xcode表示 | SystemCapabilitiesにSign in with Appleの表示metadataがなかったため、com.apple.SignInWithApple enabled=1の3行だけ追加。entitlement自体は既存。metadata欠落だけを署名不良の原因とは断定しない。 |

Development Profileによる署名とApp Store配布用署名は別。今回の結果をストア提出・配布Profileの確認完了とは扱わない。

## 接続済みiPhoneとXcode

現在はiPhone17e／iOS26.5.1で実機接続・導入・起動済み。以下のCoreDeviceError12040／MissingVariantとOS更新待ちは10/18の履歴であり、現在の停止理由ではない。macOS27.0.1への更新は本人報告、今回のOS実測はしていない。

- iPhone 17e、iOS26.5.1。Macと有線pairing済み。ユーザーがDeveloper Modeを有効にし、実APIでもenabledを確認した。
- 実機アプリ一覧の取得でCoreDeviceError12040、DDI mountの`kAMDMobileImageMounterPersonalizedBundleMissingVariantError`が発生した。iPhone用variantがないことが具体的な停止理由。
- Apple公式の`xcodebuild -runFirstLaunch -checkForNewerComponents`を選択Xcode16.2に限定して1回実行。Install Succeeded／終了0、DDI更新を確認。以後の接続確認1回も同じMissingVariantだったため、繰返し更新や手動差替えへ広げない。
- SDK18.2という番号だけから新しいiOS実機が使えないと推測していない。Apple資料のdevice supportとSDKの区別、および上記実エラーに基づく。[Xcode16.2公式資料](https://developer.apple.com/documentation/xcode-release-notes/xcode-16_2-release-notes)、[公式実機サポート更新](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components#Download-and-install-new-hardware-support-in-between-Xcode-releases)
- 限定再確認でも現MacはmacOS14.8.9／23J631。最小更新候補のXcode26.3はmacOS Sequoia15.6以降に対応し、同梱SDK26.2と実機Device Support iOS15以降は別の条件。iPhoneのiOS26.5.1だけを理由にSDK26.5／macOS26.2を必須とした前回答は訂正する。現在OSでは26.3を導入できないため、ユーザー承認後のOS更新まで止める。新hardwareの実接続成功は未検証。[Appleの要件表](https://developer.apple.com/xcode/system-requirements)、[Xcode26.3公式資料](https://developer.apple.com/documentation/xcode-release-notes/xcode-26_3-release-notes)

## 本番を書き換えない認証確認

通常のAuthScreenは、新規ユーザーなら同意内容をFirestoreへ保存する。通常MyAppはログイン後に通知トークンを保存し、Homeのcallableが起動する。また新規Firebase Authユーザーは既存登録triggerを発火し得る。したがって今回は通常アプリからの本番ログインを実行しない。

隔離コピーに、本番Firebaseへ接続しない認証専用画面を用意した。Googleは既存GoogleSignInのinitialize／authenticateまで、AppleはAuthenticationServicesのネイティブ承認まで。Firebase credential交換、Firestore、Functions、AI、Stripeは呼び出さない。Google Client ID／URL Scheme、Bundle ID、署名・entitlementは対象アプリと同じ。Firebase接続用plist値はprobeから取り除き、Analytics／FCM自動初期化もprobeだけ無効にした。認証情報の中身・個人情報を独自ログへ出さず、状態／存在booleanだけを画面へ返す。SDK固有の端末内セッション保持とは区別する。

この確認で将来PASSにできる範囲は各プロバイダの承認・アプリ復帰まで。Firebase最終ログインは、通常アプリの自動書込みをどう扱うか決めて別途確認する。今回probeは端末へ入っておらず、各OAuthは未実施。Face ID／パスコード／二段階認証の本人操作が必要になった際だけユーザーへ引き継ぐ。

## 2026-10-26 TestFlight版DeviceCheck：サーバー計測による実動作PASS

現在のTestFlight版 `com.gotainu.hamster`／1.0.1（2）について、本人更新確認10:09:51 JSTと、以下の既存サーバー計測をread-onlyで照合した。SDK前のデバッガ停止をDeviceCheck失敗と扱わず、今回の**最小実動作はサーバー計測に基づくPASS**とする。端末のSDK callback・token・個別有効期限を直接読み取ったPASSとは区別する。

| 根拠 | 実値／確認範囲 |
| --- | --- |
| DeviceCheck交換 | `serviceruntime.googleapis.com/api/request_count`、`google.firebase.appcheck.v1.TokenExchangeService.ExchangeDeviceCheckToken`、HTTP200／grpc0が1件。10:09:07.001〜10:10:07 JSTの区間で、本人TestFlight更新確認と同じ分。照会した同期間にExchangeDebugToken seriesなし |
| 対象アプリの実検証 | `firebaseappcheck.googleapis.com/services/verification_count` を現iOS AppID `1:797691641198:ios:8742688c983e31766b557f` へ限定。Firestoreのsecurity=VALID／result=ALLOWが10:09〜10:31 JSTの12区間、計412件。これはAI利用回数ではない |
| 現iOS登録 | DeviceCheckConfig GETが200、対象name一致、TTL3600s、`privateKeySet=true` |
| 旧iOS登録の切分け | 旧 `com.example.hamsterProject` のConfig GETも200、TTL3600s、`privateKeySet=false`（protobufのfalse既定でfield省略）。旧AppIDの同期間verification seriesは0。旧登録・アプリは削除／変更していない |

交換methodの計測はproject単位でAppID／端末ラベルを持たず、AppID別VALIDはprovider／端末を直接識別しない。そのため、現在TestFlight版の更新分、現アプリの検証成功、現登録true／旧登録falseを組み合わせてRelease経路の実成功を評価した。個体を識別するSDK callback、raw token、token単体のexpiryは未観測のままで、設定TTL3600sを取得tokenの実有効期限とは扱わない。API method計測には最大1800秒の取込遅延があり、412件は照会時点で観測できた件数。監査／RAGログの該当0件を実失敗としたり、過去Debug版のVALIDだけを根拠にしたりしていない。[公式のApp Check計測](https://firebase.google.com/docs/app-check/monitor-metrics)、[計測ラベル](https://docs.cloud.google.com/monitoring/api/metrics_gcp_d_h#firebaseappcheck)、[登録booleanの定義](https://firebase.google.com/docs/reference/appcheck/rest/v1/projects.apps.deviceCheckConfig)。

今回の確認は既存計測・既存登録metadataの読み取りだけ。新しいattach／SDK getToken／forceRefresh／AI／Auth／trial／同意grant・revokeは0。現TestFlight版の上書き・再署名・診断版導入、App Check強制設定・本番ログ設定・認証方式の変更も0。管理API初回403は既存の割当先ヘッダ指定で200へ解消し、登録boolean取得時の一時DNSエラーも同じread-only GETの再試行で解消した。これらをDeviceCheckの失敗とはしない。十分な正の証拠を得た後の追加計測は行わない。

永続証拠は既存 `/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/audit/` の `devicecheck-testflight-readonly-final-20261026.json`（判定・限界・根拠一覧）、`devicecheck-testflight-monitoring-initial-20261026.json`（現AppIDのVALID412）、`devicecheck-testflight-provider-metrics-20261026.json`（DeviceCheck200×1）、`devicecheck-testflight-private-key-set-booleans-20261026.json`（現true／旧false）、`devicecheck-testflight-app-config-quota-header-20261026.json`、`devicecheck-testflight-legacy-app-exclusion-20261026.json`。既存ログ0件・管理API初回403の安全記録も同auditへ保存し、App Checkの生token・秘密鍵・相談本文は取得／保存／表示していない。

## 2026-10-26 Release DeviceCheckの最小実機確認（TestFlight更新前の診断履歴）

既存Development署名Release（通常 `com.gotainu.hamster`、1.0.1／build2）だけを通常起動し、同一アプリの停止metadataとSDK前のデバッガ式を段階別に確認した。再ビルド・再署名・インストール・元コード／認証方式／App Check強制設定の変更は0。端末のRelease・ログイン・データを維持し、診断によるAI／Auth／trialの明示呼出しとApp Check SDK強制取得はすべて0。通常起動に伴う既存バックグラウンド通信まで0とは断定しない。

| 保存時刻（UTC、JSTは＋9時間） | SDK前の確認結果 | 終了状態 |
| --- | --- | --- |
| 10/26 00:18:41 | ObjC++／AllowJIT=falseの純定数 `1+1` とmodule importがPASS。続くAllowJIT=trueのBundle一致booleanも1でPASS。通常StopIDは1のまま、式評価を含むStopIDは1→2 | runningへresume後、後続SDK入力は実行前に止まり、resume指定detach・セッション終了0を確認。SDK取得0 |
| 10/26 00:22:01 | 純定数・module importは再びPASS。同じBundle一致booleanのJIT式が `Expression execution was interrupted: signal SIGSTOP` で中断し、評価前の状態へ巻き戻った。通常StopIDは1のまま、式評価を含むStopIDは1→3 | detach成功・detached。provider読取り／App Check SDK取得へ到達せず0 |

attach直後は両方ともthread 1のSIGSTOP（signal 17）、StopID 1で、既存のsignal policyはstop／notify／suppressがtrue。公開イベントを排出後もpending eventは空で、policyは変更していない。前回10/25のimportとBundleをまとめた式での中断から、今回は純定数・import・Bundleを分け、**確定した停止箇所をApp Check SDK前のデバッガ式実行へ切り分けた**。同じ非SDK JIT式が一度は成功したため、ReleaseのJITが常に禁止される、DeviceCheckが失敗した、未実装である、という結論にはしない。SIGSTOPの発生元・前回中断の根本理由は一意に特定していない。途中の診断scriptの未対応 `SetExecutionPolicy` によるAttributeErrorは端末／SDK失敗と分離し、利用可能APIだけに直してから上表を実行した。

00:55:44 UTC開始の最終限定確認では、本人が既存HamCareを開き、USB・ロック解除・画面点灯を維持した状態で、公式read-onlyのlockStateが `passcodeRequired=false`／`unlockedSinceBoot=true`、既存Release実体と一致するRunnerが1件・PID9221であることを直前照合した。attachコマンド1回はOS側で `Not allowed to attach to process`（consoleのdebugserver理由を参照する案内）と拒否され、安定したstopped状態へ到達しなかった。従って予定したresume→explicit Stop・定数／import／Bundle・provider判定は一切未実行（stagesは空）、SDK取得試行0・callback未作成。LLDB session13616はquit後終了0。接続が確立していないため、この最終試行をdetach成功とは記録しない。**このnative診断の停止点はOSのデバッグ接続許可の拒否であり、先のSIGSTOP式評価中断やCodex自動承認レビュー拒否とは別要因**。拒否の下位原因を未取得のまま端末設定／署名／DeviceCheckの不良へ断定しない。

00:57:08 UTCに追加read-onlyを1回だけ行い、同じ既存Runner実体1件・同PID9221の存続を確認した。公式processesの返却項目は実行ファイルとPIDだけでforeground／background／suspendedは確認できず、displaysの点灯情報からもアプリ前景は断定しない。00:18／00:22当時のlock／foreground記録がないため、過去のSIGSTOPが端末ロックや背景suspendと一致したとは証明できない。最終試行後の追加attach／SDK取得／起動／AI／Authは0。当時の既存Release・データ・設定を維持し、このnative診断の範囲では実attestation未確認だった。後続の既存サーバー計測による判定は前節を参照する。

固定SDK sourceでprovider参照経路は `FIRAppCheck.appCheckCore → GACAppCheck.appCheckProvider → FIRInternalAppCheckProvider.appCheckProvider` と確認したが、実機でのprovider判定・Firebase AppID照合・token取得／有効期限はSDK前の中断により未確認。FirebaseへのDeviceCheck登録とReleaseのDeviceCheck指定は既存確認済みのままで、診断版への上書きやDebug providerへの変更はしていない。

既存ログのread-only照合は10/26 00:12:00 UTC以降を対象に1回、同00:23:23 UTCに実施した。対象は既知のiOS Firebase AppIDと、①Cloud Run `hamster-rag-api` の `Firebase App Check token verified` 行、②`firebaseappcheck.googleapis.com` のDeviceCheck／ExchangeDeviceCheckToken監査行の組合せ。該当0件・権限拒否なし。10/24以降および前回後の既存照合も0件だった。監査ログが記録されない場合を含むため、0件を交換失敗や未実行の証明にはしない。ログ設定は変更していない。

今回の照会にはFunctions callableの検証行を含めていない。限定source照合ではFunctions SDK標準のcallable検証ログは `verifications.app/auth` の状態だけでAppID／providerを出さず、直接関係するFunctions sourceに対象AppIDを追加記録する処理も確認できなかった。従来のDebug版で得たVALIDを現Releaseへ転記しない。通常起動後のHome／Firestore表示成功はmonitor-only運用やcache利用と両立し、翌日であることだけでは実tokenの有効期限切れも証明できない。既存AI成功とReleaseのprovider指定だけから実attestation PASSを推定せず、**このnative診断時点ではRelease DeviceCheck実attestation未確認**だった。後続のサーバー計測PASSは前節の別証拠による。追加AI／認証／強制refreshで証拠を作る試行は行っていない。

証拠は既存staging `ios-device-runtime-20261019/audit/` の `devicecheck-native-staged-20261026-result.json`、`devicecheck-sdk-stage-blocked-20261026.json`、`devicecheck-root-staged-20261026-result.json`、`devicecheck-existing-logs-after-launch-20261026.json`、`devicecheck-sdk-before-jit-comparison-20261026.json`。数値・boolean・停止理由・照合件数だけを保存し、生token・秘密鍵・相談本文は保存／出力していない。00:18の保存JSONはfollowup前のrunning状態であり、その後の安全detachはblocked記録、00:22の安全detachはroot-staged記録を参照する。 最終attach拒否は `devicecheck-final-foreground-20261026-result.json`、親が確認したLLDB拒否・終了状態の安全要約は `devicecheck-final-attach-denial-summary-20261026.json`、その後の同PID存続は `devicecheck-after-attach-denial-process-20261026.json`、00:49のlock／画面点灯・process参考情報は `devicecheck-lock-process-readonly-20261026.json` を参照する。

## 次期アバター更新版build3：画像完成後の手順

- 既存1.0.1／build2のTestFlight更新・同意表示／取消・保持・Release DeviceCheckのPASSを維持。次期は`1.0.1／build3`。画像受領前の今は元`pubspec.yaml`の`1.0.1+2`、workspace／署名／iPhoneのReleaseを保持する。画像統合時だけ`1.0.1+3`へ更新し、生成物のCFBundleShortVersionString=1.0.1／CFBundleVersion=3を確認する。
- 本人サインイン後の10/31 TestFlight一覧とAll StatusesのBuild Uploadsを読み取り、Version1.0.1のbuild2のみ（Upload Complete／10/26 9:50）で、build3は未登録・処理中表示なしと確認した。次番号はbuild3と確定。番号は他作業によって消費され得るため、アップロード直前もBuild Uploads／同versionを確認する。
- `assets/avatars/README.md`の受入確認後、恒久Flutter3.47.7・Xcode`/Applications/Xcode_27.1.app`・通常`lib/main.dart`・既存lockを再利用する。`DEVELOPER_DIR=/Applications/Xcode_27.1.app/Contents/Developer`を工程単位で指定し、既存SDKやxcode-selectを変更しない。
- 前回の既存staging `ios-device-runtime-20261019/audit/consent-ios-generation-result-20261025.json`／`consent-ios-archive-command-20261025.json`の環境・引数を再利用する。画像と番号の差分を同期した隔離workspaceで、固定依存の生成／Podsを準備し、Runner／Release／generic iOS・独立DerivedData／SourcePackages・依存の自動更新なしで新Archiveを作る。番号指定だけ3へ変更し、検証用entrypointへ切り替えない。Archive前に隔離workspaceの`ios/Flutter/Generated.xcconfig`を再生成し、`FLUTTER_BUILD_NAME=1.0.1`／`FLUTTER_BUILD_NUMBER=3`／`FLUTTER_TARGET=lib/main.dart`を照合する（生成設定へbuild2を残したままArchiveしない）。
- 新Archiveは必要（旧build2 IPAへ画像を後入れしない）。同Team3SA77V3SM7／com.gotainu.hamsterと既存Apple Distribution／App Store Profileを維持し、前回成功のautomatic exportを使用する。Xcode-managed Profileに不適合だったmanual exportへ戻さず、不要なallowProvisioningUpdates／資格発行・権限変更を行わない。codesign strict、get-task-allow=false、production App Check／APNs、ZIPと追加PNG格納、Archiveとのコード・資産一致を限定確認する。
- 成果物はbuild3と画像更新を示す別名で保存し、build2／既存Archive／監査を上書きしない。ローカル生成後は、対象IPA／既存TestFlight本人向け配布の承認を得てからTransporterへ1回だけ送る。現コードの暗号利用が変わらなければ前回の輸出回答を参照し、確約・新規申告が必要な最終操作はその時点の承認条件に従う。
- ASC App ID6826783734の既存内部グループ「本人実機確認」・本人1名・手動配布を維持し、処理済みbuild3を追加する。外部beta／新招待／App Store一般審査へ広げない。TestFlightから2→3を削除なし更新し、Home・ログイン／既存記録保持と追加アバターのプレビュー／表示のみ確認する。AI・認証・DeviceCheckを再試験せず、体験期限／履歴・残枠を保持する。普段使いReleaseをDebug版で上書きしない。
- Apple Case103009817213は回答待ち。アバター更新準備をIAP適合確定や購入導線変更の根拠にしない。今回は新Archive／IPA生成・upload・配布を実行しない。

## 次の最小作業

現在の次作業は正本 `REL-03` の残件だけとする。指定IPAのTransporterデリバリは10/26 9:50成功、App Store Connect処理後の輸出申告は本人承認を得て「標準暗号（OS外TLSを含む）／独自暗号なし／フランス配布なし」で保存済み。TestFlightは本人のみの内部グループ1テスター／1ビルドがTestingで、upload・内部配布待ちへ戻さない。証拠は `/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/audit/asc-owner-internal-build2-testing.png`。一般公開の審査送信・公開は今回の内部配布と区別する。

本人がTestFlightからインストールし、Home表示・ログイン・既存飼育記録の保持をPASS確認した。端末metadataのBundle `com.gotainu.hamster`／1.0.1（2）は一致。`builtByDeveloper` は更新前後ともtrueのため、そのflagを署名／配布方式の移行証明には使わない。アプリ実体パスの変化と、本人によるデータ・ログイン保持の確認も別の根拠として扱う。同意説明の表示、「送信しない」による取消後の入力保持、正しい設定ルート再案内後の同意撤回項目の表示は本人PASS。設定の確認ダイアログの開閉／キャンセルまでは本人の明言がないため未確認。実同意承諾・保存済同意の実撤回・同意対応版での新実AIは未実施。本人確認の記録は `/Users/gota/hamcare-deploy-staging/ios-device-runtime-20261019/audit/testflight-consent-owner-ui-final-20261026.json` を参照する。Androidは固定同意AAB由来・同じ既存52ab証明書のローカルRelease APKを削除なし上書きして起動PASS。本人も再ログインなしのHome・既存記録と設定の撤回項目表示を確認PASS。これはPlay署名配布版への移行とは区別し、iOSの説明Dialog／取消の結果をAndroidへ転記しない。本人証拠は既存Android staging/audit/android-local-consent-owner-confirmed-20261026.json。更新後の現アプリ・既存データ・ログインを維持し、従来のGoogle実OAuth・復帰・Home・再起動保持と、同意対応版の配布前に本人確認した両端末の文字AI各1件のPASSを再実施しない。同意対応版で新たにAI送信済みとは扱わない。Release DeviceCheckの最小実動作は、後続のTestFlight版の既存サーバー計測でPASS。前段のOS attach拒否・SDK取得0は診断履歴として残し、端末SDK callback／token／個別有効期限の直接観測とは区別する。今回の根拠を得るための追加attach／SDK取得／AI送信は行わず、同じ確認を再実行する必要はない。必要な削除時token取消の残確認も正本で管理する。

Apple Distribution export・署名検証は生成履歴、実機のDevelopment署名PASSは従来の端末履歴として区別する。SchemeのArchiveActionは既にReleaseで変更不要。App Store Connect規約本人同意、レコード作成・1.0.1手動公開／日本のみ／無料・掲載原稿／Privacy URL保存はPASS済み。以下の1〜4は10/18時点の計画を保存した履歴であり、OS更新・初回導入を再び行う指示ではない。

1. ユーザー承認後、最小候補のmacOS Sequoia15.6以降の対応15.xへ更新する。現在14.8.9はXcode26.3の動作要件を満たさないため。今回OSのdownload／installは行わない。
2. 既存Xcode16.2を保持し、公式配布元のXcode26.3を別名で並行導入する。既存Flutterは置き換えず、隔離コピーとコマンド単位DEVELOPER_DIRで互換性を確認する。このiPhoneのDDI variant取得・mountが通るかは導入後に実測する。
3. 接続iPhoneのDDI mount、アプリ一覧取得が通ることを確認。既存アプリの有無を確認してから検証版を導入し、Apple／Google承認・URL復帰を実施する。通常アプリを無断アンインストール／消去しない。
4. 本番Firebaseまでのログインは、自動データ保存を避ける条件を明確にして実施する。実AI・Stripe決済は不要。

Apple DeveloperでのCapability再設定・証明書再発行・別Bundle ID作成は、現証拠からは不要。既存Profileで足りている。

## 保護と証拠

通常候補はpbxprojの表示metadata 3行＋本書／既存文書・PROJECT_STATUSの追記だけ。probeのmain／AppDelegate／telemetry設定は通常repoへ反映しない。既存dirty、Known Good、課金導線、Stripe権限、本番Functions／Firestore／Stripe設定は維持する。git reset／clean／stash、ストア申請・本番配備・実機インストールは未実施。

最初のsandbox内証明書参照は0件／profile decode不可だったが、読み取り権限を明示した実環境参照で有効1件・Profile一致を確認した。最初のEntitlements読取りで空hashが返った事象も保持し、再読446byte／既存archiveと同hash／cmp／plist lintの一致で解消してから保護対象のbaselineを確定した。

## 署名付きビルドの確定結果

現在の署名付きRelease AOTと実機Home起動は10/24の記録を正とする。下表は10/18の旧Xcode／当時のProfileの証拠であり、配布用署名やGoogle実認証のPASSを示すものではない。

| 対象 | 結果 |
| --- | --- |
| 通常HamCare | Xcode16.2／SDK18.2、Release、Automatic、終了0／BUILD SUCCEEDED。1.0.1+2、arm64、最小iOS15.0。 |
| 隔離認証probe | 同じTeam／App ID／entitlement／AutomaticでRelease終了0／BUILD SUCCEEDED。Dart限定解析もNo issues。 |
| 成果物照合 | 両方codesign deep／strict検証PASS。署名済みapplication-identifier／team／applesignin=[Default]、embedded profile UUID、Apple権限、対象iPhone登録が一致。 |
| 実使用Profile | iOS Team Provisioning Profile: com.gotainu.hamster、UUID 4f2a909f-f3ed-483f-b686-eae8786e50b0、期限2027-09-24。古いProfileではない。 |
| 通常版への混入 | 元main／AppDelegate／通常plistでビルド。Google Client ID／URL Scheme一致、probe用収集停止フラグ・確認画面は含まない。Podfile.lock／Dart lock／既存entitlement不変。 |
| 署名環境 | 開発証明書とDevelopment Profileの署名。APNs development、App Attest entitlement production。実通知／App Check動作やApp Store配布署名のPASSとはしない。 |
| 実機・認証 | アプリ導入・起動・Apple／Google承認は未実施。上記DDI errorによる停止を維持。 |

初回のFlutter build iosはProfile／Teamに関する汎用エラーで停止した。設定を再発行せず、同じAutomatic設定・既存Profileでgeneric iOS destinationのXcodeビルドを実行し、probe／通常版とも成功した。初回の失敗ログは保持し、CLI初回失敗の原因を未確定のまま隠さない。既存Podsの最小OS警告、CocoaPods推奨版警告は残るが、今回の署名ビルドは両方終了0。

証拠・署名済み成果物・実際にコンパイルしたprobe source・変更前ファイル・公式更新前のDDIは`/Users/gota/hamcare-deploy-staging/ios-signing-physical-auth-20261018/`へ保存する。Known Goodの旧成果物は上書きしない。
