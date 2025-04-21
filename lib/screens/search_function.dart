import 'package:flutter/material.dart';
import 'package:hamster_project/services/openai_service.dart';

class FuncSearchScreen extends StatefulWidget {
  const FuncSearchScreen({super.key});

  @override
  State<FuncSearchScreen> createState() => _FuncSearchScreenState();
}

class _FuncSearchScreenState extends State<FuncSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _responseText = '';
  bool _isLoading = false;

  // OpenAI API キーは環境変数から取得（安全な管理を推奨）
  final String _apiKey = const String.fromEnvironment('OPENAI_API_KEY');

  // OpenAIService のインスタンスを生成
  late final OpenAIService _openAIService = OpenAIService(apiKey: _apiKey);

  Future<void> _sendMessage(String message) async {
    // すでにロード中の場合は何もしない
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _responseText = '';
    });

    try {
      final answer = await _openAIService.sendMessage(message);
      setState(() {
        _responseText = answer;
      });
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
      appBar: AppBar(
        title: const Text('AI質問機能'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Go/hamsterチャンネルで８年間蓄積したハムスター飼育のノウハウを学習させたAIが、'
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
            // 送信ボタン
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
