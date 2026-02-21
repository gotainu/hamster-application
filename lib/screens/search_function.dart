import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:async';

import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/shine_border.dart';

class RetrievedChunk {
  final String id;
  final double score;
  final String text;
  final String filename;
  final int? lineStart;
  final int? lineEnd;
  final String semanticTitle;
  final String sectionName;
  final String sectionSummary;
  final String metaVersion;

  RetrievedChunk({
    required this.id,
    required this.score,
    required this.text,
    required this.filename,
    this.lineStart,
    this.lineEnd,
    required this.semanticTitle,
    required this.sectionName,
    required this.sectionSummary,
    required this.metaVersion,
  });

  factory RetrievedChunk.fromJson(Map<String, dynamic> j) {
    return RetrievedChunk(
      id: (j['id'] ?? '') as String,
      score: (j['score'] as num?)?.toDouble() ?? 0.0,
      text: (j['text'] ?? '') as String,
      filename: (j['filename'] ?? '') as String,
      lineStart: (j['line_start'] as num?)?.toInt(),
      lineEnd: (j['line_end'] as num?)?.toInt(),
      semanticTitle: (j['semantic_title'] ?? '') as String,
      sectionName: (j['section_name'] ?? '') as String,
      sectionSummary: (j['section_summary'] ?? '') as String,
      metaVersion: (j['meta_version'] ?? '') as String,
    );
  }
}

class ChatApiResult {
  final String answer;
  final List<RetrievedChunk> chunks;
  ChatApiResult({required this.answer, required this.chunks});
}

class ChatMessage {
  final String content;
  final bool isUser;
  final List<RetrievedChunk>? chunks;
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
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // ユーザーのメインペット画像URL（users/{uid}/pet_profiles/main_pet.imageUrl）
  String? _userImageUrl;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _avatarSub;

  // ドットアニメ用
  int _dotCount = 1;
  Timer? _dotTimer;

  final List<Map<String, String>> _conversationHistory = [];

  bool _showDescriptionCard = true;
  double _cardOpacity = 1.0;
  Offset _cardOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _listenUserAvatar(); // ← ここで購読開始
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showDescriptionCard) {
        setState(() {
          _cardOpacity = 0.0;
          _cardOffset = const Offset(0, -0.15);
        });
      }
    });
  }

  Widget _aiAvatar() => const CircleAvatar(
        radius: 30,
        backgroundImage: AssetImage('assets/images/roi.png'),
        backgroundColor: Colors.transparent,
      );

  /// users/{uid}/pet_profiles/main_pet をリアルタイム購読して imageUrl を反映
  void _listenUserAvatar() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('pet_profiles')
        .doc('main_pet');

    _avatarSub = docRef.snapshots().listen((snap) {
      final url = snap.data()?['imageUrl'] as String?;
      if (mounted) {
        setState(() {
          _userImageUrl = (url != null && url.isNotEmpty) ? url : null;
        });
      }
    }, onError: (_) {
      // 失敗時はデフォルトアイコンに戻す
      if (mounted) setState(() => _userImageUrl = null);
    });
  }

  Future<ChatApiResult> _fetchAIResponseWithHistory(String userMessage) async {
    final url = Uri.parse('http://10.0.2.2:8000/chat');

    // 直近の履歴を送る（多すぎ防止）
    const int maxHistory = 12;
    final historyToSend = List<Map<String, String>>.from(
      _conversationHistory.length > maxHistory
          ? _conversationHistory
              .sublist(_conversationHistory.length - maxHistory)
          : _conversationHistory,
    );

    final requestBody = json.encode({
      "query": userMessage,
      "history": historyToSend, // ★ role/content の配列
    });

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    if (res.statusCode == 200) {
      final decoded =
          json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final answer = (decoded["answer"] ?? "") as String;

      final rawChunks = (decoded["chunks"] as List<dynamic>? ?? []);
      final chunks = rawChunks
          .map((e) => RetrievedChunk.fromJson(e as Map<String, dynamic>))
          .toList();

      return ChatApiResult(answer: answer, chunks: chunks);
    } else {
      throw Exception('API通信に失敗しました (HTTP ${res.statusCode})');
    }
  }

  void _startDotTimer() {
    _dotTimer?.cancel();
    _dotCount = 1;
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
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

      setState(() {
        _messages.removeWhere((msg) => msg.isLoading);
        _messages.add(ChatMessage(
          content: result.answer,
          isUser: false,
          chunks: result.chunks,
          originalQuery: text,
        ));
        _conversationHistory
            .add({"role": "assistant", "content": result.answer});
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

  Future<void> _showChunksDialog(List<RetrievedChunk> chunks) async {
    if (chunks.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) {
        return DefaultTabController(
          length: chunks.length,
          child: AlertDialog(
            title: const Text('引用チャンク'),
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
                      children: chunks.map((c) {
                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('score: ${c.score}'),
                              Text('id: ${c.id}'),
                              if (c.filename.isNotEmpty)
                                Text('file: ${c.filename}'),
                              if (c.lineStart != null && c.lineEnd != null)
                                Text('lines: ${c.lineStart}-${c.lineEnd}'),
                              if (c.semanticTitle.isNotEmpty)
                                Text('title: ${c.semanticTitle}'),
                              if (c.sectionName.isNotEmpty)
                                Text('section: ${c.sectionName}'),
                              const SizedBox(height: 8),
                              Text(c.text),
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
                  child: const Text('閉じる')),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final hasChunks = (msg.chunks?.isNotEmpty ?? false);
    if (msg.isLoading) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _aiAvatar(),
          // const CircleAvatar(
          //     radius: 30, child: Icon(Icons.smart_toy, size: 45)),
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
              // const CircleAvatar(
              //   radius: 30,
              //   child: Icon(Icons.smart_toy, size: 45),
              // ),
              _aiAvatar(),
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
        if (!msg.isUser && hasChunks)
          TextButton(
            onPressed: () => _showChunksDialog(msg.chunks!),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
              child: const Text('引用に使われたYouTubeシナリオを確認'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          top: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // AnimatedSwitcherをAnimatedContainerで高さ調整して置き換える
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _showDescriptionCard
                    ? AnimatedOpacity(
                        key: const ValueKey('descCard'),
                        opacity: _cardOpacity,
                        duration: const Duration(milliseconds: 400),
                        onEnd: () {
                          if (_cardOpacity == 0.0 && mounted) {
                            setState(() {
                              _showDescriptionCard = false;
                            });
                          }
                        },
                        child: AnimatedSlide(
                          offset: _cardOffset,
                          duration: const Duration(milliseconds: 400),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.cardInnerDark
                                  : AppTheme.cardInnerLight,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accent.withOpacity(0.23),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 24),
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
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppTheme.cardInnerDark
                                              .withOpacity(0.88)
                                          : AppTheme.cardInnerLight
                                              .withOpacity(0.92),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'YouTubeチャンネルで紹介した内容を学習したAIにチャットで相談することができます。\nまた、AIが返答の際に引用した内容も「チャンクを確認」ボタンから確認できます。',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: isDark
                                                ? AppTheme.cardTextColor
                                                : AppTheme.lightText
                                                    .withOpacity(0.88),
                                            height: 1.6,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return KeyedSubtree(
                      key: ValueKey(_messages[index].hashCode),
                      child: _buildMessageBubble(_messages[index]),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  8,
                  8,
                  8,
                  mq.viewInsets.bottom + 8,
                ),
                child: AnimatedShiningBorder(
                  borderRadius: 22,
                  borderWidth: 2.5,
                  active: _focusNode.hasFocus,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          focusNode: _focusNode,
                          controller: _textController,
                          style: const TextStyle(fontSize: 17),
                          decoration: InputDecoration(
                            hintText: '質問してみましょう',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 13),
                            filled: true,
                            fillColor:
                                Theme.of(context).scaffoldBackgroundColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: Icon(Icons.send,
                            color: Theme.of(context).colorScheme.primary),
                        onPressed: _handleSend,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _dotTimer?.cancel();
    _avatarSub?.cancel(); // ← 購読解除
    _avatarSub = null;
    super.dispose();
  }
}
