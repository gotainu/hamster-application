import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FuncSearchScreen extends StatefulWidget {
  const FuncSearchScreen({super.key});

  @override
  State<FuncSearchScreen> createState() => _FuncSearchScreenState();
}

class _FuncSearchScreenState extends State<FuncSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _responseText = '';
  List<String> _chunks = []; // 取得したチャンクを格納する変数を用意
  bool _isLoading = false;

  Future<void> _sendMessage(String message) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _responseText = '';
      _chunks = []; // 以前のチャンクをクリア
    });

    try {
      // ここは、エミュレータではなく実機／同一ネットワークからアクセスする際の IP を指定
      //   実機: 192.168.0.30:8000
      //   エミュレータ: 10.0.2.2:8000
      final uri = Uri.parse(
          'http://192.168.0.30:8000/search?query=${Uri.encodeComponent(message)}');
      final resp = await http.get(uri);

      if (resp.statusCode == 200) {
        // サーバから返ってきた JSON は「リスト」なので List<dynamic> としてデコード
        final List<dynamic> decoded = json.decode(utf8.decode(resp.bodyBytes));

        // decoded[0] が回答テキスト (String)、decoded[1] がチャンク一覧 (List<dynamic>)
        setState(() {
          _responseText = decoded[0] as String;

          // List<dynamic> を List<String> にキャストして _chunks に格納
          final List<dynamic> rawChunks = decoded[1] as List<dynamic>;
          _chunks = rawChunks.map((e) => e.toString()).toList();
        });
      } else {
        setState(() {
          _responseText = 'エラー: ステータスコード ${resp.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _responseText = 'エラー: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI質問機能')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'YouTubeチャンネル動画のシナリオをRAGで読み込ませて、OpenAIのLLMで返答します。'
              'つまり８年分のノウハウを学習させたAIが、あなたの質問に回答します。飼育に関する質問を入力してください:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            // ─── 質問入力部 ────────────────────────────────────────────────
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: '質問を入力...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                final message = _controller.text.trim();
                if (message.isNotEmpty) _sendMessage(message);
              },
              child: _isLoading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('送信中...'),
                      ],
                    )
                  : const Text('送信'),
            ),
            const SizedBox(height: 16),
            // ─── 回答表示部 ────────────────────────────────────────────────
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 回答テキスト
                      Text(
                        _responseText,
                        style: const TextStyle(fontSize: 16),
                      ),

                      const SizedBox(height: 16),
                      // “チャンクを確認” ボタンは、チャンクが 1 件以上あるときだけ表示
                      if (_chunks.isNotEmpty)
                        ElevatedButton(
                          onPressed: () {
                            // チャンク一覧をダイアログなどで表示
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('取得されたチャンク一覧'),
                                  content: SizedBox(
                                    width: double.maxFinite,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _chunks.length,
                                      itemBuilder: (ctx, i) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4.0),
                                          child: Text('- ' + _chunks[i]),
                                        );
                                      },
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('閉じる'),
                                    )
                                  ],
                                );
                              },
                            );
                          },
                          child: const Text('チャンクを確認'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
