import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/hamster_avatar.dart';
import '../models/pet_profile.dart';
import '../models/feature_trial_access.dart';
import '../services/ai_chat_history_repo.dart';
import '../services/app_analytics.dart';
import '../services/chat_request_sanitizer.dart';
import '../services/hamster_avatar_appearance_resolver.dart';
import '../services/hamster_avatar_asset_resolver.dart';
import '../services/pet_profile_repo.dart';
import '../services/feature_trial_repo.dart';
import '../services/billing_status_repo.dart';
import '../services/onboarding_state_repo.dart';
import 'monitoring_introduction_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/hamster_avatar_view.dart';
import '../widgets/floating_bottom_navigation.dart';
import '../widgets/hamster_feedback_popup.dart';
import '../widgets/paid_feature_gate.dart';
import '../widgets/shine_border.dart';

const String _ragApiBaseUrl = String.fromEnvironment(
  'RAG_API_BASE_URL',
  defaultValue: 'https://hamster-rag-api-laroc33gtq-an.a.run.app',
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
  final String youtubeVideoId;
  final String youtubeUrl;
  final String thumbnailUrl;
  final String contextRole;

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
    required this.youtubeVideoId,
    required this.youtubeUrl,
    required this.thumbnailUrl,
    required this.contextRole,
  });

  /// Older conversation history can contain an excerpt produced before the
  /// server-side source-quality guard existed.  Never render a lost-byte
  /// marker from that retained audit data as user-facing evidence.
  bool get isDisplayableEvidence {
    const replacementCharacter = '\ufffd';
    return ![
      text,
      filename,
      semanticTitle,
      sectionName,
      sectionSummary,
    ].any((value) => value.contains(replacementCharacter));
  }

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
      youtubeVideoId: (j['youtube_video_id'] ?? '') as String,
      youtubeUrl: (j['youtube_url'] ?? '') as String,
      thumbnailUrl: (j['thumbnail_url'] ?? '') as String,
      contextRole: (j['context_role'] ?? '') as String,
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
      'youtube_video_id': youtubeVideoId,
      'youtube_url': youtubeUrl,
      'thumbnail_url': thumbnailUrl,
      'context_role': contextRole,
    };
  }
}

class ChatApiResult {
  final String answer;
  final List<RetrievedChunk> chunks;
  final Map<String, dynamic> ragMetadata;

  ChatApiResult({
    required this.answer,
    required this.chunks,
    this.ragMetadata = const {},
  });
}

class ChatMessage {
  final String? id;
  final String content;
  final bool isUser;
  final List<RetrievedChunk>? chunks;
  final String? originalQuery;
  final Map<String, dynamic> ragMetadata;
  final AiChatAnswerFeedback? feedback;
  final String? archiveId;
  final bool isLoading;

  ChatMessage({
    this.id,
    required this.content,
    required this.isUser,
    this.chunks,
    this.originalQuery,
    this.ragMetadata = const {},
    this.feedback,
    this.archiveId,
    this.isLoading = false,
  });

  bool get canReceiveFeedback =>
      !isUser &&
      !isLoading &&
      id != null &&
      (originalQuery?.isNotEmpty ?? false);

  ChatMessage copyWith({
    AiChatAnswerFeedback? feedback,
  }) {
    return ChatMessage(
      id: id,
      content: content,
      isUser: isUser,
      chunks: chunks,
      originalQuery: originalQuery,
      ragMetadata: ragMetadata,
      feedback: feedback ?? this.feedback,
      archiveId: archiveId,
      isLoading: isLoading,
    );
  }
}

class FuncSearchScreen extends StatefulWidget {
  final String? initialDraft;
  final bool showCloseButton;
  final bool showPaidGateBackground;
  final Future<void> Function()? onConsultationCompleted;
  final TrialFeature? trialFeature;
  final bool allowDuringOnboarding;
  final bool useInitialTrial;
  final bool canStartInitialTrial;
  final bool showInputCoach;

  const FuncSearchScreen({
    super.key,
    this.initialDraft,
    this.showCloseButton = false,
    this.showPaidGateBackground = false,
    this.onConsultationCompleted,
    this.trialFeature,
    this.allowDuringOnboarding = false,
    this.useInitialTrial = false,
    this.canStartInitialTrial = false,
    this.showInputCoach = false,
  });

  @override
  FuncSearchScreenState createState() => FuncSearchScreenState();
}

class FuncSearchScreenState extends State<FuncSearchScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AiChatHistoryRepo _chatHistoryRepo = AiChatHistoryRepo();
  final PetProfileRepo _petProfileRepo = PetProfileRepo();
  final FeatureTrialRepo _trialRepo = FeatureTrialRepo();
  final BillingStatusRepo _billingRepo = BillingStatusRepo();
  final OnboardingStateRepo _onboardingRepo = OnboardingStateRepo();
  late final Stream<OnboardingState> _onboardingStream;

  static const HamsterAvatarAppearanceResolver _avatarAppearanceResolver =
      HamsterAvatarAppearanceResolver();
  static const HamsterAvatarAssetResolver _avatarAssetResolver =
      HamsterAvatarAssetResolver();

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final FlutterSecureStorage _voiceConsentStorage =
      const FlutterSecureStorage();
  final GlobalKey _composerCoachKey = GlobalKey();
  bool _inputCoachShown = false;
  final List<ChatMessage> _messages = [];

  String? _activeArchiveId;

  bool _isLoading = false;
  bool _openingMonitoringIntro = false;
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
  String? _retryRequestText;
  String? _retryRequestId;
  final Set<String> _feedbackSavingMessageIds = <String>{};
  StreamSubscription<Amplitude>? _amplitudeSub;
  List<double> _voiceWaveform = List<double>.filled(28, 0.14);
  bool _isRecordingVoice = false;
  bool _isTranscribingVoice = false;

  static const _voiceConsentStorageKey = 'ai_voice_transcription_consent_v1';

  bool get _isViewingArchivedThread => _activeArchiveId != null;

  void _showFeedback(
    String message, {
    HamsterFeedbackTone tone = HamsterFeedbackTone.success,
  }) {
    if (!mounted) return;
    HamsterFeedbackPopup.show(
      context,
      message: message,
      tone: tone,
    );
  }

  @override
  void initState() {
    super.initState();
    _onboardingStream = _onboardingRepo.watchState();
    _restoreChatHistory();
    _listenUserAvatar();

    final initialDraft = widget.initialDraft?.trim();
    if (initialDraft != null && initialDraft.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setDraftText(initialDraft);
      });
    }
    if (widget.showInputCoach) {
      WidgetsBinding.instance.addPostFrameCallback((_) => showInputCoach());
    }

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

  void showInputCoach() {
    if (_inputCoachShown || !mounted) return;
    _inputCoachShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TutorialCoachMark(
        targets: [
          TargetFocus(
            identify: 'ai-question-input',
            keyTarget: _composerCoachKey,
            shape: ShapeLightFocus.RRect,
            radius: 24,
            contents: [
              TargetContent(
                align: ContentAlign.top,
                child: const _AiInputCoachContent(),
              ),
            ],
          ),
        ],
        colorShadow: Colors.black,
        opacityShadow: 0.78,
        textSkip: 'あとで',
      ).show(context: context);
    });
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
            id: m.id,
            content: m.content,
            isUser: m.isUser,
            chunks: chunks,
            originalQuery: m.originalQuery,
            ragMetadata: m.ragMetadata,
            feedback: m.feedback,
          ),
        );

        restoredHistory.add({
          'role': m.role,
          'content': m.content,
        });
      }

      final lastSaved = savedMessages.isEmpty ? null : savedMessages.last;
      final unresolvedRequestId = lastSaved?.isUser == true &&
              (lastSaved?.requestId?.isNotEmpty ?? false)
          ? lastSaved!.requestId
          : null;

      setState(() {
        _messages
          ..clear()
          ..addAll(restoredMessages);

        _conversationHistory
          ..clear()
          ..addAll(restoredHistory);

        _activeArchiveId = null;
        _retryRequestText =
            unresolvedRequestId == null ? null : lastSaved!.content;
        _retryRequestId = unresolvedRequestId;
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

      _showFeedback('新しい相談を始めました。');
    } catch (e) {
      if (!mounted) return;

      _showFeedback(
        '新しい相談を始められませんでした。通信を確認してお試しください。',
        tone: HamsterFeedbackTone.error,
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
            id: m.id,
            content: m.content,
            isUser: m.isUser,
            chunks: chunks,
            originalQuery: m.originalQuery,
            ragMetadata: m.ragMetadata,
            feedback: m.feedback,
            archiveId: thread.id,
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

      _showFeedback(
        '過去の相談を読み込めませんでした。通信を確認してお試しください。',
        tone: HamsterFeedbackTone.error,
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

  Future<void> _confirmHideArchivedThread(AiChatThreadSummary thread) async {
    if (_isLoading || _isRestoringHistory) return;

    final shouldHide = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('相談履歴を削除しますか？'),
        content: const Text(
          'この相談は履歴一覧から見えなくなります。会話データは品質改善・監査用に保存され、'
          '削除した状態も記録されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (shouldHide != true) return;

    try {
      await _chatHistoryRepo.hideArchivedThread(archiveId: thread.id);
      if (!mounted) return;
      if (_activeArchiveId == thread.id) {
        await _returnToMainThread();
      }
      if (!mounted) return;
      _showFeedback('相談履歴を一覧から削除しました。');
    } catch (_) {
      if (!mounted) return;
      _showFeedback(
        '相談履歴を削除できませんでした。',
        tone: HamsterFeedbackTone.error,
      );
    }
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

  Future<Map<String, String>> _authenticatedApiHeaders() async {
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

    final headers = <String, String>{
      'Authorization': 'Bearer $idToken',
    };
    if (appCheckToken != null && appCheckToken.isNotEmpty) {
      headers['X-Firebase-AppCheck'] = appCheckToken;
    }
    return headers;
  }

  Future<bool> _confirmVoiceTranscriptionConsent() async {
    final alreadyConsented =
        await _voiceConsentStorage.read(key: _voiceConsentStorageKey);
    if (alreadyConsented == 'accepted') return true;
    if (!mounted) return false;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('音声入力について'),
        content: const Text(
          '録音した音声は文字起こしのために OpenAI へ安全に送信されます。'
          '変換後、音声ファイルはこの端末とサーバーに保存しません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('同意して録音する'),
          ),
        ],
      ),
    );

    if (accepted == true) {
      await _voiceConsentStorage.write(
        key: _voiceConsentStorageKey,
        value: 'accepted',
      );
      return true;
    }
    return false;
  }

  Future<void> _startVoiceRecording() async {
    if (_isLoading ||
        _isViewingArchivedThread ||
        _isRecordingVoice ||
        _isTranscribingVoice) {
      return;
    }

    try {
      if (!await _confirmVoiceTranscriptionConsent()) return;
      if (!await _audioRecorder.hasPermission()) {
        if (!mounted) return;
        _showFeedback(
          '音声入力にはマイクの許可が必要です。',
          tone: HamsterFeedbackTone.warning,
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/ham-care-voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );

      await _amplitudeSub?.cancel();
      _amplitudeSub = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 90))
          .listen((amplitude) {
        if (!mounted || !_isRecordingVoice) return;
        final normalized =
            ((amplitude.current + 55) / 55).clamp(0.08, 1.0).toDouble();
        setState(() {
          _voiceWaveform = [
            ..._voiceWaveform.sublist(1),
            normalized,
          ];
        });
      });

      if (!mounted) return;
      setState(() {
        _isRecordingVoice = true;
        _voiceWaveform = List<double>.filled(28, 0.14);
      });
    } catch (_) {
      if (!mounted) return;
      _showFeedback(
        '音声入力を開始できませんでした。',
        tone: HamsterFeedbackTone.error,
      );
    }
  }

  Future<void> _cancelVoiceRecording() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    await _audioRecorder.cancel();
    if (!mounted) return;
    setState(() {
      _isRecordingVoice = false;
      _voiceWaveform = List<double>.filled(28, 0.14);
    });
  }

  Future<String> _transcribeVoiceFile(File audioFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_ragApiBaseUrl/transcribe'),
    );
    request.headers.addAll(await _authenticatedApiHeaders());
    request.files.add(
      await http.MultipartFile.fromPath(
        'audio',
        audioFile.path,
        filename: audioFile.uri.pathSegments.last,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return (decoded['text'] as String? ?? '').trim();
      }
    }
    if (response.statusCode == 401) {
      throw Exception('認証に失敗しました。ログインし直してください。');
    }
    if (response.statusCode == 413) {
      throw Exception('録音時間が長すぎます。短く区切ってお試しください。');
    }
    if (response.statusCode >= 500) {
      throw Exception('文字起こしサービスで一時的なエラーが発生しました。');
    }
    throw Exception('音声を文字に変換できませんでした。');
  }

  Future<void> _stopAndTranscribeVoice() async {
    if (!_isRecordingVoice || _isTranscribingVoice) return;

    File? audioFile;
    try {
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;
      final path = await _audioRecorder.stop();
      if (path == null || path.isEmpty) {
        throw Exception('録音ファイルを取得できませんでした。');
      }

      audioFile = File(path);
      if (!mounted) return;
      setState(() {
        _isRecordingVoice = false;
        _isTranscribingVoice = true;
      });

      final transcription = await _transcribeVoiceFile(audioFile);
      if (!mounted) return;
      if (transcription.isEmpty) {
        _showFeedback(
          '音声を聞き取れませんでした。もう一度お試しください。',
          tone: HamsterFeedbackTone.warning,
        );
      } else {
        final existing = _textController.text.trim();
        final combined =
            existing.isEmpty ? transcription : '$existing $transcription';
        _textController.value = TextEditingValue(
          text: combined,
          selection: TextSelection.collapsed(offset: combined.length),
        );
        _focusNode.requestFocus();
      }
    } catch (error) {
      if (mounted) {
        _showFeedback(
          '音声入力に失敗しました。もう一度お試しください。',
          tone: HamsterFeedbackTone.error,
        );
      }
    } finally {
      if (audioFile != null) {
        try {
          if (await audioFile.exists()) await audioFile.delete();
        } catch (_) {
          // 一時ファイルの削除に失敗しても、相談画面は継続できる。
        }
      }
      if (mounted) {
        setState(() {
          _isRecordingVoice = false;
          _isTranscribingVoice = false;
          _voiceWaveform = List<double>.filled(28, 0.14);
        });
      }
    }
  }

  Future<ChatApiResult> _fetchAIResponseWithHistory(
    String userMessage, {
    required String requestId,
  }) async {
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

    final historyToSend = sanitizeChatRequestHistory(_conversationHistory);

    final requestBody = json.encode({
      'query': userMessage,
      'history': historyToSend,
      'request_id': requestId,
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

      final rawRelatedVideos = decoded['related_videos'];
      final relatedVideos = rawRelatedVideos is List
          ? rawRelatedVideos.whereType<Map>().map((video) {
              final item = Map<String, dynamic>.from(video);
              return <String, dynamic>{
                'videoId': item['video_id'] as String? ?? '',
                'title': item['title'] as String? ?? '',
                'url': item['url'] as String? ?? '',
                'thumbnailUrl': item['thumbnail_url'] as String? ?? '',
              };
            }).toList()
          : const <Map<String, dynamic>>[];

      final ragMetadata = <String, dynamic>{
        'namespace': decoded['namespace'] as String? ?? '',
        'indexName': decoded['index_name'] as String? ?? '',
        'ragBuild': decoded['rag_build'] as String? ?? '',
        'questionCategory': decoded['question_category'] as String? ?? '',
        'relatedVideos': relatedVideos,
      };

      return ChatApiResult(
        answer: answer,
        chunks: chunks,
        ragMetadata: ragMetadata,
      );
    }

    if (res.statusCode == 401) {
      throw Exception('認証に失敗しました。ログインし直してください。');
    }

    if (res.statusCode == 429) {
      throw Exception('AI相談の利用上限に達している可能性があります。少し時間をおいて再度お試しください。');
    }

    if (res.statusCode == 422) {
      throw Exception('質問または会話履歴が長すぎるか、形式を確認できませんでした。質問を短くして再度お試しください。');
    }

    if (res.statusCode == 409) {
      throw Exception(
        '前回の相談を確認中です。同じ内容を連続して送信せず、少し時間をおいて画面を開き直してください。',
      );
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
    if (text.runes.length > maxChatRequestQueryRunes) {
      _showFeedback(
        '質問は$maxChatRequestQueryRunes文字以内で送信してください。',
        tone: HamsterFeedbackTone.warning,
      );
      return;
    }

    final hasHistory =
        _conversationHistory.any((message) => message['role'] == 'assistant');
    unawaited(
      AppAnalytics.logAiConsultationStarted(hasHistory: hasHistory),
    );

    if (widget.trialFeature == TrialFeature.ai) {
      final billing = await _billingRepo.fetchBillingStatus();
      if (!billing.canUsePaidFeatures) {
        final trial = await _trialRepo.fetch();
        if (!trial.allows(TrialFeature.ai)) {
          if (!mounted) return;
          _showFeedback(
            'AIの無料体験は3回までです。',
            tone: HamsterFeedbackTone.warning,
          );
          return;
        }
      }
    }

    final requestId = _retryRequestText == text && _retryRequestId != null
        ? _retryRequestId!
        : 'chat_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';

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

    _textController.clear();
    _scrollToBottom();

    try {
      await _chatHistoryRepo.addUserMessage(
        content: text,
        requestId: requestId,
      );
      _startDotTimer();
      final result = await _fetchAIResponseWithHistory(
        text,
        requestId: requestId,
      );

      if (!mounted) return;

      setState(() {
        _messages.removeWhere((msg) => msg.isLoading);
        final assistantMessageId = const Uuid().v4();
        _messages.add(
          ChatMessage(
            id: assistantMessageId,
            content: result.answer,
            isUser: false,
            chunks: result.chunks,
            originalQuery: text,
            ragMetadata: result.ragMetadata,
          ),
        );
        _conversationHistory.add({
          'role': 'assistant',
          'content': result.answer,
        });
      });

      final assistantMessage = _messages.last;
      unawaited(
        _chatHistoryRepo.addAssistantMessage(
          messageId: assistantMessage.id!,
          content: result.answer,
          originalQuery: text,
          chunks: result.chunks.map((e) => e.toJson()).toList(),
          ragMetadata: result.ragMetadata,
        ),
      );
      unawaited(
        AppAnalytics.logAiConsultationCompleted(
          retrievedChunkCount: result.chunks.length,
        ),
      );
      if (_retryRequestId == requestId) {
        _retryRequestId = null;
        _retryRequestText = null;
      }
      if (widget.trialFeature == TrialFeature.ai) {
        final billing = await _billingRepo.fetchBillingStatus();
        if (!billing.canUsePaidFeatures) await _trialRepo.consumeAiTrial();
      }
      final onConsultationCompleted = widget.onConsultationCompleted;
      if (onConsultationCompleted != null) {
        unawaited(onConsultationCompleted());
      }

      _scrollToBottom();
    } catch (e) {
      _retryRequestText = text;
      _retryRequestId = requestId;
      unawaited(AppAnalytics.logAiConsultationFailed());

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

  Future<void> _openReferenceVideoUrl(String rawUrl) async {
    rawUrl = rawUrl.trim();
    if (rawUrl.isEmpty) return;

    try {
      final opened = await launchUrl(
        Uri.parse(rawUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _showFeedback(
          'YouTubeを開けませんでした。',
          tone: HamsterFeedbackTone.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      _showFeedback(
        'YouTubeを開けませんでした。',
        tone: HamsterFeedbackTone.error,
      );
    }
  }

  Map<String, dynamic>? _videoForReference(
    RetrievedChunk chunk,
    List<Map<String, dynamic>> relatedVideos,
  ) {
    final title = chunk.semanticTitle.trim();
    if (title.isEmpty) return null;
    for (final video in relatedVideos) {
      if ((video['title'] as String? ?? '').trim() == title) return video;
    }
    return null;
  }

  Widget _buildReferenceVideoPreview(
    RetrievedChunk chunk,
    List<Map<String, dynamic>> relatedVideos,
  ) {
    final relatedVideo = _videoForReference(chunk, relatedVideos);
    final thumbnailUrl = chunk.thumbnailUrl.trim().isNotEmpty
        ? chunk.thumbnailUrl.trim()
        : (relatedVideo?['thumbnailUrl'] as String? ?? '').trim();
    final videoUrl = chunk.youtubeUrl.trim().isNotEmpty
        ? chunk.youtubeUrl.trim()
        : (relatedVideo?['url'] as String? ?? '').trim();
    if (thumbnailUrl.isEmpty || videoUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final label = chunk.semanticTitle.isNotEmpty
        ? '「${chunk.semanticTitle}」をYouTubeで再生'
        : 'YouTubeで関連動画を再生';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openReferenceVideoUrl(videoUrl),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.cardSurface(context),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.play_circle_outline_rounded,
                        size: 48,
                        color: AppTheme.secondaryText(context),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.56),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    color: Colors.black.withValues(alpha: 0.62),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new_rounded,
                            size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'YouTubeで動画を見る',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showChunksDialog(
    List<RetrievedChunk> chunks, {
    List<Map<String, dynamic>> relatedVideos = const [],
  }) async {
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
                        final showFilename = c.filename.isNotEmpty &&
                            c.filename != c.semanticTitle;
                        return SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildReferenceVideoPreview(c, relatedVideos),
                                if (c.semanticTitle.isNotEmpty)
                                  Text(
                                    c.semanticTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                if (showFilename) ...[
                                  const SizedBox(height: 4),
                                  Text('出典: ${c.filename}'),
                                ],
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.accent
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '回答の根拠となった抜粋',
                                        style: TextStyle(
                                          color: AppTheme.accent,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        c.text,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          height: 1.6,
                                        ),
                                      ),
                                    ],
                                  ),
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
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveAnswerFeedback(
    ChatMessage message, {
    required String rating,
    String? reason,
  }) async {
    final messageId = message.id;
    final originalQuery = message.originalQuery;
    if (messageId == null || originalQuery == null || originalQuery.isEmpty) {
      return;
    }
    if (_feedbackSavingMessageIds.contains(messageId)) return;

    final previousFeedback = message.feedback;
    final nextFeedback = AiChatAnswerFeedback(
      value: rating,
      reason: reason,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _feedbackSavingMessageIds.add(messageId);
      final index = _messages.indexWhere((item) => item.id == messageId);
      if (index >= 0) {
        _messages[index] = message.copyWith(feedback: nextFeedback);
      }
    });

    try {
      await _chatHistoryRepo.saveAssistantFeedback(
        messageId: messageId,
        rating: rating,
        reason: reason,
        originalQuery: originalQuery,
        answer: message.content,
        chunks: (message.chunks ?? const <RetrievedChunk>[])
            .map((chunk) => chunk.toJson())
            .toList(),
        ragMetadata: message.ragMetadata,
        archiveId: message.archiveId,
      );

      if (!mounted) return;
      _showFeedback(
        rating == 'helpful'
            ? '評価ありがとうございます。今後の改善に役立てます。'
            : 'ご指摘ありがとうございます。回答改善に役立てます。',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((item) => item.id == messageId);
        if (index >= 0) {
          _messages[index] = message.copyWith(feedback: previousFeedback);
        }
      });
      _showFeedback(
        '評価を保存できませんでした。通信を確認してもう一度お試しください。',
        tone: HamsterFeedbackTone.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _feedbackSavingMessageIds.remove(messageId);
        });
      }
    }
  }

  Future<void> _showNotHelpfulReasons(ChatMessage message) async {
    const reasons = <({String value, String label, IconData icon})>[
      (
        value: 'inaccurate',
        label: '内容が正確ではない',
        icon: Icons.gpp_bad_outlined,
      ),
      (
        value: 'too_abstract',
        label: 'もっと具体的に知りたい',
        icon: Icons.format_align_left_rounded,
      ),
      (
        value: 'off_topic',
        label: '質問に十分答えていない',
        icon: Icons.question_mark_rounded,
      ),
      (
        value: 'safety_concern',
        label: '安全面が心配',
        icon: Icons.health_and_safety_outlined,
      ),
      (
        value: 'other',
        label: 'その他',
        icon: Icons.more_horiz_rounded,
      ),
    ];

    final selectedReason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text(
                    '良くない回答',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('理由を選ぶと、改善点を把握しやすくなります。'),
                ),
                ...reasons.map(
                  (reason) => ListTile(
                    leading: Icon(reason.icon),
                    title: Text(reason.label),
                    onTap: () => Navigator.of(sheetContext).pop(reason.value),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedReason == null) return;
    await _saveAnswerFeedback(
      message,
      rating: 'not_helpful',
      reason: selectedReason,
    );
  }

  Widget _buildAssistantMarkdown(String content, Color textColor) {
    final theme = Theme.of(context);
    final baseTextStyle = theme.textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.55,
          color: textColor,
          fontWeight: FontWeight.w500,
        ) ??
        TextStyle(
          fontSize: 16,
          height: 1.55,
          color: textColor,
          fontWeight: FontWeight.w500,
        );
    final codeBackground = theme.brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.22)
        : AppTheme.quickActionFill(context);

    return MarkdownBody(
      data: content,
      styleSheet: MarkdownStyleSheet(
        p: baseTextStyle,
        h1: baseTextStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w900),
        h2: baseTextStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w900),
        h3: baseTextStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
        strong: baseTextStyle.copyWith(fontWeight: FontWeight.w900),
        em: baseTextStyle.copyWith(fontStyle: FontStyle.italic),
        listBullet: baseTextStyle,
        blockquote: baseTextStyle.copyWith(
          color: AppTheme.secondaryText(context),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
                color: AppTheme.accent.withValues(alpha: 0.7), width: 3),
          ),
        ),
        code: baseTextStyle.copyWith(
          fontFamily: 'monospace',
          fontSize: 14,
          backgroundColor: codeBackground,
        ),
        codeblockDecoration: BoxDecoration(
          color: codeBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        a: baseTextStyle.copyWith(
          color: AppTheme.accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildAnswerFeedbackControls(ChatMessage message) {
    if (!message.canReceiveFeedback) return const SizedBox.shrink();

    final messageId = message.id!;
    final isSaving = _feedbackSavingMessageIds.contains(messageId);
    final isHelpful = message.feedback?.isHelpful ?? false;
    final isNotHelpful = message.feedback?.isNotHelpful ?? false;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: '良い回答',
          child: IconButton(
            tooltip: '良い回答',
            visualDensity: VisualDensity.compact,
            onPressed: isSaving
                ? null
                : () => _saveAnswerFeedback(message, rating: 'helpful'),
            icon: Icon(
              isHelpful
                  ? Icons.thumb_up_alt_rounded
                  : Icons.thumb_up_alt_outlined,
            ),
            color: isHelpful ? AppTheme.accent : Colors.white,
          ),
        ),
        Semantics(
          button: true,
          label: '良くない回答',
          child: IconButton(
            tooltip: '良くない回答',
            visualDensity: VisualDensity.compact,
            onPressed: isSaving ? null : () => _showNotHelpfulReasons(message),
            icon: Icon(
              isNotHelpful
                  ? Icons.thumb_down_alt_rounded
                  : Icons.thumb_down_alt_outlined,
            ),
            color: isNotHelpful ? Colors.redAccent : Colors.white,
          ),
        ),
      ],
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
          if (widget.showCloseButton) ...[
            IconButton(
              tooltip: '初回設定に戻る',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 5,
                    offset: Offset(0, 1),
                  ),
                ],
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
                        onLongPress: () => _confirmHideArchivedThread(thread),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _aiAvatar(),
          const SizedBox(height: 8),
          Text(
            List.filled(_dotCount, '・').join(''),
            style: TextStyle(
              fontSize: 22,
              color: AppTheme.secondaryText(context),
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserMessage(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(6),
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
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.55,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _userAvatar(),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _relatedVideosFor(ChatMessage message) {
    final raw = message.ragMetadata['relatedVideos'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((video) => Map<String, dynamic>.from(video))
        .toList();
  }

  List<RetrievedChunk> _referenceChunksFor(ChatMessage message) {
    final chunks = (message.chunks ?? const <RetrievedChunk>[])
        .where((chunk) => chunk.isDisplayableEvidence)
        .toList();
    final concreteEvidence =
        chunks.where((chunk) => chunk.contextRole == '具体的な根拠抜粋').toList();
    return concreteEvidence.isNotEmpty ? concreteEvidence : chunks;
  }

  Widget _buildAssistantMessage(ChatMessage msg) {
    final referenceChunks = _referenceChunksFor(msg);
    final hasChunks = referenceChunks.isNotEmpty;
    final relatedVideos = _relatedVideosFor(msg);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark
        ? Colors.black.withValues(alpha: 0.54)
        : Colors.white.withValues(alpha: 0.82);
    final panelBorder = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.white.withValues(alpha: 0.88);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _aiAvatar(),
              const SizedBox(width: 10),
              Text(
                'マロ博士からの回答',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: panelBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: _buildAssistantMarkdown(
                  msg.content,
                  AppTheme.primaryText(context),
                ),
              ),
            ),
          ),
          if (hasChunks || msg.canReceiveFeedback)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (hasChunks)
                    ActionChip(
                      avatar: const Icon(Icons.article_outlined, size: 18),
                      label: const Text('参照された内容を見る'),
                      onPressed: () => _showChunksDialog(
                        referenceChunks,
                        relatedVideos: relatedVideos,
                      ),
                    ),
                  _buildAnswerFeedbackControls(msg),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    if (msg.isLoading) {
      return _buildLoadingBubble(context);
    }

    return msg.isUser ? _buildUserMessage(msg) : _buildAssistantMessage(msg);
  }

  Widget _buildVoiceComposer() {
    final isTranscribing = _isTranscribingVoice;
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          IconButton(
            tooltip: '録音を取り消す',
            onPressed: isTranscribing ? null : _cancelVoiceRecording,
            icon: const Icon(Icons.close_rounded),
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: isTranscribing ? '音声を文字に変換中' : '録音中',
              child: _VoiceWaveform(
                samples: _voiceWaveform,
                color: AppTheme.accent,
              ),
            ),
          ),
          if (isTranscribing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else
            IconButton.filled(
              tooltip: '録音を終了して文字にする',
              onPressed: _stopAndTranscribeVoice,
              icon: const Icon(Icons.stop_rounded),
            ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Future<void> _openMonitoringIntroduction() async {
    if (_openingMonitoringIntro || !mounted) return;
    setState(() => _openingMonitoringIntro = true);
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const MonitoringIntroductionScreen(),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingMonitoringIntro = false);
    }
  }

  Widget _buildMonitoringIntroCta() => StreamBuilder<OnboardingState>(
        stream: _onboardingStream,
        builder: (context, snapshot) {
          if (snapshot.hasError ||
              snapshot.data?.monitoringIntroCtaPending != true ||
              _isLoading ||
              _isRestoringHistory ||
              _isViewingArchivedThread) {
            return const SizedBox.shrink();
          }
          return Card(
            key: const ValueKey('monitoring-intro-cta'),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('回答を確認したら、見守りを始めましょう'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _openingMonitoringIntro
                        ? null
                        : _openMonitoringIntroduction,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('次へ：記録を始める'),
                  ),
                ],
              ),
            ),
          );
        },
      );

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
        showBackground: widget.showPaidGateBackground,
        trialFeature: widget.trialFeature,
        allowDuringOnboarding: widget.allowDuringOnboarding,
        useInitialTrial: widget.useInitialTrial,
        canStartInitialTrial: widget.canStartInitialTrial,
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
                  SliverToBoxAdapter(child: _buildMonitoringIntroCta()),
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
                  key: _composerCoachKey,
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
                  child: (_isRecordingVoice || _isTranscribingVoice)
                      ? _buildVoiceComposer()
                      : Row(
                          children: [
                            Expanded(
                              child: TextField(
                                focusNode: _focusNode,
                                controller: _textController,
                                enabled:
                                    !_isLoading && !_isViewingArchivedThread,
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
                            IconButton(
                              tooltip: '音声入力',
                              onPressed:
                                  (_isLoading || _isViewingArchivedThread)
                                      ? null
                                      : _startVoiceRecording,
                              icon: const Icon(Icons.mic_none_rounded),
                            ),
                            const SizedBox(width: 2),
                            IconButton.filled(
                              icon: const Icon(Icons.send_rounded),
                              onPressed:
                                  (_isLoading || _isViewingArchivedThread)
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
    _amplitudeSub?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }
}

class _VoiceWaveform extends StatelessWidget {
  final List<double> samples;
  final Color color;

  const _VoiceWaveform({
    required this.samples,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: samples
          .map(
            (sample) => AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              width: 3.5,
              height: 8 + (28 * sample),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.45 + (sample * 0.55)),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AiInputCoachContent extends StatelessWidget {
  const _AiInputCoachContent();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Text(
          'ここに、いま気になることを入力してみましょう。\n例：今日の飼育環境で確認しておくことを教えてください。',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
        ),
      );
}
