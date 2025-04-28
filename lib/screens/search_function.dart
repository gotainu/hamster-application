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
  bool _isLoading = false;

  Future<void> _sendMessage(String message) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _responseText = '';
    });

    try {
      final uri = Uri.parse(
          //'http://10.0.2.2:8000/search?query=${Uri.encodeQueryComponent(message)}');
          'http://192.168.0.30:8000/search?query=${Uri.encodeQueryComponent(message)}');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        final body = json.decode(decoded);
        setState(() {
          _responseText = body['result'] ?? '回答が取得できませんでした。';
        });
      } else {
        setState(() {
          _responseText = 'エラー: ステータスコード ${response.statusCode}';
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
              'YouTubeチャンネル動画のシナリオをRAGで読み込ませて、OpenAIのLLMで返答します。つまり８年分のノウハウを学習させたAIが、'
              'あなたの質問に回答します。飼育に関する質問を入力してください:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
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
                if (message.isNotEmpty) {
                  _sendMessage(message);
                }
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
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: Text(
                    _responseText,
                    style: const TextStyle(fontSize: 16),
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
