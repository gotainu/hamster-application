import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class ChatMessage {
  final String content;
  final bool isUser;
  final List<String>? chunks;
  final String? originalQuery;
  ChatMessage({
    required this.content,
    required this.isUser,
    this.chunks,
    this.originalQuery,
  });
}

class FuncSearchScreen extends StatefulWidget {
  const FuncSearchScreen({super.key});

  @override
  State<FuncSearchScreen> createState() => _FuncSearchScreenState();
}

class _FuncSearchScreenState extends State<FuncSearchScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _userImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserImage();
  }

  Future<void> _fetchUserImage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final docSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() {
      _userImageUrl = docSnapshot.data()?['imageUrl'];
    });
  }

  Future<List<String>> _fetchAIResponse(String userMessage) async {
    final url = Uri.parse(
        'http://192.168.0.30:8000/search?query=${Uri.encodeQueryComponent(userMessage)}');
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final decoded = json.decode(utf8.decode(res.bodyBytes));
      if (decoded is List && decoded.length >= 2) {
        final answer = decoded[0] as String;
        final chunks = (decoded[1] as List<dynamic>).cast<String>();
        return [answer, ...chunks];
      } else if (decoded is String) {
        return [decoded];
      } else {
        throw Exception('予期しないレスポンス');
      }
    }
    throw Exception('API通信に失敗しました (HTTP ${res.statusCode})');
  }

  void _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(content: text, isUser: true));
      _isLoading = true;
      _messages.add(ChatMessage(content: '...', isUser: false)); // Placeholder
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final result = await _fetchAIResponse(text);
      final aiAnswer = result[0];
      final aiChunks = result.sublist(1);

      setState(() {
        _messages.removeLast(); // placeholder削除
        _messages.add(ChatMessage(
            content: aiAnswer,
            isUser: false,
            chunks: aiChunks,
            originalQuery: text));
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(content: 'エラー: $e', isUser: false));
      });
      _scrollToBottom();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showDebugChunksDialog(String query) async {
    final uri = Uri.parse(
        'http://192.168.0.30:8000/debug_search?query=${Uri.encodeQueryComponent(query)}&top_k=10');
    final resp = await http.get(uri);

    if (resp.statusCode == 200) {
      final decoded = json.decode(utf8.decode(resp.bodyBytes));
      final List<Map<String, dynamic>> chunks =
          (decoded['matches'] as List).map((item) {
        return {
          'score': item['score'] ?? 0.0,
          'id': item['id'] ?? '',
          'text': item['text'] ?? '',
        };
      }).toList();
      showDialog(
        context: context,
        builder: (context) {
          return DefaultTabController(
            length: chunks.length,
            child: AlertDialog(
              title: const Text('検索チャンク一覧'),
              content: SizedBox(
                width: double.maxFinite,
                height: 420,
                child: Column(
                  children: [
                    TabBar(
                      isScrollable: true,
                      tabs: List.generate(
                          chunks.length, (i) => Tab(text: 'チャンク${i + 1}')),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: chunks.map((chunk) {
                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('score: ${chunk['score']}'),
                                Text('id: ${chunk['id']}'),
                                SizedBox(height: 8),
                                Text(chunk['text']),
                              ],
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる'),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI質問チャット')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Row(
                  mainAxisAlignment: msg.isUser
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!msg.isUser)
                      const CircleAvatar(child: Icon(Icons.smart_toy)),
                    if (!msg.isUser) const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: msg.isUser
                                  ? Colors.blueAccent
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: msg.content == '...'
                                ? const SizedBox(
                                    width: 30,
                                    child: LinearProgressIndicator(
                                      backgroundColor: Colors.transparent,
                                      color: Colors.grey,
                                    ),
                                  )
                                : Text(
                                    msg.content,
                                    style: TextStyle(
                                      color: msg.isUser
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                          ),
                          if (!msg.isUser &&
                              msg.content != '...' &&
                              msg.originalQuery != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: SizedBox(
                                width: 160,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    side: BorderSide(
                                        color: Theme.of(context).primaryColor),
                                  ),
                                  onPressed: () => _showDebugChunksDialog(
                                      msg.originalQuery!),
                                  child: const Text('チャンクを確認'),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (msg.isUser) const SizedBox(width: 8),
                    if (msg.isUser)
                      CircleAvatar(
                        backgroundImage: _userImageUrl != null
                            ? NetworkImage(_userImageUrl!)
                            : null,
                        child:
                            _userImageUrl == null ? Icon(Icons.person) : null,
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                        hintText: '質問を入力してください', border: OutlineInputBorder()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _handleSend,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
