# hamster_project

A new Flutter project.

## 実機で実行する方法

Android 実機を使って Flutter アプリを実行するには、以下の手順を順に実行していけば OK です！

⸻

✅ 1. Android 端末側の準備

📱【1-1】開発者モードを有効にする
	1.	端末の「設定」 > 「デバイス情報」へ移動
	2.	「ビルド番号」を 7回連続タップ（「開発者モードが有効になりました」と表示される）

⸻

🔓【1-2】USBデバッグを有効にする
	1.	「設定」 > 「システム」>「開発者向けオプション」へ移動
	2.	「USB デバッグ」を オン にする

⸻

✅ 2. パソコン側の確認

🧪【2-1】接続確認

ターミナルで以下を実行：
```
flutter devices
```
➡ 接続された端末がリストに表示されていれば OK！

表示例：
```
2 connected devices:

Pixel 7 (mobile) • 192.168.x.x:5555 • android-arm64 • Android 13
```

⸻

⚠️ 表示されない場合のチェック
	•	USBケーブルを再接続
	•	スマホ画面に「このPCを許可しますか？」→「許可」タップ
	•	adb devices を実行しても確認可能（adb は Android SDK に含まれる）

⸻

✅ 3. Flutter アプリを実機で起動！

🚀 実行コマンド
```
flutter run
```
Flutter が自動で接続された実機にアプリをインストールして起動してくれます。

⸻

✅ 💡補足：FastAPI（ホストPC）への接続について

実機から FastAPI にアクセスしたい場合は、以下に注意してください：


| 接続元 | アクセス先にすべきアドレス |
|---------|---------|
| Android 実機（スマホ）   | ホストPCのIPアドレス（例：192.168.0.30）   |
| Android エミュレーター   | 10.0.2.2（= ホストPCの localhost を参照する特殊なIP）   |

理由：
	•	エミュレーターは仮想マシン上で動いているため、内部的にホストPCと「NAT越しの通信」をしています。
	•	10.0.2.2 はその特殊な通信経路における「ホストPCの代替名」です。
	•	ですが、Android 実機 は実ネットワーク上のデバイスなので、10.0.2.2 は無効です。


🔍 確認方法（macOS/Linux）:
```
ifconfig | grep inet
```
🔍 Windows の場合:
```
ipconfig
```

⸻

✅ 4. search_function.dart の修正例（実機接続用）

-  FastAPI にアクセスする際、lib/screens/search_function.dart 内で以下のように定義しています。

```
final uri = Uri.parse(
  'http://XXX.XXX.X.X:8000/search?query=${Uri.encodeQueryComponent(message)}',
);
```
-  Android 実機で FastAPI に正しく接続したい場合は以下に変更しましょう

```
final uri = Uri.parse(
  'http://192.168.0.30:8000/search?query=${Uri.encodeQueryComponent(message)}',
);
```

-  Androidエミュレータで FastAPI に正しく接続したい場合は以下に変更しましょう

```
final uri = Uri.parse(
  'http://10.0.2.2:8000/search?query=${Uri.encodeQueryComponent(message)}',
);
```
※ 192.168.1.5 の部分は、あなたの PCのIPアドレス に置き換えてください。

⸻

## Getting Started






