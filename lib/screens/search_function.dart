import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:async';

class ChatMessage {
  final String content;
  final bool isUser;
  final List<String>? chunks;
  final String? originalQuery;
  final bool isLoading;

  ChatMessage({
    required this.content,
    required this.isUser,
    this.chunks,
    this.originalQuery,
    this.isLoading = false,
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
  final FocusNode _focusNode = FocusNode(); // ← 追加
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _userImageUrl;
  bool _showDescriptionCard = true; // ← 追加

  // ドットアニメ用
  int _dotCount = 1;
  Timer? _dotTimer;

  final List<Map<String, String>> _conversationHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchUserImage();
    // TextFieldにフォーカスされたら説明カードを消す
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showDescriptionCard) {
        setState(() {
          _showDescriptionCard = false;
        });
      }
    });
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

  Future<List<String>> _fetchAIResponseWithHistory(String userMessage) async {
    final url = Uri.parse('http://10.0.2.2:8000/chat');
    final List<String> history =
        _messages.where((msg) => msg.isUser).map((msg) => msg.content).toList();
    final requestBody = json.encode({
      "query": userMessage,
      "history": history,
    });

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    if (res.statusCode == 200) {
      final decoded = json.decode(utf8.decode(res.bodyBytes));
      final answer = decoded["answer"] as String;
      final chunks = (decoded["chunks"] as List<dynamic>).cast<String>();
      return [answer, ...chunks];
    } else {
      throw Exception('API通信に失敗しました (HTTP ${res.statusCode})');
    }
  }

  void _startDotTimer() {
    _dotTimer?.cancel();
    _dotCount = 1;
    _dotTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      setState(() {
        _dotCount = _dotCount % 3 + 1;
      });
    });
  }

  void _stopDotTimer() {
    _dotTimer?.cancel();
  }

  void _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(content: text, isUser: true));
      _conversationHistory.add({"role": "user", "content": text});
      _isLoading = true;
      _messages.add(ChatMessage(
        content: '',
        isUser: false,
        isLoading: true,
      ));
    });
    _startDotTimer();
    _textController.clear();
    _scrollToBottom();

    try {
      final result = await _fetchAIResponseWithHistory(text);
      final aiAnswer = result[0];
      final aiChunks = result.sublist(1);

      setState(() {
        _messages.removeWhere((msg) => msg.isLoading);
        _messages.add(ChatMessage(
          content: aiAnswer,
          isUser: false,
          chunks: aiChunks,
          originalQuery: text,
        ));
        _conversationHistory.add({"role": "assistant", "content": aiAnswer});
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.removeWhere((msg) => msg.isLoading);
        _messages.add(ChatMessage(content: 'エラー: $e', isUser: false));
      });
      _scrollToBottom();
    } finally {
      setState(() {
        _isLoading = false;
      });
      _stopDotTimer();
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
        'http://10.0.2.2:8000/debug_search?query=${Uri.encodeQueryComponent(query)}&top_k=10');
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

  Widget _buildMessageBubble(ChatMessage msg) {
    if (msg.isLoading) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
              radius: 30, child: Icon(Icons.smart_toy, size: 45)),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                List.filled(_dotCount, '・').join(''),
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.black54,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment:
          msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!msg.isUser) ...[
              const CircleAvatar(
                radius: 30,
                child: Icon(Icons.smart_toy, size: 45),
              ),
              const SizedBox(width: 18),
            ],
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: msg.isUser ? Colors.blueAccent : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(msg.content,
                    style: TextStyle(
                        fontSize: 18,
                        color: msg.isUser ? Colors.white : Colors.black)),
              ),
            ),
            if (msg.isUser) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 30,
                backgroundImage:
                    _userImageUrl != null ? NetworkImage(_userImageUrl!) : null,
                child: _userImageUrl == null
                    ? const Icon(Icons.person, size: 30)
                    : null,
              ),
            ],
          ],
        ),
        if (!msg.isUser && msg.originalQuery != null)
          TextButton(
            onPressed: () => _showDebugChunksDialog(msg.originalQuery!),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
              child: const Text('チャンクを確認'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBarは削除
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showDescriptionCard)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 32, 16, 0),
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            color: Colors.blue, size: 28),
                        SizedBox(width: 10),
                        Text(
                          "AI質問チャット",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(0xFFF2F7FB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'YouTubeチャンネルで紹介した内容を学習したAIにチャットで相談することができます。\nまた、AIが返答の際に引用した内容も「チャンクを確認」ボタンから確認できます。',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF3B4B68),
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    focusNode: _focusNode, // ← ここ
                    controller: _textController,
                    decoration: const InputDecoration(
                        hintText: '質問してみましょう', border: OutlineInputBorder()),
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
    _focusNode.dispose(); // ← 忘れずにdispose
    _dotTimer?.cancel();
    super.dispose();
  }
}
