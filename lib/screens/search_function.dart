import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/hamster_avatar.dart';
import '../models/pet_profile.dart';
import '../services/ai_chat_history_repo.dart';
import '../services/hamster_avatar_appearance_resolver.dart';
import '../services/hamster_avatar_asset_resolver.dart';
import '../services/pet_profile_repo.dart';
import '../theme/app_theme.dart';
import '../widgets/hamster_avatar_view.dart';
import '../widgets/floating_bottom_navigation.dart';
import '../widgets/paid_feature_gate.dart';
import '../widgets/shine_border.dart';

const String _ragApiBaseUrl = String.fromEnvironment(
  'RAG_API_BASE_URL',
  defaultValue: 'https://hamster-rag-api-797691641198.asia-northeast1.run.app',
);

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'score': score,
      'text': text,
      'filename': filename,
      'line_start': lineStart,
      'line_end': lineEnd,
      'semantic_title': semanticTitle,
      'section_name': sectionName,
      'section_summary': sectionSummary,
      'meta_version': metaVersion,
    };
  }
}

class ChatApiResult {
  final String answer;
  final List<RetrievedChunk> chunks;

  ChatApiResult({
    required this.answer,
    required this.chunks,
  });
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
  FuncSearchScreenState createState() => FuncSearchScreenState();
}

class FuncSearchScreenState extends State<FuncSearchScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AiChatHistoryRepo _chatHistoryRepo = AiChatHistoryRepo();
  final PetProfileRepo _petProfileRepo = PetProfileRepo();

  static const HamsterAvatarAppearanceResolver _avatarAppearanceResolver =
      HamsterAvatarAppearanceResolver();
  static const HamsterAvatarAssetResolver _avatarAssetResolver =
      HamsterAvatarAssetResolver();

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];

  String? _activeArchiveId;

  bool _isLoading = false;
  bool _isRestoringHistory = true;
  bool _hasRestoredHistory = false;
  bool _showDescriptionCard = true;

  PetProfile? _petProfile;
  StreamSubscription<PetProfile?>? _avatarSub;

  int _dotCount = 1;
  Timer? _dotTimer;

  double _cardOpacity = 1.0;
  Offset _cardOffset = Offset.zero;

  final List<Map<String, String>> _conversationHistory = [];

  bool get _isViewingArchivedThread => _activeArchiveId != null;

  @override
  void initState() {
    super.initState();
    _restoreChatHistory();
    _listenUserAvatar();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showDescriptionCard) {
        setState(() {
          _cardOpacity = 0.0;
          _cardOffset = const Offset(0, -0.15);
        });
      }
    });
  }

  void setDraftText(String text, {bool focus = true}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _activeArchiveId = null;
      _textController.text = trimmed;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );

      if (_showDescriptionCard) {
        _cardOpacity = 0.0;
        _cardOffset = const Offset(0, -0.15);
      }
    });

    if (focus) {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        _focusNode.requestFocus();
      });
    }

    _scrollToBottom();
  }

  void openChatHistory() {
    if (!mounted) return;

    FocusManager.instance.primaryFocus?.unfocus();
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void requestStartNewChat() {
    if (!mounted) return;

    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(_confirmStartNewChat());
  }

  Future<void> _restoreChatHistory() async {
    setState(() {
      _isRestoringHistory = true;
    });

    try {
      final savedMessages =
          await _chatHistoryRepo.fetchRecentMessages(limit: 50);

      if (!mounted) return;

      final restoredMessages = <ChatMessage>[];
      final restoredHistory = <Map<String, String>>[];

      for (final m in savedMessages) {
        final chunks = m.chunks.map((e) => RetrievedChunk.fromJson(e)).toList();

        restoredMessages.add(
          ChatMessage(
            content: m.content,
            isUser: m.isUser,
            chunks: chunks,
            originalQuery: m.originalQuery,
          ),
        );

        restoredHistory.add({
          'role': m.role,
          'content': m.content,
        });
      }

      setState(() {
        _messages
          ..clear()
          ..addAll(restoredMessages);

        _conversationHistory
          ..clear()
          ..addAll(restoredHistory);

        _activeArchiveId = null;
        _hasRestoredHistory = restoredMessages.isNotEmpty;

        if (_messages.isNotEmpty) {
          _showDescriptionCard = false;
          _cardOpacity = 0.0;
          _cardOffset = const Offset(0, -0.15);
        } else {
          _showDescriptionCard = true;
          _cardOpacity = 1.0;
          _cardOffset = Offset.zero;
        }
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            content: '履歴の読み込みに失敗しました: $e',
            isUser: false,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRestoringHistory = false;
        });
      }
    }
  }

  Future<void> _confirmStartNewChat() async {
    if (_isLoading || _isRestoringHistory) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('新しく相談を始めますか？'),
          content: const Text(
            '今の相談履歴は画面から消えますが、記録としては保存されます。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('新しく始める'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isRestoringHistory = true;
      _activeArchiveId = null;
    });

    try {
      await _chatHistoryRepo.archiveAndClearMainThread();

      if (!mounted) return;

      setState(() {
        _messages.clear();
        _conversationHistory.clear();
        _hasRestoredHistory = false;
        _showDescriptionCard = true;
        _cardOpacity = 1.0;
        _cardOffset = Offset.zero;
        _textController.clear();
      });

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('新しい相談を始めました。'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('新しい相談の開始に失敗しました: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRestoringHistory = false;
        });
      }
    }
  }

  Future<void> _openArchivedThread(AiChatThreadSummary thread) async {
    if (_isLoading || _isRestoringHistory) return;

    Navigator.of(context).maybePop();

    setState(() {
      _isRestoringHistory = true;
    });

    try {
      final savedMessages = await _chatHistoryRepo.fetchArchivedMessages(
        archiveId: thread.id,
        limit: 100,
      );

      if (!mounted) return;

      final restoredMessages = <ChatMessage>[];
      final restoredHistory = <Map<String, String>>[];

      for (final m in savedMessages) {
        final chunks = m.chunks.map((e) => RetrievedChunk.fromJson(e)).toList();

        restoredMessages.add(
          ChatMessage(
            content: m.content,
            isUser: m.isUser,
            chunks: chunks,
            originalQuery: m.originalQuery,
          ),
        );

        restoredHistory.add({
          'role': m.role,
          'content': m.content,
        });
      }

      setState(() {
        _messages
          ..clear()
          ..addAll(restoredMessages);

        _conversationHistory
          ..clear()
          ..addAll(restoredHistory);

        _activeArchiveId = thread.id;
        _hasRestoredHistory = false;
        _showDescriptionCard = false;
        _cardOpacity = 0.0;
        _cardOffset = const Offset(0, -0.15);
        _textController.clear();
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('過去の相談を読み込めませんでした: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRestoringHistory = false;
        });
      }
    }
  }

  Future<void> _returnToMainThread() async {
    if (_isLoading || _isRestoringHistory) return;

    setState(() {
      _activeArchiveId = null;
    });

    await _restoreChatHistory();
  }

  static const double _chatAvatarRadius = 35;
  static const double _chatAvatarSize = _chatAvatarRadius * 2;
  static const double _generatedAvatarZoom = 1.38;

  Widget _aiAvatar() {
    return const CircleAvatar(
      radius: _chatAvatarRadius,
      backgroundImage: AssetImage('assets/images/roi.png'),
      backgroundColor: Colors.transparent,
    );
  }

  HamsterAvatarPresentation _stableAvatarPresentation(
    PetProfile profile,
  ) {
    final appearance = _avatarAppearanceResolver.resolve(profile);

    return _avatarAssetResolver.resolve(
      appearance: appearance,
      conditionResult: const HamsterAvatarConditionResult(
        condition: HamsterAvatarCondition.stable,
        cause: HamsterAvatarCause.none,
        message: '登録された種類と毛色に応じたアバターです。',
        animateBreathing: false,
      ),
    );
  }

  Widget _avatarOrUnregisteredIcon(PetProfile? profile) {
    if (profile?.hasAvatarIdentity == true) {
      final zoomedSize = _chatAvatarSize * _generatedAvatarZoom;

      return Semantics(
        label: '登録された種類と毛色のペットアバター',
        image: true,
        child: Container(
          width: _chatAvatarSize,
          height: _chatAvatarSize,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.cardSurface(context),
            border: Border.all(
              color: AppTheme.envGood.withValues(alpha: 0.72),
              width: 1.5,
            ),
          ),
          child: OverflowBox(
            minWidth: 0,
            minHeight: 0,
            maxWidth: zoomedSize,
            maxHeight: zoomedSize,
            child: Transform.translate(
              offset: const Offset(0, 5),
              child: HamsterAvatarView(
                presentation: _stableAvatarPresentation(profile!),
                size: zoomedSize,
                showMessage: false,
                showDebugLabel: false,
                showBackdrop: false,
              ),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: _chatAvatarRadius,
      backgroundColor: AppTheme.cardSurface(context),
      child: Icon(
        Icons.pets_rounded,
        size: 36,
        color: AppTheme.secondaryText(context),
      ),
    );
  }

  Widget _userAvatar() {
    final profile = _petProfile;
    final imageUrl = profile?.imageUrl?.trim();

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Semantics(
        label: '登録されたペットの写真',
        image: true,
        child: SizedBox.square(
          dimension: _chatAvatarSize,
          child: ClipOval(
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: _chatAvatarSize,
              height: _chatAvatarSize,
              errorBuilder: (_, __, ___) => _avatarOrUnregisteredIcon(profile),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: profile?.hasAvatarIdentity == true
          ? '登録された種類と毛色のペットアバター'
          : 'ペットプロフィール未登録',
      image: true,
      child: _avatarOrUnregisteredIcon(profile),
    );
  }

  void _listenUserAvatar() {
    _avatarSub?.cancel();
    _avatarSub = _petProfileRepo.watchMainPet().listen(
      (profile) {
        if (!mounted) return;
        setState(() {
          _petProfile = profile;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _petProfile = null;
        });
      },
    );
  }

  Future<ChatApiResult> _fetchAIResponseWithHistory(String userMessage) async {
    final url = Uri.parse('$_ragApiBaseUrl/chat');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('ログイン情報を確認できませんでした。もう一度ログインしてください。');
    }

    final idToken = await user.getIdToken();

    if (idToken == null || idToken.isEmpty) {
      throw Exception('認証トークンを取得できませんでした。もう一度ログインしてください。');
    }

    String? appCheckToken;
    try {
      appCheckToken = await FirebaseAppCheck.instance.getToken();
    } catch (error) {
      debugPrint(
        '[App Check] token unavailable; continuing in monitor-only mode '
        '(${error.runtimeType})',
      );
    }

    const int maxHistory = 12;
    final historyToSend = List<Map<String, String>>.from(
      _conversationHistory.length > maxHistory
          ? _conversationHistory
              .sublist(_conversationHistory.length - maxHistory)
          : _conversationHistory,
    );

    final requestBody = json.encode({
      'query': userMessage,
      'history': historyToSend,
    });

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
    if (appCheckToken != null && appCheckToken.isNotEmpty) {
      headers['X-Firebase-AppCheck'] = appCheckToken;
    }

    final res = await http.post(
      url,
      headers: headers,
      body: requestBody,
    );

    if (res.statusCode == 200) {
      final decoded =
          json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final answer = (decoded['answer'] ?? '') as String;

      final rawChunks = decoded['chunks'] as List<dynamic>? ?? [];
      final chunks = rawChunks
          .map((e) => RetrievedChunk.fromJson(e as Map<String, dynamic>))
          .toList();

      return ChatApiResult(answer: answer, chunks: chunks);
    }

    if (res.statusCode == 401) {
      throw Exception('認証に失敗しました。ログインし直してください。');
    }

    if (res.statusCode == 429) {
      throw Exception('AI相談の利用上限に達している可能性があります。少し時間をおいて再度お試しください。');
    }

    if (res.statusCode >= 500) {
      throw Exception('AIサーバー側で一時的なエラーが発生しました。少し時間をおいて再度お試しください。');
    }

    throw Exception('API通信に失敗しました (HTTP ${res.statusCode})');
  }

  void _startDotTimer() {
    _dotTimer?.cancel();
    _dotCount = 1;
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) return;

      setState(() {
        _dotCount = _dotCount % 3 + 1;
      });
    });
  }

  void _stopDotTimer() {
    _dotTimer?.cancel();
    _dotTimer = null;
  }

  void _handleSend() async {
    if (_isViewingArchivedThread) return;

    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _hasRestoredHistory = false;
      _messages.add(ChatMessage(content: text, isUser: true));
      _conversationHistory.add({'role': 'user', 'content': text});
      _isLoading = true;
      _messages.add(
        ChatMessage(
          content: '',
          isUser: false,
          isLoading: true,
        ),
      );
    });

    unawaited(_chatHistoryRepo.addUserMessage(content: text));
    _startDotTimer();
    _textController.clear();
    _scrollToBottom();

    try {
      final result = await _fetchAIResponseWithHistory(text);

      if (!mounted) return;

      setState(() {
        _messages.removeWhere((msg) => msg.isLoading);
        _messages.add(
          ChatMessage(
            content: result.answer,
            isUser: false,
            chunks: result.chunks,
            originalQuery: text,
          ),
        );
        _conversationHistory.add({
          'role': 'assistant',
          'content': result.answer,
        });
      });

      unawaited(
        _chatHistoryRepo.addAssistantMessage(
          content: result.answer,
          originalQuery: text,
          chunks: result.chunks.map((e) => e.toJson()).toList(),
        ),
      );

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.removeWhere((msg) => msg.isLoading);
        _messages.add(
          ChatMessage(
            content: 'エラー: $e',
            isUser: false,
          ),
        );
      });

      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
            title: const Text('参照された内容'),
            content: SizedBox(
              width: double.maxFinite,
              height: 420,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    tabs: List.generate(
                      chunks.length,
                      (i) => Tab(text: '資料${i + 1}'),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: chunks.map((c) {
                        return SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (c.semanticTitle.isNotEmpty)
                                  Text(
                                    c.semanticTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                if (c.sectionName.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text('section: ${c.sectionName}'),
                                ],
                                if (c.filename.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text('file: ${c.filename}'),
                                ],
                                if (c.lineStart != null &&
                                    c.lineEnd != null) ...[
                                  const SizedBox(height: 4),
                                  Text('lines: ${c.lineStart}-${c.lineEnd}'),
                                ],
                                const SizedBox(height: 12),
                                Text(c.text),
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
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryRestoredCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardInnerDark : AppTheme.cardInnerLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.quickActionBorder(context),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.history_rounded,
            color: AppTheme.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '前回の相談を読み込みました',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'このまま続けて相談できます。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText(context),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _confirmStartNewChat,
            child: const Text('新しく始める'),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardInnerDark : AppTheme.cardInnerLight,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.quickActionFill(context),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '気になることを相談できます',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '飼育環境・温湿度・記録を踏まえて、今確認したいことを一緒に整理します。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText(context),
                        height: 1.5,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatHeader(BuildContext context) {
    final subtitle = _isViewingArchivedThread ? '過去の相談を表示中' : '気になることを相談できます';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryText(context),
                  ),
            ),
          ),
          if (_isViewingArchivedThread)
            TextButton(
              onPressed: _returnToMainThread,
              child: const Text('現在の相談へ'),
            ),
        ],
      ),
    );
  }

  Widget _buildChatHistoryDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: AppTheme.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '相談履歴',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('現在の相談'),
              subtitle: const Text('今の相談に戻る'),
              selected: !_isViewingArchivedThread,
              onTap: () {
                Navigator.of(context).maybePop();
                _returnToMainThread();
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<AiChatThreadSummary>>(
                stream:
                    _chatHistoryRepo.watchArchivedThreadSummaries(limit: 30),
                builder: (context, snap) {
                  final threads = snap.data ?? const <AiChatThreadSummary>[];

                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (threads.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '保存された過去の相談はまだありません。',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.secondaryText(context),
                                  ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: threads.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final thread = threads[index];
                      final isSelected = thread.id == _activeArchiveId;

                      return ListTile(
                        selected: isSelected,
                        leading: const Icon(Icons.forum_outlined),
                        title: Text(
                          thread.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${thread.messageCount}件のメッセージ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _openArchivedThread(thread),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _aiAvatar(),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardSurface(context),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              List.filled(_dotCount, '・').join(''),
              style: TextStyle(
                fontSize: 22,
                color: AppTheme.secondaryText(context),
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final hasChunks = msg.chunks?.isNotEmpty ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (msg.isLoading) {
      return _buildLoadingBubble(context);
    }

    final bubbleColor = msg.isUser
        ? AppTheme.accent
        : isDark
            ? AppTheme.cardInnerDark
            : Colors.white;

    final textColor = msg.isUser ? Colors.white : AppTheme.primaryText(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment:
            msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!msg.isUser) ...[
                _aiAvatar(),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(msg.isUser ? 18 : 6),
                      bottomRight: Radius.circular(msg.isUser ? 6 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.softShadow(context),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.content,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.55,
                      color: textColor,
                      fontWeight:
                          msg.isUser ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (msg.isUser) ...[
                const SizedBox(width: 12),
                _userAvatar(),
              ],
            ],
          ),
          if (!msg.isUser && hasChunks)
            Padding(
              padding: const EdgeInsets.only(left: 82, top: 6),
              child: ActionChip(
                avatar: const Icon(Icons.article_outlined, size: 18),
                label: const Text('参照された内容を見る'),
                onPressed: () => _showChunksDialog(msg.chunks!),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboardVisible = mq.viewInsets.bottom > 0;
    final topContentInset = mq.padding.top + kToolbarHeight + 12;
    final composerBottomPadding =
        keyboardVisible ? 10.0 : FloatingBottomNavigation.contentClearance + 10;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      endDrawer: _buildChatHistoryDrawer(context),
      body: PaidFeatureGate(
        featureName: 'AI相談',
        lockedTitle: 'AI相談は有料プランの機能です',
        lockedMessage: 'ペットプロフィール、飼育環境、温湿度データを踏まえたAI相談は、有料プランで利用できます。',
        icon: Icons.smart_toy_rounded,
        showBackground: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: topContentInset),
                  ),
                  SliverToBoxAdapter(
                    child: _buildChatHeader(context),
                  ),
                  SliverToBoxAdapter(
                    child: AnimatedSwitcher(
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
                                child: _buildDescriptionCard(context),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  if (!_isRestoringHistory &&
                      _hasRestoredHistory &&
                      _messages.isNotEmpty &&
                      !_isViewingArchivedThread)
                    SliverToBoxAdapter(
                      child: _buildHistoryRestoredCard(context),
                    ),
                  if (_isRestoringHistory)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return KeyedSubtree(
                              key: ValueKey(_messages[index].hashCode),
                              child: _buildMessageBubble(_messages[index]),
                            );
                          },
                          childCount: _messages.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 12),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                composerBottomPadding,
              ),
              child: AnimatedShiningBorder(
                borderRadius: 24,
                borderWidth: 2.2,
                active: _focusNode.hasFocus && !_isViewingArchivedThread,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardSurface(context),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.softShadow(context),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          focusNode: _focusNode,
                          controller: _textController,
                          enabled: !_isLoading && !_isViewingArchivedThread,
                          minLines: 1,
                          maxLines: 4,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.primaryText(context),
                          ),
                          decoration: InputDecoration(
                            hintText: _isViewingArchivedThread
                                ? '過去の相談を表示中です'
                                : '気になることを相談する',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 13,
                            ),
                            filled: true,
                            fillColor: Colors.transparent,
                            hintStyle: TextStyle(
                              color: AppTheme.weakText(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filled(
                        icon: const Icon(Icons.send_rounded),
                        onPressed: (_isLoading || _isViewingArchivedThread)
                            ? null
                            : _handleSend,
                      ),
                      const SizedBox(width: 6),
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

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _dotTimer?.cancel();
    _avatarSub?.cancel();
    _avatarSub = null;
    super.dispose();
  }
}
