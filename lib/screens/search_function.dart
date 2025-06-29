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
  List<String> _chunks = [];
  bool _isLoading = false;

  // デバッグ用: チャンク＋スコア表示
  List<Map<String, dynamic>> _debugChunks = [];

  Future<void> _sendMessage(String message) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _responseText = '';
      _chunks = [];
    });

    try {
      final uri = Uri.parse(
          'http://10.0.2.2:8000/search?query=${Uri.encodeQueryComponent(message)}');
      final resp = await http.get(uri);

      if (resp.statusCode == 200) {
        // Listで返る場合に対応
        final decoded = json.decode(utf8.decode(resp.bodyBytes));
        if (decoded is List && decoded.length >= 2) {
          setState(() {
            _responseText = decoded[0] as String;
            _chunks = (decoded[1] as List<dynamic>).cast<String>();
          });
        } else if (decoded is String) {
          setState(() {
            _responseText = decoded;
          });
        } else {
          setState(() {
            _responseText = 'エラー: 予期しないレスポンス形式';
          });
        }
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

  // デバッグ用: /debug_search の呼び出し
  Future<void> _debugSearch(String message) async {
    setState(() {
      _debugChunks = [];
    });
    try {
      final uri = Uri.parse(
          'http://10.0.2.2:8000/debug_search?query=${Uri.encodeQueryComponent(message)}&top_k=10');
      final resp = await http.get(uri);

      if (resp.statusCode == 200) {
        final decoded = json.decode(utf8.decode(resp.bodyBytes));
        // /debug_search の戻り値 {"matches": [...]}
        List<Map<String, dynamic>> chunks = [];
        if (decoded is Map && decoded['matches'] is List) {
          for (final item in decoded['matches']) {
            if (item is Map) {
              // 必ずscore, id, textキーが存在するとは限らないので安全に
              chunks.add({
                'score': item['score'] ?? 0.0,
                'id': item['id'] ?? '',
                'text': item['text'] ?? '',
              });
            }
          }
        }
        setState(() {
          _debugChunks = chunks;
        });
        _showDebugChunksDialog();
      } else {
        setState(() {
          _debugChunks = [];
        });
        _showErrorDialog('デバッグ用チャンク取得に失敗しました: ステータスコード${resp.statusCode}');
      }
    } catch (e) {
      setState(() {
        _debugChunks = [];
      });
      _showErrorDialog('デバッグ用チャンク取得に失敗: $e');
    }
  }

  void _showDebugChunksDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return DefaultTabController(
          length: _debugChunks.length,
          child: AlertDialog(
            title: const Text('検索チャンク一覧'),
            content: SizedBox(
              width: double.maxFinite,
              height: 420,
              child: _debugChunks.isEmpty
                  ? const Text('チャンクが見つかりませんでした。')
                  : Column(
                      children: [
                        TabBar(
                          isScrollable: true,
                          labelColor: Theme.of(context).primaryColor,
                          unselectedLabelColor: Colors.grey,
                          tabs: List.generate(
                            _debugChunks.length,
                            (i) => Tab(text: 'チャンク${i + 1}'),
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: _debugChunks.map((chunk) {
                              return SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'score: ${chunk['score']?.toStringAsFixed(4) ?? "??"}',
                                        style: const TextStyle(
                                            fontSize: 14, color: Colors.grey),
                                      ),
                                      Text(
                                        'id: ${chunk['id'] ?? "??"}',
                                        style: const TextStyle(
                                            fontSize: 13, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        chunk['text'] ?? '',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('閉じる'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('エラー'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
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
              'YouTubeチャンネル動画のシナリオをRAGで読み込ませて、OpenAIのLLMで返答します。つまり８年分のノウハウを学習させたAIが、あなたの質問に回答します。飼育に関する質問を入力してください:',
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final message = _controller.text.trim();
                if (message.isNotEmpty) {
                  _debugSearch(message);
                }
              },
              child: const Text('チャンクを確認'),
            ),
          ],
        ),
      ),
    );
  }
}
